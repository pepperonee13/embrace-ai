#!/usr/bin/env node
/**
 * Minimal full‑stack web app to send a user prompt to Google's Gemini LLM
 * with optional file(s) sourced from a given local path.
 *
 * Single file. No build step. Run with:
 *   GEMINI_API_KEY=your_key node server.js /absolute/or/relative/base/path
 *
 * Optional env:
 *   PORT=3000
 *   GEMINI_MODEL=gemini-1.5-pro (default)
 *   MAX_TREE_DEPTH=6 (default)
 *   IGNORE_DIRS=node_modules,.git,.svn,.hg,.idea,.vscode,.DS_Store,dist,build,tmp,temp
 */

const path = require("path");
const fs = require("fs");
const http = require("http");
const express = require("express");
const bodyParser = require("body-parser");
const mime = require("mime");

// Gemini SDK
let GoogleGenerativeAI;
try {
  ({ GoogleGenerativeAI } = require("@google/generative-ai"));
} catch (_) {
  console.error("\nMissing dependency '@google/generative-ai'.\nInstall deps first: npm i express body-parser mime @google/generative-ai\n");
  // continue; we'll throw later on first request if still missing
}

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-1.5-pro";
const MAX_TREE_DEPTH = process.env.MAX_TREE_DEPTH ? Number(process.env.MAX_TREE_DEPTH) : 6;
const IGNORE_DIRS = (process.env.IGNORE_DIRS || "node_modules,.git,.svn,.hg,.idea,.vscode,.DS_Store,dist,build,tmp,temp")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const basePathArg = process.argv[2];
if (!basePathArg) {
  console.error("Usage: node server.js <base-path>\nExample: node server.js ./docs\n");
  process.exit(1);
}
const BASE_PATH = path.resolve(process.cwd(), basePathArg);
if (!fs.existsSync(BASE_PATH) || !fs.statSync(BASE_PATH).isDirectory()) {
  console.error(`Base path does not exist or is not a directory: ${BASE_PATH}`);
  process.exit(1);
}

// --- Utilities ---
function isIgnored(name) {
  return IGNORE_DIRS.includes(name);
}

function safeRel(p) {
  const rel = path.relative(BASE_PATH, p);
  // prevent escaping base path
  if (rel.startsWith("..")) throw new Error("Path escapes base directory");
  return rel.replace(/\\/g, "/");
}

function buildTree(dir, depth = 0) {
  const name = path.basename(dir);
  const node = { name, path: safeRel(dir), type: "dir", children: [] };
  if (depth >= MAX_TREE_DEPTH) return node;
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (e) {
    node.error = e.message;
    return node;
  }
  for (const ent of entries) {
    if (ent.name.startsWith(".")) continue; // hide dotfiles by default
    if (ent.isDirectory() && isIgnored(ent.name)) continue;
    const full = path.join(dir, ent.name);
    try {
      if (ent.isDirectory()) {
        node.children.push(buildTree(full, depth + 1));
      } else if (ent.isFile()) {
        node.children.push({
          name: ent.name,
          path: safeRel(full),
          type: "file",
          size: fs.statSync(full).size,
          mime: mime.getType(full) || "application/octet-stream",
        });
      }
    } catch (e) {
      node.children.push({ name: ent.name, path: safeRel(full), type: "error", error: e.message });
    }
  }
  // sort: dirs first, then files
  node.children.sort((a, b) => (a.type === b.type ? a.name.localeCompare(b.name) : a.type === "dir" ? -1 : 1));
  return node;
}

function readFilePart(relPath) {
  const full = path.join(BASE_PATH, relPath);
  const stat = fs.statSync(full);
  if (!stat.isFile()) throw new Error("Not a file: " + relPath);
  const buf = fs.readFileSync(full);
  const mt = mime.getType(full) || "application/octet-stream";
  return { dataB64: buf.toString("base64"), mimeType: mt, name: path.basename(full) };
}

