"""Gera a cena da tela de login (tema escuro e claro) a partir da referência.

Uso (fora do app; precisa de Pillow, numpy e opencv-python-headless):
    python tooling/gerar_cena_login.py <imagem_de_referencia.png>

A referência (1024x1536) não fica no repositório. O script:
- escuro: recorta a parte de cima (0..632 px), remove os textos da marca
  e suaviza o preenchimento;
- claro: recria a mesma composição em versão clara (céu menta, aurora
  translúcida, montanha em verdes profundos com a textura da original,
  arco/marcas/N em verde do tema claro), sem inverter cores.
Saída: assets/login/login_scene_dark.webp e login_scene_light.webp.
"""

import math
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'login')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'inter', 'Inter-Bold.ttf')
H, W = 632, 1024

# Caixas dos textos da marca na referência (x0, y0, x1, y1).
TEXT_BOXES = [(430, 30, 595, 150), (370, 140, 660, 235),
              (295, 245, 745, 365), (315, 365, 710, 408)]

# Crista das montanhas traçada sobre a referência (x, y).
RIDGE = [(0, 617), (50, 610), (80, 600), (105, 592), (120, 594), (150, 602),
         (165, 604), (180, 602), (200, 603), (225, 590), (245, 580),
         (262, 590), (280, 596), (300, 600), (320, 605), (348, 610),
         (380, 590), (400, 579), (420, 569), (450, 554), (480, 538),
         (512, 520), (516, 522), (530, 531), (550, 541), (575, 558),
         (602, 561), (625, 578), (650, 593), (685, 606), (720, 611),
         (740, 609), (760, 606), (775, 598), (790, 592), (805, 596),
         (830, 606), (850, 616), (880, 614), (910, 616), (950, 621),
         (1000, 626), (1023, 628)]


def rgb(hex_):
    return np.array([(hex_ >> 16) & 255, (hex_ >> 8) & 255, hex_ & 255],
                    np.float32) / 255


def lerp(a, b, t):
    return a + (b - a) * t


def dark_scene(ref):
    im = ref[:640]
    mask = np.zeros(im.shape[:2], np.uint8)
    for x0, y0, x1, y1 in TEXT_BOXES:
        mask[y0:y1, x0:x1] = 255
    mask = cv2.dilate(mask, np.ones((15, 15), np.uint8))
    small = cv2.resize(im, (256, 160), interpolation=cv2.INTER_AREA)
    ms = cv2.resize(mask, (256, 160), interpolation=cv2.INTER_NEAREST)
    fill = cv2.inpaint(small, ms, 12, cv2.INPAINT_NS)
    fill = cv2.GaussianBlur(fill, (0, 0), 6)
    fill = cv2.resize(fill, (1024, 640), interpolation=cv2.INTER_CUBIC)
    m = cv2.GaussianBlur(mask.astype(np.float32) / 255, (0, 0), 10)
    m = np.clip(m * 1.6, 0, 1)[..., None]
    noise = np.random.default_rng(1).normal(0, 1.2, fill.shape[:2])[..., None]
    out = im.astype(np.float32) * (1 - m) + (fill.astype(np.float32) + noise) * m
    return np.clip(out, 0, 255).astype(np.uint8)[:H]


