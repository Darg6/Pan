"""
Genera todo el pixel art provisional de Pan (tiles, sprites, fondos e interfaz).

No necesitas correr esto para jugar: las imágenes ya están en arte/.
Sirve si quieres regenerarlas o ver cómo están hechas. Requiere Python 3 + Pillow:
    pip install pillow
    python herramientas/generar_pixel_art.py

Cuando tengas tu propio arte, simplemente reemplaza los PNG en arte/ con el mismo nombre
y tamaño, y Godot los usará automáticamente.
"""
import json
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ARTE = os.path.join(RAIZ, "arte")
T = 16  # tamaño de un tile

# ---------------------------------------------------------------------------
# Paleta (post-apocalíptica, tonos polvorientos)
# ---------------------------------------------------------------------------
def c(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

CONTORNO = c("1b161c")
TIERRA = [c("b08559"), c("9c7450"), c("8a6445"), c("c49a68"), c("70503a")]
ARENA = [c("c9884a"), c("b5763e"), c("a06535"), c("dba05e")]
ASFALTO = [c("4b4a52"), c("403f47"), c("57565f"), c("33323a")]
CONCRETO = [c("8d8984"), c("75716c"), c("5c5955"), c("aaa69f"), c("44413e")]
OXIDO = [c("9b4f2a"), c("7a3a1e"), c("c06a36"), c("5c2a16"), c("d98a4a")]
PASTO = [c("8c8a3a"), c("6f6d2c"), c("aaa752"), c("55531f"), c("c4c06a")]
TOXICO = [c("7bd13b"), c("4f9a24"), c("b6f06a")]
METAL = [c("56606b"), c("444c56"), c("6d7985"), c("2f353d"), c("8a96a3")]
MADERA = [c("8a5a32"), c("6b4426"), c("a8743f")]
SOMBRA = (0, 0, 0, 70)

def nuevo(w, h, color=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), color)

def ruido(img, rect, colores, densidad, rng):
    x0, y0, x1, y1 = rect
    for _ in range(int((x1 - x0) * (y1 - y0) * densidad)):
        x = rng.randrange(x0, x1)
        y = rng.randrange(y0, y1)
        img.putpixel((x, y), rng.choice(colores))

def contorno(img, color=CONTORNO):
    """Agrega un borde de 1 píxel alrededor de lo dibujado (estilo pixel art)."""
    w, h = img.size
    src = img.copy()
    px = src.load()
    out = img.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0 and px[nx, ny] != color:
                        out[x, y] = color
                        break
    return img

def sombrear(img, luz=1.15, sombra=0.7):
    """Luz arriba-izquierda, sombra abajo-derecha: da volumen a las figuras."""
    w, h = img.size
    src = img.copy()
    px = src.load()
    out = img.load()
    def vacio(x, y):
        return not (0 <= x < w and 0 <= y < h) or px[x, y][3] == 0 or px[x, y] == CONTORNO
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0 or p == CONTORNO:
                continue
            f = 1.0
            if vacio(x, y - 1) or vacio(x - 1, y):
                f = luz
            if vacio(x, y + 1) or vacio(x + 1, y) or vacio(x + 1, y + 1):
                f = sombra
            out[x, y] = (min(255, int(p[0] * f)), min(255, int(p[1] * f)), min(255, int(p[2] * f)), p[3])
    return img

def guardar(img, ruta, escala=1):
    ruta = os.path.join(ARTE, ruta)
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    if escala != 1:
        img = img.resize((img.width * escala, img.height * escala), Image.NEAREST)
    img.save(ruta)

def tramado(img, rect, c1, c2, rng=None, nivel=0.5):
    """Tramado (dithering) en tablero de ajedrez: mezcla dos colores como en los 16 bits."""
    x0, y0, x1, y1 = rect
    d = ImageDraw.Draw(img)
    for y in range(y0, y1):
        for x in range(x0, x1):
            if nivel >= 0.5:
                usar2 = (x + y) % 2 == 0 if nivel < 0.75 else (x % 2 == 0 or y % 2 == 0)
            else:
                usar2 = (x % 2 == 0 and y % 2 == 0) if nivel >= 0.25 else (x % 4 == 0 and y % 4 == 0)
            d.point((x, y), c2 if usar2 else c1)

