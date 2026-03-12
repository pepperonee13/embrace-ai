# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ContributionAnalyzer is a Vue.js dashboard application for visualizing Team Foundation Server (TFS) code ownership and contribution data. It processes CSV data to create interactive charts and visualizations for understanding team contributions and code ownership patterns.

## Technology Stack

- **Vue 3** with Composition API and `<script setup>` syntax
- **Vite** for build tooling and development server
- **Pinia** for state management
- **Vue Router** for navigation
- **D3.js** for custom data visualizations
- **PapaParse** for CSV data processing

## Common Development Commands

```bash
# Navigate to Vue app directory
cd Vue-App

# Install dependencies
npm install

# Start development server (opens at http://localhost:5173)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## PowerShell Data Scripts

```powershell
# Fetch TFS contributor data
./Fetch-TFSContributors.ps1

# Generate combined ownership report
./Generate-CombinedOwnershipReport.ps1
```

## Application Architecture

### Component Structure
- **App.vue**: Main application component with router outlet
- **Components**:
  - `AuthorDonutChart.vue`: D3.js donut chart for author contributions
  - `ChartsPanel.vue`: Container for multiple chart visualizations
  - `FilterPanel.vue`: UI controls for data filtering
  - `PieChart.vue`: D3.js pie chart component
- **Views**:
  - `DashboardView.vue`: Main dashboard layout
- **Router**: Navigation configuration in `router/index.js`

### State Management
- **Pinia Store**: `stores/useOwnershipStore.js` manages:
  - CSV data loading and parsing
  - Author and team mapping
  - Filtered data computation
  - Chart data transformations

### Data Flow
1. CSV data → PapaParse → Pinia store
2. Store processes data with author/team mappings
3. Vue components consume reactive store data
4. D3.js renders visualizations

## Configuration Files

- **`author_mappings.json`**: Maps TFS usernames to display names
- **`team_mappings.json`**: Maps authors to team assignments
- **`teamColors.js`**: Color scheme configuration for teams
- **`RawOwnershipReport.example.csv`**: Sample data for development/testing

## Development Patterns

### Vue.js Patterns
- Uses Composition API with `<script setup>` syntax
- Reactive state management with Pinia
- Component-based architecture with clear separation of concerns
- Props and events for component communication

### D3.js Integration
- Custom D3.js charts integrated within Vue components
- Reactive data binding between Vue state and D3 visualizations
- SVG-based charts with hover interactions and tooltips

### Data Processing
- CSV parsing with PapaParse library
- Real-time filtering and data transformation
- Author/team mapping for data normalization
- Computed properties for derived data

## File Structure

```
ContributionAnalyzer/
├── Vue-App/
│   ├── components/          # Reusable Vue components
│   ├── views/              # Page-level components
│   ├── stores/             # Pinia state management
│   ├── router/             # Vue Router configuration
│   ├── *.json             # Configuration and mapping files
│   └── *.js               # Utilities and configuration
├── *.ps1                  # PowerShell data fetching scripts
└── *.csv                  # Sample data files
```

## Data Sources

The application expects CSV data with TFS contribution information. Use the PowerShell scripts to fetch real data, or work with the provided example CSV file for development.