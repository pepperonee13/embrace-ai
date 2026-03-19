<template>
  <div class="dashboard">
    <!-- Loading State -->
    <div v-if="loading" class="loading-container">
      <div class="loading-spinner"></div>
      <p class="loading-text">Loading contributor data...</p>
    </div>

    <!-- Enhanced Header with Logo and Branding -->
    <header v-else class="bg-gradient-to-r from-brand-blue via-brand-blue-light to-brand-teal text-white shadow-lg rounded-xl p-6 mb-6 animate-fade-in">
      <div class="flex items-center justify-between flex-wrap gap-4">
        <!-- Logo and Title Section -->
        <div class="flex items-center gap-6">
          <div class="bg-white rounded-lg p-2 shadow-md">
            <img
              src="/assets/TIMETOACT-AT_logo.svg"
              alt="TIMETOACT Logo"
              class="h-10 w-auto"
            />
          </div>
          <div>
            <h1 class="text-3xl font-bold mb-1 text-white">Code Ownership Insights</h1>
            <div class="flex items-center gap-3">
              <span class="bg-white/20 backdrop-blur-sm px-3 py-1 rounded-full text-sm font-medium">
                EmbraceAI Initiative
              </span>
              <span v-if="dateRangeText" class="text-sm opacity-90">
                📅 {{ dateRangeText }}
              </span>
            </div>
          </div>
        </div>

        <!-- Navigation -->
        <div class="flex gap-3">
          <router-link
            to="/admin"
            class="bg-white/10 backdrop-blur-sm text-white px-4 py-3 rounded-lg font-semibold hover:bg-white/20 transition-all border-2 border-white/30 flex items-center gap-2"
            title="Configuration Settings"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
          </router-link>
          <button
            @click="showInfoModal = true"
            class="bg-white/10 backdrop-blur-sm text-white px-5 py-3 rounded-lg font-semibold hover:bg-white/20 transition-all border-2 border-white/30"
            title="About this application"
          >
            ℹ️ Info
          </button>
          <router-link
            to="/timeline"
            class="bg-white text-brand-blue px-6 py-3 rounded-lg font-semibold hover:bg-opacity-90 transition-all shadow-md hover:shadow-lg"
          >
            📈 View Timeline
          </router-link>
        </div>
      </div>

      <!-- Statistics Summary -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 pt-6 border-t border-white/20">
        <div class="stat-card">
          <div class="stat-value">{{ totalContributions.toLocaleString() }}</div>
          <div class="stat-label">Total Contributions</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">{{ productCount }}</div>
          <div class="stat-label">Products Analyzed</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">{{ authorCount }}</div>
          <div class="stat-label">Contributors</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">{{ teamCount }}</div>
          <div class="stat-label">Teams</div>
        </div>
      </div>
    </header>

    <div v-if="!loading" class="content-container">
      <FilterPanel />
      <main class="charts-main animate-slide-up" style="animation-delay: 0.2s">
        <ChartsPanel />
      </main>
    </div>

    <!-- Info Modal -->
    <teleport to="body">
      <transition name="modal">
        <div v-if="showInfoModal" class="modal-overlay" @click="showInfoModal = false">
          <div class="modal-content" @click.stop>
            <div class="modal-header">
              <h2 class="text-2xl font-bold text-white">📊 About Code Ownership Insights</h2>
              <button @click="showInfoModal = false" class="close-button" title="Close">
                ✕
              </button>
            </div>

            <div class="modal-body">
              <section>
                <h3>🎯 Purpose</h3>
                <p>This application helps make <strong>knowledge sharing</strong> and <strong>domain expertise discovery</strong> more conscious and visible within development teams. It provides visual analytics to identify key contributors, domain experts, and knowledge distribution across projects.</p>
              </section>

              <section>
                <h4>🔍 What it analyzes:</h4>
                <ul>
                  <li><strong>Team Foundation Server (TFS)</strong> version control history</li>
                  <li><strong>Git repositories</strong> commit logs</li>
                  <li><strong>Code contributions</strong> across multiple products and projects</li>
                  <li><strong>Developer activity patterns</strong> over time</li>
                </ul>
              </section>

              <section>
                <h4>📈 Key Insights:</h4>
                <ul>
                  <li><strong>Bus Factor Analysis:</strong> Identify critical knowledge dependencies and single points of failure</li>
                  <li><strong>Domain Expertise Mapping:</strong> Find who has the most experience in specific products/areas</li>
                  <li><strong>Contribution Distribution:</strong> Visualize workload and code ownership across teams</li>
                  <li><strong>Knowledge Sharing Opportunities:</strong> Spot areas where expertise could be better distributed</li>
                </ul>
              </section>

              <section>
                <h4>🛠️ How it works:</h4>
                <ol>
                  <li><strong>Data Collection:</strong> Fetches commit/changeset history from TFS and Git repositories</li>
                  <li><strong>Processing:</strong> Parses and aggregates contribution data by author, product, and time</li>
                  <li><strong>Visualization:</strong> Interactive dashboard with donut charts, filters, and team-based views</li>
                  <li><strong>Analysis:</strong> Filter by teams, products, authors, and contribution thresholds</li>
                </ol>
              </section>

              <section>
                <h4>👥 Use Cases:</h4>
                <ul>
                  <li><strong>Team Leaders:</strong> Plan knowledge transfer and identify training needs</li>
                  <li><strong>Project Managers:</strong> Understand team capacity and expertise distribution</li>
                  <li><strong>Developers:</strong> Find domain experts and collaboration opportunities</li>
                  <li><strong>Management:</strong> Assess technical risk and plan resource allocation</li>
                </ul>
              </section>
            </div>
          </div>
        </div>
      </transition>
    </teleport>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';
