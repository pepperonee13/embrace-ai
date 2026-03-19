<template>
  <div class="timeline-chart">
    <div class="timeline-header">
      <h3 class="timeline-title">
        {{ title }}
      </h3>
      <div class="timeline-controls">
        <select v-model="localGroupBy" class="group-select">
          <option value="day">Group by Day</option>
          <option value="week">Group by Week</option>
          <option value="month">Group by Month</option>
        </select>
        <button @click="$emit('close')" class="close-btn">✕</button>
      </div>
    </div>

    <div class="timeline-content" ref="chartContainer">
      <svg ref="svg" :width="width" :height="height">
        <!-- Chart will be rendered here by D3 -->
      </svg>
    </div>

    <div v-if="tooltip.show" class="timeline-tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
      <div class="tooltip-content">
        <div class="tooltip-header">
          <strong>{{ tooltip.period }}</strong>
        </div>
        <div class="tooltip-body">
          <div v-if="tooltip.contributions.length === 1">
            <strong>{{ tooltip.contributions[0].Author }}</strong>
            <div class="tooltip-details">
              {{ tooltip.contributions[0].changeCount }} change{{ tooltip.contributions[0].changeCount !== 1 ? 's' : ''
              }}
            </div>
          </div>
          <div v-else>
            <div v-for="contrib in tooltip.contributions" :key="contrib.Author" class="tooltip-contributor">
              <span class="contributor-dot" :style="{ backgroundColor: authorColors[contrib.Author] }"></span>
              <strong>{{ contrib.Author }}</strong>: {{ contrib.changeCount }} change{{ contrib.changeCount !== 1 ? 's'
              : '' }}
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="timeline-legend" v-if="legendItems.length > 0">
      <div class="legend-title">Contributors:</div>
      <div class="legend-items">
        <div v-for="item in legendItems" :key="item.author" class="legend-item">
          <span class="legend-dot" :style="{ backgroundColor: item.color }"></span>
          <span class="legend-label">{{ item.author }} ({{ item.count }})</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUpdated, onUnmounted, nextTick } from 'vue';
import * as d3 from 'd3';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';

const props = defineProps({
  timelineData: {
    type: Array,
    required: true
  },
  title: {
    type: String,
    default: 'Timeline'
  },
  groupBy: {
    type: String,
    default: 'week'
  },
  type: {
    type: String,
    default: 'author' // 'author' or 'product'
  }
});

const emit = defineEmits(['close', 'period-selected', 'update:groupBy']);

const { authorColors } = storeToRefs(useOwnershipStore());

const svg = ref();
const chartContainer = ref();
// internal local groupBy sync'd with parent prop
const localGroupBy = ref(props.groupBy || 'week');
// keep prop -> local in sync
watch(() => props.groupBy, (v) => {
  if (v && v !== localGroupBy.value) localGroupBy.value = v;
});
// emit updates when local changes
watch(localGroupBy, (v) => {
  emit('update:groupBy', v || 'week');
});
const width = ref(1000); // responsive width (will be measured from container)
const height = 400;
const margin = { top: 20, right: 20, bottom: 60, left: 60 };

const tooltip = ref({
  show: false,
  x: 0,
  y: 0,
  period: '',
  contributions: []
});

// Group timeline data by time period
const groupedData = computed(() => {
  if (!props.timelineData || props.timelineData.length === 0) return [];

  const groups = {};

  props.timelineData.forEach(item => {
    let key;
    const date = new Date(item.Date);
    let periodDate = date;

    switch (localGroupBy.value) {
      case 'day':
        key = d3.timeFormat('%Y-%m-%d')(date);
        // normalize to start of day (midnight)
        periodDate = d3.timeDay(new Date(key));
        break;
      case 'week':
        const weekStart = d3.timeMonday(date);
        key = d3.timeFormat('%Y-%m-%d')(weekStart);
        // use the week's start date as the period date
        periodDate = weekStart;
        break;
      case 'month':
        key = d3.timeFormat('%Y-%m')(date);
        // normalize to the first day of the month
        periodDate = new Date(key + '-01');
        break;
    }

    if (!groups[key]) {
      groups[key] = {
        period: key,
        date: periodDate,
        items: [],
        byAuthor: {}
      };
    }

    groups[key].items.push(item);

    if (!groups[key].byAuthor[item.Author]) {
      groups[key].byAuthor[item.Author] = 0;
    }
    groups[key].byAuthor[item.Author]++;
  });

  return Object.values(groups).sort((a, b) => a.date - b.date);
});

