<template>
  <!-- Floating Toggle Button (always visible) -->
  <button
    class="floating-filter-toggle"
    @click="panelOpen = true"
    v-if="!panelOpen"
    :title="'Show Filters' + (activeFilterCount > 0 ? ' (' + activeFilterCount + ' active)' : '')"
  >
    <span class="toggle-icon-large">🔍</span>
    <span class="toggle-text">Filters</span>
    <span class="floating-badge" v-if="activeFilterCount > 0">{{ activeFilterCount }}</span>
  </button>

  <!-- Backdrop Overlay -->
  <transition name="backdrop-fade">
    <div
      v-if="panelOpen"
      class="filter-backdrop"
      @click="panelOpen = false"
    ></div>
  </transition>

  <!-- Slide-out Filter Panel -->
  <transition name="slide-panel">
    <div v-if="panelOpen" class="filter-panel-overlay">
      <div class="filter-panel-header">
        <h2 class="panel-title">
          <span class="panel-icon">🔍</span>
          Filters & Analytics
        </h2>
        <button class="panel-close-btn" @click="panelOpen = false" title="Close filters (ESC)">
          ✕
        </button>
      </div>

      <div class="filter-panel-content">
        <!-- Summary Card at Top -->
    <div class="summary-card">
      <div class="summary-stat">
        <div class="summary-icon">📊</div>
        <div class="summary-content">
          <div class="summary-value">{{ totalContributions.toLocaleString() }}</div>
          <div class="summary-label">Contributions</div>
        </div>
      </div>
      <div class="summary-stat">
        <div class="summary-icon">📦</div>
        <div class="summary-content">
          <div class="summary-value">{{ productCount }}</div>
          <div class="summary-label">Products</div>
        </div>
      </div>
      <div class="summary-stat">
        <div class="summary-icon">👤</div>
        <div class="summary-content">
          <div class="summary-value">{{ authorCount }}</div>
          <div class="summary-label">Authors</div>
        </div>
      </div>
    </div>

    <!-- Active Filter Chips with Clear All Button -->
    <div v-if="hasActiveFilters" class="active-filters-section">
      <div class="active-filters-chips">
        <span class="chips-label">Active:</span>

        <!-- Team chips -->
        <button
          v-for="team in selectedTeams"
          :key="'team-' + team"
          class="filter-chip team-chip"
          @click="toggleTeam(teamsWithColor.find(t => t.name === team))"
          :title="'Remove team filter: ' + team"
        >
          {{ team }} ×
        </button>

        <!-- Product chips (show first 3, then count) -->
        <button
          v-for="(product, idx) in selectedProducts.slice(0, 3)"
          :key="'product-' + product"
          class="filter-chip product-chip"
          @click="toggleProduct(product)"
          :title="'Remove product filter: ' + product"
        >
          {{ product }} ×
        </button>
        <span v-if="selectedProducts.length > 3" class="filter-chip-count">
          +{{ selectedProducts.length - 3 }} more products
        </span>

        <!-- Author chips (show first 3, then count) -->
        <button
          v-for="(author, idx) in selectedAuthors.slice(0, 3)"
          :key="'author-' + author"
          class="filter-chip author-chip"
          @click="toggleAuthor(author)"
          :title="'Remove author filter: ' + author"
        >
          {{ author }} ×
        </button>
        <span v-if="selectedAuthors.length > 3" class="filter-chip-count">
          +{{ selectedAuthors.length - 3 }} more authors
        </span>

        <!-- VCS chips -->
        <button
          v-for="vcs in selectedVcs"
          :key="'vcs-' + vcs"
          :class="['filter-chip', 'vcs-chip-' + vcs]"
          @click="toggleVcs(vcs)"
          :title="'Remove VCS filter: ' + vcs.toUpperCase()"
        >
          {{ vcs.toUpperCase() }} ×
        </button>

        <!-- Min percent chip -->
        <span v-if="minPercent > 0" class="filter-chip percent-chip">
          Min {{ minPercent }}%
        </span>
      </div>

      <!-- Clear All Button -->
      <button class="clear-all-btn" @click="clearFilters" title="Clear all active filters">
        Clear All
      </button>
    </div>

    <!-- Filter Groups -->
    <div class="space-y-5">
        <!-- Quick Filters - Only show in product view -->
        <div v-if="chartMode === 'product'" class="quick-filters-section">
          <div class="filter-group">
            <span class="filter-label">⚡ Quick Filters:</span>
            <div class="quick-filters-grid">
              <button
                class="quick-filter-card high-risk"
                @click="applySingleContributorFilter"
                :disabled="singleContributorProducts.length === 0"
                :title="'Show products with only one significant contributor (Bus Factor = 1)'"
              >
                <div class="qf-icon">🚨</div>
                <div class="qf-content">
                  <div class="qf-title">High Risk</div>
                  <div class="qf-count">{{ singleContributorProducts.length }}</div>
                  <div class="qf-subtitle">Single contributor</div>
                </div>
              </button>

              <button
                class="quick-filter-card multi-team"
                @click="applyMultiTeamFilter"
                :disabled="multiTeamProducts.length === 0"
                :title="'Show products with contributors from multiple teams'"
              >
                <div class="qf-icon">👥</div>
                <div class="qf-content">
                  <div class="qf-title">Multi-Team</div>
                  <div class="qf-count">{{ multiTeamProducts.length }}</div>
                  <div class="qf-subtitle">Cross-team products</div>
                </div>
              </button>

              <button
                class="quick-filter-card top-active"
                @click="applyTopActiveFilter"
                :disabled="topActiveProducts.length === 0"
                :title="'Show top 10% most active products by contribution count'"
              >
                <div class="qf-icon">🔥</div>
                <div class="qf-content">
                  <div class="qf-title">Most Active</div>
                  <div class="qf-count">{{ topActiveProducts.length }}</div>
                  <div class="qf-subtitle">Top 10%</div>
                </div>
              </button>

            </div>
          </div>
        </div>

        <!-- 1. Teams (high-level grouping) -->
        <div class="filter-group">
          <span class="filter-label">👥 Teams:</span>
          <div class="pills">
            <button
              v-for="team in teamsWithColor"
              :key="team.name"
              :class="['pill', { selected: selectedTeams.includes(team.name) }]"
              @click="toggleTeam(team)"
              :style="selectedTeams.includes(team.name) ? { background: team.color, color: '#fff', borderColor: team.color } : { borderColor: team.color }"
            >
              {{ team.name }}
            </button>
          </div>
        </div>

        <!-- 2. Min Contribution % (affects all views) -->
        <div class="filter-group slider-group">
          <span class="filter-label">📊 Min Contribution %:</span>
          <div class="slider-container">
            <input type="range" v-model.number="minPercent" min="0" max="100" class="slider" />
            <span class="slider-value">{{ minPercent }}%</span>
          </div>
        </div>

        <!-- 3. Products (what to analyze) -->
        <div class="filter-group">
          <span class="filter-label">📦 Products:</span>
          <input
            v-model="productSearch"
            type="text"
            placeholder="🔍 Search products..."
            class="search-input mb-2"
          />
          <div class="pills">
            <button
              v-for="p in filteredProducts"
              :key="p"
              :class="['pill', { selected: selectedProducts.includes(p) }]"
              @click="toggleProduct(p)"
              :style="selectedProducts.includes(p) ? { background: productTeamColor(p), color: '#fff', borderColor: productTeamColor(p) } : {}"
            >
              {{ p }}
            </button>
          </div>
          <p v-if="filteredProducts.length === 0" class="text-sm text-gray-500 mt-2">No products match your search</p>
        </div>

        <!-- 4. Version Control (product attribute) -->
        <div v-if="chartMode === 'product'" class="filter-group">
          <span class="filter-label">🔧 Version Control:</span>
          <div class="pills">
            <button
              v-for="opt in vcsOptions"
              :key="opt.value"
              :class="['pill', { selected: selectedVcs.includes(opt.value) }, selectedVcs.includes(opt.value) ? ('vcs-' + opt.value) : 'vcs-default']"
              @click="toggleVcs(opt.value)"
            >
              {{ opt.label }}
            </button>
          </div>
        </div>

        <!-- 5. Authors (who to analyze) -->
        <div class="filter-group">
          <span class="filter-label">👤 Authors:</span>
          <input
            v-model="authorSearch"
            type="text"
            placeholder="🔍 Search authors..."
            class="search-input mb-2"
          />
          <div class="pills">
            <button
              v-for="a in filteredAuthors"
              :key="a"
              :class="['pill', { selected: selectedAuthors.includes(a) }]"
              @click="toggleAuthor(a)"
              :style="authorColors[a] ? {
                background: selectedAuthors.includes(a) ? authorColors[a] : '#f8f9fa',
                color: selectedAuthors.includes(a) ? '#fff' : '#222',
                borderColor: authorColors[a]
              } : {}"
            >
              {{ a }}
            </button>
          </div>
          <p v-if="filteredAuthors.length === 0" class="text-sm text-gray-500 mt-2">No authors match your search</p>
        </div>
      </div>
    </div>
    </div>
  </transition>
