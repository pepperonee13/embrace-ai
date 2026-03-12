<template>
  <div class="timeline-view">
    <div class="timeline-header">
      <h2 class="timeline-title">
        <span class="back-btn" @click="$router.push('/')" title="Back to Dashboard">← </span>
        Timeline Analysis
        <span v-if="dateRangeText" class="date-range">{{ dateRangeText }}</span>
      </h2>
      <div class="timeline-header-actions">
        <router-link
          to="/admin"
          class="settings-icon-btn"
          title="Configuration Settings"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
        </router-link>
      </div>
      <div class="timeline-stats">
        <div class="stat-item">
          <span class="stat-value">{{ changesDisplay }}</span>
          <span class="stat-label">Changes</span>
        </div>
        <div class="stat-item">
          <span class="stat-value">{{ authorsDisplay }}</span>
          <span class="stat-label">Contributors</span>
        </div>
        <div class="stat-item">
          <span class="stat-value">{{ productsDisplay }}</span>
          <span class="stat-label">Products</span>
        </div>
      </div>
    </div>

    <!-- Timeline Filters -->
    <div class="timeline-filters">
      <div class="filter-group">
        <label>View Type:</label>
        <select v-model="viewType" class="filter-select">
          <option value="all">All Changes</option>
          <option value="author">By Author</option>
          <option value="product">By Product</option>
        </select>
      </div>

      <div class="filter-group" v-if="viewType === 'author'">
        <label>Select Author:</label>
        <select v-model="selectedAuthorSingle" class="filter-select">
          <option value="">All Authors</option>
          <option v-for="author in authors" :key="author" :value="author">
            {{ author }}
          </option>
        </select>
      </div>

      <div class="filter-group" v-if="viewType === 'product'">
        <label>Select Product:</label>
        <select v-model="selectedProduct" class="filter-select">
          <option value="">All Products</option>
          <option v-for="product in products" :key="product" :value="product">
            {{ product }}
          </option>
        </select>
      </div>

      <div class="filter-group">
        <label>Source:</label>
        <select v-model="selectedSource" class="filter-select">
          <option value="">All Sources</option>
          <option value="TFS">TFS</option>
          <option value="Git">Git</option>
        </select>
      </div>

      <div class="filter-group date-range-group">
        <label>Date Range:</label>
        <div class="quick-range-buttons">
          <button type="button" class="pill" @click="applyQuickRange('thisYear')">This Year</button>
          <button type="button" class="pill" @click="applyQuickRange('lastMonth')">Last Month</button>
          <button type="button" class="pill" @click="applyQuickRange('last30')">Last 30 Days</button>
          <button type="button" class="pill" @click="applyQuickRange('last7')">Last Week</button>
          <select v-if="sprintsList.length" v-model="selectedSprint" @change="applySprint(selectedSprint)"
            class="filter-select" style="min-width:180px;margin-left:0.5rem;">
            <option value="">Select Sprint...</option>
            <option v-for="sp in sprintsList" :key="sp.name" :value="sp.name">{{ sp.name }}</option>
          </select>
          <select v-else disabled class="filter-select" style="min-width:180px;margin-left:0.5rem;">
            <option>No sprints configured</option>
          </select>
        </div>
        <div class="date-slider-container">
          <div class="date-range-display" v-if="sliderInitialized">
            <span class="date-display">{{ formatDateDisplay(dateFromValue) }}</span>
            <span class="date-separator">to</span>
            <span class="date-display">{{ formatDateDisplay(dateToValue) }}</span>
          </div>
          <div v-else class="loading-display">
            <span>Loading date range...</span>
          </div>
          <div class="vue-slider-container">
            <VueSlider v-if="sliderInitialized" v-model="dateRange" :min="minDateTimestamp" :max="maxDateTimestamp"
              :lazy="false" :tooltip="'none'" :enableCross="false" :order="true" class="date-range-slider" />
            <div v-else class="loading-display">Initializing slider...</div>
          </div>
          <div class="date-labels">
            <span class="date-label-min">{{ formatDateDisplay(new Date(Number(minDateTimestamp))) }}</span>
            <span class="date-label-max">{{ formatDateDisplay(new Date(Number(maxDateTimestamp))) }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Timeline Content -->
    <div class="timeline-content">
      <div v-if="!timelineData.length" class="no-data">
        <p>No timeline data available. Please run the data generation script first.</p>
      </div>
      <div v-else>
        <!-- Chart View -->
        <div class="main-timeline-chart">
          <TimelineChart v-if="filteredTimelineData.length" :timeline-data="filteredTimelineData"
            :group-by="chartGroupBy" @update:groupBy="(v) => {
              if (typeof chartGroupBy === 'object' && 'value' in chartGroupBy) {
                chartGroupBy.value = v || 'week';
              } else {
                chartGroupBy = ref(v || 'week');
              }
            }" @period-selected="handlePeriodSelected" :title="chartTitle"
            :type="viewType === 'product' && selectedProduct ? 'product' : 'author'" />
          <div v-else class="no-chart-data">
            <p>No changes in the selected date range.</p>
          </div>
        </div>

        <!-- Contributor Legend (Pill Buttons) -->
        <div class="contributor-legend">
          <button v-for="author in authors" :key="author" type="button"
            :class="['pill', 'contributor-pill', { selected: selectedAuthors.includes(author) }]"
            @click="selectAuthor(author)" :style="authorColors[author]
              ? (selectedAuthors.includes(author)
                ? { background: authorColors[author], color: '#000', borderColor: authorColors[author] }
                : { borderColor: authorColors[author], color: '#000' })
              : { color: '#000' }">
            {{ author }}
          </button>

          <button type="button" class="pill contributor-pill all-pill"
            :class="{ selected: selectedAuthors.length === 0 }" @click="clearAuthor"
            :style="selectedAuthors.length === 0 ? { background: '#e9ecef', color: '#000', borderColor: '#e9ecef' } : { borderColor: '#bbb', color: '#000' }">
            All Contributors
          </button>
        </div>

        <!-- Data Table -->
        <div class="timeline-table-container">
          <h3>Recent Changes (Last 50)</h3>
          <div class="table-wrapper">
            <table class="timeline-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Author</th>
                  <th>Product</th>
                  <th>Change Type</th>
                  <th>File</th>
                  <th>Source</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in recentChanges" :key="`${item.ChangesetId}-${item.FilePath}`">
                  <td class="date-cell">{{ formatDate(item.Date) }}</td>
                  <td class="author-cell">
                    <span class="author-dot" :style="{ backgroundColor: authorColors[item.Author] }"></span>
                    {{ item.Author }}
                  </td>
                  <td class="product-cell">{{ item.Product }}</td>
                  <td class="change-type-cell">
                    <span class="change-badge" :class="getChangeTypeClass(item.ChangeType)">
                      {{ item.ChangeType }}
                    </span>
                  </td>
                  <td class="file-cell" :title="item.FilePath">
                    {{ getFileName(item.FilePath) }}
                  </td>
                  <td class="source-cell">
                    <span class="source-badge" :class="item.Source.toLowerCase()">
                      {{ item.Source }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';
import { useRoute } from 'vue-router';
import TimelineChart from '../components/TimelineChart.vue';
import { getEnvironmentPath } from '../utils/environment';
import VueSlider from 'vue-slider-component';
import 'vue-slider-component/theme/antd.css';

const store = useOwnershipStore();
const route = useRoute();
const { timelineData, dateInfo, authorColors, sprints } = storeToRefs(store);

// Filter states
const viewType = ref('all');
const selectedAuthors = ref([]); // array for multi-select authors (OR semantics)
const selectedProduct = ref('');
const selectedSource = ref(''); // '' = All, 'TFS', 'Git'

// Adapter so the existing single-select dropdown works with the multi-select
const selectedAuthorSingle = computed({
  get() { return selectedAuthors.value[0] || ''; },
  set(v) {
    if (!v) selectedAuthors.value = [];
    else selectedAuthors.value = [v];
  }
});

// Sprint quick-filter state (expects `sprints` from store as array of { name, since, until })
const selectedSprint = ref('');
const sprintsList = computed(() => (sprints && sprints.value ? sprints.value : []));

function applyQuickRange(type) {
  const now = new Date();
  let start;
  let end = new Date();
  switch (type) {
    case 'thisYear':
      start = new Date(now.getFullYear(), 0, 1);
      end = now;
      break;
    case 'lastMonth':
      start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      end = new Date(now.getFullYear(), now.getMonth(), 0);
      break;
    case 'last30':
      start = new Date();
      start.setDate(now.getDate() - 29);
      end = now;
      break;
    case 'last7':
      start = new Date();
      start.setDate(now.getDate() - 6);
      end = now;
      break;
    default:
      return;
  }

  if (!sliderInitialized.value) initializeDateSlider();
  // Clamp to slider bounds to avoid vue-slider errors
  const min = Number(minDateTimestamp.value || -Infinity);
  const max = Number(maxDateTimestamp.value || Infinity);
  let s = start.getTime();
  let e = end.getTime();
  if (s < min) s = min;
  if (e > max) e = max;
  if (s > e) s = Math.max(min, Math.min(e, max));
  dateRange.value = [s, e];
  selectedSprint.value = '';
}

function applySprint(sprintName) {
  if (!sprintName || !sprintsList.value.length) return;
  const sp = sprintsList.value.find(s => s.name === sprintName);
  if (!sp) return;
  const start = new Date(sp.since);
  const end = new Date(sp.until);
  if (!sliderInitialized.value) initializeDateSlider();
  // Clamp to slider bounds
  const min = Number(minDateTimestamp.value || -Infinity);
  const max = Number(maxDateTimestamp.value || Infinity);
  let s = start.getTime();
  let e = end.getTime();
  if (s < min) s = min;
  if (e > max) e = max;
  if (s > e) s = Math.max(min, Math.min(e, max));
  dateRange.value = [s, e];
  selectedSprint.value = sprintName;
}

// Date slider states  
const dateRange = ref([null, null]);
const minDateTimestamp = ref(null);
const maxDateTimestamp = ref(null);
const sliderInitialized = ref(false);

// Computed properties
const dateRangeText = computed(() => {
  const dr = dateInfo.value;
  if (!dr || (!dr.since && !dr.until)) return '';
  if (dr.since && dr.until) return `from ${dr.since} to ${dr.until}`;
  if (dr.since) return `since ${dr.since}`;
  if (dr.until) return `until ${dr.until}`;
  return '';
});

const authors = computed(() => {
  return [...new Set(timelineData.value.map(item => item.Author))].sort();
});

const products = computed(() => {
  return [...new Set(timelineData.value.map(item => item.Product))].sort();
});

const uniqueAuthors = computed(() => authors.value.length);
const uniqueProducts = computed(() => products.value.length);

// Filtered stats (reflect current filters)
const filteredChangesCount = computed(() => filteredTimelineData.value.length);
const filteredAuthorsCount = computed(() => {
  return new Set(filteredTimelineData.value.map(item => item.Author)).size;
});
const filteredProductsCount = computed(() => {
  return new Set(filteredTimelineData.value.map(item => item.Product)).size;
});

// Number formatter for thousands separator
const numberFormatter = new Intl.NumberFormat('en-US');

// Display helpers: show 'filtered / total' only when different
const changesDisplay = computed(() => {
  const f = filteredChangesCount.value;
  const t = timelineData.value.length;
  return f === t ? numberFormatter.format(t) : `${numberFormatter.format(f)} / ${numberFormatter.format(t)}`;
});

const authorsDisplay = computed(() => {
  const f = filteredAuthorsCount.value;
  const t = uniqueAuthors.value;
  return f === t ? numberFormatter.format(t) : `${numberFormatter.format(f)} / ${numberFormatter.format(t)}`;
});

const productsDisplay = computed(() => {
  const f = filteredProductsCount.value;
  const t = uniqueProducts.value;
  return f === t ? numberFormatter.format(t) : `${numberFormatter.format(f)} / ${numberFormatter.format(t)}`;
});

// Chart grouping control (synced with component)
const chartGroupBy = ref('week');

// Date slider computed properties
const dateFromValue = computed(() => {
  if (!dateRange.value || !dateRange.value[0]) return new Date();
  return new Date(Number(dateRange.value[0]));
});
const dateToValue = computed(() => {
  if (!dateRange.value || !dateRange.value[1]) return new Date();
  return new Date(Number(dateRange.value[1]));
});



const filteredTimelineData = computed(() => {
  let filtered = timelineData.value;

  // Filter by view type and selection
  if (viewType.value === 'author' && selectedAuthors.value && selectedAuthors.value.length) {
    filtered = filtered.filter(item => selectedAuthors.value.includes(item.Author));
  } else if (viewType.value === 'product' && selectedProduct.value) {
    filtered = filtered.filter(item => item.Product === selectedProduct.value);
  }

  // Filter by source
  if (selectedSource.value) {
    filtered = filtered.filter(item => (item.Source || '').toLowerCase() === selectedSource.value.toLowerCase());
  }

  // Filter by date range using slider values (only if slider is initialized)
  if (sliderInitialized.value && dateRange.value && dateRange.value[0] && dateRange.value[1]) {
    const fromDate = new Date(Number(dateRange.value[0]));
    const toDate = new Date(Number(dateRange.value[1]));
    toDate.setHours(23, 59, 59, 999); // End of day
    filtered = filtered.filter(item => {
      const itemDate = new Date(item.Date);
      return itemDate >= fromDate && itemDate <= toDate;
    });
  }

  return filtered.sort((a, b) => b.Date - a.Date);
});

const recentChanges = computed(() => {
  return filteredTimelineData.value.slice(0, 50);
});

const chartTitle = computed(() => {
  let title = 'Timeline Overview';
  if (viewType.value === 'author' && selectedAuthors.value && selectedAuthors.value.length === 1) {
    title = `Timeline for ${selectedAuthors.value[0]}`;
  } else if (viewType.value === 'product' && selectedProduct.value) {
    title = `Timeline for ${selectedProduct.value}`;
  }

  const filteredCount = filteredTimelineData.value.length;
  const totalCount = timelineData.value.length;
  if (filteredCount === totalCount) {
    title += ` (${numberFormatter.format(filteredCount)} changes)`;
  } else {
    title += ` (${numberFormatter.format(filteredCount)} of ${numberFormatter.format(totalCount)} changes)`;
  }

  return title;
});

// Helper functions
function formatDate(date) {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  }).format(date);
}