// Legend items
const legendItems = computed(() => {
  const authorCounts = {};

  props.timelineData.forEach(item => {
    if (!authorCounts[item.Author]) {
      authorCounts[item.Author] = 0;
    }
    authorCounts[item.Author]++;
  });

  return Object.entries(authorCounts)
    .map(([author, count]) => ({
      author,
      count,
      color: authorColors.value[author] || '#ccc'
    }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 10); // Show top 10 contributors
});

function drawChart() {
  if (!svg.value || !groupedData.value.length || !chartContainer.value) return;

  // Clear previous chart
  d3.select(svg.value).selectAll('*').remove();

  const chartWidth = width.value - margin.left - margin.right;
  const chartHeight = height - margin.top - margin.bottom;

  // Prepare tick values (one per grouped period) and add padding to domain
  const tickValues = groupedData.value.map(d => d.date).sort((a, b) => a - b);
  const domainMin = tickValues.length ? d3.min(tickValues) : d3.min(groupedData.value, d => d.date);
  const domainMax = tickValues.length ? d3.max(tickValues) : d3.max(groupedData.value, d => d.date);
  // Default padding: half the distance between first two ticks, or 1 day if only one tick
  let timePadding = 24 * 60 * 60 * 1000; // 1 day in ms
  if (tickValues.length > 1) {
    const diff = tickValues[1].getTime() - tickValues[0].getTime();
    if (diff > 0) timePadding = diff / 2;
  }
  const domainStart = new Date(domainMin.getTime() - timePadding);
  const domainEnd = new Date(domainMax.getTime() + timePadding);

  // Create scales
  const xScale = d3.scaleTime()
    .domain([domainStart, domainEnd])
    .range([0, chartWidth]);

  // Create a band scale for discrete bar positioning (one band per grouped period)
  const bandDomain = groupedData.value.map(d => d.period);
  const xBand = d3.scaleBand()
    .domain(bandDomain)
    .range([0, chartWidth])
    .padding(0.2);

  const maxContributions = d3.max(groupedData.value, d => d.items.length);
  const yScale = d3.scaleLinear()
    .domain([0, maxContributions])
    .range([chartHeight, 0]);

  // Create SVG group
  const g = d3.select(svg.value)
    .append('g')
    .attr('transform', `translate(${margin.left},${margin.top})`);

  // Add axes
  if (props.type === 'product') {
    // For stacked bar charts, use the band scale for the x-axis
    const xAxisG = g.append('g')
      .attr('transform', `translate(0,${chartHeight})`)
      .call(d3.axisBottom(xBand).tickFormat(d => {
        // domain values are period strings like 'YYYY-MM-DD' or 'YYYY-MM'
        if (localGroupBy.value === 'week') {
          const dt = new Date(d);
          try {
            return 'CW' + d3.timeFormat('%V')(dt);
          } catch (e) {
            return d3.timeFormat('%m/%d')(dt);
          }
        }
        // month domain values are 'YYYY-MM' — show full month name
        if (localGroupBy.value === 'month') {
          const dt = new Date(d + '-01');
          return d3.timeFormat('%B %Y')(dt);
        }
        const dt = new Date(d + (d.length === 7 ? '-01' : ''));
        return d3.timeFormat('%m/%d')(dt);
      }));

    // Rotate tick labels for readability
    xAxisG.selectAll('text')
      .style('text-anchor', 'end')
      .attr('transform', 'rotate(-45)')
      .attr('dx', '-0.6em')
      .attr('dy', '0.25em');
  } else {
    // For bar charts use the band scale so each grouped period occupies one band
    const xAxisG = g.append('g')
      .attr('transform', `translate(0,${chartHeight})`)
      .call(d3.axisBottom(xBand).tickFormat(d => {
        // domain values are period strings like 'YYYY-MM-DD' or 'YYYY-MM'
        if (localGroupBy.value === 'week') {
          const dt = new Date(d);
          try {
            return 'CW' + d3.timeFormat('%V')(dt);
          } catch (e) {
            return d3.timeFormat('%m/%d')(dt);
          }
        }
        // month domain values are 'YYYY-MM' — show full month name
        if (localGroupBy.value === 'month') {
          const dt = new Date(d + '-01');
          return d3.timeFormat('%B %Y')(dt);
        }
        const dt = new Date(d + (d.length === 7 ? '-01' : ''));
        return d3.timeFormat('%m/%d')(dt);
      }));

    // Rotate tick labels for readability
    xAxisG.selectAll('text')
      .style('text-anchor', 'end')
      .attr('transform', 'rotate(-45)')
      .attr('dx', '-0.6em')
      .attr('dy', '0.25em');
  }

  g.append('g')
    .call(d3.axisLeft(yScale));

  // Add axis labels
  g.append('text')
    .attr('transform', 'rotate(-90)')
    .attr('y', 0 - margin.left)
    .attr('x', 0 - (chartHeight / 2))
    .attr('dy', '1em')
    .style('text-anchor', 'middle')
    .style('font-size', '12px')
    .text('Number of Changes');

  g.append('text')
    .attr('transform', `translate(${chartWidth / 2}, ${chartHeight + margin.bottom - 10})`)
    .style('text-anchor', 'middle')
    .style('font-size', '12px')
    .text('Date');

  // Create stacked bar chart if showing by product, or bar chart if showing by author
  if (props.type === 'product') {
    // Stacked bar chart for 'by product' view
    const authors = [...new Set(props.timelineData.map(d => d.Author))];
    const stack = d3.stack()
      .keys(authors)
      .value((d, key) => d.byAuthor[key] || 0);

    const stackedData = stack(groupedData.value);

    g.selectAll('.stacked-bar-group')
      .data(stackedData)
      .enter().append('g')
      .attr('class', 'stacked-bar-group')
      .style('fill', d => authorColors.value[d.key] || '#ccc')
      .selectAll('rect')
      .data(d => d)
      .enter().append('rect')
      .attr('x', d => xBand(d.data.period))
      .attr('y', d => yScale(d[1]))
      .attr('width', xBand.bandwidth())
      .attr('height', d => yScale(d[0]) - yScale(d[1]))
      .style('opacity', 0.7)
      .on('mouseover', function (event, d) {
        d3.select(this).style('opacity', 0.9);
      })
      .on('mouseout', function (event, d) {
        d3.select(this).style('opacity', 0.7);
      });
  } else {
    // Bar chart (use band scale for discrete groups)
    const bandWidth = Math.max(2, xBand.bandwidth());

    g.selectAll('.bar')
      .data(groupedData.value)
      .enter().append('rect')
      .attr('class', 'bar')
      .attr('x', d => xBand(d.period))
      .attr('y', d => yScale(d.items.length))
      .attr('width', bandWidth)
      .attr('height', d => chartHeight - yScale(d.items.length))
      .style('fill', '#1f77b4')
      .style('opacity', 0.7)
      .style('cursor', 'pointer')
      .on('mouseover', function (event, d) {
        d3.select(this).style('opacity', 0.9);
        showTooltip(event, d);
      })
      .on('mouseout', function (event, d) {
        d3.select(this).style('opacity', 0.7);
        hideTooltip();
      })
      .on('mousemove', function (event, d) {
        showTooltip(event, d);
      })
      .on('click', function (event, d) {
        // Only meaningful for week/month grouping
        if (localGroupBy.value === 'day') return;

        try {
          let startTs = null;
          let endTs = null;
          let suggestedNewGroup = null;
          if (localGroupBy.value === 'week') {
            // d.period is week start in 'YYYY-MM-DD'
            const start = new Date(d.period);
            start.setHours(0, 0, 0, 0);
            const end = new Date(start);
            end.setDate(end.getDate() + 6);
            end.setHours(23, 59, 59, 999);
            startTs = start.getTime();
            endTs = end.getTime();
            suggestedNewGroup = 'day';
          } else if (localGroupBy.value === 'month') {
            // d.period is 'YYYY-MM'
            const start = new Date(d.period + '-01');
            start.setHours(0, 0, 0, 0);
            const end = new Date(start.getFullYear(), start.getMonth() + 1, 0);
            end.setHours(23, 59, 59, 999);
            startTs = start.getTime();
            endTs = end.getTime();
            suggestedNewGroup = 'week';
          }

          if (startTs != null && endTs != null) {
            emit('period-selected', { start: startTs, end: endTs, newGroup: suggestedNewGroup });
          }
        } catch (err) {
          // swallow — don't break interactions
          console.error('Failed to compute period bounds for click:', err);
        }
      });
  }
}

function showTooltip(event, data) {
  const [x, y] = d3.pointer(event, chartContainer.value);

  const contributions = Object.entries(data.byAuthor).map(([author, count]) => ({
    Author: author,
    changeCount: count
  })).sort((a, b) => b.changeCount - a.changeCount);

  tooltip.value = {
    show: true,
    x: x + 10,
    y: y - 10,
    period: formatPeriod(data.period),
    contributions
  };
}

function hideTooltip() {
  tooltip.value.show = false;
}

function formatPeriod(period) {
  if (localGroupBy.value === 'month') {
    return d3.timeFormat('%B %Y')(new Date(period + '-01'));
  } else if (localGroupBy.value === 'week') {
    const weekStart = new Date(period);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 6);
    return `Week of ${d3.timeFormat('%m/%d')(weekStart)} - ${d3.timeFormat('%m/%d')(weekEnd)}`;
  } else {
    return d3.timeFormat('%m/%d/%Y')(new Date(period));
  }
}

