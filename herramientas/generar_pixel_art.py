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

from PIL import Image, ImageDraw

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
# PERSONAJES
# ---------------------------------------------------------------------------
PIEL = c("c08a5a")
PIEL_S = c("9a6a42")
PELO = c("15161f")
PELO_AZUL = c("2a3c6e")
NEGRO_ROPA = c("26262e")
NEGRO_ROPA2 = c("34343e")
OJO_VERDE = c("3ee07a")
MOCHILA = c("7a4e2a")
PERLA = c("9b4fd1")

def pan_frame(direccion, paso):
    """Pan en el mapa: 16x24. direccion: 0 abajo, 1 izquierda, 2 derecha, 3 arriba."""
    img = nuevo(16, 24)
    d = ImageDraw.Draw(img)
    ab = {0: 0, 1: 1, 2: -1}[paso]  # balanceo de piernas
    # Piernas (pantalón cargo negro)
    if direccion in (0, 3):
        d.rectangle((5, 17, 7, 22 - max(0, ab)), NEGRO_ROPA)
        d.rectangle((9, 17, 11, 22 - max(0, -ab)), NEGRO_ROPA)
        d.point((5, 19), NEGRO_ROPA2)
        d.point((11, 19), NEGRO_ROPA2)
    else:
        d.rectangle((6 + ab, 17, 8 + ab, 22), NEGRO_ROPA)
        d.rectangle((8 - ab, 17, 10 - ab, 22), NEGRO_ROPA2)
    # Torso
    d.rectangle((4, 10, 11, 17), NEGRO_ROPA)
    d.line((4, 15, 11, 15), c("3a3a44"))  # cinturón
    # Brazos
    if direccion in (0, 3):
        d.rectangle((3, 11, 3, 16 - (1 if paso == 1 else 0)), NEGRO_ROPA2)
        d.rectangle((12, 11, 12, 16 - (1 if paso == 2 else 0)), NEGRO_ROPA2)
        d.point((3, 16), PIEL)
        d.point((12, 16), PIEL)
    # Mochila (se ve de espaldas y de lado)
    if direccion == 3:
        d.rectangle((5, 10, 10, 16), MOCHILA)
        d.line((5, 12, 10, 12), c("5e3a1e"))
    elif direccion == 1:
        d.rectangle((10, 11, 12, 16), MOCHILA)
    elif direccion == 2:
        d.rectangle((3, 11, 5, 16), MOCHILA)
    # Cabeza
    d.rectangle((4, 2, 11, 9), PIEL)
    # Pelo estilo Nightwing (negro con reflejo azul)
    if direccion == 0:
        d.rectangle((4, 1, 11, 4), PELO)
        d.point((4, 5), PELO)
        d.point((11, 5), PELO)
        d.point((6, 5), PELO)
        d.line((6, 2, 9, 2), PELO_AZUL)
        d.point((6, 6), OJO_VERDE)
        d.point((9, 6), OJO_VERDE)
        d.point((8, 11), c("c9c9d1"))  # collar
        d.point((8, 12), PERLA)
    elif direccion == 3:
        d.rectangle((4, 1, 11, 9), PELO)
        d.line((5, 2, 9, 2), PELO_AZUL)
        d.line((5, 8, 10, 8), PELO)
    else:
        mira = -1 if direccion == 1 else 1
        d.rectangle((4, 1, 11, 5), PELO)
        if mira < 0:
            d.rectangle((9, 1, 11, 8), PELO)
            d.point((5, 6), OJO_VERDE)
            d.point((10, 6), c("e6c34a"))  # aro de mariposa (oreja izquierda)
        else:
            d.rectangle((4, 1, 6, 8), PELO)
            d.point((10, 6), OJO_VERDE)
        d.line((6, 2, 9, 2), PELO_AZUL)
    sombrear(img, 1.1, 0.8)
    contorno(img)
    return img

def generar_pan():
    hoja = nuevo(16 * 3, 24 * 4)
    for direccion in range(4):
        for paso in range(3):
            hoja.alpha_composite(pan_frame(direccion, paso), (paso * 16, direccion * 24))
    guardar(hoja, "personajes/pan_mapa.png")

