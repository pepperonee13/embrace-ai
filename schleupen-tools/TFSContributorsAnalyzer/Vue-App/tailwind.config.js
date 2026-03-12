/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./App.vue",
    "./main.js",
    "./components/**/*.{vue,js,ts,jsx,tsx}",
    "./views/**/*.{vue,js,ts,jsx,tsx}",
    "./router/**/*.{vue,js,ts,jsx,tsx}",
    "./stores/**/*.{vue,js,ts,jsx,tsx}",
    "./utils/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['JetBrains Mono', 'Courier New', 'monospace'],
      },
      colors: {
        // TIMETOACT Brand Colors from logo
        'brand': {
          'blue': {
            DEFAULT: '#225EA9',
            'light': '#1E5EA8',
            'dark': '#054A80',
          },
          'teal': {
            DEFAULT: '#088F9B',
            'dark': '#006B75',
          },
          'orange': {
            DEFAULT: '#F08223',
            'dark': '#D47113',
          },
          'gray': {
            DEFAULT: '#2F3944',
          }
        },
        // VCS colors mapped to brand
        'vcs': {
          'git': '#088F9B',  // Brand teal
          'tfs': '#F08223',  // Brand orange
          'unknown': '#6c757d'
        }
      },
      animation: {
        'fade-in': 'fadeIn 0.3s ease-in-out',
        'slide-up': 'slideUp 0.4s ease-out',
        'scale-in': 'scaleIn 0.3s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(20px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        scaleIn: {
          '0%': { transform: 'scale(0.95)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
      },
    },
  },
  plugins: [],
}
