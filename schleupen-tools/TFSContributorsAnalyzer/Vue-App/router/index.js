import { createRouter, createWebHashHistory } from 'vue-router';
import DashboardView from '../views/DashboardView.vue';
import TimelineView from '../views/TimelineView.vue';
import AdminView from '../views/AdminView.vue';
import ProductDetailView from '../views/ProductDetailView.vue';

const routes = [
  { path: '/', name: 'Dashboard', component: DashboardView },
  {
    path: '/timeline',
    name: 'Timeline',
    component: TimelineView,
    // Allow query parameters for filtering
    props: route => ({ query: route.query })
  },
  {
    path: '/admin',
    name: 'Admin',
    component: AdminView
  },
  {
    path: '/product/:name',
    name: 'ProductDetail',
    component: ProductDetailView,
    props: true
  },
];

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

export default router;
