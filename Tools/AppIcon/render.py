#!/usr/bin/env python3
"""Renders every theme's app icon, in its light, dark and tinted appearances, from the SVGs here.

    python3 Tools/AppIcon/render.py

Needs Inkscape on the PATH. The dark icon drops the background and shadow so iOS can put the bag on
its own dark backdrop. The tinted icon, which iOS also uses for clear icons, is the bag in greys on
black: iOS tints by brightness, so black drops away and the cream paper takes the most tint.
"""

import json
import re
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parent.parent / "BudgetAndBuy" / "Assets.xcassets"
THEMES = {"sage": "AppIcon", "coral": "AppIcon-Coral", "slate": "AppIcon-Slate",
          "amber": "AppIcon-Amber", "lavender": "AppIcon-Lavender"}

BACKGROUND = re.compile(r"<rect\b[^>]*\bid=\"rect18\"[^>]*/>", re.S)
SHADOW = re.compile(r"<ellipse\b[^>]*\bid=\"ellipse18\"[^>]*/>", re.S)
COLOUR = re.compile(r"stop-color=\"#([0-9A-Fa-f]{6})\"")


def grey(match):
    r, g, b = (int(match.group(1)[i:i + 2], 16) for i in (0, 2, 4))
    level = round(0.2126 * r + 0.7152 * g + 0.0722 * b)
    return f'stop-color="#{level:02X}{level:02X}{level:02X}"'


def without_backdrop(svg):
    svg = BACKGROUND.sub("", svg, count=1)
    return SHADOW.sub("", svg, count=1)


def tinted(svg):
    svg = COLOUR.sub(grey, without_backdrop(svg))
    return svg.replace("<!-- Square, edge-to-edge background",
                       '<rect width="1248" height="1248" fill="#000000"/>\n  <!-- Square, edge-to-edge background', 1)


def render(svg, png, opaque):
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as file:
        file.write(svg)
    args = ["inkscape", file.name, "--export-type=png", f"--export-filename={png}",
            "--export-width=1024", "--export-height=1024"]
    if not opaque:
        args.append("--export-background-opacity=0")
    subprocess.run(args, check=True, capture_output=True)
    Path(file.name).unlink()
    if opaque:
        # App Store icons must have no alpha channel.
        subprocess.run(["sips", "-s", "format", "jpeg", png, "--out", f"{png}.jpg"], check=True, capture_output=True)
        subprocess.run(["sips", "-s", "format", "png", f"{png}.jpg", "--out", png], check=True, capture_output=True)
        Path(f"{png}.jpg").unlink()


def main():
    for theme, name in THEMES.items():
        svg = (HERE / f"shopping-bag-{theme}.svg").read_text()
        folder = ASSETS / f"{name}.appiconset"
        render(svg, folder / f"{name}.png", opaque=True)
        render(without_backdrop(svg), folder / f"{name}-Dark.png", opaque=False)
        render(tinted(svg), folder / f"{name}-Tinted.png", opaque=True)

        image = {"idiom": "universal", "platform": "ios", "size": "1024x1024"}
        contents = {
            "images": [
                {**image, "filename": f"{name}.png"},
                {**image, "filename": f"{name}-Dark.png",
                 "appearances": [{"appearance": "luminosity", "value": "dark"}]},
                {**image, "filename": f"{name}-Tinted.png",
                 "appearances": [{"appearance": "luminosity", "value": "tinted"}]},
            ],
            "info": {"author": "xcode", "version": 1},
        }
        (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
        print(f"Rendered {name}")


if __name__ == "__main__":
    main()
