#!/usr/bin/env python3
"""
parallax.py — генератор багатошарових паралакс-шпалер з одного фото.

Розрізає зображення на N прозорих шарів за картою глибини
(Depth Anything V2, ONNX) і готує їх для Quickshell-паралакса.

Що змінилось порівняно з першою версією (чому було «криво»):
  * Кожен шар ДОМАЛЬОВУЄТЬСЯ під ближчими шарами на ширину можливого зсуву
    (раніше — лише фон), тож при русі довкола об'єктів не вилазить небо.
  * Глибина більше не розмивається Гаусом перед нарізкою — краї об'єктів
    підтягуються до країв фото (guided filter), без «ореолу» фону.
  * Орієнтація глибини за замовчуванням — як каже модель (DA V2: більше = ближче),
    а не вгадування за верхом/низом кадру, яке перевертало сцени з персонажем угорі.
  * Кожен шар отримує СВОЮ глибину (середня глибина його пікселів) → layers.json
    з полем "depth": шар рухається пропорційно реальній глибині, а не номеру.
  * Порожні смуги не пишуться; є анімоване прев'ю (preview.mp4) і --depth-in
    (можна підправити _depth.png у GIMP і перезапустити без моделі).

Приклади:
    python3 parallax.py photo.jpg --screen 1920x1200 -s 10
    python3 parallax.py photo.jpg --screen 1920x1200 -s 10 -n 8 --anim
    python3 parallax.py photo.jpg --depth-in photo/_depth.png --screen 1920x1200 -s 10

Вихід (у папці -o):
    layer00.png ... layerNN.png   — шари (найдальший → найближчий)
    layers.json                    — готовий фрагмент для settings.json (з "depth")
    preview.png                    — зібраний вигляд
    preview.mp4                    — як рухатиметься (з --anim)
    _depth.png                     — карта глибини (білий = близько)
"""

import argparse
import json
import math
import os
import sys
from concurrent.futures import ThreadPoolExecutor

import cv2
import numpy as np
from scipy import ndimage

# ---- шлях до моделі (поруч зі скриптом) ----
_MODEL = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "models", "depth_anything_v2_small.onnx")

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)   # ImageNet
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)
PATCH = 14                 # розмір патча ViT: сторони мають бути кратні 14
IN_SIZE = 518              # менша сторона входу моделі (кратне 14)
MAX_SIDE = 74 * PATCH      # стеля для довшої сторони (1036), щоб не вбити CPU
PNG_PARAMS = [cv2.IMWRITE_PNG_COMPRESSION, 4]