</template>

<script setup>
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';
import { computed, ref, watch, onMounted, onUnmounted } from 'vue';

const store = useOwnershipStore();
const { data, filters, authorColors, totalContributions, productCount, authorCount, teams, chartMode, singleContributorProducts, multiTeamProducts, topActiveProducts, productVcsMap, teamColors } = storeToRefs(store);
const { setProducts, setAuthors, setMinPercent, loadTeams, setVcs } = store;

const teamsWithColor = computed(() => (teams.value || []).map(team => ({
  ...team,
  color: teamColors.value?.[team.name] || '#bbb'
})));
onMounted(async () => {
  loadTeams();
});

const products = computed(() => [...new Set(data.value.map(r => r.Product))].sort((a, b) => a.localeCompare(b)));
const authors = computed(() => [...new Set(data.value.map(r => r.Author))].sort((a, b) => a.localeCompare(b)));

const selectedProducts = ref([...filters.value.products]);
const selectedAuthors = ref([...filters.value.authors]);
const selectedVcs = ref([...filters.value.vcs]);
const minPercent = ref(filters.value.minPercent);
const selectedTeams = ref([]);

// Search states
const productSearch = ref('');
const authorSearch = ref('');

// Filtered lists based on search
const filteredProducts = computed(() => {
  if (!productSearch.value.trim()) return products.value;
  const searchLower = productSearch.value.toLowerCase();
  return products.value.filter(p => p.toLowerCase().includes(searchLower));
});