async function generateWithGemini(prompt, relFilePaths) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error("GEMINI_API_KEY is not set");
  }
  if (!GoogleGenerativeAI) {
    ({ GoogleGenerativeAI } = require("@google/generative-ai"));
  }
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

  const parts = [];
  if (prompt && prompt.trim()) parts.push({ text: prompt.trim() });
  for (const rel of relFilePaths || []) {
    const { dataB64, mimeType, name } = readFilePart(rel);
    // Inline file data; Gemini supports text, images, PDFs, code, etc.
    parts.push({ inlineData: { data: dataB64, mimeType } });
    // Provide a hint with filename as text to add context
    parts.push({ text: `Attached file: ${name} (path: ${rel})` });
  }

  const res = await model.generateContent({
    contents: [{ role: "user", parts }],
  });
  const out = res.response;
  return out.text?.() || "(No text response)";
}

// --- App ---
const app = express();
app.use(bodyParser.json({ limit: "25mb" }));
app.use(bodyParser.urlencoded({ extended: true, limit: "25mb" }));

app.get("/api/tree", (req, res) => {
  try {
    const tree = buildTree(BASE_PATH, 0);
    res.json({ basePath: BASE_PATH, tree, ignore: IGNORE_DIRS, maxDepth: MAX_TREE_DEPTH });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post("/api/generate", async (req, res) => {
  const { prompt, files } = req.body || {};
  if (!prompt && (!files || files.length === 0)) {
    return res.status(400).json({ error: "Provide a prompt and/or at least one file." });
  }
  try {
    const text = await generateWithGemini(String(prompt || ""), Array.isArray(files) ? files : []);
    res.json({ ok: true, model: GEMINI_MODEL, text });
  } catch (e) {
    console.error("/api/generate error:", e);
    res.status(500).json({ error: e.message });
  }
});

// Serve a tiny embedded UI
app.get("/", (req, res) => {
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.end(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Gemini Prompt App</title>
  <style>
    :root { --bg:#0b1020; --card:#121a33; --muted:#2a355f; --text:#e6ecff; --acc:#8fb3ff; }
    html,body{height:100%;}
    body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu; background:var(--bg); color:var(--text);} 
    .container{max-width:1100px;margin:0 auto;padding:24px;}
    .grid{display:grid;grid-template-columns: 1fr 1.2fr; gap:18px;}
    .card{background:var(--card);border:1px solid var(--muted);border-radius:16px;padding:16px; box-shadow:0 6px 18px rgba(0,0,0,.25);} 
    h1{font-weight:700;letter-spacing:.3px;margin:0 0 12px;}
    h2{font-size:14px;text-transform:uppercase;opacity:.85;letter-spacing:.6px;margin:0 0 8px}
    .tree{max-height:60vh;overflow:auto;padding:8px;border-radius:12px;border:1px solid var(--muted);}
    .dir{font-weight:600}
    .file{opacity:.95}
    details > summary { cursor:pointer; }
    .controls{display:flex; gap:12px; align-items:center; margin:8px 0 12px}
    textarea{width:100%;min-height:140px;border-radius:12px;border:1px solid var(--muted);background:#0e1630;color:var(--text);padding:12px;font:inherit}
    button{background:var(--acc);border:0;color:#0b1020;padding:10px 14px;border-radius:12px;font-weight:700;cursor:pointer}
    button[disabled]{opacity:.6;cursor:not-allowed}
    .badge{background:#0e1630;border:1px solid var(--muted);padding:2px 8px;border-radius:999px;font-size:12px}
    .response{white-space:pre-wrap; background:#0e1630; border-radius:12px; border:1px solid var(--muted); padding:12px; min-height:120px}
    .path{font-family:ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;}
    .small{opacity:.8;font-size:12px}
  </style>
</head>
<body>
  <div class="container">
    <h1>Gemini Prompt App</h1>
    <div class="small">Base path: <span id="base" class="path"></span> · Model: <span id="model" class="badge"></span></div>
    <div class="grid">
      <div class="card">
        <h2>Files</h2>
        <div class="controls">
          <button id="expandAll">Expand all</button>
          <button id="collapseAll">Collapse all</button>
          <button id="clearSel">Clear selection</button>
        </div>
        <div id="tree" class="tree"></div>
      </div>
      <div class="card">
        <h2>Prompt</h2>
        <textarea id="prompt" placeholder="Enter your prompt..."></textarea>
        <div class="controls">
          <span id="selCount" class="badge">0 files selected</span>
          <button id="send">Send to Gemini</button>
        </div>
        <h2>Response</h2>
        <div id="resp" class="response"></div>
      </div>
    </div>
  </div>

<script>
  const $ = (sel) => document.querySelector(sel);
  const baseSpan = $('#base');
  const modelSpan = $('#model');
  const treeEl = $('#tree');
  const promptEl = $('#prompt');
  const respEl = $('#resp');
  const sendBtn = $('#send');
  const selCount = $('#selCount');

  let selected = new Set();

  function updateSelCount(){ selCount.textContent = selected.size + (selected.size === 1 ? ' file selected' : ' files selected'); }

  function nodeHtml(node){
    if(node.type === 'dir'){
      const children = (node.children||[]).map(nodeHtml).join('');
      const open = '';
      return `<details ${open}><summary class="dir">📁 ${escapeHtml(node.name)}</summary><div style="margin-left:14px">${children}</div></details>`;
    }
    if(node.type === 'file'){
      const id = `cb_${btoa(node.path).replace(/=/g,'')}`;
      return `<label class="file"><input type="checkbox" data-path="${encodeURIComponent(node.path)}" id="${id}"> 📄 ${escapeHtml(node.name)} <span class="small badge">${escapeHtml(node.mime||'')}</span></label>`;
    }
    return `<div>⚠️ ${escapeHtml(node.name)} (${escapeHtml(node.error||node.type)})</div>`;
  }

  function escapeHtml(s){return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));}

  async function loadTree(){
    respEl.textContent = '';
    const r = await fetch('/api/tree');
    const j = await r.json();
    if(j.error){ treeEl.textContent = 'Error: ' + j.error; return; }
    baseSpan.textContent = j.basePath;
    modelSpan.textContent = (j.model || 'gemini-1.5-pro');
    treeEl.innerHTML = nodeHtml(j.tree);

    treeEl.querySelectorAll('input[type=checkbox]').forEach(cb => {
      cb.addEventListener('change', () => {
        const p = decodeURIComponent(cb.getAttribute('data-path'));
        if(cb.checked) selected.add(p); else selected.delete(p);
        updateSelCount();
      });
    });

    updateSelCount();
  }

  $('#expandAll').addEventListener('click', () => {
    treeEl.querySelectorAll('details').forEach(d => d.open = true);
  });
  $('#collapseAll').addEventListener('click', () => {
    treeEl.querySelectorAll('details').forEach(d => d.open = false);
  });
  $('#clearSel').addEventListener('click', () => {
    selected.clear();
    treeEl.querySelectorAll('input[type=checkbox]').forEach(cb => cb.checked = false);
    updateSelCount();
  });

  sendBtn.addEventListener('click', async () => {
    sendBtn.disabled = true;
    respEl.textContent = '⏳ Generating...';
    try{
      const r = await fetch('/api/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: promptEl.value, files: Array.from(selected) }),
      });
      const j = await r.json();
      if(j.error) throw new Error(j.error);
      respEl.textContent = j.text || '(No text)';
    }catch(e){
      respEl.textContent = 'Error: ' + e.message;
    }finally{
      sendBtn.disabled = false;
    }
  });

  loadTree();
</script>
</body>
</html>`);
});

const server = http.createServer(app);
server.listen(PORT, () => {
  console.log(`\nGemini Prompt App running on http://localhost:${PORT}`);
  console.log(`Base path: ${BASE_PATH}`);
  console.log(`Model: ${GEMINI_MODEL}`);
});