import FilterPanel from '../components/FilterPanel.vue';
import ChartsPanel from '../components/ChartsPanel.vue';
import { getEnvironmentPath } from '../utils/environment';

const store = useOwnershipStore();
const { dateInfo, teams } = storeToRefs(store);
const loading = ref(true);
const showInfoModal = ref(false);

const dateRangeText = computed(() => {
  const dr = dateInfo.value;
  if (!dr || (!dr.since && !dr.until)) return '';
  if (dr.since && dr.until) return `${dr.since} to ${dr.until}`;
  if (dr.since) return `since ${dr.since}`;
  if (dr.until) return `until ${dr.until}`;
  return '';
});

// Statistics computed properties
const totalContributions = computed(() => store.totalContributions || 0);
const productCount = computed(() => store.productCount || 0);
const authorCount = computed(() => store.authorCount || 0);
const teamCount = computed(() => teams.value?.length || 0);

onMounted(async () => {
  try {
    const csvResp = await fetch(getEnvironmentPath('/RawOwnershipReport', '.csv'));
    const csvText = await csvResp.text();
    const mapResp = await fetch(getEnvironmentPath('/author_mappings', '.json'));
    const mappingJson = await mapResp.json();
    await store.loadData(csvText, mappingJson);
    await store.loadTeams();
    await store.loadTeamColors();
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.dashboard {
  max-width: 1920px;
  margin: 0 auto;
  padding: 2rem 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

@media (min-width: 1920px) {
  .dashboard {
    max-width: 95vw;
  }
}

.content-container {
  @apply flex flex-col;
  width: 100%;
}

.charts-main {
  @apply w-full;
}

.loading-container {
  @apply flex flex-col items-center justify-center min-h-[60vh] gap-6;
}

.loading-spinner {
  @apply w-16 h-16 border-4 border-gray-200 border-t-brand-blue rounded-full;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.loading-text {
  @apply text-xl font-semibold text-brand-blue animate-pulse;
}

.stat-card {
  @apply text-center;
}

.stat-value {
  @apply text-3xl font-bold mb-1 font-mono;
}

.stat-label {
  @apply text-sm opacity-90 font-medium;
}

@media (max-width: 768px) {
  .stat-value {
    @apply text-2xl;
  }
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
