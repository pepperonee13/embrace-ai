<template>
  <div class="contributor-list-card">
    <!-- Flip back button - Top-left corner (matching front) -->
    <button class="flip-back-btn" @click="$emit('flipBack')" title="Back to chart view" aria-label="Flip back">
      🔄
    </button>

    <!-- Timeline button - Top-right corner (matching front) -->
    <button @click="openTimeline" class="timeline-btn" title="Show timeline for this product" aria-label="Show timeline">
      📈
    </button>

    <!-- VCS Badge - Bottom-right corner (matching front) -->
    <div class="vcs-badge-corner">
      <span :class="vcsBadgeClass">{{ vcsLabel }}</span>
      <span v-if="riskBadge" :class="riskBadge.class" :title="riskBadge.tooltip">{{ riskBadge.icon }}</span>
    </div>

    <!-- Title - Centered (matching front) -->
    <div class="pie-title">
      <span class="product-name" :title="product">{{ product }}</span>
    </div>

    <!-- Contributors List -->
    <div class="contributors-section">
      <div class="section-title">Top Contributors</div>
      <div v-if="topContributors.length" class="contributor-rows">
        <div v-for="contributor in topContributors" :key="contributor.author" class="contributor-row">
          <div class="contributor-info">
            <span class="author-swatch" :style="{ background: contributor.color }"></span>
            <button class="author-name" @click="filterToAuthor(contributor.author)" :title="`Filter to ${contributor.author}`">
              {{ contributor.author }}
            </button>
          </div>
          <div class="contributor-stats">
            <span class="contrib-count">{{ contributor.count }}</span>
            <span class="contrib-percent">({{ contributor.percent }}%)</span>
          </div>
        </div>
      </div>
      <div v-else class="no-contributors">
        No contributors match current filters
      </div>
    </div>

    <!-- Summary Footer -->
    <div class="card-footer">
      <div class="summary-stats">
        <span class="stat-item">{{ totalContributors }} total contributors</span>
        <span class="stat-separator">•</span>
        <span class="stat-item">{{ totalContributions }} contributions</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';

const props = defineProps({
  product: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['flipBack']);

const store = useOwnershipStore();
const router = useRouter();
const { filteredData, filters, data: allData, productVcsMap, authorColors } = storeToRefs(store);

const TOP_N = 5;

// VCS type logic
function vcsType() {
  return (productVcsMap.value && productVcsMap.value[props.product]) ? productVcsMap.value[props.product] : 'git';
}

const vcsLabel = computed(() => {
  const src = vcsType();
  if (src === 'tfs') return 'TFS';
  if (src === 'git') return 'Git';
  return 'Unknown';
});

const vcsBadgeClass = computed(() => {
  const src = vcsType();
  if (src === 'tfs') return 'vcs-badge tfs';
  if (src === 'git') return 'vcs-badge git';
  return 'vcs-badge unknown';
});

// Contributors data
const contributorsData = computed(() => {
  let rows = (filteredData.value || []).filter(r => r.Product === props.product);
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
      percent: total ? Number((info.count / total * 100).toFixed(1)) : 0,
      color: (authorColors.value && authorColors.value[author]) ? authorColors.value[author] : '#ccc'
    }))
    .filter(item => item.percent >= minPercent)
    .sort((a, b) => b.count - a.count);

  return { contributors: arr, total };
});

const topContributors = computed(() => {
  return contributorsData.value.contributors.slice(0, TOP_N);
});

const totalContributors = computed(() => {
  const authors = new Set((allData.value || []).filter(r => r.Product === props.product).map(r => r.Author));
  return authors.size;
});

const totalContributions = computed(() => {
  return contributorsData.value.total;
});

// Risk indicator
const riskBadge = computed(() => {
  const contributors = contributorsData.value.contributors;
  if (contributors.length === 0) return null;

  if (contributors.length === 1) {
    return { icon: '🔴', class: 'risk-badge critical', tooltip: 'Single contributor - Bus factor = 1' };
  }

  if (contributors.length > 0 && contributors[0].percent >= 70) {
    return { icon: '⚠️', class: 'risk-badge warning', tooltip: 'Highly concentrated knowledge' };
  }

  return null;
});

