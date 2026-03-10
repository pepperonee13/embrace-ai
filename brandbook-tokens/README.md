# brandbook-tokens

Extracts design tokens from `kata-3-slide-generator/brandbook.pdf` by visually
rendering the PDF and using Claude claude-opus-4-6 vision to identify colours.

## Why visual extraction?

The printed hex labels in the brandbook PDF contain copy-paste errors — the secondary
colour scale entries are wrong (they repeat primary values instead of the actual tints).
This script bypasses those labels entirely: it renders each page as a 150 DPI image and
asks Claude what each swatch **looks like**, producing colour values based on visual
perception rather than unreliable text.

## Outputs

| File | Description |
|------|-------------|
| `output/design-tokens.yaml` | Canonical token set (matches `tgg-design-tokens.yaml` structure) |
| `output/design-tokens.css` | CSS custom properties (`--tgg-*`) ready to import |
| `output/page_NN_analysis.json` | Per-page Claude findings (useful for debugging) |
| `output/synthesis_raw.json` | Raw synthesis JSON before YAML/CSS serialisation |

## Prerequisites

- Python 3.11+
- `ANTHROPIC_API_KEY` set in your environment

## Setup

```bash
cd brandbook-tokens
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
```

## Usage

```bash
python extract_tokens.py
```

The script is idempotent: if `output/page_NN_analysis.json` already exists from a
previous run it is reused, so you only pay for API calls once per page.

## Pipeline

```
brandbook.pdf
    │
    ▼  PyMuPDF (no ghostscript)
page_01.png … page_04.png   (150 DPI)
    │
    ▼  claude-opus-4-6 vision (1 call per page)
page_NN_analysis.json        (primary colours, secondary scales, gradients)
    │
    ▼  claude-opus-4-6 text (1 synthesis call)
synthesis_raw.json           (unified canonical token dict)
    │
    ├─▶ design-tokens.yaml
    └─▶ design-tokens.css
```

## API Cost Estimate

4 analysis calls + 1 synthesis call ≈ **5 API calls total**.
Estimated cost: < $0.10 at current claude-opus-4-6 pricing.

## Using the CSS Tokens

```html
<link rel="stylesheet" href="design-tokens.css">
```

```css
.hero {
  background: var(--tgg-bg-dark);
  color: var(--tgg-text-primary);
  border-left: 4px solid var(--tgg-accent-primary);
}

.progress-bar {
  background: var(--tgg-gradient-brand);
}
```
