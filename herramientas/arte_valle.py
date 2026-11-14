"""
Arte de la Ciudad 4: VALLE CENIZA (Comandante Kael, El Protector Leal) y el camino para llegar
(el Bosque Calcinado). Lo llama herramientas/generar_pixel_art.py (no hace falta correrlo solo).

  - atlas nuevo "ceniza" (ceniza, senderos, hierba quemada, brasas, brotes verdes, cercas, troncos...)
  - construcciones (cabañas de madera, el invernadero, el monumento a los caídos, la olla común...)
  - vecinos del valle, Kael (de pie y de rodillas, mapa y combate) y sus retratos
  - primeros planos de Pan para la decisión (normal, perdón y la sombra del pelo sobre los ojos)
  - iconos (Códigos de la Capital, Mapa de Debilidades, Grabación, brote) y fondos "bosque" y "valle"
"""
import math
import random

from PIL import Image, ImageDraw

from generar_pixel_art import *   # noqa: F401,F403
import generar_pixel_art as g
import arte_bastion as ab
from arte_sumidero import ilum, terminar, suelo_propio, W, H
from arte_neon import escribir, ancho

CENIZA = [c("5e5852"), c("4e4844"), c("6e6862"), c("3e3a36"), c("8a847c")]
SENDERO = [c("6a5444"), c("5a463a"), c("7a6250"), c("4a3a30")]
MADERA_V = [c("7a5232"), c("5e3e24"), c("94683e"), c("432a18")]
QUEMADO = [c("2a2420"), c("1c1814"), c("3a322c")]
VERDE_V = [c("5aa83a"), c("3e8a2a"), c("8ad05a"), c("2a6a1e")]
BRASA = [c("ff7a2a"), c("ffb03a"), c("c83a1a")]


# ---------------------------------------------------------------------------
# TILES (atlas propio: arte/tiles/ceniza.png)
# ---------------------------------------------------------------------------
def t_ceniza(rng, v):
    t = nuevo(T, T, CENIZA[0])
    ruido(t, (0, 0, T, T), [CENIZA[1], CENIZA[2]], 0.25, rng)
    d = ImageDraw.Draw(t)
    for _ in range(3):
        d.point((rng.randrange(T), rng.randrange(T)), CENIZA[4])
    if v == 1:
        x, y = rng.randrange(2, 12), rng.randrange(3, 12)
        d.line((x, y, x + 3, y + 1), QUEMADO[0])                        # ramita quemada
    if v == 2:                                                          # un brotecito verde entre la ceniza
        x, y = rng.randrange(4, 11), rng.randrange(6, 12)
        d.line((x, y, x, y - 3), VERDE_V[1]); d.point((x - 1, y - 3), VERDE_V[2]); d.point((x + 1, y - 2), VERDE_V[0])
    return t

def t_sendero(rng, v):
    t = nuevo(T, T, SENDERO[0])
    ruido(t, (0, 0, T, T), [SENDERO[1], SENDERO[2]], 0.22, rng)
    d = ImageDraw.Draw(t)
    if v == 1:
        for _ in range(3):
            x, y = rng.randrange(1, 14), rng.randrange(1, 14)
            d.rectangle((x, y, x + 1, y + 1), CENIZA[2])                 # piedritas
    return t

def t_hierba(rng, v):
    """Hierba alta y quemada (aquí salen criaturas)."""
    t = t_ceniza(rng, 0)
    d = ImageDraw.Draw(t)
    for _ in range(12 + v * 3):
        x, y = rng.randrange(T), rng.randrange(5, T + 2)
        alto = rng.randint(4, 8)
        d.line((x, y, x + rng.choice((-1, 0, 1)), y - alto), rng.choice([c("4a4034"), c("6a5a44"), c("2e2822"), c("7a6a50")]))
    if v == 1:
        d.point((rng.randrange(3, 13), rng.randrange(3, 10)), VERDE_V[0])
    return t

def t_brasa(rng, v):
    """Brasas que todavía arden bajo la ceniza: queman a la criatura del frente."""
    t = nuevo(T, T, c("3a2a24"))
    ruido(t, (0, 0, T, T), [c("2a1e1a"), c("4a3a30")], 0.3, rng)
    d = ImageDraw.Draw(t)
    for _ in range(5 + v * 2):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        d.point((x, y), rng.choice(BRASA))
        if rng.random() < 0.4:
            d.point((x + 1, y), BRASA[2])
    d.line((3, 4, 8, 6), QUEMADO[1])
    return t

def t_huerto(rng):
    t = nuevo(T, T, c("4a3a2a"))
    d = ImageDraw.Draw(t)
    for y in (2, 7, 12):
        d.line((0, y + 2, 15, y + 2), c("3a2c20"))
        for x in range(1, T, 3):
            d.line((x, y + 1, x, y - 1), VERDE_V[1]); d.point((x + 1, y - 1), VERDE_V[2])
    return t

def t_pasto_verde(rng):
    t = nuevo(T, T, c("4e6a34"))
    ruido(t, (0, 0, T, T), [c("3e5a2a"), c("5e7a40")], 0.3, rng)
    d = ImageDraw.Draw(t)
    for _ in range(3):
        d.point((rng.randrange(T), rng.randrange(T)), CENIZA[2])        # todavía cae ceniza encima
    return t

def t_madera(rng):
    t = nuevo(T, T, MADERA_V[0])
    d = ImageDraw.Draw(t)
    for y in (0, 5, 10):
        d.line((0, y, 15, y), MADERA_V[3]); d.line((0, y + 1, 15, y + 1), MADERA_V[2])
        d.point((rng.randrange(T), y + 3), MADERA_V[1])
    return t

def t_agua(rng, v):
    """Arroyo con ceniza flotando."""
    t = nuevo(T, T, c("3a4a52"))
    ruido(t, (0, 0, T, T), [c("2e3e46"), c("4a5a62")], 0.2, rng)
    d = ImageDraw.Draw(t)
    d.line((2, 5 + v, 7, 5 + v), c("6a7a82")); d.line((9, 11 - v, 13, 11 - v), c("6a7a82"))
    d.point((rng.randrange(T), rng.randrange(T)), CENIZA[4])
    return t

