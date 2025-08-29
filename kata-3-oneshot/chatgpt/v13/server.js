/* eslint-disable no-console */
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const fs = require("fs");
const fsp = fs.promises;
const path = require("path");
const archiver = require("archiver");
const mime = require("mime-types");

const app = express();
app.use(cors());
app.use(express.json({ limit: "20mb" }));
app.use(express.static(path.join(__dirname, "public")));

const ROOT_DIR = process.env.ROOT_DIR
  ? path.resolve(process.env.ROOT_DIR)
  : path.join(__dirname, "sample"); // fallback to sample folder for demo

const PORT = process.env.PORT || 3000;
const DEFAULT_MODEL = process.env.DEFAULT_MODEL || "gemini-1.5-flash";

// Build file tree once at startup
let fileTree = null;
let fileIndex = new Map(); // relativePath -> absolutePath

function isHidden(name) {
  return name.startsWith(".") || name === "node_modules";
}

async function buildTree(dir, base) {
  const entries = await fsp.readdir(dir, { withFileTypes: true });
  const children = [];
  for (const e of entries) {
    if (isHidden(e.name)) continue;
    const full = path.join(dir, e.name);
    const rel = path.relative(base, full);
    const stat = await fsp.stat(full);
    if (e.isDirectory()) {
      const subtree = await buildTree(full, base);
      children.push({
        type: "dir",
        name: e.name,
        path: rel.replace(/\\/g, "/"),
        children: subtree.children,
      });
    } else if (e.isFile()) {
      fileIndex.set(rel.replace(/\\/g, "/"), full);
      children.push({
        type: "file",
        name: e.name,
        path: rel.replace(/\\/g, "/"),
        size: stat.size,
      });
    }
  }
  // sort dirs first, then files
  children.sort((a, b) => {
    if (a.type !== b.type) return a.type === "dir" ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
  return { type: "dir", name: path.basename(dir), path: "", children };
}

async function refreshIndex() {
  fileIndex.clear();
  fileTree = await buildTree(ROOT_DIR, ROOT_DIR);
}

function ensureUnderRoot(absPath) {
  const normalized = path.resolve(absPath);
  if (!normalized.startsWith(ROOT_DIR)) {
    throw new Error("Path traversal is not allowed.");
  }
  return normalized;
}

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, root: ROOT_DIR, model: DEFAULT_MODEL });
});

app.get("/api/tree", async (_req, res) => {
  try {
    res.json({ ok: true, tree: fileTree });
  } catch (err) {
    console.error(err);
    res.status(500).json({ ok: false, error: String(err.message || err) });
  }
});

app.post("/api/rescan", async (_req, res) => {
  try {
    await refreshIndex();
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ ok: false, error: String(err.message || err) });
  }
});

// Generate ZIP with Gemini response (and optional context files)
app.post("/api/generate", async (req, res) => {
  const { prompt, files = [], model, includeContextInZip = false } = req.body || {};
  if (!process.env.GOOGLE_API_KEY) {
    return res.status(400).json({ ok: false, error: "Missing GOOGLE_API_KEY in environment." });
  }
  if (!prompt || typeof prompt !== "string" || !prompt.trim()) {
    return res.status(400).json({ ok: false, error: "Prompt is required." });
  }

  // Validate files
  const validFiles = [];
  for (const rel of files) {
    const abs = fileIndex.get(rel);
    if (!abs) {
      return res.status(400).json({ ok: false, error: `Unknown file: ${rel}` });
    }
    validFiles.push({ rel, abs: ensureUnderRoot(abs) });
  }

  try {
    // Lazy-import to avoid ESM/CJS friction
    const { GoogleGenerativeAI } = await import("@google/generative-ai");
    const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
    const activeModel = genAI.getGenerativeModel({ model: model || DEFAULT_MODEL });

    // Build content parts
    const parts = [{ text: prompt }];
    for (const { rel, abs } of validFiles) {
      const buf = await fsp.readFile(abs);
      const b64 = buf.toString("base64");
      const mimeType = mime.lookup(abs) || "application/octet-stream";
      // Add a tiny text header letting the model know which file follows
      parts.push({ text: `\n[FILE NAME]: ${rel}\n[FILE MIME]: ${mimeType}\nBelow is the full content of the file.\n` });
      parts.push({ inlineData: { data: b64, mimeType } });
    }

    const result = await activeModel.generateContent({
      contents: [{ role: "user", parts }],
    });

    const modelText = result?.response?.text?.() ?? "";
    const rawResponse = JSON.stringify(result, null, 2);

    // Stream ZIP back
    res.setHeader("Content-Type", "application/zip");
    res.setHeader("Content-Disposition", 'attachment; filename="gemini_response.zip"');

    const archive = archiver("zip", { zlib: { level: 9 } });
    archive.on("error", (err) => {
      console.error("Archive error:", err);
      try { res.status(500).end(); } catch {}
    });
    archive.pipe(res);

    archive.append(`# Gemini Response\n\nModel: ${model || DEFAULT_MODEL}\n\n---\n\n${modelText}`, { name: "response/response.md" });
    archive.append(rawResponse, { name: "response/raw.json" });

    if (includeContextInZip && validFiles.length > 0) {
      for (const { rel, abs } of validFiles) {
        archive.file(abs, { name: `context/${rel}` });
      }
    }

    await archive.finalize();
  } catch (err) {
    console.error(err);
    res.status(500).json({ ok: false, error: String(err.message || err) });
  }
});

// Serve app
app.get("*", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

(async function main() {
  // Ensure sample folder exists for demo if ROOT_DIR not provided
  if (!fs.existsSync(ROOT_DIR)) {
    await fsp.mkdir(ROOT_DIR, { recursive: true });
    await fsp.writeFile(path.join(ROOT_DIR, "README.txt"), "Place your files here.\n");
  }
  await refreshIndex();
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log(`Root directory: ${ROOT_DIR}`);
  });
})();