def persona_simple(ropa, ropa2, pelo, extra=None, encorvado=False):
    img = nuevo(16, 24)
    d = ImageDraw.Draw(img)
    dy = 1 if encorvado else 0
    d.rectangle((5, 17, 7, 22), ropa2)
    d.rectangle((9, 17, 11, 22), ropa2)
    d.rectangle((4, 10 + dy, 11, 17), ropa)
    d.rectangle((3, 11 + dy, 3, 16), ropa)
    d.rectangle((12, 11 + dy, 12, 16), ropa)
    d.rectangle((4, 2 + dy, 11, 9 + dy), PIEL)
    d.rectangle((4, 1 + dy, 11, 3 + dy), pelo)
    d.point((6, 6 + dy), CONTORNO)
    d.point((9, 6 + dy), CONTORNO)
    if extra:
        extra(d, dy)
    sombrear(img, 1.1, 0.8)
    contorno(img)
    return img

def generar_npcs():
    # Recluta de Chatarra: chaleco oxidado y pañuelo
    recluta = persona_simple(OXIDO[0], c("3a3328"), c("4a3a2a"),
                             lambda d, dy: (d.rectangle((4, 7, 11, 9), c("8c2f2f")), d.line((4, 12, 11, 12), METAL[2])))
    guardar(recluta, "personajes/recluta_mapa.png")
    # Ciudadano de Bastión de Óxido: ropa con hollín, encorvado
    ciudadano = persona_simple(c("6b6458"), c("3e3a33"), c("2b2722"),
                               lambda d, dy: ruido_d(d, 4, 10, 11, 17, c("3a3530")), encorvado=True)
    guardar(ciudadano, "personajes/ciudadano_mapa.png")

def ruido_d(d, x0, y0, x1, y1, col):
    rng = random.Random(3)
    for _ in range(6):
        d.point((rng.randint(x0, x1), rng.randint(y0, y1)), col)

def generar_combate_humanos():
    # Pan en combate (32x48): de brazos cruzados, quieto como una estatua.
    img = nuevo(32, 48)
    d = ImageDraw.Draw(img)
    d.rectangle((10, 32, 14, 46), NEGRO_ROPA)
    d.rectangle((17, 32, 21, 46), NEGRO_ROPA2)
    d.rectangle((9, 36, 10, 40), NEGRO_ROPA2)  # bolsillos cargo
    d.rectangle((21, 36, 22, 40), NEGRO_ROPA)
    d.rectangle((6, 16, 12, 30), MOCHILA)        # mochila detrás
    d.rectangle((9, 15, 23, 33), NEGRO_ROPA)
    d.rectangle((8, 22, 24, 26), NEGRO_ROPA2)    # brazos cruzados
    d.point((10, 24), PIEL)
    d.point((22, 24), PIEL)
    d.rectangle((11, 4, 21, 14), PIEL)
    d.rectangle((10, 2, 22, 7), PELO)
    d.rectangle((10, 2, 12, 12), PELO)
    d.line((13, 3, 19, 3), PELO_AZUL)
    d.line((14, 4, 18, 4), PELO_AZUL)
    d.point((18, 9), OJO_VERDE)
    d.point((19, 9), OJO_VERDE)
    d.line((16, 8, 19, 8), PELO)                 # ceño
    d.point((13, 10), c("e6c34a"))               # aro de mariposa
    d.point((16, 16), c("c9c9d1"))
    d.point((16, 17), PERLA)
    sombrear(img, 1.12, 0.75)
    contorno(img)
    guardar(img, "personajes/pan_combate.png")
    # Recluta en combate (mira a la izquierda)
    img = nuevo(32, 48)
    d = ImageDraw.Draw(img)
    d.rectangle((10, 32, 14, 46), c("3a3328"))
    d.rectangle((17, 32, 21, 46), c("3a3328"))
    d.rectangle((9, 15, 23, 33), OXIDO[0])
    d.line((9, 26, 23, 26), METAL[2])
    d.rectangle((5, 17, 8, 30), OXIDO[1])
    d.rectangle((23, 17, 26, 24), OXIDO[1])
    d.rectangle((25, 10, 27, 18), OXIDO[1])      # brazo levantado
    d.rectangle((11, 4, 21, 14), PIEL)
    d.rectangle((10, 2, 22, 5), c("4a3a2a"))
    d.rectangle((11, 10, 21, 14), c("8c2f2f"))   # pañuelo
    d.point((13, 8), CONTORNO)
    d.point((14, 8), CONTORNO)
    sombrear(img, 1.12, 0.75)
    contorno(img)
    guardar(img, "personajes/recluta_combate.png")