function getFileName(filePath) {
  if (!filePath) return '';
  const parts = filePath.split(/[/\\]/);
  return parts[parts.length - 1];
}

function getChangeTypeClass(changeType) {
  if (!changeType) return 'unknown';
  const type = changeType.toLowerCase();
  if (type.includes('add')) return 'add';
  if (type.includes('edit')) return 'edit';
  if (type.includes('delete')) return 'delete';
  if (type.includes('merge')) return 'merge';
  return 'other';
}

function formatDateDisplay(date) {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  }).format(date);
}

// Select/clear contributor from legend
function selectAuthor(author) {
  const idx = selectedAuthors.value.indexOf(author);
  if (idx === -1) selectedAuthors.value.push(author);
  else selectedAuthors.value.splice(idx, 1);
  viewType.value = 'author';
}

function clearAuthor() {
  selectedAuthors.value = [];
  viewType.value = 'all';
}

// Handle drill-down period selection from the chart
function handlePeriodSelected(payload) {
  if (!payload || !payload.start || !payload.end) return;
  if (!sliderInitialized.value) initializeDateSlider();
  const min = Number(minDateTimestamp.value || -Infinity);
  const max = Number(maxDateTimestamp.value || Infinity);
  let s = Number(payload.start);
  let e = Number(payload.end);
  if (s < min) s = min;
  if (e > max) e = max;
  if (s > e) s = Math.max(min, Math.min(e, max));
  dateRange.value = [s, e];
  // clear selected sprint when drilling down
  selectedSprint.value = '';
  // If the chart suggests a new grouping (e.g., month->week, week->day), apply it
  if (payload.newGroup) {
    // update the chart grouping which is synced via `chartGroupBy` prop
    chartGroupBy.value = payload.newGroup;
  }
}


