<template>
  <div class="pie-chart">
    <div class="pie-title">{{ product }}</div>
    <svg ref="svg" :width="width" :height="height">
      <foreignObject v-if="totalContributions > 0" :x="width / 2 - 70" :y="height / 2 - 40" :width="140" :height="80"
        class="center-label-fo" style="pointer-events: none;">
        <div class="center-label">
          <template v-if="contributionsByFilteredAuthors === totalContributions">
            {{ totalContributions }}
          </template>
          <template v-else>
            {{ contributionsByFilteredAuthors }} / {{ totalContributions }}
          </template>
        </div>
      </foreignObject>
    </svg>
    <div v-if="tooltip.show" class="pie-tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
      <b>{{ tooltip.author }}</b><br />
      <!-- Contributions: {{ tooltip.count }}<br /> -->
      Percentage (all authors): {{ tooltip.percent }}%<br />
      <div v-if="tooltip.percentFiltered != tooltip.percent">Percentage (filtered authors): {{ tooltip.percentFiltered
        }}%
      </div>
    </div>
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
</template>

<script setup>
import { ref, watch, onMounted, computed, nextTick } from 'vue';
import * as d3 from 'd3';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';

const props = defineProps({
  product: String
});

const { filteredData, authorColors, filters, data } = storeToRefs(useOwnershipStore());
const width = 320, height = 300;
const svg = ref();

const tooltip = ref({ show: false, x: 0, y: 0, author: '', count: 0, percent: 0, percentFiltered: 0 });

// Get the total number of authors after applying author selection filter
const filteredAuthorCount = computed(() => {
  let data = filteredData.value.filter(r => r.Product === props.product);
  data = getFilteredAuthors(data, filters.value.authors);
  return new Set(data.map(r => r.Author)).size;
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
  let data = filteredData.value.filter(r => r.Product === props.product);
  data = getFilteredAuthors(data, filters.value.authors);

  // Calculate total first to determine percentages
  const { byAuthor, total: totalBeforeMinPercent } = aggregateByAuthor(data);

  // Filter authors by minimum percentage
  const minPercent = filters.value.minPercent;
  const significantAuthors = Object.entries(byAuthor)
    .filter(([_, count]) => (count / totalBeforeMinPercent) * 100 >= minPercent)
    .map(([_, count]) => count);

  return significantAuthors.reduce((sum, count) => sum + count, 0);
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
  const arc = d3.arc().innerRadius(85).outerRadius(120);

  d3.select(svg.value).selectAll('g').remove();
  const g = d3.select(svg.value).append('g').attr('transform', `translate(${width / 2},${height / 2})`);
  g.selectAll('path')
    .data(pie)
    .join('path')
    .attr('d', arc)
    .attr('fill', d => authorColors.value[d.data.Author] || '#ccc')
    .on('mousemove', function (event, d) {
      const [mx, my] = d3.pointer(event, svg.value);
      tooltip.value = {
        show: true,
        x: mx + 20,
        y: my,
        author: d.data.Author,
        count: d.data.value,
        percent: unfilteredTotal.value ? ((d.data.value / unfilteredTotal.value * 100).toFixed(1)) : 0,
        percentFiltered: total ? ((d.data.value / total * 100).toFixed(1)) : 0
      };
    })
    .on('mouseleave', () => {
      tooltip.value.show = false;
    });
}

onMounted(() => { nextTick(draw); });
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
.pie-chart {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 1em;
  position: relative;
}

.pie-title {
  font-weight: bold;
  margin-bottom: 0.5em;
}

svg {
  width: 100%;
  height: 300px;
}

.center-label-fo {
  pointer-events: none;
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
}

.pie-tooltip {
  position: absolute;
  pointer-events: none;
  background: #fff;
  color: #222;
  border: 1.5px solid #bbb;
  border-radius: 6px;
  box-shadow: 0 2px 8px #0002;
  padding: 0.5em 1em;
  font-size: 1em;
  z-index: 10;
  min-width: 140px;
  white-space: nowrap;
}

.filtered-out-info {
  color: #6c757d;
  font-size: 0.9em;
  margin-top: 0.5em;
  font-style: italic;
}
</style>