function updateSize() {
  if (!chartContainer.value) return;
  const rect = chartContainer.value.getBoundingClientRect();
  // set width only if changed to avoid extra redraws
  if (width.value !== rect.width) width.value = Math.max(300, rect.width);
  // ensure svg element reflects width
  if (svg.value) svg.value.setAttribute('width', String(width.value));
}

onMounted(() => {
  console.log('TimelineChart mounted');
  updateSize();
  window.addEventListener('resize', updateSize);
  nextTick(drawChart);
});

onUpdated(() => {
  console.log('TimelineChart updated');
});

onUnmounted(() => {
  console.log('TimelineChart unmounted');
  window.removeEventListener('resize', updateSize);
});


watch([groupedData, () => props.timelineData, localGroupBy], () => {
  nextTick(drawChart);
});
</script>

<style scoped>
.timeline-chart {
  background: white;
  border-radius: 10px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  padding: 1.5rem;
  margin: 1rem 0;
  position: relative;
}

.timeline-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  border-bottom: 1px solid #eee;
  padding-bottom: 1rem;
}

.timeline-title {
  margin: 0;
  color: #333;
  font-size: 1.2em;
}

.timeline-subtitle {
  color: #666;
  font-size: 0.8em;
  font-weight: normal;
}

.timeline-controls {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.group-select {
  padding: 0.3rem 0.6rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: white;
  font-size: 0.9em;
}

.close-btn {
  background: #f0f0f0;
  border: none;
  border-radius: 50%;
  width: 24px;
  height: 24px;
  cursor: pointer;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #666;
}

.close-btn:hover {
  background: #e0e0e0;
  color: #333;
}

.timeline-content {
  position: relative;
  overflow: hidden;
}

.timeline-tooltip {
  position: absolute;
  pointer-events: none;
  background: rgba(0, 0, 0, 0.9);
  color: white;
  border-radius: 4px;
  padding: 0.5rem;
  font-size: 0.85em;
  z-index: 1000;
  max-width: 300px;
}

.tooltip-header {
  border-bottom: 1px solid #555;
  padding-bottom: 0.25rem;
  margin-bottom: 0.25rem;
}

.tooltip-contributor {
  display: flex;
  align-items: center;
  margin: 0.2rem 0;
}

.contributor-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 0.5rem;
}

.timeline-legend {
  margin-top: 1rem;
  border-top: 1px solid #eee;
  padding-top: 1rem;
}

.legend-title {
  font-weight: bold;
  margin-bottom: 0.5rem;
  color: #333;
}

.legend-items {
  display: flex;
  flex-wrap: wrap;
  gap: 0.8rem;
}

.legend-item {
  display: flex;
  align-items: center;
  font-size: 0.85em;
}

.legend-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 0.3rem;
}

.legend-label {
  color: #666;
}

/* Chart styling */
:deep(.area) {
  stroke: none;
}

:deep(.bar) {
  stroke: none;
}

:deep(.axis) {
  font-size: 12px;
}

:deep(.axis .domain) {
  stroke: #ccc;
}

:deep(.axis .tick line) {
  stroke: #ccc;
}

:deep(.axis .tick text) {
  fill: #666;
}
</style>