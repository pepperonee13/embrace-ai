// src/stores/useDataStore.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useDataStore = defineStore('data', () => {
    const rawData = ref(null)
    const solutionData = ref([])
    const loading = ref(false)
    const error = ref(null)

    const loadData = async () => {
        loading.value = true
        error.value = null
        try {
            const response = await fetch('/index.json')
            if (!response.ok) throw new Error('Failed to load data')
            const indexData = await response.json()

            indexData.forEach(async entry => {
                const res = await fetch('/' + entry.FilePath);
                const data = await res.json();
                solutionData.value.push(data);
            });

            rawData.value = indexData;
        } catch (err) {
            error.value = err.message
        } finally {
            loading.value = false
        }
    }

    return { rawData, loading, error, loadData }
})
