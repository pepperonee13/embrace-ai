const treeEl = document.getElementById("tree");
const rootPathEl = document.getElementById("rootPath");
const promptEl = document.getElementById("prompt");
const sendBtn = document.getElementById("sendBtn");
const selCountEl = document.getElementById("selCount");
const outputEl = document.getElementById("output");

const selected = new Set();            // relPaths of selected files
const loadedDirs = new Set();          // relPaths of directories already fetched
const nodeCache = new Map();           // relPath -> items

function humanSize(n) {
  if (typeof n !== "number") return "";
  const units = ["B","KB","MB","GB"];
  let i = 0; let v = n;
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return `${v.toFixed(v < 10 && i > 0 ? 1 : 0)} ${units[i]}`;
}

function updateSelCount() {
  selCountEl.textContent = `${selected.size} file(s) selected`;
}

function fileCheckbox(relPath) {
  const cb = document.createElement("input");
  cb.type = "checkbox";
  cb.checked = selected.has(relPath);
  cb.addEventListener("change", () => {
    if (cb.checked) selected.add(relPath);
    else selected.delete(relPath);
    updateSelCount();
  });
  return cb;
}

function renderItems(parentUL, items) {
  for (const it of items) {
    const li = document.createElement("li");
    const row = document.createElement("div");
    row.className = "row";

    if (it.kind === "dir") {
      const toggle = document.createElement("span");
      toggle.className = "folder-toggle";
      toggle.innerHTML = `<span class="caret">▶</span>`;
      const name = document.createElement("span");
      name.className = "folder-name";
      name.textContent = it.name;

      const childrenUL = document.createElement("ul");
      childrenUL.style.display = "none";

      toggle.addEventListener("click", async () => {
        const caret = toggle.querySelector(".caret");
        const isOpen = childrenUL.style.display !== "none";
        if (isOpen) {
          childrenUL.style.display = "none";
          caret.textContent = "▶";
          return;
        }
        caret.textContent = "▼";
        childrenUL.style.display = "";
        if (!loadedDirs.has(it.relPath)) {
          const data = await fetchTree(it.relPath);
          loadedDirs.add(it.relPath);
          renderItems(childrenUL, data.items);
        }
      });

      row.appendChild(toggle);
      row.appendChild(name);
      li.appendChild(row);
      li.appendChild(childrenUL);
    } else {
      const cb = fileCheckbox(it.relPath);
      const name = document.createElement("span");
      name.className = "file-name";
      name.textContent = it.name;

      const meta = document.createElement("span");
      meta.className = "file-meta";
      meta.textContent = it.size != null ? `(${humanSize(it.size)})` : "";

      row.appendChild(cb);
      row.appendChild(name);
      row.appendChild(meta);
      li.appendChild(row);
    }

    parentUL.appendChild(li);
  }
}

async function fetchTree(relPath = "") {
  if (nodeCache.has(relPath)) return nodeCache.get(relPath);
  const url = new URL("/api/tree", window.location.origin);
  if (relPath) url.searchParams.set("relPath", relPath);
  const res = await fetch(url);
  if (!res.ok) throw new Error(await res.text());
  const data = await res.json();
  nodeCache.set(relPath, data);
  return data;
}

async function init() {
  const data = await fetchTree("");
  rootPathEl.textContent = `Root: ${data.root || "/"}`;
  const ul = document.createElement("ul");
  renderItems(ul, data.items);
  treeEl.appendChild(ul);
  loadedDirs.add("");
  updateSelCount();
}

sendBtn.addEventListener("click", async () => {
  const files = Array.from(selected);
  const prompt = promptEl.value.trim();
  if (!prompt) {
    alert("Please enter a prompt.");
    return;
  }
  if (files.length === 0) {
    alert("Please select at least one file.");
    return;
  }
  sendBtn.disabled = true;
  outputEl.textContent = "Sending...";
  try {
    const res = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prompt, files })
    });
    const data = await res.json();
    if (!res.ok) {
      outputEl.textContent = `Error: ${data.error || res.statusText}\n${data.detail || ""}`;
      return;
    }
    if (data.mode === "dry-run") {
      outputEl.textContent = `DRY RUN (no API key set)\nModel: ${data.model}\nSent bytes: ${data.sentBytes}\n\nPreview:\n${data.preview}`;
    } else {
      outputEl.textContent = data.answer || "(no content)";
    }
  } catch (e) {
    outputEl.textContent = `Request failed: ${e.message}`;
  } finally {
    sendBtn.disabled = false;
  }
});

init().catch(e => {
  treeEl.textContent = `Failed to load tree: ${e.message}`;
});