// Handle query parameters for filtering after data is loaded
function applyRouteFilters() {
  if (route.query.author && authors.value.includes(route.query.author)) {
    viewType.value = 'author';
    selectedAuthors.value = [route.query.author];
  } else if (route.query.product && products.value.includes(route.query.product)) {
    viewType.value = 'product';
    selectedProduct.value = route.query.product;
  }
}

// Initialize date slider after data is loaded
function initializeDateSlider() {
  if (sliderInitialized.value || !timelineData.value.length) return;

  const dates = timelineData.value.map(item => item.Date);
  const dataMinDate = new Date(Math.min(...dates));
  const dataMaxDate = new Date(Math.max(...dates));
  const today = new Date();

  // Use dataset since date if available, otherwise use data min date
  let minDate = dataMinDate;
  if (dateInfo.value && dateInfo.value.since) {
    const sinceDate = new Date(dateInfo.value.since);
    // Use since date but ensure it's not later than data min date
    minDate = sinceDate < dataMinDate ? sinceDate : dataMinDate;
  }

  // Use today or data max date, whichever is later
  let maxDate = dataMaxDate > today ? dataMaxDate : today;

  const minTimestamp = minDate.getTime();
  const maxTimestamp = maxDate.getTime();

  // Ensure we have a valid range
  if (minTimestamp >= maxTimestamp) {
    console.warn('Invalid date range, using fallback');
    const fallbackMin = new Date();
    fallbackMin.setDate(fallbackMin.getDate() - 30);
    minDateTimestamp.value = fallbackMin.getTime();
    maxDateTimestamp.value = today.getTime();
    dateRange.value = [fallbackMin.getTime(), today.getTime()];
  } else {
    minDateTimestamp.value = minTimestamp;
    maxDateTimestamp.value = maxTimestamp;

    // Set default selection: if we have a since date, use it to today, otherwise use full range
    let defaultStart = minTimestamp;
    let defaultEnd = maxTimestamp;

    if (dateInfo.value && dateInfo.value.since) {
      defaultStart = new Date(dateInfo.value.since).getTime();
      defaultEnd = today.getTime();
      // Ensure default end is within bounds
      if (defaultEnd > maxTimestamp) defaultEnd = maxTimestamp;
      if (defaultStart < minTimestamp) defaultStart = minTimestamp;
    }

    dateRange.value = [defaultStart, defaultEnd];
  }

  sliderInitialized.value = true;

  // Debug logging
  console.log('Date Range Initialized:', {
    minDate: new Date(minDateTimestamp.value).toISOString().split('T')[0],
    maxDate: new Date(maxDateTimestamp.value).toISOString().split('T')[0],
    defaultStart: new Date(dateRange.value[0]).toISOString().split('T')[0],
    defaultEnd: new Date(dateRange.value[1]).toISOString().split('T')[0],
    dataPoints: timelineData.value.length
  });
}

