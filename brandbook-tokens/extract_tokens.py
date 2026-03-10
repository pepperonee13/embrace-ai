"""
extract_tokens.py
=================
Extracts design tokens from a brandbook PDF by:
  1. Rendering each page to PNG at 150 DPI (PyMuPDF, no ghostscript)
  2. Sending each rendered image to Claude claude-opus-4-6 vision for visual color analysis
     — explicitly instructed to estimate hex from what colors LOOK LIKE, not from printed labels
  3. Synthesising all per-page findings into a unified token set via a second Claude call
  4. Writing design-tokens.yaml and design-tokens.css

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    pip install -r requirements.txt
    python extract_tokens.py
"""

from __future__ import annotations

import base64
import json
import sys
import time
from datetime import date
from pathlib import Path

import anthropic
import fitz  # PyMuPDF

from token_writer import write_css, write_yaml

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PDF_PATH = Path(__file__).parent.parent / "kata-3-slide-generator" / "brandbook.pdf"
OUTPUT_DIR = Path(__file__).parent / "output"
DPI = 150
MODEL = "claude-opus-4-6"
MAX_RETRIES = 3

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

PAGE_ANALYSIS_SYSTEM = """\
You are a design token extraction specialist analysing pages from a corporate brand guide PDF.

CRITICAL INSTRUCTION: The hex colour labels printed in this PDF are KNOWN TO BE INCORRECT
(copy-paste errors). Do NOT simply read and report the hex text printed on the page.
Instead, look at each coloured rectangle or swatch visually and estimate its hex value
from how the colour APPEARS in the rendered image. Trust your visual perception over any
text label you can see.

Respond ONLY with valid JSON — no markdown fences, no commentary outside the JSON object.
"""

PAGE_ANALYSIS_USER_TMPL = """\
Analyse this brand guide page (page {page_num} of {total_pages}).

Examine ALL visible colour swatches, gradients, text samples, and design elements.

For each coloured swatch or rectangle: estimate the hex value from its VISUAL APPEARANCE.
Include the printed label text only as a reference ("printed_label") but base your
"visual_hex" value on what the colour actually looks like rendered on screen.

Return a JSON object with these keys (omit any key absent on this page):

{{
  "page": {page_num},
  "primary_colors": [
    {{
      "name": "<descriptive name, e.g. 'blue', 'petrol', 'orange', 'gunmetal'>",
      "visual_hex": "<your hex estimate from visual appearance, e.g. '#205ea7'>",
      "printed_label": "<the hex text printed in the PDF, if visible, else null>",
      "cmyk_printed": "<CMYK values printed, if visible, else null>",
      "confidence": "high|medium|low"
    }}
  ],
  "secondary_color_scales": [
    {{
      "base_hue": "<hue family name, e.g. 'blue', 'petrol', 'pistachio', 'orange'>",
      "tints": [
        {{ "step": 2, "visual_hex": "<hex>", "printed_label": "<text or null>", "confidence": "high|medium|low" }},
        {{ "step": 3, "visual_hex": "<hex>", "printed_label": "<text or null>", "confidence": "high|medium|low" }},
        {{ "step": 4, "visual_hex": "<hex>", "printed_label": "<text or null>", "confidence": "high|medium|low" }},
        {{ "step": 5, "visual_hex": "<hex>", "printed_label": "<text or null>", "confidence": "high|medium|low" }}
      ]
    }}
  ],
  "gradients": [
    {{
      "name": "<gradient name or description>",
      "type": "linear|radial",
      "stops": [
        {{ "position": "0%", "visual_hex": "<hex>" }},
        {{ "position": "100%", "visual_hex": "<hex>" }}
      ]
    }}
  ],
  "typography": {{
    "fonts_identified": ["<font name>"],
    "type_samples": [
      {{ "role": "heading|body|label|caption", "weight": "<weight if visible>" }}
    ]
  }},
  "notes": "<any important observations about this page>"
}}

For large flat-colour swatches you can be high confidence. For gradients or small chips, use
medium or low. Always prefer visual evidence over text labels.
"""

