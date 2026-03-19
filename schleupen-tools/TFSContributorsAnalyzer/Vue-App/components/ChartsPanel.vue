<template>
  <div class="charts-panel">
    <!-- Unified Control Card -->
    <div class="control-card">
      <!-- Main Mode Tabs -->
      <div class="mode-tabs">
        <button
          :class="['mode-tab', { 'active': chartMode === 'product' }]"
          @click="switchToProductMode"
        >
          📦 By Product
        </button>
        <button
          :class="['mode-tab', { 'active': chartMode === 'author' }]"
          @click="switchToAuthorMode"
        >
          👤 By Author
        </button>
        <button
          :class="['mode-tab', { 'active': chartMode === 'zscore' }]"
          @click="switchToZScoreMode"
        >
          📊 Z-Score Analysis
        </button>
      </div>

    </div>

    <!-- Content Area -->
    <div :class="{ 'pie-charts': chartMode !== 'zscore', 'zscore-chart': chartMode === 'zscore' }">
      <template v-if="chartMode === 'product'">
        <div v-for="product in productsWithAuthors" :key="product" class="pie-card">
          <PieChart :product="product" @authorClick="handleAuthorClick" @showTimeline="handleShowProductTimeline" />
        </div>
      </template>
      <template v-else-if="chartMode === 'author'">
        <div v-for="author in authorsWithContributions" :key="author" class="pie-card">
          <AuthorDonutChart :author="author" @productClick="handleProductClick" @showTimeline="handleShowAuthorTimeline" />
        </div>
      </template>
      <template v-else>
        <div class="zscore-container">
          <ContributionZScoreChart />
        </div>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';
import PieChart from './PieChart.vue';
import AuthorDonutChart from './AuthorDonutChart.vue';
import ContributionZScoreChart from './ContributionZScoreChart.vue';
import { useRouter } from 'vue-router';

const store = useOwnershipStore();
const router = useRouter();
const { filters, data, filteredData, productFilteredContributions, chartMode } = storeToRefs(store);

// Get all available products
const allProducts = computed(() => {
  const products = [...new Set(data.value.map(r => r.Product))];
  const productsToShow = filters.value.products.length ? filters.value.products : products;
  return productsToShow;
});

// Only include products that have contributions after all filters (author selection, min percent)
const productsWithAuthors = computed(() => {
  const contributions = productFilteredContributions.value || {};
  
  // Filter products that have non-zero contributions after all filters
  const products = allProducts.value.filter(product => {
    return (contributions[product] || 0) > 0;
  });
  
  // Sort by filtered contributions
  return products.sort((a, b) => {
    return (contributions[b] || 0) - (contributions[a] || 0);
  });
});

// Authors with actual contributions after filtering and min percent threshold
const authorsWithContributions = computed(() => {
  const contributions = productFilteredContributions.value || {};
  
  // Get all products that have contributions after filtering
  const activeProducts = Object.entries(contributions)
    .filter(([_, count]) => count > 0)
    .map(([product]) => product);

  // Get author contributions for these products
  const authorContributions = {};
  activeProducts.forEach(product => {
    const productData = filteredData.value.filter(r => r.Product === product);
    const total = productData.reduce((sum, r) => sum + r.ContributionCount, 0);

    productData.forEach(r => {
      // Only count if author meets the threshold
      if ((r.ContributionCount / total * 100) >= filters.value.minPercent) {
        if (!authorContributions[r.Author]) {
          authorContributions[r.Author] = new Set();
        }
        authorContributions[r.Author].add(product);
      }
    });
  });

  // Get authors who have any contributions meeting the threshold
  const authors = Object.keys(authorContributions);

  // Sort by number of products they have significant contributions in
  return authors.sort((a, b) => {
    return authorContributions[b].size - authorContributions[a].size;
  });
});

// Handle author click from pie chart
function handleAuthorClick(author) {
  // Switch to author view
  store.setChartMode('author');
  
  // Clear existing filters and set only the clicked author
  store.setProducts([]);
  store.setAuthors([author]);
}

// Handle product click from author donut chart
function handleProductClick(product) {
  // Switch to product view
  store.setChartMode('product');
  
  // Clear existing filters and set only the clicked product
  store.setAuthors([]);
  store.setProducts([product]);
}

// Handle timeline display - navigate to timeline route
function handleShowAuthorTimeline(author) {
  // Navigate to timeline route with author filter
  router.push({ name: 'Timeline', query: { author } });
}

function handleShowProductTimeline(product) {
  // Navigate to timeline route with product filter
  router.push({ name: 'Timeline', query: { product } });
}

