<template>
  <div class="dashboard-container">
    <div v-if="loading" class="dashboard-loading">Loading solutions...</div>

    <div v-else-if="error" class="dashboard-error">
      {{ error }}
    </div>

    <template v-else>
      <section v-if="topWarnings && Object.keys(topWarnings).length" class="top-warnings-section">
        <h2>Top 5 Warnings Across All Solutions</h2>
        <div class="top-warnings-list">
          <a v-for="(count, code) in topWarnings" :key="code" :href="getDocsUrl(code)" target="_blank"
            class="top-warning" :style="{ backgroundColor: codeColors[code] || '#e3f2fd' }">
            {{ code }} ({{ count }})
          </a>
        </div>
      </section>

      <!-- Filter Section -->
      <section class="filter-section">
        <label>
          Warning Code:
          <input v-model="filterCode" placeholder="e.g. CS0168" />
        </label>
        <label>
          Warning Message:
          <input v-model="filterMessage" placeholder="Message contains..." />
        </label>
        <span v-if="filteredSolutions.length !== solutions.length" class="filter-count">{{ filteredSolutions.length }} of {{ solutions.length }} products match</span>
      </section>

      <div class="solutions-grid">
        <SolutionCard v-for="solution in filteredSolutions" :key="solution.ProductShortcut" :solutionData="solution" :trendValue="solution.TrendValue" :codeColors="codeColors" />
      </div>
    </template>
  </div>
</template>


<script setup>
import { ref, onMounted, computed } from 'vue'
import { getDocsUrl } from '../utils/docs'
import SolutionCard from '../components/SolutionCard.vue'
import { useDataStore } from '../stores/useDataStore'
import * as d3 from 'd3'

const { rawData: indexData, loading, error } = useDataStore()

const solutions = ref([])
const topWarnings = ref({})
const codeColors = ref({})

// Filter state
const filterCode = ref('')
const filterMessage = ref('')

const filteredSolutions = computed(() => {
  if (!filterCode.value && !filterMessage.value) return solutions.value
  return solutions.value.filter(sol => {
    // Check if any warning code starts with filterCode
    let codeMatch = true
    let msgMatch = true
    if (filterCode.value) {
      codeMatch = sol.SortedCodes.some(([code]) => code.toLowerCase().startsWith(filterCode.value.toLowerCase()))
    }
    if (filterMessage.value) {
      // Need to fetch the warning messages for this solution
      if (sol.Warnings && Array.isArray(sol.Warnings)) {
        msgMatch = sol.Warnings.some(w => w.Messages.some(m => m.toLowerCase().includes(filterMessage.value.toLowerCase())))
      } else {
        msgMatch = false
      }
    }
    return codeMatch && msgMatch
  })
})

onMounted(async () => {
  if (!Array.isArray(indexData) || indexData.length === 0) {
    throw new Error("No indexed solutions found.")
  }

  const aggregate = {}
  const enriched = []
  const allCodes = new Set()

  for (const entry of indexData) {
    const res = await fetch('/' + entry.FilePath)
    const data = await res.json()

    const warningCounts = {}
    data.Warnings.forEach(w => {
      warningCounts[w.Code] = w.Messages.length
      aggregate[w.Code] = (aggregate[w.Code] || 0) + w.Messages.length
      allCodes.add(w.Code)
    })
    const sorted = Object.entries(warningCounts).sort((a, b) => b[1] - a[1])

    enriched.push({
      ...entry,
      SortedCodes: sorted,
      Warnings: data.Warnings // Attach warnings for filtering
    })
  }

  // Build a consistent color mapping for all codes
  const palette = d3.schemeCategory10.concat(d3.schemeSet3, d3.schemeSet2, d3.schemeTableau10)
  const colorMap = {}
  Array.from(allCodes).forEach((code, idx) => {
    colorMap[code] = palette[idx % palette.length]
  })
  codeColors.value = colorMap

  // Sort solutions by total warning count (descending)
  solutions.value = enriched.sort((a, b) => {
    const totalA = a.SortedCodes.reduce((sum, [, count]) => sum + count, 0)
    const totalB = b.SortedCodes.reduce((sum, [, count]) => sum + count, 0)
    return totalB - totalA
  })

  topWarnings.value = Object.fromEntries(
    Object.entries(aggregate).sort((a, b) => b[1] - a[1]).slice(0, 5)
  )
})
</script>


<style scoped>
.dashboard-container {
  max-width: 1200px;
  padding: 1rem;
  background: rgba(36,36,36,0.98);
  border-radius: 18px;
  box-shadow: 0 4px 32px rgba(0,0,0,0.18);
}
.dashboard-title {
  text-align: center;
  font-size: 1.6rem;
  margin-bottom: 1rem;
  letter-spacing: 1px;
  color: #f5f7fa;
  text-shadow: 0 2px 8px rgba(0,0,0,0.13);
}
.dashboard-loading, .dashboard-error {
  text-align: center;
  font-size: 1.2rem;
  margin: 2rem 0;
}
.dashboard-error {
  color: #ff5252;
}
.top-warnings-section {
  margin-bottom: 1rem;
  background: #23272f;
  border-radius: 12px;
  padding: 1rem 1rem;
  box-shadow: 0 2px 12px rgba(0,0,0,0.08);
}
.top-warnings-section h2 {
  font-size: 1.1rem;
  margin-bottom: 0.7rem;
}
.top-warnings-list {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  margin-top: 1rem;
}
.top-warning {
  display: inline-block;
  padding: 0.5em 0.9em;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.95rem;
  color: #222;
  background: #e3f2fd;
  box-shadow: 0 2px 8px rgba(0,0,0,0.07);
  transition: transform 0.15s, box-shadow 0.15s;
  text-decoration: none;
}
.top-warning:hover {
  transform: translateY(-2px) scale(1.04);
  box-shadow: 0 4px 16px rgba(0,0,0,0.13);
  text-decoration: none;
}
.filter-section {
  display: flex;
  gap: 1.2rem;
  margin: 1rem 0 1.5rem 0;
  align-items: center;
  justify-content: flex-start;
  font-size: 0.97em;
  background: #23272f;
  border-radius: 12px;
  padding: 1rem 1rem;
  box-shadow: 0 2px 12px rgba(0,0,0,0.08);
}
.filter-section label {
  font-weight: 500;
  color: #e0e0e0;
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 0.5em;
  font-size: 0.97em;
}
.filter-section input {
  padding: 0.25em 0.7em;
  border-radius: 6px;
  border: 1px solid #444;
  background: #23272f;
  color: #e0e0e0;
  font-size: 0.97em;
  outline: none;
  transition: border-color 0.15s;
  height: 2em;
}
.filter-section input:focus {
  border-color: #90caf9;
}
.filter-count {
  color: #90caf9;
  font-size: 0.97em;
  margin-left: 0.7em;
  font-weight: 500;
}
.solutions-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 2rem;
}
@media (max-width: 1200px) {
  .solutions-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}
@media (max-width: 900px) {
  .solutions-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
@media (max-width: 600px) {
  .solutions-grid {
    grid-template-columns: 1fr;
  }
}
</style>
