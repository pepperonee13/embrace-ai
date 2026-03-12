<template>
  <div class="flip-card" :class="{ 'is-flipped': isFlipped }">
    <div class="flip-card-inner">
      <!-- FRONT: Pie Chart -->
      <div class="flip-card-front">
        <div class="pie-chart">
          <!-- Flip button - Top-left corner -->
          <button @click="flipCard" class="flip-btn" title="Show contributor details" aria-label="Flip to details">
            🔄
          </button>

          <!-- VCS Badge - Bottom-right corner -->
          <div class="vcs-badge-corner">
            <span :class="vcsBadgeClass" :title="vcsSource ? ('Version control: ' + vcsLabel) : 'Version control: Unknown'">
              {{ vcsLabel }}
            </span>
          </div>

          <!-- Timeline button - Top-right corner (hover only) -->
          <button @click="showTimeline" class="timeline-btn-hover" title="Show timeline for this product">
            📈
          </button>

          <!-- Centered title -->
          <div class="pie-title">
            <span class="product-name" :title="product">{{ product }}</span>
          </div>
          <svg ref="svg" :viewBox="`0 0 ${width} ${height}`" preserveAspectRatio="xMidYMid meet">
            <foreignObject v-if="totalContributions > 0" :x="width / 2 - 70" :y="height / 2 - 40" :width="140" :height="80"
              class="center-label-fo" style="pointer-events: auto;">
              <div class="center-label" :title="centerLabelTooltip">
                <template v-if="contributionsByFilteredAuthors === totalContributions">
                  {{ totalContributions }}
                </template>
                <template v-else>
                  {{ contributionsByFilteredAuthors }} / {{ totalContributions }}
                </template>
              </div>
            </foreignObject>
          </svg>

          <!-- Teleport tooltip to body to escape card stacking context -->
          <teleport to="body">
            <div v-if="tooltip.show" class="pie-tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
              <b>{{ tooltip.author }}</b><br />
              <!-- Contributions: {{ tooltip.count }}<br /> -->
              Percentage (all authors): {{ tooltip.percent }}%<br />
              <div v-if="tooltip.percentFiltered != tooltip.percent">Percentage (filtered authors): {{ tooltip.percentFiltered
                }}%
              </div>
            </div>
          </teleport>

          <div v-if="filteredOutAuthorsCount > 0" class="filtered-out-info">
            <template v-if="filteredOutAuthorsCount === filteredAuthorCount">
              All authors below {{ filters.minPercent }}% threshold
            </template>
            <template v-else>
              {{ filteredOutAuthorsCount }} author{{ filteredOutAuthorsCount !== 1 ? 's' : '' }} below {{ filters.minPercent
              }}% threshold
            </template>
          </div>
        </div>
      </div>

      <!-- BACK: Contributor List -->
      <div class="flip-card-back">
        <ProductContributorList :product="product" @flipBack="flipCard" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, computed, nextTick } from 'vue';
import * as d3 from 'd3';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';
import ProductContributorList from './ProductContributorList.vue';

const props = defineProps({
  product: String
});

const emit = defineEmits(['authorClick', 'showTimeline']);

const { filteredData, authorColors, filters, data, productFilteredContributions, productVcsMap } = storeToRefs(useOwnershipStore());
const width = 360, height = 340;
const svg = ref();

const tooltip = ref({ show: false, x: 0, y: 0, author: '', count: 0, percent: 0, percentFiltered: 0 });
const isFlipped = ref(false);

function flipCard() {
  isFlipped.value = !isFlipped.value;
  // Hide tooltip when flipping
  tooltip.value.show = false;
}

// Get the total number of authors after applying author selection filter
const filteredAuthorCount = computed(() => {
  let data = filteredData.value.filter(r => r.Product === props.product);
  data = getFilteredAuthors(data, filters.value.authors);
  return new Set(data.map(r => r.Author)).size;
});

// Determine version control source for this product using the store-provided mapping
const vcsSource = computed(() => {
  return productVcsMap.value ? productVcsMap.value[props.product] || null : null;
});

const vcsLabel = computed(() => {
  if (vcsSource.value === 'tfs') return 'TFS';
  if (vcsSource.value === 'git') return 'Git';
  return 'Unknown';
});

const vcsBadgeClass = computed(() => {
  if (vcsSource.value === 'tfs') return 'vcs-badge tfs';
  if (vcsSource.value === 'git') return 'vcs-badge git';
  return 'vcs-badge unknown';
});