// Handle mode switching functions
function switchToProductMode() {
  store.setChartMode('product');
}

function switchToAuthorMode() {
  store.setChartMode('author');
}

function switchToZScoreMode() {
  // Switch to z-score view and reset all filters
  store.setChartMode('zscore');
  store.setProducts([]);
  store.setAuthors([]);
}
</script>

<style scoped>
.charts-panel {
  @apply flex flex-col gap-6;
}

/* Unified Control Card */
.control-card {
  @apply bg-white rounded-xl shadow-md border-2 border-gray-100 p-4
         transition-all duration-300 hover:shadow-lg;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 1rem;
}

/* Mode Tabs */
.mode-tabs {
  @apply flex gap-1 bg-gray-100 rounded-lg p-1;
  flex: 1;
  min-width: fit-content;
}

.mode-tab {
  @apply px-4 py-2.5 font-semibold rounded-lg transition-all duration-200;
  flex: 1;
  white-space: nowrap;
  color: #6b7280;
}

.mode-tab:hover:not(.active) {
  @apply bg-gray-200;
}

.mode-tab.active {
  @apply bg-gradient-to-r from-brand-blue to-brand-blue-light text-white shadow-md;
  transform: scale(1.02);
}

.pie-charts {
  display: grid;
  gap: 1.5rem;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
}

@media (min-width: 1400px) {
  .pie-charts {
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  }
}

@media (min-width: 1920px) {
  .pie-charts {
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  }
}

.zscore-chart {
  @apply flex justify-center items-start p-4;
}

.zscore-container {
  @apply bg-white rounded-xl shadow-lg p-5 border-2 border-gray-100 hover:shadow-xl transition-shadow duration-200;
}

.pie-card {
  @apply bg-white rounded-xl shadow-md hover:shadow-xl pb-2
         flex flex-col items-center
         border-2 border-gray-100 transition-all duration-300 hover:border-brand-blue/30
         hover:-translate-y-1;
  animation: slideUp 0.4s ease-out;
  padding: 1.5rem 1rem 0.5rem 1rem;
  overflow: visible;
  width: 100%;
  /* Grid item takes full width of its column */
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

/* Info content styles for nested elements */
.charts-panel h3 {
  @apply text-brand-blue text-lg font-semibold mb-3 mt-0;
}

.charts-panel h4 {
  @apply text-gray-700 font-semibold text-base mt-5 mb-2;
}

.charts-panel p {
  @apply mb-4 text-gray-600;
}

.charts-panel ul,
.charts-panel ol {
  @apply mb-4 pl-6 text-gray-600;
}

.charts-panel li {
  @apply mb-2;
}

.charts-panel strong {
  @apply text-gray-800 font-semibold;
}

/* Modal Styles */
.modal-overlay {
  @apply fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4;
}

.modal-content {
  @apply bg-white rounded-2xl shadow-2xl max-w-3xl w-full max-h-[90vh] overflow-hidden;
  animation: modalSlideIn 0.3s ease-out;
}

@keyframes modalSlideIn {
  from {
    opacity: 0;
    transform: translateY(-20px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

.modal-header {
  @apply bg-gradient-to-r from-brand-blue to-brand-teal text-white p-6 flex items-center justify-between;
}

.modal-header h2 {
  @apply text-white m-0;
}

.close-button {
  @apply text-white hover:bg-white/20 rounded-full w-8 h-8 flex items-center justify-center
         text-xl font-bold transition-all duration-200 hover:scale-110;
}

.modal-body {
  @apply p-8 overflow-y-auto max-h-[calc(90vh-100px)] leading-relaxed text-gray-700;
}

.modal-body section {
  @apply mb-6;
}

.modal-body h3 {
  @apply text-brand-blue text-xl font-bold mb-3 mt-0;
}

.modal-body h4 {
  @apply text-brand-blue-dark text-lg font-semibold mb-2 mt-4;
}

.modal-body p {
  @apply mb-4 text-gray-700;
}

.modal-body ul,
.modal-body ol {
  @apply mb-4 pl-6 text-gray-700;
}

.modal-body li {
  @apply mb-2;
}

.modal-body strong {
  @apply text-gray-900 font-semibold;
}

/* Modal transition */
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-active .modal-content,
.modal-leave-active .modal-content {
  transition: transform 0.3s ease, opacity 0.3s ease;
}

.modal-enter-from .modal-content,
.modal-leave-to .modal-content {
  transform: translateY(-20px) scale(0.95);
  opacity: 0;
}
</style>