const filteredAuthors = computed(() => {
  if (!authorSearch.value.trim()) return authors.value;
  const searchLower = authorSearch.value.toLowerCase();
  return authors.value.filter(a => a.toLowerCase().includes(searchLower));
});

// Panel open/closed state - start closed for better initial view (shows charts first)
const panelOpen = ref(false);

// Handle ESC key to close panel
function handleKeyDown(event) {
  if (event.key === 'Escape' && panelOpen.value) {
    panelOpen.value = false;
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeyDown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown);
});

// Keep pills in sync with store filters (for external changes)
watch(
  () => filters.value.products,
  (val) => { selectedProducts.value = [...val]; }
);
watch(
  () => filters.value.authors,
  (val) => { selectedAuthors.value = [...val]; }
);
watch(
  () => filters.value.vcs,
  (val) => { selectedVcs.value = [...val]; }
);
watch(
  () => filters.value.minPercent,
  (val) => { minPercent.value = val; }
);

const productTeamColor = (product) => {
  const team = teamsWithColor.value.find(t => t.products.includes(product));
  return team ? team.color : '#1f77b4';
};

const vcsOptions = computed(() => [
  { value: 'git', label: 'Git' },
  { value: 'tfs', label: 'TFS' }
]);

function toggleVcs(v) {
  const idx = selectedVcs.value.indexOf(v);
  if (idx === -1) selectedVcs.value.push(v);
  else selectedVcs.value.splice(idx, 1);
  setVcs(selectedVcs.value);
}