function getFilteredAuthors(data, selectedAuthors) {
  // If no authors selected, show all
  if (!selectedAuthors.length) return data;
  return data.filter(r => selectedAuthors.includes(r.Author));
}

const totalContributions = computed(() => {
  return data.value
    .filter(r => r.Product === props.product)
    .reduce((sum, r) => sum + r.ContributionCount, 0);
});

// Unfiltered total for percent calculation
const unfilteredTotal = computed(() => {
  return data.value
    .filter(r => r.Product === props.product)
    .reduce((sum, r) => sum + r.ContributionCount, 0);
});

// Helper function to aggregate contributions by author
function aggregateByAuthor(data) {
  const byAuthor = {};
  let total = 0;
  data.forEach(r => {
    if (!byAuthor[r.Author]) byAuthor[r.Author] = 0;
    byAuthor[r.Author] += r.ContributionCount;
    total += r.ContributionCount;
  });
  return { byAuthor, total };
}

const filteredOutAuthorsCount = computed(() => {
  let data = filteredData.value.filter(r => r.Product === props.product);
  data = getFilteredAuthors(data, filters.value.authors);

  const { byAuthor, total } = aggregateByAuthor(data);
  const minPercent = filters.value.minPercent;

  // Count authors below threshold
  return Object.entries(byAuthor).filter(([_, count]) =>
    (count / total) * 100 < minPercent
  ).length;
});

const contributionsByFilteredAuthors = computed(() => {
  return (productFilteredContributions.value || {})[props.product] || 0;
});

const centerLabelTooltip = computed(() => {
  if (contributionsByFilteredAuthors.value === totalContributions.value) {
    return "Total number of contributions";
  } else {
    return "Filtered contributions / Total contributions (some authors or contributions filtered out)";
  }
});

function draw() {
  let data = filteredData.value.filter(r => r.Product === props.product);
  data = getFilteredAuthors(data, filters.value.authors);
  // Aggregate by author
  const byAuthor = {};
  let total = 0;
  data.forEach(r => {
    if (!byAuthor[r.Author]) byAuthor[r.Author] = 0;
    byAuthor[r.Author] += r.ContributionCount;
    total += r.ContributionCount;
  });

  // Filter out authors below minimum percentage
  const minPercent = filters.value.minPercent;
  const filteredByAuthor = Object.fromEntries(
    Object.entries(byAuthor).filter(([_, count]) => {
      const percentage = (count / total) * 100;
      return percentage >= minPercent;
    })
  );

  // Recalculate total after filtering
  total = Object.values(filteredByAuthor).reduce((sum, count) => sum + count, 0);
  const pieData = Object.entries(filteredByAuthor).map(([Author, cnt]) => ({ Author, value: cnt }));
  // Make the chart thinner by increasing innerRadius
  const pie = d3.pie().value(d => d.value)(pieData);
  const arc = d3.arc().innerRadius(100).outerRadius(150);

  d3.select(svg.value).selectAll('g').remove();

  // Add mouseleave to SVG to hide tooltip when leaving the chart
  d3.select(svg.value)
    .on('mouseleave', () => {
      tooltip.value.show = false;
    });

  const g = d3.select(svg.value).append('g').attr('transform', `translate(${width / 2},${height / 2})`);
  g.selectAll('path')
    .data(pie)
    .join('path')
    .attr('d', arc)
    .attr('fill', d => authorColors.value[d.data.Author] || '#ccc')
    .style('cursor', 'pointer')
    .style('transition', 'all 0.2s ease')
    .on('mouseenter', function(event, d) {
      d3.select(this)
        .style('opacity', 0.8)
        .style('filter', 'brightness(1.1)');
    })
    .on('mouseleave', function() {
      d3.select(this)
        .style('opacity', 1)
        .style('filter', 'brightness(1)');
    })
    .on('mousemove', function (event, d) {
      // Use clientX/Y for viewport coordinates (works with scrolling)
      tooltip.value = {
        show: true,
        x: event.clientX + 15,
        y: event.clientY - 10,
        author: d.data.Author,
        count: d.data.value,
        percent: unfilteredTotal.value ? ((d.data.value / unfilteredTotal.value * 100).toFixed(1)) : 0,
        percentFiltered: total ? ((d.data.value / total * 100).toFixed(1)) : 0
      };
    })
    .on('click', function (event, d) {
      emit('authorClick', d.data.Author);
    });
}