def light_scene(dark):
    c = dark[..., ::-1].astype(np.float32) / 255
    G, L = c[..., 1], c.mean(2)
    yy = np.arange(H)[:, None]
    ridge = np.interp(np.arange(W), [p[0] for p in RIDGE],
                      [p[1] for p in RIDGE]).astype(np.float32)
    # Chão contínuo na base (colinas suaves), para a montanha preencher o
    # fundo da imagem inteira, inclusive nas laterais.
    xs = np.arange(W, dtype=np.float32)
    ground = 604 + 4 * np.sin(xs / 55) + 3 * np.sin(xs / 23 + 1.3)
    ridge = np.minimum(ridge, ground).astype(np.float32)
    mtn = cv2.GaussianBlur((yy >= ridge[None, :]).astype(np.float32), (0, 0), 0.9)

    # Arco, marcas e N com a geometria da referência (supersample 4x).
    ss, cx, cy, r = 4, 513, 669, 222
    font = ImageFont.truetype(FONT, 34 * ss)
    img = Image.new('L', (W * ss, H * ss), 0)
    dr = ImageDraw.Draw(img)
    dr.arc([(cx - r) * ss, (cy - r) * ss, (cx + r) * ss, (cy + r) * ss],
           198.9, 342.5, fill=255, width=int(4.2 * ss))
    for dv in (15.6, 31.0, 45.4, 58.4):
        for ang in (270 - dv, 270 + dv):
            a = math.radians(ang)
            dr.line([((cx + 188 * math.cos(a)) * ss, (cy + 188 * math.sin(a)) * ss),
                     ((cx + 208 * math.cos(a)) * ss, (cy + 208 * math.sin(a)) * ss)],
                    fill=255, width=int(3.6 * ss))
    dr.line([(513 * ss, 458 * ss), (513 * ss, 481 * ss)], fill=255, width=5 * ss)
    line = np.asarray(img.resize((W, H), Image.LANCZOS), np.float32) / 255
    line *= (yy < ridge[None, :] + 2)
    xx = np.arange(W)[None, :]
    line = np.where((xx >= 486) & (xx < 541) & (yy >= 425) & (yy < 458), 0, line)
    n_img = Image.new('L', (W * ss, H * ss), 0)
    ImageDraw.Draw(n_img).text((513 * ss, 438 * ss), 'N', font=font, fill=255,
                               anchor='mm')
    line = np.maximum(line, np.asarray(n_img.resize((W, H), Image.LANCZOS),
                                       np.float32) / 255)
    reg = cv2.dilate((line > 0.02).astype(np.float32), np.ones((9, 9), np.uint8))

    # Céu claro com brilho no horizonte e aurora menta translúcida.
    t = (yy / H).astype(np.float32)
    sky = lerp(rgb(0xF4F6F5), rgb(0xDCF1E9),
               np.clip(t * 1.6, 0, 1)[..., None] * np.ones((1, W, 1), np.float32))
    hz = cv2.GaussianBlur(np.clip((G - 0.25) / 0.7, 0, 1), (0, 0), 10)
    sky = lerp(sky, rgb(0xD6F6C6), np.clip(hz * 0.85, 0, 1)[..., None])
    aur = np.clip(cv2.GaussianBlur(L, (0, 0), 3) * 1.9, 0, 1)
    sky = lerp(sky, rgb(0x5FD4B0), (aur * 0.55)[..., None])

    # Estrelas viram pontos discretos em verde do tema claro.
    sm = ((G - cv2.GaussianBlur(G, (0, 0), 4)) > 0.10).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(sm, 8)
    keep = np.zeros_like(sm)
    for i in range(1, n):
        if (st[i, cv2.CC_STAT_AREA] <= 14 and
                max(st[i, cv2.CC_STAT_WIDTH], st[i, cv2.CC_STAT_HEIGHT]) <= 5):
            keep[lab == i] = 1
    stars = cv2.GaussianBlur(keep.astype(np.float32), (0, 0), 0.6) * (1 - mtn) * (1 - reg)
    deep = rgb(0x0E7C62)
    sky = lerp(sky, deep, (stars * 0.9)[..., None])

    # Montanha: textura da original mapeada para verdes e neve clara.
    mt = np.clip(L / 0.75, 0, 1)
    c0, c1, c2 = rgb(0x1B5547), rgb(0x2F7F6A), rgb(0xECF9F4)
    col = lerp(lerp(c0, c1, np.clip(mt * 2, 0, 1)[..., None]), c2,
               np.clip((mt - 0.5) * 2, 0, 1)[..., None])
    base = np.clip((yy - 560) / 70.0, 0, 1).astype(np.float32)
    col = lerp(col, c0 * 0.9, (base * 0.5)[..., None] * np.ones((1, W, 1), np.float32))
    out = lerp(sky, col, mtn[..., None])
    out = lerp(out, deep, (line * 0.95)[..., None])
    return np.clip(out[..., ::-1] * 255, 0, 255).astype(np.uint8)


def save(bgr, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    Image.fromarray(bgr[..., ::-1]).save(path, 'WEBP', quality=94, method=6)
    print(path, os.path.getsize(path) // 1024, 'KB')


if __name__ == '__main__':
    ref = cv2.imread(sys.argv[1])
    dark = dark_scene(ref)
    save(dark, 'login_scene_dark.webp')
    save(light_scene(dark), 'login_scene_light.webp')
