<template>
  <div class="chart-container">
    <div class="chart-header">
      <h3 class="chart-title">Contribution Distribution Analysis</h3>
      <p class="chart-description">
        Statistical analysis showing how each contributor compares to the average.
        Authors in the upper-right quadrant contribute to many products with high contribution counts.
      </p>
    </div>
    <svg ref="svgRef"></svg>
    <teleport to="body">
      <div v-if="tooltip.show" class="zscore-tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
        <div class="tooltip-header">
          <span class="author-name" :style="{ color: authorColors[tooltip.author] || '#225EA9' }">
            {{ tooltip.author }}
          </span>
        </div>
        <div class="tooltip-body">
          <div class="stat-row">
            <span class="stat-label">Products:</span>
            <span class="stat-value">{{ tooltip.products }}</span>
            <span class="stat-zscore">(Z: {{ tooltip.zProduct }})</span>
          </div>
          <div class="stat-row">
            <span class="stat-label">Contributions:</span>
            <span class="stat-value">{{ tooltip.contributions }}</span>
            <span class="stat-zscore">(Z: {{ tooltip.zContrib }})</span>
          </div>
        </div>
        <div class="tooltip-footer">
          <span class="click-hint">💡 Click to filter by author</span>
        </div>
      </div>
    </teleport>
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

const store = useOwnershipStore();
const { filteredData, authorColors } = storeToRefs(store);

// Reactive dimensions for responsive sizing
const dimensions = reactive({
  width: 1000,
  height: 800
});

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

// Refs for DOM elements
const svgRef = ref(null);

