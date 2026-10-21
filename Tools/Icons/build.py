"""Builds the grocery icons as custom SF Symbols.

Downloads the free icon sets named in icons.json (and reads our own
drawings, "custom:name", from custom/name.svg on a 24-point grid), evens out
their stroke weights, converts each icon to an SF Symbol template with SwiftDraw
(`brew install swiftdraw`) and writes them to the asset catalogue, along with
the sets' licences.

    python3 Tools/Icons/build.py
"""
import io, json, re, shutil, subprocess, sys, tarfile, tempfile, urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
ASSETS = ROOT / "BudgetAndBuy/Assets.xcassets/Grocery Icons"
LICENCES = ROOT / "BudgetAndBuy/Resources/Icon Licences.txt"

# Every set is drawn on a square grid; this scales its strokes to Hugeicons'
# 1.5 points on 24, so icons from different sets look the same weight.
STROKE_SCALE = {"lucide": .75, "tabler": .75, "tdesign": .75, "mingcute": .75, "icon-park-outline": .75}
TITLES = {"hugeicons": "Hugeicons", "tabler": "Tabler Icons", "lucide": "Lucide", "icon-park-outline": "IconPark",
          "tdesign": "TDesign Icons", "mingcute": "MingCute", "carbon": "Carbon", "healthicons": "Health Icons",
          "fluent": "Fluent UI System Icons", "iconoir": "Iconoir"}


def load_set(name, version):
    url = f"https://registry.npmjs.org/@iconify-json/{name}/-/{name}-{version}.tgz"
    with urllib.request.urlopen(url) as response:
        archive = tarfile.open(fileobj=io.BytesIO(response.read()))
    return json.load(archive.extractfile("package/icons.json"))


def svg(icon_set, set_name, icon_name):
    if set_name == "custom":
        return 24, (HERE / "custom" / f"{icon_name}.svg").read_text()
    icon = icon_set["icons"][icon_name]
    width = icon.get("width", icon_set.get("width", 16))
    height = icon.get("height", icon_set.get("height", 16))
    body = icon["body"]
    scale = STROKE_SCALE.get(set_name)
    if scale:
        body = re.sub(r'stroke-width="([\d.]+)"', lambda m: f'stroke-width="{float(m.group(1)) * scale:g}"', body)
    return width, f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">{body}</svg>'


def main():
    if not shutil.which("swiftdraw"):
        sys.exit("SwiftDraw isn't installed. Run: brew install swiftdraw")
    config = json.load(open(HERE / "icons.json"))
    sets = {name: load_set(name, version) for name, version in config["iconifyPackages"].items()}
    sets["custom"] = None

    shutil.rmtree(ASSETS, ignore_errors=True)
    ASSETS.mkdir(parents=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    with tempfile.TemporaryDirectory() as temp:
        for icon_id, source in config["icons"].items():
            set_name, icon_name = source.split(":")
            grid, text = svg(sets[set_name], set_name, icon_name)
            source_file = Path(temp) / f"{icon_id}.svg"
            source_file.write_text(text)
            # Crop each grid's usual padding, a twelfth of its size, so the
            # drawing spans cap height to baseline like a system symbol.
            inset = f"{grid / 12:g}"
            name = f"grocery.{icon_id}"
            symbolset = ASSETS / f"{name}.symbolset"
            symbolset.mkdir()
            subprocess.run(
                ["swiftdraw", str(source_file), "--format", "sfsymbol", "--insets", ",".join([inset] * 4),
                 "--output", str(symbolset / f"{name}.svg")],
                check=True, capture_output=True)
            (symbolset / "Contents.json").write_text(json.dumps({
                "info": {"author": "xcode", "version": 1},
                "symbols": [{"filename": f"{name}.svg", "idiom": "universal"}],
            }, indent=2) + "\n")

    used = sorted({source.split(":")[0] for source in config["icons"].values()} - {"custom"}, key=lambda s: s != "hugeicons")
    LICENCES.parent.mkdir(parents=True, exist_ok=True)
    sections = [f"{TITLES[s]}\n\n{(HERE / 'licenses' / f'{s}.txt').read_text().strip()}" for s in used]
    LICENCES.write_text("Product icons are adapted from these free icon sets.\n\n" + "\n\n\n".join(sections) + "\n")
    print(f"Built {len(config['icons'])} icons from {len(used)} sets.")


if __name__ == "__main__":
    main()