def generar_retratos():
    # Retrato de Pan para diálogos (32x32): ojos verdes y aro de mariposa
    img = nuevo(32, 32, c("2a2530"))
    d = ImageDraw.Draw(img)
    d.rectangle((6, 26, 25, 31), NEGRO_ROPA)
    d.rectangle((12, 22, 19, 27), PIEL_S)
    d.rectangle((8, 7, 23, 24), PIEL)
    d.rectangle((7, 3, 24, 11), PELO)
    d.rectangle((7, 3, 9, 20), PELO)
    d.rectangle((22, 3, 24, 16), PELO)
    d.polygon([(10, 10), (14, 10), (11, 14)], PELO)  # mechón
    d.line((11, 4, 19, 4), PELO_AZUL)
    d.line((13, 5, 17, 5), PELO_AZUL)
    d.rectangle((11, 14, 13, 15), c("f0f0f0"))
    d.rectangle((18, 14, 20, 15), c("f0f0f0"))
    d.point((12, 14), OJO_VERDE)
    d.point((12, 15), c("1f9a50"))
    d.point((19, 14), OJO_VERDE)
    d.point((19, 15), c("1f9a50"))
    d.line((11, 12, 14, 13), PELO)
    d.line((17, 13, 20, 12), PELO)
    d.line((14, 20, 17, 20), PIEL_S)
    d.point((7, 17), c("e6c34a"))   # aro de mariposa
    d.point((6, 18), c("e6c34a"))
    d.point((8, 18), c("e6c34a"))
    d.point((15, 28), c("c9c9d1"))
    d.point((15, 29), PERLA)
    contorno(img)
    guardar(img, "retratos/pan.png")
    # Recluta
    img = nuevo(32, 32, c("3a2a22"))
    d = ImageDraw.Draw(img)
    d.rectangle((5, 26, 26, 31), OXIDO[0])
    d.rectangle((8, 7, 23, 25), PIEL_S)
    d.rectangle((7, 3, 24, 9), c("4a3a2a"))
    d.rectangle((8, 18, 23, 25), c("8c2f2f"))
    d.point((12, 14), CONTORNO)
    d.point((19, 14), CONTORNO)
    d.line((11, 12, 14, 12), c("2a2018"))
    d.line((17, 12, 21, 11), c("2a2018"))
    d.line((20, 9, 22, 15), c("e0a080"))  # cicatriz
    guardar(img, "retratos/recluta.png")
    # Ciudadano
    img = nuevo(32, 32, c("3a3530"))
    d = ImageDraw.Draw(img)
    d.rectangle((5, 26, 26, 31), c("6b6458"))
    d.rectangle((9, 8, 22, 25), PIEL_S)
    d.rectangle((8, 5, 23, 9), c("2b2722"))
    d.point((12, 15), CONTORNO)
    d.point((19, 15), CONTORNO)
    d.line((14, 21, 17, 21), c("6a4a32"))
    for (x, y) in ((11, 18), (20, 11), (16, 23)):
        d.point((x, y), c("4a3a30"))  # hollín
    guardar(img, "retratos/ciudadano.png")

# ---------------------------------------------------------------------------
# CRIATURAS (64x64, para el combate)
# ---------------------------------------------------------------------------
def criatura(nombre, dibujar, espejo=False):
    """Todas las criaturas miran a la DERECHA; el juego las voltea cuando son enemigas."""
    img = nuevo(64, 64)
    dibujar(ImageDraw.Draw(img), img)
    sombrear(img)
    contorno(img)
    if espejo:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    guardar(img, f"criaturas/{nombre}.png")