// Actions
function filterToAuthor(author) {
  store.setAuthors([author]);
  store.setChartMode('author');
}

function openTimeline() {
  router.push({ name: 'Timeline', query: { product: props.product } });
}
</script>

<style scoped>
.contributor-list-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  margin-bottom: 1em;
  position: relative;
  background: white;
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
}

/* Flip back button - Top-left corner (matching front) */
.flip-back-btn {
  @apply absolute top-0 left-3 z-10
         bg-gradient-to-r from-brand-teal to-brand-blue text-white rounded-full w-8 h-8
         flex items-center justify-center text-base cursor-pointer
         transition-all duration-200 shadow-md
         hover:scale-110 hover:shadow-lg;
}

.flip-back-btn:active {
  @apply scale-95;
}

/* VCS Badge - Bottom-right corner (matching front) */
.vcs-badge-corner {
  @apply absolute bottom-16 right-3 z-10;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

/* Timeline button - Top-right corner (matching front) */
.timeline-btn {
  @apply absolute top-0 right-3 z-10
         bg-brand-blue text-white rounded-full w-8 h-8
         flex items-center justify-center text-base cursor-pointer
         transition-all duration-200 shadow-md
         hover:bg-brand-blue-dark hover:scale-110 hover:shadow-lg;
}

.timeline-btn:active {
  @apply scale-95;
}

/* Centered title (matching front) */
.pie-title {
  @apply font-bold text-xl text-brand-gray mb-3;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  min-width: 0;
}

.product-name {
  @apply truncate;
  max-width: 90%;
  text-align: center;
}

.vcs-badge {
  display: inline-block;
  padding: 0.15rem 0.5rem;
  font-size: 0.7rem;
  font-weight: 600;
  border-radius: 0.35rem;
  color: #fff;
  text-transform: uppercase;
}

.vcs-badge.tfs { background: var(--vcs-tfs, #ff7f0e); }
.vcs-badge.git { background: var(--vcs-git, #1f77b4); }
.vcs-badge.unknown { background: var(--vcs-unknown, #6c757d); }

.risk-badge {
  display: inline-flex;
  align-items: center;
  font-size: 1rem;
  cursor: help;
}

.risk-badge.critical { filter: drop-shadow(0 0 2px rgba(239, 68, 68, 0.5)); }
.risk-badge.warning { filter: drop-shadow(0 0 2px rgba(251, 191, 36, 0.5)); }

/* Contributors Section */
.contributors-section {
  width: 100%;
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding: 0 1rem;
}

.section-title {
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  color: #6b7280;
  margin-bottom: 0.75rem;
  letter-spacing: 0.05em;
  text-align: center;
}

.contributor-rows {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  overflow-y: auto;
}

.contributor-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 0.75rem;
  background: #f9fafb;
  border-radius: 0.5rem;
  transition: all 0.2s ease;
}

.contributor-row:hover {
  background: #f3f4f6;
  transform: translateX(2px);
}

.contributor-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  min-width: 0;
}

.author-swatch {
  width: 12px;
  height: 12px;
  border-radius: 2px;
  flex-shrink: 0;
  border: 1px solid rgba(0, 0, 0, 0.1);
}

.author-name {
  background: none;
  border: none;
  color: #1f77b4;
  cursor: pointer;
  padding: 0;
  font: inherit;
  text-align: left;
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  transition: color 0.2s ease;
}

.author-name:hover {
  color: #0d5a91;
  text-decoration: underline;
}

.contributor-stats {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  flex-shrink: 0;
}

.contrib-count {
  font-weight: 600;
  color: #374151;
}

.contrib-percent {
  font-size: 0.875rem;
  color: #6b7280;
}

.no-contributors {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  color: #9ca3af;
  font-style: italic;
}

/* Footer */
.card-footer {
  width: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 0.75rem 1rem 0.5rem 1rem;
  border-top: 1px solid #e5e7eb;
}

.summary-stats {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
  color: #6b7280;
  flex-wrap: wrap;
  justify-content: center;
}

.stat-item {
  white-space: nowrap;
}

.stat-separator {
  color: #d1d5db;
}
</style>
