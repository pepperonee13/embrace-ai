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
