<template>
  <div class="charts-panel">
    <div class="mode-toggle-group">
      <button :class="['mode-btn', { active: chartMode === 'product' }]" @click="chartMode = 'product'">
        By Product
      </button>
      <button :class="['mode-btn', { active: chartMode === 'author' }]" @click="chartMode = 'author'">
        By Author
      </button>
    </div>
    <div class="pie-charts">
      <template v-if="chartMode === 'product'">
        <div v-for="product in productsWithAuthors" :key="product" class="pie-card">
          <PieChart :product="product" />
        </div>
      </template>
      <template v-else>
        <div v-for="author in authorsWithContributions" :key="author" class="pie-card">
          <AuthorDonutChart :author="author" />
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

const chartMode = ref('product'); // 'product' or 'author'
const { filters, data, productTotals, filteredData } = storeToRefs(useOwnershipStore());

// Always show all products if none are selected
const selectedProducts = computed(() => {
  const allProducts = [...new Set(data.value.map(r => r.Product))];
  const productsToShow = filters.value.products.length ? filters.value.products : allProducts;
  // Order by total contributions descending using store's productTotals
  return [...productsToShow].sort((a, b) => (productTotals.value[b] || 0) - (productTotals.value[a] || 0));
});

// Only include products with at least one author after filtering
const productsWithAuthors = computed(() => {
  return selectedProducts.value.filter(product => {
    return filteredData.value.some(r => r.Product === product);
  });
});

// Authors with at least one contribution after filtering, sorted by number of products
const authorsWithContributions = computed(() => {
  const authors = [...new Set(filteredData.value.map(r => r.Author))];
  
  // Count number of products per author
  return authors.sort((a, b) => {
    const aProducts = new Set(filteredData.value.filter(r => r.Author === a).map(r => r.Product)).size;
    const bProducts = new Set(filteredData.value.filter(r => r.Author === b).map(r => r.Product)).size;
    return bProducts - aProducts; // Sort descending
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
