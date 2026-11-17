"""Gera o ícone do Norte no Android a partir da arte aprovada (1254x1254).

Uso (fora do app; precisa de Pillow, numpy e opencv-python-headless):
    python tooling/gerar_icone_app.py <icone_norte.png>

A arte não fica no repositório. O script separa o símbolo (arco + seta) do
fundo e gera:
- ícone adaptável (Android 8+): fundo, símbolo e versão monocromática
  (ícones temáticos do Android 13+), em mipmap-*/ e mipmap-anydpi-v26/;
- ícone legado (ic_launcher.png) com cantos arredondados transparentes.
"""

import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
# Recorte interno da arte, sem os cantos pretos e sem a borda brilhante.
INSET = 90


def split_layers(art):
    """Devolve (fundo sem símbolo, símbolo RGBA) no tamanho da arte."""
    rgb = art.astype(np.float32)
    g = rgb[..., 1]
    mask = (g > 70).astype(np.uint8) * 255
    mask[:INSET, :] = 0
    mask[-INSET:, :] = 0
    mask[:, :INSET] = 0
    mask[:, -INSET:] = 0
    mask = cv2.dilate(mask, np.ones((31, 31), np.uint8))
    small = cv2.resize(art, (314, 314), interpolation=cv2.INTER_AREA)
    ms = cv2.resize(mask, (314, 314), interpolation=cv2.INTER_NEAREST)
    bg = cv2.inpaint(small, ms, 15, cv2.INPAINT_TELEA)
    bg = cv2.GaussianBlur(bg, (0, 0), 6)
    bg = cv2.resize(bg, art.shape[1::-1], interpolation=cv2.INTER_CUBIC)
    bgf = bg.astype(np.float32)
    # Alfa pelo quanto o verde sobe acima do fundo (o brilho vira alfa parcial).
    a = np.clip((g - bgf[..., 1]) / (235 - bgf[..., 1]), 0, 1)
    a[a < 0.02] = 0
    # Fora do recorte interno só há o contorno do quadrado da arte: descarta.
    a[:INSET, :] = 0
    a[-INSET:, :] = 0
    a[:, :INSET] = 0
    a[:, -INSET:] = 0
    # Só o que está em volta do símbolo (arco + seta) entra na camada.
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    a[np.hypot(xx - 624, yy - 569) > 480] = 0
    safe = np.maximum(a, 1e-3)[..., None]
    col = np.clip(bgf + (rgb - bgf) / safe, 0, 255)
    sym = np.dstack([col, a * 255]).astype(np.uint8)
    return bg, sym


def save(img, folder, name):
    path = os.path.join(RES, folder)
    os.makedirs(path, exist_ok=True)
    img.save(os.path.join(path, name), optimize=True)


def main(src):
    art = np.asarray(Image.open(src).convert('RGB'))
    n = art.shape[0]
    bg, sym = split_layers(art)
    inner = bg[INSET:n - INSET, INSET:n - INSET]
    bg_img = Image.fromarray(inner)
    sym_img = Image.fromarray(sym, 'RGBA')

    # Camadas adaptáveis: 108dp, com a arte inteira ocupando os 72dp visíveis.
    for d, f in DENSITIES.items():
        layer = round(108 * f)
        visible = round(72 * f)
        off = (layer - visible) // 2
        save(bg_img.resize((layer, layer), Image.LANCZOS), f'mipmap-{d}',
             'ic_launcher_background.png')
        fg = Image.new('RGBA', (layer, layer), (0, 0, 0, 0))
        fg.alpha_composite(sym_img.resize((visible, visible), Image.LANCZOS),
                           (off, off))
        save(fg, f'mipmap-{d}', 'ic_launcher_foreground.png')
        mono = Image.new('RGBA', (layer, layer), (255, 255, 255, 0))
        mono.putalpha(fg.getchannel('A'))
        save(mono, f'mipmap-{d}', 'ic_launcher_monochrome.png')

        # Legado: arte inteira com cantos arredondados transparentes.
        size = round(48 * f)
        big = size * 4
        tile = bg_img.resize((big, big), Image.LANCZOS).convert('RGBA')
        tile.alpha_composite(sym_img.resize((big, big), Image.LANCZOS))
        rmask = Image.new('L', (big, big), 0)
        ImageDraw.Draw(rmask).rounded_rectangle((0, 0, big - 1, big - 1),
                                                radius=big * 0.22, fill=255)
        tile.putalpha(rmask)
        save(tile.resize((size, size), Image.LANCZOS), f'mipmap-{d}',
             'ic_launcher.png')

    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android='
           '"http://schemas.android.com/apk/res/android">\n'
           '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
           '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
           '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
           '</adaptive-icon>\n')
    path = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(path, exist_ok=True)
    with open(os.path.join(path, 'ic_launcher.xml'), 'w', encoding='utf-8') as fh:
        fh.write(xml)
    print('ícones gerados em', RES)


if __name__ == '__main__':
    main(sys.argv[1])