// Check if any filters are currently active
const hasActiveFilters = computed(() => {
  return selectedProducts.value.length > 0 ||
         selectedAuthors.value.length > 0 ||
         selectedTeams.value.length > 0 ||
         selectedVcs.value.length > 0 ||
         minPercent.value > 0;
});

// Count active filters for badge
const activeFilterCount = computed(() => {
  let count = 0;
  if (selectedTeams.value.length > 0) count++;
  if (selectedProducts.value.length > 0) count++;
  if (selectedAuthors.value.length > 0) count++;
  if (selectedVcs.value.length > 0) count++;
  if (minPercent.value > 0) count++;
  return count;
});

function toggleProduct(p) {
  const idx = selectedProducts.value.indexOf(p);
  if (idx === -1) selectedProducts.value.push(p);
  else selectedProducts.value.splice(idx, 1);
  setProducts(selectedProducts.value);
}
function toggleAuthor(a) {
  const idx = selectedAuthors.value.indexOf(a);
  if (idx === -1) selectedAuthors.value.push(a);
  else selectedAuthors.value.splice(idx, 1);
  setAuthors(selectedAuthors.value);
}
function toggleTeam(team) {
  const idx = selectedTeams.value.indexOf(team.name);
  if (idx === -1) {
    selectedTeams.value.push(team.name);
    // Add team authors/products to filters (union)
    const newAuthors = Array.from(new Set([...selectedAuthors.value, ...team.authors]));
    const newProducts = Array.from(new Set([...selectedProducts.value, ...team.products]));
    setAuthors(newAuthors);
    setProducts(newProducts);
  } else {
    selectedTeams.value.splice(idx, 1);
    // Remove team authors/products from filters (but keep others)
    const teamAuthors = new Set(team.authors);
    const teamProducts = new Set(team.products);
    setAuthors(selectedAuthors.value.filter(a => !teamAuthors.has(a)));
    setProducts(selectedProducts.value.filter(p => !teamProducts.has(p)));
  }
}

watch(minPercent, (val) => {
  setMinPercent(val);
});

function clearFilters() {
  setProducts([]);
  setAuthors([]);
  setMinPercent(0);
  selectedTeams.value = [];
  selectedVcs.value = [];
  setVcs([]);
  selectedProducts.value = [];
  selectedAuthors.value = [];
}

function applySingleContributorFilter() {
  // Clear current filters and apply the single contributor products filter
  setAuthors([]);
  selectedTeams.value = [];
  setProducts([...singleContributorProducts.value]);
}

function applyMultiTeamFilter() {
  // Clear current filters and show multi-team products
  setAuthors([]);
  selectedTeams.value = [];
  setProducts([...multiTeamProducts.value]);
}

function applyTopActiveFilter() {
  // Clear current filters and show top active products
  setAuthors([]);
  selectedTeams.value = [];
  setProducts([...topActiveProducts.value]);
}
</script>

<style scoped>
:root {
  --vcs-git: #088F9B;
  --vcs-tfs: #F08223;
  --vcs-unknown: #6c757d;
  --panel-width: 480px;
}

/* Floating Toggle Button */
.floating-filter-toggle {
  @apply fixed left-6 bottom-6 z-40
         bg-gradient-to-r from-brand-blue to-brand-teal text-white
         rounded-full shadow-2xl px-6 py-4
         font-bold text-base cursor-pointer
         transition-all duration-300
         hover:shadow-[0_20px_40px_rgba(34,94,169,0.4)]
         hover:scale-110 active:scale-100
         flex items-center gap-3;
}

.toggle-icon-large {
  @apply text-2xl;
}

.toggle-text {
  @apply font-semibold;
}

.floating-badge {
  @apply bg-brand-orange text-white text-xs font-bold
         px-2.5 py-1 rounded-full ml-1;
}

/* Backdrop Overlay */
.filter-backdrop {
  @apply fixed inset-0 bg-black/50 backdrop-blur-sm z-40;
}

.backdrop-fade-enter-active,
.backdrop-fade-leave-active {
  transition: opacity 0.3s ease;
}