# =====================================================================
#  Глибина
# =====================================================================
class DepthEstimator:
    """Оцінка відносної глибини Depth Anything V2 (Small) через onnxruntime."""

    def __init__(self, model_path=_MODEL):
        import onnxruntime as ort          # імпорт тут: для --depth-in модель не потрібна
        if not os.path.exists(model_path):
            sys.exit(f"Модель не знайдено: {model_path}\n"
                     f"Завантаж: https://huggingface.co/onnx-community/"
                     f"depth-anything-v2-small/resolve/main/onnx/model.onnx")
        wanted = ("CUDAExecutionProvider", "ROCMExecutionProvider",
                  "CPUExecutionProvider")
        avail = ort.get_available_providers()
        providers = [p for p in wanted if p in avail] or ["CPUExecutionProvider"]
        self.sess = ort.InferenceSession(model_path, providers=providers)

        inp = self.sess.get_inputs()[0]
        self.in_name = inp.name
        shp = inp.shape
        self.fixed = None
        if len(shp) == 4 and isinstance(shp[2], int) and isinstance(shp[3], int):
            self.fixed = (shp[3], shp[2])  # (w, h)

    def _size_for(self, W, H):
        """Розмір входу зі збереженням пропорцій (кратний 14)."""
        if self.fixed:
            return self.fixed
        s = IN_SIZE / min(W, H)
        w, h = W * s, H * s
        big = max(w, h)
        if big > MAX_SIDE:
            k = MAX_SIDE / big
            w, h = w * k, h * k

        def snap(v):
            return max(PATCH, int(round(v / PATCH)) * PATCH)
        return snap(w), snap(h)

    def _infer(self, rgb, size):
        w, h = size
        interp = cv2.INTER_AREA if w < rgb.shape[1] else cv2.INTER_CUBIC
        x = cv2.resize(rgb, (w, h), interpolation=interp).astype(np.float32) / 255.0
        x = ((x - MEAN) / STD).transpose(2, 0, 1)[None].astype(np.float32)
        out = self.sess.run(None, {self.in_name: x})[0]
        return np.squeeze(out).astype(np.float32)

    def predict(self, img_bgr, tta=False):
        H, W = img_bgr.shape[:2]
        rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)

        def run(size):
            d = self._infer(rgb, size)
            if tta:
                flipped = np.ascontiguousarray(rgb[:, ::-1])
                d = (d + self._infer(flipped, size)[:, ::-1]) / 2.0
            return d

        size = self._size_for(W, H)
        try:
            d = run(size)
        except Exception:
            if size == (IN_SIZE, IN_SIZE):
                raise
            print("  ! модель не прийняла динамічний розмір, пробую 518x518")
            d = run((IN_SIZE, IN_SIZE))
        d = np.ascontiguousarray(d, dtype=np.float32)
        # INTER_LINEAR, а не CUBIC: кубічна дає «дзвін» (перехльости) на краях об'єктів
        return cv2.resize(d, (W, H), interpolation=cv2.INTER_LINEAR)


