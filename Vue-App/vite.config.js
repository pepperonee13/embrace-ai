import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
  plugins: [vue()],
  server: {
    open: true,
    port: 5173
  },
  resolve: {
    alias: {
      '@': '/src',
    },
  },
});
