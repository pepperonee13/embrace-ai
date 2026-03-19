<template>
  <div class="pie-chart">
    <!-- Timeline button - Top-right corner (hover only) -->
    <button @click="showTimeline" class="timeline-btn-hover" title="Show timeline for this author">
      📈
    </button>

    <!-- Centered title -->
    <div class="pie-title">
      <span class="author-name" :title="author">{{ author }}</span>
    </div>
    <svg ref="svg" :viewBox="`0 0 ${width} ${height}`" preserveAspectRatio="xMidYMid meet">
      <foreignObject
        v-if="totalProductCount > 0"
        :x="width/2 - 70"
        :y="height/2 - 40"
        :width="140"
        :height="80"
        class="center-label-fo"
        style="pointer-events: auto;"
      >
        <div class="center-label" :title="centerLabelTooltip">
          <template v-if="productCount === totalProductCount">
            {{ totalProductCount }}
          </template>
          <template v-else>
            {{ productCount }} / {{ totalProductCount }}
          </template>
        </div>
      </foreignObject>
    </svg>

    <!-- Teleport tooltip to body to escape card stacking context -->
    <teleport to="body">
      <div v-if="tooltip.show" class="pie-tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
        <b>{{ tooltip.product }}</b><br />
        <!-- Contributions: {{ tooltip.count }}<br /> -->
        Percentage: {{ tooltip.percent }}%
      </div>
    </teleport>

    <div v-if="filteredOutProductsCount > 0" class="filtered-out-info">
      <template v-if="filteredOutProductsCount === filteredProductCount">
        All products below {{ filters.minPercent }}% threshold
      </template>
      <template v-else>
        {{ filteredOutProductsCount }} product{{ filteredOutProductsCount !== 1 ? 's' : '' }} below {{ filters.minPercent }}% threshold
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
  author: String
});

const emit = defineEmits(['productClick', 'showTimeline']);

const { filteredData, authorColors, filters, data, productTeamMap, teamColors } = storeToRefs(useOwnershipStore());
const width = 360, height = 340;
const svg = ref();

const tooltip = ref({ show: false, x: 0, y: 0, product: '', count: 0, percent: 0 });

// Get the total number of products after applying product selection filter
const filteredProductCount = computed(() => {
  let dataFiltered = filteredData.value.filter(r => r.Author === props.author);
  dataFiltered = getFilteredProducts(dataFiltered, filters.value.products);
  return new Set(dataFiltered.map(r => r.Product)).size;
});

const filteredOutProductsCount = computed(() => {
  let dataFiltered = filteredData.value.filter(r => r.Author === props.author);
  dataFiltered = getFilteredProducts(dataFiltered, filters.value.products);

  // Calculate total contributions per product
  const productTotals = {};
  const authorContributions = {};
  
  filteredData.value.forEach(r => {
    if (!productTotals[r.Product]) productTotals[r.Product] = 0;
    productTotals[r.Product] += r.ContributionCount;
  });

  dataFiltered.forEach(r => {
    if (!authorContributions[r.Product]) authorContributions[r.Product] = 0;
    authorContributions[r.Product] += r.ContributionCount;
  });

  // Count products below threshold
  const minPercent = filters.value.minPercent;
  return Object.entries(authorContributions)
    .filter(([product, count]) => {
      const percentage = (count / productTotals[product]) * 100;
      return percentage < minPercent;
    }).length;
});

function getFilteredProducts(data, selectedProducts) {
  // If no products selected, show all
  if (!selectedProducts.length) return data;
  return data.filter(r => selectedProducts.includes(r.Product));
}

const totalProductCount = computed(() => {
  // All products this author has contributed to (unfiltered)
  const all = data.value.filter(r => r.Author === props.author);
  return new Set(all.map(r => r.Product)).size;
});