.backdrop-fade-enter-from,
.backdrop-fade-leave-to {
  opacity: 0;
}

/* Slide-out Panel */
.filter-panel-overlay {
  @apply fixed left-0 top-0 bottom-0 z-50
         bg-white shadow-2xl
         flex flex-col;
  width: var(--panel-width);
  max-width: 90vw;
}

.slide-panel-enter-active,
.slide-panel-leave-active {
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-panel-enter-from,
.slide-panel-leave-to {
  transform: translateX(-100%);
}

/* Panel Header */
.filter-panel-header {
  @apply bg-gradient-to-r from-brand-blue via-brand-blue-light to-brand-teal
         text-white px-6 py-5 flex items-center justify-between
         shadow-lg flex-shrink-0;
}

.panel-title {
  @apply text-2xl font-bold m-0 flex items-center gap-3;
}

.panel-icon {
  @apply text-3xl;
}

.panel-close-btn {
  @apply text-white hover:bg-white/20 rounded-full w-10 h-10
         flex items-center justify-center text-2xl font-bold
         transition-all duration-200 hover:scale-110 cursor-pointer;
}

/* Panel Content */
.filter-panel-content {
  @apply flex-1 overflow-y-auto p-6;
  scrollbar-width: thin;
  scrollbar-color: rgba(34, 94, 169, 0.3) transparent;
}

.filter-panel-content::-webkit-scrollbar {
  width: 8px;
}

.filter-panel-content::-webkit-scrollbar-track {
  background: transparent;
}

.filter-panel-content::-webkit-scrollbar-thumb {
  background: rgba(34, 94, 169, 0.3);
  border-radius: 4px;
}

.filter-panel-content::-webkit-scrollbar-thumb:hover {
  background: rgba(34, 94, 169, 0.5);
}

/* Summary Card */
.summary-card {
  @apply bg-gradient-to-r from-brand-blue via-brand-blue-light to-brand-teal
         rounded-xl p-4 mb-4 grid grid-cols-3 gap-3 shadow-lg;
}

.summary-stat {
  @apply flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-lg p-3;
}

.summary-icon {
  @apply text-3xl;
}

.summary-content {
  @apply flex flex-col;
}

.summary-value {
  @apply text-2xl font-bold text-white font-mono;
}

.summary-label {
  @apply text-xs text-white/90 font-medium uppercase tracking-wide;
}

/* Active Filter Section */
.active-filters-section {
  @apply mt-3 flex items-start gap-3;
}

.active-filters-chips {
  @apply flex flex-wrap items-center gap-2 p-3 bg-blue-50 rounded-lg border border-blue-200 flex-1;
}

.clear-all-btn {
  @apply bg-red-600 text-white font-bold px-4 py-3 rounded-lg
         cursor-pointer transition-all duration-200
         hover:bg-red-700 hover:shadow-lg hover:scale-105 active:scale-95
         whitespace-nowrap flex-shrink-0;
}

.chips-label {
  @apply text-xs font-semibold text-brand-blue uppercase tracking-wide mr-1;
}

.filter-chip {
  @apply px-3 py-1 rounded-full text-xs font-medium border-2 transition-all duration-200
         hover:shadow-md hover:-translate-y-0.5 cursor-pointer;
}

.filter-chip.team-chip {
  @apply bg-brand-blue text-white border-brand-blue hover:bg-brand-blue-dark;
}

.filter-chip.product-chip {
  @apply bg-brand-teal text-white border-brand-teal hover:bg-brand-teal/80;
}

.filter-chip.author-chip {
  @apply bg-purple-600 text-white border-purple-600 hover:bg-purple-700;
}

.filter-chip.vcs-chip-git {
  @apply bg-teal-600 text-white border-teal-600 hover:bg-teal-700;
}

.filter-chip.vcs-chip-tfs {
  @apply bg-orange-600 text-white border-orange-600 hover:bg-orange-700;
}

.filter-chip.percent-chip {
  @apply bg-gray-600 text-white border-gray-600 cursor-default;
}

.filter-chip-count {
  @apply px-2 py-1 text-xs font-medium text-gray-600 bg-gray-200 rounded-full;
}

.filter-group {
  @apply flex flex-col gap-1.5;
}

.filter-label {
  @apply text-sm font-semibold text-gray-700 mb-1;
}

.pills {
  @apply flex flex-wrap gap-2;
}

.pill {
  @apply border-2 border-gray-300 bg-gray-50 rounded-full px-4 py-1.5 text-sm font-medium
         cursor-pointer transition-all duration-200 hover:border-brand-blue hover:bg-blue-50
         hover:shadow-md hover:-translate-y-0.5;
}

.pill:active {
  @apply scale-95 translate-y-0;
}

.pill.selected {
  @apply border-[3px] shadow-md transform scale-105;
  animation: pillSelect 0.2s ease-out;
}

@keyframes pillSelect {
  0% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.1);
  }
  100% {
    transform: scale(1.05);
  }
}

