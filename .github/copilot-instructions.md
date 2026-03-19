# ContributorsAnalyzer - AI Agent Instructions

This project analyzes contributor data from TFS version control and Git repositories to visualize code ownership and team contributions.

## Architecture Overview

### Data Flow
1. PowerShell scripts fetch contributor data from TFS/Git repositories
2. Data is processed and exported to CSV files
3. Vue.js app visualizes the data with D3.js charts

### Core Components
- **PowerShell Scripts**: Extract and process contributor data
  - `Fetch-TFSContributors.ps1`: Retrieves TFS version control history
  - `Generate-CombinedOwnershipReport.ps1`: Processes raw data into ownership metrics
  - `Run-GenerateOwnershipReport.ps1`: Orchestrates the entire workflow
- **Vue.js Frontend**: Visualizes the contributor data
  - Uses Pinia for state management
  - D3.js for visualization
  - Loads team/author mappings from JSON files

## Key Developer Workflows

### Data Extraction

```powershell
# Extract TFS data (with current date - 12 months)
./Fetch-TFSContributors.ps1 -TfsCollectionUrl "https://tfsprod/tfs/DefaultCollection" -Paths "/Kontinente/prod/alpha/" -OutputCsv "TFSChanges.local.csv"

# Generate ownership report
./Generate-CombinedOwnershipReport.ps1 -TfsPaths @("/Kontinente/prod/alpha/") -TfsCsv "TFSChanges.local.csv" -FromDate "2025-01-01"

# Run the full workflow (configured in Run-GenerateOwnershipReport.ps1)
./Run-GenerateOwnershipReport.ps1
```

### Frontend Development

```bash
# In the Vue-App directory
npm install
npm run dev  # Start development server
npm run build  # Build for production
```

## Project-Specific Conventions

### Data Mapping
- `team_mappings.json`: Maps teams to authors and products
- `author_mappings.json`: Normalizes different author name variations

### Product Naming
- Product names follow the format: `{area}.{product}` (e.g., `prod.alpha`)
- Extracted automatically from TFS paths with pattern `/Kontinente/{area}/{product}/` or `/GP/{area}/{product}/`

### Chart Visualization
- Products are visualized as pie charts showing author contributions
- Authors are visualized as donut charts showing product contributions
- The dashboard allows switching between these two views

## Critical Integration Points

1. **TFS/Git Integration**:
   - Requires proper TFS collection URL configuration in `Run-GenerateOwnershipReport.ps1`
   - Git repositories must be available at the path specified by `$gitRepoRoot`

2. **Data Format**:
   - CSV format: `Product,Author,ContributionCount,FileCount`
   - Last line contains date range info: `Since=YYYY-MM-DD,Until=YYYY-MM-DD`

3. **Frontend Data Loading**:
   - The Vue app automatically loads `RawOwnershipReport.example.csv` and `author_mappings.json`
   - For custom data, modify the paths in `DashboardView.vue`
