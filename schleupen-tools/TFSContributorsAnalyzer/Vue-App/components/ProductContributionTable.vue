<template>
  <div class="product-table-view">
    <table class="product-table">
      <thead>
        <tr>
          <th>Product</th>
          <th>Total Contributors</th>
          <th>VCS</th>
          <th>Contributions (filtered / total)</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rowList" :key="row.type + '-' + row.product">
          <!-- Product row -->
          <template v-if="row.type === 'product'">
            <td class="product-name">
              <button class="expand-btn" @click.stop="toggleExpanded(row.product)" :aria-expanded="isExpanded(row.product)">
                <span v-if="isExpanded(row.product)">▾</span>
                <span v-else>▸</span>
              </button>
              {{ row.product }}
            </td>
            <td class="contrib-count">{{ totalContributors(row.product) }}</td>
            <td class="vcs-type"><span :class="vcsBadgeClass(row.product)">{{ vcsLabel(row.product) }}</span></td>
            <td class="contrib-ratio">{{ filteredContribFor(row.product) }} / {{ totalContribFor(row.product) }}</td>
            <td class="actions">
              <button class="timeline-btn" @click="openTimeline(row.product)" title="Show timeline for this product" aria-label="Show timeline">📈</button>
            </td>
          </template>

          <!-- Expanded content row (render only when expanded) -->
          <template v-else-if="row.type === 'expand'">
            <td colspan="5" v-if="isExpanded(row.product)">
              <div class="expanded-content">
                <div v-if="contributorsFor(row.product).length">
                  <table class="inner-table">
                    <thead>
                      <tr>
                        <th>Author</th>
                        <th>Contributions</th>
                        <th>Percent</th>
                        <th>Files</th>
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="c in (isShowingFull(row.product) ? contributorsFor(row.product) : contributorsFor(row.product).slice(0, TOP_N))" :key="c.author">
                        <td class="author-cell">
                          <span class="author-swatch" :style="{ background: authorColors && authorColors[c.author] ? authorColors[c.author] : '#ccc' }"></span>
                          <button class="author-link" @click="filterToAuthor(c.author)" title="Filter to this author and switch to author view">{{ c.author }}</button>
                        </td>
                        <td>{{ c.count }}</td>
                        <td>{{ c.percent }}%</td>
                        <td>{{ c.files }}</td>
                        <td>
                          <button class="tiny-btn" @click="openAuthorTimeline(c.author)" title="Show timeline for this author" aria-label="Show timeline">📈</button>
                        </td>
                      </tr>
                    </tbody>
                  </table>

                  <div class="show-more-row" v-if="contributorsFor(row.product).length > TOP_N">
                    <button class="show-more-btn" v-if="!isShowingFull(row.product)" @click="toggleShowMore(row.product)">Show more</button>
                    <button class="show-more-btn" v-else @click="toggleShowMore(row.product)">Show less</button>
                  </div>
                </div>
                <div v-else class="no-contrib">No contributors match current filters.</div>
              </div>
            </td>
          </template>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';

const props = defineProps({
  products: {
    type: Array,
    required: true
  }
});

const store = useOwnershipStore();
const router = useRouter();
const { filteredData, filters, data: allData, productFilteredContributions, productTotals, productVcsMap, authorColors } = storeToRefs(store);


// track expanded rows and full-list toggles
const expanded = ref(new Set());
const showFull = ref(new Set());
const TOP_N = 5;


// Flattened row list: for rendering product row + expand row as separate entries
const rowList = computed(() => {
  const rows = [];
  (props.products || []).forEach(p => {
    rows.push({ type: 'product', product: p });
    rows.push({ type: 'expand', product: p });
  });
  return rows;
});

function toggleExpanded(product) {
  const s = expanded.value;
  if (s.has(product)) s.delete(product);
  else s.add(product);
  expanded.value = new Set([...s]);
}

function isExpanded(product) {
  return expanded.value.has(product);
}

function toggleShowMore(product) {
  const s = showFull.value;
  if (s.has(product)) s.delete(product);
  else s.add(product);
  showFull.value = new Set([...s]);
}

function isShowingFull(product) {
  return showFull.value.has(product);
}

function totalContributors(product) {
  // Total unique authors for the product in the full dataset
  const authors = new Set((allData.value || []).filter(r => r.Product === product).map(r => r.Author));
  return authors.size;
}

function vcsType(product) {
  return (productVcsMap.value && productVcsMap.value[product]) ? productVcsMap.value[product] : 'git';
}

function vcsLabel(product) {
  const src = vcsType(product);
  if (src === 'tfs') return 'TFS';
  if (src === 'git') return 'Git';
  return 'Unknown';
}