SYNTHESIS_SYSTEM = """\
You are a design token compiler. You receive structured JSON analyses of individual pages
from a corporate brand guide. Merge and deduplicate these findings into a single canonical
design token set.

Rules:
- Where the same colour appears on multiple pages with slightly different visual_hex values,
  average them or prefer the reading with the highest confidence.
- Flag any colour whose visual_hex differs significantly from its printed_label.
- Convert hex values to RGB [R, G, B] integers yourself.
- Respond ONLY with valid JSON — no markdown fences, no text outside the JSON object.
"""

SYNTHESIS_USER_TMPL = """\
Here are per-page analyses from a {total_pages}-page TIMETOACT GROUP brand guide:

{analyses_json}

Produce a unified canonical design token JSON with this exact structure
(fill in actual hex values from the analyses above):

{{
  "brand": "TIMETOACT GROUP",
  "extraction_date": "{today}",
  "extraction_method": "visual-sampling-claude-opus-4-6",
  "brand_palette": {{
    "primary": {{
      "blue":         {{ "hex": "#????", "rgb": [0,0,0], "source_confidence": "high" }},
      "dark-blue":    {{ "hex": "#????", "rgb": [0,0,0], "source_confidence": "high" }},
      "petrol":       {{ "hex": "#????", "rgb": [0,0,0], "source_confidence": "high" }},
      "dark-petrol":  {{ "hex": "#????", "rgb": [0,0,0], "source_confidence": "high" }},
      "orange":       {{ "hex": "#????", "rgb": [0,0,0], "source_confidence": "high" }},
      "dark-orange":  {{ "hex": "#????", "rgb": [0,0,0], "source_confidence": "high" }},
      "gunmetal":     {{ "hex": "#????", "rgb": [0,0,0], "source_confidence": "high" }},
      "dark-gunmetal":{{ "hex": "#????", "rgb": [0,0,0], "source_confidence": "high" }}
    }},
    "secondary": {{
      "blue": {{
        "2": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "3": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "4": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "5": {{ "hex": "#????", "source_confidence": "high|medium|low" }}
      }},
      "petrol": {{
        "2": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "3": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "4": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "5": {{ "hex": "#????", "source_confidence": "high|medium|low" }}
      }},
      "pistachio": {{
        "base": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "2":    {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "3":    {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "4":    {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "5":    {{ "hex": "#????", "source_confidence": "high|medium|low" }}
      }},
      "orange": {{
        "2": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "3": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "4": {{ "hex": "#????", "source_confidence": "high|medium|low" }},
        "5": {{ "hex": "#????", "source_confidence": "high|medium|low" }}
      }}
    }},
    "gradient_stops": [
      {{ "name": "blue",      "hex": "#????", "gradient_position": "0%"   }},
      {{ "name": "petrol",    "hex": "#????", "gradient_position": "33%"  }},
      {{ "name": "pistachio", "hex": "#????", "gradient_position": "66%"  }},
      {{ "name": "orange",    "hex": "#????", "gradient_position": "100%" }}
    ]
  }},
  "typography": {{
    "font_primary": "'Inter', 'Helvetica Neue', Arial, sans-serif",
    "scale": {{
      "display-title": {{ "size": "3.125rem", "weight": 800 }},
      "slide-title":   {{ "size": "2.25rem",  "weight": 700 }},
      "body":          {{ "size": "1rem",     "weight": 400 }},
      "small":         {{ "size": "0.9375rem" }},
      "label":         {{ "size": "0.75rem",  "weight": 600, "transform": "uppercase" }},
      "overline":      {{ "size": "0.6875rem","weight": 600, "transform": "uppercase" }}
    }}
  }},
  "applied_tokens": {{
    "color": {{
      "bg": {{
        "dark":    "#????",
        "surface": "#????",
        "card":    "#????"
      }},
      "accent": {{
        "primary":    "#????",
        "dark-blue":  "#????",
        "secondary":  "#????",
        "dark-petrol":"#????",
        "warm":       "#????",
        "dark-warm":  "#????"
      }},
      "text": {{
        "primary":   "#ffffff",
        "secondary": "rgba(255,255,255,0.78)",
        "muted":     "rgba(255,255,255,0.45)"
      }}
    }}
  }},
  "gradient": {{
    "brand": "linear-gradient(to right, <blue-hex> 0%, <petrol-hex> 33%, <pistachio-hex> 66%, <orange-hex> 100%)"
  }},
  "notes": "<caveats about confidence or ambiguous readings>"
}}

Substitute all placeholder '#????' values with actual hex values from the analyses.
For 'rgb' fields convert the hex to [R, G, B] integers.
For the gradient 'brand' value substitute the actual hex values from gradient_stops.
"""


