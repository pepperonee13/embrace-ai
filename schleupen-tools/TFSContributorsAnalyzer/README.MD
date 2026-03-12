# Contributor analyser

This tool has the primary goal of making the first step the concious know-how sharing.

By visualising who contributes how much and where helps individuals find dev leads/domain experts/product responsibles/people with the most know-how in specific areas.

Metrics like "bus factor" can also be read from the visualisations.

# How does it work?

Run-GenerateOwnershipReport.ps1 contains Product Shortcuts both for solutions that are still in TFS VC as well as one that are already in GIT.

The basic workflow is:
- fetch product history (TFS history or git log)
- parse history
- store parsed history in CSV file
- display dashboard based on CSV file

Before executing:
- check and adjust product shortcuts (TODO: extract them to config file and pass it as parameter)
- check and adjust parameters like local git repo root path and from dates

# How to Run the Script

The `Run-GenerateOwnershipReport.ps1` script is used to generate ownership reports and timeline data for contributors. It supports both TFS and Git repositories.

## Usage

```powershell
./Run-GenerateOwnershipReport.ps1 [-Environment <EnvironmentName>]
```

### Parameters
- `-Environment` (Optional): Specifies the environment for the generated files. For example, if you set `-Environment TEST`, the output files will include `.TEST` in their names. If not provided, the default filenames without any environment suffix will be used.

### Example
To run the script for the default environment:
```powershell
./Run-GenerateOwnershipReport.ps1
```

To run the script for the `TEST` environment:
```powershell
./Run-GenerateOwnershipReport.ps1 -Environment TEST
```

### Notes
- Ensure that the required product shortcuts and parameters (e.g., Git repo root path, from dates) are correctly configured in the script or passed dynamically.
- The script dynamically adjusts file paths based on the provided environment parameter.

## Prerequisites

Before running the `Run-GenerateOwnershipReport.ps1` script, ensure the following JSON configuration files in the `Vue-App` folder are properly set up:

### Required Configuration Files
1. **`team_mappings.json`**: Defines the mapping of teams to products. This file is used to extract product shortcuts for both TFS and Git repositories.
2. **`author_mappings.json`**: Maps author names to canonical names. This helps unify contributor names across different repositories.
3. **`ignored_authors.json`** (Optional): Specifies authors to exclude from the analysis.

### Environment-Specific Configuration
If you are using the `-Environment` parameter, ensure that environment-specific versions of these files exist. For example:
- `team_mappings.TEST.json`
- `author_mappings.TEST.json`
- `ignored_authors.TEST.json`

The script will dynamically select the appropriate file based on the provided environment parameter. If no environment is specified, the default files (e.g., `team_mappings.json`) will be used.

### Example
For the `TEST` environment:
- Ensure `team_mappings.TEST.json` and `author_mappings.TEST.json` are present in the `Vue-App` folder.
- Run the script with the `-Environment TEST` parameter:
  ```powershell
  ./Run-GenerateOwnershipReport.ps1 -Environment TEST
  ```

For the default environment:
- Ensure `team_mappings.json` and `author_mappings.json` are present in the `Vue-App` folder.
- Run the script without the `-Environment` parameter:
  ```powershell
  ./Run-GenerateOwnershipReport.ps1
  ```

### Frontend Configuration

The frontend, located in the `Vue-App` folder, uses a `.env` file to configure the environment. The `VITE_ENVIRONMENT` variable in the `.env` file determines the current environment (e.g., `production`, `development`, `staging`). This environment setting is used by the `utils/environment.js` utility to dynamically construct file paths for environment-specific data.

### Example `.env` File
For the `TEST` environment, the `.env` file might look like this:
```
VITE_ENVIRONMENT=TEST
```

For the default `production` environment, the `.env` file might look like this:
```
VITE_ENVIRONMENT=production
```

### How It Works
The `utils/environment.js` file contains the following key functions:
- **`getCurrentEnvironment`**: Retrieves the current environment from the `VITE_ENVIRONMENT` variable.
- **`getEnvironmentPath`**: Appends the environment suffix to file paths based on the current environment. For example:
  - In `production`: `team_mappings.json`
  - In `TEST`: `team_mappings.TEST.json`

### Keeping in Sync
Ensure that the `VITE_ENVIRONMENT` value in the `.env` file matches the environment parameter used in the `Run-GenerateOwnershipReport.ps1` script. This ensures that the frontend and backend use the same environment-specific data files.

### Purpose of Each JSON Configuration File

The `Vue-App` folder contains several JSON configuration files that are essential for the proper functioning of the tool. Below is a detailed description of each file:

1. **`team_mappings.json`**
   - **Purpose**: Maps teams to their respective products. This file is used to determine which products belong to which teams, enabling the script to extract product shortcuts for both TFS and Git repositories.
   - **Example Structure**:
     ```json
     [
       {
         "team": "Team A",
         "products": [
           { "name": "product1", "source": "tfs" },
           { "name": "product2", "source": "git" }
         ]
       },
       {
         "team": "Team B",
         "products": [
           { "name": "product3", "source": "git" }
         ]
       }
     ]
     ```

2. **`author_mappings.json`**
   - **Purpose**: Maps author names (e.g., usernames or email addresses) to canonical names. This helps unify contributor names across different repositories, ensuring consistency in the generated reports.
   - **Example Structure**:
     ```json
     {
       "jdoe": "John Doe",
       "asmith": "Alice Smith"
     }
     ```

3. **`ignored_authors.json`** (Optional)
   - **Purpose**: Specifies a list of authors to exclude from the analysis. This is useful for filtering out system accounts or other irrelevant contributors.
   - **Example Structure**:
     ```json
     [
       "system_account",
       "build_server"
     ]
     ```

4. **Environment-Specific Versions**
   - For each of the above files, environment-specific versions can be created by appending the environment name to the filename (e.g., `team_mappings.TEST.json`, `author_mappings.TEST.json`). These files are used when the `-Environment` parameter is specified in the PowerShell script.

### Notes
- Ensure that these files are correctly configured before running the script.
- The `VITE_ENVIRONMENT` variable in the `.env` file determines which environment-specific files are used by the frontend.