def normalize_depth(d, gamma=1.0, equalize=False, orient="model"):
    """Результат: 1 = близько (передній план), 0 = далеко (небо/фон).

    orient: 'model'  — довіряти моделі (DA V2 і так дає більше = ближче) — за замовч.,
            'auto'   — вгадати за верхом/низом кадру (стара поведінка),
            'invert' — примусово інвертувати.
    Розмиття тут більше НЕМА: воно «розтягувало» об'єкти на фон."""
    H, W = d.shape
    if orient == "invert":
        d = -d
    elif orient == "auto":
        if d[:H // 6].mean() > d[-H // 6:].mean():
            d = -d
    lo, hi = np.percentile(d, 1), np.percentile(d, 99)
    if hi - lo < 1e-6:
        hi = lo + 1e-6
    d = np.clip((d - lo) / (hi - lo), 0, 1).astype(np.float32)
    if equalize:
        d8 = (d * 255).astype(np.uint8)
        d = cv2.equalizeHist(d8).astype(np.float32) / 255.0
    if gamma != 1.0:
        d = np.power(np.clip(d, 0.0, 1.0), gamma)
    return d


def guided_filter(guide, src, radius, eps=1e-3):
    """Guided filter (He et al.): підтягує краї карти глибини до країв фото."""
    k = (2 * radius + 1, 2 * radius + 1)

    def box(x):
        return cv2.blur(x, k)

    mean_I, mean_p = box(guide), box(src)
    var_I = box(guide * guide) - mean_I * mean_I
    cov_Ip = box(guide * src) - mean_I * mean_p
    a = cov_Ip / (var_I + eps)
    b = mean_p - a * mean_I
    return box(a) * guide + box(b)


def refine_depth(img_bgr, D):
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
    r = max(4, img_bgr.shape[1] // 320)
    return np.clip(guided_filter(gray, D.astype(np.float32), r), 0.0, 1.0)


def snap_edges(img_bgr, D, radius=None, min_jump=0.12, iters=2):
    """«Прилипання» країв глибини до країв на фото.

    Модель дає на межі об'єкта плавний перехід глибини (10–20 px). Пікселі
    цього переходу мають «проміжну» глибину й потрапляють у середні шари —
    звідси контури-ниточки й ореоли при русі. Тут кожен піксель у зоні
    перепаду (локальний max−min > min_jump) отримує глибину ТІЄЇ сторони
    (ближньої чи дальньої), на чий колір він схожий більше."""
    H, W = D.shape
    if radius is None:
        radius = max(4, int(round(W / 160)))
    k = 2 * radius + 1
    ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
    lab = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2LAB).astype(np.float32)
    for _ in range(iters):
        dmax = cv2.dilate(D, ker)
        dmin = cv2.erode(D, ker)
        edge = (dmax - dmin) > min_jump
        if not edge.any():
            break
        mid = (dmax + dmin) * 0.5
        near = (D > mid).astype(np.float32)
        # «чисті» пікселі сторін: далеко від середини перепаду
        span = np.maximum(dmax - dmin, 1e-6)
        conf = np.abs(D - mid) / span                       # 0 на середині, 0.5 на краях
        wn = near * (conf > 0.3)
        wf = (1 - near) * (conf > 0.3)
        box = lambda x: cv2.boxFilter(x, -1, (k, k), normalize=False)
        sn, sf = box(wn), box(wf)
        cn = np.dstack([box(lab[..., c] * wn) for c in range(3)]) / np.maximum(sn, 1e-6)[..., None]
        cf = np.dstack([box(lab[..., c] * wf) for c in range(3)]) / np.maximum(sf, 1e-6)[..., None]
        dn = np.linalg.norm(lab - cn, axis=2)
        df = np.linalg.norm(lab - cf, axis=2)
        ok = edge & (sn > 2) & (sf > 2)
        D = D.copy()
        D[ok] = np.where(dn[ok] <= df[ok], dmax[ok], dmin[ok])
    return D


def fill_objects(D, threshold=0.5):
    """Заливає 'порожні' об'єкти суцільним переднім планом (як раніше)."""
    near = D >= threshold
    if not near.any():
        return D
    D_out = D.copy()
    D_out[near] = float(D[near].mean())
    return D_out


# =====================================================================
#  Мітки шарів
# =====================================================================
def depth_thresholds(D, n_layers, split="uniform"):
    """uniform  — рівні смуги за значенням глибини;
    quantile — смуги з однаковою кількістю пікселів."""
    if split == "quantile":
        return np.quantile(D, np.linspace(0, 1, n_layers + 1))
    return np.linspace(0, 1, n_layers + 1)


def _reassign(labels, bad):
    """Замінює мітки в масці bad мітками найближчих «хороших» пікселів."""
    if not bad.any() or bad.all():
        return labels
    _, idx = ndimage.distance_transform_edt(bad, return_indices=True)
    return labels[idx[0], idx[1]]


def clean_labels(labels, min_width, min_area):
    """Прибирає «ниточки» й дрібні шматки (зливає з найближчим більшим шаром)."""
    if min_width and min_width >= 3:
        k = min_width | 1
        ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
        good = np.zeros(labels.shape, bool)
        for v in np.unique(labels):
            m = (labels == v).astype(np.uint8)
            good |= cv2.morphologyEx(m, cv2.MORPH_OPEN, ker) > 0
        labels = _reassign(labels, ~good)
    if min_area > 0:
        bad = np.zeros(labels.shape, bool)
        for v in np.unique(labels):
            m = (labels == v).astype(np.uint8)
            n, cc, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
            for c in range(1, n):
                if stats[c, cv2.CC_STAT_AREA] < min_area:
                    bad |= (cc == c)
        labels = _reassign(labels, bad)
    return labels


def make_labels(D, n_layers, split, min_width, min_area):
    ts = depth_thresholds(D, n_layers, split)
    labels = np.searchsorted(ts[1:-1], D, side="right").astype(np.uint8)
    labels = clean_labels(labels, min_width, min_area)
    # лишаємо лише непорожні шари й перенумеровуємо 0..K-1 (дальній → ближній)
    used = [v for v in range(n_layers) if (labels == v).any()]
    remap = np.zeros(max(used) + 1, np.uint8)
    for i, v in enumerate(used):
        remap[v] = i
    return remap[labels], len(used)


# =====================================================================
#  Шари
# =====================================================================
def extend_layer(img_bgr, own, region, margin, smooth):
    """Домальовує колір шару в region (місце під ближчими шарами), беручи лише
    його власні пікселі (own). Близько до краю — найближчий реальний піксель,
    далі — дедалі сильніше розмита версія: без «смугастих» розтягнень."""
    if not region.any():
        return img_bgr
    # Джерело кольору — «серцевина» шару, на кілька px углиб від краю: на самому
    # краї бувають чужі пікселі (сусіднього об'єкта), і їх розмазало б смугами.
    src = own
    er = max(2, img_bgr.shape[1] // 400)
    core = cv2.erode(own.astype(np.uint8),
                     cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * er + 1,) * 2)) > 0
    if core.sum() > 0.25 * own.sum():
        src = core
    # найближчий надійний піксель для кожної точки
    dist, idx = ndimage.distance_transform_edt(~src, return_indices=True)
    near = img_bgr[idx[0], idx[1]]
    out = img_bgr.copy()
    if smooth > 0 and margin > 2:
        sig = max(1.0, margin / 3.0) * smooth
        blur = cv2.GaussianBlur(near, (0, 0), sig)
        t = np.clip(dist / max(1.0, margin), 0, 1)[..., None]   # 0 біля краю → 1 далеко
        mixed = near * (1 - t) + blur * t
        out[region] = np.clip(mixed[region], 0, 255).astype(np.uint8)
    else:
        out[region] = near[region]
    return out