# ---------------------------------------------------------------------------
# Phase 0: Environment validation
# ---------------------------------------------------------------------------

def validate_environment(pdf_path: Path, output_dir: Path) -> None:
    if not (api_key := __import__("os").environ.get("ANTHROPIC_API_KEY")):
        sys.exit(
            "ERROR: ANTHROPIC_API_KEY environment variable is not set.\n"
            "  export ANTHROPIC_API_KEY=sk-ant-..."
        )
    if not pdf_path.exists():
        sys.exit(f"ERROR: PDF not found at {pdf_path}")
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"✓ Environment OK (key: {api_key[:12]}…)")
    print(f"✓ PDF: {pdf_path} ({pdf_path.stat().st_size // 1024} KB)")
    print(f"✓ Output dir: {output_dir}")


# ---------------------------------------------------------------------------
# Phase 1: PDF rendering
# ---------------------------------------------------------------------------

def render_pdf_pages(pdf_path: Path, output_dir: Path, dpi: int = 150) -> list[Path]:
    doc = fitz.open(str(pdf_path))
    rendered: list[Path] = []
    print(f"\nRendering {len(doc)} page(s) at {dpi} DPI …")
    for i in range(len(doc)):
        page = doc[i]
        mat = fitz.Matrix(dpi / 72, dpi / 72)
        pix = page.get_pixmap(matrix=mat, alpha=False)
        out_path = output_dir / f"page_{i + 1:02d}.png"
        pix.save(str(out_path))
        size_kb = out_path.stat().st_size // 1024
        print(f"  page {i + 1}: {pix.width}×{pix.height}px → {size_kb} KB  ({out_path.name})")
        rendered.append(out_path)
    doc.close()
    return rendered


# ---------------------------------------------------------------------------
# Phase 2: Per-page visual analysis
# ---------------------------------------------------------------------------

def _call_with_retry(client: anthropic.Anthropic, **kwargs) -> anthropic.types.Message:
    for attempt in range(MAX_RETRIES + 1):
        try:
            return client.messages.create(**kwargs)
        except anthropic.RateLimitError as exc:
            if attempt == MAX_RETRIES:
                raise
            wait = 2 ** attempt
            print(f"    Rate limit hit — retrying in {wait}s …")
            time.sleep(wait)
        except anthropic.APIError as exc:
            raise


