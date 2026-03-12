import express from "express";
import dotenv from "dotenv";
import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// --- Startup: root dir from CLI arg or CWD ---
const rootInput = process.argv[2] ? String(process.argv[2]) : process.cwd();
const rootDir = path.resolve(rootInput);
const port = Number(process.env.PORT || 3000);

// Hard caps (prevent sending massive context)
const MAX_FILE_BYTES = Number(process.env.MAX_FILE_BYTES || 262144);   // 256 KB
const MAX_TOTAL_BYTES = Number(process.env.MAX_TOTAL_BYTES || 1048576); // 1 MB

// Allow only text-like files for context to keep things simple and safe
const TEXT_EXTS = new Set([
  "txt","md","json","yaml","yml","xml","html","css","js","ts","tsx","jsx",
  "c","cpp","h","hpp","java","kt","cs","csproj","vb","rs","go","py","rb",
  "sh","ps1","sql","ini","cfg","toml","properties","gradle","sbt","dockerfile",
  "makefile","cmake","gitignore","gitattributes","bat","cmd"
]);

// Validate root dir exists
const rootStat = await fs.stat(rootDir).catch(() => null);
if (!rootStat || !rootStat.isDirectory()) {
  console.error(`Root path is not a directory: ${rootDir}`);
  process.exit(1);
}

// Helpers
function toRel(absPath) {
  // normalized forward slashes for client
  return path.relative(rootDir, absPath).split(path.sep).join("/");
}
function safeResolve(relPath = "") {
  const abs = path.resolve(rootDir, relPath);
  const rel = path.relative(rootDir, abs);
  if (rel.startsWith("..") || path.isAbsolute(rel)) {
    throw new Error("Path outside root");
  }
  return abs;
}
async function listChildren(relPath = "") {
  const abs = safeResolve(relPath);
  const entries = await fs.readdir(abs, { withFileTypes: true });
  const results = [];
  for (const d of entries) {
    try {
      const absChild = path.resolve(abs, d.name);
      const relChild = toRel(absChild);
      if (d.isDirectory()) {
        results.push({ name: d.name, kind: "dir", relPath: relChild });
      } else if (d.isFile()) {
        const st = await fs.stat(absChild);
        results.push({
          name: d.name,
          kind: "file",
          relPath: relChild,
          size: st.size,
          ext: path.extname(d.name).slice(1).toLowerCase()
        });
      }
    } catch {
      // ignore unreadable entries
    }
  }
  // directories first, then files; alphabetically
  results.sort((a, b) => {
    if (a.kind !== b.kind) return a.kind === "dir" ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
  return results;
}

async function readFileCapped(relPath) {
  const abs = safeResolve(relPath);
  const st = await fs.stat(abs);
  if (!st.isFile()) throw new Error("Not a file");

  const ext = path.extname(abs).slice(1).toLowerCase();
  if (!TEXT_EXTS.has(ext) && ext !== "") {
    return { relPath, included: false, reason: `Skipped non-text extension .${ext}` };
  }

  // Read up to MAX_FILE_BYTES
  const fh = await fs.open(abs, "r");
  try {
    const toRead = Math.min(st.size, MAX_FILE_BYTES);
    const buf = Buffer.alloc(toRead);
    await fh.read(buf, 0, toRead, 0);
    let content = buf.toString("utf8");
    const truncated = st.size > MAX_FILE_BYTES;
    return { relPath, included: true, truncated, size: st.size, content, ext };
  } finally {
    await fh.close();
  }
}

function composeContext(prompt, fileParts) {
  const header = `You are a helpful coding assistant. The user prompt is followed by project file snippets as context.\n` +
    `Assume missing files are not available.\n\n` +
    `---\nUSER PROMPT:\n${prompt}\n---\n\n` +
    `CONTEXT FILES:\n`;

  const filesText = fileParts.map(p => {
    if (!p.included) {
      return `### ${p.relPath}\n(Skipped: ${p.reason})\n`;
    }
    const fenceLang = p.ext && p.ext.length <= 20 ? p.ext : "";
    const truncNote = p.truncated ? `\n[TRUNCATED to ${MAX_FILE_BYTES} bytes]\n` : "";
    return `### ${p.relPath}\n\`\`\`${fenceLang}\n${p.content}\n\`\`\`\n${truncNote}`;
  }).join("\n");

  return header + filesText;
}

const app = express();
app.use(express.json({ limit: "2mb" }));
app.use(express.static(path.join(__dirname, "public")));

app.get("/api/tree", async (req, res) => {
  try {
    const relPath = String(req.query.relPath || "");
    const items = await listChildren(relPath);
    res.json({ root: toRel(safeResolve("")), relPath, items });
  } catch (err) {
    res.status(400).json({ error: String(err.message || err) });
  }
});

app.post("/api/chat", async (req, res) => {
  try {
    const { prompt, files } = req.body || {};
    if (typeof prompt !== "string" || !prompt.trim()) {
      return res.status(400).json({ error: "Missing 'prompt' (string)" });
    }
    if (!Array.isArray(files) || files.length === 0) {
      return res.status(400).json({ error: "Provide 'files' as non-empty array of relative paths" });
    }

    // Read and cap files
    let totalBytes = 0;
    const parts = [];
    for (const rel of files) {
      const p = await readFileCapped(String(rel)).catch(e => ({
        relPath: String(rel), included: false, reason: e.message
      }));
      parts.push(p);
      if (p.included) {
        totalBytes += Buffer.byteLength(p.content, "utf8");
        if (totalBytes > MAX_TOTAL_BYTES) {
          const idx = parts.length - 1;
          parts[idx] = { relPath: p.relPath, included: false, reason: `Total cap ${MAX_TOTAL_BYTES} bytes exceeded` };
          break;
        }
      }
    }

    const composed = composeContext(prompt, parts);

    // ---------- Gemini config ----------
    const apiKey = process.env.GOOGLE_API_KEY;
    const model = process.env.GEMINI_MODEL || "gemini-1.5-flash";
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey || "")}`;

    if (!apiKey) {
      // Dry-run: return what would be sent
      return res.json({
        mode: "dry-run",
        note: "No GOOGLE_API_KEY set; skipping Gemini call.",
        model,
        sentBytes: Buffer.byteLength(composed, "utf8"),
        preview: composed.slice(0, 2000) + (composed.length > 2000 ? "\n...[truncated preview]..." : "")
      });
    }

    // Gemini expects a 'contents' array with role + parts
    const body = {
      contents: [
        {
          role: "user",
          parts: [{ text: composed }]
        }
      ],
      generationConfig: {
        temperature: 0.2,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048
      }
      // You can also add safetySettings here if you wish.
    };

    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const err = await response.text().catch(() => "");
      return res.status(502).json({ error: "Gemini call failed", detail: err });
    }

    const data = await response.json();
    const answer =
      data?.candidates?.[0]?.content?.parts?.map(p => p.text).join("") ||
      data?.candidates?.[0]?.content?.parts?.[0]?.text ||
      "(no content)";

    res.json({ model, answer, raw: data });
  } catch (err) {
    res.status(500).json({ error: String(err.message || err) });
  }
});


// Fallback: let the SPA handle unknown routes (optional)
app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.listen(port, () => {
  console.log(`Root: ${rootDir}`);
  console.log(`Server: http://localhost:${port}`);
});