def iter_layers(img_bgr, labels, n, layer_depths, strength, dilate_px=1,
                feather=0.8, smooth=1.0):
    """Генератор BGRA-шарів (дальній → ближній).

    Шар k = власні пікселі + домальоване продовження під ближчими шарами на
    ширину максимального відносного зсуву (strength · (d_max − d_k)) + запас.
    Фон (k = 0) домальовується повністю, щоб ніде не було прозорості."""
    H, W = img_bgr.shape[:2]
    d_max = max(layer_depths)
    ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * dilate_px + 1,) * 2) if dilate_px > 0 else None

    for k in range(n):
        own = labels == k
        nearer = labels > k
        if k == 0:
            region = ~own                                  # фон — суцільний
            margin = strength * 2
        else:
            margin = int(math.ceil(strength * (d_max - layer_depths[k]))) + dilate_px + 3
            if margin > 0 and nearer.any():
                grow = cv2.dilate(own.astype(np.uint8),
                                  cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * margin + 1,) * 2))
                region = (grow > 0) & nearer
            else:
                region = np.zeros_like(own)

        color = extend_layer(img_bgr, own, region, margin, smooth)

        if k == 0:
            alpha = np.full((H, W), 255, np.uint8)
        else:
            core = own.astype(np.uint8) * 255
            if ker is not None:
                core_d = cv2.dilate(core, ker)             # невелике перекриття шва
            else:
                core_d = core
            soft = cv2.GaussianBlur(core_d, (0, 0), feather) if feather > 0 else core_d
            alpha = np.maximum(np.maximum(core, soft), region.astype(np.uint8) * 255)
        yield np.dstack([color, alpha])


