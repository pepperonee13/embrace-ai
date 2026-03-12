<template>
  <div class="dashboard">
    <h2 class="date-title">
      Contribution data
      <span v-if="dateRangeText">from {{ dateRangeText }}</span>
    </h2>
    <FilterPanel />
    <ChartsPanel />
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue';
import { storeToRefs } from 'pinia';
import { useOwnershipStore } from '../stores/useOwnershipStore';
import FilterPanel from '../components/FilterPanel.vue';
import ChartsPanel from '../components/ChartsPanel.vue';
import { getEnvironmentPath } from '../utils/environment';

const store = useOwnershipStore();
const { dateInfo } = storeToRefs(store);

const dateRangeText = computed(() => {
  const dr = dateInfo.value;
  if (!dr || (!dr.since && !dr.until)) return '';
  if (dr.since && dr.until) return `${dr.since} to ${dr.until}`;
  if (dr.since) return `since ${dr.since}`;
  if (dr.until) return `until ${dr.until}`;
  return '';
});

onMounted(async () => {
  const csvResp = await fetch(getEnvironmentPath('/RawOwnershipReport', '.csv'));
  const csvText = await csvResp.text();
  const mapResp = await fetch(getEnvironmentPath('/author_mappings', '.json'));
  const mappingJson = await mapResp.json();
  await store.loadData(csvText, mappingJson);
});
</script>

<style scoped>
.dashboard {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 2rem;
}
.date-title {
  margin-bottom: 0.5em;
  font-size: 1.4em;
  font-weight: 600;
}
</style>