def t_vacio_bosque(rng):
    """Bosque quemado denso (no se puede pasar)."""
    t = nuevo(T, T, c("1a1614"))
    d = ImageDraw.Draw(t)
    for _ in range(4):
        x = rng.randrange(T)
        d.line((x, 0, x + rng.choice((-1, 0, 1)), T), QUEMADO[2])
    for _ in range(3):
        d.point((rng.randrange(T), rng.randrange(T)), CENIZA[3])
    return t

def t_objeto_v(rng, dibujar, fondo=None):
    base = fondo if fondo is not None else t_ceniza(rng, 0)
    capa = nuevo(T, T)
    dibujar(ImageDraw.Draw(capa))
    sombrear(capa); contorno(capa)
    base.alpha_composite(capa)
    return base

def dib_tronco(d):
    d.rectangle((5, 0, 10, 15), QUEMADO[0]); d.line((5, 0, 5, 15), QUEMADO[2])
    d.line((8, 3, 8, 9), QUEMADO[1]); d.point((9, 12), BRASA[2])

def dib_tocon(d):
    d.rectangle((3, 7, 12, 14), QUEMADO[2]); d.ellipse((3, 4, 12, 9), MADERA_V[1]); d.ellipse((5, 5, 10, 8), MADERA_V[0])

def dib_roca(d):
    d.polygon([(1, 13), (3, 5), (8, 2), (13, 4), (15, 12), (12, 15), (3, 15)], CENIZA[3])
    d.line((4, 6, 9, 3), CENIZA[2])

def dib_arbusto(d):
    for (x, y) in ((4, 10), (8, 6), (11, 10), (7, 11)):
        d.line((x, 15, x + 2, y), QUEMADO[2]); d.line((x + 2, y, x + 4, y - 2), QUEMADO[2])

def dib_lena(d):
    for y in (6, 9, 12):
        for x in (1, 6, 11):
            d.ellipse((x, y - 1, x + 4, y + 3), MADERA_V[2]); d.point((x + 2, y + 1), MADERA_V[3])

def dib_cerca(d):
    d.rectangle((0, 6, 15, 7), MADERA_V[0]); d.rectangle((0, 11, 15, 12), MADERA_V[0])
    for x in (2, 13):
        d.rectangle((x, 3, x + 1, 15), MADERA_V[1])

def dib_cerca_v(d):
    d.rectangle((6, 0, 7, 15), MADERA_V[0]); d.rectangle((9, 0, 10, 15), MADERA_V[0])
    for y in (2, 12):
        d.rectangle((5, y, 11, y + 1), MADERA_V[1])

def dib_barril_agua(d):
    d.rectangle((3, 3, 12, 14), MADERA_V[1]); d.line((3, 6, 12, 6), METAL[1]); d.line((3, 11, 12, 11), METAL[1])
    d.ellipse((3, 1, 12, 5), c("3a5a6a"))

def dib_canasto(d):
    d.polygon([(2, 7), (13, 7), (11, 14), (4, 14)], c("a0804a"))
    for x in range(4, 12, 2):
        d.line((x, 8, x, 13), c("806030"))
    d.point((6, 6), c("e04a3a")); d.point((9, 6), VERDE_V[2]); d.point((7, 5), c("e6c34a"))

def tiles_ceniza(rng):
    puente = t_agua(rng, 0)
    dp = ImageDraw.Draw(puente)
    for x in range(0, T, 4):
        dp.rectangle((x, 2, x + 3, 13), MADERA_V[0]); dp.line((x, 2, x, 13), MADERA_V[3])
    return [
        ("ceniza_1", t_ceniza(rng, 0), False), ("ceniza_2", t_ceniza(rng, 1), False), ("ceniza_brote", t_ceniza(rng, 2), False),
        ("sendero_1", t_sendero(rng, 0), False), ("sendero_2", t_sendero(rng, 1), False),
        ("hierba_1", t_hierba(rng, 0), False), ("hierba_2", t_hierba(rng, 1), False),
        ("brasa_1", t_brasa(rng, 0), False), ("brasa_2", t_brasa(rng, 1), False),
        ("huerto", t_huerto(rng), False), ("pasto_verde", t_pasto_verde(rng), False), ("madera", t_madera(rng), False),
        ("agua_1", t_agua(rng, 0), True), ("agua_2", t_agua(rng, 1), True), ("puente", puente, False),
        ("bosque", t_vacio_bosque(rng), True),
        ("tronco", t_objeto_v(rng, dib_tronco), True), ("tocon", t_objeto_v(rng, dib_tocon), True),
        ("roca", t_objeto_v(rng, dib_roca), True), ("arbusto", t_objeto_v(rng, dib_arbusto), True),
        ("lena", t_objeto_v(rng, dib_lena), True), ("cerca", t_objeto_v(rng, dib_cerca), True),
        ("cerca_v", t_objeto_v(rng, dib_cerca_v), True), ("barril_agua", t_objeto_v(rng, dib_barril_agua), True),
        ("canasto", t_objeto_v(rng, dib_canasto, t_sendero(rng, 0)), True),
    ]


# ---------------------------------------------------------------------------
# CONSTRUCCIONES (arte/decorados/*.png). La base es el suelo.
# ---------------------------------------------------------------------------
def tablas(d, x0, y0, x1, y1, rng, cols=MADERA_V):
    for y in range(y0, y1 + 1, 4):
        d.rectangle((x0, y, x1, min(y + 3, y1)), rng.choice(cols[:3]))
        d.line((x0, y, x1, y), cols[3])
        if rng.random() < 0.5:
            d.point((rng.randrange(x0, x1), y + 2), cols[3])