function vcsBadgeClass(product) {
  const src = vcsType(product);
  if (src === 'tfs') return 'vcs-badge tfs';
  if (src === 'git') return 'vcs-badge git';
  return 'vcs-badge unknown';
}

function filteredContribFor(product) {
  // contributions after filters and minPercent
  const val = (productFilteredContributions.value && productFilteredContributions.value[product]) ? productFilteredContributions.value[product] : 0;
  return val;
}

function totalContribFor(product) {
  return (productTotals.value && productTotals.value[product]) ? productTotals.value[product] : 0;
}

function openTimeline(product) {
  router.push({ name: 'Timeline', query: { product } });
}

function filterToAuthor(author) {
  // Apply author filter and switch to author chart mode
  store.setAuthors([author]);
  store.setChartMode('author');
}

function openAuthorTimeline(author) {
  router.push({ name: 'Timeline', query: { author } });
}

function contributorsFor(product) {
  // Build contributors list from filteredData for the product, include file counts and percent
  let rows = (filteredData.value || []).filter(r => r.Product === product);
  const byAuthor = {};
  let total = 0;
  rows.forEach(r => {
    if (!byAuthor[r.Author]) byAuthor[r.Author] = { count: 0, files: 0 };
    byAuthor[r.Author].count += r.ContributionCount || 0;
    byAuthor[r.Author].files += r.FileCount || 0;
    total += r.ContributionCount || 0;
  });
  const minPercent = filters.value.minPercent || 0;
  const arr = Object.entries(byAuthor)
    .map(([author, info]) => ({
      author,
      count: info.count,
      files: info.files,
      percent: total ? Number((info.count / total * 100).toFixed(1)) : 0
    }))
    .filter(item => item.percent >= minPercent)
    .sort((a, b) => b.count - a.count);
  return arr;
}
</script>

<style scoped>
.product-table-view {
  background: #fff;
  border-radius: 10px;
  box-shadow: 0 2px 8px #0001;
  padding: 1.2rem;
}
.product-table {
  width: 100%;
  border-collapse: collapse;
}
.product-table th, .product-table td {
  border: 1px solid #d0d7de;
  padding: 0.6em 1em;
  text-align: left;
}
.product-table th {
  background: #f0f6ff;
  color: #1f77b4;
}
.product-name {
  font-weight: 600;
}
.expand-btn {
  margin-right: 0.5rem;
  background: transparent;
  border: none;
  cursor: pointer;
  font-size: 0.9em;
}
.contrib-count, .vcs-type, .contrib-ratio {
  width: 140px;
}
.actions {
  width: 120px;
}
.timeline-btn {
  padding: 0.35em 0.6em;
  border-radius: 6px;
  border: 1px solid #bbb;
  background: #f8f9fa;
  color: #1f77b4;
  cursor: pointer;
}
.timeline-btn:hover {
  background: #eaf4ff;
}
.expand-row td {
  background: #fbfdff;
  padding: 0.8em 1em;
}
.inner-table {
  width: 100%;
  border-collapse: collapse;
}
.inner-table th, .inner-table td {
  border: 1px solid #e2e8f0;
  padding: 0.4em 0.6em;
}
.inner-table th {
  background: #f7fbff;
  color: #1f77b4;
  font-weight: 600;
}
.no-contrib {
  color: #6c757d;
}

.author-cell {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.author-swatch {
  width: 12px;
  height: 12px;
  border-radius: 2px;
  display: inline-block;
  border: 1px solid #ddd;
}
.author-link {
  background: none;
  border: none;
  color: #1f77b4;
  cursor: pointer;
  padding: 0;
  font: inherit;
  text-align: left;
}
.tiny-btn {
  padding: 0.25em 0.5em;
  margin-left: 0.3em;
  border-radius: 6px;
  border: 1px solid #ccc;
  background: #fff;
  cursor: pointer;
  font-size: 0.85em;
}
.tiny-btn:hover { background: #f0f6ff; }
.show-more-row { margin-top: 0.6rem; }
.show-more-btn { background: none; border: none; color: #1f77b4; cursor: pointer; }

/* VCS badge styles (copied from PieChart.vue) */
.vcs-badge {
  display: inline-block;
  margin-left: 0.5rem;
  padding: 0.12rem 0.4rem;
  font-size: 0.75rem;
  font-weight: 600;
  border-radius: 0.35rem;
  color: #fff;
  text-transform: uppercase;
}
.vcs-badge.tfs { background: var(--vcs-tfs, #ff7f0e); }
.vcs-badge.git { background: var(--vcs-git, #1f77b4); }
.vcs-badge.unknown { background: var(--vcs-unknown, #6c757d); }
</style>
