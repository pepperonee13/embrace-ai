<template>
    <div v-if="solution == null">
        Loading Solution data
    </div>
    <div v-else class="card" @click="goToDetails(solution.FilePath)">
        <h2>{{ solution.ProductShortcut }}</h2>
        <div ref="chartRef" class="donut-chart" @click.stop></div>
        <p>Last CI Build: <a :href="getBuildUrl(solution.BuildId)" target="_blank">{{ solution.BuildId }}</a></p>
        <p>
          Warning Trend:
          <span v-if="trendValue === null || trendValue === undefined" style="color: gray;">N/A</span>
          <span v-else-if="Math.round(trendValue) === 0" style="color: gray;">0</span>
          <span v-else-if="trendValue > 0" style="color: red;">+{{ Math.round(trendValue) }}</span>
          <span v-else style="color: green;">{{ Math.round(trendValue) }}</span>
        </p>
    </div>
</template>

<script setup>
import { ref, onMounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import * as d3 from 'd3'
import { getDocsUrl } from '../utils/docs'

const router = useRouter()
const props = defineProps({
    solutionData: Object,
    trendValue: Number,
    codeColors: Object
});

const solution = ref(null);
const trendValue = props.trendValue;
const chartRef = ref(null);

function getBuildUrl(buildId) {
    return `https://tfsprod.schleupen-ag.de/tfs/DefaultCollection/CS3/_build/results?buildId=${buildId}`
}

function goToDetails(filePath) {
    router.push({ path: `/solution/${encodeURIComponent(filePath)}` })
}

function renderDonutChart(warningCounts) {
    const el = chartRef.value;
    if (!el) return;
    // Clean up previous chart
    el.innerHTML = '';
    const width = 180, height = 180, radius = Math.min(width, height) / 2;
    const svg = d3.select(el)
        .append('svg')
        .attr('width', width)
        .attr('height', height)
        .append('g')
        .attr('transform', `translate(${width / 2},${height / 2})`);
    const pie = d3.pie().value(d => d.count);
    const data = Object.entries(warningCounts).map(([code, count]) => ({ code, count }));
    const arc = d3.arc().innerRadius(radius * 0.6).outerRadius(radius - 5);

    // Tooltip div
    let tooltip = d3.select(el).select('.d3-tooltip');
    if (tooltip.empty()) {
        tooltip = d3.select(el)
            .append('div')
            .attr('class', 'd3-tooltip')
            // Updated styles for better contrast and consistency
            .style('position', 'absolute')
            .style('background', '#23272f')
            .style('color', '#e0e0e0')
            .style('border', '1px solid #444')
            .style('padding', '4px 8px')
            .style('border-radius', '4px')
            .style('pointer-events', 'none')
            .style('font-size', '13px')
            .style('display', 'none')
            .style('z-index', 10);
    }

    svg.selectAll('path')
        .data(pie(data))
        .enter()
        .append('path')
        .attr('d', arc)
        .attr('fill', d => props.codeColors && props.codeColors[d.data.code] ? props.codeColors[d.data.code] : '#888')
        .on('mouseover', function(event, d) {
            tooltip.style('display', 'block')
                .html(`<strong>${d.data.code}</strong>: ${d.data.count}`);
            d3.select(this).attr('stroke', '#333').attr('stroke-width', 2);
        })
        .on('mousemove', function(event) {
            // Position tooltip relative to mouse, no further than 20-30px
            const offsetX = 10; // px right
            const offsetY = 10; // px down
            tooltip.style('left', (event.offsetX + offsetX) + 'px')
                   .style('top', (event.offsetY + offsetY) + 'px');
        })
        .on('mouseout', function() {
            tooltip.style('display', 'none');
            d3.select(this).attr('stroke', null);
        })
        .on('click', function(event, d) {
            // Open docs link for the warning code
            const url = getDocsUrl(d.data.code);
            if (url) {
                window.open(url, '_blank');
            }
            event.stopPropagation();
        });

    // Add total warnings in the center
    const total = Object.values(warningCounts).reduce((a, b) => a + b, 0);
    svg.append('text')
        .attr('text-anchor', 'middle')
        .attr('dy', '0.35em')
        .attr('font-size', '2rem')
        .attr('font-weight', 'bold')
        .attr('fill', '#f5f7fa') // Light color for dark background
        .text(total);
}

onMounted(async () => {
    const res = await fetch('/' + props.solutionData.FilePath)
    const data = await res.json()

    const warningCounts = {};
    data.Warnings.forEach(w => {
        warningCounts[w.Code] = w.Messages.length;
    });

    const enriched = {
        ...props.solutionData,
        ...data
    }

    solution.value = enriched;
    await nextTick();
    renderDonutChart(warningCounts);
});

watch(solution, async (val) => {
    if (val && val.Warnings) {
        const warningCounts = {};
        val.Warnings.forEach(w => {
            warningCounts[w.Code] = w.Messages.length;
        });
        await nextTick();
        renderDonutChart(warningCounts);
    }
});
</script>

<style>
.grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
}

.card {
  background: #23272f;
  border-radius: 14px;
  box-shadow: 0 2px 16px rgba(0,0,0,0.13);
  transition: transform 0.15s, box-shadow 0.15s;
  margin-bottom: 1.5rem;
  padding: 2em 1.5em 1.5em 1.5em;
  border: none;
  color: #e0e0e0;
  cursor: pointer;
  min-height: 340px;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.card:hover {
  transform: translateY(-4px) scale(1.02);
  box-shadow: 0 6px 32px rgba(0,0,0,0.18);
  background: #283046;
}

.donut-chart {
  width: 180px;
  height: 180px;
  margin: 1.2rem auto 1.5rem auto;
  display: flex;
  justify-content: center;
  align-items: center;
}

h2 {
  font-size: 1.5em;
  margin-bottom: 0.7em;
  color: #90caf9;
  font-weight: 600;
  letter-spacing: 0.5px;
}

p {
  margin: 0.5em 0;
  color: #e0e0e0;
  font-size: 1.05em;
}

.card a {
  color: #90caf9;
  text-decoration: underline dotted 1.5px;
  transition: color 0.15s;
}

.card a:hover {
  color: #fff;
}

.d3-tooltip {
  background: #23272f;
  color: #e0e0e0;
  border: 1px solid #444;
  box-shadow: 0 2px 8px rgba(0,0,0,0.13);
}

/* Responsive adjustments */
@media (max-width: 700px) {
  .card {
    padding: 1em;
    min-height: 260px;
  }
  .donut-chart {
    width: 120px;
    height: 120px;
  }
}
</style>