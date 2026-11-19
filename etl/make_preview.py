"""Draw the link-preview image (assets/preview.png) shown when the site is shared.

Social sites (LinkedIn, WhatsApp, Slack, X) show this 1200x630 card for links to
the website. It is drawn from the exported CSVs, so rerun this after etl/export.py
if the headline numbers change.

Usage:
    python etl/make_preview.py
"""

import csv
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "dashboard" / "data"
OUT = ROOT / "assets" / "preview.png"

W, H = 1200, 630
PAGE, INK, SECONDARY, MUTED, ACCENT = "#f9f9f7", "#0b0b0b", "#52514e", "#898781", "#2a78d6"
FONT_FILE = "/System/Library/Fonts/HelveticaNeue.ttc"   # macOS system font


def font(size, style="Regular"):
    """Pick a style (Regular / Medium / Bold) out of the Helvetica Neue collection."""
    for index in range(20):
        try:
            f = ImageFont.truetype(FONT_FILE, size, index=index)
        except OSError:
            break
        if f.getname()[1] == style:
            return f
    return ImageFont.truetype(FONT_FILE, size)


def main():
    meta = json.loads((DATA / "meta.json").read_text(encoding="utf-8"))
    with open(DATA / "01_death_strike_rate.csv", encoding="utf-8") as fh:
        leader = next(r for r in csv.DictReader(fh)
                      if r["period"] == "All time" and r["competition"] == "IPL")

    img = Image.new("RGB", (W, H), PAGE)
    d = ImageDraw.Draw(img)
    x = 80

    d.rectangle([0, 0, W, 10], fill=ACCENT)
    d.text((x, 70), "CRICKET ANALYTICS  ·  DUCKDB  ·  SQL", font=font(26, "Medium"), fill=MUTED)
    d.text((x, 112), "What wins T20 games?", font=font(76, "Bold"), fill=INK)

    d.text((x, 250), leader["strike_rate"], font=font(150, "Bold"), fill=INK)
    d.text((x, 420), f"{leader['batter']}'s strike rate in the IPL's death overs,",
           font=font(32), fill=SECONDARY)
    d.text((x, 462), "the best of anyone with 300+ balls", font=font(32), fill=SECONDARY)

    footer = (f"{meta['matches']:,} matches  ·  {meta['deliveries'] / 1e6:.2f}M balls  ·  "
              f"IPL + T20 internationals  ·  {meta['first_date'][:4]}–{meta['last_date'][:4]}")
    d.text((x, 545), footer, font=font(26, "Medium"), fill=MUTED)

    OUT.parent.mkdir(exist_ok=True)
    img.save(OUT, optimize=True)
    print(f"Saved {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