// Load data on mount
onMounted(async () => {
  // Load main data if not already loaded
  if (!store.data.length) {
    try {
      const csvResp = await fetch(getEnvironmentPath('/RawOwnershipReport', '.csv'));
      const csvText = await csvResp.text();
      const mapResp = await fetch(getEnvironmentPath('/author_mappings', '.json'));
      const mappingJson = await mapResp.json();
      await store.loadData(csvText, mappingJson);
      await store.loadTeams();
      await store.loadTeamColors();
    } catch (error) {
      console.error('Failed to load main data:', error);
    }
  } else {
    // Just load timeline data if main data is already loaded
    await store.loadTimelineData();
  }

  // Initialize date slider after data is loaded
  initializeDateSlider();

  // Apply route-based filters after data is loaded
  applyRouteFilters();
});

// Watch for view type changes to reset selections (but not when coming from route)
watch(viewType, (newType, oldType) => {
  // Only reset selections if it's a user-initiated change, not a route-based change
  if (oldType !== undefined) {
    if (newType === 'author') {
      selectedProduct.value = '';
    } else if (newType === 'product') {
      selectedAuthors.value = [];
    } else if (newType === 'all') {
      selectedAuthors.value = [];
      selectedProduct.value = '';
    }
  }
});

// Watch for route changes to apply new filters
watch(() => route.query, () => {
  applyRouteFilters();
}, { deep: true });