onMounted(() => { nextTick(draw); });
function showTimeline() {
  emit('showTimeline', props.product);
}

watch(
  [
    filteredData,
    () => props.product,
    authorColors,
    () => filters.value.authors,
    () => filters.value.minPercent
  ],
  () => nextTick(draw)
);
</script>

<style scoped>
/* Flip Card Container */
.flip-card {
  perspective: 1000px;
  width: 100%;
  height: 100%;
  min-height: 440px;
}

.flip-card-inner {
  position: relative;
  width: 100%;
  height: 100%;
  transition: transform 0.6s;
  transform-style: preserve-3d;
}

.flip-card.is-flipped .flip-card-inner {
  transform: rotateY(180deg);
}

.flip-card-front,
.flip-card-back {
  position: absolute;
  width: 100%;
  height: 100%;
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
}

.flip-card-front {
  z-index: 2;
}

.flip-card-back {
  transform: rotateY(180deg);
}

/* Flip button - Top-left corner */
.flip-btn {
  @apply absolute top-0 left-3 z-10
         bg-gradient-to-r from-brand-teal to-brand-blue text-white rounded-full w-8 h-8
         flex items-center justify-center text-base cursor-pointer
         transition-all duration-200 shadow-md
         hover:scale-110 hover:shadow-lg;
}

.flip-btn:active {
  @apply scale-95;
}

.pie-chart {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 1em;
  position: relative;
  height: 100%;
}

/* VCS Badge - Bottom-right corner */
.vcs-badge-corner {
  @apply absolute bottom-16 right-3 z-10;
}

/* Timeline button - Top-right corner, same row as title (hover only) */
.timeline-btn-hover {
  @apply absolute top-0 right-3 z-10
         bg-brand-blue text-white rounded-full w-8 h-8
         flex items-center justify-center text-base cursor-pointer
         transition-all duration-200 shadow-md
         hover:bg-brand-blue-dark hover:scale-110 hover:shadow-lg
         opacity-0 pointer-events-none;
}

.pie-chart:hover .timeline-btn-hover {
  @apply opacity-100 pointer-events-auto;
  animation: fadeInScale 0.2s ease-out;
}

@keyframes fadeInScale {
  from {
    opacity: 0;
    transform: scale(0.8);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.timeline-btn-hover:active {
  @apply scale-95;
}

/* Centered title */
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

svg {
  display: block;
  margin: 0 auto;
  max-width: 100%;
  height: 340px;
  width: auto;
}

.center-label-fo {
  pointer-events: auto;
}

.center-label {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: clamp(1.2em, 5vw, 2.6em);
  /* Responsive font size */
  font-weight: 700;
  color: #111;
  opacity: 1;
  text-align: center;
  user-select: none;
  overflow: hidden;
  text-overflow: ellipsis;
  line-height: 1.1;
  word-break: break-word;
  max-width: 100%;
  max-height: 100%;
  cursor: help;
}

.pie-tooltip {
  @apply fixed pointer-events-none bg-white rounded-xl shadow-2xl border-2
         px-4 py-3 text-sm font-medium;
  border-color: var(--brand-blue);
  z-index: 9999;
  min-width: 160px;
  backdrop-filter: blur(8px);
  animation: tooltipFadeIn 0.2s ease-out;
}

@keyframes tooltipFadeIn {
  from {
    opacity: 0;
    transform: translateY(-5px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.pie-tooltip b {
  @apply text-brand-blue text-base block mb-2;
}

.filtered-out-info {
  @apply bg-yellow-50 border-2 border-yellow-200 text-yellow-800 rounded-lg
         px-3 py-2 text-xs font-medium mt-3;
}

.vcs-badge {
  @apply inline-flex items-center px-2 py-1 text-xs font-bold rounded-md
         text-white uppercase tracking-wide shadow-md;
}
.vcs-badge.tfs {
  background: var(--vcs-tfs);
  box-shadow: 0 2px 6px rgba(240, 130, 35, 0.4);
}
.vcs-badge.git {
  background: var(--vcs-git);
  box-shadow: 0 2px 6px rgba(8, 143, 155, 0.4);
}
.vcs-badge.unknown {
  background: var(--vcs-unknown);
  box-shadow: 0 2px 6px rgba(108, 117, 125, 0.4);
}
</style>