// Function to render the chart
function renderChart() {
  const width = dimensions.width;
  const height = dimensions.height;

  // Responsive margins
  const margin = {
    top: height * 0.05,
    right: width * 0.04,
    bottom: height * 0.075,
    left: width * 0.06
  };

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

  // Add axis labels with classes for styling
  svg.append('text')
    .attr('class', 'axis-label')
    .attr('x', width / 2)
    .attr('y', height - 10)
    .attr('text-anchor', 'middle')
    .text('Products Z-Score');

  svg.append('text')
    .attr('class', 'axis-label')
    .attr('transform', 'rotate(-90)')
    .attr('x', -(height / 2))
    .attr('y', 15)
    .attr('text-anchor', 'middle')
    .text('Contributions Z-Score');

  // Add subtle background grid
  const gridColor = '#f0f0f0';
  const axisColor = '#cbd5e1'; // Tailwind gray-300

  // Background grid lines
  [-2, -1, 1, 2].forEach(z => {
    // Vertical grid lines
    svg.append('line')
      .attr('x1', xScale(z))
      .attr('x2', xScale(z))
      .attr('y1', margin.top)
      .attr('y2', height - margin.bottom)
      .attr('stroke', gridColor)
      .attr('stroke-width', 1);

    // Horizontal grid lines
    svg.append('line')
      .attr('x1', margin.left)
      .attr('x2', width - margin.right)
      .attr('y1', yScale(z))
      .attr('y2', yScale(z))
      .attr('stroke', gridColor)
      .attr('stroke-width', 1);
  });

  // Highlighted zero axis lines
  svg.append('line')
    .attr('x1', margin.left)
    .attr('x2', width - margin.right)
    .attr('y1', yScale(0))
    .attr('y2', yScale(0))
    .attr('stroke', axisColor)
    .attr('stroke-width', 2)
    .attr('stroke-dasharray', '5,5');

  svg.append('line')
    .attr('x1', xScale(0))
    .attr('x2', xScale(0))
    .attr('y1', margin.top)
    .attr('y2', height - margin.bottom)
    .attr('stroke', axisColor)
    .attr('stroke-width', 2)
    .attr('stroke-dasharray', '5,5');

  // Add subtle background colors to quadrants
  const quadrants = [
    { x: xScale(0), y: yScale(0), width: xScale(3) - xScale(0), height: yScale(0) - yScale(3), fill: 'rgba(8, 143, 155, 0.03)' },
    { x: margin.left, y: yScale(0), width: xScale(0) - margin.left, height: yScale(0) - yScale(3), fill: 'rgba(225, 234, 169, 0.03)' },
    { x: margin.left, y: yScale(-3), width: xScale(0) - margin.left, height: yScale(0) - yScale(-3), fill: 'rgba(220, 220, 220, 0.03)' },
    { x: xScale(0), y: yScale(-3), width: xScale(3) - xScale(0), height: yScale(0) - yScale(-3), fill: 'rgba(240, 130, 35, 0.03)' }
  ];

  svg.selectAll('.quadrant-bg')
    .data(quadrants)
    .enter()
    .append('rect')
    .attr('class', 'quadrant-bg')
    .attr('x', d => d.x)
    .attr('y', d => d.y)
    .attr('width', d => d.width)
    .attr('height', d => d.height)
    .attr('fill', d => d.fill)
    .attr('pointer-events', 'none');

  // Enhanced quadrant labels with subtexts
  const labelData = [
    { x: xScale(1.5), y: yScale(2.5), text: 'High Impact', subtext: 'Many products, high contributions', color: '#006B75' },
    { x: xScale(-1.5), y: yScale(2.5), text: 'Specialist', subtext: 'Few products, high contributions', color: '#088F9B' },
    { x: xScale(-1.5), y: yScale(-2.5), text: 'Limited Activity', subtext: 'Few products & contributions', color: '#999' },
    { x: xScale(1.5), y: yScale(-2.5), text: 'Broad Scope', subtext: 'Many products, lower contributions', color: '#D47113' }
  ];

  labelData.forEach(label => {
    // Main label
    svg.append('text')
      .attr('x', label.x)
      .attr('y', label.y)
      .attr('text-anchor', 'middle')
      .attr('font-size', '15px')
      .attr('font-weight', '600')
      .attr('fill', label.color)
      .attr('class', 'quadrant-label-main')
      .text(label.text);

    // Subtext
    svg.append('text')
      .attr('x', label.x)
      .attr('y', label.y + 18)
      .attr('text-anchor', 'middle')
      .attr('font-size', '11px')
      .attr('font-weight', '400')
      .attr('fill', '#999')
      .attr('class', 'quadrant-label-sub')
      .text(label.subtext);
  });

  // Add data points with enhanced styling (rendered last to appear on top)
  svg.selectAll('circle')
    .data(zScoreData.value)
    .enter()
    .append('circle')
    .attr('cx', d => xScale(d.zProduct))
    .attr('cy', d => yScale(d.zContrib))
    .attr('r', 7)
    .attr('fill', d => authorColors.value[d.author] || '#225EA9')
    .attr('stroke', '#fff')
    .attr('stroke-width', 2)
    .style('opacity', 0.85)
    .style('cursor', 'pointer')
    .style('transition', 'all 0.2s ease')
    .style('filter', 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))')
    .on('mouseenter', function(event, d) {
      d3.select(this)
        .style('opacity', 1)
        .attr('r', 9)
        .style('filter', 'drop-shadow(0 4px 8px rgba(0,0,0,0.2))');
    })
    .on('mousemove', (event, d) => {
      const productCount = filteredData.value
        .filter(item => item.Author === d.author)
        .reduce((set, item) => set.add(item.Product), new Set()).size;
      const totalContrib = filteredData.value
        .filter(item => item.Author === d.author)
        .reduce((sum, item) => sum + item.ContributionCount, 0);

      tooltip.value = {
        show: true,
        x: event.clientX + 12,
        y: event.clientY - 10,
        author: d.author,
        products: productCount,
        contributions: totalContrib,
        zProduct: d3.format('.2f')(d.zProduct),
        zContrib: d3.format('.2f')(d.zContrib)
      };
    })
    .on('mouseleave', function() {
      // Reset circle styles
      d3.select(this)
        .style('opacity', 0.85)
        .attr('r', 7)
        .style('filter', 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))');
      // Hide tooltip
      tooltip.value.show = false;
    })
    .on('click', (event, d) => {
      // Hide tooltip on click
      tooltip.value.show = false;

      // Navigate to by author view filtered to the clicked author
      store.setChartMode('author');

      // Clear existing filters and set only the clicked author
      store.setProducts([]);
      store.setAuthors([d.author]);
    });
}