def analyze_page(
    client: anthropic.Anthropic,
    img_path: Path,
    page_num: int,
    total_pages: int,
) -> dict:
    image_data = base64.standard_b64encode(img_path.read_bytes()).decode("utf-8")
    user_prompt = PAGE_ANALYSIS_USER_TMPL.format(
        page_num=page_num,
        total_pages=total_pages,
    )

    try:
        response = _call_with_retry(
            client,
            model=MODEL,
            max_tokens=2048,
            system=PAGE_ANALYSIS_SYSTEM,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/png",
                                "data": image_data,
                            },
                        },
                        {"type": "text", "text": user_prompt},
                    ],
                }
            ],
        )
        raw_text = response.content[0].text
    except anthropic.APIError as exc:
        print(f"    API error on page {page_num}: {exc}")
        return {"page": page_num, "api_error": str(exc)}

    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        # Strip common markdown fences Claude sometimes adds
        stripped = raw_text.strip()
        if stripped.startswith("```"):
            stripped = stripped.split("\n", 1)[1].rsplit("```", 1)[0].strip()
        try:
            return json.loads(stripped)
        except json.JSONDecodeError:
            fallback = img_path.parent / f"page_{page_num:02d}_raw.txt"
            fallback.write_text(raw_text)
            print(f"    JSON parse failed — raw response saved to {fallback.name}")
            return {"page": page_num, "parse_error": True}


# ---------------------------------------------------------------------------
# Phase 3: Synthesis
# ---------------------------------------------------------------------------

def synthesize_tokens(client: anthropic.Anthropic, page_analyses: list[dict]) -> dict:
    analyses_json = json.dumps(page_analyses, indent=2)
    user_prompt = SYNTHESIS_USER_TMPL.format(
        total_pages=len(page_analyses),
        analyses_json=analyses_json,
        today=date.today().isoformat(),
    )

    try:
        response = _call_with_retry(
            client,
            model=MODEL,
            max_tokens=4096,
            system=SYNTHESIS_SYSTEM,
            messages=[{"role": "user", "content": user_prompt}],
        )
        raw_text = response.content[0].text
    except anthropic.APIError as exc:
        sys.exit(f"ERROR during synthesis call: {exc}")

    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        stripped = raw_text.strip()
        if stripped.startswith("```"):
            stripped = stripped.split("\n", 1)[1].rsplit("```", 1)[0].strip()
        try:
            return json.loads(stripped)
        except json.JSONDecodeError:
            fallback = OUTPUT_DIR / "synthesis_raw.txt"
            fallback.write_text(raw_text)
            sys.exit(
                f"ERROR: Could not parse synthesis JSON response.\n"
                f"Raw text saved to {fallback}"
            )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    validate_environment(PDF_PATH, OUTPUT_DIR)
    client = anthropic.Anthropic()

    # Phase 1 — render
    page_images = render_pdf_pages(PDF_PATH, OUTPUT_DIR, dpi=DPI)

    # Phase 2 — per-page analysis
    page_analyses: list[dict] = []
    print()
    for i, img_path in enumerate(page_images, start=1):
        cache_path = OUTPUT_DIR / f"page_{i:02d}_analysis.json"
        if cache_path.exists():
            print(f"[page {i}/{len(page_images)}] Using cached analysis ({cache_path.name})")
            page_analyses.append(json.loads(cache_path.read_text()))
            continue

        print(f"[page {i}/{len(page_images)}] Analysing with Claude vision …")
        analysis = analyze_page(client, img_path, page_num=i, total_pages=len(page_images))
        cache_path.write_text(json.dumps(analysis, indent=2))
        n_primary = len(analysis.get("primary_colors") or [])
        n_scales = len(analysis.get("secondary_color_scales") or [])
        print(f"  → {n_primary} primary colour(s), {n_scales} secondary scale(s) found")
        page_analyses.append(analysis)

    # Phase 3 — synthesis
    print("\nSynthesising tokens across all pages …")
    unified = synthesize_tokens(client, page_analyses)
    (OUTPUT_DIR / "synthesis_raw.json").write_text(json.dumps(unified, indent=2))
    print("  → synthesis_raw.json saved")

    # Phase 4 — write outputs
    yaml_path = OUTPUT_DIR / "design-tokens.yaml"
    css_path = OUTPUT_DIR / "design-tokens.css"
    write_yaml(unified, yaml_path)
    write_css(unified, css_path)
    print(f"\n✓ {yaml_path}")
    print(f"✓ {css_path}")
    print("\nDone.")


if __name__ == "__main__":
    main()