// Watch for timeline data to become available and initialize slider
watch(timelineData, (newData) => {
  if (newData.length > 0 && !sliderInitialized.value) {
    initializeDateSlider();
  }
}, { immediate: true });

// Ensure dateRange stays within min/max bounds if those change (prevents vue-slider errors)
watch([minDateTimestamp, maxDateTimestamp], ([min, max]) => {
  if (!min || !max) return;
  const s = Number(dateRange.value && dateRange.value[0]) || min;
  const e = Number(dateRange.value && dateRange.value[1]) || max;
  let newS = s;
  let newE = e;
  if (newS < Number(min)) newS = Number(min);
  if (newE > Number(max)) newE = Number(max);
  if (newS > newE) newS = newE;
  // Only update if different to avoid extra re-renders
  if (dateRange.value[0] !== newS || dateRange.value[1] !== newE) {
    dateRange.value = [newS, newE];
  }
}, { immediate: true });

</script>

<style scoped>
.timeline-view {
  max-width: 1920px;
  margin: 0 auto;
  padding: 1.5rem;
}

@media (min-width: 1920px) {
  .timeline-view {
    max-width: 95vw;
  }
}

.timeline-header {
  @apply bg-gradient-to-r from-brand-blue via-brand-blue-light to-brand-teal
         text-white shadow-lg rounded-xl p-6 mb-6;
  display: flex;
  justify-content: space-between;
  align-items: center;
  animation: fadeIn 0.3s ease-in-out;
}

