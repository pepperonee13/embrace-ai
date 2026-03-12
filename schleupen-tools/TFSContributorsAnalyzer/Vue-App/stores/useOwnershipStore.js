import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import Papa from 'papaparse';
import { getEnvironmentPath } from '../utils/environment';

export const useOwnershipStore = defineStore('ownership', () => {
  const rawCsv = ref('');
  const authorMap = ref({});
  const data = ref([]); // Parsed and mapped
  const timelineData = ref([]); // Timeline data for detailed view
  const filters = ref({
    products: [],
    authors: [],
    minPercent: 0,
    vcs: [],
  });
  const chartMode = ref('product'); // 'product', 'author', 'zscore'
  const dateInfo = ref(null);
  const authorColors = ref({});

  // Teams loaded from external JSON
  const teams = ref([]);
  // Map of product name -> vcs/source (e.g. 'tfs' | 'git' | null)
  const productVcsMap = ref({});
  // Map of product name -> team name
  const productTeamMap = ref({});
  // Map of team name -> color
  const teamColors = ref({});

  async function loadTeams() {
    const resp = await fetch(getEnvironmentPath('./team_mappings', '.json'));
    const teamsData = await resp.json();

    // Keep `teams` structure compatible with existing UI (products as array of names)
    teams.value = teamsData.map(team => ({
      name: team.name,
      authors: team.authors,
      products: team.products.map(product => product.name)
    }));

    // Build productVcsMap using the source field from the mapping JSON (if present)
    const map = {};
    const teamMap = {};
    teamsData.forEach(team => {
      if (!team.products) return;
      team.products.forEach(p => {
        if (p && p.name) {
          // Default missing source to 'git'
          map[p.name] = p.source ? String(p.source).toLowerCase() : 'git';
          // Map product to team
          teamMap[p.name] = team.name;
        }
      });
    });
    productVcsMap.value = map;
    productTeamMap.value = teamMap;
  }

  // Load team colors from external JSON
  async function loadTeamColors() {
    try {
      const resp = await fetch(getEnvironmentPath('./teamColors', '.json'));
      teamColors.value = await resp.json();
    } catch (error) {
      console.warn('Could not load team colors configuration:', error);
      teamColors.value = {};
    }
  }

  // Ignored authors loaded from external JSON
  const ignoredAuthors = ref([]);
  async function loadIgnoredAuthors() {
    try {
      const resp = await fetch(getEnvironmentPath('./ignored_authors', '.json'));
      ignoredAuthors.value = await resp.json();
    } catch (error) {
      console.warn('Could not load ignored authors configuration:', error);
      ignoredAuthors.value = [];
    }
  }

  // Load timeline data
  async function loadTimelineData() {
    try {
      const resp = await fetch(getEnvironmentPath('./TimelineData', '.csv'));
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
      }
      const csvText = await resp.text();
      const parsed = Papa.parse(csvText, { header: true, skipEmptyLines: true });
      
      timelineData.value = parsed.data.map(row => ({
        ...row,
        Author: authorMap.value[row.Author] || row.Author,
        Date: new Date(row.DateTime),
        FormattedDate: row.Date
      })).filter(row => !ignoredAuthors.value.includes(row.Author));
      
      console.log(`Loaded ${timelineData.value.length} timeline entries`);
      
    } catch (error) {
      console.warn('Could not load timeline data:', error);
      timelineData.value = [];
    }
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
    
    // Load ignored authors configuration
    await loadIgnoredAuthors();
    
    data.value = parsed.data
      .map(row => ({
        ...row,
        Author: mappingJson[row.Author] || row.Author,
        ContributionCount: +row.ContributionCount,
        FileCount: +row.FileCount,
      }))
      .filter(row => !ignoredAuthors.value.includes(row.Author)); // Filter out ignored authors
    
    dateInfo.value = parsedDateInfo;

    // Load timeline data after main data is loaded
    await loadTimelineData();

    // Assign colors using brand-focused gradient palette with team-based intelligent assignment
    const authors = [...new Set(data.value.map(r => r.Author))];

    // Brand-focused gradient palette (blues, teals, oranges with variations)
    const brandPalette = {
      // Blues family (TIMETOACT primary)
      blues: [
        '#054A80', '#0D5A91', '#1E5EA8', '#225EA9', '#3A75BA',
        '#4A8FD8', '#6BA5E3', '#8CBBEE', '#B3D4F5'
      ],
      // Teals family (TIMETOACT secondary)
      teals: [
        '#006B75', '#007B86', '#088F9B', '#1A9FA9', '#3DB8C4',
        '#5AC7D1', '#7DD6DD', '#A0E5E9', '#C2F2F5'
      ],
      // Oranges family (TIMETOACT accent)
      oranges: [
        '#C45E0F', '#D47113', '#E08120', '#F08223', '#F5963F',
        '#FFB366', '#FFC88A', '#FFD9AD', '#FFE8CF'
      ],
      // Complementary purples (derived from blues)
      purples: [
        '#5A4A80', '#6B5A91', '#7B6AA8', '#8C7AB9', '#9D8ACA',
        '#AE9ADB', '#BFAAEC', '#D0BAFD'
      ],
      // Neutral grays (for overflow)
      neutrals: [
        '#495057', '#5A6268', '#6C757D', '#868E96', '#ADB5BD',
        '#CED4DA', '#DEE2E6', '#E9ECEF'
      ]
    };

    // Flatten palette with distribution: more blues/teals (primary brand colors)
    const fullPalette = [
      ...brandPalette.blues,
      ...brandPalette.teals,
      ...brandPalette.oranges,
      ...brandPalette.purples,
      ...brandPalette.blues.slice(2, 6), // Repeat some blues for larger teams
      ...brandPalette.teals.slice(2, 6), // Repeat some teals
      ...brandPalette.neutrals
    ];

    authorColors.value = {};

    // If teams are loaded, assign colors by team (same family per team)
    if (teams.value && teams.value.length > 0) {
      const colorFamilies = [
        brandPalette.blues,
        brandPalette.teals,
        brandPalette.oranges,
        brandPalette.purples
      ];

      let familyIndex = 0;
      const assignedAuthors = new Set();

      // Assign colors to team members
      teams.value.forEach(team => {
        const family = colorFamilies[familyIndex % colorFamilies.length];
        const teamAuthors = team.authors || [];

        teamAuthors.forEach((author, idx) => {
          const mappedAuthor = authorMap.value[author] || author;
          if (authors.includes(mappedAuthor)) {
            // Assign color from family, cycling if team is larger than family
            authorColors.value[mappedAuthor] = family[idx % family.length];
            assignedAuthors.add(mappedAuthor);
          }
        });

        familyIndex++;
      });

      // Assign remaining authors (not in any team) using full palette
      let paletteIndex = 0;
      authors.forEach(author => {
        if (!assignedAuthors.has(author)) {
          authorColors.value[author] = fullPalette[paletteIndex % fullPalette.length];
          paletteIndex++;
        }
      });
    } else {
      // No teams loaded, use full palette sequentially
      authors.forEach((author, i) => {
        authorColors.value[author] = fullPalette[i % fullPalette.length];
      });
    }
  }

  // Filtered data
  const filteredData = computed(() => {
    // ...filter logic by filters.value...
    let d = data.value;    
    if (filters.value.products.length)
      d = d.filter(r => filters.value.products.includes(r.Product));
    if (filters.value.authors.length)
      d = d.filter(r => filters.value.authors.includes(r.Author));
    // Filter by version control (product -> vcs mapping provided by productVcsMap)
    if (filters.value.vcs && filters.value.vcs.length) {
      d = d.filter(r => {
        const vcs = productVcsMap.value && productVcsMap.value[r.Product] ? productVcsMap.value[r.Product] : 'git';
        return filters.value.vcs.includes(vcs);
      });
    }
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

  // Get filtered contributions by product, taking into account author filters and min percent threshold
  const productFilteredContributions = computed(() => {
    const result = {};
    const products = new Set(filteredData.value.map(r => r.Product));
    
    products.forEach(product => {
      let data = filteredData.value.filter(r => r.Product === product);
      
      // Calculate totals by author
      const byAuthor = {};
      let totalBeforeMinPercent = 0;
      data.forEach(r => {
        if (!byAuthor[r.Author]) byAuthor[r.Author] = 0;
        byAuthor[r.Author] += r.ContributionCount;
        totalBeforeMinPercent += r.ContributionCount;
      });

      // Filter authors by minimum percentage
      const minPercent = filters.value.minPercent;
      const significantAuthors = Object.entries(byAuthor)
        .filter(([_, count]) => (count / totalBeforeMinPercent) * 100 >= minPercent)
        .map(([_, count]) => count);

      result[product] = significantAuthors.reduce((sum, count) => sum + count, 0);
    });

    return result;
  });

  // Get products that have only a single contributor (after filtering)
  const singleContributorProducts = computed(() => {
    const result = [];
    const products = new Set(filteredData.value.map(r => r.Product));

    products.forEach(product => {
      let data = filteredData.value.filter(r => r.Product === product);

      // Calculate totals by author
      const byAuthor = {};
      let totalBeforeMinPercent = 0;
      data.forEach(r => {
        if (!byAuthor[r.Author]) byAuthor[r.Author] = 0;
        byAuthor[r.Author] += r.ContributionCount;
        totalBeforeMinPercent += r.ContributionCount;
      });

      // Filter authors by minimum percentage
      const minPercent = filters.value.minPercent;
      const significantAuthors = Object.entries(byAuthor)
        .filter(([_, count]) => (count / totalBeforeMinPercent) * 100 >= minPercent);

      if (significantAuthors.length === 1) {
        result.push(product);
      }
    });

    return result.sort((a, b) => a.localeCompare(b));
  });

  // Get products that have contributors from multiple teams
  const multiTeamProducts = computed(() => {
    if (!teams.value || teams.value.length === 0) return [];

    const result = [];
    const products = new Set(data.value.map(r => r.Product));

    products.forEach(product => {
      const productData = data.value.filter(r => r.Product === product);
      const productAuthors = new Set(productData.map(r => r.Author));

      // Find which teams contribute to this product
      const contributingTeams = new Set();
      teams.value.forEach(team => {
        const hasContributor = team.authors?.some(author => productAuthors.has(author));
        if (hasContributor) {
          contributingTeams.add(team.name);
        }
      });

      if (contributingTeams.size > 1) {
        result.push(product);
      }
    });

    return result.sort((a, b) => a.localeCompare(b));
  });

  // Get top 10% most active products by contribution count
  const topActiveProducts = computed(() => {
    const productContribs = Object.entries(productTotals.value)
      .sort(([, a], [, b]) => b - a);

    const topCount = Math.max(1, Math.ceil(productContribs.length * 0.1));
    return productContribs.slice(0, topCount).map(([product]) => product);
  });

  function setProducts(products) {
    filters.value.products = [...products];
  }
  function setAuthors(authors) {
    filters.value.authors = [...authors];
  }
  function setVcs(vcsArray) {
    filters.value.vcs = [...vcsArray];
  }
  function setMinPercent(val) {
    filters.value.minPercent = val;
  }
  function setChartMode(mode) {
    chartMode.value = mode;
  }

  // Get timeline data for specific author
  const getAuthorTimeline = computed(() => (author) => {
    return timelineData.value
      .filter(item => item.Author === author)
      .sort((a, b) => a.Date - b.Date);
  });

  // Get timeline data for specific product
  const getProductTimeline = computed(() => (product) => {
    return timelineData.value
      .filter(item => item.Product === product)
      .sort((a, b) => a.Date - b.Date);
  });

  return {
    rawCsv, authorMap, data, timelineData, filters, loadData, loadTimelineData,
    filteredData, totalContributions, productCount, authorCount,
    dateInfo, authorColors, productTotals, productFilteredContributions,
    setProducts, setAuthors, setMinPercent,
    teams, loadTeams,
    productVcsMap,
    productTeamMap,
    teamColors, loadTeamColors,
    setVcs,
    ignoredAuthors, loadIgnoredAuthors,
    chartMode, setChartMode,
    singleContributorProducts, multiTeamProducts, topActiveProducts,
    getAuthorTimeline, getProductTimeline,
  };
});
