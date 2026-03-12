---
source: schleupen-tools/TFSContributorsAnalyzer/prompts/003_product_details.md
created: 2026-03-12
---
# Plan: Product Detail Page

## Overview

Add a `ProductDetailView` that shows per-product data (contributors, VCS info, contribution stats). Clicking the product name in the "By product" table navigates to this view via `/product/:name`.

## Affected Files

- `Vue-App/router/index.js` — add `/product/:name` route
- `Vue-App/views/ProductDetailView.vue` — new view (create)
- `Vue-App/components/ProductContributionTable.vue` — make product name a clickable link

## Implementation Steps

1. **Create `ProductDetailView.vue`**
   - Accept `name` as a route param (via `props: true`)
   - Read product data from `useOwnershipStore`: `filteredData`, `allData`, `productVcsMap`, `productTeamMap`, `authorColors`, `productTotals`
   - Display a header with the product name, team, VCS badge, and total/filtered contribution counts
   - Show a full contributors table (author, contributions, %, files) sorted by contribution count — no `TOP_N` cap, no "Show more"
   - Include a back button (`router.back()` or link to `/`)

2. **Register the route in `router/index.js`**
   ```js
   {
     path: '/product/:name',
     name: 'ProductDetail',
     component: ProductDetailView,
     props: true
   }
   ```

3. **Make product name a link in `ProductContributionTable.vue`**
   - Replace the plain `{{ row.product }}` text with a `<router-link :to="{ name: 'ProductDetail', params: { name: row.product } }">` element
   - Keep the existing expand button (`▸/▾`) in place; only the name text becomes a link

## Considerations

- Product names can contain dots (e.g. `prod.alpha`) — `createWebHashHistory` handles this safely; no special encoding needed
- The view should derive all its data from the existing store (no new fetch calls)
- Re-use existing CSS patterns (`.vcs-badge`, `.inner-table`, header gradient) to stay visually consistent
- No new Pinia actions needed — all required data is already exposed by the store
