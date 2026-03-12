<template>
  <div class="chart-container">
    <svg ref="svgRef"></svg>
    <div v-if="tooltip.show" class="tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
      <b><span :style="{ color: authorColors[tooltip.author] || '#1f77b4' }">{{ tooltip.author }}</span></b><br/>
      Products: {{ tooltip.products }} (Z: {{ tooltip.zProduct }})<br/>
      Total Contributions: {{ tooltip.contributions }} (Z: {{ tooltip.zContrib }})
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, reactive, computed, watch } from 'vue';
import { storeToRefs } from 'pinia';
import * as d3 from 'd3';
import { useOwnershipStore } from '../stores/useOwnershipStore';

const tooltip = ref({ 
  show: false, 
  x: 0, 
  y: 0, 
  author: '', 
  products: 0, 
  contributions: 0 
});

const { filteredData, authorColors } = storeToRefs(useOwnershipStore());

// Compute z-scores from store data
const zScoreData = computed(() => {
  // Get the filtered data from store
  const authors = [...new Set(filteredData.value.map(d => d.Author))];
  
  // Calculate product count per author
  const productCounts = authors.map(author => {
    const authorData = filteredData.value.filter(d => d.Author === author);
    return {
      author,
      productCount: new Set(authorData.map(d => d.Product)).size,
      totalContrib: authorData.reduce((sum, d) => sum + d.ContributionCount, 0)
    };
  });

  // Calculate means and standard deviations
  const productMean = d3.mean(productCounts, d => d.productCount);
  const productStd = d3.deviation(productCounts, d => d.productCount);
  const contribMean = d3.mean(productCounts, d => d.totalContrib);
  const contribStd = d3.deviation(productCounts, d => d.totalContrib);

  // Calculate z-scores
  return productCounts.map(d => ({
    author: d.author,
    zProduct: (d.productCount - productMean) / productStd,
    zContrib: (d.totalContrib - contribMean) / contribStd
  }));
});

// Chart dimensions and margins
const margin = { top: 40, right: 40, bottom: 60, left: 60 };
const width = 1000;
const height = 800;

// Refs for DOM elements
const svgRef = ref(null);

// Function to render the chart
function renderChart() {
  const svg = d3.select(svgRef.value)
    .attr('width', width)
    .attr('height', height);

  // Clear any existing elements
  svg.selectAll('*').remove();

  // Create scales
  const xScale = d3.scaleLinear()
    .domain([-3, 3])
    .range([margin.left, width - margin.right]);

  const yScale = d3.scaleLinear()
    .domain([-3, 3])
    .range([height - margin.bottom, margin.top]);

  // Create axes
  const xAxis = d3.axisBottom(xScale)
    .ticks(6)
    .tickFormat(d3.format('.1f'));

  const yAxis = d3.axisLeft(yScale)
    .ticks(6)
    .tickFormat(d3.format('.1f'));

  // Add axes
  svg.append('g')
    .attr('transform', `translate(0,${height - margin.bottom})`)
    .call(xAxis);

  svg.append('g')
    .attr('transform', `translate(${margin.left},0)`)
    .call(yAxis);

  // Add axis labels
  svg.append('text')
    .attr('x', width / 2)
    .attr('y', height - margin.bottom / 3)
    .attr('text-anchor', 'middle')
    .text('Products Z-Score');

  svg.append('text')
    .attr('transform', 'rotate(-90)')
    .attr('x', -(height / 2))
    .attr('y', margin.left / 3)
    .attr('text-anchor', 'middle')
    .text('Contributions Z-Score');

  // Add reference lines at z=0
  svg.append('line')
    .attr('x1', margin.left)
    .attr('x2', width - margin.right)
    .attr('y1', yScale(0))
    .attr('y2', yScale(0))
    .attr('stroke', '#ccc')
    .attr('stroke-dasharray', '4,4');

  svg.append('line')
    .attr('x1', xScale(0))
    .attr('x2', xScale(0))
    .attr('y1', margin.top)
    .attr('y2', height - margin.bottom)
    .attr('stroke', '#ccc')
    .attr('stroke-dasharray', '4,4');

  // Add data points
  svg.selectAll('circle')
    .data(zScoreData.value)
    .enter()
    .append('circle')
    .attr('cx', d => xScale(d.zProduct))
    .attr('cy', d => yScale(d.zContrib))
    .attr('r', 6)
    .attr('fill', d => authorColors.value[d.author] || '#1f77b4')
    .attr('stroke', '#fff')
    .attr('stroke-width', 1.5)
    .style('opacity', 0.85)
    .on('mousemove', (event, d) => {
      const productCount = filteredData.value
        .filter(item => item.Author === d.author)
        .reduce((set, item) => set.add(item.Product), new Set()).size;
      const totalContrib = filteredData.value
        .filter(item => item.Author === d.author)
        .reduce((sum, item) => sum + item.ContributionCount, 0);
      
      const containerRect = d3.select('.chart-container').node().getBoundingClientRect();
      tooltip.value = {
        show: true,
        x: event.clientX - containerRect.left + 15,
        y: event.clientY - containerRect.top - 40,
        author: d.author,
        products: productCount,
        contributions: totalContrib,
        zProduct: d3.format('.2f')(d.zProduct),
        zContrib: d3.format('.2f')(d.zContrib)
      };
    })
    .on('mouseleave', () => {
      tooltip.value.show = false;
    });

  // Add quadrant labels
  const quadrantLabels = [
    { x: xScale(2), y: yScale(2), text: 'High Products & Contributions' },
    { x: xScale(-2), y: yScale(2), text: 'Low Products, High Contributions' },
    { x: xScale(-2), y: yScale(-2), text: 'Low Products & Contributions' },
    { x: xScale(2), y: yScale(-2), text: 'High Products, Low Contributions' }
  ];

  svg.selectAll('.quadrant-label')
    .data(quadrantLabels)
    .enter()
    .append('text')
    .attr('x', d => d.x)
    .attr('y', d => d.y)
    .attr('text-anchor', 'middle')
    .attr('font-size', '12px')
    .attr('fill', '#666')
    .text(d => d.text);
}

// Trigger re-render when data changes
watch([zScoreData], () => {
  renderChart();
}, { deep: true });

// Initial render on mount
onMounted(() => {
  renderChart();
});

// Cleanup
onBeforeUnmount(() => {
  if (svgRef.value) {
    d3.select(svgRef.value).selectAll('*').remove();
  }
});
</script>

<style scoped>
.chart-container {
  position: relative;
  width: 1000px;
  height: 800px;
  margin: 0 auto;
}

svg {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.tooltip {
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
</style>
