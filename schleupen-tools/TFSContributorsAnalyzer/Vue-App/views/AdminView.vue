<template>
  <div class="admin-view">
    <header
      class="bg-gradient-to-r from-brand-blue via-brand-blue-light to-brand-teal text-white shadow-lg rounded-xl p-6 mb-6">
      <div class="flex items-center justify-between flex-wrap gap-4">
        <div class="flex items-center gap-4">
          <router-link to="/" class="text-white hover:text-white/80 transition-colors">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
          </router-link>
          <h1 class="text-3xl font-bold">⚙️ Configuration Settings</h1>
        </div>
        <div class="bg-white/20 backdrop-blur-sm px-3 py-1 rounded-full text-sm font-medium">
          Environment: {{ currentEnvironment }}
        </div>
      </div>
    </header>

    <!-- Loading State -->
    <div v-if="loading" class="loading-container">
      <div class="loading-spinner"></div>
      <p class="loading-text">Loading configuration files...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="loadError" class="error-container">
      <div class="error-icon">⚠️</div>
      <h2 class="text-xl font-bold text-red-600 mb-2">Failed to Load Configuration</h2>
      <p class="text-gray-600 mb-4">{{ loadError }}</p>
      <button @click="loadConfigs" class="btn-brand-primary">Retry</button>
    </div>

    <!-- Success Message -->
    <transition name="fade">
      <div v-if="successMessage" class="success-banner">
        ✅ {{ successMessage }}
      </div>
    </transition>

    <!-- Configuration Tabs -->
    <div v-if="!loading && !loadError" class="config-container">
      <div class="tabs">
        <button v-for="tab in tabs" :key="tab.id" @click="activeTab = tab.id"
          :class="['tab-button', { active: activeTab === tab.id }]">
          {{ tab.icon }} {{ tab.label }}
        </button>
      </div>

      <div class="tab-content">
        <!-- Team Mappings -->
        <div v-show="activeTab === 'teams'" class="config-section">
          <div class="section-header">
            <h2>Team Mappings</h2>
            <p class="text-sm text-gray-600 mt-1">Configure teams, their members, and associated products</p>
          </div>

          <div class="teams-editor">
            <div v-for="(team, index) in configs.teamMappings" :key="index" class="team-card">
              <div class="team-card-header">
                <input v-model="team.name" placeholder="Team name" class="input-team-name" />
                <button @click="removeTeam(index)" class="btn-brand-danger" title="Remove team">
                  🗑️ Remove
                </button>
              </div>

              <div class="team-section">
                <label class="section-label">👥 Team Members</label>
                <div class="tag-list">
                  <span v-for="(author, aIdx) in team.authors" :key="aIdx" class="tag">
                    {{ author }}
                    <button @click="removeAuthorFromTeam(index, aIdx)" class="tag-remove">×</button>
                  </span>
                </div>
                <div class="input-group">
                  <input v-model="newAuthorInputs[index]" @keyup.enter="addAuthorToTeam(index)"
                    placeholder="Add author..." class="input-text" />
                  <button @click="addAuthorToTeam(index)" class="btn-brand-secondary btn-brand-sm">Add</button>
                </div>
              </div>

              <div class="team-section">
                <label class="section-label">📦 Products</label>
                <div class="product-list">
                  <div v-for="(product, pIdx) in team.products" :key="pIdx" class="product-item">
                    <input v-model="product.name" placeholder="Product name" class="input-text" />
                    <select v-model="product.source" class="input-select">
                      <option value="git">Git</option>
                      <option value="tfs">TFS</option>
                    </select>
                    <button @click="removeProduct(index, pIdx)" class="btn-brand-danger btn-brand-icon">×</button>
                  </div>
                </div>
                <button @click="addProduct(index)" class="btn-brand-secondary btn-brand-sm">➕ Add Product</button>
              </div>
            </div>

            <button @click="addTeam" class="btn-brand-accent w-full py-3 text-lg">
              ➕ Add New Team
            </button>
          </div>
        </div>

        <!-- Author Mappings -->
        <div v-show="activeTab === 'authors'" class="config-section">
          <div class="section-header">
            <h2>Author Mappings</h2>
            <p class="text-sm text-gray-600 mt-1">Map various usernames to canonical display names</p>
          </div>

          <div class="mappings-editor">
            <div class="mapping-list">
              <div v-for="(canonicalName, username) in configs.authorMappings" :key="username" class="mapping-row">
                <input :value="username" @input="updateAuthorMappingKey(username, $event.target.value)"
                  placeholder="Username" class="input-text" />
                <span class="arrow">→</span>
                <input v-model="configs.authorMappings[username]" placeholder="Canonical name" class="input-text" />
                <button @click="removeAuthorMapping(username)" class="btn-brand-danger btn-brand-icon">×</button>
              </div>
            </div>

            <div class="input-group">
              <input v-model="newAuthorMapping.username" @keyup.enter="addAuthorMapping" placeholder="Username"
                class="input-text" />
              <span class="arrow">→</span>
              <input v-model="newAuthorMapping.canonicalName" @keyup.enter="addAuthorMapping"
                placeholder="Canonical name" class="input-text" />
              <button @click="addAuthorMapping" class="btn-brand-secondary">Add Mapping</button>
            </div>
          </div>
        </div>

        <!-- Ignored Authors -->
        <div v-show="activeTab === 'ignored'" class="config-section">
          <div class="section-header">
            <h2>Ignored Authors</h2>
            <p class="text-sm text-gray-600 mt-1">Authors to exclude from analysis (e.g., build bots, system accounts)
            </p>
          </div>

          <div class="ignored-editor">
            <div class="tag-list">
              <span v-for="(author, index) in configs.ignoredAuthors" :key="index" class="tag tag-ignored">
                {{ author }}
                <button @click="removeIgnoredAuthor(index)" class="tag-remove">×</button>
              </span>
            </div>

            <div class="input-group">
              <input v-model="newIgnoredAuthor" @keyup.enter="addIgnoredAuthor" placeholder="Add author to ignore..."
                class="input-text" />
              <button @click="addIgnoredAuthor" class="btn-brand-secondary">Add</button>
            </div>
          </div>
        </div>

        <!-- Team Colors -->
        <div v-show="activeTab === 'colors'" class="config-section">
          <div class="section-header">
            <h2>Team Colors</h2>
            <p class="text-sm text-gray-600 mt-1">Assign colors to teams for visualization</p>
          </div>

          <div class="colors-editor">
            <div class="color-list">
              <div v-for="(color, teamName) in configs.teamColors" :key="teamName" class="color-row">
                <input :value="teamName" @input="updateTeamColorKey(teamName, $event.target.value)"
                  placeholder="Team name" class="input-text" />
                <div class="color-picker-container">
                  <input v-model="configs.teamColors[teamName]" type="color" class="color-picker" />
                  <input v-model="configs.teamColors[teamName]" type="text" placeholder="#000000"
                    class="input-color-text" />
                </div>
                <button @click="removeTeamColor(teamName)" class="btn-brand-danger btn-brand-icon">×</button>
              </div>
            </div>

            <div class="input-group">
              <input v-model="newTeamColor.teamName" @keyup.enter="addTeamColor" placeholder="Team name"
                class="input-text" />
              <div class="color-picker-container">
                <input v-model="newTeamColor.color" type="color" class="color-picker" />
                <input v-model="newTeamColor.color" type="text" placeholder="#000000" class="input-color-text" />
              </div>
              <button @click="addTeamColor" class="btn-brand-secondary">Add Color</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="action-bar">
        <button @click="resetConfigs" class="btn-brand-neutral">
          ↺ Reset Changes
        </button>
        <div class="flex gap-3">
          <button @click="downloadConfigs" class="btn-brand-primary">
            💾 Download All
          </button>
          <button @click="saveConfigs" class="btn-brand-success" :disabled="saving">
            {{ saving ? '⏳ Saving...' : '✓ Save All Changes' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue';
import { getEnvironmentPath, getCurrentEnvironment, loadEnvironmentJson, loadEnvironmentTeamColors } from '../utils/environment';

const currentEnvironment = ref(getCurrentEnvironment());
const loading = ref(true);
const loadError = ref('');
const saving = ref(false);
const successMessage = ref('');
const activeTab = ref('teams');

const tabs = [
  { id: 'teams', label: 'Team Mappings', icon: '👥' },
  { id: 'authors', label: 'Author Mappings', icon: '👤' },
  { id: 'ignored', label: 'Ignored Authors', icon: '🚫' },
  { id: 'colors', label: 'Team Colors', icon: '🎨' },
];

const configs = reactive({
  teamMappings: [],
  authorMappings: {},
  ignoredAuthors: [],
  teamColors: {},
});

const originalConfigs = reactive({
  teamMappings: [],
  authorMappings: {},
  ignoredAuthors: [],
  teamColors: {},
});

// Input helpers
const newAuthorInputs = ref({});
const newIgnoredAuthor = ref('');
const newAuthorMapping = reactive({ username: '', canonicalName: '' });
const newTeamColor = reactive({ teamName: '', color: '#2ca02c' });

const CONFIG_SPECS = [
  { stateKey: 'teamMappings', fileKey: 'team_mappings', type: 'json' },
  { stateKey: 'authorMappings', fileKey: 'author_mappings', type: 'json' },
  { stateKey: 'ignoredAuthors', fileKey: 'ignored_authors', type: 'json' },
  { stateKey: 'teamColors', fileKey: 'teamColors', type: 'teamColors' },
];

const loadConfigs = () => {
  loading.value = true;
  loadError.value = '';

  try {
    for (const spec of CONFIG_SPECS) {
      const config =
        spec.type === 'teamColors'
          ? loadEnvironmentTeamColors()
          : loadEnvironmentJson(spec.fileKey);

      // ✅ updates existing reactive props (teamMappings, authorMappings, ...)
      configs[spec.stateKey] = config;
      originalConfigs[spec.stateKey] = JSON.parse(JSON.stringify(config));
    }
  } catch (error) {
    loadError.value = error?.message ?? String(error);
    console.error('Error loading configs:', error);
  } finally {
    loading.value = false;
  }
};

const resetConfigs = () => {
  if (!confirm('Are you sure you want to reset all changes? This cannot be undone.')) return;

  configs.teamMappings = JSON.parse(JSON.stringify(originalConfigs.teamMappings));
  configs.authorMappings = JSON.parse(JSON.stringify(originalConfigs.authorMappings));
  configs.ignoredAuthors = JSON.parse(JSON.stringify(originalConfigs.ignoredAuthors));
  configs.teamColors = JSON.parse(JSON.stringify(originalConfigs.teamColors));

  showSuccess('Changes reset to original values');
};

const downloadConfigs = () => {
  const downloads = [
    { name: getEnvironmentPath('team_mappings', '.json'), data: configs.teamMappings },
    { name: getEnvironmentPath('author_mappings', '.json'), data: configs.authorMappings },
    { name: getEnvironmentPath('ignored_authors', '.json'), data: configs.ignoredAuthors },
    { name: getEnvironmentPath('teamColors', '.json'), data: configs.teamColors },
  ];

  downloads.forEach(({ name, data }) => {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    // Remove leading slash if present
    a.download = name.startsWith('/') ? name.slice(1) : name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  });

  showSuccess('Configuration files downloaded');
};

const saveConfigs = async () => {
  if (!confirm('Note: This will download the configuration files. You need to manually replace them on the server. Continue?')) {
    return;
  }

  saving.value = true;
  try {
    downloadConfigs();

    // Update original configs to match current state
    originalConfigs.teamMappings = JSON.parse(JSON.stringify(configs.teamMappings));
    originalConfigs.authorMappings = JSON.parse(JSON.stringify(configs.authorMappings));
    originalConfigs.ignoredAuthors = JSON.parse(JSON.stringify(configs.ignoredAuthors));
    originalConfigs.teamColors = JSON.parse(JSON.stringify(configs.teamColors));

    showSuccess('Configuration files saved! Please upload them to the server.');
  } catch (error) {
    alert(`Error saving configs: ${error.message}`);
  } finally {
    saving.value = false;
  }
};

const showSuccess = (message) => {
  successMessage.value = message;
  setTimeout(() => {
    successMessage.value = '';
  }, 3000);
};

// Team Mappings functions
const addTeam = () => {
  configs.teamMappings.push({
    name: 'New Team',
    authors: [],
    products: []
  });
};

const removeTeam = (index) => {
  if (confirm('Are you sure you want to remove this team?')) {
    configs.teamMappings.splice(index, 1);
  }
};

const addAuthorToTeam = (teamIndex) => {
  const author = newAuthorInputs.value[teamIndex]?.trim();
  if (author && !configs.teamMappings[teamIndex].authors.includes(author)) {
    configs.teamMappings[teamIndex].authors.push(author);
    newAuthorInputs.value[teamIndex] = '';
  }
};

const removeAuthorFromTeam = (teamIndex, authorIndex) => {
  configs.teamMappings[teamIndex].authors.splice(authorIndex, 1);
};

const addProduct = (teamIndex) => {
  configs.teamMappings[teamIndex].products.push({
    name: '',
    source: 'git'
  });
};

const removeProduct = (teamIndex, productIndex) => {
  configs.teamMappings[teamIndex].products.splice(productIndex, 1);
};

// Author Mappings functions
const addAuthorMapping = () => {
  const username = newAuthorMapping.username.trim();
  const canonicalName = newAuthorMapping.canonicalName.trim();

  if (username && canonicalName) {
    configs.authorMappings[username] = canonicalName;
    newAuthorMapping.username = '';
    newAuthorMapping.canonicalName = '';
  }
};

const removeAuthorMapping = (username) => {
  delete configs.authorMappings[username];
};

const updateAuthorMappingKey = (oldKey, newKey) => {
  if (oldKey === newKey) return;
  const value = configs.authorMappings[oldKey];
  delete configs.authorMappings[oldKey];
  if (newKey.trim()) {
    configs.authorMappings[newKey] = value;
  }
};

// Ignored Authors functions
const addIgnoredAuthor = () => {
  const author = newIgnoredAuthor.value.trim();
  if (author && !configs.ignoredAuthors.includes(author)) {
    configs.ignoredAuthors.push(author);
    newIgnoredAuthor.value = '';
  }
};

const removeIgnoredAuthor = (index) => {
  configs.ignoredAuthors.splice(index, 1);
};

// Team Colors functions
const addTeamColor = () => {
  const teamName = newTeamColor.teamName.trim();
  const color = newTeamColor.color.trim();

  if (teamName && color) {
    configs.teamColors[teamName] = color;
    newTeamColor.teamName = '';
    newTeamColor.color = '#2ca02c';
  }
};

const removeTeamColor = (teamName) => {
  delete configs.teamColors[teamName];
};

const updateTeamColorKey = (oldKey, newKey) => {
  if (oldKey === newKey) return;
  const value = configs.teamColors[oldKey];
  delete configs.teamColors[oldKey];
  if (newKey.trim()) {
    configs.teamColors[newKey] = value;
  }
};

onMounted(() => {
  loadConfigs();
});
</script>

<style scoped>
.admin-view {
  max-width: 1600px;
  margin: 0 auto;
  padding: 2rem 1.5rem;
}

.loading-container,
.error-container {
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

.error-icon {
  @apply text-6xl;
}

.success-banner {
  @apply bg-teal-600 text-white px-6 py-3 rounded-lg shadow-lg mb-6 font-semibold text-center;
  animation: slideDown 0.3s ease-out;
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.config-container {
  @apply bg-white rounded-xl shadow-lg overflow-hidden;
}

.tabs {
  @apply flex border-b border-gray-200 bg-gray-50;
}

.tab-button {
  @apply px-6 py-4 font-semibold text-gray-600 hover:text-brand-blue hover:bg-white/50 transition-all border-b-2 border-transparent;
}

.tab-button.active {
  @apply text-brand-blue bg-white border-brand-blue;
}

.tab-content {
  @apply p-8;
}

.config-section {
  animation: fadeIn 0.3s ease-out;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }

  to {
    opacity: 1;
  }
}

.section-header {
  @apply mb-6;
}

.section-header h2 {
  @apply text-2xl font-bold text-gray-800;
}

/* Teams Editor */
.teams-editor {
  @apply space-y-4;
}

.team-card {
  @apply bg-gray-50 rounded-lg p-6 border-2 border-gray-200;
}

.team-card-header {
  @apply flex items-center justify-between gap-4 mb-4 pb-4 border-b border-gray-300;
}

.input-team-name {
  @apply flex-1 text-xl font-bold px-4 py-2 border-2 border-gray-300 rounded-lg focus:border-brand-blue focus:outline-none;
}

.team-section {
  @apply mb-4;
}

.section-label {
  @apply block text-sm font-semibold text-gray-700 mb-2;
}

.tag-list {
  @apply flex flex-wrap gap-2 mb-3;
}

.tag {
  @apply bg-brand-blue text-white px-3 py-1 rounded-full text-sm font-medium flex items-center gap-2;
}

.tag-ignored {
  @apply bg-red-600;
}

.tag-remove {
  @apply hover:bg-white/20 rounded-full w-5 h-5 flex items-center justify-center font-bold;
}

.input-group {
  @apply flex gap-2 items-center;
}

.input-text {
  @apply flex-1 px-4 py-2 border-2 border-gray-300 rounded-lg focus:border-brand-blue focus:outline-none;
}

.input-select {
  @apply px-4 py-2 border-2 border-gray-300 rounded-lg focus:border-brand-blue focus:outline-none bg-white;
}

.product-list {
  @apply space-y-2 mb-3;
}

.product-item {
  @apply flex gap-2 items-center;
}

/* Mappings Editor */
.mappings-editor,
.ignored-editor,
.colors-editor {
  @apply space-y-4;
}

.mapping-list,
.color-list {
  @apply space-y-2 mb-4;
}

.mapping-row,
.color-row {
  @apply flex gap-2 items-center;
}

.arrow {
  @apply text-gray-400 font-bold;
}

.color-picker-container {
  @apply flex gap-2 items-center;
}

.color-picker {
  @apply w-12 h-10 rounded cursor-pointer border-2 border-gray-300;
}

.input-color-text {
  @apply w-32 px-3 py-2 border-2 border-gray-300 rounded-lg focus:border-brand-blue focus:outline-none font-mono;
}

/* Action Bar */
.action-bar {
  @apply flex justify-between items-center pt-6 mt-6 border-t border-gray-200;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
