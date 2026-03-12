<template>
  <div class="product-detail">
    <header class="detail-header">
      <button class="back-btn" @click="router.back()">← Back</button>
      <div class="header-info">
        <h1 class="product-title">{{ name }}</h1>
        <div class="header-meta">
          <span v-if="team" class="team-badge">{{ team }}</span>
          <span :class="vcsBadgeClass">{{ vcsLabel }}</span>
          <span class="contrib-summary">
            {{ filteredTotal }} / {{ grandTotal }} contributions (filtered / total)
          </span>
        </div>
      </div>
    </header>

    <div class="table-container">
      <table class="contributors-table" v-if="contributors.length">
        <thead>
          <tr>
            <th>Author</th>
            <th>Contributions</th>
            <th>%</th>
            <th>Files</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in contributors" :key="c.author">
            <td class="author-cell">
              <span class="author-swatch" :style="{ background: authorColors && authorColors[c.author] ? authorColors[c.author] : '#ccc' }"></span>
              {{ c.author }}
            </td>
            <td>{{ c.count }}</td>
            <td>{{ c.percent }}%</td>
            <td>{{ c.files }}</td>
          </tr>
        </tbody>
      </table>
      <div v-else class="no-data">No contributors match current filters.</div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';

const props = defineProps({
  name: {
    type: String,
    required: true
  }
});

const router = useRouter();
const store = useOwnershipStore();
const { filteredData, filters, data: allData, productVcsMap, productTeamMap, authorColors, productTotals, productFilteredContributions } = storeToRefs(store);

const team = computed(() => productTeamMap.value?.[props.name] ?? '');

const vcsType = computed(() => productVcsMap.value?.[props.name] ?? 'git');

const vcsLabel = computed(() => {
  if (vcsType.value === 'tfs') return 'TFS';
  if (vcsType.value === 'git') return 'Git';
  return 'Unknown';
});

const vcsBadgeClass = computed(() => {
  if (vcsType.value === 'tfs') return 'vcs-badge tfs';
  if (vcsType.value === 'git') return 'vcs-badge git';
  return 'vcs-badge unknown';
});

const filteredTotal = computed(() => productFilteredContributions.value?.[props.name] ?? 0);
const grandTotal = computed(() => productTotals.value?.[props.name] ?? 0);

const contributors = computed(() => {
  const rows = (filteredData.value || []).filter(r => r.Product === props.name);
  const byAuthor = {};
  let total = 0;
  rows.forEach(r => {
    if (!byAuthor[r.Author]) byAuthor[r.Author] = { count: 0, files: 0 };
    byAuthor[r.Author].count += r.ContributionCount || 0;
    byAuthor[r.Author].files += r.FileCount || 0;
    total += r.ContributionCount || 0;
  });
  const minPercent = filters.value?.minPercent ?? 0;
  return Object.entries(byAuthor)
    .map(([author, info]) => ({
      author,
      count: info.count,
      files: info.files,
      percent: total ? Number((info.count / total * 100).toFixed(1)) : 0
    }))
    .filter(item => item.percent >= minPercent)
    .sort((a, b) => b.count - a.count);
});
</script>

<style scoped>
.product-detail {
  max-width: 960px;
  margin: 2rem auto;
  padding: 0 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.detail-header {
  display: flex;
  align-items: flex-start;
  gap: 1.5rem;
  background: linear-gradient(90deg, #1f77b4, #2e9fc5);
  color: #fff;
  border-radius: 10px;
  padding: 1.5rem;
}

.back-btn {
  background: rgba(255,255,255,0.15);
  border: 1px solid rgba(255,255,255,0.4);
  color: #fff;
  padding: 0.4em 1em;
  border-radius: 6px;
  cursor: pointer;
  white-space: nowrap;
  font-size: 0.95em;
}
.back-btn:hover {
  background: rgba(255,255,255,0.25);
}

.header-info {
  flex: 1;
}

.product-title {
  margin: 0 0 0.4rem;
  font-size: 1.6rem;
  font-weight: 700;
}

.header-meta {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  font-size: 0.9rem;
}

.team-badge {
  background: rgba(255,255,255,0.2);
  border-radius: 0.35rem;
  padding: 0.15rem 0.5rem;
  font-weight: 600;
}

.contrib-summary {
  opacity: 0.9;
}

.table-container {
  background: #fff;
  border-radius: 10px;
  box-shadow: 0 2px 8px #0001;
  padding: 1.2rem;
}

.contributors-table {
  width: 100%;
  border-collapse: collapse;
}

.contributors-table th,
.contributors-table td {
  border: 1px solid #d0d7de;
  padding: 0.6em 1em;
  text-align: left;
}

.contributors-table th {
  background: #f0f6ff;
  color: #1f77b4;
  font-weight: 600;
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
  flex-shrink: 0;
}

.no-data {
  color: #6c757d;
  padding: 1rem 0;
}

.vcs-badge {
  display: inline-block;
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
