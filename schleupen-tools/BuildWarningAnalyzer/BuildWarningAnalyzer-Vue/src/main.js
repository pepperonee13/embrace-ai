import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { createPinia } from 'pinia';
import { useDataStore } from './stores/useDataStore'

const app = createApp(App);
const pinia = createPinia()

app.use(router);
app.use(pinia);

const dataStore = useDataStore();

// Load data before mounting the app
dataStore.loadData().finally(() => {
  app.mount('#app')
})