const productCount = computed(() => {
  let dataFiltered = filteredData.value.filter(r => r.Author === props.author);
  dataFiltered = getFilteredProducts(dataFiltered, filters.value.products);

  // Calculate contributions and percentages per product
  const productTotals = {};
  const authorContributions = {};
  
  // Get total contributions for each product
  filteredData.value.forEach(r => {
    if (!productTotals[r.Product]) productTotals[r.Product] = 0;
    productTotals[r.Product] += r.ContributionCount;
  });

  // Get author's contributions for each product
  dataFiltered.forEach(r => {
    if (!authorContributions[r.Product]) authorContributions[r.Product] = 0;
    authorContributions[r.Product] += r.ContributionCount;
  });

  // Filter products where author meets minimum percentage
  const minPercent = filters.value.minPercent;
  const significantProducts = Object.entries(authorContributions)
    .filter(([product, count]) => {
      const percentage = (count / productTotals[product]) * 100;
      return percentage >= minPercent;
    });

  return significantProducts.length;
});

const centerLabelTooltip = computed(() => {
  if (productCount.value === totalProductCount.value) {
    return "Number of products this author has contributed to";
  } else {
    return "Filtered products / Total products (some products or contributions filtered out)";
  }
});

function draw() {
  let data = filteredData.value.filter(r => r.Author === props.author);
  data = getFilteredProducts(data, filters.value.products);
  
  // Calculate total contributions per product (from all authors) to determine percentages
  const productTotals = {};
  filteredData.value.forEach(r => {
    if (!productTotals[r.Product]) productTotals[r.Product] = 0;
    productTotals[r.Product] += r.ContributionCount;
  });

  // Aggregate author's contributions by product
  const byProduct = {};
  let total = 0;
  data.forEach(r => {
    if (!byProduct[r.Product]) byProduct[r.Product] = 0;
    byProduct[r.Product] += r.ContributionCount;
  });

  // Filter products where author meets minimum percentage
  const minPercent = filters.value.minPercent;
  const filteredByProduct = Object.entries(byProduct)
    .filter(([product, count]) => {
      const percentage = (count / productTotals[product]) * 100;
      return percentage >= minPercent;
    })
    .reduce((acc, [product, count]) => {
      acc[product] = count;
      total += count;
      return acc;
    }, {});

  const pieData = Object.entries(filteredByProduct).map(([Product, cnt]) => ({ Product, value: cnt }));
  const pie = d3.pie().value(d => d.value)(pieData);
  // Make the donut thinner (same as PieChart: innerRadius 100, outerRadius 150)
  const arc = d3.arc().innerRadius(100).outerRadius(150);

  d3.select(svg.value).selectAll('g').remove();

  // Add mouseleave to SVG to hide tooltip when leaving the chart
  d3.select(svg.value)
    .on('mouseleave', () => {
      tooltip.value.show = false;
    });

  const g = d3.select(svg.value).append('g').attr('transform',`translate(${width/2},${height/2})`);
  g.selectAll('path')
    .data(pie)
    .join('path')
    .attr('d', arc)
    .attr('fill', d => {
      // Get the team for this product
      const team = productTeamMap.value[d.data.Product];
      // Use team color if available, otherwise fallback to gray
      return team && teamColors.value[team] ? teamColors.value[team] : '#ccc';
    })
    .attr('stroke', d => '#fff')
    .attr('stroke-width', 2)
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
    .on('mousemove', function(event, d) {
      // Use clientX/Y for viewport coordinates (works with scrolling)
      tooltip.value = {
        show: true,
        x: event.clientX + 15,
        y: event.clientY - 10,
        product: d.data.Product,
        count: d.data.value,
        percent: total ? ((d.data.value / total * 100).toFixed(1)) : 0
      };
    })
    .on('click', function(event, d) {
      emit('productClick', d.data.Product);
    });
}

function showTimeline() {
  emit('showTimeline', props.author);
}

onMounted(draw);
watch(
  [
    filteredData, 
    () => props.author, 
    authorColors, 
    () => filters.value.products,
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

.author-name {
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
  font-size: 2.6em;
  font-weight: 700;
  color: #111;
  opacity: 1;
  text-align: center;
  user-select: none;
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
</style>