# =====================================================================
#  Підготовка зображення
# =====================================================================
def autocrop_black_borders(img, thr=12, max_frac=0.33):
    """Прибирає однорідні чорні смуги по краях (letterbox/pillarbox)."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    H, W = gray.shape

    def uniform(a):
        return a.mean() < thr and a.std() < thr

    top = 0
    while top < H and uniform(gray[top]):
        top += 1
    bot = 0
    while bot < H - top and uniform(gray[H - 1 - bot]):
        bot += 1
    left = 0
    while left < W and uniform(gray[:, left]):
        left += 1
    right = 0
    while right < W - left and uniform(gray[:, W - 1 - right]):
        right += 1

    top = min(top, int(H * max_frac))
    bot = min(bot, int(H * max_frac))
    left = min(left, int(W * max_frac))
    right = min(right, int(W * max_frac))

    if (top or bot or left or right) and (H - bot - top) > 10 and (W - right - left) > 10:
        return img[top:H - bot, left:W - right]
    return img


def fit_to_size(img, tw, th):
    """Центр-кроп під аспект цілі + ресайз до точного розміру."""
    H, W = img.shape[:2]
    sa, ta = W / H, tw / th
    if sa > ta:
        nw = int(round(H * ta))
        x0 = (W - nw) // 2
        img = img[:, x0:x0 + nw]
    elif sa < ta:
        nh = int(round(W / ta))
        y0 = (H - nh) // 2
        img = img[y0:y0 + nh]
    interp = cv2.INTER_AREA if (tw < W or th < H) else cv2.INTER_CUBIC
    return cv2.resize(img, (tw, th), interpolation=interp)


def parse_wh(ap, s, name):
    try:
        w, h = (int(v) for v in s.lower().split("x"))
        if w <= 0 or h <= 0:
            raise ValueError
    except ValueError:
        ap.error(f"{name}: очікується формат WxH, напр. 2120x1400")
    return w, h


# =====================================================================
#  Прев'ю
# =====================================================================
def shift_layer(L, dx, dy):
    """Зсув BGRA-шару на (dx, dy) з субпіксельною точністю (як у Quickshell)."""
    M = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(L, M, (L.shape[1], L.shape[0]), flags=cv2.INTER_LINEAR,
                          borderMode=cv2.BORDER_REPLICATE)


def composite(layers, depths, nx, ny, strength, invert=False):
    """Як Quickshell складає шари при курсорі (nx, ny ∈ [-1, 1])."""
    sgn = 1 if invert else -1
    out = None
    for L, d in zip(layers, depths):
        S = shift_layer(L, sgn * nx * strength * d, sgn * ny * strength * d)
        a = S[:, :, 3:4].astype(np.float32) / 255.0
        rgb = S[:, :, :3].astype(np.float32)
        out = rgb if out is None else rgb * a + out * (1 - a)
    return np.clip(np.rint(out), 0, 255).astype(np.uint8)


def write_anim(path, layers, depths, strength, crop, fps=30, seconds=4):
    """preview.mp4: курсор обходить екран по колу — видно, як рухаються шари."""
    x0, y0, w, h = crop
    vw = cv2.VideoWriter(path, cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    n = fps * seconds
    for i in range(n):
        t = 2 * math.pi * i / n
        fr = composite(layers, depths, math.cos(t), math.sin(t), strength)
        vw.write(fr[y0:y0 + h, x0:x0 + w])
    vw.release()


# =====================================================================
#  CLI
# =====================================================================
def main():
    ap = argparse.ArgumentParser(
        description="Генератор багатошарових паралакс-шпалер з одного фото.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    ap.add_argument("image", help="шлях до вхідного фото (jpg/png/webp...)")
    ap.add_argument("-o", "--output", default=None,
                    help="папка виходу (за замовч.: ім'я файлу без розширення)")
    ap.add_argument("--model", default=_MODEL, help="шлях до ONNX-моделі")
    ap.add_argument("--depth-in", default=None, metavar="PNG",
                    help="готова карта глибини (білий = близько) замість моделі; "
                         "напр. підправлений у GIMP _depth.png")
    ap.add_argument("-n", "--layers", type=int, default=10,
                    help="макс. кількість шарів (порожні смуги пропускаються)")
    ap.add_argument("-w", "--max-width", type=int, default=2560,
                    help="макс. ширина шарів (якщо не задано --size/--screen)")
    ap.add_argument("--size", default=None, metavar="WxH",
                    help="точний розмір виходу, напр. '1940x1220'")
    ap.add_argument("--screen", default=None, metavar="WxH",
                    help="розмір екрана; вихід = екран + 2*strength по кожній осі")
    ap.add_argument("-s", "--strength", type=int, default=60,
                    help="сила паралакса в px — ТА САМА, що parallax.strength у settings.json "
                         "(від неї залежить, наскільки домальовувати шари)")
    ap.add_argument("--smooth", type=float, default=1.0,
                    help="м'якість домальованих ділянок (0 = найближчий піксель, 1 = норм, 2 = дуже м'яко)")
    ap.add_argument("--dilate", type=int, default=1,
                    help="перекриття швів між шарами, px (0-3)")
    ap.add_argument("--feather", type=float, default=0.8,
                    help="згладжування країв шарів (сигма px, 0 = різкі «драбинкою»)")
    ap.add_argument("--min-width", type=int, default=-1,
                    help="мін. товщина смуги шару в px (-1 = авто, 0 = вимкнути)")
    ap.add_argument("--min-area", type=float, default=0.0005,
                    help="мін. площа шматка шару як частка кадру (0 = вимкнути)")
    ap.add_argument("--split", choices=["uniform", "quantile"], default="uniform",
                    help="ділити глибину рівними смугами чи рівними за кількістю пікселів")
    ap.add_argument("--gamma", type=float, default=1.0,
                    help="гамма глибини: <1 витягує далекі/низькоконтрастні об'єкти")
    ap.add_argument("--equalize", action="store_true", help="гістограмна еквалізація глибини")
    ap.add_argument("--orient", choices=["model", "auto", "invert"], default="model",
                    help="орієнтація глибини: model (довіряти моделі), auto (вгадати за "
                         "верхом/низом кадру — стара поведінка), invert (перевернути)")
    ap.add_argument("--no-refine", action="store_true",
                    help="не підтягувати краї глибини до країв фото (guided filter)")
    ap.add_argument("--no-snap", action="store_true",
                    help="не «приклеювати» краї глибини до кольорів (буде як раніше: "
                         "контури-ниточки довкола об'єктів)")
    ap.add_argument("--tta", action="store_true",
                    help="усереднення з дзеркальним проходом (×2 за часом)")
    ap.add_argument("--fill-holes", action="store_true",
                    help="заливає об'єкти суцільно ('не чорне' → близька глибина)")
    ap.add_argument("--fill-threshold", type=float, default=0.5,
                    help="поріг 'близько/далеко' для --fill-holes")
    ap.add_argument("--anim", action="store_true",
                    help="зберегти preview.mp4 — як рухатиметься паралакс")
    ap.add_argument("--path-prefix", default="./assets/parallax_backgrounds",
                    help="префікс шляхів у layers.json (відносно shell.qml)")
    ap.add_argument("--no-autocrop", action="store_true",
                    help="не обрізати чорні смуги по краях")
    args = ap.parse_args()

    if args.layers < 2:
        ap.error("-n/--layers: потрібно щонайменше 2 шари")
    if args.size and args.screen:
        ap.error("--size і --screen разом не використовуються")
    if not os.path.exists(args.image):
        sys.exit(f"Файл не знайдено: {args.image}")

    target = None
    if args.screen:
        sw, sh = parse_wh(ap, args.screen, "--screen")
        target = (sw + 2 * args.strength, sh + 2 * args.strength)
    elif args.size:
        target = parse_wh(ap, args.size, "--size")

    outdir = args.output or os.path.splitext(os.path.basename(args.image))[0]

    print(f"Завантаження {os.path.basename(args.image)} ...")
    img = cv2.imread(args.image, cv2.IMREAD_COLOR)
    if img is None:
        sys.exit(f"Не вдалося прочитати зображення: {args.image}")
    if not args.no_autocrop:
        img = autocrop_black_borders(img)
    if target:
        img = fit_to_size(img, *target)
        print(f"  розмір виходу: {target[0]}x{target[1]}")
    elif img.shape[1] > args.max_width:
        s = args.max_width / img.shape[1]
        img = cv2.resize(img, (args.max_width, int(img.shape[0] * s)), interpolation=cv2.INTER_AREA)
    img = np.ascontiguousarray(img)
    H, W = img.shape[:2]

    if args.depth_in:
        print(f"Глибина з файлу {args.depth_in} ...")
        dm = cv2.imread(args.depth_in, cv2.IMREAD_UNCHANGED)
        if dm is None:
            sys.exit(f"Не вдалося прочитати карту глибини: {args.depth_in}")
        if dm.ndim == 3:
            dm = cv2.cvtColor(dm[:, :, :3], cv2.COLOR_BGR2GRAY)
        dm = dm.astype(np.float32) / (65535.0 if dm.dtype == np.uint16 else 255.0)
        raw = cv2.resize(dm, (W, H), interpolation=cv2.INTER_LINEAR)
        D = normalize_depth(raw, args.gamma, args.equalize,
                            "invert" if args.orient == "invert" else "model")
    else:
        print(f"Оцінка глибини ({W}x{H}) ...")
        est = DepthEstimator(args.model)
        D = normalize_depth(est.predict(img, tta=args.tta), gamma=args.gamma,
                            equalize=args.equalize, orient=args.orient)
    if not args.no_refine:
        D = refine_depth(img, D)
    if not args.no_snap:
        D = snap_edges(img, D)
    if args.fill_holes:
        D = fill_objects(D, args.fill_threshold)
    print(f"  діапазон глибини: {D.min():.3f}..{D.max():.3f}  "
          f"(верх={D[:H // 6].mean():.3f} / низ={D[-H // 6:].mean():.3f})")

    min_width = args.min_width if args.min_width >= 0 else max(5, int(round(W / 250)))
    labels, n = make_labels(D, args.layers, args.split, min_width, int(args.min_area * W * H))
    # глибина кожного шару = середня глибина його пікселів (0 = нерухомий горизонт, 1 = найближче)
    depths = [float(D[labels == k].mean()) for k in range(n)]
    depths = [round(min(1.0, max(0.0, d)), 3) for d in depths]
    if n < args.layers:
        print(f"  порожні смуги пропущено: вийшло {n} шарів із {args.layers}")

    os.makedirs(outdir, exist_ok=True)
    print(f"Запис {n} шарів у {outdir}/ ...")

    layers = []
    futures = []
    with ThreadPoolExecutor() as ex:
        for i, L in enumerate(iter_layers(img, labels, n, depths, args.strength,
                                          dilate_px=args.dilate, feather=args.feather,
                                          smooth=args.smooth)):
            path = os.path.join(outdir, f"layer{i:02d}.png")
            futures.append((path, ex.submit(cv2.imwrite, path, L, PNG_PARAMS)))
            layers.append(L)
        cv2.imwrite(os.path.join(outdir, "_depth.png"), (D * 255).astype(np.uint8))
        cv2.imwrite(os.path.join(outdir, "preview.png"),
                    composite(layers, depths, 0, 0, args.strength))

    failed = [p for p, f in futures if not f.result()]
    if failed:
        sys.exit("Не вдалося записати: " + ", ".join(failed))

    # готовий фрагмент для settings.json
    name = os.path.basename(os.path.normpath(outdir))
    snippet = {"layers": [{"file": f"{args.path_prefix.rstrip('/')}/{name}/layer{i:02d}.png",
                           "crop": True, "depth": depths[i]} for i in range(n)],
               "strength": args.strength}
    with open(os.path.join(outdir, "layers.json"), "w", encoding="utf-8") as f:
        json.dump(snippet, f, ensure_ascii=False, indent=2)

    if args.anim:
        print("Анімоване прев'ю ...")
        s = args.strength
        crop = (s, s, W - 2 * s, H - 2 * s) if W > 4 * s and H > 4 * s else (0, 0, W, H)
        write_anim(os.path.join(outdir, "preview.mp4"), layers, depths, s, crop)

    print("Готово ✅  " + ", ".join(f"{i}:{d:.2f}" for i, d in enumerate(depths)))
    print(f"  глибини шарів записано в {outdir}/layers.json (поле \"depth\")")


if __name__ == "__main__":
    main()
