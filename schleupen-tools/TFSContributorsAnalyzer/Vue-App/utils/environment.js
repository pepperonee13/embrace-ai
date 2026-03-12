/**
 * Gets the current environment from Vite environment variables
 * @returns {string} The current environment (production, development, staging, etc.)
 */
export const getCurrentEnvironment = () => {
  return import.meta.env.VITE_ENVIRONMENT || 'production';
};

/**
 * Gets the file path with the environment-specific suffix
 * @param {string} baseName - The base name of the file without extension
 * @param {string} extension - The file extension (including the dot)
 * @returns {string} The file path with environment suffix
 */
export const getEnvironmentPath = (baseName, extension) => {
    const env = getCurrentEnvironment();
    const suffix = env === 'production' ? '' : `.${env}`;
    return `${baseName}${suffix}${extension}`;
};

// ---- JSON config loader ----

// Glob all JSON files in Vue-App/ (one level up from utils/)
const jsonModules = import.meta.glob('../*.json', { eager: true });

export const loadEnvironmentJson = (baseName) => {
  const env = getCurrentEnvironment();
  const suffix = env === 'production' ? '' : `.${env}`;
  const filePath = `../${baseName}${suffix}.json`;

  const mod = jsonModules[filePath];
  if (!mod) {
    console.error('Available JSON modules:', Object.keys(jsonModules));
    throw new Error(`Config file not found: ${filePath}`);
  }

  return mod.default;
};

// ---- teamColors loader (env-specific JS module) ----

// Load only teamColors modules (avoid the __vite__injectQuery collision)
const teamColorsModules = import.meta.glob(
  ['../teamColors.js', '../teamColors.*.js'],
  { eager: true }
);

export const loadEnvironmentTeamColors = () => {
  const env = getCurrentEnvironment();
  const envPath = `../teamColors.${env}.js`;
  const prodPath = `../teamColors.js`;

  const mod = teamColorsModules[envPath] ?? teamColorsModules[prodPath];

  if (!mod) {
    console.error('Available teamColors modules:', Object.keys(teamColorsModules));
    throw new Error(`No teamColors module found for env "${env}"`);
  }

  // Preferred: export const TEAM_COLORS = {...}
  if (mod.TEAM_COLORS) return mod.TEAM_COLORS;

  // Accept: export default {...}
  if (mod.default) return mod.default;

  // Fallback: named exports like `export const Grün = ...`
  // (strip common meta keys if present)
  const { __esModule, ...named } = mod;
  return named;
};