def cabana(seed, ancho_=64, alto_=56, techo=c("4a3a2a"), extra=None):
    """Cabaña de troncos con techo de tablas, chimenea con humito y una ventana con luz cálida."""
    rng = random.Random(seed)
    img = nuevo(ancho_, alto_); d = ImageDraw.Draw(img)
    base = alto_ - 1
    tablas(d, 4, 24, ancho_ - 5, base, rng)
    d.polygon([(0, 26), (ancho_ // 2, 4), (ancho_ - 1, 26)], techo)                       # techo
    for k in range(6, 24, 4):
        d.line((ancho_ // 2 - k, 4 + k, ancho_ // 2 + k, 4 + k), ilum(techo, 0.75))
    d.line((0, 26, ancho_ // 2, 4), ilum(techo, 1.3)); d.line((ancho_ // 2, 4, ancho_ - 1, 26), ilum(techo, 0.7))
    cx = ancho_ - 16
    d.rectangle((cx, 6, cx + 5, 18), c("5a5450")); d.line((cx, 6, cx + 5, 6), c("7a746e"))  # chimenea de piedra
    px = ancho_ // 2
    d.rectangle((px - 6, base - 16, px + 6, base), MADERA_V[3]); d.rectangle((px - 5, base - 15, px + 5, base), MADERA_V[1])
    d.point((px + 3, base - 8), c("e6c34a"))
    for wx in (10, ancho_ - 22):
        d.rectangle((wx, 32, wx + 10, 41), MADERA_V[3]); d.rectangle((wx + 1, 33, wx + 9, 40), c("ffc46a"))
        d.line((wx + 5, 33, wx + 5, 40), MADERA_V[3]); d.line((wx + 1, 36, wx + 9, 36), MADERA_V[3])
    if extra:
        extra(d, rng)
    return terminar(img, 1.1, 0.78)

def cabana_kael():
    def extra(d, rng):
        # cornamenta sobre la puerta, pieles colgando y el escudo roto de Kael
        d.line((30, 30, 36, 26), c("d8ccb4")); d.line((42, 30, 36, 26), c("d8ccb4"))
        d.line((31, 28, 29, 25), c("d8ccb4")); d.line((41, 28, 43, 25), c("d8ccb4"))
        d.ellipse((58, 40, 66, 48), METAL[2]); d.line((60, 41, 64, 47), METAL[3])
        d.rectangle((4, 44, 9, 55), c("7a6050")); d.rectangle((5, 45, 8, 50), c("8a7060"))
    return cabana(41, 72, 60, c("3e3024"), extra)

def invernadero():
    """El invernadero que cuida Lucía: vidrios remendados y plantas verdes de verdad."""
    rng = random.Random(51)
    img = nuevo(80, 56); d = ImageDraw.Draw(img)
    d.rectangle((2, 50, 77, 55), MADERA_V[1])
    d.polygon([(2, 50), (2, 18), (40, 4), (77, 18), (77, 50)], (170, 210, 220, 120))      # vidrio
    for x in range(2, 78, 12):
        d.line((x, 50, x, 18 - (x if x < 40 else 80 - x) * 14 // 40 + 2), MADERA_V[1])
    d.line((2, 18, 40, 4), MADERA_V[1]); d.line((40, 4, 77, 18), MADERA_V[1]); d.line((2, 30, 77, 30), MADERA_V[1])
    for x in range(6, 74, 5):                                                              # plantas adentro
        alto = rng.randint(8, 16)
        d.line((x, 49, x, 49 - alto), VERDE_V[3])
        d.ellipse((x - 3, 49 - alto - 3, x + 3, 49 - alto + 3), rng.choice(VERDE_V[:3]))
        if rng.random() < 0.3:
            d.point((x, 49 - alto), rng.choice([c("e04a3a"), c("e6c34a")]))               # tomates y flores
    d.rectangle((34, 34, 46, 50), (120, 90, 60, 255)); d.rectangle((35, 35, 45, 50), (150, 200, 210, 140))   # puerta
    d.rectangle((14, 20, 22, 26), (90, 80, 70, 200))                                       # vidrio remendado con tabla
    return terminar(img, 1.06, 0.82)

def monumento():
    """Monumento a los caídos: tablas con nombres tallados, flores frescas y velas."""
    rng = random.Random(61)
    img = nuevo(44, 56); d = ImageDraw.Draw(img)
    d.rectangle((2, 46, 41, 55), c("5a5450")); d.line((2, 46, 41, 46), c("7a746e"))       # base de piedra
    d.rectangle((14, 6, 29, 46), MADERA_V[1]); d.rectangle((15, 7, 28, 45), MADERA_V[0])
    d.polygon([(12, 6), (22, 0), (31, 6)], MADERA_V[3])
    d.rectangle((6, 14, 37, 18), MADERA_V[1])                                              # travesaño
    for y in range(22, 44, 4):                                                             # nombres tallados
        d.line((17, y, 17 + rng.randint(5, 9), y), MADERA_V[3])
    for x in (5, 9, 33, 37):
        d.line((x, 46, x, 42), VERDE_V[3]); d.point((x, 41), rng.choice([c("f0e0f0"), c("e6c34a"), c("e07a8a")]))
    for x in (12, 30):
        d.rectangle((x, 43, x + 1, 46), c("e8e0c8")); d.point((x, 41), c("ffd27a")); d.point((x, 42), c("ff9a3a"))
    d.ellipse((19, 9, 24, 13), METAL[2])                                                   # un casco colgado
    return terminar(img, 1.08, 0.8)

def olla_comun():
    """La olla común sobre el fuego (3 cuadros de 40x40): el vapor sube y las llamas bailan."""
    hoja = nuevo(40 * 3, 40)
    for f in range(3):
        img = nuevo(40, 40); d = ImageDraw.Draw(img)
        for x in (6, 33):
            d.line((x, 39, 20, 10), MADERA_V[3], 2)                                        # trípode
        d.line((20, 10, 20, 18), METAL[3])
        d.ellipse((9, 18, 31, 34), METAL[3]); d.ellipse((10, 18, 30, 24), METAL[1]); d.ellipse((12, 19, 28, 23), c("8a6a3a"))
        for i, x in enumerate((12, 18, 24, 28)):                                           # llamas
            alto = 4 + ((f + i) % 3) * 2
            d.polygon([(x - 2, 39), (x, 39 - alto - 2), (x + 3, 39)], BRASA[(f + i) % 2])
        for i in range(3):                                                                 # vapor
            y = 14 - ((f * 4 + i * 5) % 12)
            x = 16 + i * 4 + (f % 2)
            d.ellipse((x - 2, y - 2, x + 2, y + 2), (230, 230, 230, 120))
        hoja.alpha_composite(img, (f * 40, 0))
    return hoja

def lenera():
    rng = random.Random(71)
    img = nuevo(40, 28); d = ImageDraw.Draw(img)
    d.rectangle((2, 4, 37, 6), MADERA_V[3]); d.line((3, 6, 3, 27), MADERA_V[1]); d.line((36, 6, 36, 27), MADERA_V[1])
    for y in range(9, 27, 5):
        for x in range(4, 34, 5):
            d.ellipse((x, y, x + 4, y + 4), rng.choice(MADERA_V[:3])); d.point((x + 2, y + 2), MADERA_V[3])
    d.line((30, 2, 38, 10), METAL[2]); d.rectangle((35, 0, 38, 3), METAL[1])               # hacha clavada
    return terminar(img)

def arco_valle():
    """Arco de troncos a la entrada del pueblo con el letrero tallado."""
    img = nuevo(112, 56); d = ImageDraw.Draw(img)
    for x in (6, 98):
        d.rectangle((x, 8, x + 7, 55), MADERA_V[1]); d.line((x, 8, x, 55), MADERA_V[2])
    d.rectangle((0, 6, 111, 12), MADERA_V[0]); d.line((0, 6, 111, 6), MADERA_V[2])
    d.rectangle((24, 14, 87, 26), MADERA_V[2]); d.rectangle((24, 14, 87, 26), outline=MADERA_V[3])
    d.line((30, 12, 30, 14), METAL[1]); d.line((82, 12, 82, 14), METAL[1])
    escribir(d, 56 - ancho("VALLE CENIZA") // 2, 18, "VALLE CENIZA", MADERA_V[3])
    for x in (4, 16, 94, 106):                                                             # enredaderas verdes
        for y in range(16, 54, 6):
            d.point((x + (y // 6) % 2, y), VERDE_V[(y // 6) % 3])
    return terminar(img, 1.08, 0.8)

def puesto_caza():
    """Donde Kael limpia lo que caza para todo el pueblo: pieles, un arco y un cuchillo."""
    img = nuevo(48, 44); d = ImageDraw.Draw(img)
    for x in (3, 42):
        d.rectangle((x, 6, x + 3, 43), MADERA_V[1])
    d.polygon([(0, 8), (24, 0), (47, 8)], c("5a4a3a"))
    d.line((4, 14, 44, 14), MADERA_V[3])
    for x in (10, 22, 34):                                                                 # pieles
        d.polygon([(x - 4, 14), (x + 4, 14), (x + 5, 26), (x, 30), (x - 5, 26)], c("8a7060"))
        d.line((x, 16, x, 27), c("6a5040"))
    d.rectangle((8, 34, 40, 37), MADERA_V[0])                                              # mesa
    d.arc((30, 18, 46, 42), 260, 100, MADERA_V[2]); d.line((40, 19, 40, 41), c("d8d0c0"))  # arco de caza
    return terminar(img)

def arbol(seed, con_brote=False):
    """Árbol quemado (32x64). Con brote: le salieron hojas verdes nuevas."""
    rng = random.Random(seed)
    img = nuevo(32, 64); d = ImageDraw.Draw(img)
    d.polygon([(13, 63), (14, 20), (18, 20), (19, 63)], QUEMADO[0])
    d.line((14, 63, 14, 20), QUEMADO[2])
    for (x0, y0, x1, y1) in ((16, 30, 5, 18), (16, 26, 27, 12), (16, 40, 26, 30), (16, 22, 12, 6), (8, 22, 3, 14)):
        d.line((x0, y0, x1, y1), QUEMADO[0], 2)
    d.point((15, 50), BRASA[2]) if not con_brote else None
    if con_brote:
        for (x, y) in ((5, 17), (27, 11), (12, 5), (25, 29), (3, 13)):
            d.ellipse((x - 3, y - 2, x + 3, y + 2), rng.choice(VERDE_V[:3]))
            d.point((x, y - 1), VERDE_V[2])
    return terminar(img, 1.06, 0.82)

def pozo():
    img = nuevo(28, 32); d = ImageDraw.Draw(img)
    d.ellipse((2, 18, 25, 31), c("5a5450")); d.ellipse((6, 20, 21, 27), c("1a2228"))
    for x in (3, 23):
        d.rectangle((x, 4, x + 2, 24), MADERA_V[1])
    d.polygon([(0, 6), (14, 0), (27, 6)], MADERA_V[3]); d.line((5, 10, 22, 10), MADERA_V[2])
    d.line((14, 10, 14, 18), c("a0906a")); d.rectangle((12, 18, 16, 21), MADERA_V[0])
    return terminar(img)

def tendedero():
    img = nuevo(48, 28); d = ImageDraw.Draw(img)
    for x in (2, 45):
        d.rectangle((x, 2, x + 1, 27), MADERA_V[1])
    d.line((3, 4, 45, 6), c("c8c0b0"))
    for i, x in enumerate((8, 18, 28, 37)):
        col = [c("8a5a4a"), c("4a6a8a"), c("c8c0a0"), c("6a8a4a")][i]
        d.rectangle((x, 5, x + 6, 14 + (i % 2) * 3), col)
    return terminar(img)

def carreta_org():
    """Carreta de la Organización (el recaudador que viene a cobrar al valle)."""
    img = nuevo(48, 32); d = ImageDraw.Draw(img)
    d.rectangle((4, 8, 43, 22), c("2a2a30")); d.rectangle((4, 8, 43, 10), c("3a3a44"))
    d.rectangle((16, 12, 31, 18), c("8a1a1a")); d.line((18, 15, 29, 15), c("e0e0e0"))      # sello de la Organización
    for x in (12, 36):
        d.ellipse((x - 6, 20, x + 6, 31), METAL[3]); d.ellipse((x - 2, 24, x + 2, 27), METAL[1])
    d.rectangle((6, 2, 20, 8), c("6a5a40")); d.rectangle((24, 3, 40, 8), c("5a6a3a"))     # lo que se llevan (comida)
    return terminar(img)

def espantapajaros():
    img = nuevo(20, 32); d = ImageDraw.Draw(img)
    d.line((10, 8, 10, 31), MADERA_V[1]); d.line((2, 12, 18, 12), MADERA_V[1])
    d.ellipse((6, 1, 14, 9), c("c8b080")); d.polygon([(4, 3), (10, -1), (16, 3)], c("8a6a3a"))
    d.rectangle((6, 11, 14, 22), c("6a4a6a")); d.point((8, 5), c("2a2020")); d.point((12, 5), c("2a2020"))
    return terminar(img)

def generar_decorados():
    guardar(cabana(31), "decorados/cabana_1.png")
    guardar(cabana(32, techo=c("5a3a2a")), "decorados/cabana_2.png")
    guardar(cabana(33, 56, 52, c("4a4030")), "decorados/cabana_3.png")
    guardar(cabana_kael(), "decorados/cabana_kael.png")
    guardar(invernadero(), "decorados/invernadero.png")
    guardar(monumento(), "decorados/monumento.png")
    guardar(olla_comun(), "decorados/olla_comun.png")
    guardar(lenera(), "decorados/lenera.png")
    guardar(arco_valle(), "decorados/arco_valle.png")
    guardar(puesto_caza(), "decorados/puesto_caza.png")
    guardar(arbol(81), "decorados/arbol_quemado.png")
    guardar(arbol(82, True), "decorados/arbol_brote.png")
    guardar(pozo(), "decorados/pozo.png")
    guardar(tendedero(), "decorados/tendedero.png")
    guardar(carreta_org(), "decorados/carreta_org.png")
    guardar(espantapajaros(), "decorados/espantapajaros.png")


# ---------------------------------------------------------------------------
# PERSONAS DEL VALLE (16x24): ropa de lana, pañuelos, delantales, manos de trabajar
# ---------------------------------------------------------------------------
pf = g.persona_frente

def aldeano_mapa():
    def extra(d, dy):
        d.rectangle((3, 11 + dy, 7, 13 + dy), c("6a4a3a"))                          # chaleco de lana
    return pf(c("b8865e"), c("3a2a1a"), "corto", c("5a6a4a"), c("44523a"), c("4a3a2a"), c("2a1e14"), extra=extra)

def aldeana_mapa():
    def extra(d, dy):
        d.rectangle((3, 1 + dy, 7, 2 + dy), c("8a3a3a"))                            # pañuelo en la cabeza
        d.rectangle((4, 13, 7, 17), c("c8b890"))                                    # delantal
    return pf(c("c8966e"), c("4a2a1a"), "largo", c("6a5a7a"), c("4a3e5a"), c("4a3a2a"), c("2a1e14"), extra=extra)

def nita_mapa():
    """La abuela Nita: chal tejido, pelo blanco en moño, encorvada."""
    def extra(d, dy):
        d.rectangle((2, 11 + dy, 7, 14 + dy), c("8a4a5a")); d.point((4, 12 + dy), c("c8a8b0"))   # chal
        d.rectangle((4, 0 + dy, 6, 1 + dy), c("e8e4dc"))                                         # moño
    return pf(c("c8a080"), c("e8e4dc"), "corto", c("5a4a5a"), c("443a44"), c("3a3030"), c("2a1e14"), extra=extra, encorvado=True)

def lucia_mapa():
    """Lucía, la del invernadero: sombrero de paja y delantal verde con tierra."""
    def extra(d, dy):
        d.rectangle((4, 13, 7, 17), VERDE_V[3]); d.point((5, 16), c("6a4a2a"))
    def despues(d, dy):
        d.rectangle((2, 1 + dy, 13, 2 + dy), c("d8b86a")); d.rectangle((4, 0 + dy, 11, 1 + dy), c("c8a85a"))   # sombrero
    return pf(c("a87a58"), c("2a1a10"), "largo", c("e8dcc0"), c("c8bca0"), c("4a3a2a"), c("2a1e14"), extra=extra, despues=despues)

def hugo_mapa():
    """Hugo, el de la despensa: grande, delantal de cuero, sonrisa fácil."""
    def extra(d, dy):
        d.rectangle((2, 11, 7, 17), c("7a5a3a")); d.rectangle((3, 13, 7, 17), c("8a6a48"))
        d.rectangle((4, 8, 7, 9), c("4a3020"))                                      # barba
    return pf(c("c08a60"), c("4a3020"), "corto", c("7a5a3a"), c("5a402a"), c("3a3028"), c("2a1e14"), extra=extra)

def ramiro_mapa():
    """Ramiro, el leñador: camisa a cuadros y un hacha al hombro."""
    def extra(d, dy):
        for y in (12, 14, 16):
            d.line((3, y, 7, y), c("6a1a1a"))
    def despues(d, dy):
        d.line((12, 4, 13, 18), MADERA_V[1]); d.rectangle((11, 3, 14, 6), METAL[2])
    return pf(c("b07a50"), c("6a4a2a"), "corto", c("a83a3a"), c("7a2a2a"), c("3a3a4a"), c("2a1e14"), extra=extra, despues=despues)

def ana_mapa():
    """Ana, la esposa de Kael: trenza larga y un chal verde musgo."""
    def extra(d, dy):
        d.rectangle((2, 11 + dy, 7, 13 + dy), c("4a5a3a"))
    def despues(d, dy):
        d.rectangle((12, 4 + dy, 12, 15 + dy), c("3a2a1a")); d.point((12, 16 + dy), c("8a3a3a"))   # trenza
    return pf(c("c8966e"), c("3a2a1a"), "corto", c("7a6a5a"), c("5a4e44"), c("4a3a2a"), c("2a1e14"), extra=extra, despues=despues)

def teo_mapa():
    """Teo, el hijo de Kael: lleva un escudito de madera igual al de su papá."""
    def despues(d):
        d.ellipse((10, 13, 14, 18), MADERA_V[0]); d.point((12, 15), METAL[2])
    return ab.nino_frente(c("b8865e"), c("4a3a2a"), c("5a6a4a"), c("44523a"), c("4a3a2a"), c("2a1e14"), despues=despues)

def nina_valle_mapa():
    def extra(d):
        d.point((4, 15), c("e07a8a"))                                               # florcita
    return ab.nino_frente(c("c8966e"), c("2a1a10"), c("8a5a6a"), c("6a4450"), c("4a3a2a"), c("2a1e14"), extra=extra, coletas=True)

KAEL_P = c("b8865e"); KAEL_PELO = c("4a4440"); KAEL_ARM = c("6e6a62"); KAEL_ARM2 = c("4e4a44")

def kael_mapa():
    """Kael: grande, barba gris, armadura gastada con un escudo roto a la espalda."""
    def extra(d, dy):
        d.rectangle((2, 11, 7, 17), KAEL_ARM); d.line((2, 11, 7, 11), c("8a867e"))     # peto
        d.rectangle((4, 8, 7, 10), c("6a645e"))                                          # barba
        d.point((3, 2), c("9a948c"))                                                     # canas
    def despues(d, dy):
        d.ellipse((11, 9, 15, 15), METAL[3]); d.line((12, 10, 14, 14), METAL[1])         # escudo roto
    return pf(KAEL_P, KAEL_PELO, "corto", KAEL_ARM, KAEL_ARM2, c("3a3630"), c("2a2420"), ojo=c("6a7a8a"), extra=extra, despues=despues)

def de_rodillas_mapa(img):
    """Toma un sprite de 16x24 y lo pone de rodillas (cabeza gacha, piernas dobladas)."""
    out = nuevo(16, 24)
    torso = img.crop((0, 0, 16, 18))
    out.alpha_composite(torso, (0, 5))
    d = ImageDraw.Draw(out)
    d.rectangle((3, 22, 12, 23), c("3a3630")); d.rectangle((2, 22, 3, 23), c("2a2420")); d.rectangle((12, 22, 13, 23), c("2a2420"))
    d.line((5, 10, 10, 10), c("1b161c"))                                                 # cabeza gacha (sombra)
    return out

def kael_combate():
    def extra(d):
        d.polygon([(6, 17), (15, 16), (15, 32), (7, 32)], KAEL_ARM)                   # peto gastado
        d.line((9, 20, 13, 26), KAEL_ARM2)
        d.polygon([(10, 12), (15, 12), (15, 16), (12, 15)], c("6a645e"))             # barba
        d.point((10, 4), c("9a948c")); d.point((12, 3), c("9a948c"))
    def despues(d):
        d.ellipse((22, 18, 31, 31), METAL[3]); d.ellipse((23, 19, 30, 30), METAL[1])  # escudo roto
        d.line((25, 19, 28, 30), c("1b161c")); d.line((26, 22, 29, 24), c("1b161c"))
        d.line((1, 20, 1, 38), MADERA_V[1]); d.polygon([(0, 18), (1, 14), (3, 18)], METAL[2])   # lanza de caza
        d.line((17, 5, 19, 8), c("8a5a40"))                                            # cicatriz
    return figura(KAEL_P, KAEL_PELO, "corto", KAEL_ARM, KAEL_ARM2, c("3a3630"), c("2a2420"), ojos=c("6a7a8a"), extra=extra, despues=despues)

def kael_rodillas_combate():
    """Kael de rodillas, sin armas, llorando (32x48)."""
    de_pie = kael_combate()
    out = nuevo(32, 48)
    torso = de_pie.crop((0, 0, 32, 32))
    out.alpha_composite(torso, (0, 10))
    d = ImageDraw.Draw(out)
    d.rectangle((7, 40, 25, 45), c("3a3630")); d.rectangle((5, 44, 10, 47), c("2a2420")); d.rectangle((22, 44, 27, 47), c("2a2420"))
    d.rectangle((0, 22, 5, 44), (0, 0, 0, 0))                                            # soltó la lanza
    d.rectangle((21, 26, 31, 42), (0, 0, 0, 0))                                          # y el escudo
    d.point((14, 21), c("9ad0ff")); d.point((14, 22), c("9ad0ff")); d.point((18, 21), c("9ad0ff"))   # lágrimas
    d = ImageDraw.Draw(out)
    d.line((26, 46, 31, 44), MADERA_V[1]); d.ellipse((0, 40, 6, 46), METAL[3])           # armas en el suelo
    return out

def recaudador_combate():
    def extra(d):
        d.polygon([(6, 17), (15, 16), (15, 32), (7, 32)], c("2a2a30"))
        d.rectangle((8, 20, 12, 23), c("8a1a1a"))
    def despues(d):
        d.line((22, 20, 30, 14), METAL[2], 2)                                           # porra
    return figura(c("c8966e"), c("1a1a1e"), "corto", c("2a2a30"), c("1e1e24"), c("1e1e24"), c("101014"), ojos=c("3a2a2a"), extra=extra, despues=despues)

def recaudador_mapa():
    def extra(d, dy):
        d.rectangle((3, 11, 7, 17), c("2a2a30")); d.point((4, 13), c("8a1a1a"))
    def despues(d, dy):
        d.line((12, 12, 14, 18), METAL[2])
    return pf(c("c8966e"), c("1a1a1e"), "corto", c("2a2a30"), c("1e1e24"), c("1e1e24"), c("101014"), extra=extra, despues=despues)

def retrato_simple(*a, **k):
    import arte_neon
    return arte_neon.retrato_simple(*a, **k)

def retrato_nita():
    def det(d):
        d.ellipse((20, 4, 28, 10), c("e8e4dc"))                                         # moño
        d.line((15, 28, 19, 29), c("a8805e")); d.line((28, 28, 32, 29), c("a8805e"))     # arrugas
        d.polygon([(4, 47), (10, 38), (38, 38), (44, 47)], c("8a4a5a"))                  # chal
    return retrato_simple(c("c8a080"), c("e8e4dc"), c("5a4a5a"), c("443a44"), c("3a3030"), c("4a3a2a"), "triste", "sonrisa", det, True)

def retrato_lucia():
    def det(d):
        d.rectangle((6, 6, 41, 9), c("d8b86a")); d.rectangle((12, 1, 35, 7), c("c8a85a"))   # sombrero de paja
        d.point((30, 31), c("6a4a2a"))                                                        # tierra en la mejilla
    return retrato_simple(c("a87a58"), c("2a1a10"), c("e8dcc0"), c("c8bca0"), c("2a3a24"), c("3a2a10"), "fina", "sonrisa", det, True)

def retrato_hugo():
    def det(d):
        d.polygon([(14, 30), (17, 37), (24, 40), (31, 37), (34, 30), (30, 33), (18, 33)], c("4a3020"))   # barba
    return retrato_simple(c("c08a60"), c("4a3020"), c("7a5a3a"), c("5a402a"), c("3a2a1e"), c("3a2a10"), "recta", "sonrisa", det)

def retrato_teo():
    return retrato_simple(c("b8865e"), c("4a3a2a"), c("5a6a4a"), c("44523a"), c("2a3424"), c("6a7a8a"), "triste", "triste")

def retrato_ana():
    def det(d):
        d.polygon([(4, 47), (10, 39), (38, 39), (44, 47)], c("4a5a3a"))
    return retrato_simple(c("c8966e"), c("3a2a1a"), c("7a6a5a"), c("5a4e44"), c("2a2a24"), c("3a2a10"), "triste", "seria", det, True)

def retrato_ramiro():
    def det(d):
        for y in (40, 43, 46):
            d.line((4, y, 44, y), c("7a2a2a"))
    return retrato_simple(c("b07a50"), c("6a4a2a"), c("a83a3a"), c("7a2a2a"), c("2e2a22"), c("3a2a10"), "recta", "seria", det)

def retrato_kael_llora():
    img = g.retrato_kael()
    d = ImageDraw.Draw(img)
    for (x, y) in ((17, 27), (17, 29), (30, 27), (30, 30), (31, 32)):
        d.point((x, y), c("9ad0ff"))
    return img

def retrato_recaudador():
    def det(d):
        d.rectangle((14, 40, 20, 44), c("8a1a1a"))
    return retrato_simple(c("c8966e"), c("1a1a1e"), c("2a2a30"), c("1e1e24"), c("1a1418"), c("2a1a1a"), "enojo", "seria", det)

# Primeros planos de Pan (96x96) para el momento de la decisión
def pan_cerca():
    return g.pan_hd()

def pan_cerca_piedad():
    """Los ojos de Pan se suavizan: párpados un poco más bajos y un brillo húmedo."""
    img = g.pan_hd()
    d = ImageDraw.Draw(img)
    for cx in (37, 58):
        d.line((cx - 6, 44, cx + 6, 44), c("141018"))                              # párpado más bajo (mirada suave)
        d.line((cx - 5, 45, cx + 5, 45), c("141018"))
        d.point((cx - 2, 49), c("bfeaff")); d.point((cx + 2, 49), c("bfeaff"))       # brillo de lágrima
    d.line((40, 68, 56, 68), g.acl(g.PAN_P, 0.72))                                    # boca más relajada
    return img

def pan_cerca_sombra():
    """La sombra del pelo cubre los ojos de Pan: solo se ve el brillo verde."""
    img = g.pan_hd()
    capa = nuevo(96, 96)
    d = ImageDraw.Draw(capa)
    d.polygon([(16, 24), (80, 24), (84, 50), (78, 58), (72, 53), (66, 60), (58, 54), (48, 57), (38, 53), (30, 60),
               (24, 53), (18, 58), (12, 50)], (6, 6, 10, 235))                         # mechones que tapan los ojos
    img.alpha_composite(capa)
    d = ImageDraw.Draw(img)
    for cx in (37, 58):
        d.ellipse((cx - 3, 45, cx + 3, 49), (47, 208, 122, 90))                     # halo
        d.line((cx - 2, 47, cx + 2, 47), c("2fd07a")); d.point((cx, 47), c("b8ffd8"))
    return img

def generar_personas():
    for nombre, f in (("aldeano_mapa", aldeano_mapa), ("aldeana_mapa", aldeana_mapa), ("nita_mapa", nita_mapa),
                      ("lucia_mapa", lucia_mapa), ("hugo_mapa", hugo_mapa), ("ramiro_mapa", ramiro_mapa),
                      ("ana_mapa", ana_mapa), ("teo_mapa", teo_mapa), ("nina_valle_mapa", nina_valle_mapa),
                      ("kael_mapa", kael_mapa), ("kael_combate", kael_combate),
                      ("kael_rodillas_combate", kael_rodillas_combate),
                      ("recaudador_mapa", recaudador_mapa), ("recaudador_combate", recaudador_combate)):
        guardar(f(), f"personajes/{nombre}.png")
    guardar(de_rodillas_mapa(kael_mapa()), "personajes/kael_rodillas_mapa.png")
    for nombre, f in (("nita", retrato_nita), ("lucia", retrato_lucia), ("hugo", retrato_hugo), ("teo", retrato_teo),
                      ("ana", retrato_ana), ("ramiro", retrato_ramiro), ("kael_llora", retrato_kael_llora),
                      ("recaudador", retrato_recaudador)):
        guardar(f(), f"retratos/{nombre}.png")
    for nombre, f in (("pan_cerca", pan_cerca), ("pan_cerca_piedad", pan_cerca_piedad), ("pan_cerca_sombra", pan_cerca_sombra)):
        guardar(f(), f"cinematica/{nombre}.png")


# ---------------------------------------------------------------------------
# ICONOS
# ---------------------------------------------------------------------------
def icono_codigos():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((2, 3, 13, 13), c("2a3a2a")); d.rectangle((3, 4, 12, 12), c("1a2a1a"))
    for y in (5, 7, 9, 11):
        d.line((4, y, 4 + (y * 3) % 7 + 3, y), c("7aff9a"))
    contorno(img)
    return img

def icono_mapa_deb():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.polygon([(1, 3), (5, 2), (10, 4), (14, 3), (14, 13), (10, 14), (5, 12), (1, 13)], c("d8c8a0"))
    d.line((5, 2, 5, 12), c("b8a880")); d.line((10, 4, 10, 14), c("b8a880"))
    d.line((3, 10, 7, 7, 11, 9), c("8a3a3a")); d.line((11, 6, 13, 8), c("e04a4a")); d.line((13, 6, 11, 8), c("e04a4a"))
    contorno(img)
    return img

def icono_grabacion():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((1, 4, 14, 12), c("3a3a44")); d.rectangle((3, 5, 12, 8), c("e8e0c8"))
    d.ellipse((4, 8, 7, 11), METAL[4]); d.ellipse((9, 8, 12, 11), METAL[4])
    d.point((5, 9), c("1a1a1e")); d.point((10, 9), c("1a1a1e")); d.line((4, 6, 11, 6), c("a35ae0"))
    contorno(img)
    return img

def icono_brote():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.ellipse((3, 10, 12, 15), c("5a4a3a")); d.line((7, 11, 7, 5), VERDE_V[3])
    d.ellipse((2, 3, 7, 7), VERDE_V[0]); d.ellipse((7, 1, 13, 6), VERDE_V[2])
    contorno(img)
    return img

def generar_iconos():
    guardar(icono_codigos(), "objetos/codigos_capital.png")
    guardar(icono_mapa_deb(), "objetos/mapa_debilidades.png")
    guardar(icono_grabacion(), "objetos/grabacion_padres.png")
    guardar(icono_brote(), "objetos/brote.png")


# ---------------------------------------------------------------------------
# FONDOS DE COMBATE
# ---------------------------------------------------------------------------
def fondo_bosque():
    """Bosque calcinado: troncos negros, cielo gris y ceniza que cae como nieve."""
    rng = random.Random(401)
    hz = 108
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("4a4448"), c("5a5456"), c("6a6462"), c("7a726c"), c("8a7e72")])
    capa = nuevo(W, H); d = ImageDraw.Draw(capa)
    d.ellipse((60, 20, 100, 60), (230, 210, 180, 70))                                   # sol apagado detrás del humo
    cielo.alpha_composite(capa)
    nubes = g.nubes_capa(rng, [(110, 104, 100, 120), (130, 124, 118, 100), (90, 84, 82, 120)], n=16)
    lejos = nuevo(W, H)
    d = ImageDraw.Draw(lejos)
    for _ in range(60):                                                                  # troncos lejanos
        x = rng.randrange(W); alto = rng.randint(30, 80)
        d.line((x, hz + 2, x, hz - alto), c("3a3432"), rng.choice((1, 2)))
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    for x in (20, 90, 300, 420, 460):                                                    # troncos cercanos
        alto = rng.randint(90, 120)
        d.rectangle((x, hz - alto, x + rng.randint(5, 9), hz + 6), QUEMADO[0])
        d.line((x + 3, hz - alto + 30, x + 18, hz - alto + 10), QUEMADO[0], 2)
        if rng.random() < 0.5:
            d.point((x + 2, hz - 20), BRASA[0])
    for _ in range(90):                                                                  # ceniza cayendo
        x, y = rng.randrange(W), rng.randrange(0, hz + 40)
        d.point((x, y), (220, 216, 210, 170))
    suelo = nuevo(W, H)
    def det(d):
        for _ in range(30):
            x, y = rng.randrange(W), rng.randrange(hz + 10, H)
            d.point((x, y), rng.choice([CENIZA[4], QUEMADO[0], BRASA[2]]))
        for x in (40, 230, 400):
            d.line((x, hz + 40, x + 6, hz + 38), VERDE_V[1]); d.point((x + 6, hz + 37), VERDE_V[2])   # brotes
    def matas(d, x, y):
        d.line((x, y, x - 1, y - 4), c("6a5a44")); d.line((x + 1, y, x + 2, y - 3), c("4a4034"))
    suelo_propio(suelo, rng, hz, CENIZA[0], CENIZA[3], CENIZA[2], det,
                 (c("2e2a26"), (CENIZA[2], CENIZA[4]), [CENIZA[0], CENIZA[1], c("4a4034")], matas))
    return cielo, nubes, lejos, medio, suelo, []

def fondo_valle():
    """El claro del monumento al atardecer: cabañas, el invernadero a lo lejos y ceniza que cae despacio."""
    rng = random.Random(411)
    hz = 108
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("3a3446"), c("5a4a56"), c("8a6a5e"), c("b88a64"), c("d0a070")])
    nubes = g.nubes_capa(rng, [(120, 100, 110, 110), (150, 120, 120, 90)], n=12)
    lejos = nuevo(W, H)
    d = ImageDraw.Draw(lejos)
    pts = [(0, hz - 30)]
    for x in range(0, W + 40, 40):
        pts.append((x, hz - 30 - rng.randint(0, 26)))
    pts += [(W, hz + 4), (0, hz + 4)]
    d.polygon(pts, c("4a4048"))                                                          # cerros
    for x in range(0, W, 9):
        d.line((x, hz - 4, x + rng.choice((-1, 1)), hz - 4 - rng.randint(6, 18)), c("3a3238"))
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    for (x, w) in ((30, 50), (380, 56)):                                                 # cabañas
        d.rectangle((x, hz - 24, x + w, hz + 4), MADERA_V[1]); d.polygon([(x - 4, hz - 22), (x + w // 2, hz - 44), (x + w + 4, hz - 22)], c("4a3a2a"))
        d.rectangle((x + 8, hz - 14, x + 16, hz - 6), c("ffc46a"))
    d.rectangle((228, hz - 60, 252, hz + 4), MADERA_V[1]); d.polygon([(224, hz - 60), (240, hz - 70), (256, hz - 60)], MADERA_V[3])   # monumento
    d.rectangle((214, hz - 48, 266, hz - 44), MADERA_V[1])
    for x in (220, 232, 246, 258):
        d.point((x, hz + 2), rng.choice([c("f0e0f0"), c("e6c34a"), c("e07a8a")]))
    for _ in range(50):
        x, y = rng.randrange(W), rng.randrange(0, hz + 40)
        d.point((x, y), (230, 226, 220, 150))
    suelo = nuevo(W, H)
    def det(d):
        for _ in range(26):
            x, y = rng.randrange(W), rng.randrange(hz + 10, H)
            d.line((x, y, x, y - 2), rng.choice([VERDE_V[1], VERDE_V[3], CENIZA[2]]))
    def matas(d, x, y):
        d.line((x, y, x, y - 3), VERDE_V[1]); d.point((x + 1, y - 3), VERDE_V[2])
    suelo_propio(suelo, rng, hz, c("5a5a4a"), c("44443a"), c("6a6a58"), det,
                 (c("2e2e26"), (c("6a6a58"), c("7a7a66")), [c("5a5a4a"), VERDE_V[3], CENIZA[2]], matas))
    return cielo, nubes, lejos, medio, suelo, []


def generar_tiles_valle():
    rng = random.Random(444)
    registro = {}
    g.armar_atlas(tiles_ceniza(rng), "tiles/ceniza.png", registro)
    return registro


def generar():
    generar_decorados()
    generar_personas()
    generar_iconos()
