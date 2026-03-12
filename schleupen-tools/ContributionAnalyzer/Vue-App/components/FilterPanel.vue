<template>
  <div class="filter-panel">
    <button class="collapse-toggle" @click="collapsed = !collapsed">
      <span v-if="collapsed">Show Filters ▼</span>
      <span v-else>Hide Filters ▲</span>
    </button>
    <transition name="fade">
      <div v-show="!collapsed">
        <div class="filter-group">
          <span class="filter-label">Teams:</span>
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
        <div class="filter-group">
          <span class="filter-label">Products:</span>
          <div class="pills">
            <button
              v-for="p in products"
              :key="p"
              :class="['pill', { selected: selectedProducts.includes(p) }]"
              @click="toggleProduct(p)"
              :style="selectedProducts.includes(p) ? { background: productTeamColor(p), color: '#fff', borderColor: productTeamColor(p) } : {}"
            >
              {{ p }}
            </button>
          </div>
        </div>
        <div class="filter-group">
          <span class="filter-label">Authors:</span>
          <div class="pills">
            <button
              v-for="a in authors"
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
        </div>
        <div class="filter-group slider-group">
          <span class="filter-label">Min Contribution %:</span>
          <div class="slider-container">
            <input type="range" v-model.number="minPercent" min="0" max="100" class="slider" />
            <span class="slider-value">{{ minPercent }}%</span>
          </div>
        </div>
      </div>
    </transition>
    <div class="metrics-muted-and-clear">
      <div class="metrics-muted">
        <span><b>Contributions:</b> {{ totalContributions }}</span>
        <span><b>Products:</b> {{ productCount }}</span>
        <span><b>Authors:</b> {{ authorCount }}</span>
      </div>
      <button class="clear-btn" @click="clearFilters">Clear Filters</button>

      <!-- <div><span v-for="a of authors" :key="a">{{ a }}<br></span></div> -->
    </div>
  </div>
</template>

<script setup>
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';
import { computed, ref, watch, onMounted, shallowRef } from 'vue';
import { getCurrentEnvironment } from '../utils/environment';

const env = getCurrentEnvironment();
const teamColorsModule = shallowRef(null);
const store = useOwnershipStore();
const { data, filters, authorColors, totalContributions, productCount, authorCount, teams } = storeToRefs(store);
const { setProducts, setAuthors, setMinPercent, loadTeams } = store;

const teamsWithColor = computed(() => (teams.value || []).map(team => ({
  ...team,
  color: teamColorsModule.value?.TEAM_COLORS?.[team.name] || '#bbb'
})));
onMounted(async () => {
  // Load team colors module
  teamColorsModule.value = await import(/* @vite-ignore */ `../teamColors${env === 'production' ? '' : `.${env}`}.js`);
  loadTeams();
});

const products = computed(() => [...new Set(data.value.map(r => r.Product))].sort((a, b) => a.localeCompare(b)));
const authors = computed(() => [...new Set(data.value.map(r => r.Author))].sort((a, b) => a.localeCompare(b)));

const selectedProducts = ref([...filters.value.products]);
const selectedAuthors = ref([...filters.value.authors]);
const minPercent = ref(filters.value.minPercent);
const selectedTeams = ref([]);

// Collapsible state
const collapsed = ref(true);

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
  () => filters.value.minPercent,
  (val) => { minPercent.value = val; }
);

const productTeamColor = (product) => {
  const team = teamsWithColor.value.find(t => t.products.includes(product));
  return team ? team.color : '#1f77b4';
};

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
}
</script>

<style scoped>
.filter-panel {
  display: flex;
  gap: 1.5rem;
  flex-wrap: wrap;
  align-items: flex-start;
  background: #fff;
  padding: 1rem;
  border-radius: 8px;
  box-shadow: 0 1px 4px #0001;
  flex-direction: column;
  min-width: 220px;
}
.collapse-toggle {
  background: none;
  border: none;
  color: #1f77b4;
  font-weight: 600;
  font-size: 1em;
  cursor: pointer;
  margin-bottom: 0.5em;
  align-self: flex-start;
  padding: 0;
}
.collapse-toggle:focus {
  outline: 2px solid #1f77b4;
}
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.3em;
}
.filter-label {
  font-size: 0.95em;
  margin-bottom: 0.2em;
}
.pills {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5em;
}
.pill {
  border: 2.5px solid #bbb;
  background: #f8f9fa;
  border-radius: 999px;
  padding: 0.3em 1.1em;
  font-size: 1em;
  cursor: pointer;
  transition: background 0.2s, border 0.2s, color 0.2s;
  outline: none;
}
.pill.selected {
  /* background and color now set inline for author pills */
  border-width: 3.5px;
  outline: none;
  box-shadow: none;
}
.pill.selected:focus {
  outline: none !important;
  box-shadow: none !important;
}
.pill:focus {
  box-shadow: 0 0 0 2px #1f77b4aa;
}
.metrics-muted {
  color: #6c757d;
  font-size: 0.98em;
  display: flex;
  gap: 2.5em;
  flex-wrap: wrap;
  justify-content: flex-start;
  align-items: flex-start;
  margin-top: 0.5em;
}
.metrics-muted-and-clear {
  display: flex;
  width: 100%;
  justify-content: space-between;
  align-items: flex-end;
  margin-top: 0.5em;
}
.clear-btn {
  background: #fff;
  color: #d62728;
  border: 1.5px solid #d62728;
  border-radius: 6px;
  padding: 0.4em 1.2em;
  font-size: 1em;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s, color 0.2s, border 0.2s;
}
.clear-btn:hover {
  background: #ffeaea;
  color: #a00;
  border-color: #a00;
}

.slider-group {
  width: 100%;
  max-width: 300px;
}

.slider-container {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.5rem 0;
}

.slider {
  flex: 1;
  -webkit-appearance: none;
  appearance: none;
  height: 6px;
  background: #e9ecef;
  border-radius: 3px;
  outline: none;
}

.slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 18px;
  height: 18px;
  background: #1f77b4;
  border-radius: 50%;
  cursor: pointer;
  transition: background 0.2s;
}

.slider::-moz-range-thumb {
  width: 18px;
  height: 18px;
  background: #1f77b4;
  border: none;
  border-radius: 50%;
  cursor: pointer;
  transition: background 0.2s;
}

.slider::-webkit-slider-thumb:hover,
.slider::-moz-range-thumb:hover {
  background: #155987;
}

.slider-value {
  min-width: 3.5em;
  font-size: 0.95em;
  color: #495057;
}
</style>
