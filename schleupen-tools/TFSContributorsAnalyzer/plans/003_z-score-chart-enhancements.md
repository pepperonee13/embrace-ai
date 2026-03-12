# Z-Score Chart UI/UX Enhancements

**Prompt Reference:** `prompts/002_z-score-chart-enhancements.md`

**Status:** Ready for Implementation

**Created:** 2025-12-09

## Executive Summary

Enhance the ContributionZScoreChart.vue component to align with the established TIMETOACT brand guidelines and match the polished design patterns used throughout the application. The current implementation is functional but lacks the visual refinement, interactive polish, and brand consistency present in other components like PieChart and ChartsPanel.

## Current State Analysis

### Existing Design Patterns in Codebase

**Brand Colors (from variables.css & tailwind.config.js):**
- Primary: `--brand-blue` (#225EA9)
- Teal: `--brand-teal` (#088F9B)
- Orange: `--brand-orange` (#F08223)
- Gray: `--brand-gray` (#2F3944)
- Gradients: `linear-gradient(135deg, var(--brand-blue) 0%, var(--brand-teal) 100%)`

**Typography:**
- Font Family: 'Inter' for UI text, 'JetBrains Mono' for data/numbers
- Headings: Bold (700 weight), brand-gray color
- Font sizes: Responsive scale from 1rem to 2.5rem

**Interactive Elements:**
- Smooth transitions: `--transition-base` (250ms cubic-bezier)
- Hover effects: Scale transforms, shadow elevation, subtle color shifts
- Active states: Scale down (0.98), ripple effects
- Focus states: 2px outline with 4px shadow in brand-blue

**Component Cards (from PieChart & ChartsPanel):**
- White background (`bg-white`)
- Rounded corners (`rounded-xl`)
- Layered shadows (`shadow-md` → `shadow-xl` on hover)
- Border: `border-2 border-gray-100` → `border-brand-blue/30` on hover
- Hover lift: `-translate-y-1` transform
- Entry animation: `slideUp` (0.4s ease-out)

**Tooltips (from PieChart.vue:233-356):**
- Fixed positioning with teleport to body
- White background with 2px colored border (`border-brand-blue`)
- Rounded (`rounded-xl`), large shadow (`shadow-2xl`)
- Backdrop blur effect (`backdrop-filter: blur(8px)`)
- Padding: `px-4 py-3`
- Font: `text-sm font-medium`
- Animation: `tooltipFadeIn` (0.2s ease-out, translateY)
- Bold author name: `text-brand-blue text-base block mb-2`

**Chart Styling:**
- SVG elements use system font stack
- Reference lines: Gray dashed (`#ccc`, `stroke-dasharray: '4,4'`)
- Data points: Colored circles with white stroke, 0.85 opacity, cursor pointer
- Hover states: Reduced opacity (0.8), brightness filter (1.1)

### Issues with Current Z-Score Chart

1. **Container lacks card styling**: No white background, borders, shadows, or hover effects
2. **Tooltip design inconsistent**: Different border style, no backdrop blur, positioned incorrectly
3. **Typography misalignment**: Generic sans-serif instead of Inter font
4. **Axis styling basic**: Black text without brand color hierarchy
5. **No hover animations**: Chart container doesn't respond to interaction
6. **Quadrant labels too subtle**: Hard to read at #666 color
7. **Missing visual hierarchy**: All text elements same weight/size
8. **No responsive considerations**: Fixed 1000x800 size doesn't adapt
9. **Chart title missing**: No clear heading explaining the visualization
10. **No chart description**: Users lack context for interpreting Z-scores

## Enhancement Plan

### Phase 1: Container & Card Styling (ContributionZScoreChart.vue:222-227)

**Current State:**
```css
.chart-container {
  position: relative;
  width: 1000px;
  height: 800px;
  margin: 0 auto;
}
```

**Proposed Changes:**
```css
.chart-container {
  @apply relative bg-white rounded-xl shadow-lg
         border-2 border-gray-100 transition-all duration-300
         hover:shadow-xl hover:border-brand-blue/30
         p-6;
  max-width: 1000px;
  margin: 0 auto;
  animation: slideUp 0.4s ease-out;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

**Rationale:** Match the `.pie-card` styling from ChartsPanel.vue:276-286 and PieChart.vue card wrapper. This creates visual consistency across all chart types.

### Phase 2: Add Chart Header & Description

**Location:** Add before SVG element in template (after line 2)

**Implementation:**
```vue
<div class="chart-header">
  <h3 class="chart-title">Contribution Distribution Analysis</h3>
  <p class="chart-description">
    Statistical analysis showing how each contributor compares to the average.
    Authors in the upper-right quadrant contribute to many products with high contribution counts.
  </p>
</div>
```

**Styling:**
```css
.chart-header {
  @apply mb-6 text-center;
}

.chart-title {
  @apply text-2xl font-bold text-brand-gray mb-3;
  font-family: 'Inter', sans-serif;
}

.chart-description {
  @apply text-sm text-gray-600 leading-relaxed max-w-2xl mx-auto;
  font-family: 'Inter', sans-serif;
}
```

**Rationale:** Matches heading styles from ChartsPanel.vue:301-302 and provides context similar to how PieChart.vue has clear product names.

### Phase 3: Enhance SVG Typography & Styling

**Current Issues (ContributionZScoreChart.vue:229-231):**
```css
svg {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}
```

**Proposed Changes:**
```css
svg {
  display: block;
  margin: 0 auto;
  max-width: 100%;
  height: auto;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}

svg text {
  @apply fill-gray-700;
  font-weight: 500;
}

svg .axis-label {
  @apply fill-brand-gray;
  font-weight: 600;
  font-size: 14px;
}

svg .quadrant-label {
  @apply fill-gray-500;
  font-weight: 500;
  font-size: 11px;
}
```

**Code Changes (renderChart function, lines 105-116):**

Replace axis label creation with:
```javascript
// Add axis labels with classes for styling
svg.append('text')
  .attr('class', 'axis-label')
  .attr('x', width / 2)
  .attr('y', height - 10)
  .attr('text-anchor', 'middle')
  .text('Products Z-Score');

svg.append('text')
  .attr('class', 'axis-label')
  .attr('transform', 'rotate(-90)')
  .attr('x', -(height / 2))
  .attr('y', 15)
  .attr('text-anchor', 'middle')
  .text('Contributions Z-Score');
```

**Rationale:** Matches Inter font used throughout the app (style.css:10, tailwind.config.js:16). Creates visual hierarchy with different weights and sizes.

### Phase 4: Improve Reference Lines & Grid

**Current Implementation (lines 118-133):**
```javascript
svg.append('line')
  .attr('stroke', '#ccc')
  .attr('stroke-dasharray', '4,4');
```

**Proposed Changes:**
```javascript
// Add subtle background grid
const gridColor = '#f0f0f0';
const axisColor = '#cbd5e1'; // Tailwind gray-300

// Background grid lines
[-2, -1, 1, 2].forEach(z => {
  // Vertical grid lines
  svg.append('line')
    .attr('x1', xScale(z))
    .attr('x2', xScale(z))
    .attr('y1', margin.top)
    .attr('y2', height - margin.bottom)
    .attr('stroke', gridColor)
    .attr('stroke-width', 1);

  // Horizontal grid lines
  svg.append('line')
    .attr('x1', margin.left)
    .attr('x2', width - margin.right)
    .attr('y1', yScale(z))
    .attr('y2', yScale(z))
    .attr('stroke', gridColor)
    .attr('stroke-width', 1);
});

// Highlighted zero axis lines
svg.append('line')
  .attr('x1', margin.left)
  .attr('x2', width - margin.right)
  .attr('y1', yScale(0))
  .attr('y2', yScale(0))
  .attr('stroke', axisColor)
  .attr('stroke-width', 2)
  .attr('stroke-dasharray', '5,5');

svg.append('line')
  .attr('x1', xScale(0))
  .attr('x2', xScale(0))
  .attr('y1', margin.top)
  .attr('y2', height - margin.bottom)
  .attr('stroke', axisColor)
  .attr('stroke-width', 2)
  .attr('stroke-dasharray', '5,5');
```

**Rationale:** Adds visual structure and makes it easier to judge data point positions. Matches the professional look of modern data visualizations.

### Phase 5: Enhance Data Point Styling & Interactions

**Current Implementation (lines 136-181):**
```javascript
.attr('r', 6)
.attr('fill', d => authorColors.value[d.author] || '#1f77b4')
.attr('stroke', '#fff')
.attr('stroke-width', 1.5)
.style('opacity', 0.85)
.style('cursor', 'pointer')
```

**Proposed Changes:**
```javascript
// Add data points with enhanced styling
const circles = svg.selectAll('circle')
  .data(zScoreData.value)
  .enter()
  .append('circle')
  .attr('cx', d => xScale(d.zProduct))
  .attr('cy', d => yScale(d.zContrib))
  .attr('r', 7)  // Slightly larger
  .attr('fill', d => authorColors.value[d.author] || '#225EA9')
  .attr('stroke', '#fff')
  .attr('stroke-width', 2)
  .style('opacity', 0.85)
  .style('cursor', 'pointer')
  .style('transition', 'all 0.2s ease')  // Smooth transitions
  .style('filter', 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))')
  .on('mouseenter', function(event, d) {
    d3.select(this)
      .style('opacity', 1)
      .attr('r', 9)  // Grow on hover
      .style('filter', 'drop-shadow(0 4px 8px rgba(0,0,0,0.2))');
  })
  .on('mouseleave', function() {
    // Only reset if tooltip is hidden (prevents flicker)
    if (!tooltip.value.show) {
      d3.select(this)
        .style('opacity', 0.85)
        .attr('r', 7)
        .style('filter', 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))');
    }
  })
  // ... rest of event handlers
```

**Rationale:** Matches hover effects from PieChart.vue:199-208, with scale and filter changes. Adds drop shadow for depth perception.

### Phase 6: Redesign Tooltip (ContributionZScoreChart.vue:233-252)

**Current Implementation:**
```vue
<div v-if="tooltip.show" class="tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
  <b><span :style="{ color: authorColors[tooltip.author] || '#1f77b4' }">{{ tooltip.author }}</span></b><br/>
  Products: {{ tooltip.products }} (Z: {{ tooltip.zProduct }})<br/>
  Total Contributions: {{ tooltip.contributions }} (Z: {{ tooltip.zContrib }})<br/>
  <span class="click-hint">Click to view author details</span>
</div>
```

**Proposed Template:**
```vue
<teleport to="body">
  <div v-if="tooltip.show" class="zscore-tooltip" :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }">
    <div class="tooltip-header">
      <span class="author-name" :style="{ color: authorColors[tooltip.author] || '#225EA9' }">
        {{ tooltip.author }}
      </span>
    </div>
    <div class="tooltip-body">
      <div class="stat-row">
        <span class="stat-label">Products:</span>
        <span class="stat-value">{{ tooltip.products }}</span>
        <span class="stat-zscore">(Z: {{ tooltip.zProduct }})</span>
      </div>
      <div class="stat-row">
        <span class="stat-label">Contributions:</span>
        <span class="stat-value">{{ tooltip.contributions }}</span>
        <span class="stat-zscore">(Z: {{ tooltip.zContrib }})</span>
      </div>
    </div>
    <div class="tooltip-footer">
      <span class="click-hint">💡 Click to filter by author</span>
    </div>
  </div>
</teleport>
```

**Proposed Styles:**
```css
.zscore-tooltip {
  @apply fixed pointer-events-none bg-white rounded-xl shadow-2xl
         border-2 px-4 py-3 text-sm font-medium;
  border-color: var(--brand-blue);
  z-index: 9999;
  min-width: 240px;
  backdrop-filter: blur(8px);
  animation: tooltipFadeIn 0.2s ease-out;
  font-family: 'Inter', sans-serif;
}

@keyframes tooltipFadeIn {
  from {
    opacity: 0;
    transform: translateY(-8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.tooltip-header {
  @apply border-b border-gray-200 pb-2 mb-2;
}

.author-name {
  @apply font-bold text-base;
}

.tooltip-body {
  @apply space-y-1.5;
}

.stat-row {
  @apply flex items-center justify-between gap-3 text-gray-700;
}

.stat-label {
  @apply text-xs font-medium text-gray-500 uppercase tracking-wide;
  flex: 0 0 auto;
}

.stat-value {
  @apply font-mono font-bold text-brand-gray;
  flex: 0 0 auto;
}

.stat-zscore {
  @apply text-xs text-gray-500 font-mono;
  flex: 1 1 auto;
  text-align: right;
}

.tooltip-footer {
  @apply border-t border-gray-200 pt-2 mt-2;
}

.click-hint {
  @apply text-xs text-gray-500 italic flex items-center gap-1;
}
```

**Rationale:**
- Matches PieChart tooltip styling (PieChart.vue:337-360)
- Uses teleport to escape stacking context issues
- Adds visual hierarchy with header/body/footer sections
- Monospace font for numbers matches `.stat-value` pattern (style.css:36-38)
- Improved layout with flexbox for better alignment

### Phase 7: Enhance Quadrant Labels

**Current Implementation (lines 184-200):**
```javascript
const quadrantLabels = [
  { x: xScale(2), y: yScale(2), text: 'High Products & Contributions' },
  // ...
];

svg.selectAll('.quadrant-label')
  .data(quadrantLabels)
  .enter()
  .append('text')
  .attr('text-anchor', 'middle')
  .attr('font-size', '12px')
  .attr('fill', '#666')
  .text(d => d.text);
```

**Proposed Changes:**
```javascript
// Quadrant background panels
const quadrants = [
  { x: xScale(0), y: yScale(0), width: xScale(3) - xScale(0), height: yScale(0) - yScale(3), class: 'quadrant-high-high', label: 'High Impact' },
  { x: margin.left, y: yScale(0), width: xScale(0) - margin.left, height: yScale(0) - yScale(3), class: 'quadrant-low-high', label: 'Specialist' },
  { x: margin.left, y: yScale(-3), width: xScale(0) - margin.left, height: yScale(0) - yScale(-3), class: 'quadrant-low-low', label: 'Limited Activity' },
  { x: xScale(0), y: yScale(-3), width: xScale(3) - xScale(0), height: yScale(0) - yScale(-3), class: 'quadrant-high-low', label: 'Broad Scope' }
];

// Add subtle background colors to quadrants
svg.selectAll('.quadrant-bg')
  .data(quadrants)
  .enter()
  .append('rect')
  .attr('class', d => `quadrant-bg ${d.class}`)
  .attr('x', d => d.x)
  .attr('y', d => d.y)
  .attr('width', d => d.width)
  .attr('height', d => d.height)
  .attr('fill', (d, i) => {
    const colors = ['rgba(8, 143, 155, 0.03)', 'rgba(225, 234, 169, 0.03)',
                    'rgba(220, 220, 220, 0.03)', 'rgba(240, 130, 35, 0.03)'];
    return colors[i];
  })
  .attr('pointer-events', 'none');

// Enhanced quadrant labels
const labelData = [
  { x: xScale(1.5), y: yScale(2.5), text: 'High Impact', subtext: 'Many products, high contributions', color: '#006B75' },
  { x: xScale(-1.5), y: yScale(2.5), text: 'Specialist', subtext: 'Few products, high contributions', color: '#088F9B' },
  { x: xScale(-1.5), y: yScale(-2.5), text: 'Limited Activity', subtext: 'Few products & contributions', color: '#999' },
  { x: xScale(1.5), y: yScale(-2.5), text: 'Broad Scope', subtext: 'Many products, lower contributions', color: '#D47113' }
];

labelData.forEach(label => {
  // Main label
  svg.append('text')
    .attr('x', label.x)
    .attr('y', label.y)
    .attr('text-anchor', 'middle')
    .attr('font-size', '13px')
    .attr('font-weight', '600')
    .attr('fill', label.color)
    .attr('class', 'quadrant-label-main')
    .text(label.text);

  // Subtext
  svg.append('text')
    .attr('x', label.x)
    .attr('y', label.y + 16)
    .attr('text-anchor', 'middle')
    .attr('font-size', '10px')
    .attr('font-weight', '400')
    .attr('fill', '#999')
    .attr('class', 'quadrant-label-sub')
    .text(label.subtext);
});
```

**Rationale:**
- Adds visual separation between quadrants with subtle background colors
- Two-line labels provide better context for interpretation
- Color-coded labels match brand colors and provide visual hierarchy
- Improves readability and user understanding of the chart

### Phase 8: Responsive Design Improvements

**Current Issues:**
- Fixed 1000x800 dimensions don't adapt to screen size
- No mobile considerations

**Proposed Changes:**

**Template updates (lines 60-63):**
```javascript
// Reactive dimensions based on container size
const containerRef = ref(null);
const dimensions = reactive({
  width: 1000,
  height: 800
});

// Add resize observer
onMounted(() => {
  renderChart();

  // Set up responsive sizing
  if (containerRef.value) {
    const updateDimensions = () => {
      const containerWidth = containerRef.value.clientWidth;
      dimensions.width = Math.max(600, Math.min(1200, containerWidth - 48)); // Account for padding
      dimensions.height = dimensions.width * 0.8; // Maintain aspect ratio
      renderChart();
    };

    updateDimensions();
    window.addEventListener('resize', updateDimensions);

    onBeforeUnmount(() => {
      window.removeEventListener('resize', updateDimensions);
    });
  }
});
```

**Update renderChart to use reactive dimensions:**
```javascript
function renderChart() {
  const width = dimensions.width;
  const height = dimensions.height;

  // Responsive margins
  const margin = {
    top: height * 0.05,
    right: width * 0.04,
    bottom: height * 0.075,
    left: width * 0.06
  };

  // ... rest of function uses these values
}
```

**CSS updates:**
```css
.chart-container {
  @apply relative bg-white rounded-xl shadow-lg
         border-2 border-gray-100 transition-all duration-300
         hover:shadow-xl hover:border-brand-blue/30
         p-6;
  max-width: 100%;
  width: 100%;
  margin: 0 auto;
  animation: slideUp 0.4s ease-out;
}

@media (max-width: 768px) {
  .chart-container {
    @apply p-4;
  }

  .chart-title {
    @apply text-xl;
  }

  .chart-description {
    @apply text-xs;
  }
}
```

**Rationale:** Makes the chart usable on various screen sizes while maintaining readability and proportions.

## Implementation Order

1. **Phase 1** (Container & Card Styling) - Foundation for visual consistency
2. **Phase 2** (Chart Header) - Context for users
3. **Phase 6** (Tooltip Redesign) - High-impact UX improvement
4. **Phase 3** (SVG Typography) - Brand alignment
5. **Phase 5** (Data Point Interactions) - Enhanced interactivity
6. **Phase 7** (Quadrant Labels) - Improved interpretability
7. **Phase 4** (Reference Lines & Grid) - Visual structure
8. **Phase 8** (Responsive Design) - Accessibility across devices

## Testing Checklist

- [ ] Chart container has proper card styling matching other components
- [ ] Hover effects work smoothly on container and data points
- [ ] Tooltip appears correctly positioned and styled
- [ ] Tooltip teleports to body to avoid clipping issues
- [ ] Author click functionality filters to clicked author
- [ ] Typography matches Inter font family
- [ ] Colors align with brand variables
- [ ] Quadrant labels are readable and informative
- [ ] Reference lines provide useful visual structure
- [ ] Chart is responsive on desktop (1920px, 1440px, 1024px)
- [ ] Chart is usable on tablet (768px)
- [ ] All animations run smoothly at 60fps
- [ ] Accessibility: keyboard navigation works
- [ ] Accessibility: screen reader can interpret chart context

## Files to Modify

- `Vue-App/components/ContributionZScoreChart.vue` (all changes)

## Estimated Complexity

**Medium** - Primarily styling updates with some structural template changes. No complex state management or data processing modifications required.

## Dependencies

- Existing: d3, Vue 3 Composition API, Pinia store
- No new dependencies required

## Accessibility Considerations

1. Add ARIA labels to SVG elements
2. Ensure tooltip content is accessible via keyboard
3. Add focus indicators for data points
4. Provide text alternative describing chart purpose
5. Ensure color contrast meets WCAG AA standards (all proposed colors do)

## Performance Considerations

- Resize event should be debounced (add 150ms debounce)
- D3 transitions should use requestAnimationFrame (already handled by D3)
- Tooltip should not cause layout thrashing (uses transform, not top/left changes)
- Background grid should render before data points (already correct order)

## Future Enhancements (Out of Scope)

1. Export chart as PNG/SVG
2. Toggle between different statistical views (percentile, standard deviation bands)
3. Color coding by team instead of individual authors
4. Animation on initial data point render
5. Zoom/pan functionality for detailed inspection
6. Compare button to see historical Z-score changes
