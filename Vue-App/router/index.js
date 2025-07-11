import { createRouter, createWebHashHistory } from 'vue-router';
import DashboardView from '../views/DashboardView.vue';

const routes = [
  { path: '/', name: 'Dashboard', component: DashboardView },
  // Future: { path: '/product/:id', ... }, { path: '/author/:id', ... }
];

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

export default router;
