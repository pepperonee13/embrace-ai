<template>
  <div>
    <h1>
      {{ solution?.ProductShortcut }} – Build
      <a :href="buildUrl" target="_blank">{{ solution?.BuildId }}</a>
    </h1>

    <p><router-link to="/">⬅ Back to Dashboard</router-link></p>

    <div v-for="(warning, index) in sortedWarnings" :key="index" class="warning-block">
      <h3>
        <a :href="getDocsUrl(warning.Code)" target="_blank">
          {{ warning.Code }}
        </a>
        ({{ warning.Messages.length }} occurrence{{ warning.Messages.length > 1 ? 's' : '' }})
      </h3>

      <ul>
        <li v-for="(group, i) in groupMessagesByDescription(warning)" :key="i">
          <span>{{ group.description }}</span>
          <button @click="detailsOpen[index + '-' + i] = !detailsOpen[index + '-' + i]" style="margin-left: 0.5em;" v-if="group.references.length || group.filePaths.length">
            {{ detailsOpen[index + '-' + i] ? 'Hide locations' : 'Show locations' }}
          </button>
          <div v-if="detailsOpen[index + '-' + i]" style="margin-left: 1.5em; font-size: 0.95em; color: #555;">
            <div v-if="group.references.length">
              <div v-for="(ref, r) in group.references" :key="r">
                Reference: <a :href="ref" target="_blank">{{ ref }}</a>
              </div>
            </div>
            <div v-if="group.filePaths.length">
              <div>Files:</div>
              <ul>
                <li v-for="(file, f) in group.filePaths" :key="f">{{ file }}</li>
              </ul>
            </div>
          </div>
        </li>
      </ul>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { getDocsUrl } from '../utils/docs'

//TODO: PSZ
/*
- fetch build info from https://tfsprod/tfs/DefaultCollection/CS3/_apis/build/builds/{buildId}/?api-version=7.0
- show warning trends over build history
- use props instead of filepath
- group warnings by message
*/

const route = useRoute()
const solution = ref(null)
const sortedWarnings = ref([])
const showMore = ref([])
const detailsOpen = ref({})

const buildUrl = computed(() =>
  solution.value
    ? `https://tfsprod.schleupen-ag.de/tfs/DefaultCollection/CS3/_build/results?buildId=${solution.value.BuildId}&view=results`
    : '#'
)

const previewMessages = (w) => w.Messages.slice(0, 5)
const hiddenMessages = (w) => w.Messages.slice(5)

// Helper to parse a message into description, reference link, and file path
function parseMessage(msg) {
  // If there is a [file] at the end, extract it
  const fileMatch = msg.match(/\[(.*?)\]$/);
  const filePath = fileMatch ? fileMatch[1].trim() : null;
  // Remove the [file] part from the message for description/reference parsing
  let main = filePath ? msg.replace(/\s*\[.*?\]$/, '').trim() : msg;
  // If there is a (reference) at the end, extract it
  const refMatch = main.match(/\((.*?)\)$/);
  const reference = refMatch ? refMatch[1].trim() : null;
  // Remove the (reference) part from the message for description
  if (reference) main = main.replace(/\s*\(.*?\)$/, '').trim();
  // The rest is the description
  const description = main;
  return { description, reference, filePath };
}

const groupMessagesByDescription = (warning) => {
  const groups = {};
  warning.Messages.forEach((msg) => {
    const parsed = parseMessage(msg);
    const key = parsed.description;
    if (!groups[key]) {
      groups[key] = { count: 1, references: [], filePaths: [] };
      if (parsed.reference) groups[key].references.push(parsed.reference);
      if (parsed.filePath) groups[key].filePaths.push(parsed.filePath);
    } else {
      groups[key].count++;
      if (parsed.reference && !groups[key].references.includes(parsed.reference)) {
        groups[key].references.push(parsed.reference);
      }
      if (parsed.filePath && !groups[key].filePaths.includes(parsed.filePath)) {
        groups[key].filePaths.push(parsed.filePath);
      }
    }
  });
  return Object.entries(groups).map(([description, data]) => ({
    description,
    count: data.count,
    references: data.references,
    filePaths: data.filePaths
  }));
}

onMounted(async () => {
  const filePath = route.params.filePath
  const res = await fetch('/' + filePath)
  const data = await res.json()
  solution.value = data

  sortedWarnings.value = [...data.Warnings].sort(
    (a, b) => b.Messages.length - a.Messages.length
  )

  showMore.value = new Array(data.Warnings.length).fill(false)
})
</script>

<style scoped>
.warning-block {
  margin-top: 1rem;
  padding: 1rem;
  border-left: 4px solid #888;
  background: #f0f0f0;
  border-radius: 6px;
}

.warning-block h3 {
  margin-bottom: 0.5rem;
}

.warning-block ul {
  margin: 0;
  padding-left: 1.25rem;
}

.warning-block button {
  margin-top: 0.5rem;
}
</style>
