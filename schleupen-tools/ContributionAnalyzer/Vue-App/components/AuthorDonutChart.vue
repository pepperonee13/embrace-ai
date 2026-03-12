<template>
  <div class="pie-chart">
    <div class="pie-title">{{ author }}</div>
    <svg ref="svg" :width="width" :height="height">
      <foreignObject
        v-if="totalProductCount > 0"
        :x="width/2 - 70"
        :y="height/2 - 40"
        :width="140"
        :height="80"
        class="center-label-fo"
        style="pointer-events: none;"
      >
        <div class="center-label">
          <template v-if="productCount === totalProductCount">
            {{ totalProductCount }}
          </template>
          <template v-else>
            {{ productCount }} / {{ totalProductCount }}
          </template>
        </div>
      </foreignObject>
    </svg>
    <div v-if="tooltip.show" class="pie-tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
      <b>{{ tooltip.product }}</b><br />
      <!-- Contributions: {{ tooltip.count }}<br /> -->
      Percentage: {{ tooltip.percent }}%
    </div>
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

const { filteredData, authorColors, filters, data } = storeToRefs(useOwnershipStore());
const width = 320, height = 300;
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
  // Make the donut thinner (same as PieChart: innerRadius 85, outerRadius 120)
  const arc = d3.arc().innerRadius(85).outerRadius(120);

  d3.select(svg.value).selectAll('g').remove();
  const g = d3.select(svg.value).append('g').attr('transform',`translate(${width/2},${height/2})`);
  g.selectAll('path')
    .data(pie)
    .join('path')
    .attr('d', arc)
    .attr('fill', d => authorColors.value[props.author] || '#ccc')
    .attr('stroke', d => '#fff')
    .attr('stroke-width', 2)
    .on('mousemove', function(event, d) {
      const [mx, my] = d3.pointer(event, svg.value);
      tooltip.value = {
        show: true,
        x: mx + 20,
        y: my,
        product: d.data.Product,
        count: d.data.value,
        percent: total ? ((d.data.value / total * 100).toFixed(1)) : 0
      };
    })
    .on('mouseleave', () => {
      tooltip.value.show = false;
    });
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
  font-size: 2.6em;
  font-weight: 700;
  color: #111;
  opacity: 1;
  text-align: center;
  user-select: none;
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