.timeline-header-actions {
  display: flex;
  gap: 0.75rem;
  align-items: center;
}

.settings-icon-btn {
  @apply bg-white/10 backdrop-blur-sm text-white rounded-lg transition-all border-2 border-white/30 flex items-center justify-center;
  padding: 0.75rem;
  width: 44px;
  height: 44px;
}

.settings-icon-btn:hover {
  @apply bg-white/20;
}

.timeline-title {
  margin: 0;
  font-size: 1.8em;
  color: white;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 700;
}

.back-btn {
  cursor: pointer;
  color: white;
  font-size: 1.2em;
  padding: 0.4rem 0.8rem;
  border-radius: 8px;
  transition: all 0.2s;
  background: rgba(255, 255, 255, 0.1);
}

.back-btn:hover {
  background: rgba(255, 255, 255, 0.2);
  transform: translateX(-2px);
}

.date-range {
  font-size: 0.6em;
  color: rgba(255, 255, 255, 0.9);
  font-weight: normal;
}

.timeline-stats {
  display: flex;
  gap: 2rem;
}

.stat-item {
  text-align: center;
}

.stat-value {
  @apply font-mono;
  display: block;
  font-size: 1.8em;
  font-weight: bold;
  color: white;
}

.stat-label {
  display: block;
  font-size: 0.9em;
  color: rgba(255, 255, 255, 0.9);
  font-weight: 500;
}

.timeline-filters {
  @apply bg-white rounded-xl shadow-md p-6 border-2 border-gray-100
         transition-all duration-300 hover:shadow-xl;
  margin-bottom: 2rem;
  display: flex;
  flex-wrap: wrap;
  gap: 1.5rem;
  align-items: end;
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}

.date-range-group {
  min-width: 300px;
}

.filter-group label {
  font-weight: 600;
  font-size: 0.9em;
  color: #333;
}

.filter-select,
.filter-input {
  padding: 0.4rem 0.8rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 0.9em;
  min-width: 150px;
}

.date-slider-container {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.date-range-display {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9em;
  font-weight: 500;
  justify-content: center;
}

.date-display {
  background: #f0f6ff;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  color: #1f77b4;
  min-width: 70px;
  text-align: center;
}

.date-separator {
  color: #666;
}

.loading-display {
  display: flex;
  align-items: center;
  justify-content: center;
  font-style: italic;
  color: #666;
  min-height: 2rem;
}


.date-labels {
  display: flex;
  justify-content: space-between;
  font-size: 0.8em;
  color: #666;
  margin-top: 0.2rem;
}

.date-label-min,
.date-label-max {
  font-size: 0.75em;
}

.timeline-content {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.no-data {
  text-align: center;
  padding: 3rem;
  color: #666;
  background: #f8f9fa;
  border-radius: 8px;
}

.main-timeline-chart {
  margin-bottom: 0;
}

.timeline-table-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  padding: 1.5rem;
}

.timeline-table-container h3 {
  margin: 0 0 1rem 0;
  color: #333;
}

.table-wrapper {
  overflow-x: auto;
}

.timeline-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9em;
}