// Trigger re-render when data changes
watch([zScoreData], () => {
  renderChart();
}, { deep: true });

// Debounce helper for resize
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Initial render on mount
onMounted(() => {
  renderChart();

  // Set up responsive sizing with resize observer
  const updateDimensions = () => {
    if (svgRef.value && svgRef.value.parentElement) {
      const containerWidth = svgRef.value.parentElement.clientWidth;
      dimensions.width = Math.max(600, Math.min(1200, containerWidth - 48)); // Account for padding
      dimensions.height = dimensions.width * 0.8; // Maintain aspect ratio
      renderChart();
    }
  };

  // Initial sizing
  updateDimensions();

  // Debounced resize listener
  const debouncedUpdate = debounce(updateDimensions, 150);
  window.addEventListener('resize', debouncedUpdate);

  // Cleanup on unmount
  onBeforeUnmount(() => {
    window.removeEventListener('resize', debouncedUpdate);
    if (svgRef.value) {
      d3.select(svgRef.value).selectAll('*').remove();
    }
  });
});
</script>

<style scoped>
.chart-container {
  @apply relative bg-white rounded-xl shadow-lg
         border-2 border-gray-100 transition-all duration-300
         hover:shadow-xl hover:border-brand-blue/30
         p-6;
  max-width: 1000px;
  margin: 0 auto;
  animation: slideUp 0.4s ease-out;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.chart-header {
  @apply mb-6 text-center;
}

.chart-title {
  @apply text-2xl font-bold text-brand-gray mb-3;
  font-family: 'Inter', sans-serif;
}

.chart-description {
  @apply text-sm text-gray-600 leading-relaxed max-w-2xl mx-auto;
  font-family: 'Inter', sans-serif;
}

svg {
  display: block;
  margin: 0 auto;
  max-width: 100%;
  height: auto;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}

svg text {
  @apply fill-gray-700;
  font-weight: 500;
}

svg .axis-label {
  @apply fill-brand-gray;
  font-weight: 600;
  font-size: 14px;
}

svg .quadrant-label {
  @apply fill-gray-500;
  font-weight: 500;
  font-size: 13px;
}

.zscore-tooltip {
  @apply fixed pointer-events-none bg-white rounded-xl shadow-2xl
         border-2 px-4 py-3 text-sm font-medium;
  border-color: var(--brand-blue);
  z-index: 9999;
  min-width: 240px;
  backdrop-filter: blur(8px);
  animation: tooltipFadeIn 0.2s ease-out;
  font-family: 'Inter', sans-serif;
}

@keyframes tooltipFadeIn {
  from {
    opacity: 0;
    transform: translateY(-8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.tooltip-header {
  @apply border-b border-gray-200 pb-2 mb-2;
}

.author-name {
  @apply font-bold text-base;
}

.tooltip-body {
  @apply space-y-1.5;
}

.stat-row {
  @apply flex items-center justify-between gap-3 text-gray-700;
}

.stat-label {
  @apply text-xs font-medium text-gray-500 uppercase tracking-wide;
  flex: 0 0 auto;
}

.stat-value {
  @apply font-mono font-bold text-brand-gray;
  flex: 0 0 auto;
}

.stat-zscore {
  @apply text-xs text-gray-500 font-mono;
  flex: 1 1 auto;
  text-align: right;
}

.tooltip-footer {
  @apply border-t border-gray-200 pt-2 mt-2;
}

.click-hint {
  @apply text-xs text-gray-500 italic flex items-center gap-1;
}

@media (max-width: 768px) {
  .chart-container {
    @apply p-4;
  }

  .chart-title {
    @apply text-xl;
  }

  .chart-description {
    @apply text-xs;
  }
}
</style>