def gradiente(img, rect, colores, tramar=True):
    """Cielo en franjas con tramado entre franjas."""
    x0, y0, x1, y1 = rect
    n = len(colores) - 1
    alto = (y1 - y0) / n
    d = ImageDraw.Draw(img)
    for i in range(n):
        ya = int(y0 + i * alto)
        yb = int(y0 + (i + 1) * alto)
        d.rectangle((x0, ya, x1 - 1, yb - 1), colores[i])
        if tramar:
            banda = max(2, (yb - ya) // 3)
            tramado(img, (x0, yb - banda, x1, yb - banda // 2), colores[i], colores[i + 1], nivel=0.3)
            tramado(img, (x0, yb - banda // 2, x1, yb), colores[i], colores[i + 1], nivel=0.5)

# Simetría y luz para personajes
def espejar(img):
    """Copia la mitad izquierda sobre la derecha: figura simétrica perfecta."""
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w // 2):
            px[w - 1 - x, y] = px[x, y]
    return img

def contorno_suave(img):
    w, h = img.size
    src = img.copy(); px = src.load(); out = img.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((0, 1), (0, -1), (-1, 0), (1, 0)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                    out[x, y] = oscurecer(px[nx, ny], 0.25)[:3] + (255,)
                    break
    return img

def luz_lateral(img, luz=1.12, sombra=0.78):
    """Luz desde arriba: borde de arriba más claro, borde de abajo/lados un poco más oscuro (simétrico)."""
    w, h = img.size
    src = img.copy(); px = src.load(); out = img.load()
    def v(x, y):
        return not (0 <= x < w and 0 <= y < h) or px[x, y][3] == 0
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0:
                continue
            f = 1.0
            if v(x, y - 1):
                f = luz
            elif v(x, y + 1) or v(x - 1, y) or v(x + 1, y):
                f = sombra
            out[x, y] = (min(255, int(p[0] * f)), min(255, int(p[1] * f)), min(255, int(p[2] * f)), p[3])
    return img

# ---------------------------------------------------------------------------
# TILES DEL EXTERIOR
# ---------------------------------------------------------------------------
TILES_EXT = {}   # nombre -> (col, fila, solido)
TILES_INT = {}

def tile_tierra(rng, base=TIERRA):
    t = nuevo(T, T, base[0])
    ruido(t, (0, 0, T, T), [base[1], base[2]], 0.18, rng)
    ruido(t, (0, 0, T, T), [base[3]], 0.05, rng)
    for _ in range(rng.randint(0, 2)):  # piedritas
        x, y = rng.randrange(1, T - 2), rng.randrange(1, T - 2)
        t.putpixel((x, y), base[4] if len(base) > 4 else base[2])
        t.putpixel((x + 1, y), base[2])
        t.putpixel((x, y - 1), base[3])
    return t

def tile_asfalto(rng, grieta=False, linea=False):
    t = nuevo(T, T, ASFALTO[0])
    ruido(t, (0, 0, T, T), [ASFALTO[1], ASFALTO[2], ASFALTO[3]], 0.25, rng)
    d = ImageDraw.Draw(t)
    if grieta:
        x, y = rng.randrange(3, 12), 0
        while y < T:
            nx = max(0, min(T - 1, x + rng.choice((-1, 0, 1))))
            d.line((x, y, nx, y + 2), CONTORNO)
            x, y = nx, y + 2
        ruido(t, (0, 0, T, T), [PASTO[1]], 0.03, rng)  # hierbita en la grieta
    if linea:
        d.rectangle((1, 7, 6, 8), c("c9a227"))
        d.rectangle((9, 7, 14, 8), c("c9a227"))
        t.putpixel((3, 7), c("8e7420"))
        t.putpixel((11, 8), c("8e7420"))
    return t

def tile_concreto(rng):
    t = nuevo(T, T, CONCRETO[1])
    ruido(t, (0, 0, T, T), [CONCRETO[0], CONCRETO[2]], 0.2, rng)
    d = ImageDraw.Draw(t)
    d.line((0, 0, T - 1, 0), CONCRETO[2])
    d.line((0, 0, 0, T - 1), CONCRETO[2])
    return t

def tile_pasto(rng, variante):
    t = tile_tierra(rng)
    d = ImageDraw.Draw(t)
    for _ in range(7 + variante * 2):
        x = rng.randrange(0, T)
        y = rng.randrange(5, T + 2)
        h = rng.randint(4, 7)
        col = rng.choice([PASTO[0], PASTO[2], PASTO[1]])
        d.line((x, y, x + rng.choice((-1, 0, 1)), y - h), col)
        d.point((x, y - h), PASTO[4])
        d.line((x + 1, y, x + 1, y - h + 2), PASTO[3])
    return t

def tile_arena(rng):
    t = nuevo(T, T, ARENA[0])
    ruido(t, (0, 0, T, T), [ARENA[1], ARENA[3]], 0.16, rng)
    d = ImageDraw.Draw(t)
    y = rng.randrange(3, 12)  # ondas de viento
    d.line((2, y, 7, y), ARENA[2])
    d.line((8, y + 3, 13, y + 3), ARENA[2])
    return t

def tile_toxico(rng):
    t = tile_tierra(rng)
    d = ImageDraw.Draw(t)
    d.ellipse((1, 3, 14, 13), TOXICO[1])
    d.ellipse((2, 4, 13, 12), TOXICO[0])
    d.point((5, 6), TOXICO[2])
    d.point((6, 6), TOXICO[2])
    d.point((10, 9), TOXICO[2])
    return t

def tile_vacio(rng):
    t = nuevo(T, T, c("1d1820"))
    ruido(t, (0, 0, T, T), [c("261f2a")], 0.1, rng)
    return t

def tile_acantilado(rng):
    t = nuevo(T, T, CONCRETO[2])
    d = ImageDraw.Draw(t)
    for y in range(0, T, 4):
        d.line((0, y, T, y), CONCRETO[4])
    ruido(t, (0, 0, T, T), [CONCRETO[1], CONCRETO[4]], 0.15, rng)
    return t

def tile_borde_acantilado(rng):
    t = tile_tierra(rng)
    d = ImageDraw.Draw(t)
    d.rectangle((0, 10, T, T), CONCRETO[2])
    d.line((0, 10, T, 10), CONCRETO[3])
    d.line((0, 11, T, 11), TIERRA[4])
    ruido(t, (0, 12, T, T), [CONCRETO[4]], 0.2, rng)
    return t

def tile_borde_norte(rng):
    """Borde del acantilado visto desde el sur: el abismo queda arriba."""
    t = tile_tierra(rng)
    d = ImageDraw.Draw(t)
    d.rectangle((0, 0, T, 5), c("1d1820"))
    d.line((0, 6, T, 6), CONCRETO[2])
    d.line((0, 7, T, 7), CONCRETO[3])
    for x in range(0, T, 4):
        d.point((x + rng.randint(0, 2), 5), CONCRETO[2])
    return t

def tile_muro_top(rng):
    t = nuevo(T, T, CONCRETO[0])
    ruido(t, (0, 0, T, T), [CONCRETO[3], CONCRETO[1]], 0.22, rng)
    d = ImageDraw.Draw(t)
    d.rectangle((0, 0, T - 1, T - 1), outline=CONCRETO[2])
    # borde roto
    for x in range(0, T, 3):
        d.point((x, 0), (0, 0, 0, 0))
    return t

def tile_muro(rng):
    t = nuevo(T, T, CONCRETO[1])
    ruido(t, (0, 0, T, T), [CONCRETO[2], CONCRETO[0]], 0.2, rng)
    d = ImageDraw.Draw(t)
    d.line((0, 0, T, 0), CONCRETO[3])
    d.line((0, T - 1, T, T - 1), CONCRETO[4])
    # ladrillos/bloques
    for y in (5, 10):
        d.line((0, y, T, y), CONCRETO[2])
    d.line((7, 0, 7, 5), CONCRETO[2])
    d.line((3, 5, 3, 10), CONCRETO[2])
    d.line((11, 5, 11, 10), CONCRETO[2])
    d.line((8, 10, 8, 15), CONCRETO[2])
    # varilla oxidada
    if rng.random() < 0.5:
        d.line((12, 1, 14, 4), OXIDO[0])
    return t

def objeto_sobre(base, dibujar, rng, sombra=True):
    """Dibuja un objeto con contorno y sombreado encima de un tile de suelo."""
    capa = nuevo(T, T)
    dibujar(ImageDraw.Draw(capa), capa, rng)
    sombrear(capa)
    contorno(capa)
    t = base.copy()
    if sombra:
        s = nuevo(T, T)
        ImageDraw.Draw(s).ellipse((2, 11, 14, 15), SOMBRA)
        t.alpha_composite(s)
    t.alpha_composite(capa)
    return t

def dib_barril(d, img, rng, color=OXIDO):
    d.rectangle((4, 3, 11, 13), color[0])
    d.line((4, 6, 11, 6), color[1])
    d.line((4, 10, 11, 10), color[1])
    d.ellipse((4, 1, 11, 5), color[2])
    d.ellipse((6, 2, 9, 4), color[1])

def dib_barril_toxico(d, img, rng):
    dib_barril(d, img, rng, (c("c9a227"), c("8e7420"), c("e0c048")))
    d.ellipse((6, 2, 9, 4), TOXICO[0])
    d.point((7, 8), CONTORNO)
    d.point((8, 8), CONTORNO)

def dib_chatarra(d, img, rng):
    d.polygon([(1, 14), (4, 6), (8, 4), (12, 7), (15, 14)], OXIDO[1])
    d.polygon([(3, 13), (6, 8), (9, 9), (7, 13)], METAL[0])
    d.line((9, 5, 14, 11), OXIDO[2])
    d.rectangle((10, 10, 13, 13), METAL[2])
    d.point((5, 9), OXIDO[4])
    d.line((2, 12, 5, 12), OXIDO[0])

def dib_neumaticos(d, img, rng):
    d.ellipse((2, 7, 13, 14), c("2a2a2e"))
    d.ellipse((5, 9, 10, 12), c("17171a"))
    d.ellipse((3, 2, 12, 9), c("333338"))
    d.ellipse((6, 4, 9, 7), c("17171a"))

def dib_arbol(d, img, rng):
    d.line((8, 15, 8, 4), MADERA[1], 2)
    d.line((8, 8, 3, 3), MADERA[1])
    d.line((8, 6, 13, 2), MADERA[1])
    d.line((8, 10, 12, 7), MADERA[1])
    d.line((3, 3, 2, 1), MADERA[1])
    d.line((13, 2, 14, 0), MADERA[1])

def dib_cartel(d, img, rng):
    d.line((8, 15, 8, 6), MADERA[1], 2)
    d.rectangle((2, 2, 13, 8), MADERA[0])
    d.line((4, 4, 11, 4), MADERA[1])
    d.line((4, 6, 9, 6), MADERA[1])

def dib_fogata(d, img, rng):
    d.line((3, 13, 12, 10), MADERA[1], 2)
    d.line((3, 10, 12, 13), MADERA[1], 2)
    d.polygon([(5, 11), (8, 2), (11, 11)], c("ff8c1a"))
    d.polygon([(7, 11), (8, 6), (10, 11)], c("ffd24d"))

def dib_cama_carton(d, img, rng):
    d.rectangle((1, 4, 14, 13), c("a07a4a"))
    d.line((1, 8, 14, 8), c("7d5d36"))
    d.rectangle((2, 5, 5, 7), c("c9c0a8"))  # almohada
    d.rectangle((6, 9, 13, 12), c("6b5a7a"))  # manta

def dib_viga(d, img, rng):
    # Viga oxidada caída sobre escombros (aquí está atrapado el gato del prólogo)
    d.polygon([(0, 13), (3, 8), (13, 7), (16, 13)], CONCRETO[2])
    d.rectangle((0, 5, 15, 8), OXIDO[0])
    d.line((0, 5, 15, 5), OXIDO[4])
    for x in (3, 8, 13):
        d.point((x, 6), OXIDO[3])

def dib_valla(d, img, rng):
    d.line((1, 3, 1, 15), METAL[1])
    d.line((14, 3, 14, 15), METAL[1])
    for i in range(-12, 16, 3):
        d.line((i, 15, i + 12, 3), METAL[2])
        d.line((i, 3, i + 12, 15), METAL[3])
    d.line((0, 3, 15, 3), METAL[4])

def tile_auto(rng, lado):
    base = tile_asfalto(rng)
    capa = nuevo(T * 2, T)
    d = ImageDraw.Draw(capa)
    d.rounded_rectangle((1, 3, 30, 13), 3, OXIDO[0])
    d.rectangle((8, 1, 22, 6), OXIDO[1])
    d.rectangle((9, 2, 14, 5), METAL[3])
    d.rectangle((16, 2, 21, 5), METAL[3])
    d.point((10, 3), METAL[4])
    d.ellipse((4, 10, 9, 15), c("222226"))
    d.ellipse((21, 10, 26, 15), c("222226"))
    ruido(capa, (2, 7, 29, 12), [OXIDO[3], OXIDO[4]], 0.12, rng)
    # quitar ruido fuera del auto
    pa = capa.load()
    sombrear(capa)
    contorno(capa)
    parte = capa.crop((0, 0, T, T)) if lado == 0 else capa.crop((T, 0, 2 * T, T))
    t = base.copy()
    t.alpha_composite(parte)
    return t

def tile_contenedor(rng, color, borde=False):
    t = nuevo(T, T, color[0])
    d = ImageDraw.Draw(t)
    for x in range(1, T, 3):
        d.line((x, 0, x, T), color[1])
    ruido(t, (0, 0, T, T), [OXIDO[0], OXIDO[3]], 0.08, rng)
    if borde:
        d.line((0, 0, T, 0), color[2])
        d.line((0, 1, T, 1), color[1])
    d.line((0, T - 1, T, T - 1), CONTORNO)
    return t

def tile_porton(rng, parte):
    t = nuevo(T, T, METAL[1])
    d = ImageDraw.Draw(t)
    for y in range(2, T, 4):
        d.line((0, y, T, y), METAL[3])
    d.line((0, 0, T, 0), OXIDO[4])
    if parte == 0:
        d.line((T - 1, 0, T - 1, T), CONTORNO)
    else:
        d.line((0, 0, 0, T), CONTORNO)
    ruido(t, (0, 0, T, T), [OXIDO[0]], 0.08, rng)
    return t

def tile_escotilla(rng, sellada=False):
    t = tile_tierra(rng)
    capa = nuevo(T, T)
    d = ImageDraw.Draw(capa)
    d.ellipse((1, 2, 14, 14), METAL[1])
    d.ellipse((3, 4, 12, 12), METAL[0])
    d.line((7, 4, 7, 12), METAL[3])
    d.line((3, 8, 12, 8), METAL[3])
    d.ellipse((6, 7, 9, 10), OXIDO[2] if not sellada else c("aa3333"))
    if sellada:
        d.line((2, 3, 13, 13), OXIDO[1], 2)
        d.line((13, 3, 2, 13), OXIDO[1], 2)
    sombrear(capa)
    contorno(capa)
    t.alpha_composite(capa)
    return t

def generar_tiles_exterior():
    rng = random.Random(42)
    lista = []  # (nombre, imagen, solido)
    for i in range(3):
        lista.append((f"tierra_{i+1}", tile_tierra(rng), False))
    lista.append(("asfalto_1", tile_asfalto(rng), False))
    lista.append(("asfalto_2", tile_asfalto(rng), False))
    lista.append(("asfalto_grieta", tile_asfalto(rng, grieta=True), False))
    lista.append(("asfalto_linea", tile_asfalto(rng, linea=True), False))
    lista.append(("concreto", tile_concreto(rng), False))
    lista.append(("pasto_1", tile_pasto(rng, 0), False))
    lista.append(("pasto_2", tile_pasto(rng, 1), False))
    lista.append(("arena_1", tile_arena(rng), False))
    lista.append(("arena_2", tile_arena(rng), False))
    lista.append(("charco_toxico", tile_toxico(rng), True))
    lista.append(("vacio", tile_vacio(rng), True))
    lista.append(("acantilado", tile_acantilado(rng), True))
    lista.append(("borde_acantilado", tile_borde_acantilado(rng), True))
    lista.append(("borde_norte", tile_borde_norte(rng), True))
    lista.append(("muro_top", tile_muro_top(rng), True))
    lista.append(("muro", tile_muro(rng), True))
    lista.append(("barril", objeto_sobre(tile_tierra(rng), dib_barril, rng), True))
    lista.append(("barril_toxico", objeto_sobre(tile_tierra(rng), dib_barril_toxico, rng), True))
    lista.append(("chatarra", objeto_sobre(tile_tierra(rng), dib_chatarra, rng), True))
    lista.append(("neumaticos", objeto_sobre(tile_tierra(rng), dib_neumaticos, rng), True))
    lista.append(("arbol_muerto", objeto_sobre(tile_tierra(rng), dib_arbol, rng), True))
    lista.append(("cartel", objeto_sobre(tile_tierra(rng), dib_cartel, rng), True))
    lista.append(("fogata", objeto_sobre(tile_arena(rng), dib_fogata, rng), True))
    lista.append(("cama_carton", objeto_sobre(tile_arena(rng), dib_cama_carton, rng, sombra=False), False))
    lista.append(("viga", objeto_sobre(tile_tierra(rng), dib_viga, rng), True))
    lista.append(("valla", objeto_sobre(tile_tierra(rng), dib_valla, rng, sombra=False), True))
    lista.append(("auto_izq", tile_auto(rng, 0), True))
    lista.append(("auto_der", tile_auto(rng, 1), True))
    rojo = (OXIDO[0], OXIDO[1], OXIDO[4])
    azul = (c("3f5f73"), c("2f4757"), c("5f8399"))
    lista.append(("contenedor_rojo_top", tile_contenedor(rng, rojo, True), True))
    lista.append(("contenedor_rojo", tile_contenedor(rng, rojo), True))
    lista.append(("contenedor_azul_top", tile_contenedor(rng, azul, True), True))
    lista.append(("contenedor_azul", tile_contenedor(rng, azul), True))
    lista.append(("porton_izq", tile_porton(rng, 0), True))
    lista.append(("porton_der", tile_porton(rng, 1), True))
    lista.append(("escotilla", tile_escotilla(rng), True))
    lista.append(("escotilla_sellada", tile_escotilla(rng, True), True))
    lista.append(("tierra_oscura", tile_tierra(rng, [TIERRA[2], TIERRA[4], TIERRA[1], TIERRA[0], c("5a3f2c")]), False))
    return armar_atlas(lista, "tiles/exterior.png", TILES_EXT)

def armar_atlas(lista, ruta, registro, columnas=8):
    filas = math.ceil(len(lista) / columnas)
    atlas = nuevo(columnas * T, filas * T)
    for i, (nombre, img, solido) in enumerate(lista):
        col, fila = i % columnas, i // columnas
        atlas.alpha_composite(img, (col * T, fila * T))
        registro[nombre] = [col, fila, solido]
    guardar(atlas, ruta)

# ---------------------------------------------------------------------------
# TILES DEL INTERIOR (Refugio Cero)
# ---------------------------------------------------------------------------
def generar_tiles_interior():
    rng = random.Random(7)
    lista = []
    def piso(variante):
        t = nuevo(T, T, METAL[1])
        d = ImageDraw.Draw(t)
        d.rectangle((0, 0, T - 1, T - 1), outline=METAL[3])
        d.line((1, 1, T - 2, 1), METAL[0])
        for (x, y) in ((2, 2), (13, 2), (2, 13), (13, 13)):
            d.point((x, y), METAL[4])
        if variante:
            d.line((4, 6, 11, 6), METAL[3])
            d.line((4, 9, 11, 9), METAL[3])
        ruido(t, (1, 1, T - 1, T - 1), [METAL[3]], 0.04, rng)
        return t
    lista.append(("piso_1", piso(False), False))
    lista.append(("piso_2", piso(True), False))
    t = nuevo(T, T, METAL[3])
    ImageDraw.Draw(t).line((0, T - 1, T, T - 1), METAL[2])
    ruido(t, (0, 0, T, T), [c("262b31")], 0.15, rng)
    lista.append(("pared_top", t, True))
    t = nuevo(T, T, METAL[0])
    d = ImageDraw.Draw(t)
    d.rectangle((0, 0, T - 1, 2), METAL[4])
    d.line((0, T - 1, T, T - 1), METAL[3])
    d.line((0, 3, T, 3), METAL[3])
    for x in (2, 13):
        d.point((x, 6), METAL[4])
        d.point((x, 12), METAL[4])
    ruido(t, (0, 4, T, T - 1), [OXIDO[1]], 0.03, rng)
    lista.append(("pared", t, True))

    def mueble(nombre, dibujar, solido=True):
        lista.append((nombre, objeto_sobre(piso(False), dibujar, rng, sombra=False), solido))
    def cama_top(d, img, rng):
        d.rectangle((2, 3, 13, 15), MADERA[1])
        d.rectangle((3, 4, 12, 15), c("cfcabb"))
        d.rectangle((4, 5, 11, 9), c("e8e4d8"))  # almohada
    def cama_bot(d, img, rng):
        d.rectangle((2, 0, 13, 12), MADERA[1])
        d.rectangle((3, 0, 12, 11), c("5f7a8c"))  # manta
        d.line((3, 4, 12, 4), c("4b6272"))
        d.line((2, 12, 13, 12), MADERA[0])
    def mesa_izq(d, img, rng):
        d.rectangle((1, 4, 15, 11), MADERA[0])
        d.line((1, 4, 15, 4), MADERA[2])
        d.line((2, 11, 2, 15), MADERA[1])
    def mesa_der(d, img, rng):
        d.rectangle((0, 4, 14, 11), MADERA[0])
        d.line((0, 4, 14, 4), MADERA[2])
        d.line((13, 11, 13, 15), MADERA[1])
        d.rectangle((4, 6, 9, 9), c("3c8f3c"))  # tapete/mapa
    def casillero(d, img, rng):
        d.rectangle((2, 0, 13, 15), METAL[0])
        d.line((7, 1, 7, 14), METAL[3])
        for y in (2, 4):
            d.line((3, y, 6, y), METAL[3])
            d.line((9, y, 12, y), METAL[3])
    def generador(d, img, rng):
        d.rectangle((1, 3, 14, 14), c("4a5a3a"))
        d.rectangle((3, 5, 8, 10), METAL[3])
        d.point((11, 6), c("ff4040"))
        d.point((11, 8), TOXICO[0])
        d.line((3, 12, 12, 12), METAL[3])
    def estante(d, img, rng):
        d.rectangle((1, 1, 14, 14), MADERA[1])
        for y in (5, 10):
            d.line((2, y, 13, y), MADERA[2])
        d.rectangle((3, 2, 5, 4), c("8c3a3a"))
        d.rectangle((7, 7, 10, 9), c("c9a227"))
        d.rectangle((3, 11, 6, 13), METAL[2])
    def escalera(d, img, rng):
        d.line((4, 0, 4, 15), METAL[2])
        d.line((11, 0, 11, 15), METAL[2])
        for y in range(2, 16, 3):
            d.line((4, y, 11, y), METAL[4])
    def caja(d, img, rng):
        d.rectangle((2, 4, 13, 14), MADERA[0])
        d.line((2, 4, 13, 14), MADERA[1])
        d.line((2, 9, 13, 9), MADERA[1])
    def alfombra(d, img, rng):
        d.rectangle((0, 2, 15, 13), c("6b2f2f"))
        d.rectangle((2, 4, 13, 11), c("8c4040"))
        d.rectangle((5, 6, 10, 9), c("c9a227"))
    mueble("cama_top", cama_top)
    mueble("cama_bot", cama_bot)
    mueble("mesa_izq", mesa_izq)
    mueble("mesa_der", mesa_der)
    mueble("casillero", casillero)
    mueble("generador", generador)
    mueble("estante", estante)
    mueble("escalera", escalera)
    mueble("caja", caja)
    mueble("alfombra", alfombra, solido=False)
    armar_atlas(lista, "tiles/interior.png", TILES_INT)

# ---------------------------------------------------------------------------
# OBJETOS SUELTOS (se recogen en el Refugio Cero)
# ---------------------------------------------------------------------------
def generar_objetos():
    def item(dibujar, nombre):
        img = nuevo(T, T)
        dibujar(ImageDraw.Draw(img))
        sombrear(img)
        contorno(img)
        guardar(img, f"objetos/{nombre}.png")
    item(lambda d: (d.rounded_rectangle((3, 4, 12, 14), 2, c("7a4e2a")), d.rectangle((4, 2, 11, 6), c("5e3a1e")),
                    d.rectangle((5, 8, 10, 11), c("94643a")), d.point((7, 9), c("c9a227"))), "mochila")
    item(lambda d: (d.rectangle((2, 5, 7, 12), c("f4e9c8")), d.rectangle((5, 4, 10, 11), c("f4e9c8")),
                    d.rectangle((8, 3, 13, 10), c("f4e9c8")), d.rectangle((9, 5, 12, 8), c("7fd6e6"))), "cartas")
    item(lambda d: (d.ellipse((4, 6, 11, 13), c("4f5a3a")), d.rectangle((6, 3, 9, 6), METAL[2]),
                    d.line((9, 4, 12, 2), METAL[4])), "granada")
    item(lambda d: (d.arc((3, 1, 12, 10), 200, 340, c("c9c9d1")), d.polygon([(5, 8), (6, 6), (7, 8), (9, 8), (10, 6), (11, 8), (11, 13), (5, 13)], c("b8b8c4")),
                    d.point((8, 11), c("9b4fd1")), d.point((7, 11), c("c07ae6"))), "collar")
    item(lambda d: (d.polygon([(2, 12), (5, 7), (9, 5), (13, 8), (14, 12)], OXIDO[1]), d.rectangle((6, 8, 9, 11), METAL[2]),
                    d.line((10, 7, 13, 10), OXIDO[4])), "saqueo")

# ---------------------------------------------------------------------------
# PERSONAJES (Pan es simétrico de frente: se dibuja la mitad y se espeja)
# ---------------------------------------------------------------------------
PIEL = c("d29a6a"); PIEL_S = c("a8714a")
PELO = c("17171f"); PELO_AZUL = c("34508a")
CHAQ = c("2a2a33"); CHAQ2 = c("3a3a46"); PANT = c("22222a"); BOTA = c("3a2a20")
OJO = c("3ee07a"); OJO2 = c("1a7a40"); MOCH = c("7a4e2a"); MOCH2 = c("5a3820")
PLATA = c("c9c9d1"); PERLA = c("a35ae0"); ORO = c("e6c34a")

# ---------------------------------------------------------------- Pan en el mapa (16x24)
def pan_frente(paso, de_espaldas=False):
    img = nuevo(16, 24); d = ImageDraw.Draw(img)
    # (solo la mitad izquierda, x 0..7; luego se espeja)
    d.rectangle((4, 18, 6, 21), PANT)              # pierna
    d.rectangle((4, 22, 6, 23), BOTA)
    d.rectangle((3, 11, 7, 17), CHAQ)              # torso
    d.rectangle((2, 12, 2, 16), CHAQ2)             # brazo
    d.point((2, 17), PIEL)                         # mano
    d.line((3, 17, 7, 17), c("4a4a56"))            # cinturón
    if de_espaldas:
        d.rectangle((4, 11, 7, 17), MOCH)          # mochila
        d.line((4, 13, 7, 13), MOCH2)
        d.rectangle((3, 1, 7, 10), PELO)
        d.line((4, 2, 6, 2), PELO_AZUL)
        d.point((3, 10), PELO)
    else:
        d.line((4, 11, 4, 16), MOCH)               # tirante de la mochila
        d.rectangle((4, 3, 7, 10), PIEL)           # cara
        d.rectangle((3, 1, 7, 4), PELO)            # pelo
        d.point((3, 5), PELO); d.point((3, 6), PELO); d.point((3, 7), PELO)
        d.point((5, 5), PELO)                      # flequillo en puntas
        d.line((5, 2, 6, 2), PELO_AZUL)            # reflejo azul
        d.point((5, 7), OJO); d.point((5, 8), OJO2)  # ojo
        d.point((7, 11), PLATA)                    # collar
        d.point((7, 12), PERLA)
    espejar(img)
    d = ImageDraw.Draw(img)
    if not de_espaldas:
        d.point((12, 8), ORO)                      # aro de mariposa (oreja izquierda de Pan)
    # paso: una pierna sube
    if paso == 1:
        d.rectangle((4, 21, 6, 23), (0, 0, 0, 0)); d.rectangle((4, 21, 6, 22), BOTA)
    elif paso == 2:
        d.rectangle((9, 21, 11, 23), (0, 0, 0, 0)); d.rectangle((9, 21, 11, 22), BOTA)
    luz_lateral(img); contorno_suave(img)
    return img

def pan_lado(paso):
    """Mirando a la DERECHA (la izquierda se obtiene espejando)."""
    img = nuevo(16, 24); d = ImageDraw.Draw(img)
    zancada = {0: 0, 1: 2, 2: -2}[paso]
    d.rectangle((6 - zancada // 2, 18, 8 - zancada // 2, 21), PANT)   # pierna de atrás
    d.rectangle((6 - zancada // 2, 22, 8 - zancada // 2, 23), BOTA)
    d.rectangle((3, 11, 6, 17), MOCH)                                 # mochila
    d.line((3, 13, 6, 13), MOCH2)
    d.rectangle((6, 11, 10, 17), CHAQ)                                # torso
    d.line((6, 17, 10, 17), c("4a4a56"))
    d.rectangle((7 + zancada // 2, 18, 9 + zancada // 2, 21), CHAQ2)  # pierna de adelante
    d.rectangle((7 + zancada // 2, 22, 10 + zancada // 2, 23), BOTA)
    d.rectangle((8 - zancada // 2, 12, 9 - zancada // 2, 16), CHAQ2)  # brazo
    d.point((9 - zancada // 2, 17), PIEL)
    d.rectangle((5, 3, 11, 10), PIEL)                                 # cara
    d.rectangle((4, 1, 10, 4), PELO)
    d.rectangle((4, 4, 7, 9), PELO)
    d.point((11, 2), PELO); d.point((9, 5), PELO)
    d.line((6, 2, 8, 2), PELO_AZUL)
    d.point((10, 7), OJO); d.point((10, 8), OJO2)
    d.point((11, 11), PLATA)
    luz_lateral(img); contorno_suave(img)
    return img

def generar_pan_mapa():
    hoja = nuevo(48, 96)
    for paso in range(3):
        hoja.alpha_composite(pan_frente(paso), (paso * 16, 0))
        der = pan_lado(paso)
        hoja.alpha_composite(der.transpose(Image.FLIP_LEFT_RIGHT), (paso * 16, 24))
        hoja.alpha_composite(der, (paso * 16, 48))
        hoja.alpha_composite(pan_frente(paso, True), (paso * 16, 72))
    return hoja

# ---------------------------------------------------------------- figura grande (32x48) de frente
def figura(piel, pelo, peinado, torso, torso2, piernas, botas, ojos=OJO, pose="abajo", extra=None, despues=None):
    img = nuevo(32, 48); d = ImageDraw.Draw(img)
    # piernas
    d.rectangle((10, 32, 14, 43), piernas)
    d.rectangle((9, 44, 14, 47), botas)
    # torso
    d.polygon([(8, 17), (15, 16), (15, 32), (9, 32)], torso)
    d.rectangle((9, 30, 15, 32), torso2)               # cinturón / cadera
    # brazos
    if pose == "abajo":
        d.rectangle((5, 18, 8, 29), torso2)
        d.rectangle((5, 30, 7, 32), piel)
    elif pose == "cruzados":
        d.rectangle((6, 18, 8, 22), torso2)
        d.rectangle((7, 22, 15, 26), torso2)
        d.rectangle((6, 23, 7, 25), piel)
    # cuello y cabeza
    d.rectangle((13, 13, 15, 16), oscurecer(piel, 0.85))
    d.rectangle((10, 4, 15, 14), piel)
    d.rectangle((11, 14, 15, 15), piel)
    # ojos
    d.rectangle((11, 9, 12, 10), (240, 240, 240, 255))
    d.point((12, 9), ojos); d.point((12, 10), oscurecer(ojos, 0.6))
    d.line((14, 13, 15, 13), oscurecer(piel, 0.7))      # boca
    # pelo
    if peinado == "pan":
        d.rectangle((9, 1, 15, 5), pelo)
        d.rectangle((9, 5, 9, 11), pelo)
        d.polygon([(10, 5), (13, 5), (11, 8)], pelo)   # mechones en punta
        d.point((14, 6), pelo)
        d.line((11, 2, 14, 2), PELO_AZUL)
    elif peinado == "corto":
        d.rectangle((9, 2, 15, 5), pelo)
        d.rectangle((9, 5, 9, 8), pelo)
    elif peinado == "largo":
        d.rectangle((9, 1, 15, 5), pelo)
        d.rectangle((8, 5, 9, 22), pelo)
        d.rectangle((10, 5, 11, 6), pelo)
    elif peinado == "calvo":
        pass
    if extra:
        extra(d)
    espejar(img)
    d = ImageDraw.Draw(img)
    if despues:
        despues(d)
    luz_lateral(img); contorno_suave(img)
    return img

def pan_combate():
    """Pan en combate (32x48): de frente, brazos cruzados, serio. Simétrico salvo el aro."""
    img = nuevo(32, 48); d = ImageDraw.Draw(img)
    PS = oscurecer(PIEL, 0.8)
    # piernas (cargo negro con bolsillo) y botas
    d.rectangle((9, 32, 14, 43), PANT); d.rectangle((9, 36, 10, 39), CHAQ2)
    d.rectangle((8, 44, 14, 47), BOTA); d.line((8, 44, 14, 44), oscurecer(BOTA, 1.3))
    # torso con chaqueta negra, tirantes de la mochila y cinturón
    d.polygon([(6, 19), (12, 18), (15, 18), (15, 32), (8, 32), (7, 26)], CHAQ)
    d.line((9, 32, 15, 32), c("4a4a56"))
    d.line((10, 19, 10, 30), MOCH)
    # brazos cruzados
    d.rectangle((4, 19, 7, 27), CHAQ2)
    d.rectangle((6, 24, 15, 27), oscurecer(CHAQ2, 0.85)); d.line((6, 24, 15, 24), CHAQ2)
    d.rectangle((5, 26, 7, 27), PIEL)
    # cuello y cara (mandíbula en punta suave)
    d.rectangle((13, 16, 15, 18), PS)
    for y, x in {7: 10, 8: 10, 9: 10, 10: 10, 11: 10, 12: 10, 13: 11, 14: 12, 15: 13, 16: 14}.items():
        d.line((x, y, 15, y), PIEL)
    d.rectangle((9, 10, 9, 12), PS)                                    # oreja
    d.line((10, 13, 11, 14), PS)                                       # pómulo
    # ojo verde con brillo y pestaña
    d.line((11, 11, 13, 11), c("ece8e4")); d.rectangle((12, 10, 13, 11), OJO)
    d.point((13, 11), OJO2); d.point((12, 10), c("c8ffd8"))
    d.line((11, 9, 13, 9), PELO)                                       # ceño
    d.line((14, 14, 15, 14), oscurecer(PIEL, 0.6))                     # boca seria
    d.point((15, 12), PS)                                              # nariz
    # pelo estilo Nightwing con flequillo en puntas
    d.line((12, 2, 15, 2), PELO); d.line((10, 3, 15, 3), PELO)
    d.rectangle((9, 4, 15, 6), PELO)
    d.rectangle((9, 7, 9, 13), PELO); d.line((10, 7, 10, 9), PELO)
    d.polygon([(11, 7), (13, 7), (12, 9)], PELO)
    d.polygon([(14, 7), (15, 7), (15, 9)], PELO)
    d.line((11, 3, 13, 3), PELO_AZUL); d.point((10, 4), PELO_AZUL)
    # collar del gato con la perla morada
    d.point((14, 19), PLATA); d.point((15, 20), PLATA); d.rectangle((15, 21, 15, 22), PERLA)
    espejar(img)
    d = ImageDraw.Draw(img)
    d.point((22, 12), ORO); d.point((22, 13), c("fff0a0"))            # aro de mariposa
    d.polygon([(16, 7), (18, 7), (17, 10)], PELO)                      # mechón que cae entre los ojos
    luz_lateral(img); contorno_suave(img)
    return img

def recluta_combate():
    def extra(d):
        d.rectangle((10, 11, 15, 15), c("8c2f2f"))   # pañuelo
        d.line((9, 24, 15, 24), METAL[2])            # correa
        d.rectangle((8, 17, 10, 20), METAL[0])       # hombrera
        d.point((11, 19), METAL[4])
    return figura(c("b88458"), c("4a3a2a"), "corto", OXIDO[0], OXIDO[1], c("3a3328"), c("2a2018"), ojos=c("3a2a1a"), extra=extra)


# ---------------------------------------------------------------- otras personas en el mapa (16x24, de frente)
def persona_frente(piel, pelo, peinado, ropa, ropa2, pantalon, bota, ojo=c("2a2018"), extra=None, despues=None, encorvado=False):
    img = nuevo(16, 24); d = ImageDraw.Draw(img)
    dy = 1 if encorvado else 0
    d.rectangle((4, 18, 6, 21), pantalon)
    d.rectangle((4, 22, 6, 23), bota)
    d.rectangle((3, 11 + dy, 7, 17), ropa)
    d.rectangle((2, 12 + dy, 2, 16 + dy), ropa2)
    d.point((2, 17 + dy), piel)
    d.line((3, 17, 7, 17), ropa2)
    d.rectangle((4, 3 + dy, 7, 10 + dy), piel)
    if peinado == "corto":
        d.rectangle((3, 1 + dy, 7, 3 + dy), pelo); d.point((3, 4 + dy), pelo)
    elif peinado == "largo":
        d.rectangle((3, 1 + dy, 7, 3 + dy), pelo); d.rectangle((3, 4 + dy, 3, 12 + dy), pelo)
    elif peinado == "capucha":
        d.rectangle((3, 1 + dy, 7, 3 + dy), pelo); d.rectangle((3, 4 + dy, 3, 10 + dy), pelo); d.point((4, 4 + dy), pelo)
    d.point((5, 7 + dy), ojo)
    if extra:
        extra(d, dy)
    espejar(img)
    d = ImageDraw.Draw(img)
    if despues:
        despues(d, dy)
    luz_lateral(img); contorno_suave(img)
    return img

def recluta_mapa():
    def extra(d, dy):
        d.rectangle((4, 8, 7, 10), c("8c2f2f"))        # pañuelo
        d.line((3, 13, 7, 13), METAL[2])               # correa
        d.point((3, 11), METAL[3])                     # hombrera
    return persona_frente(c("b88458"), c("4a3a2a"), "corto", OXIDO[0], OXIDO[1], c("3a3328"), c("2a2018"), extra=extra)

def ciudadano_mapa():
    def extra(d, dy):
        d.point((4, 14), c("4a4238")); d.point((6, 12), c("4a4238"))   # hollín
        d.point((5, 9 + dy), c("8a6a52"))                               # cara cansada
    return persona_frente(c("c08a60"), c("5a5246"), "capucha", c("6b6458"), c("4e483f"), c("3e3a33"), c("2a2620"), extra=extra, encorvado=True)

# ---------------------------------------------------------------- retratos 48x48 (cara simétrica + detalles)
R = 48
# borde izquierdo de la cara en cada fila (la mitad derecha se espeja)
CARA_L = {12: 16, 13: 15, 14: 14, 15: 14}
for _y in range(16, 28):
    CARA_L[_y] = 13
CARA_L.update({28: 14, 29: 14, 30: 15, 31: 16, 32: 17, 33: 18, 34: 19, 35: 21})

def mitad(d, y, x0, col):
    d.line((x0, y, 23, y), col)

def cara_base(d, piel, quijada=0, delgada=0):
    """Dibuja (mitad izquierda) cabeza, orejas, cuello y sombreado de la piel."""
    sombra = oscurecer(piel, 0.8); sombra2 = oscurecer(piel, 0.66); luz = tuple(min(255, int(v * 1.08)) for v in piel[:3]) + (255,)
    d.rectangle((18, 34, 23, 41), sombra)                          # cuello
    d.rectangle((18, 34, 23, 36), sombra2)                         # sombra de la barbilla
    for y, x in CARA_L.items():
        x2 = x + delgada if 16 <= y <= 29 else x
        if y >= 28:
            x2 = max(x2 - quijada, 13)
        mitad(d, y, x2, piel)
        d.point((x2, y), sombra)                                   # borde
    d.rectangle((11, 20, 13, 26), piel); d.point((11, 20), sombra); d.line((12, 22, 12, 25), sombra)   # oreja
    for y in range(17, 26):
        d.point((15 + delgada, y), luz) if y < 20 else None
    d.line((15 + delgada, 28, 17, 30), sombra)                     # pómulo
    d.line((20, 20, 23, 20), luz)                                  # frente con luz

def ojo(d, iris, x=16, y=22, lineal=c("1a1418"), blanco=c("ece8e4"), pupila=None, abierto=1):
    d.rectangle((x, y + 1, x + 5, y + 2 + abierto - 1), blanco)
    d.rectangle((x + 2, y, x + 4, y + 2 + abierto), iris)
    d.line((x + 2, y + 2 + abierto, x + 4, y + 2 + abierto), oscurecer(iris, 0.6))
    d.rectangle((x + 3, y + 1, x + 3, y + 1 + abierto), pupila or oscurecer(iris, 0.3))
    d.point((x + 2, y), c("ffffff"))                               # brillo
    d.line((x, y, x + 5, y - 1), lineal)                           # párpado / pestaña
    d.point((x - 1, y + 1), lineal)

def ceja(d, col, forma="recta", y=19):
    if forma == "recta":
        d.line((15, y, 21, y), col); d.line((16, y - 1, 20, y - 1), col)
    elif forma == "enojo":   # baja hacia el centro
        d.line((15, y - 2, 21, y), col); d.line((16, y - 2, 21, y - 1), col)
    elif forma == "triste":  # sube hacia el centro
        d.line((15, y, 21, y - 2), col); d.line((16, y, 20, y - 2), col)
    elif forma == "fina":
        d.line((15, y, 21, y - 1), col)

def nariz(d, piel):
    s = oscurecer(piel, 0.74)
    d.line((22, 25, 22, 29), s); d.point((21, 30), s); d.point((22, 30), oscurecer(piel, 0.55))
    d.point((23, 29), tuple(min(255, int(v * 1.1)) for v in piel[:3]) + (255,))

def boca(d, piel, forma="seria", y=32):
    s = oscurecer(piel, 0.55); labio = oscurecer(piel, 0.85)
    if forma == "seria":
        d.line((20, y, 23, y), s); d.line((21, y + 1, 23, y + 1), labio)
    elif forma == "sonrisa":
        d.point((19, y - 1), s); d.line((20, y, 23, y), s); d.line((21, y + 1, 23, y + 1), labio)
    elif forma == "triste":
        d.point((19, y + 1), s); d.line((20, y, 23, y), s)
    elif forma == "dientes":
        d.rectangle((19, y - 1, 23, y + 1), c("2a1414")); d.line((20, y - 1, 23, y - 1), c("f0ece0"))
        d.point((19, y - 2), s)

def hombros(d, ropa, ropa2, cuello=None):
    d.polygon([(0, 47), (2, 42), (8, 39), (17, 38), (23, 39), (23, 47)], ropa)
    d.line((2, 42, 8, 39), oscurecer(ropa, 1.25) if False else tuple(min(255, int(v * 1.25)) for v in ropa[:3]) + (255,))
    d.line((17, 39, 17, 47), ropa2)
    if cuello:
        d.polygon([(16, 38), (18, 36), (23, 40), (23, 44)], cuello)

def retrato48(fondo, piel, dibujar_mitad, despues=None, fondo2=None, solo_figura=False):
    fig = nuevo(R, R); d = ImageDraw.Draw(fig)
    dibujar_mitad(d)
    espejar(fig)
    d = ImageDraw.Draw(fig)
    if despues:
        despues(d)
    contorno_suave(fig)
    if solo_figura:
        return fig
    img = nuevo(R, R)
    gradiente(img, (0, 0, R, R), [fondo, fondo2 or oscurecer(fondo, 0.55)])
    img.alpha_composite(fig)
    return img

# ---------------------------------------------------------------- PAN
PIEL_PAN = c("c98f62")
def retrato_pan48(solo_figura=False):
    piel = PIEL_PAN
    def m(d):
        hombros(d, c("26262e"), c("1a1a20"))
        d.line((13, 40, 15, 47), MOCH)                                         # tirante de la mochila
        cara_base(d, piel, delgada=1)
        ojo(d, OJO, x=16, y=23)
        d.point((16, 25), oscurecer(piel, 0.8))                               # ojera leve (madurez)
        ceja(d, PELO, "recta", y=20)
        nariz(d, piel)
        boca(d, piel, "seria")
        # pelo estilo Nightwing: negro profundo, masa llena y flequillo en puntas sobre la frente
        d.polygon([(10, 27), (9, 16), (11, 10), (15, 6), (20, 4), (23, 4), (23, 13), (12, 13), (12, 28)], PELO)
        d.polygon([(11, 12), (14, 13), (13, 23), (11, 25)], PELO)             # mechón que tapa la sien
        d.polygon([(13, 12), (18, 12), (15, 19)], PELO)                       # puntas del flequillo
        d.polygon([(17, 12), (22, 12), (20, 18)], PELO)
        d.polygon([(21, 12), (23, 12), (23, 16)], PELO)
        d.line((12, 11, 15, 8), PELO_AZUL); d.line((15, 8, 19, 6), PELO_AZUL)  # reflejo azul marino
        d.point((16, 12), PELO_AZUL); d.point((20, 12), PELO_AZUL)
        d.line((10, 27, 10, 31), PELO)                                        # nuca / patilla
    def despues(d):
        d.polygon([(23, 13), (28, 12), (25, 20)], PELO)                       # mechón asimétrico que cae entre los ojos
        d.point((36, 25), ORO); d.point((35, 26), ORO); d.point((37, 26), ORO); d.point((36, 27), c("fff0a0"))  # aro de mariposa (oreja izq. de Pan)
        d.line((19, 38, 24, 41), PLATA); d.line((28, 38, 24, 41), PLATA)       # collar
        d.rectangle((23, 41, 25, 43), c("b8b8c4")); d.point((24, 42), PERLA); d.point((23, 41), c("e8e8f0"))  # gatito con perla
    return retrato48(c("2a3048"), piel, m, despues, c("14141e"), solo_figura)

# ---------------------------------------------------------------- COMANDANTES
def retrato_rictus():
    piel = c("b07a50")
    def m(d):
        hombros(d, OXIDO[1], OXIDO[3])
        d.polygon([(0, 44), (3, 39), (12, 38), (14, 42), (6, 47), (0, 47)], METAL[1])      # hombrera de chatarra
        d.line((3, 39, 12, 38), METAL[4])
        d.point((6, 42), METAL[4]); d.point((10, 41), METAL[4])                           # remaches
        cara_base(d, piel, quijada=1)
        ojo(d, c("8a5a2a"), x=16, y=23)
        ceja(d, c("3a2a1a"), "enojo", y=21)
        nariz(d, piel)
        for (x, y) in ((16, 31), (18, 33), (20, 34), (17, 29), (15, 30)):
            d.point((x, y), oscurecer(piel, 0.7))                                         # barba de días
        boca(d, piel, "dientes", y=32)
        d.rectangle((20, 4, 23, 13), c("8c2f2f"))                                         # cresta (mohicano) roja
        d.line((21, 3, 23, 3), c("8c2f2f")); d.line((21, 5, 21, 12), c("b04040"))
        d.rectangle((13, 13, 23, 16), oscurecer(piel, 0.9))                               # cabeza rapada
    def despues(d):
        d.line((30, 18, 33, 28), c("e0b090")); d.line((31, 18, 34, 28), c("8a4a30"))     # cicatriz
        d.rectangle((26, 30, 27, 31), c("e6c34a"))                                        # diente de oro
        d.polygon([(27, 22), (34, 21), (34, 26), (27, 26)], c("2a2a2a"))                  # parche con remache
        d.point((30, 23), METAL[4])
    return retrato48(c("5a2e1e"), piel, m, despues)

def retrato_vesper():
    piel = c("d8c0a8")
    def m(d):
        hombros(d, c("d8dcd0"), c("a8ae9e"), cuello=c("eef0e8"))                         # bata de laboratorio
        d.point((10, 43), TOXICO[1]); d.point((12, 45), TOXICO[0]); d.point((6, 46), TOXICO[1])   # manchas tóxicas
        cara_base(d, piel, delgada=1)
        d.ellipse((14, 21, 21, 27), c("2a3a2a"))                                          # gafas redondas
        d.ellipse((15, 22, 20, 26), c("6aff8a"))
        d.point((16, 23), c("e0ffe8"))
        d.line((21, 24, 23, 24), c("2a3a2a"))
        nariz(d, piel)
        boca(d, piel, "sonrisa")
        d.point((22, 32), c("6a2a4a")); d.point((23, 32), c("6a2a4a"))                    # labios oscuros
        d.polygon([(11, 24), (11, 13), (15, 9), (23, 8), (23, 14), (16, 15), (13, 19), (12, 26)], c("2a3a30"))   # pelo tirante
        d.ellipse((17, 1, 23, 8), c("2a3a30"))                                            # moño
        d.line((14, 11, 20, 9), c("4a6a50"))
        d.polygon([(12, 41), (17, 38), (23, 39), (23, 44), (16, 44)], c("3a4a3a"))       # máscara de gas colgando
        d.ellipse((13, 41, 17, 45), c("5a6a50"))
    def despues(d):
        d.line((22, 3, 27, 1), c("c9c9d1"))                                               # aguja en el moño
        d.point((33, 36), TOXICO[2])
    return retrato48(c("1e3a2a"), piel, m, despues)

def retrato_silas():
    piel = c("e2b496")
    def m(d):
        hombros(d, c("3a1a4a"), c("2a1036"), cuello=c("ff4ad8"))                         # cuello alto neón
        d.polygon([(4, 47), (6, 38), (12, 34), (14, 40), (10, 47)], c("4a2060"))         # capa alta
        cara_base(d, piel, delgada=1)
        ojo(d, c("c070ff"), x=16, y=23)
        d.line((15, 23, 21, 22), c("1a0a1a")); d.point((14, 23), c("1a0a1a"))            # delineado
        ceja(d, c("5a1a6a"), "fina", y=20)
        nariz(d, piel)
        boca(d, piel, "sonrisa")
        d.point((22, 32), c("a03a6a"))
        # copete teatral morado
        d.polygon([(11, 22), (11, 12), (15, 6), (21, 2), (23, 2), (23, 11), (16, 13), (13, 18)], c("6a2a9a"))
        d.line((14, 8, 21, 3), c("ff4ad8")); d.line((12, 13, 15, 9), c("c070ff"))
    def despues(d):
        # media máscara de neón sobre el ojo derecho (izquierda del dibujo es su derecho: ponemos a un lado)
        d.polygon([(25, 20), (35, 19), (36, 24), (33, 28), (26, 27)], c("1a1a2a"))
        d.line((25, 20, 35, 19), c("3af0ff")); d.line((36, 24, 33, 28), c("3af0ff"))
        d.rectangle((29, 23, 31, 24), c("3af0ff")); d.point((30, 23), c("e0ffff"))
        d.polygon([(30, 2), (37, 6), (33, 7)], c("6a2a9a"))                               # mechón que sale
    return retrato48(c("2a0f3a"), piel, m, despues, c("0a1a3a"))

def retrato_kael():
    piel = c("b8865e")
    def m(d):
        hombros(d, c("5a5650"), c("3e3a36"))
        d.polygon([(2, 47), (4, 40), (12, 38), (16, 47)], c("6e6a62"))                   # peto gastado
        d.line((6, 41, 12, 46), c("2a2826"))                                              # escudo roto (grieta)
        d.line((9, 40, 8, 44), c("2a2826"))
        cara_base(d, piel, quijada=1)
        ojo(d, c("6a7a8a"), x=16, y=23)
        d.line((16, 26, 21, 26), oscurecer(piel, 0.72))                                   # ojeras: cansancio
        ceja(d, c("4a4440"), "triste", y=21)
        nariz(d, piel)
        # barba gris descuidada
        d.polygon([(14, 28), (17, 33), (20, 36), (23, 37), (23, 33), (19, 32), (16, 29)], c("6a645e"))
        d.point((16, 31), c("8a847e")); d.point((19, 34), c("8a847e"))
        boca(d, piel, "triste", y=32)
        d.polygon([(11, 24), (11, 13), (15, 8), (23, 7), (23, 12), (17, 13), (14, 16), (13, 21)], c("4a4440"))   # pelo con canas
        d.line((13, 12, 17, 9), c("9a948c")); d.point((12, 18), c("9a948c"))
    def despues(d):
        d.line((27, 14, 30, 19), c("8a5a40"))                                             # cicatriz en la frente
    return retrato48(c("3a3634"), piel, m, despues)

def retrato_valera():
    piel = c("c89a7a")
    def m(d):
        hombros(d, c("1e2228"), c("12151a"), cuello=c("2a2f38"))                         # uniforme negro
        d.rectangle((6, 41, 9, 43), c("8c1a1a")); d.point((7, 42), c("e6c34a"))          # insignia
        cara_base(d, piel, delgada=1)
        ojo(d, c("8aa0b0"), x=16, y=23, abierto=1)
        ceja(d, c("c8c0b0"), "recta", y=21)
        nariz(d, piel)
        boca(d, piel, "seria")
        # gorra militar
        d.polygon([(11, 17), (12, 10), (17, 6), (23, 5), (23, 17)], c("1e2228"))
        d.polygon([(11, 17), (23, 17), (23, 20), (13, 20)], c("12151a"))                  # visera
        d.line((14, 9, 20, 6), c("3a404a"))
        d.rectangle((12, 18, 12, 22), c("d8d0c0"))                                        # pelo platinado corto
    def despues(d):
        d.polygon([(22, 9), (25, 8), (26, 12), (23, 13)], c("8c1a1a")); d.point((24, 10), c("e6c34a"))   # emblema de la gorra
        d.line((30, 21, 33, 30), c("e8c0a8"))                                             # cicatriz sobre el ojo
    return retrato48(c("1a2230"), piel, m, despues)

def retrato_marcus():
    piel = c("e0b498")
    def m(d):
        hombros(d, c("f2efe8"), c("cfc8bb"), cuello=c("ffffff"))                         # traje blanco impecable
        d.polygon([(14, 39), (18, 38), (23, 46), (23, 47), (19, 47)], c("d6d0c4"))        # solapa
        d.line((23, 40, 23, 47), c("8a1a1a"))                                             # corbata
        cara_base(d, piel, delgada=0)
        ojo(d, c("7ab8e0"), x=16, y=23)
        ceja(d, c("b8a888"), "recta", y=20)
        nariz(d, piel)
        boca(d, piel, "sonrisa")
        # pelo peinado hacia atrás, plateado
        d.polygon([(11, 22), (11, 13), (14, 8), (19, 5), (23, 5), (23, 10), (17, 11), (13, 15), (12, 22)], c("cfc6b0"))
        d.line((13, 12, 19, 7), c("f0ead8")); d.line((15, 13, 21, 9), c("a89e88"))
    def despues(d):
        d.point((35, 40), c("e6c34a")); d.point((36, 41), c("e6c34a")); d.point((34, 41), c("e6c34a"))   # broche dorado
        d.line((24, 40, 24, 47), c("8a1a1a"))
    return retrato48(c("e8dcc0"), piel, m, despues, c("9a8a6a"))

def retrato_papa48():
    piel = c("c48a5e")
    def m(d):
        hombros(d, c("4a5a4a"), c("3a4a3a"))
        cara_base(d, piel, quijada=1)
        ojo(d, c("5a3a22"), x=16, y=23)
        ceja(d, c("2a201c"), "recta", y=20)
        nariz(d, piel)
        d.polygon([(14, 28), (17, 33), (20, 36), (23, 37), (23, 33), (19, 32), (16, 29)], c("3a2a22"))   # barba corta
        boca(d, piel, "sonrisa")
        d.polygon([(11, 22), (11, 12), (15, 8), (23, 7), (23, 12), (16, 13), (13, 17)], c("2a201c"))
    return retrato48(c("3a3a2a"), piel, m)

def retrato_mama48():
    piel = c("d8a070")
    def m(d):
        hombros(d, c("7a3a3a"), c("5e2c2c"))
        cara_base(d, piel, delgada=1)
        ojo(d, OJO, x=16, y=23)
        d.point((15, 23), c("1a1418"))                                                    # pestañas
        ceja(d, c("3a2418"), "fina", y=20)
        nariz(d, piel)
        boca(d, piel, "sonrisa")
        d.line((21, 33, 23, 33), c("b0605a"))
        d.polygon([(8, 44), (9, 18), (12, 10), (17, 7), (23, 6), (23, 11), (17, 12), (13, 17), (12, 30), (13, 40)], c("3a2418"))  # pelo largo
        d.line((12, 13, 17, 9), c("5a3a28"))
    def despues(d):
        d.point((36, 25), ORO)
    return retrato48(c("3a2a34"), piel, m)

def retrato_recluta48():
    piel = c("b88458")
    def m(d):
        hombros(d, OXIDO[0], OXIDO[1])
        d.polygon([(2, 42), (6, 38), (13, 38), (11, 43)], METAL[1]); d.point((7, 40), METAL[4])
        cara_base(d, piel, quijada=1)
        ojo(d, c("6a4a2a"), x=16, y=23)
        ceja(d, c("4a3a2a"), "enojo", y=21)
        d.polygon([(13, 27), (23, 27), (23, 37), (18, 36), (14, 31)], c("8c2f2f"))        # pañuelo
        d.line((15, 30, 23, 30), c("6a1f1f")); d.point((18, 33), c("6a1f1f"))
        d.polygon([(11, 22), (11, 13), (15, 9), (23, 8), (23, 12), (16, 13), (13, 17)], c("4a3a2a"))
    def despues(d):
        d.line((29, 15, 31, 21), c("e0a080"))
    return retrato48(c("4a2c22"), piel, m, despues)

def retrato_ciudadano48():
    piel = c("c08a60")
    def m(d):
        hombros(d, c("6b6458"), c("4e483f"))
        cara_base(d, piel, delgada=1)
        ojo(d, c("6a5a3a"), x=16, y=24)
        d.line((16, 27, 21, 27), oscurecer(piel, 0.72))
        ceja(d, c("4a4238"), "triste", y=21)
        nariz(d, piel)
        boca(d, piel, "triste")
        d.point((17, 30), c("6a4a30")); d.point((20, 18), c("6a4a30"))                    # hollín
        d.polygon([(4, 47), (6, 22), (10, 10), (16, 5), (23, 4), (23, 9), (15, 11), (12, 17), (11, 30), (13, 38), (10, 47)], c("5a5246"))  # capucha
        d.line((9, 14, 14, 8), c("6e6658"))
    return retrato48(c("3e3832"), piel, m)

TODOS = [("pan", retrato_pan48), ("rictus", retrato_rictus), ("vesper", retrato_vesper), ("silas", retrato_silas),
         ("kael", retrato_kael), ("valera", retrato_valera), ("marcus", retrato_marcus),
         ("papa", retrato_papa48), ("mama", retrato_mama48), ("recluta", retrato_recluta48), ("ciudadano", retrato_ciudadano48)]


def generar_pan():
    guardar(generar_pan_mapa(), "personajes/pan_mapa.png")

def generar_npcs():
    guardar(recluta_mapa(), "personajes/recluta_mapa.png")
    guardar(ciudadano_mapa(), "personajes/ciudadano_mapa.png")

def generar_combate_humanos():
    guardar(pan_combate(), "personajes/pan_combate.png")
    guardar(recluta_combate(), "personajes/recluta_combate.png")

def generar_retratos():
    """Caras de 48x48 (el tamaño exacto del cuadro de diálogo, así no se deforman los píxeles)."""
    for nombre, hacer in TODOS:
        guardar(hacer(), f"retratos/{nombre}.png")

# ---------------------------------------------------------------------------
# CRIATURAS (64x64, para el combate)
# ---------------------------------------------------------------------------
def oscurecer(col, f):
    return (int(col[0] * f), int(col[1] * f), int(col[2] * f), col[3])

def volumen(img, luz=1.18, sombra1=0.62, sombra2=0.8, piso=0.86):
    """Sombreado de pixel art: borde de luz arriba-izquierda, sombra abajo-derecha
    (2 niveles, el segundo tramado) y la parte baja del cuerpo un poco más oscura."""
    w, h = img.size
    src = img.copy()
    px = src.load()
    out = img.load()
    caja = img.getbbox()
    if not caja:
        return img
    y_piso = caja[1] + (caja[3] - caja[1]) * 0.62
    def v(x, y):
        return not (0 <= x < w and 0 <= y < h) or px[x, y][3] == 0
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0:
                continue
            f = 1.0
            if y > y_piso + 2 or (y > y_piso and (x + y) % 2 == 0):
                f = piso
            if v(x, y + 1) or v(x + 1, y) or v(x + 1, y + 1):
                f = sombra1
            elif (v(x, y + 2) or v(x + 2, y)) and (x + y) % 2 == 0:
                f = min(f, sombra2)
            elif v(x, y - 1) or v(x - 1, y):
                f = luz
            out[x, y] = (min(255, int(p[0] * f)), min(255, int(p[1] * f)), min(255, int(p[2] * f)), p[3])
    return img

def contorno_color(img, base=0.32):
    """Contorno del color del vecino pero muy oscuro (más suave que el negro puro);
    abajo se usa casi negro para que la figura "pese" sobre el suelo."""
    w, h = img.size
    src = img.copy()
    px = src.load()
    out = img.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                    f = 0.22 if dy == -1 else base
                    out[x, y] = oscurecer(px[nx, ny], f)[:3] + (255,)
                    break
    return img

def P(d, pts, col):
    d.polygon(pts, col)

def mezclar(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)

def brillo_borde(img, col, grosor=2):
    """Pelo negro con brillo: el borde de arriba/izquierda toma un tono claro (y tramado hacia dentro)."""
    w, h = img.size
    src = img.copy(); px = src.load(); out = img.load()
    def v(x, y):
        return not (0 <= x < w and 0 <= y < h) or px[x, y][3] == 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            if v(x, y - 1) or (v(x - 1, y) and v(x - 1, y - 1)):
                out[x, y] = col
            elif grosor > 1 and (v(x, y - 2) or v(x - 1, y - 1)) and (x + y) % 2 == 0:
                out[x, y] = mezclar(px[x, y], col, 0.5)
    return img

def dibujar_criatura(base, detalles, brillo=None):
    """Todas las criaturas miran a la DERECHA y apoyan las patas en la fila 60-61.
    El juego las voltea cuando son enemigas. Formas angulosas (polígonos), sombreado
    en 2 tonos, brillo en el borde de arriba (pelo) y contorno de color."""
    img = nuevo(64, 64)
    base(ImageDraw.Draw(img), img)
    volumen(img)
    if brillo:
        brillo_borde(img, brillo)
    contorno_color(img)
    detalles(ImageDraw.Draw(img), img)
    return img

def criatura(nombre, base, detalles, brillo=None):
    guardar(dibujar_criatura(base, detalles, brillo), f"criaturas/{nombre}.png")

# ------------------------------------------------------------- GATO MUTADO (negro, con cristales tóxicos)
GN = c("3a3349"); GN2 = c("272233"); GN_B = c("7e6ca6"); GN_PECHO = c("5e5078")
VERDE = c("3ee07a"); VERDE2 = c("1f9a50"); VERDE_L = c("c8ffd8")
def gato_base(d, img):
    # cola alta en S, gruesa y peluda
    P(d, [(15, 41), (10, 37), (6, 30), (6, 22), (9, 15), (13, 10), (18, 8), (21, 10), (18, 13), (14, 17), (12, 23), (12, 30), (15, 35), (20, 38)], GN)
    # patas lejanas
    P(d, [(19, 46), (25, 46), (25, 59), (19, 59)], GN2)
    P(d, [(41, 44), (46, 44), (46, 59), (41, 59)], GN2)
    # cuerpo
    P(d, [(13, 41), (16, 34), (24, 31), (35, 31), (43, 33), (47, 39), (46, 46), (39, 49), (22, 49), (15, 47)], GN)
    # pelo de la panza en mechones
    for x in range(24, 38, 4):
        P(d, [(x, 48), (x + 2, 52), (x + 4, 48)], GN)
    # mechones de la cola
    P(d, [(6, 25), (3, 23), (6, 21)], GN); P(d, [(7, 31), (4, 32), (8, 34)], GN)
    # anca (pata trasera cercana)
    P(d, [(12, 40), (19, 35), (26, 38), (27, 46), (23, 51), (23, 58), (25, 61), (15, 61), (16, 52), (12, 47)], GN)
    # pata delantera cercana
    P(d, [(36, 41), (44, 41), (43, 50), (42, 57), (46, 59), (46, 61), (36, 61), (37, 57), (37, 50)], GN)
    # cabeza grande (proporción tierna)
    P(d, [(36, 23), (39, 16), (46, 12), (55, 12), (61, 17), (62, 25), (59, 32), (52, 35), (43, 35), (37, 31)], GN)
    # mejillas peludas
    P(d, [(38, 28), (34, 32), (39, 32), (37, 35), (43, 35)], GN)
    P(d, [(60, 28), (63, 31), (59, 32)], GN)
    # orejas grandes
    P(d, [(39, 18), (38, 3), (48, 13)], GN)
    P(d, [(52, 12), (59, 2), (62, 19)], GN)

def gato_det(d, img):
    # interior de las orejas: rosa oscuro con brillo tóxico en la punta
    P(d, [(40, 15), (40, 7), (45, 13)], c("6a3a5a"))
    P(d, [(54, 12), (58, 6), (60, 16)], c("6a3a5a"))
    d.point((40, 8), VERDE2); d.point((58, 7), VERDE2)
    # pechera clara y esponjosa
    P(d, [(44, 34), (49, 35), (52, 34), (50, 38), (48, 43), (46, 40), (44, 42), (43, 37)], GN_PECHO)
    d.point((47, 36), GN_B); d.point((49, 37), GN_B)
    # ojos grandes, verdes y brillantes
    for (x, y) in ((42, 20), (52, 19)):
        d.rectangle((x, y, x + 4, y + 4), VERDE)
        d.point((x, y), GN); d.point((x + 4, y + 4), GN)     # forma almendrada
        d.line((x + 1, y + 4, x + 3, y + 4), VERDE2)
        d.line((x + 2, y + 1, x + 2, y + 3), c("0e1a12"))  # pupila rasgada
        d.point((x + 1, y + 1), VERDE_L); d.point((x + 3, y + 1), c("ffffff"))
    d.line((42, 26, 43, 26), c("b06a8a")); d.line((55, 25, 56, 25), c("b06a8a"))  # cachetes rosados
    # nariz y boquita
    P(d, [(57, 26), (60, 26), (58, 28)], c("e07aa0"))
    d.point((58, 29), c("15111b")); d.point((57, 30), c("15111b")); d.point((59, 30), c("15111b"))
    d.point((60, 31), c("15111b"))
    # bigotes
    d.line((60, 28, 63, 27), c("8a84a0")); d.line((60, 30, 63, 31), c("8a84a0"))
    d.line((37, 28, 33, 27), c("6a6480"))
    # mutación: cristales tóxicos que salen del lomo
    for (x, y, h) in ((23, 32, 7), (29, 31, 9), (35, 31, 6)):
        P(d, [(x - 2, y), (x - 1, y - h + 2), (x + 1, y - h), (x + 2, y)], VERDE2)
        d.line((x, y - 1, x, y - h + 2), VERDE)
        d.point((x + 1, y - h + 1), VERDE_L)
    # rayas tóxicas que brillan en el anca y el hombro
    for (x0, y0, x1, y1) in ((16, 41, 19, 39), (16, 44, 20, 42), (17, 47, 21, 45), (38, 44, 41, 43), (38, 47, 41, 46)):
        d.line((x0, y0, x1, y1), VERDE2)
        d.point((x1, y1), VERDE)
    # punta de la cola encendida
    P(d, [(15, 10), (18, 8), (21, 10), (18, 13), (16, 12)], VERDE2)
    d.point((18, 9), VERDE); d.point((19, 10), VERDE_L)
    # garritas y almohadillas
    for x in (16, 19, 22, 37, 40, 43):
        d.point((x, 61), c("d8d0e0"))

# ------------------------------------------------------------- BESTIA BLANCA
BB = c("e4e7ec"); BB2 = c("9aa1ad"); BB_PELO = c("f6f7fa"); BB_PELO2 = c("bfc5cf")
def bestia_base(d, img):
    P(d, [(22, 34), (28, 38), (17, 49), (12, 58), (15, 61), (5, 61), (8, 56), (12, 46)], BB2)          # pierna de atrás
    P(d, [(37, 27), (42, 27), (47, 43), (50, 57), (53, 61), (45, 61), (44, 56), (43, 44)], BB2)       # brazo lejano
    P(d, [(43, 12), (34, 9), (24, 11), (14, 15), (5, 22), (14, 20), (9, 27), (20, 22), (18, 29), (28, 20), (40, 18)], BB_PELO2)  # melena
    P(d, [(19, 37), (23, 28), (31, 22), (40, 19), (46, 23), (43, 31), (35, 38), (26, 42)], BB)        # torso inclinado
    P(d, [(22, 35), (30, 35), (38, 43), (37, 49), (33, 57), (37, 59), (37, 61), (27, 61), (29, 55), (32, 48), (24, 44)], BB)  # pierna doblada
    P(d, [(42, 12), (48, 9), (55, 10), (59, 15), (58, 20), (51, 23), (45, 22), (41, 18)], BB)        # cabeza
    P(d, [(39, 22), (45, 24), (51, 38), (55, 54), (58, 59), (59, 61), (50, 61), (50, 55), (46, 40)], BB)  # brazo largo

def bestia_det(d, img):
    # pelo blanco brillante por encima de la cabeza
    P(d, [(42, 11), (47, 8), (53, 8), (50, 11), (45, 13), (42, 16)], BB_PELO)
    for (x0, y0, x1, y1) in ((32, 11, 18, 16), (26, 13, 10, 21), (34, 15, 20, 21), (28, 18, 16, 25)):
        d.line((x0, y0, x1, y1), BB_PELO)
        d.line((x0, y0 + 1, x1 + 2, y1 + 1), c("a7adb8"))
    # cuenca oscura y ojo blanco que brilla
    d.line((49, 13, 54, 13), c("8a909c"))                      # ceja
    d.rectangle((50, 14, 54, 16), c("2a2f3a"))
    d.line((51, 15, 53, 15), c("ffffff")); d.point((54, 15), c("bfefff")); d.point((52, 14), c("bfefff"))
    # boca con dientes
    d.line((52, 20, 58, 19), c("4a1f2a"))
    d.point((54, 20), c("ffffff")); d.point((56, 20), c("ffffff"))
    # columna y costillas
    for (x, y) in ((25, 30), (29, 26), (33, 23), (37, 21)):
        d.point((x, y), BB2)
    for y in range(29, 38, 3):
        d.line((30, y, 36, y - 2), c("b8bec8"))
    # garras oscuras
    for (x, y) in ((51, 61), (54, 61), (57, 61), (46, 61), (49, 61)):
        d.point((x, y), c("3a3f47"))
    d.line((5, 61, 9, 61), c("3a3f47")); d.line((33, 61, 37, 61), c("3a3f47"))

# ------------------------------------------------------------- AVES NEGRAS
AN = c("23202c"); AN2 = c("3a3550"); AN3 = c("15131b"); AN_B = c("4d5a8c")
def un_ave(d, x, y, arriba, s=1.0):
    def p(pts):
        return [(x + int(a * s), y + int(b * s)) for (a, b) in pts]
    if arriba:   # ala levantada con plumas en sierra
        P(d, p([(-3, 0), (-8, -6), (-12, -12), (-9, -11), (-8, -14), (-5, -11), (-3, -14), (-1, -10), (2, -1)]), AN2)
    else:        # ala hacia abajo
        P(d, p([(-3, 1), (-9, 5), (-13, 9), (-10, 9), (-9, 12), (-6, 9), (-4, 11), (-2, 7), (3, 3)]), AN2)
    P(d, p([(-8, 1), (-4, -2), (3, -3), (7, -1), (5, 3), (-3, 4)]), AN)       # cuerpo
    P(d, p([(-8, 0), (-14, -1), (-12, 2), (-14, 4), (-7, 3)]), AN3)            # cola abierta
    P(d, p([(4, -5), (8, -6), (10, -3), (8, 0), (5, 0)]), AN)                 # cabeza

AVES = [(32, 16, True, 1.0), (16, 30, False, 0.9), (52, 26, True, 0.9), (28, 44, True, 1.15), (49, 49, False, 1.0)]
def aves_base(d, img):
    for (x, y, a, s) in AVES:
        un_ave(d, x, y, a, s)

def aves_det(d, img):
    for (x, y, a, s) in AVES:
        P(d, [(x + int(9 * s), y - int(5 * s)), (x + int(14 * s), y - int(3 * s)), (x + int(9 * s), y - int(2 * s))], c("c9a24a"))  # pico
        d.point((x + int(9 * s), y - int(5 * s)), c("f0d070"))
        d.point((x + int(7 * s), y - int(4 * s)), c("ff3b3b"))                                                             # ojo rojo
        d.point((x + int(7 * s) - 1, y - int(4 * s)), c("ffb0a0"))

# ------------------------------------------------------------- OSO DE ESCORIA
OS = c("5e524c"); OS2 = c("3e3532"); OS3 = c("857469"); OS_B = c("8f8078")
def oso_base(d, img):
    P(d, [(15, 46), (24, 46), (24, 60), (15, 60)], OS2)                                       # patas lejanas
    P(d, [(43, 44), (51, 44), (52, 60), (44, 60)], OS2)
    P(d, [(3, 44), (4, 34), (11, 24), (21, 17), (33, 14), (43, 18), (50, 26), (53, 38), (49, 50), (10, 52)], OS)  # cuerpo con joroba
    for x in range(10, 46, 5):                                                                 # pelo de la panza
        P(d, [(x, 50), (x + 2, 54), (x + 4, 50)], OS)
    P(d, [(4, 42), (19, 41), (22, 50), (21, 58), (23, 61), (6, 61), (8, 52)], OS)              # pata trasera
    P(d, [(37, 38), (50, 38), (50, 50), (51, 58), (54, 61), (37, 61), (39, 50)], OS)           # pata delantera
    P(d, [(43, 27), (49, 22), (57, 23), (61, 28), (63, 35), (61, 41), (53, 42), (46, 39)], c("6e605a"))  # cabeza baja
    P(d, [(48, 24), (48, 18), (54, 23)], OS)                                                   # oreja
    P(d, [(56, 33), (63, 33), (63, 40), (57, 41)], OS3)                                        # hocico

def oso_det(d, img):
    # placas de metal remachadas sobre la joroba
    P(d, [(12, 27), (24, 19), (30, 27), (18, 35)], METAL[1])
    P(d, [(24, 19), (36, 16), (40, 27), (30, 28)], METAL[0])
    d.line((12, 27, 24, 19), METAL[4]); d.line((24, 19, 36, 16), METAL[4])
    for (x, y) in ((16, 28), (24, 23), (27, 29), (30, 21), (36, 20), (37, 25)):
        d.point((x, y), METAL[4])
    P(d, [(40, 25), (47, 28), (45, 36), (38, 33)], OXIDO[1])                                   # placa oxidada en el hombro
    d.line((40, 25, 47, 28), OXIDO[2]); d.point((43, 30), OXIDO[3])
    # grietas de escoria al rojo vivo
    for pts in (((6, 38), (11, 41), (15, 37), (20, 42)), ((24, 44), (28, 40), (32, 45), (34, 42)), ((40, 42), (44, 46), (47, 43)), ((9, 52), (12, 56), (11, 59))):
        d.line(pts, c("ff7a1a"))
        for q in pts[1:-1]:
            d.point(q, c("ffd34a"))
    d.line((46, 39, 53, 42), OS2)                                                              # mentón
    d.rectangle((52, 27, 54, 28), c("ff6a1a")); d.point((54, 27), c("ffe08a"))                 # ojo de brasa
    d.line((50, 26, 56, 25), OS2)                                                              # ceño
    d.rectangle((61, 33, 62, 34), c("1a1412"))                                                 # nariz
    d.line((57, 39, 62, 39), c("2a201c")); d.point((58, 40), c("e8e0d0")); d.point((61, 40), c("e8e0d0"))  # colmillos
    for x in (7, 10, 13, 17, 20, 39, 42, 46, 49, 52):
        d.point((x, 61), c("e8e0d0"))                                                          # garras

def generar_criaturas():
    criatura("gato_mutado", gato_base, gato_det, GN_B)
    criatura("bestia_blanca", bestia_base, bestia_det, BB_PELO)
    criatura("aves_negras", aves_base, aves_det, AN_B)
    criatura("oso_de_escoria", oso_base, oso_det, OS_B)

# ---------------------------------------------------------------------------
# FONDOS (480x270): combate, cinemática del recuerdo y título
# ---------------------------------------------------------------------------
W, H = 480, 270

def skyline(destino, y_base, color, rng, alto=(20, 80), ancho=(14, 40), ventanas=None, roto=True):
    img = nuevo(W, H)  # se dibuja en una capa aparte y luego se pega encima
    d = ImageDraw.Draw(img)
    x = -5
    while x < W:
        a = rng.randint(*ancho)
        h = rng.randint(*alto)
        top = y_base - h
        d.rectangle((x, top, x + a, y_base), color)
        if roto:  # bordes rotos
            for i in range(0, a, 3):
                if rng.random() < 0.4:
                    d.rectangle((x + i, top, x + i + 2, top + rng.randint(1, 6)), (0, 0, 0, 0))
        if ventanas and rng.random() < 0.8:
            for wy in range(top + 6, y_base - 4, 7):
                for wx in range(x + 3, x + a - 3, 6):
                    if rng.random() < 0.35:
                        d.rectangle((wx, wy, wx + 2, wy + 3), ventanas)
        x += a + rng.randint(2, 18)
    destino.alpha_composite(img)

def plataforma(img, cx, cy, rx, ry, rng):
    d = ImageDraw.Draw(img)
    d.ellipse((cx - rx, cy - ry + 3, cx + rx, cy + ry + 3), c("3a2f26"))
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), TIERRA[2])
    d.ellipse((cx - rx + 6, cy - ry + 3, cx + rx - 6, cy + ry - 2), TIERRA[1])
    for _ in range(int(rx * ry * 0.25)):
        a = rng.random() * math.tau
        r = math.sqrt(rng.random())
        x = int(cx + math.cos(a) * r * (rx - 6))
        y = int(cy + math.sin(a) * r * (ry - 3))
        img.putpixel((x, y), rng.choice([TIERRA[0], TIERRA[2], TIERRA[4]]))
    for i in range(6):  # matas secas
        x = cx + rng.randint(-rx + 10, rx - 10)
        y = cy + rng.randint(-ry + 4, ry - 4)
        d.line((x, y, x - 1, y - 4), PASTO[0])
        d.line((x + 1, y, x + 2, y - 3), PASTO[2])

def generar_fondo_combate():
    """Fondo del combate. Las plataformas deben coincidir con POS_ENEMIGO y POS_ALIADO de combate.gd."""
    rng = random.Random(11)
    img = nuevo(W, H)
    hz = 108  # línea del horizonte
    gradiente(img, (0, 0, W, hz + 10), [c("2e2638"), c("4a3346"), c("74463f"), c("a8603e"), c("c98a4e")])
    d = ImageDraw.Draw(img)
    d.ellipse((330, 22, 366, 58), c("e8b878"))  # sol tapado por smog
    tramado(img, (325, 36, 371, 48), c("e8b878"), c("c98a4e"), nivel=0.5)
    skyline(img, hz - 8, c("5a3a42"), rng, (24, 70), (16, 46))
    skyline(img, hz, c("3a2733"), rng, (12, 46), (12, 34), ventanas=c("6a4a3a"))
    for x in (60, 75, 410):  # chimeneas a lo lejos
        d.rectangle((x, 44, x + 6, hz), c("2a1f28"))
        for k in range(5):
            r = 4 + k * 3
            d.ellipse((x - r + 3 + k * 4, 36 - k * 8 - r, x + r + 3 + k * 4, 36 - k * 8 + r), c("2a2228"))
    # Suelo
    d.rectangle((0, hz, W, H), TIERRA[1])
    gradiente(img, (0, hz, W, hz + 18), [c("6e5440"), TIERRA[2], TIERRA[1]])
    ruido(img, (0, hz + 10, W, H), [TIERRA[0], TIERRA[2], TIERRA[3]], 0.12, rng)
    for _ in range(14):  # grietas
        x, y = rng.randrange(0, W), rng.randrange(hz + 20, H)
        for _ in range(6):
            nx, ny = x + rng.randint(-4, 6), y + rng.randint(-1, 3)
            d.line((x, y, nx, ny), TIERRA[4])
            x, y = nx, ny
    for _ in range(8):  # restos en el suelo
        x, y = rng.randrange(0, W), rng.randrange(hz + 6, hz + 50)
        d.rectangle((x, y, x + rng.randint(4, 12), y + rng.randint(2, 5)), rng.choice([OXIDO[1], METAL[1], CONCRETO[2]]))
    plataforma(img, 340, 124, 66, 12, rng)
    plataforma(img, 138, 182, 82, 13, rng)
    guardar(img, "fondos/combate_paramo.png")

# ---------------------------------------------------------------------------
# INTRO (El Recuerdo): escenas con personajes en pixel art grande
# ---------------------------------------------------------------------------

def x2(img, k=2):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)

def pegar(dest, spr, x, y_pies, k=2, flip=False):
    """Pega un sprite escalado (pixel grande) con los pies en (x, y_pies)."""
    s = x2(spr, k)
    if flip:
        s = s.transpose(Image.FLIP_LEFT_RIGHT)
    caja = s.getbbox()
    dest.alpha_composite(s, (int(x - s.width / 2), int(y_pies - caja[3])))

def tintar(img, col, fuerza):
    capa = Image.new("RGBA", img.size, col[:3] + (255,))
    mezcla = ImageChops.multiply(img, capa)
    return Image.blend(img, mezcla, fuerza)

def silueta(spr, col):
    out = spr.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3]:
                px[x, y] = col
    return out

def luz_anillos(img, cx, cy, radios, colores_noche, calido):
    """Luz de fogata en anillos (estilo pixel): cerca = color real tibio, lejos = noche."""
    mapa = Image.new("RGBA", img.size, colores_noche[-1][:3] + (255,))
    d = ImageDraw.Draw(mapa)
    pasos = list(zip(radios, colores_noche))
    for r, col in reversed(pasos):
        d.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), col[:3] + (255,))
    d.ellipse((cx - radios[0] * 0.55, cy - radios[0] * 0.4, cx + radios[0] * 0.55, cy + radios[0] * 0.4), calido[:3] + (255,))
    return ImageChops.multiply(img, mapa)

# ------------------------------------------------------------------ personajes de la intro
PAPA = dict(piel=c("c48a5e"), pelo=c("2a201c"), ropa=c("4a5a4a"), ropa2=c("3a4a3a"), pant=c("3a3328"), bota=c("2a2018"))
MAMA = dict(piel=c("d8a070"), pelo=c("3a2418"), ropa=c("7a3a3a"), ropa2=c("5e2c2c"), pant=c("33303a"), bota=c("2a2420"))
MARCUS = dict(piel=c("e0b090"), pelo=c("d8d0c0"), ropa=c("f2efe8"), ropa2=c("d6d0c4"), pant=c("e8e4dc"), bota=c("c8c0b0"))

def papa_frente(pose="abajo", despues=None):
    def extra(d):
        d.rectangle((10, 11, 15, 15), c("3a2a22"))          # barba
        d.line((13, 13, 15, 13), c("8a5a40"))
    return figura(PAPA["piel"], PAPA["pelo"], "corto", PAPA["ropa"], PAPA["ropa2"], PAPA["pant"], PAPA["bota"], ojos=c("5a3a22"), pose=pose, extra=extra, despues=despues)

def mama_frente(pose="abajo", despues=None):
    return figura(MAMA["piel"], MAMA["pelo"], "largo", MAMA["ropa"], MAMA["ropa2"], MAMA["pant"], MAMA["bota"], ojos=OJO, pose=pose, despues=despues)

def marcus_frente(despues=None):
    def extra(d):
        d.line((15, 17, 15, 30), c("8a1a1a"))               # corbata roja
        d.polygon([(11, 17), (15, 17), (15, 22)], c("c8c0b0"))  # solapa
    return figura(MARCUS["piel"], MARCUS["pelo"], "corto", MARCUS["ropa"], MARCUS["ropa2"], MARCUS["pant"], MARCUS["bota"], ojos=c("3a3a44"), extra=extra, despues=despues)

def corredor(p, peinado, paso, pelo_largo=False):
    """Adulto corriendo hacia la DERECHA (24x40)."""
    img = nuevo(24, 40); d = ImageDraw.Draw(img)
    if paso == 0:
        piernas = [((11, 24), (6, 30), (2, 33)), ((13, 24), (18, 30), (17, 37))]
    else:
        piernas = [((11, 24), (9, 31), (7, 37)), ((13, 24), (17, 28), (20, 33))]
    (a, b, e) = piernas[0]
    d.line((a, b), oscurecer(p["pant"], 0.75), 3); d.line((b, e), oscurecer(p["pant"], 0.75), 3)
    d.rectangle((e[0] - 2, e[1], e[0] + 1, e[1] + 2), p["bota"])
    d.line((12, 13, 7, 18), p["ropa2"], 2); d.line((7, 18, 5, 15), p["ropa2"], 2)   # brazo de atrás
    d.polygon([(9, 12), (16, 11), (17, 24), (10, 25)], p["ropa"])                    # torso inclinado
    (a, b, e) = piernas[1]
    d.line((a, b), p["pant"], 3); d.line((b, e), p["pant"], 3)
    d.rectangle((e[0] - 1, e[1], e[0] + 3, e[1] + 2), p["bota"])
    d.line((15, 13, 20, 17), p["ropa2"], 2); d.line((20, 17, 22, 13), p["ropa2"], 2)  # brazo de adelante
    d.point((22, 12), p["piel"])
    d.rectangle((11, 2, 18, 10), p["piel"])                                          # cabeza
    d.rectangle((10, 1, 17, 4), p["pelo"]); d.rectangle((10, 4, 12, 8), p["pelo"])
    if pelo_largo:
        d.polygon([(10, 2), (3, 6), (1, 12), (6, 9), (10, 10)], p["pelo"])          # pelo al viento
    d.point((16, 6), c("1a1416"))
    luz_lateral(img); contorno_suave(img)
    return img

def pan_nino_lado(paso):
    return pan_lado(paso)

# ------------------------------------------------------------------ escenas
def nube(d, x, y, col, col2):
    for (dx, dy, w, h) in ((0, 6, 40, 8), (8, 0, 18, 10), (22, 2, 14, 8)):
        d.rectangle((x + dx, y + dy, x + dx + w, y + dy + h), col)
    d.line((x, y + 14, x + 40, y + 14), col2)

def escena_antes():
    rng = random.Random(1)
    img = nuevo(W, H)
    gradiente(img, (0, 0, W, 170), [c("4a90d8"), c("78b8ec"), c("a8d8f4"), c("d8f0fa")])
    d = ImageDraw.Draw(img)
    d.ellipse((380, 40, 412, 72), c("fff2b0")); d.ellipse((386, 46, 406, 66), c("fffbe0"))
    for (x, y) in ((60, 40), (170, 64), (290, 34)):
        nube(d, x, y, c("ffffff"), c("cfe6f4"))
    skyline(img, 150, c("9ab8cc"), rng, (40, 90), (16, 34), ventanas=c("c8e0f0"), roto=False)
    skyline(img, 160, c("d8d0c0"), rng, (24, 70), (14, 30), ventanas=c("6aa0d0"), roto=False)
    d.polygon([(0, 160), (120, 150), (260, 158), (400, 148), (480, 156), (480, H), (0, H)], c("5aa84a"))   # colinas
    gradiente(img, (0, 168, W, 182), [c("5aa84a"), c("4a9a3e")])
    d.polygon([(0, 186), (480, 178), (480, 214), (0, 222)], c("3a7ad0"))                             # río
    for _ in range(40):
        x = rng.randrange(0, W); y = rng.randrange(186, 214)
        d.line((x, y, x + rng.randint(3, 8), y), c("bfe4ff"))
    d.rectangle((0, 214, W, H), c("4a9a3e"))
    d.polygon([(0, 222), (480, 214), (480, 220), (0, 228)], c("8acb5a"))
    for x in (30, 90, 410, 450):                                                                       # árboles
        d.rectangle((x, 150, x + 3, 170), c("5a3a22"))
        d.ellipse((x - 9, 132, x + 12, 156), c("3a8a3a")); d.ellipse((x - 5, 134, x + 6, 146), c("5ab04a"))
    for (x, y) in ((120, 90), (134, 84), (148, 94)):                                                  # pájaros blancos
        d.line((x - 3, y - 2, x, y, x + 3, y - 2), c("ffffff"))
    return img

def escena_ruinas():
    rng = random.Random(1)
    img = nuevo(W, H)
    gradiente(img, (0, 0, W, 170), [c("2e2236"), c("6a3440"), c("b0583a"), c("e08a40")])
    d = ImageDraw.Draw(img)
    d.ellipse((380, 40, 412, 72), c("f2b070"))
    tramado(img, (370, 50, 420, 62), c("f2b070"), c("b0583a"), nivel=0.5)
    skyline(img, 150, c("5a3440"), rng, (40, 90), (16, 34))
    skyline(img, 160, c("3a2430"), rng, (24, 70), (14, 30), ventanas=c("6a3a30"))
    for x in (70, 300):                                                                                # humo
        for k in range(6):
            r = 6 + k * 4
            d.ellipse((x - r + k * 6, 110 - k * 14 - r, x + r + k * 6, 110 - k * 14 + r), c("2a2028"))
    d.polygon([(0, 160), (120, 150), (260, 158), (400, 148), (480, 156), (480, H), (0, H)], TIERRA[2])
    gradiente(img, (0, 168, W, 182), [TIERRA[2], TIERRA[1]])
    d.polygon([(0, 186), (480, 178), (480, 214), (0, 222)], c("3a4a2a"))                              # río tóxico
    for _ in range(40):
        x = rng.randrange(0, W); y = rng.randrange(186, 214)
        d.line((x, y, x + rng.randint(2, 6), y), rng.choice([TOXICO[1], TOXICO[2]]))
    d.rectangle((0, 214, W, H), TIERRA[1])
    ruido(img, (0, 214, W, H), [TIERRA[0], TIERRA[2]], 0.1, rng)
    for x in (30, 90, 450):                                                                            # árboles muertos
        d.line((x, 170, x, 136), c("2a1c18"), 3)
        d.line((x, 150, x - 8, 140), c("2a1c18"), 2); d.line((x, 144, x + 7, 134), c("2a1c18"), 2)
    d.polygon([(330, 180), (350, 160), (372, 156), (396, 166), (410, 182)], c("4a3a34"))              # escombros
    d.rectangle((356, 164, 368, 170), OXIDO[1])
    gato = dibujar_criatura(gato_base, gato_det, GN_B)
    pegar(img, gato, 372, 166, k=1)
    aves = dibujar_criatura(aves_base, aves_det, AN_B)
    img.alpha_composite(aves.transpose(Image.FLIP_LEFT_RIGHT), (120, 44))
    bestia = silueta(dibujar_criatura(bestia_base, bestia_det, BB_PELO), c("1e1620"))
    pegar(img, bestia, 210, 166, k=1)
    d = ImageDraw.Draw(img)
    d.rectangle((222, 136, 223, 137), c("ffffff"))                                                     # ojo blanco de la bestia
    return img

def escena_familia():
    """De noche, alrededor de una fogata: Papá, Mamá y Pan niño."""
    rng = random.Random(2)
    img = nuevo(W, H)
    gradiente(img, (0, 0, W, 150), [c("0e1020"), c("1a1a32"), c("2a2440")])
    d = ImageDraw.Draw(img)
    for _ in range(50):
        d.point((rng.randrange(0, W), rng.randrange(0, 110)), c("d8d8f0"))
    skyline(img, 150, c("1a1626"), rng, (40, 100), (16, 40))
    d.rectangle((0, 150, W, H), c("4a3a30"))
    ruido(img, (0, 150, W, H), [c("3a2e26"), c("5a463a")], 0.12, rng)
    d.polygon([(40, 150), (60, 96), (110, 100), (120, 150)], c("4a4048"))                              # muro roto
    d.polygon([(380, 150), (390, 110), (430, 90), (450, 150)], c("4a4048"))
    pegar(img, papa_frente(), 160, 200)
    pegar(img, mama_frente(), 320, 200)
    pegar(img, pan_frente(0), 240, 184)
    # fogata
    d = ImageDraw.Draw(img)
    fy = 18
    for (x0, y0, x1, y1) in ((222, 212, 258, 204), (222, 204, 258, 212)):
        d.line((x0, y0 + fy, x1, y1 + fy), c("5a3a22"), 4)
    d.polygon([(a, b + fy) for (a, b) in [(226, 206), (232, 186), (238, 196), (242, 180), (248, 196), (252, 188), (256, 206)]], c("e85a1a"))
    d.polygon([(a, b + fy) for (a, b) in [(232, 206), (238, 194), (242, 188), (246, 196), (250, 206)]], c("ffb030"))
    d.polygon([(a, b + fy) for (a, b) in [(238, 206), (242, 198), (246, 206)]], c("fff0a0"))
    img = luz_anillos(img, 240, 200, [80, 120, 170, 230, 300],
                      [c("fff0d8"), c("e8d0c0"), c("c0a8b8"), c("8a7c98"), c("5a5478")], c("fff4e0"))
    d = ImageDraw.Draw(img)
    for _ in range(14):                                                                                # chispas
        x = 240 + rng.randint(-20, 20); y = rng.randint(130, 180)
        d.point((x, y), c("ffb040"))
    return img

def calle_roja(img, rng):
    gradiente(img, (0, 0, W, 160), [c("3a1418"), c("7a2a22"), c("b04a2a"), c("d87a3a")])
    d = ImageDraw.Draw(img)
    skyline(img, 140, c("4a1c1c"), rng, (60, 130), (20, 50), ventanas=c("6a2a20"))
    d.rectangle((0, 140, W, H), c("3a2420"))
    for y in range(150, H, 14):                                                                       # adoquines
        d.line((0, y, W, y), c("2e1c1a"))
    ruido(img, (0, 140, W, H), [c("2e1c1a"), c("4a2e26")], 0.1, rng)

def escena_huida():
    """Corren de la mano por la calle; atrás, a lo lejos, una figura blanca los sigue."""
    rng = random.Random(3)
    img = nuevo(W, H)
    calle_roja(img, rng)
    marcus = marcus_frente()
    pegar(img, marcus, 70, 168, k=1)                                                                  # lejos, pequeño
    d = ImageDraw.Draw(img)
    d.polygon([(64, 168), (80, 168), (150, 186), (120, 186)], c("2a1816"))                              # su sombra larga
    pegar(img, corredor(MAMA, "largo", 1, True), 230, 214)
    pegar(img, pan_lado(1), 296, 214)
    pegar(img, corredor(PAPA, "corto", 0), 360, 214)
    d = ImageDraw.Draw(img)
    d.line((306, 186, 344, 188), PAPA["ropa2"], 4)                                                     # Pan de la mano de papá
    d.line((250, 182, 282, 190), MAMA["ropa2"], 4)                                                     # y de mamá
    for (x, y) in ((190, 210), (176, 206), (268, 212)):                                               # polvo
        d.ellipse((x - 4, y - 3, x + 4, y + 3), c("6a4a3a"))
    return img

def muro_ladrillos(img, y0, y1):
    d = ImageDraw.Draw(img)
    d.rectangle((0, y0, W, y1), c("4a1c15"))
    for y in range(y0 + 4, y1, 12):
        off = 0 if (y // 12) % 2 else 14
        for x in range(-14 + off, W, 28):
            d.rectangle((x, y, x + 26, y + 10), c("5a251c"))
            d.line((x, y, x + 26, y), c("6a3022"))

def rejilla(d, x0, y0, x1, y1, cerrada=1.0):
    d.rectangle((x0, y0, x1, y1), c("0e0808"))
    d.rectangle((x0 - 3, y0 - 3, x1 + 3, y1 + 3), outline=METAL[1], width=3)
    for i, x in enumerate(range(x0 + 6, x1, 9)):
        if i / max(1, (x1 - x0) // 9) <= cerrada:
            d.line((x, y0 + 2, x, y1 - 2), METAL[2], 3)
            d.line((x - 1, y0 + 2, x - 1, y1 - 2), METAL[4])

def escena_callejon():
    """Sin salida: Mamá señala el conducto de ventilación."""
    rng = random.Random(4)
    img = nuevo(W, H)
    gradiente(img, (0, 0, W, 60), [c("3a1418"), c("7a2a22")])
    muro_ladrillos(img, 30, 200)
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (70, 30), (70, 200), (0, 230)], c("2e120e"))
    d.polygon([(W, 0), (W - 70, 30), (W - 70, 200), (W, 230)], c("2e120e"))
    d.rectangle((0, 200, W, H), c("2a1612"))
    rejilla(d, 96, 140, 176, 196)                                                                      # el conducto
    for i in range(3):                                                                                # brillo que llama la atención
        d.line((136 + (i - 1) * 22, 124, 136 + (i - 1) * 30, 112), c("ffd890"), 2)
    def brazo(d):   # brazo extendido hacia la izquierda (hacia el conducto)
        d.rectangle((0, 18, 8, 21), MAMA["ropa2"]); d.rectangle((0, 18, 1, 21), MAMA["piel"])
    pegar(img, mama_frente(despues=brazo), 236, 214)
    pegar(img, papa_frente(), 340, 214)
    pegar(img, pan_frente(0), 290, 212)
    return img

def escena_conducto():
    """Primer plano: Pan dentro del conducto con su mochila; la mano de papá cierra la rejilla."""
    img = nuevo(W, H)
    muro_ladrillos(img, 0, H)
    d = ImageDraw.Draw(img)
    d.rectangle((130, 40, 350, 220), c("0a0606"))                                                      # boca del conducto
    d.rectangle((130, 40, 350, 46), c("2a1a16"))
    fig = tintar(retrato_pan48(solo_figura=True), c("a0a0c8"), 0.45)
    pegar(img, fig, 220, 222, k=4)
    d = ImageDraw.Draw(img)
    for x in range(300, 352, 14):                                                                      # rejilla cerrándose
        d.line((x, 44, x, 218), METAL[2], 5); d.line((x - 2, 44, x - 2, 218), METAL[4])
    d.rectangle((294, 40, 356, 46), METAL[1]); d.rectangle((294, 214, 356, 220), METAL[1])
    d.polygon([(356, 100), (420, 92), (480, 96), (480, 150), (420, 146), (360, 140)], PAPA["ropa2"])   # brazo de papá
    d.rectangle((346, 104, 364, 136), PAPA["piel"])                                                    # su mano
    d.line((346, 112, 340, 112), PAPA["piel"], 4); d.line((346, 122, 338, 122), PAPA["piel"], 4)
    d.line((346, 104, 364, 104), oscurecer(PAPA["piel"], 0.8))
    return img

def escena_rejilla():
    """Desde dentro del conducto: el hombre del traje blanco frente a sus padres."""
    img = nuevo(W, H, c("0a0606"))
    gradiente(img, (40, 30, 440, 200), [c("e0884a"), c("c0603a"), c("8a3424")])
    skyline(img, 170, c("6a2a22"), random.Random(7), (30, 90), (20, 50))
    d = ImageDraw.Draw(img)
    d.rectangle((40, 170, 440, 226), c("4a1c16"))
    def arma(d):
        d.rectangle((0, 18, 8, 21), MARCUS["ropa2"]); d.rectangle((0, 17, 2, 19), c("2a2a2a"))
    pegar(img, marcus_frente(despues=arma), 330, 214, k=3)
    d = ImageDraw.Draw(img)
    # sus padres, de espaldas (miran al hombre): siluetas con borde de luz roja
    papa = silueta(papa_frente(), c("140a0a"))
    mama = silueta(mama_frente(), c("140a0a"))
    pegar(img, papa, 140, 230, k=3)
    pegar(img, mama, 214, 230, k=3)
    d = ImageDraw.Draw(img)
    for y in range(30, 226, 26):                                                                      # láminas de la rejilla
        d.rectangle((40, y, 440, y + 4), c("0e0808"))
        d.line((40, y + 5, 440, y + 5), c("3a2a22"))
    d.rectangle((0, 0, W, 30), c("0a0606")); d.rectangle((0, 226, W, H), c("0a0606"))
    d.rectangle((0, 0, 40, H), c("0a0606")); d.rectangle((440, 0, W, H), c("0a0606"))
    return img

ESCENAS = [("01_antes", escena_antes), ("02_ruinas", escena_ruinas), ("03_familia", escena_familia),
           ("04_huida", escena_huida), ("05_callejon", escena_callejon), ("06_conducto", escena_conducto),
           ("07_rejilla", escena_rejilla)]


def generar_cinematica():
    """La intro "El Recuerdo": una imagen clara para cada momento (cambia según la frase del diálogo)."""
    for nombre, escena in ESCENAS:
        guardar(escena(), f"cinematica/{nombre}.png")
    rng = random.Random(5)
    # Título: acantilado mirando a Bastión de Óxido
    img = nuevo(W, H)
    gradiente(img, (0, 0, W, 180), [c("2a2236"), c("5a3446"), c("a3543a"), c("e08a3e"), c("f2b45a")])
    d = ImageDraw.Draw(img)
    for x in (300, 318, 340, 360):                          # chimeneas de la Ciudad 1
        hx = rng.randint(50, 80)
        d.rectangle((x, 175 - hx, x + 7, 180), c("3a2228"))
        for k in range(7):
            r = 4 + k * 3
            d.ellipse((x - r + 3 + k * 5, 175 - hx - 8 - k * 9 - r, x + r + 3 + k * 5, 175 - hx - 8 - k * 9 + r), c("1e1820"))
    skyline(img, 182, c("4a2a2e"), rng, (6, 30), (8, 22))
    d.rectangle((0, 180, W, H), c("3a2a26"))
    gradiente(img, (0, 178, W, 200), [c("6a4a3a"), c("4a3530"), c("3a2a26")])
    d.polygon([(0, 205), (170, 198), (215, 215), (230, H), (0, H)], c("2a1f1d"))   # acantilado
    d.line((0, 205, 170, 198), c("4a3a33"))
    d.line((170, 198, 215, 215), c("4a3a33"))
    # Pan de espaldas en el borde (el mismo sprite del juego, a contraluz)
    pan = tintar(pan_frente(0, True), c("6a3a3a"), 0.75)
    pegar(img, pan, 150, 199, k=2)
    guardar(img, "cinematica/04_acantilado.png")


# ---------------------------------------------------------------------------
# EFECTOS DEL COMBATE: sombra bajo los luchadores, chispa de golpe y polvo
# ---------------------------------------------------------------------------
def generar_efectos():
    # Sombra: hace que las criaturas "pisen" el suelo en vez de flotar
    img = nuevo(44, 8)
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, 43, 7), (20, 12, 10, 90))
    d.ellipse((6, 1, 37, 6), (20, 12, 10, 140))
    guardar(img, "efectos/sombra.png")

    # Chispa de impacto: 4 cuadros de 32x32 en una fila (blanca, el juego la tiñe)
    img = nuevo(128, 32)
    d = ImageDraw.Draw(img)
    blanco, amarillo = c("ffffff"), c("fff2a8")
    # cuadro 0: destello pequeño
    d.rectangle((14, 14, 17, 17), blanco)
    d.line((15, 9, 15, 22), amarillo); d.line((10, 15, 21, 15), amarillo)
    # cuadro 1: estrella grande de 8 puntas
    cx, cy = 32 + 16, 16
    for (dx, dy, l) in ((1, 0, 14), (0, 1, 14), (1, 1, 9), (1, -1, 9)):
        d.line((cx - dx * l, cy - dy * l, cx + dx * l, cy + dy * l), amarillo, 1)
    d.polygon([(cx, cy - 7), (cx + 3, cy - 3), (cx + 7, cy), (cx + 3, cy + 3), (cx, cy + 7), (cx - 3, cy + 3), (cx - 7, cy), (cx - 3, cy - 3)], blanco)
    # cuadro 2: anillo de chispas
    cx = 64 + 16
    for k in range(10):
        a = k * math.tau / 10
        x, y = cx + math.cos(a) * 11, cy + math.sin(a) * 11
        d.line((x, y, x + math.cos(a) * 3, y + math.sin(a) * 3), blanco if k % 2 else amarillo)
    d.rectangle((cx - 2, cy - 2, cx + 1, cy + 1), amarillo)
    # cuadro 3: chispas sueltas apagándose
    cx = 96 + 16
    for k in range(8):
        a = k * math.tau / 8 + 0.3
        d.point((cx + math.cos(a) * 14, cy + math.sin(a) * 14), amarillo)
    guardar(img, "efectos/impacto.png")

    # Polvo al aterrizar o caer: 4 cuadros de 32x16
    img = nuevo(128, 16)
    d = ImageDraw.Draw(img)
    for f in range(4):
        x0 = f * 32
        abre = 3 + f * 3
        col = (200, 170, 130, 220 - f * 50)
        col2 = (150, 120, 90, 220 - f * 50)
        for lado in (-1, 1):
            bx = x0 + 16 + lado * abre
            r = 4 - f // 2
            d.rectangle((bx - r, 12 - r - f, bx + r, 13 - f // 2), col)
            d.rectangle((bx - r + 1, 13 - f // 2, bx + r, 14 - f // 2), col2)
        if f < 2:
            d.rectangle((x0 + 13, 11, x0 + 18, 14), col)
    guardar(img, "efectos/polvo.png")

# ---------------------------------------------------------------------------
# INTERFAZ: paneles 9-slice, botones, joystick
# ---------------------------------------------------------------------------
def panel_9slice(nombre, fondo, borde, brillo, remaches=True, tam=24):
    img = nuevo(tam, tam)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, tam - 1, tam - 1), CONTORNO)
    d.rectangle((1, 1, tam - 2, tam - 2), borde)
    d.line((1, 1, tam - 2, 1), brillo)
    d.line((1, 1, 1, tam - 2), brillo)
    d.rectangle((3, 3, tam - 4, tam - 4), CONTORNO)
    d.rectangle((4, 4, tam - 5, tam - 5), fondo)
    if remaches:
        for (x, y) in ((2, 2), (tam - 3, 2), (2, tam - 3), (tam - 3, tam - 3)):
            d.point((x, y), brillo)
    guardar(img, f"interfaz/{nombre}.png")

def generar_interfaz():
    panel_9slice("panel", c("201c20"), c("6b4a2e"), c("a8743f"))
    panel_9slice("panel_dialogo", c("16141a"), c("4a5560"), c("8a96a3"))
    panel_9slice("boton", c("3d3530"), c("6b4a2e"), c("a8743f"), remaches=False, tam=12)
    panel_9slice("boton_encima", c("4f4238"), c("c06a36"), c("e0a060"), remaches=False, tam=12)
    panel_9slice("boton_pulsado", c("5c3a22"), c("d98a4a"), c("ffd08a"), remaches=False, tam=12)
    panel_9slice("boton_desactivado", c("2a2626"), c("3e3632"), c("4e4640"), remaches=False, tam=12)
    # Joystick
    img = nuevo(48, 48)
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, 47, 47), (20, 18, 22, 110))
    d.ellipse((0, 0, 47, 47), outline=(230, 210, 180, 170), width=2)
    d.ellipse((4, 4, 43, 43), outline=(230, 210, 180, 60))
    guardar(img, "interfaz/joystick_base.png")
    img = nuevo(20, 20)
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, 19, 19), (40, 34, 30, 220))
    d.ellipse((2, 2, 17, 17), (192, 106, 54, 230))
    d.ellipse((4, 3, 10, 8), (240, 170, 110, 230))
    guardar(img, "interfaz/joystick_palanca.png")
    # Indicador "!" sobre objetos con los que se puede interactuar
    img = nuevo(7, 9)
    d = ImageDraw.Draw(img)
    d.rectangle((2, 0, 4, 5), c("ffd24d"))
    d.rectangle((2, 7, 4, 8), c("ffd24d"))
    contorno(img)
    guardar(img, "interfaz/exclamacion.png")
    # Carta de vínculo (para la animación de captura)
    img = nuevo(10, 14)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 9, 13), c("f4e9c8"))
    d.rectangle((2, 2, 7, 11), c("7fd6e6"))
    d.rectangle((3, 3, 6, 10), c("c9f3fa"))
    contorno(img)
    guardar(img, "interfaz/carta.png")

# ---------------------------------------------------------------------------
if __name__ == "__main__":
    generar_tiles_exterior()
    generar_tiles_interior()
    generar_objetos()
    generar_pan()
    generar_npcs()
    generar_combate_humanos()
    generar_retratos()
    generar_criaturas()
    generar_fondo_combate()
    generar_efectos()
    generar_cinematica()
    generar_interfaz()
    with open(os.path.join(ARTE, "tiles", "tiles.json"), "w", encoding="utf-8") as f:
        json.dump({"exterior": TILES_EXT, "interior": TILES_INT}, f, indent=1, ensure_ascii=False)
    print("Listo:", len(TILES_EXT), "tiles exteriores,", len(TILES_INT), "interiores")