/* Version Control pills */
.pill.selected.vcs-git {
  background: var(--vcs-git) !important;
  color: #fff !important;
  border-color: var(--vcs-git) !important;
}

.pill.selected.vcs-tfs {
  background: var(--vcs-tfs) !important;
  color: #fff !important;
  border-color: var(--vcs-tfs) !important;
}

.pill.selected.vcs-default {
  background: var(--vcs-unknown) !important;
  color: #fff !important;
  border-color: var(--vcs-unknown) !important;
}

.pill:focus {
  @apply ring-2 ring-brand-blue/40 outline-none;
}

.slider-group {
  @apply w-full max-w-sm;
}

.slider-container {
  @apply flex items-center gap-4 py-2;
}

.slider {
  @apply flex-1 h-2 bg-gray-200 rounded-md outline-none appearance-none;
}

.slider::-webkit-slider-thumb {
  @apply appearance-none w-5 h-5 bg-brand-blue rounded-full cursor-pointer transition-colors;
}

.slider::-webkit-slider-thumb:hover {
  @apply bg-brand-blue-dark;
}

.slider::-moz-range-thumb {
  @apply w-5 h-5 bg-brand-blue border-0 rounded-full cursor-pointer transition-colors;
}

.slider::-moz-range-thumb:hover {
  @apply bg-brand-blue-dark;
}

.slider-value {
  @apply min-w-[3.5em] text-sm font-semibold text-gray-700;
}

.quick-filters-section {
  @apply pb-4 mb-4 border-b-2 border-gray-200;
}

.quick-filters-grid {
  @apply grid gap-3;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
}

.quick-filter-card {
  @apply bg-white border-2 rounded-lg p-3 transition-all duration-200
         hover:shadow-lg hover:-translate-y-1 cursor-pointer
         flex items-center gap-2;
}

.quick-filter-card:active {
  @apply scale-95 translate-y-0;
}

.quick-filter-card:disabled {
  @apply opacity-40 cursor-not-allowed hover:shadow-none hover:translate-y-0;
}

.quick-filter-card.high-risk {
  @apply border-red-400 hover:border-red-500 hover:bg-red-50;
}

.quick-filter-card.multi-team {
  @apply border-purple-400 hover:border-purple-500 hover:bg-purple-50;
}

.quick-filter-card.top-active {
  @apply border-orange-400 hover:border-orange-500 hover:bg-orange-50;
}

.qf-icon {
  @apply text-2xl flex-shrink-0;
}

.qf-content {
  @apply flex flex-col min-w-0;
}

.qf-title {
  @apply text-xs font-bold text-gray-700 uppercase tracking-wide;
}

.qf-count {
  @apply text-xl font-bold text-brand-blue font-mono;
}

.qf-subtitle {
  @apply text-xs text-gray-500;
}

.search-input {
  @apply w-full px-4 py-2.5 text-sm border-2 border-gray-300 rounded-lg
         focus:outline-none focus:ring-2 focus:ring-brand-blue/40 focus:border-brand-blue
         transition-all duration-200 placeholder-gray-400;
}

.search-input:hover {
  @apply border-gray-400;
}
</style>