def dib_gato(d, img):
    morado, morado2 = c("8e6bbf"), c("6c4f99")
    d.line((14, 40, 6, 26), morado2, 4)            # cola
    d.line((6, 26, 9, 18), morado2, 3)
    d.ellipse((12, 30, 46, 54), morado)            # cuerpo
    d.rectangle((16, 48, 21, 58), morado2)         # patas
    d.rectangle((36, 48, 41, 58), morado2)
    d.rectangle((24, 50, 28, 58), morado)
    d.ellipse((34, 14, 58, 38), morado)            # cabeza
    d.polygon([(36, 20), (37, 6), (44, 16)], morado2)
    d.polygon([(48, 16), (55, 6), (56, 20)], morado2)
    d.polygon([(38, 17), (38, 10), (42, 15)], c("c07ae6"))
    for (x, y, r) in ((20, 38, 4), (30, 44, 3), (40, 34, 3), (26, 34, 2)):
        d.ellipse((x - r, y - r, x + r, y + r), TOXICO[0])  # manchas tóxicas
    d.rectangle((40, 23, 44, 27), c("c6ff3d"))     # ojos
    d.rectangle((50, 23, 54, 27), c("c6ff3d"))
    d.line((42, 23, 42, 27), CONTORNO)
    d.line((52, 23, 52, 27), CONTORNO)
    d.polygon([(46, 30), (48, 30), (47, 32)], c("e05080"))
    d.line((44, 34, 50, 34), c("f0f0f0"))          # colmillos
    for x in (14, 34, 22):
        d.line((x, 58, x + 3, 58), c("f0f0f0"))    # garras

def dib_bestia(d, img):
    blanco, blanco2 = c("f2f2f2"), c("d5d8dc")
    d.rectangle((24, 44, 29, 62), blanco2)        # piernas
    d.rectangle((35, 44, 40, 62), blanco2)
    d.polygon([(22, 22), (42, 22), (40, 46), (24, 46)], blanco)  # torso
    d.line((22, 24, 12, 40), blanco2, 4)          # brazos largos
    d.line((42, 24, 52, 40), blanco2, 4)
    d.line((12, 40, 9, 46), blanco, 2)            # garras
    d.line((52, 40, 56, 46), blanco, 2)
    d.ellipse((22, 4, 42, 24), blanco)            # cabeza
    d.polygon([(22, 10), (16, 30), (24, 22)], blanco2)  # melena
    d.polygon([(42, 10), (48, 30), (40, 22)], blanco2)
    d.rectangle((26, 12, 30, 15), c("b9e6ff"))    # ojos blancos brillantes
    d.rectangle((34, 12, 38, 15), c("b9e6ff"))
    d.point((28, 13), c("ffffff"))
    d.point((36, 13), c("ffffff"))

def dib_aves(d, img):
    negro, negro2 = c("2b2733"), c("1f1c26")
    puestos = [(32, 12), (14, 24), (50, 22), (22, 44), (44, 46)]
    for i, (x, y) in enumerate(puestos):
        sube = -4 if i % 2 else 3
        d.polygon([(x - 12, y + sube), (x, y + 4), (x + 12, y + sube), (x, y)], negro2)
        d.ellipse((x - 4, y - 3, x + 5, y + 5), negro)
        d.polygon([(x + 5, y), (x + 9, y + 1), (x + 5, y + 2)], c("8a7a40"))  # pico
        d.point((x + 2, y), c("ff3b3b"))      # ojo rojo
        d.line((x - 2, y + 5, x - 5, y + 9), negro2)  # cola