.timeline-table th {
  background: #f8f9fa;
  padding: 0.8rem;
  text-align: left;
  font-weight: 600;
  border-bottom: 2px solid #dee2e6;
  color: #495057;
}

.timeline-table td {
  padding: 0.6rem 0.8rem;
  border-bottom: 1px solid #dee2e6;
  vertical-align: middle;
}

.timeline-table tr:hover {
  background: #f8f9fa;
}

.date-cell {
  min-width: 140px;
  font-family: monospace;
  font-size: 0.85em;
}

.author-cell {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-width: 120px;
}

.author-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.product-cell {
  font-weight: 500;
  min-width: 80px;
}

.change-type-cell {
  min-width: 80px;
}

.change-badge {
  padding: 0.2rem 0.5rem;
  border-radius: 12px;
  font-size: 0.8em;
  font-weight: 500;
  text-transform: capitalize;
}

.change-badge.add {
  background: #d4edda;
  color: #155724;
}

.change-badge.edit {
  background: #fff3cd;
  color: #856404;
}

.change-badge.delete {
  background: #f8d7da;
  color: #721c24;
}

.change-badge.merge {
  background: #d1ecf1;
  color: #0c5460;
}

.change-badge.other,
.change-badge.unknown {
  background: #e2e3e5;
  color: #383d41;
}

.file-cell {
  max-width: 250px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: monospace;
  font-size: 0.85em;
}

.source-cell {
  min-width: 60px;
}

.source-badge {
  padding: 0.15rem 0.4rem;
  border-radius: 8px;
  font-size: 0.75em;
  font-weight: 600;
  text-transform: uppercase;
}

.source-badge.tfs {
  background: #e3f2fd;
  color: #1565c0;
}

.source-badge.git {
  background: #f3e5f5;
  color: #7b1fa2;
}

.contributor-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin: 1rem 0 1.5rem 0;
}

.contributor-pill {
  display: inline-block;
  padding: 0.3rem 0.8rem;
  border-radius: 16px;
  font-size: 0.9em;
  font-weight: 600;
  cursor: pointer;
  color: #000;
  background: #bbb;
  transition: box-shadow 0.12s, transform 0.08s;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
  border: 2px solid transparent;
}

.contributor-pill:hover {
  transform: translateY(-1px);
}

.contributor-pill.selected {
  border-color: rgba(0, 0, 0, 0.08);
  box-shadow: 0 6px 18px rgba(31, 119, 180, 0.12);
}

.contributor-pill.all-pill {
  background: #e9ecef;
  color: #000;
}

/* Reuse pill styles similar to FilterPanel for consistent appearance */
.pill {
  border: 2.5px solid #bbb;
  background: #f8f9fa;
  border-radius: 999px;
  padding: 0.3em 0.9em;
  font-size: 0.95em;
  cursor: pointer;
  transition: background 0.15s, border 0.15s, color 0.15s;
  outline: none;
  color: #000;
}

.pill.selected {
  border-width: 3.5px;
}

.pill:focus {
  box-shadow: 0 0 0 2px #1f77b4aa;
}

.quick-range-buttons {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  margin-bottom: 0.6rem;
  flex-wrap: wrap;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .timeline-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 1rem;
  }

  .timeline-stats {
    width: 100%;
    justify-content: space-around;
  }

  .timeline-filters {
    flex-direction: column;
    align-items: stretch;
  }

  .filter-group {
    width: 100%;
  }

  .filter-select,
  .filter-input {
    min-width: auto;
    width: 100%;
  }

  .date-range-group {
    min-width: auto;
    width: 100%;
  }

  .date-range-display {
    flex-direction: column;
    gap: 0.3rem;
  }

  .date-display {
    min-width: auto;
  }
}
</style>