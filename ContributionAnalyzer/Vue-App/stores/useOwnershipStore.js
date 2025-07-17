import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import Papa from 'papaparse';

export const useOwnershipStore = defineStore('ownership', () => {
  const rawCsv = ref('');
  const authorMap = ref({});
  const data = ref([]); // Parsed and mapped
  const filters = ref({
    products: [],
    authors: [],
    minPercent: 5,
  });
  const dateInfo = ref(null);
  const authorColors = ref({});

  // Teams loaded from external JSON
  const teams = ref([]);
  async function loadTeams() {
    const resp = await fetch('./team_mappings.json');
    teams.value = await resp.json();
  }

  // Load CSV and mapping JSON
  async function loadData(csvText, mappingJson) {
    rawCsv.value = csvText;
    authorMap.value = mappingJson;
    const lines = csvText.split(/\r?\n/).filter(Boolean);
    let parsedDateInfo = null;
    if (lines.length && lines[lines.length - 1].startsWith('Since=')) {
      // Parse date info
      const match = lines[lines.length - 1].match(/Since=([\d-]+)?(?:,Until=([\d-]+))?/);
      if (match) {
        parsedDateInfo = {
          since: match[1] || null,
          until: match[2] || null
        };
      }
      lines.pop();
    }
    const csvBody = lines.join('\n');
    const parsed = Papa.parse(csvBody, { header: true, skipEmptyLines: true });
    data.value = parsed.data.map(row => ({
      ...row,
      Author: mappingJson[row.Author] || row.Author,
      ContributionCount: +row.ContributionCount,
      FileCount: +row.FileCount,
    }));
    dateInfo.value = parsedDateInfo;

    // Assign a color to each author (dynamic palette for uniqueness)
    const authors = [...new Set(data.value.map(r => r.Author))];
    // Use d3.schemeCategory10, d3.schemeSet3, and generate more if needed
    let palette = [
      '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf',
      '#aec7e8', '#ffbb78', '#98df8a', '#ff9896', '#c5b0d5', '#c49c94', '#f7b6d2', '#c7c7c7', '#dbdb8d', '#9edae5',
      '#393b79', '#637939', '#8c6d31', '#843c39', '#7b4173', '#5254a3', '#9c9ede', '#cedb9c', '#e7ba52', '#ad494a',
      '#a55194', '#6b6ecf', '#b5cf6b', '#e7969c', '#ce6dbd', '#de9ed6', '#6b486b', '#a58282', '#bd9e39', '#8ca252',
      '#bca136', '#7b4173', '#a55194', '#ce6dbd', '#de9ed6', '#393b79', '#5254a3', '#6b6ecf', '#9c9ede', '#637939',
      '#8ca252', '#b5cf6b', '#cedb9c', '#8c6d31', '#bd9e39', '#e7ba52', '#e7cb94', '#843c39', '#ad494a', '#d6616b',
      '#e7969c', '#7b4173', '#a55194', '#ce6dbd', '#de9ed6'
    ];
    // If more authors than palette, generate more colors
    while (palette.length < authors.length) {
      // Generate HSL colors spaced around the color wheel
      const extra = Array.from({ length: authors.length - palette.length }, (_, i) =>
        `hsl(${Math.round(360 * (palette.length + i) / authors.length)},70%,55%)`
      );
      palette = palette.concat(extra);
    }
    authorColors.value = {};
    authors.forEach((author, i) => {
      authorColors.value[author] = palette[i];
    });
  }

  // Filtered data
  const filteredData = computed(() => {
    // ...filter logic by filters.value...
    let d = data.value;
    if (filters.value.products.length)
      d = d.filter(r => filters.value.products.includes(r.Product));
    if (filters.value.authors.length)
      d = d.filter(r => filters.value.authors.includes(r.Author));
    // ...date range, minPercent handled in chart logic...
    return d;
  });

  // Aggregated metrics
  const totalContributions = computed(() =>
    filteredData.value.reduce((sum, r) => sum + r.ContributionCount, 0)
  );
  const productCount = computed(() =>
    new Set(filteredData.value.map(r => r.Product)).size
  );
  const authorCount = computed(() =>
    new Set(filteredData.value.map(r => r.Author)).size
  );
  const productTotals = computed(() => {
    const totals = {};
    data.value.forEach(r => {
      if (!totals[r.Product]) totals[r.Product] = 0;
      totals[r.Product] += r.ContributionCount;
    });
    return totals;
  });

  function setProducts(products) {
    filters.value.products = [...products];
  }
  function setAuthors(authors) {
    filters.value.authors = [...authors];
  }
  function setMinPercent(val) {
    filters.value.minPercent = val;
  }

  return {
    rawCsv, authorMap, data, filters, loadData,
    filteredData, totalContributions, productCount, authorCount,
    dateInfo, authorColors, productTotals,
    setProducts, setAuthors, setMinPercent,
    teams, loadTeams,
  };
});
