"""Impacchettatore di atlas (shelf packing) con JSON delle regioni.

Ogni voce: nome -> immagine PIL + metadati (ancora, frame, ecc.). Le pagine sono <= `page` px per lato,
con 2 px di padding (bordo estruso per evitare sanguinamenti col filtro bilineare).
"""
import json
import os

from PIL import Image


class Packer:
    def __init__(self, page=2048, pad=2):
        self.page, self.pad = page, pad
        self.items = []

    def add(self, name, img, **meta):
        self.items.append((name, img, meta))

    def save(self, outdir, basename):
        os.makedirs(outdir, exist_ok=True)
        items = sorted(self.items, key=lambda it: (-it[1].height, -it[1].width))
        pages = []   # [(img, shelf state)]
        regions = {}

        def new_page():
            return dict(img=Image.new("RGBA", (self.page, self.page), (0, 0, 0, 0)), x=0, y=0, rowh=0)
        cur = new_page()
        pages.append(cur)
        for name, im, meta in items:
            w, h = im.size
            pw, ph = w + self.pad * 2, h + self.pad * 2
            if pw > self.page or ph > self.page:
                raise ValueError(f"{name} troppo grande: {w}x{h}")
            if cur["x"] + pw > self.page:
                cur["x"], cur["y"], cur["rowh"] = 0, cur["y"] + cur["rowh"], 0
            if cur["y"] + ph > self.page:
                cur = new_page()
                pages.append(cur)
            x, y = cur["x"] + self.pad, cur["y"] + self.pad
            cur["img"].alpha_composite(im, (x, y))
            # bordo estruso di 1 px
            if self.pad:
                cur["img"].paste(im.crop((0, 0, w, 1)).resize((w, 1)), (x, y - 1))
                cur["img"].paste(im.crop((0, h - 1, w, h)), (x, y + h))
            r = dict(page=len(pages) - 1, x=x, y=y, w=w, h=h)
            r.update(meta)
            regions[name] = r
            cur["x"] += pw
            cur["rowh"] = max(cur["rowh"], ph)
        files = []
        for i, p in enumerate(pages):
            img = p["img"]
            bb = img.getbbox()
            # taglia l'altezza inutilizzata (potenza di 2 non necessaria in Compatibility)
            H = min(self.page, (bb[3] + 7) // 8 * 8) if bb else 8
            Wd = min(self.page, (bb[2] + 7) // 8 * 8) if bb else 8
            img = img.crop((0, 0, Wd, H))
            fn = f"{basename}_{i}.png"
            img.save(os.path.join(outdir, fn), optimize=True)
            files.append(fn)
        with open(os.path.join(outdir, f"{basename}.json"), "w", encoding="utf-8") as f:
            json.dump(dict(pages=files, regions=regions), f, ensure_ascii=False, indent=1)
        return files, regions