def dib_oso(d, img):
    escoria, escoria2 = c("5a4e48"), c("433a35")
    d.ellipse((6, 18, 58, 60), escoria)            # cuerpo enorme
    d.rectangle((10, 48, 22, 62), escoria2)
    d.rectangle((40, 48, 52, 62), escoria2)
    d.ellipse((4, 8, 30, 32), escoria)             # cabeza (mira a la izquierda)
    d.ellipse((5, 6, 12, 13), escoria2)            # orejas
    d.ellipse((20, 4, 27, 11), escoria2)
    d.ellipse((2, 20, 14, 30), c("7a6a60"))        # hocico
    d.point((4, 23), CONTORNO)
    d.rectangle((10, 15, 12, 17), c("ff6a1a"))     # ojo de brasa
    # placas de metal y escoria incrustadas
    d.polygon([(30, 22), (44, 18), (50, 30), (36, 34)], METAL[0])
    d.polygon([(38, 36), (54, 34), (52, 46), (40, 46)], OXIDO[1])
    d.line((32, 24, 46, 21), METAL[4])
    for (x, y) in ((26, 40), (46, 28), (20, 30)):
        d.ellipse((x - 2, y - 2, x + 2, y + 2), c("ff8c1a"))  # brasas
    for x in (8, 12, 16):
        d.line((x, 62, x, 63), c("e8e0d0"))

def generar_criaturas():
    criatura("gato_mutado", dib_gato)
    criatura("bestia_blanca", dib_bestia)
    criatura("aves_negras", dib_aves)
    criatura("oso_de_escoria", dib_oso, espejo=True)

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
    plataforma(img, 352, 132, 74, 16, rng)
    plataforma(img, 132, 192, 88, 20, rng)
    guardar(img, "fondos/combate_paramo.png")

def silueta_adulto(d, x, y, color, escala=1.0, corriendo=True, falda=False):
    s = escala
    d.ellipse((x - 5 * s, y - 52 * s, x + 5 * s, y - 42 * s), color)
    d.polygon([(x - 7 * s, y - 42 * s), (x + 7 * s, y - 42 * s), (x + 6 * s, y - 20 * s), (x - 6 * s, y - 20 * s)], color)
    if falda:
        d.polygon([(x - 6 * s, y - 22 * s), (x + 6 * s, y - 22 * s), (x + 10 * s, y - 12 * s), (x - 10 * s, y - 12 * s)], color)
        d.line((x - 6 * s, y - 42 * s, x - 12 * s, y - 50 * s), color, int(3 * s))  # pelo al viento
    if corriendo:
        d.line((x - 2 * s, y - 20 * s, x - 12 * s, y), color, int(4 * s))
        d.line((x + 2 * s, y - 20 * s, x + 10 * s, y - 6 * s), color, int(4 * s))
        d.line((x + 10 * s, y - 6 * s, x + 14 * s, y), color, int(4 * s))
    else:
        d.line((x - 3 * s, y - 20 * s, x - 4 * s, y), color, int(4 * s))
        d.line((x + 3 * s, y - 20 * s, x + 4 * s, y), color, int(4 * s))

