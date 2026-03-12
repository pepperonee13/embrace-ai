import { createRouter, createWebHashHistory } from 'vue-router'
import DashboardView from '../views/DashboardView.vue'
import SolutionView from '../views/SolutionView.vue'

const routes = [
  { path: '/', component: DashboardView },
  { path: '/solution/:filePath', component: SolutionView, props: true }
]

export default createRouter({
  history: createWebHashHistory(),
  routes
})
