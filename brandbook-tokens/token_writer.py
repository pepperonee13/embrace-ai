"""
token_writer.py
===============
Serialises the unified token dict produced by extract_tokens.py into:
  - design-tokens.yaml  (human-readable, matches tgg-design-tokens.yaml structure)
  - design-tokens.css   (CSS custom properties, mirrors brand.tokens.css naming)
"""

from __future__ import annotations

from datetime import date
from pathlib import Path
from typing import Any

import yaml


# ---------------------------------------------------------------------------
# YAML output
# ---------------------------------------------------------------------------

YAML_HEADER = """\
##
## design-tokens.yaml
## Visually extracted from: kata-3-slide-generator/brandbook.pdf
## Tool: extract_tokens.py using claude-opus-4-6 vision at 150 DPI
## Date: {today}
## Method: PyMuPDF render → Claude visual colour sampling
##         Hex values reflect what colours LOOK LIKE in the rendered PDF,
##         NOT the (potentially incorrect) printed labels.
##
"""


def write_yaml(tokens: dict, output_path: Path) -> None:
    header = YAML_HEADER.format(today=date.today().isoformat())
    body = yaml.dump(tokens, default_flow_style=False, allow_unicode=True, sort_keys=False)
    output_path.write_text(header + body, encoding="utf-8")
    print(f"  → YAML written: {output_path.name}")


# ---------------------------------------------------------------------------
# CSS output
# ---------------------------------------------------------------------------

CSS_HEADER = """\
/*
 * design-tokens.css
 * Visually extracted from: kata-3-slide-generator/brandbook.pdf
 * Tool: extract_tokens.py using claude-opus-4-6 vision at 150 DPI
 * Date: {today}
 * Method: PyMuPDF render → Claude visual colour sampling
 *         Hex values reflect what colours LOOK LIKE in the rendered PDF,
 *         NOT the (potentially incorrect) printed labels.
 *
 * Naming convention: --tgg-{{section}}-{{key}}
 * Import and use: var(--tgg-primary-blue), etc.
 */

"""


def _kebab(s: str) -> str:
    return str(s).lower().replace("_", "-").replace(" ", "-")


def write_css(tokens: dict, output_path: Path) -> None:
    lines: list[str] = [CSS_HEADER.format(today=date.today().isoformat()), ":root {"]

    palette = tokens.get("brand_palette", {})

    # --- Primary palette ---
    primary = palette.get("primary", {})
    if primary:
        lines.append("\n  /* --- Primary Palette --- */")
        for name, data in primary.items():
            if isinstance(data, dict):
                hex_val = data.get("hex", "")
                conf = data.get("source_confidence", "")
                comment = f"  /* confidence: {conf} */" if conf else ""
                lines.append(f"  --tgg-primary-{_kebab(name)}: {hex_val};{comment}")

    # --- Secondary scales ---
    secondary = palette.get("secondary", {})
    if secondary:
        lines.append("\n  /* --- Secondary Colour Scales --- */")
        for hue, steps in secondary.items():
            if isinstance(steps, dict):
                lines.append(f"\n  /* {hue} scale */")
                for step, data in steps.items():
                    if isinstance(data, dict):
                        hex_val = data.get("hex", "")
                        conf = data.get("source_confidence", "")
                        comment = f"  /* confidence: {conf} */" if conf else ""
                        lines.append(
                            f"  --tgg-secondary-{_kebab(hue)}-{_kebab(step)}: {hex_val};{comment}"
                        )

    # --- Gradient stops ---
    grad_stops = palette.get("gradient_stops", [])
    if grad_stops:
        lines.append("\n  /* --- Gradient Stops --- */")
        for stop in grad_stops:
            if isinstance(stop, dict):
                name = stop.get("name", "")
                hex_val = stop.get("hex", "")
                pos = stop.get("gradient_position", "")
                lines.append(f"  --tgg-gradient-stop-{_kebab(name)}: {hex_val};  /* {pos} */")

    # --- Brand gradient ---
    gradient = tokens.get("gradient", {})
    if gradient:
        lines.append("\n  /* --- Gradients --- */")
        for name, value in gradient.items():
            lines.append(f"  --tgg-gradient-{_kebab(name)}: {value};")

    # --- Applied tokens: background ---
    applied = tokens.get("applied_tokens", {}).get("color", {})
    bg = applied.get("bg", {})
    if bg:
        lines.append("\n  /* --- Background Tokens --- */")
        for key, val in bg.items():
            lines.append(f"  --tgg-bg-{_kebab(key)}: {val};")

    # --- Applied tokens: accent ---
    accent = applied.get("accent", {})
    if accent:
        lines.append("\n  /* --- Accent Tokens --- */")
        for key, val in accent.items():
            lines.append(f"  --tgg-accent-{_kebab(key)}: {val};")

    # --- Applied tokens: text ---
    text = applied.get("text", {})
    if text:
        lines.append("\n  /* --- Text Tokens --- */")
        for key, val in text.items():
            lines.append(f"  --tgg-text-{_kebab(key)}: {val};")

    # --- Typography ---
    typography = tokens.get("typography", {})
    if typography:
        lines.append("\n  /* --- Typography --- */")
        font_primary = typography.get("font_primary", "")
        if font_primary:
            lines.append(f"  --tgg-font-primary: {font_primary};")
        scale = typography.get("scale", {})
        for role, props in scale.items():
            if isinstance(props, dict):
                size = props.get("size", "")
                weight = props.get("weight", "")
                if size:
                    lines.append(f"  --tgg-type-{_kebab(role)}-size: {size};")
                if weight:
                    lines.append(f"  --tgg-type-{_kebab(role)}-weight: {weight};")

    lines.append("\n}")
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"  → CSS written:  {output_path.name}")