def generar_cinematica():
    rng = random.Random(5)
    rojo_oscuro, sepia1, sepia2, sepia3 = c("2a0f10"), c("6b2a1f"), c("a0523a"), c("d49a6a")
    negro = c("120a0a")
    # Viñeta 1: callejón en ruinas, corren de la mano
    img = nuevo(W, H)
    gradiente(img, (0, 0, W, H), [sepia3, sepia2, sepia1, rojo_oscuro])
    d = ImageDraw.Draw(img)
    skyline(img, 200, c("5a2219"), rng, (60, 150), (24, 60), ventanas=c("7a3626"))
    d.polygon([(0, 0), (120, 40), (120, 230), (0, 270)], c("3a1612"))       # pared izquierda
    d.polygon([(480, 0), (360, 40), (360, 230), (480, 270)], c("3a1612"))  # pared derecha
    for i in range(6):
        d.line((0, 30 + i * 40, 120, 60 + i * 30), c("2a0f0c"))
        d.line((480, 30 + i * 40, 360, 60 + i * 30), c("2a0f0c"))
    d.polygon([(120, 230), (360, 230), (480, 270), (0, 270)], c("4a1c15"))  # suelo
    silueta_adulto(d, 200, 238, negro)
    silueta_adulto(d, 262, 238, negro, falda=True)
    silueta_adulto(d, 232, 238, negro, escala=0.55)       # Pan niño
    d.line((207, 210, 228, 222), negro, 3)                # manos tomadas
    d.line((236, 222, 255, 210), negro, 3)
    guardar(img, "cinematica/01_callejon.png")
    # Viñeta 2: acorralados, Diego esconde a Pan en el conducto
    img = nuevo(W, H)
    gradiente(img, (0, 0, W, H), [sepia2, sepia1, rojo_oscuro, negro])
    d = ImageDraw.Draw(img)
    d.rectangle((40, 20, 440, 230), c("4a1c15"))           # muro sin salida
    for y in range(30, 230, 12):
        off = 0 if (y // 12) % 2 else 14
        for x in range(40 + off, 440, 28):
            d.rectangle((x, y, x + 26, y + 10), c("55231a"))
    d.rectangle((70, 150, 150, 200), c("1a0d0b"))           # conducto de ventilación
    for x in range(74, 150, 8):
        d.line((x, 152, x, 198), c("6b4a3a"), 2)
    d.rectangle((0, 230, W, H), c("2a0f0c"))
    silueta_adulto(d, 175, 238, negro, escala=0.9, corriendo=False)   # Diego agachado
    d.line((168, 205, 140, 185), negro, 5)                 # brazo empujando
    d.ellipse((120, 168, 136, 184), negro)                 # cabeza de Pan en el conducto
    d.rectangle((126, 176, 140, 196), c("4a2a18"))         # la mochila de cuero
    silueta_adulto(d, 300, 238, negro, corriendo=False, falda=True)   # Danitza
    guardar(img, "cinematica/02_acorralados.png")
    # Viñeta 3: a través de la rejilla, la silueta impecable de Marcus
    img = nuevo(W, H, negro)
    d = ImageDraw.Draw(img)
    gradiente(img, (60, 40, 420, 230), [c("8a3a26"), c("6b2a1f"), c("3a1612")])
    blanco = c("e8e0d4")
    silueta_adulto(d, 300, 222, blanco, escala=1.6, corriendo=False)  # Marcus, traje blanco
    d.rectangle((292, 165, 308, 175), c("c9bfb0"))         # corbata/sombra
    d.line((318, 160, 345, 150), blanco, 6)               # brazo extendido
    d.rectangle((343, 146, 352, 151), c("2a2a2a"))         # arma
    silueta_adulto(d, 150, 222, negro, escala=1.4, corriendo=False)
    silueta_adulto(d, 200, 222, negro, escala=1.4, corriendo=False, falda=True)
    for y in range(40, 232, 16):                           # rejilla
        d.rectangle((40, y, 440, y + 3), c("1a1210"))
        d.line((40, y + 4, 440, y + 4), c("3a2a22"))
    d.rectangle((0, 0, W, 40), negro)
    d.rectangle((0, 230, W, H), negro)
    d.rectangle((0, 0, 40, H), negro)
    d.rectangle((440, 0, W, H), negro)
    guardar(img, "cinematica/03_rejilla.png")
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
    # Pan de espaldas en el borde
    px, py = 150, 198
    d.rectangle((px - 4, py - 22, px + 4, py - 8), c("101014"))
    d.rectangle((px - 3, py - 8, px - 1, py), c("101014"))
    d.rectangle((px + 1, py - 8, px + 3, py), c("101014"))
    d.rectangle((px - 4, py - 20, px + 3, py - 12), c("4a2e1a"))   # mochila
    d.ellipse((px - 4, py - 30, px + 4, py - 22), c("101014"))
    d.line((px - 4, py - 28, px - 8, py - 30), c("101014"))         # pelo al viento
    guardar(img, "cinematica/04_acantilado.png")

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
    generar_cinematica()
    generar_interfaz()
    with open(os.path.join(ARTE, "tiles", "tiles.json"), "w", encoding="utf-8") as f:
        json.dump({"exterior": TILES_EXT, "interior": TILES_INT}, f, indent=1, ensure_ascii=False)
    print("Listo:", len(TILES_EXT), "tiles exteriores,", len(TILES_INT), "interiores")
