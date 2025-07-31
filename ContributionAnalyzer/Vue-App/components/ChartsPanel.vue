<template>
  <div class="charts-panel">
    <div class="mode-toggle-group">
      <button :class="['mode-btn', { active: chartMode === 'product' }]" @click="chartMode = 'product'">
        By Product
      </button>
      <button :class="['mode-btn', { active: chartMode === 'author' }]" @click="chartMode = 'author'">
        By Author
      </button>
      <button :class="['mode-btn', { active: chartMode === 'zscore' }]" @click="chartMode = 'zscore'">
        Z-Score Analysis
      </button>
    </div>
    <div :class="{ 'pie-charts': chartMode !== 'zscore', 'zscore-chart': chartMode === 'zscore' }">
      <template v-if="chartMode === 'product'">
        <div v-for="product in productsWithAuthors" :key="product" class="pie-card">
          <PieChart :product="product" />
        </div>
      </template>
      <template v-else-if="chartMode === 'author'">
        <div v-for="author in authorsWithContributions" :key="author" class="pie-card">
          <AuthorDonutChart :author="author" />
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

const chartMode = ref('product'); // 'product' or 'author'
const { filters, data, filteredData, productFilteredContributions } = storeToRefs(useOwnershipStore());

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
</script>

<style scoped>
.charts-panel {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.mode-toggle-group {
  display: flex;
  gap: 0.5em;
  margin-bottom: 0.5em;
}

.mode-btn {
  padding: 0.5em 1.2em;
  font-size: 1em;
  border-radius: 6px 6px 0 0;
  border: 1.5px solid #bbb;
  background: #f8f9fa;
  cursor: pointer;
  font-weight: 500;
  color: #1f77b4;
  transition: background 0.2s, color 0.2s;
}

.mode-btn.active {
  background: #1f77b4;
  color: #fff;
  border-bottom: 2.5px solid #1f77b4;
  z-index: 1;
}

.toggle-btn {
  align-self: flex-start;
  margin-bottom: 1rem;
  padding: 0.5em 1.2em;
  font-size: 1em;
  border-radius: 6px;
  border: 1px solid #bbb;
  background: #f8f9fa;
  cursor: pointer;
  transition: background 0.2s;
}

.toggle-btn:hover {
  background: #e0e7ef;
}

.pie-charts {
  display: flex;
  flex-wrap: wrap;
  gap: 2rem;
  justify-content: flex-start;
}

.zscore-chart {
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding: 1rem;
}

.zscore-container {
  background: #fff;
  border-radius: 10px;
  box-shadow: 0 2px 8px #0001;
  padding: 1.2rem;
}

.pie-card {
  background: #fff;
  border-radius: 10px;
  box-shadow: 0 2px 8px #0001;
  padding: 1.2rem 1.2rem 0.5rem 1.2rem;
  min-width: 340px;
  max-width: 380px;
  display: flex;
  flex-direction: column;
  align-items: center;
}
</style>
