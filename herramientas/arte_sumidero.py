"""
Arte de la Ciudad 2: EL SUMIDERO (Comandante Dra. Vesper) y el camino para llegar.
Lo llama herramientas/generar_pixel_art.py (no hace falta correrlo solo).

  - atlas nuevo "subterraneo" (túneles del metro, pasarelas podridas, ríos de lodo tóxico,
    hongos bioluminiscentes, el laboratorio blanco de Vesper...)
  - tiles nuevos del exterior para la Autopista Quemada (pasto de ceniza, baranda, asfalto roto)
  - construcciones grandes (vagones-casa, laboratorio, tanque envenenado, ventanilla del antídoto...)
  - vecinos del Sumidero, Vesper, guardias de la Organización y cazadores furtivos (mapa, combate, retratos)
  - criaturas nuevas: Lobo de Ceniza, Cazador Camuflado, Tejedor de Sombras, Burbuja Tóxica,
    Sirena de Fango, Guardián de Flora y Humanoide sin Consciencia
  - iconos (antídoto, máscara de filtro, molotov, frasco de veneno) y fondos de combate
"""
import math
import random

from PIL import Image, ImageDraw

from generar_pixel_art import *   # noqa: F401,F403  (colores y ayudantes: c, nuevo, contorno, sombrear...)
import generar_pixel_art as g

ROCA = [c("2c2636"), c("221d2b"), c("3a3247"), c("16121c"), c("4a405a")]
AZULEJO = [c("8c9a8a"), c("6e7c6e"), c("a8b4a2"), c("4c584e"), c("c2ccb8")]
LODO = [c("3c5a1e"), c("4e7226"), c("6a9a2e"), c("2a4014"), c("b6f06a")]
PODRIDA = [c("5c4a32"), c("47392a"), c("70593c"), c("2f261c"), c("4a6a2a")]
LAB = [c("e6ebe4"), c("cdd6cf"), c("b2bdb6"), c("8e9a94"), c("ffffff")]
VIOLETA = [c("6a3a8a"), c("4a2a66"), c("8a5ab0"), c("2e1a44")]
CIAN = c("5af0e0"); MORADO = c("c08aff"); VERDE_L = c("9cf05a")
METRO = [c("5a6e7a"), c("44565f"), c("7a909a"), c("2e3a40")]


def ilum(col, f):
    return (min(255, int(col[0] * f)), min(255, int(col[1] * f)), min(255, int(col[2] * f)), col[3] if len(col) > 3 else 255)


# ---------------------------------------------------------------------------
# TILES DEL SUBTERRÁNEO (atlas propio: arte/tiles/subterraneo.png)
# ---------------------------------------------------------------------------
def t_roca(rng):
    t = nuevo(T, T, ROCA[1])
    ruido(t, (0, 0, T, T), [ROCA[0], ROCA[3]], 0.25, rng)
    d = ImageDraw.Draw(t)
    for _ in range(3):
        x, y = rng.randrange(T), rng.randrange(T)
        d.line((x, y, x + rng.randint(-3, 3), y + rng.randint(1, 3)), ROCA[3])
    return t

def t_pared(rng, v):
    """Pared de ladrillo del túnel, húmeda, con chorreones verdes."""
    t = nuevo(T, T, c("3a3440"))
    d = ImageDraw.Draw(t)
    for fila, y in enumerate(range(0, T, 4)):
        off = 0 if fila % 2 == 0 else 4
        for x in range(-off, T, 8):
            d.rectangle((x + 1, y + 1, x + 7, y + 3), rng.choice([c("4a4252"), c("443c4c"), c("524a5c")]))
    ruido(t, (0, 0, T, T), [ROCA[3]], 0.08, rng)
    if v == 1:   # tubería que cruza
        d.rectangle((0, 5, T - 1, 8), METAL[1]); d.line((0, 5, T - 1, 5), METAL[2]); d.line((0, 8, T - 1, 8), METAL[3])
        d.rectangle((6, 4, 7, 9), METAL[3])
    for _ in range(2):   # chorreones de humedad tóxica
        x = rng.randrange(1, T - 1)
        largo = rng.randint(4, 10)
        d.line((x, 0, x, largo), c("4f6a3a")); d.point((x, largo + 1), LODO[2])
    d.line((0, T - 1, T - 1, T - 1), ROCA[3])
    return t

def t_azulejo(rng, letrero=False, grafiti=False):
    """Pared del andén: azulejos blancos sucios del viejo metro."""
    t = nuevo(T, T, AZULEJO[0])
    d = ImageDraw.Draw(t)
    for y in range(0, T, 4):
        for x in range(0, T, 4):
            d.rectangle((x, y, x + 3, y + 3), rng.choice([AZULEJO[0], AZULEJO[0], AZULEJO[2], AZULEJO[1]]))
            d.line((x, y + 3, x + 3, y + 3), AZULEJO[3])
            d.line((x + 3, y, x + 3, y + 3), AZULEJO[3])
    ruido(t, (0, 0, T, T), [c("5a6a4a"), c("6a6a50")], 0.12, rng)   # mugre
    if letrero:
        d.rectangle((1, 4, 14, 10), c("1e3a6a")); d.line((1, 4, 14, 4), c("3a5a9a"))
        for x in (3, 5, 7, 9, 11):
            d.line((x, 6, x, 8), c("e8ecf0"))
    if grafiti:
        d.line((2, 12, 6, 4, 9, 12, 13, 4), c("e04a8a"))
        d.point((7, 8), CIAN)
    d.rectangle((0, 12, T - 1, T - 1), c("3a3a36")); d.line((0, 12, T - 1, 12), c("6a6a5e"))   # zócalo
    return t

def t_anden(rng, v):
    t = nuevo(T, T, c("6a6a66"))
    ruido(t, (0, 0, T, T), [c("5e5e5a"), c("767670")], 0.18, rng)
    d = ImageDraw.Draw(t)
    d.line((0, 0, T - 1, 0), c("4e4e4a")); d.line((0, 0, 0, T - 1), c("4e4e4a"))
    if v == 1:   # basura y cartones
        d.rectangle((3, 9, 8, 12), c("8a6a44")); d.line((3, 9, 8, 9), c("a8865a"))
        d.point((11, 4), c("c8c8c0")); d.point((12, 5), c("a0a098"))
    if v == 2:   # borde de seguridad amarillo
        d.rectangle((0, 12, T - 1, 14), c("c9a42a"))
        for x in range(0, T, 3):
            d.point((x, 13), c("8a6e1a"))
        d.line((0, 15, T - 1, 15), c("3a3a36"))
    return t

def t_via(rng):
    t = nuevo(T, T, c("4a4038"))
    ruido(t, (0, 0, T, T), [c("3a322c"), c("5a5048"), c("6a5e52")], 0.4, rng)   # grava
    d = ImageDraw.Draw(t)
    for y in (2, 9):
        d.rectangle((0, y, T - 1, y + 2), MADERA[1]); d.line((0, y, T - 1, y), MADERA[0])   # durmientes
    for x in (3, 12):
        d.rectangle((x, 0, x + 1, T - 1), METAL[2]); d.line((x, 0, x, T - 1), METAL[4])     # rieles
    ruido(t, (0, 0, T, T), [OXIDO[1]], 0.05, rng)
    return t

def t_lodo(rng, v):
    """Río de lodo tóxico: verde enfermizo, con vetas que brillan."""
    t = nuevo(T, T, LODO[0])
    ruido(t, (0, 0, T, T), [LODO[1], LODO[3]], 0.3, rng)
    d = ImageDraw.Draw(t)
    fase = v * 6
    for base in (4, 11):
        for x in range(T):
            y = base + int(round(math.sin((x + fase) / 2.2) * 1.2))
            d.point((x, y), LODO[2])
    for _ in range(2 + v):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        d.ellipse((x - 1, y - 1, x + 1, y + 1), LODO[2]); d.point((x, y - 1), LODO[4])   # burbuja
    return t

def t_orilla(rng):
    """Borde de piedra donde el andén cae al lodo."""
    t = t_lodo(rng, 0)
    d = ImageDraw.Draw(t)
    d.rectangle((0, 0, T - 1, 5), c("5e5a52")); d.line((0, 0, T - 1, 0), c("7a766c"))
    for x in range(0, T, 4):
        d.line((x, 5, x + 1, 7), c("3e3a34"))
    d.line((0, 6, T - 1, 6), c("2a2620"))
    return t

def t_pasarela(rng, vertical=False, rota=False):
    """Pasarela de madera podrida sobre el lodo (se puede caminar, menos la rota)."""
    t = t_lodo(rng, 1)
    tablas = nuevo(T, T)
    d = ImageDraw.Draw(tablas)
    for k in range(4):
        col = rng.choice([PODRIDA[0], PODRIDA[2], PODRIDA[1]])
        if vertical:
            x = 2 + k * 3
            d.rectangle((x, 0, x + 2, T - 1), col); d.line((x, 0, x, T - 1), ilum(col, 1.2))
        else:
            y = 1 + k * 4
            d.rectangle((0, y, T - 1, y + 2), col); d.line((0, y, T - 1, y), ilum(col, 1.2))
    for _ in range(4):   # musgo y agujeros
        d.point((rng.randrange(T), rng.randrange(T)), PODRIDA[4])
    if vertical:
        d.line((1, 0, 1, T - 1), PODRIDA[3]); d.line((14, 0, 14, T - 1), PODRIDA[3])
    else:
        d.line((0, 0, T - 1, 0), PODRIDA[3]); d.line((0, 15, T - 1, 15), PODRIDA[3])
    if rota:   # le faltan tablas: se ve el lodo
        d.rectangle((4, 0, 11, T - 1) if not vertical else (0, 4, T - 1, 11), (0, 0, 0, 0))
        d.line((4, 5, 7, 9), PODRIDA[3]); d.line((11, 3, 9, 8), PODRIDA[3])
    t.alpha_composite(tablas)
    return t

def t_hongos(rng, v):
    """Suelo de musgo con hongos que brillan (aquí salen criaturas)."""
    t = nuevo(T, T, c("2e3a2a"))
    ruido(t, (0, 0, T, T), [c("3a4a30"), c("24301e"), c("44583a")], 0.35, rng)
    d = ImageDraw.Draw(t)
    colores = [CIAN, MORADO, VERDE_L]
    for k in range(3 + v):
        x, y = rng.randrange(1, 14), rng.randrange(3, 15)
        col = colores[(k + v) % 3]
        d.line((x, y, x, y - 2), c("c8c0b0"))
        d.rectangle((x - 1, y - 3, x + 1, y - 3), col); d.point((x, y - 4), ilum(col, 1.2))
    return t

def t_musgo(rng):
    t = nuevo(T, T, c("3a4234"))
    ruido(t, (0, 0, T, T), [c("2e3628"), c("465040"), c("4e6a3a")], 0.3, rng)
    return t

def t_rejilla(rng):
    t = t_anden(rng, 0)
    d = ImageDraw.Draw(t)
    d.rectangle((2, 2, 13, 13), c("1a1a1e"))
    for x in range(3, 13, 2):
        d.line((x, 3, x, 12), METAL[1])
    d.rectangle((2, 2, 13, 13), outline=METAL[3])
    d.point((7, 9), LODO[4])   # brillo verde allá abajo
    return t

def t_charco(rng):
    """Charco poco profundo: se puede pisar, pero puede infectar a tu carta."""
    t = t_anden(rng, 0)
    d = ImageDraw.Draw(t)
    d.ellipse((1, 3, 14, 13), LODO[1]); d.ellipse((3, 5, 12, 11), LODO[2])
    d.line((5, 6, 9, 6), LODO[4]); d.point((10, 9), LODO[4])
    return t

def t_tuberia(rng, vertical=False):
    t = t_roca(rng)
    d = ImageDraw.Draw(t)
    if vertical:
        d.rectangle((4, 0, 11, T - 1), METAL[1]); d.line((5, 0, 5, T - 1), METAL[4]); d.line((11, 0, 11, T - 1), METAL[3])
        d.rectangle((3, 6, 12, 9), METAL[0]); d.point((4, 7), METAL[4])
    else:
        d.rectangle((0, 4, T - 1, 11), METAL[1]); d.line((0, 5, T - 1, 5), METAL[4]); d.line((0, 11, T - 1, 11), METAL[3])
        d.rectangle((6, 3, 9, 12), METAL[0]); d.point((7, 4), METAL[4])
    d.point((rng.randrange(4, 12), 12 if not vertical else 8), LODO[2])   # fuga
    return t

def t_lab_piso(rng, linea=False):
    t = nuevo(T, T, LAB[0])
    d = ImageDraw.Draw(t)
    d.line((0, 0, T - 1, 0), LAB[2]); d.line((0, 0, 0, T - 1), LAB[2])
    d.line((8, 0, 8, T - 1), LAB[1]); d.line((0, 8, T - 1, 8), LAB[1])
    d.point((1, 1), LAB[4]); d.point((9, 9), LAB[4])
    if linea:
        d.rectangle((0, 6, T - 1, 9), c("4ad07a")); d.line((0, 6, T - 1, 6), c("8af0a0"))
    return t

def t_lab_pared(rng):
    t = nuevo(T, T, LAB[1])
    d = ImageDraw.Draw(t)
    d.rectangle((0, 0, T - 1, 3), LAB[0]); d.line((0, 3, T - 1, 3), LAB[3])
    d.rectangle((0, 10, T - 1, 11), c("4ad07a"))   # franja verde de Vesper
    d.line((0, T - 1, T - 1, T - 1), LAB[3])
    for x in (0, 8):
        d.line((x, 4, x, 9), LAB[2])
    return t

def t_cristal(rng):
    """Cristal blindado: se ve el interior limpio del laboratorio."""
    t = nuevo(T, T, c("9ad8d0"))
    gradiente(t, (0, 0, T, T), [c("b8ece6"), c("7ac0b8")], tramar=True)
    d = ImageDraw.Draw(t)
    d.line((2, 12, 9, 2), c("e8fffc")); d.line((5, 14, 13, 3), c("d0f8f4"))   # reflejos
    d.rectangle((0, 0, T - 1, 1), LAB[3]); d.rectangle((0, 14, T - 1, T - 1), LAB[3])
    d.point((1, 7), LAB[4]); d.point((14, 7), LAB[4])   # remaches del marco
    return t

def t_gas(rng, v):
    """Colector de gas: suelo de rejillas con neblina verde (criaturas raras)."""
    t = t_rejilla(rng) if v == 0 else t_musgo(rng)
    capa = nuevo(T, T)
    d = ImageDraw.Draw(capa)
    for _ in range(6):
        x, y = rng.randrange(T), rng.randrange(T)
        d.ellipse((x - 3, y - 2, x + 3, y + 2), (150, 230, 90, 70))
    t.alpha_composite(capa)
    return t

def t_oscuro(rng, v):
    """Túnel sin luz: casi negro. Aquí cazan el Tejedor de Sombras y los Humanoides."""
    t = nuevo(T, T, c("15121a"))
    ruido(t, (0, 0, T, T), [c("1e1a24"), c("0e0c12")], 0.3, rng)
    if v == 1:
        d = ImageDraw.Draw(t)
        d.line((3, 0, 3, T - 1), c("26222c")); d.line((12, 0, 12, T - 1), c("26222c"))   # rieles viejos en la oscuridad
    return t

def t_escalera(rng):
    t = nuevo(T, T, c("5e5e5a"))
    d = ImageDraw.Draw(t)
    for y in range(0, T, 3):
        d.rectangle((1, y, 14, y + 1), c("7a7a74")); d.line((1, y + 2, 14, y + 2), c("3a3a36"))
    d.line((0, 0, 0, T - 1), METAL[2]); d.line((15, 0, 15, T - 1), METAL[2])
    return t

def t_objeto(rng, dibujar, fondo=None):
    base = fondo if fondo is not None else t_anden(rng, 0)
    capa = nuevo(T, T)
    dibujar(ImageDraw.Draw(capa))
    sombrear(capa); contorno(capa)
    base.alpha_composite(capa)
    return base

def dib_cajas(d):
    d.rectangle((1, 6, 9, 14), MADERA[0]); d.line((1, 6, 9, 14), MADERA[1]); d.line((1, 6, 9, 6), MADERA[2])
    d.rectangle((7, 2, 14, 9), MADERA[2]); d.line((7, 2, 14, 2), c("c8945a")); d.line((7, 9, 14, 2), MADERA[1])

def dib_barril_verde(d):
    d.rectangle((3, 2, 12, 14), c("3a5a3a")); d.line((3, 5, 12, 5), c("2a402a")); d.line((3, 11, 12, 11), c("2a402a"))
    d.ellipse((3, 1, 12, 4), c("4a6a4a")); d.point((7, 2), LODO[4])
    d.polygon([(6, 7), (9, 7), (7, 10)], c("e6c34a"))   # símbolo de peligro

def dib_colchon(d):
    d.rectangle((1, 4, 14, 13), c("8a7a5a")); d.rectangle((1, 4, 5, 13), c("a8987a"))
    d.point((8, 8), c("6a5a3a")); d.point((11, 10), c("6a5a3a")); d.line((2, 5, 4, 5), c("d8d0c0"))
    d.point((10, 6), c("7a3a2a"))   # mancha

def dib_fogon(d):
    d.rectangle((3, 8, 12, 14), METAL[1]); d.line((3, 8, 12, 8), METAL[2])
    d.polygon([(5, 8), (7, 2), (8, 5), (10, 1), (11, 8)], c("ff9a3a")); d.polygon([(7, 8), (8, 4), (9, 8)], c("ffe08a"))

def dib_hongo_grande(d):
    d.rectangle((6, 8, 9, 15), c("d8d0c0")); d.line((6, 8, 6, 15), c("f0e8d8"))
    d.ellipse((1, 1, 14, 10), c("4ab0c0")); d.ellipse((2, 2, 13, 7), CIAN)
    for (x, y) in ((4, 4), (8, 3), (11, 5)):
        d.point((x, y), c("e0fffc"))

def dib_valla_lab(d):
    d.rectangle((0, 6, 15, 7), LAB[2]); d.rectangle((0, 11, 15, 12), LAB[2])
    for x in (1, 7, 13):
        d.rectangle((x, 3, x + 1, 14), LAB[3]); d.point((x, 3), LAB[4])

def tiles_subterraneo(rng):
    hongo_fondo = t_musgo(rng)
    return [
        ("roca", t_roca(rng), True), ("pared", t_pared(rng, 0), True), ("pared_tubo", t_pared(rng, 1), True),
        ("azulejo", t_azulejo(rng), True), ("azulejo_letrero", t_azulejo(rng, letrero=True), True),
        ("azulejo_grafiti", t_azulejo(rng, grafiti=True), True),
        ("anden_1", t_anden(rng, 0), False), ("anden_2", t_anden(rng, 1), False), ("anden_borde", t_anden(rng, 2), False),
        ("via", t_via(rng), False),
        ("lodo_1", t_lodo(rng, 0), True), ("lodo_2", t_lodo(rng, 1), True), ("orilla", t_orilla(rng), True),
        ("pasarela_h", t_pasarela(rng), False), ("pasarela_v", t_pasarela(rng, vertical=True), False),
        ("pasarela_rota", t_pasarela(rng, rota=True), True),
        ("hongos_1", t_hongos(rng, 0), False), ("hongos_2", t_hongos(rng, 1), False),
        ("musgo", t_musgo(rng), False), ("rejilla", t_rejilla(rng), False), ("charco", t_charco(rng), False),
        ("tubo_h", t_tuberia(rng), True), ("tubo_v", t_tuberia(rng, True), True),
        ("lab_piso", t_lab_piso(rng), False), ("lab_linea", t_lab_piso(rng, True), False),
        ("lab_pared", t_lab_pared(rng), True), ("cristal", t_cristal(rng), True),
        ("gas_1", t_gas(rng, 0), False), ("gas_2", t_gas(rng, 1), False),
        ("oscuro_1", t_oscuro(rng, 0), False), ("oscuro_2", t_oscuro(rng, 1), False),
        ("escalera", t_escalera(rng), False),
        ("cajas", t_objeto(rng, dib_cajas), True), ("barril_verde", t_objeto(rng, dib_barril_verde), True),
        ("colchon", t_objeto(rng, dib_colchon), False), ("fogon", t_objeto(rng, dib_fogon), True),
        ("hongo_grande", t_objeto(rng, dib_hongo_grande, hongo_fondo), True),
        ("valla_lab", t_objeto(rng, dib_valla_lab, t_lab_piso(rng)), True),
    ]


# ---------------------------------------------------------------------------
# TILES NUEVOS DEL EXTERIOR: la Autopista Quemada (van al final del atlas exterior)
# ---------------------------------------------------------------------------
def tile_ceniza(rng, v):
    """Pasto quemado y gris: aquí cazan los Lobos de Ceniza."""
    t = nuevo(T, T, c("5a5450"))
    ruido(t, (0, 0, T, T), [c("4a4442"), c("6a6460")], 0.25, rng)
    d = ImageDraw.Draw(t)
    for _ in range(7 + v * 2):
        x, y = rng.randrange(T), rng.randrange(4, T)
        alto = rng.randint(2, 5)
        d.line((x, y, x + rng.choice((-1, 0, 1)), y - alto), rng.choice([c("8a8480"), c("2e2a28"), c("a09a94")]))
    if v == 1:
        d.point((rng.randrange(T), rng.randrange(T)), c("ff7a2a"))   # brasa escondida
    return t

def tile_baranda(rng):
    t = g.tile_asfalto(rng)
    capa = nuevo(T, T); d = ImageDraw.Draw(capa)
    d.rectangle((0, 5, T - 1, 9), c("9a9aa0")); d.line((0, 5, T - 1, 5), c("c8c8d0")); d.line((0, 7, T - 1, 7), c("7a7a80"))
    for x in (2, 10):
        d.rectangle((x, 9, x + 2, 15), c("5a5a60"))
    d.point((6, 6), OXIDO[1]); d.point((12, 8), OXIDO[0])
    contorno(capa)
    t.alpha_composite(capa)
    return t

def tile_asfalto_roto(rng):
    t = g.tile_asfalto(rng, grieta=True)
    d = ImageDraw.Draw(t)
    d.polygon([(3, 4), (9, 2), (13, 7), (10, 12), (4, 11)], c("2a2a30"))
    d.polygon([(5, 5), (9, 4), (11, 7), (8, 10), (5, 9)], c("5a4a3a"))   # tierra debajo
    d.point((7, 7), c("8a8a3a"))
    return t

def tiles_exterior(rng):
    return [
        ("ceniza_1", tile_ceniza(rng, 0), False), ("ceniza_2", tile_ceniza(rng, 1), False),
        ("baranda", tile_baranda(rng), True), ("asfalto_roto", tile_asfalto_roto(rng), False),
    ]


# ---------------------------------------------------------------------------
# ICONOS (16x16) y proyectiles de la Intervención Directa
# ---------------------------------------------------------------------------
def icono_antidoto():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((6, 1, 9, 3), c("e8e8e0")); d.rectangle((5, 3, 10, 4), METAL[2])
    d.polygon([(5, 5), (10, 5), (13, 13), (11, 15), (4, 15), (2, 13)], c("d8f0f8"))
    d.polygon([(4, 9), (11, 9), (13, 13), (11, 15), (4, 15), (2, 13)], c("4ac8e8"))
    d.rectangle((6, 10, 9, 13), c("ffffff")); d.line((7, 9, 8, 9), c("ffffff"))
    d.line((5, 11, 10, 11), c("e04a5a")); d.line((7, 10, 7, 13), c("e04a5a")); d.line((8, 10, 8, 13), c("e04a5a"))
    d.point((5, 6), c("ffffff"))
    sombrear(img); contorno(img)
    return img

def icono_mascara():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.line((1, 6, 4, 4), c("3a3028")); d.line((14, 6, 11, 4), c("3a3028"))   # correas
    d.ellipse((3, 2, 12, 11), c("4a5a48"))
    d.ellipse((4, 4, 7, 7), c("9ad8d0")); d.ellipse((8, 4, 11, 7), c("9ad8d0"))
    d.point((5, 5), c("ffffff")); d.point((9, 5), c("ffffff"))
    d.ellipse((5, 9, 10, 15), METAL[1]); d.ellipse((6, 10, 9, 14), METAL[3])
    for y in (11, 13):
        d.line((6, y, 9, y), METAL[4])
    sombrear(img); contorno(img)
    return img

def icono_molotov():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.polygon([(5, 6), (10, 6), (11, 14), (4, 14)], c("6a8a3a")); d.rectangle((5, 9, 10, 13), c("c07a2a"))
    d.rectangle((6, 3, 9, 6), c("6a8a3a"))
    d.line((7, 3, 6, 0), c("e8e0d0")); d.line((8, 3, 9, 1), c("e8e0d0"))   # trapo
    d.point((6, 0), c("ffb03a")); d.point((5, 1), c("ff6a2a")); d.point((9, 0), c("ffe08a"))
    d.point((6, 7), c("c8f0a0"))
    sombrear(img); contorno(img)
    return img

def icono_frasco_veneno():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((6, 1, 9, 4), c("4a3a5a"))
    d.ellipse((2, 4, 13, 15), c("c8e0d8")); d.ellipse((3, 7, 12, 14), LODO[2])
    d.point((5, 9), LODO[4]); d.point((9, 11), LODO[4]); d.point((4, 6), c("ffffff"))
    d.polygon([(6, 9), (9, 9), (9, 12), (6, 12)], c("2a2a2a")); d.point((7, 10), c("e8e8e8")); d.point((8, 10), c("e8e8e8"))   # calavera
    sombrear(img); contorno(img)
    return img

def icono_pina_silvestre():
    """Piña salvaje: se ve rica, pero está contaminada (GDD: la comida salvaje aplica estados negativos)."""
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.ellipse((3, 5, 12, 15), c("c8a03a"))
    for (x, y) in ((5, 8), (8, 7), (10, 10), (6, 12), (9, 13)):
        d.point((x, y), c("6a5a1a"))
    d.ellipse((7, 9, 11, 13), c("7bd13b")); d.point((8, 10), c("b6f06a"))      # moho verde
    d.polygon([(6, 5), (5, 0), (8, 3), (11, 0), (10, 5)], c("4f7a24"))
    sombrear(img); contorno(img)
    return img

def generar_iconos():
    guardar(icono_pina_silvestre(), "objetos/pina_silvestre.png")
    guardar(icono_antidoto(), "objetos/antidoto.png")
    guardar(icono_mascara(), "objetos/mascara_filtro.png")
    guardar(icono_molotov(), "objetos/molotov.png")
    guardar(icono_frasco_veneno(), "objetos/frasco_veneno.png")


# ---------------------------------------------------------------------------
# Letras de 3x5 para carteles (MERCADO, ANTIDOTO, METRO...)
# ---------------------------------------------------------------------------
LETRAS = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"], "C": ["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"], "E": ["111", "100", "110", "100", "111"], "G": ["011", "100", "101", "101", "011"],
    "I": ["111", "010", "010", "010", "111"], "L": ["100", "100", "100", "100", "111"], "M": ["101", "111", "111", "101", "101"],
    "N": ["101", "111", "111", "111", "101"], "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
    "R": ["110", "101", "110", "101", "101"], "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"], "Y": ["101", "101", "010", "010", "010"],
    "X": ["101", "101", "010", "101", "101"], "F": ["111", "100", "110", "100", "100"], "Z": ["111", "001", "010", "100", "111"],
    "<": ["001", "010", "100", "010", "001"], ">": ["100", "010", "001", "010", "100"], "!": ["010", "010", "010", "000", "010"],
    " ": ["000", "000", "000", "000", "000"], "+": ["000", "010", "111", "010", "000"],
}

def escribir(d, x, y, texto, col):
    for ch in texto:
        patron = LETRAS.get(ch, LETRAS[" "])
        for fy, fila in enumerate(patron):
            for fx, v in enumerate(fila):
                if v == "1":
                    d.point((x + fx, y + fy), col)
        x += 4
    return x

def ancho_texto(texto):
    return len(texto) * 4 - 1

def simbolo_vesper(d, x, y, col=c("4ad07a")):
    """El símbolo de Vesper: un matraz con una hoja (la "selección natural")."""
    d.rectangle((x + 2, y, x + 4, y + 2), col)
    d.polygon([(x + 1, y + 3), (x + 5, y + 3), (x + 7, y + 8), (x - 1, y + 8)], col)
    d.point((x + 3, y + 5), c("e8ffe8")); d.line((x + 5, y + 1, x + 7, y - 1), c("8af0a0"))


# ---------------------------------------------------------------------------
# CONSTRUCCIONES GRANDES DEL SUMIDERO (arte/decorados/*.png). La base es el suelo.
# ---------------------------------------------------------------------------
def terminar(img, luz=1.12, sombra=0.75):
    sombrear(img, luz, sombra)
    contorno(img)
    return img

def vagon(tipo):
    """Vagón del viejo metro convertido en casa: techo arriba, costado con ventanas abajo."""
    W_, H_ = 112, 56
    img = nuevo(W_, H_); d = ImageDraw.Draw(img)
    rng = random.Random({"tienda": 1, "posada": 2, "grafiti": 3}[tipo])
    cuerpo = METRO[0] if tipo != "grafiti" else c("5a6058")
    d.rounded_rectangle((2, 2, W_ - 3, 20), 5, METRO[2])                  # techo
    d.line((8, 6, W_ - 9, 6), ilum(METRO[2], 1.15)); d.line((8, 15, W_ - 9, 15), METRO[1])
    for x in (20, 56, 92):
        d.rectangle((x - 5, 8, x + 5, 12), METRO[1])                         # rejillas de ventilación
    d.rectangle((2, 18, W_ - 3, H_ - 5), cuerpo)                            # costado
    d.rectangle((2, H_ - 9, W_ - 3, H_ - 5), METRO[3])
    d.line((2, 30, W_ - 3, 30), c("c9a42a"))                               # franja amarilla del metro
    for x in range(4, W_ - 4, 3):
        d.point((x, 50), METRO[1])
    for (x0, x1) in ((8, 26), (32, 48), (64, 80), (86, 104)):              # ventanas
        d.rectangle((x0, 20, x1, 28), c("1e2428"))
        d.line((x0, 20, x1, 20), METRO[3])
    d.rectangle((50, 20, 62, H_ - 6), c("2a3036"))                          # puerta
    d.line((56, 20, 56, H_ - 6), METRO[3])
    for x in (12, 100):
        d.rectangle((x - 4, H_ - 5, x + 4, H_ - 1), METRO[3])                # ruedas sobre la vía
        d.ellipse((x - 3, H_ - 5, x + 3, H_ - 1), METAL[1])
    if tipo == "tienda":
        for (x0, x1) in ((8, 26), (32, 48)):
            d.rectangle((x0 + 1, 21, x1 - 1, 27), c("e0b060"))               # luz cálida adentro
            for k in range(x0 + 3, x1 - 2, 4):
                d.rectangle((k, 23, k + 2, 27), rng.choice([c("4ac8e8"), c("e04a5a"), c("7bd13b"), c("e6c34a")]))   # frascos
        d.rectangle((50, 20, 62, 51), c("e0b060"))                          # puerta abierta
        d.rectangle((44, 38, 68, 44), MADERA[0]); d.line((44, 38, 68, 38), MADERA[2])   # mostrador
        d.rectangle((47, 34, 50, 38), c("4ac8e8")); d.rectangle((60, 35, 63, 38), c("e04a5a"))
        d.rectangle((22, 32, 46, 40), c("2a2a2a")); escribir(d, 24, 34, "MERCADO", c("e6c34a"))
        d.line((70, 0, 70, 4), METAL[3]); d.ellipse((67, 4, 73, 9), c("ffd27a"))   # farol colgando
    elif tipo == "posada":
        for (x0, x1) in ((64, 80), (86, 104)):
            d.rectangle((x0 + 1, 21, x1 - 1, 27), c("c09060"))
            d.polygon([(x0 + 1, 21), (x0 + 6, 21), (x0 + 3, 27), (x0 + 1, 27)], c("8a3a3a"))   # cortinas
            d.polygon([(x1 - 1, 21), (x1 - 6, 21), (x1 - 3, 27), (x1 - 1, 27)], c("8a3a3a"))
        d.rectangle((50, 20, 62, 51), c("8a3a3a")); d.line((56, 20, 56, 51), c("6a2a2a"))   # cortina en la puerta
        d.rectangle((70, 32, 98, 40), c("2a2a2a")); escribir(d, 73, 34, "DORMIR", c("e8d8b0"))
        d.rectangle((14, 40, 36, 46), c("8a7a5a")); d.rectangle((14, 40, 19, 46), c("a8987a"))   # colchón afuera
    else:   # grafiti: abandonado
        for (x0, x1) in ((8, 26), (64, 80)):
            d.polygon([(x0 + 2, 20), (x0 + 8, 24), (x0 + 4, 28)], c("8a9aa0"))   # vidrio roto
        d.line((10, 36, 18, 44, 24, 34, 30, 44), c("e04a8a"))
        escribir(d, 66, 34, "LIBRES", CIAN)
        escribir(d, 30, 34, "V", c("e6c34a")); d.line((36, 36, 42, 36), c("e6c34a")); escribir(d, 44, 34, "VENENO"[:3], c("e6c34a"))
        d.ellipse((86, 38, 96, 46), c("7bd13b")); d.point((90, 41), c("1e1e1e")); d.point((93, 41), c("1e1e1e"))
        ruido(img, (2, 18, W_ - 3, H_ - 6), [OXIDO[1], c("3a3a36")], 0.05, rng)
    return terminar(img)

def laboratorio():
    """El laboratorio prístino de Vesper: blanco, limpio, con cristales blindados. Contrasta con la mugre."""
    W_, H_ = 208, 112
    img = nuevo(W_, H_); d = ImageDraw.Draw(img)
    d.rectangle((4, 2, W_ - 5, 26), LAB[1])                                  # techo plano
    d.line((4, 2, W_ - 5, 2), LAB[4]); d.line((4, 26, W_ - 5, 26), LAB[3])
    for x in range(14, W_ - 10, 24):
        d.rectangle((x, 8, x + 12, 18), LAB[2]); d.line((x, 8, x + 12, 8), LAB[4])   # equipos del techo
        d.ellipse((x + 3, 10, x + 9, 16), METAL[2])
    d.rectangle((4, 26, W_ - 5, H_ - 3), LAB[0])                             # fachada
    d.rectangle((4, 30, W_ - 5, 33), c("4ad07a")); d.line((4, 30, W_ - 5, 30), c("8af0a0"))   # franja verde
    # cristales blindados con el interior a la vista
    for (x0, x1) in ((14, 84), (124, 194)):
        d.rectangle((x0, 40, x1, 92), c("8acfc6"))
        gradiente(img, (x0 + 1, 41, x1, 92), [c("b8ece6"), c("6aaaa2")], tramar=True)
        d = ImageDraw.Draw(img)
        for k, x in enumerate(range(x0 + 6, x1 - 8, 16)):                     # tanques con criaturas flotando
            d.rounded_rectangle((x, 50, x + 10, 86), 3, c("3a6a4a"))
            d.rectangle((x + 1, 58, x + 9, 85), c("6ae07a") if k % 2 == 0 else c("8ad0e0"))
            d.ellipse((x + 2, 64, x + 8, 72), c("2a3a2a"))                    # silueta de un espécimen
            d.point((x + 4, 66), c("ff4a4a"))
            d.rectangle((x - 1, 48, x + 11, 50), METAL[2]); d.rectangle((x - 1, 86, x + 11, 88), METAL[2])
            d.point((x + 3, 60), c("e8ffe8")); d.point((x + 6, 75), c("e8ffe8"))
        d.line((x0 + 2, 88, x0 + 30, 44), c("e8fffc")); d.line((x1 - 30, 88, x1 - 4, 50), c("d0f8f4"))   # reflejos
        d.rectangle((x0, 40, x1, 92), outline=LAB[3])
        for y in (40, 66, 92):
            for x in range(x0, x1 + 1, 10):
                d.point((x, y), LAB[4])                                       # remaches del blindaje
    # puerta corrediza y el símbolo de Vesper
    d.rectangle((92, 44, 116, H_ - 3), c("9ad8d0")); d.line((104, 44, 104, H_ - 3), LAB[3])
    d.rectangle((92, 44, 116, H_ - 3), outline=LAB[3])
    d.rectangle((90, 36, 118, 42), c("1e3a2a")); simbolo_vesper(d, 101, 34, c("6aff8a"))
    d.ellipse((96, 46, 100, 50), c("ff4a4a")); d.ellipse((108, 46, 112, 50), c("4aff7a"))   # luces de acceso
    for x in (10, W_ - 14):                                                  # focos
        d.rectangle((x, 34, x + 4, 38), METAL[3]); d.point((x + 2, 38), c("fffbe0"))
    d.rectangle((4, H_ - 6, W_ - 5, H_ - 3), LAB[2])
    return terminar(img, 1.06, 0.82)

def ventanilla():
    """Ventanilla del antídoto: la gente hace fila aquí cada semana."""
    img = nuevo(56, 60); d = ImageDraw.Draw(img)
    d.rectangle((4, 10, 51, 57), LAB[1]); d.rectangle((2, 4, 53, 12), LAB[2]); d.line((2, 4, 53, 4), LAB[4])
    d.rectangle((14, 22, 41, 38), c("1e3a2a"))
    d.rectangle((16, 24, 39, 36), c("7ac0b8"))
    for x in range(18, 39, 4):
        d.line((x, 24, x, 36), METAL[2])                                      # barrotes
    d.rectangle((24, 36, 32, 40), METAL[1])                                   # la ranura
    d.rectangle((8, 44, 47, 52), c("2a2a2a")); escribir(d, 12, 46, "ANTIDOTO", c("8af0a0"))
    d.ellipse((24, 0, 31, 6), c("4aff7a"))                                    # luz verde arriba
    simbolo_vesper(d, 42, 14)
    return terminar(img)

def tanque_veneno(limpio=False):
    """El tanque de agua del Sumidero. Vesper lo envenena; después de liberarlo, el agua corre limpia."""
    img = nuevo(56, 84); d = ImageDraw.Draw(img)
    agua = c("4ab0e0") if limpio else LODO[2]
    d.rectangle((10, 70, 14, 83), METAL[3]); d.rectangle((42, 70, 46, 83), METAL[3])   # patas
    d.rounded_rectangle((4, 6, 51, 72), 6, METAL[0])
    d.line((6, 8, 6, 70), METAL[4])
    for y in (20, 40, 60):
        d.line((4, y, 51, y), METAL[3])
    d.rectangle((14, 26, 42, 52), c("1e2428")); d.rectangle((16, 28, 40, 50), agua)   # mirilla
    for k in range(4):
        d.point((19 + k * 6, 34 + (k % 2) * 8), ilum(agua, 1.4))
    d.rectangle((14, 10, 42, 18), c("e8e4dc")); escribir(d, 21, 12, "AGUA", c("2a4a7a"))
    if not limpio:
        simbolo_vesper(d, 42, 54)
        d.rectangle((50, 28, 55, 32), METAL[1]); d.line((53, 32, 53, 44), LODO[2]); d.point((53, 46), LODO[4])   # gotea veneno
        d.polygon([(40, 4), (52, 0), (54, 6), (44, 8)], c("e6c34a")); d.point((47, 4), c("2a2a2a"))   # sello de peligro
    else:
        d.rectangle((50, 28, 55, 32), METAL[1]); d.line((53, 32, 53, 44), c("8ad8ff"))
    return terminar(img)

def altavoz():
    img = nuevo(20, 60); d = ImageDraw.Draw(img)
    d.rectangle((9, 12, 11, 59), METAL[3]); d.line((9, 12, 9, 59), METAL[2])
    d.polygon([(4, 2), (16, 0), (16, 12), (4, 10)], METAL[1]); d.polygon([(12, 2), (19, -2), (19, 14), (12, 10)], METAL[0])
    d.ellipse((14, 3, 18, 9), METAL[3])
    d.line((11, 14, 19, 18), c("2a2a2a")); d.line((19, 18, 19, 40), c("2a2a2a"))   # cable
    d.point((6, 5), c("ff4a4a"))
    return terminar(img)

def hongo_gigante(color, seed):
    rng = random.Random(seed)
    img = nuevo(40, 58); d = ImageDraw.Draw(img)
    oscuro = ilum(color, 0.55)
    d.polygon([(16, 57), (17, 30), (23, 30), (25, 57)], c("d8d0c0")); d.line((17, 30, 16, 57), c("f0e8d8"))
    for y in range(34, 56, 5):
        d.line((18, y, 22, y + 1), c("b8b0a0"))
    d.ellipse((1, 4, 39, 34), oscuro); d.ellipse((2, 2, 38, 28), color)
    d.chord((2, 14, 38, 34), 0, 180, ilum(color, 0.75))
    for _ in range(6):
        x, y = rng.randrange(6, 33), rng.randrange(5, 18)
        d.ellipse((x - 1, y - 1, x + 1, y + 1), ilum(color, 1.5))
    for x in range(6, 36, 4):
        d.line((x, 27, x + 1, 31), oscuro)                                    # láminas de abajo
    d.ellipse((6, 40, 12, 46), color); d.line((9, 46, 9, 57), c("d8d0c0"))   # hongos chiquitos
    d.ellipse((28, 44, 33, 49), color); d.line((30, 49, 30, 57), c("d8d0c0"))
    return terminar(img, 1.2, 0.8)

def mapa_metro():
    img = nuevo(48, 40); d = ImageDraw.Draw(img)
    d.rectangle((6, 24, 8, 39), METAL[3]); d.rectangle((39, 24, 41, 39), METAL[3])
    d.rectangle((0, 0, 47, 28), c("e8e4dc")); d.rectangle((0, 0, 47, 28), outline=METAL[3])
    d.line((4, 8, 20, 8, 28, 16, 44, 16), c("e04a4a"), 2)
    d.line((10, 24, 18, 14, 38, 6), c("4a8ae0"), 2)
    d.line((6, 18, 42, 22), c("4ad07a"), 2)
    for (x, y) in ((4, 8), (20, 8), (28, 16), (44, 16), (18, 14), (38, 6), (24, 20)):
        d.ellipse((x - 1, y - 1, x + 1, y + 1), c("ffffff"), outline=c("2a2a2a"))
    d.ellipse((22, 18, 26, 22), c("6aff8a"))                                  # "usted está aquí"
    ruido(img, (1, 1, 46, 27), [c("8a8a70"), c("a09a80")], 0.08, random.Random(4))
    return terminar(img, 1.05, 0.85)

def memorial():
    """Pared de los que no volvieron de los experimentos: nombres, fotos y velas."""
    rng = random.Random(8)
    img = nuevo(56, 44); d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 55, 34), c("4a4452")); d.rectangle((0, 0, 55, 34), outline=ROCA[3])
    for _ in range(9):                                                        # fotos
        x, y = rng.randrange(2, 46), rng.randrange(2, 22)
        d.rectangle((x, y, x + 7, y + 9), c("d8d0c0")); d.rectangle((x + 1, y + 1, x + 6, y + 6), rng.choice([c("8a7a6a"), c("6a6a7a"), c("7a6a5a")]))
        d.ellipse((x + 2, y + 2, x + 5, y + 5), c("c8a888"))
    for y in range(26, 33, 3):                                                # nombres rayados
        for x in range(3, 52, 7):
            d.line((x, y, x + rng.randint(3, 5), y), c("c8c0d0"))
    d.rectangle((2, 36, 53, 43), c("3a3440"))                                 # repisa con velas
    for x in (6, 15, 24, 33, 42, 50):
        d.rectangle((x, 33, x + 2, 37), c("e8e0c8")); d.point((x + 1, 31), c("ffd27a")); d.point((x + 1, 32), c("ff9a3a"))
    d.polygon([(26, 2), (30, 2), (30, 5), (33, 5), (33, 8), (30, 8), (30, 14), (26, 14), (26, 8), (23, 8), (23, 5), (26, 5)], c("c8c0d0"))
    return terminar(img, 1.08, 0.8)

def cartel_benefactor():
    img = nuevo(28, 40); d = ImageDraw.Draw(img)
    d.rectangle((12, 28, 15, 39), MADERA[1])
    d.rectangle((0, 0, 27, 30), c("e8dcc0")); d.rectangle((0, 0, 27, 30), outline=c("8a7a5a"))
    d.ellipse((8, 4, 19, 16), c("e6c34a"))                                    # sol dorado
    for k in range(8):
        a = k * math.pi / 4
        d.line((14 + math.cos(a) * 7, 10 + math.sin(a) * 7, 14 + math.cos(a) * 10, 10 + math.sin(a) * 10), c("e6c34a"))
    d.ellipse((11, 6, 16, 12), c("2a2a3a")); d.polygon([(9, 16), (18, 16), (19, 20), (8, 20)], c("2a2a3a"))   # silueta de Marcus
    escribir(d, 2, 22, "BENEF", c("8a2a2a"))
    d.line((2, 28, 25, 28), c("8a7a5a"))
    d.line((3, 2, 24, 26), c("3a5a2a"))                                       # alguien lo rayó
    return terminar(img, 1.05, 0.85)

def taller_nilo():
    img = nuevo(64, 48); d = ImageDraw.Draw(img)
    d.rectangle((4, 24, 59, 30), MADERA[0]); d.line((4, 24, 59, 24), MADERA[2])   # mesa
    for x in (6, 56):
        d.rectangle((x, 30, x + 2, 47), MADERA[1])
    for k, x in enumerate((8, 18, 28)):                                       # filtros a medio armar
        d.rounded_rectangle((x, 12, x + 7, 24), 2, c("c8c8c0") if k != 1 else c("5a8a5a"))
        d.rectangle((x + 2, 9, x + 5, 12), METAL[2]); d.line((x + 1, 16, x + 6, 16), METAL[3])
    d.line((36, 22, 44, 16, 52, 22), METAL[3], 2)                             # tubo
    d.rectangle((46, 4, 48, 24), METAL[3]); d.polygon([(42, 4), (54, 4), (50, 10), (46, 10)], METAL[1])
    d.ellipse((46, 9, 50, 13), c("ffe08a"))                                   # lámpara
    d.rectangle((40, 32, 54, 44), c("4a5a48")); d.rectangle((42, 34, 52, 42), LODO[1])   # balde de lodo
    d.point((45, 36), LODO[4])
    return terminar(img)

def valvula(cerrada=False):
    img = nuevo(44, 52); d = ImageDraw.Draw(img)
    liquido = c("6ac8ff") if cerrada else LODO[2]
    d.rectangle((0, 30, 43, 40), METAL[1]); d.line((0, 30, 43, 30), METAL[2])   # caño
    d.rectangle((2, 32, 41, 38), liquido)
    d.rectangle((14, 14, 29, 50), METAL[0]); d.line((14, 14, 14, 50), METAL[2])
    d.ellipse((8, 0, 35, 22), METAL[3]); d.ellipse((11, 3, 32, 19), c("c43a3a") if not cerrada else c("3a7ac4"))
    d.ellipse((16, 7, 27, 15), METAL[3])
    for k in range(4):                                                        # rayos del volante
        a = k * math.pi / 2 + (0.6 if cerrada else 0.0)
        d.line((21 + math.cos(a) * 4, 11 + math.sin(a) * 3, 21 + math.cos(a) * 10, 11 + math.sin(a) * 7), METAL[4])
    d.rectangle((16, 40, 27, 46), c("2a2a2a")); d.rectangle((17, 41, 26, 45), c("8af0a0") if not cerrada else c("8ad0ff"))
    return terminar(img)

def jaulas():
    """Las criaturas raras que los vecinos le entregan a Vesper a cambio del antídoto."""
    img = nuevo(56, 40); d = ImageDraw.Draw(img)
    for k, x in enumerate((2, 30)):
        d.rectangle((x, 6, x + 24, 38), c("1e2428"))
        bicho = [c("e4e7ec"), c("3a3349")][k]
        d.ellipse((x + 6, 20, x + 18, 34), bicho); d.point((x + 9, 25), c("ff4a4a")); d.point((x + 14, 25), c("ff4a4a"))
        for xx in range(x, x + 25, 4):
            d.line((xx, 6, xx, 38), METAL[2])
        d.rectangle((x, 4, x + 24, 7), METAL[0]); d.rectangle((x, 37, x + 24, 39), METAL[0])
        d.rectangle((x + 9, 9, x + 15, 13), c("e8e4dc")); simbolo_vesper(d, x + 10, 8, c("2a6a3a"))
    return terminar(img)

def boca_metro():
    """Entrada del metro en la Autopista: escaleras que bajan al Sumidero."""
    img = nuevo(64, 48); d = ImageDraw.Draw(img)
    d.rectangle((6, 14, 57, 47), c("2a2a2e"))
    for k, y in enumerate(range(18, 46, 4)):
        sombra = max(0.25, 1.0 - k * 0.12)
        d.rectangle((10, y, 53, y + 2), ilum(c("8a8a84"), sombra)); d.line((10, y + 3, 53, y + 3), c("1e1e22"))
    d.rectangle((2, 12, 7, 47), METAL[1]); d.rectangle((56, 12, 61, 47), METAL[1])   # barandas
    d.line((2, 12, 2, 47), METAL[4]); d.line((56, 12, 56, 47), METAL[4])
    d.rectangle((22, 0, 41, 12), c("1e3a6a")); d.rectangle((22, 0, 41, 12), outline=METAL[3])
    escribir(d, 25, 4, "METRO", c("e8ecf0"))
    d.line((12, 40, 20, 30), c("7bd13b")); d.line((44, 30, 52, 40), c("7bd13b"))   # lodo que sube
    d.point((32, 44), LODO[4])
    return terminar(img, 1.08, 0.8)

def barricada():
    """Contenedores caídos que tapan la salida este de Bastión (la grúa de Bruno los mueve)."""
    img = nuevo(36, 52); d = ImageDraw.Draw(img)
    d.polygon([(2, 50), (4, 22), (20, 18), (22, 50)], OXIDO[1]); d.polygon([(4, 22), (8, 14), (24, 10), (20, 18)], OXIDO[2])
    for x in range(6, 21, 3):
        d.line((x, 22, x, 48), OXIDO[3])
    d.polygon([(14, 50), (16, 30), (34, 34), (34, 50)], c("3f5f73")); d.polygon([(16, 30), (20, 24), (35, 28), (34, 34)], c("5f8399"))
    for x in range(18, 33, 3):
        d.line((x, 33, x, 49), c("2f4757"))
    d.line((0, 44, 10, 36), METAL[3]); d.line((24, 8, 30, 2), METAL[3])
    return terminar(img)

def auto_quemado(seed):
    rng = random.Random(seed)
    img = nuevo(44, 28); d = ImageDraw.Draw(img)
    cuerpo = rng.choice([c("4a3a34"), c("3a3a40"), c("5a3a2a")])
    d.rounded_rectangle((2, 8, 41, 23), 3, cuerpo); d.polygon([(10, 8), (14, 1), (30, 1), (35, 8)], ilum(cuerpo, 1.1))
    d.polygon([(13, 7), (16, 3), (21, 3), (21, 7)], c("1a1a1e")); d.polygon([(23, 7), (23, 3), (28, 3), (32, 7)], c("1a1a1e"))
    for x in (9, 33):
        d.ellipse((x - 4, 18, x + 4, 27), c("1a1a1a"))
    ruido(img, (2, 8, 41, 23), [OXIDO[1], c("2a2220"), OXIDO[0]], 0.25, rng)
    return terminar(img)

def camion():
    img = nuevo(104, 52); d = ImageDraw.Draw(img)
    d.polygon([(2, 46), (6, 12), (70, 4), (72, 40)], c("8a8a84"))            # remolque cruzado
    d.polygon([(6, 12), (10, 6), (72, 0), (70, 4)], c("aaa69f"))
    for x in range(12, 68, 6):
        d.line((x, 12 - (x - 12) // 8, x + 1, 44 - (x - 12) // 9), c("6a6a64"))
    escribir(d, 20, 22, "VIVERES", c("8a2a2a"))
    d.polygon([(72, 40), (74, 16), (100, 18), (102, 46)], c("8a3a2a"))       # cabina
    d.polygon([(78, 20), (96, 21), (96, 30), (78, 29)], c("1e2428"))
    for x in (16, 58, 88):
        d.ellipse((x - 6, 40, x + 6, 51), c("1a1a1a"))
    ruido(img, (2, 0, 102, 46), [OXIDO[1], OXIDO[0]], 0.08, random.Random(2))
    return terminar(img)

def pilar():
    """Pilar roto de la vieja autopista elevada, con fierros saliendo."""
    img = nuevo(36, 88); d = ImageDraw.Draw(img)
    d.rectangle((8, 20, 27, 87), CONCRETO[1]); d.line((8, 20, 8, 87), CONCRETO[3]); d.line((27, 20, 27, 87), CONCRETO[2])
    d.polygon([(0, 22), (6, 12), (30, 8), (35, 18), (28, 24), (6, 26)], CONCRETO[0])
    for (x, y) in ((10, 8), (16, 2), (24, 4), (30, 6)):
        d.line((x, 14, x + 2, y), OXIDO[2])
    for y in range(30, 86, 9):
        d.line((10, y, 25, y + 2), CONCRETO[2])
    d.line((12, 40, 18, 56, 14, 70), CONCRETO[4])
    escribir(d, 11, 60, "VS", c("c43a3a"))
    return terminar(img)

def letrero_autopista():
    img = nuevo(72, 60); d = ImageDraw.Draw(img)
    for x in (8, 62):
        d.rectangle((x, 26, x + 2, 59), METAL[2])
    d.rectangle((0, 0, 71, 30), c("1e6a3a")); d.rectangle((0, 0, 71, 30), outline=c("e8ecf0"))
    escribir(d, 4, 4, "< BASTION", c("e8ecf0"))
    escribir(d, 4, 12, "> METRO", c("e8ecf0"))
    escribir(d, 4, 20, "SUMIDERO", c("e6c34a"))
    d.ellipse((50, 18, 66, 28), c("2a2a2a")); d.point((55, 22), c("e8e8e8")); d.point((60, 22), c("e8e8e8"))   # alguien pintó una calavera
    d.line((52, 26, 64, 26), c("e8e8e8"))
    return terminar(img, 1.05, 0.85)

def generar_decorados():
    for tipo in ("tienda", "posada", "grafiti"):
        guardar(vagon(tipo), f"decorados/vagon_{tipo}.png")
    guardar(laboratorio(), "decorados/laboratorio.png")
    guardar(ventanilla(), "decorados/ventanilla.png")
    guardar(tanque_veneno(), "decorados/tanque_veneno.png")
    guardar(tanque_veneno(True), "decorados/tanque_limpio.png")
    guardar(altavoz(), "decorados/altavoz.png")
    guardar(hongo_gigante(c("4ae0d0"), 1), "decorados/hongo_cian.png")
    guardar(hongo_gigante(c("a46ae8"), 2), "decorados/hongo_morado.png")
    guardar(mapa_metro(), "decorados/mapa_metro.png")
    guardar(memorial(), "decorados/memorial.png")
    guardar(cartel_benefactor(), "decorados/cartel_benefactor.png")
    guardar(taller_nilo(), "decorados/taller_nilo.png")
    guardar(valvula(), "decorados/valvula.png")
    guardar(valvula(True), "decorados/valvula_cerrada.png")
    guardar(jaulas(), "decorados/jaulas.png")
    guardar(boca_metro(), "decorados/boca_metro.png")
    guardar(barricada(), "decorados/barricada.png")
    guardar(auto_quemado(1), "decorados/auto_quemado_1.png")
    guardar(auto_quemado(2), "decorados/auto_quemado_2.png")
    guardar(camion(), "decorados/camion.png")
    guardar(pilar(), "decorados/pilar.png")
    guardar(letrero_autopista(), "decorados/letrero_autopista.png")


# ---------------------------------------------------------------------------
# PERSONAS DEL SUMIDERO (16x24 en el mapa): tosen, tienen vendas sucias, piden comida
# ---------------------------------------------------------------------------
VENDA = c("d8ccb0"); VENDA_S = c("a89a7a")
import arte_bastion as ab   # noqa: E402  (nino_frente)

def vendado_mapa():
    def extra(d, dy):
        d.rectangle((4, 2 + dy, 7, 3 + dy), VENDA); d.point((4, 4 + dy), VENDA_S)   # venda en la cabeza
        d.point((5, 9 + dy), c("6a7a5a"))                                          # palidez verdosa
        d.line((2, 13 + dy, 2, 15 + dy), VENDA)                                    # brazo vendado
    return persona_frente(c("b8a080"), c("3a3430"), "corto", c("4a5a52"), c("3a4842"), c("3a3a36"), c("2a2620"), extra=extra, encorvado=True)

def vendada_mapa():
    def extra(d, dy):
        d.rectangle((3, 12 + dy, 7, 13 + dy), VENDA)                               # venda en el pecho
        d.point((5, 9 + dy), c("6a7a5a"))
    def despues(d, dy):
        d.rectangle((9, 7 + dy, 11, 8 + dy), VENDA)                                # parche en la mejilla
    return persona_frente(c("c8a888"), c("5a3a4a"), "largo", c("5a4a62"), c("443850"), c("3a3a36"), c("2a2620"), extra=extra, despues=despues, encorvado=True)

def anciano_mapa():
    def extra(d, dy):
        d.rectangle((4, 8 + dy, 7, 10 + dy), c("d0ccc4"))                         # barba
    def despues(d, dy):
        d.line((12, 13, 13, 23), MADERA[1])                                         # bastón
        d.rectangle((9, 2 + dy, 11, 3 + dy), VENDA)
    return persona_frente(c("a89070"), c("d0ccc4"), "corto", c("5a5a4a"), c("4a4a3c"), c("3a3a36"), c("2a2620"), extra=extra, despues=despues, encorvado=True)

def nino_tos_mapa():
    def extra(d):
        d.point((5, 10), c("6a7a5a")); d.line((4, 14, 7, 14), VENDA)
    return ab.nino_frente(c("c0a080"), c("2a2220"), c("5a6a7a"), c("4a5868"), c("3a3a36"), c("2a2018"), extra=extra)

def nina_tos_mapa():
    def extra(d):
        d.point((5, 10), c("6a7a5a"))
    def despues(d):
        d.rectangle((9, 15, 10, 17), VENDA)
    return ab.nino_frente(c("d0b090"), c("6a3a2a"), c("8a5a6a"), c("6a4450"), c("3a3a36"), c("2a2018"), extra=extra, despues=despues, coletas=True)

def nilo_mapa():
    """Nilo, el joven que arma filtros de agua: gafas en la frente, overol, cinturón de herramientas."""
    def extra(d, dy):
        d.rectangle((3, 2, 7, 3), c("3a3a40")); d.point((4, 2), CIAN)              # gafas
        d.rectangle((3, 15, 7, 15), MADERA[1]); d.point((4, 16), METAL[4])         # cinturón
        d.rectangle((4, 11, 7, 14), c("4a6a7a"))                                   # overol
    return persona_frente(c("a87a58"), c("1e1a18"), "corto", c("5a6a6a"), c("44524f"), c("3e5a6a"), c("2a2018"), extra=extra)

def iris_mapa():
    """Iris: chica de 14 años, pelo corto violeta oscuro, brazo vendado, mochila."""
    def extra(d):
        d.line((3, 14, 3, 17), VENDA)
    def despues(d):
        d.rectangle((11, 13, 13, 17), c("6a4a2a"))                                 # mochila
    return ab.nino_frente(c("c8a080"), c("3a2a4a"), c("2e5a5a"), c("204444"), c("3a3a40"), c("2a2018"), extra=extra, despues=despues)

def padre_iris_mapa():
    """El papá de Iris: muy enfermo, envuelto en una manta."""
    def extra(d, dy):
        d.polygon([(2, 9 + dy), (7, 9 + dy), (7, 21), (3, 21)], c("6a5a7a"))        # manta
        d.point((5, 9 + dy), c("5a7a4a"))
    return persona_frente(c("a89a80"), c("4a4440"), "corto", c("6a5a7a"), c("4a3e5a"), c("3a3a36"), c("2a2620"), extra=extra, encorvado=True)

def sabina_mapa():
    """Sabina, la mercader del vagón: máscara colgando del cuello, delantal con frascos."""
    def extra(d, dy):
        d.rectangle((4, 11, 7, 12), c("4a5a48")); d.point((5, 12), METAL[2])      # máscara al cuello
        d.rectangle((4, 13, 7, 17), c("6a4a3a")); d.point((4, 14), c("4ac8e8")); d.point((6, 15), c("e04a5a"))
    return persona_frente(c("b88a68"), c("8a8a8a"), "largo", c("3a5a5a"), c("2a4444"), c("3a3a36"), c("2a2018"), extra=extra)

def tula_mapa():
    """Tula, el que cuida el vagón dormitorio: grandote, gorro de lana, farol."""
    def extra(d, dy):
        d.rectangle((3, 0, 7, 3), c("8a3a3a")); d.point((5, 0), c("c85a5a"))       # gorro
        d.rectangle((2, 11, 7, 17), c("5a4a3a"))
    def despues(d, dy):
        d.line((13, 14, 13, 17), METAL[3]); d.rectangle((12, 17, 14, 20), c("ffd27a"))   # farol
    return persona_frente(c("8a6248"), c("2a2220"), "corto", c("5a4a3a"), c("44382a"), c("3a3a36"), c("2a2018"), extra=extra, despues=despues)

def guardia_org_mapa():
    """Guardia de la Organización: máscara de gas, uniforme verde oscuro, brazalete con el sol."""
    def extra(d, dy):
        d.rectangle((4, 5, 7, 9), c("3a4a3a")); d.point((5, 6), c("8af0a0"))        # máscara de gas
        d.rectangle((4, 9, 6, 10), METAL[1])
        d.line((3, 14, 7, 14), METAL[3])
        d.point((2, 13), c("e6c34a"))                                               # brazalete del Benefactor
    return persona_frente(c("b88458"), c("1e2420"), "corto", c("2e3e34"), c("223028"), c("2a3028"), c("1a1a18"), extra=extra)

def cazador_mapa():
    """Cazador furtivo: capucha de camuflaje, cara tapada, cuchillo."""
    def extra(d, dy):
        d.rectangle((4, 6, 7, 9), c("4a4a3a"))                                      # pañuelo
        d.point((3, 12), c("6a7a4a")); d.point((6, 15), c("3a4a2a"))
    def despues(d, dy):
        d.line((12, 15, 14, 19), METAL[4]); d.point((12, 15), MADERA[1])
    return persona_frente(c("a87a58"), c("4a5a3a"), "capucha", c("5a6a42"), c("3e4a2e"), c("3a3a2a"), c("2a2018"), extra=extra, despues=despues)

def vesper_mapa():
    """La Dra. Vesper: bata blanca impecable, moño tirante, gafas verdes."""
    piel = c("d8c0a8")
    img = nuevo(16, 24); d = ImageDraw.Draw(img)
    d.rectangle((4, 18, 6, 21), c("2a3a30")); d.rectangle((4, 22, 6, 23), c("1a1a1a"))
    d.polygon([(2, 11), (7, 11), (7, 21), (1, 21)], LAB[0])                         # bata larga
    d.line((7, 11, 7, 21), LAB[2])
    d.rectangle((4, 11, 7, 13), c("2a3a30"))                                        # cuello oscuro
    d.rectangle((4, 3, 7, 10), piel)
    d.rectangle((3, 1, 7, 3), c("2a3a30")); d.rectangle((3, 4, 3, 8), c("2a3a30"))
    d.rectangle((4, 6, 5, 7), c("6aff8a"))                                          # gafas verdes
    espejar(img)
    d = ImageDraw.Draw(img)
    d.ellipse((6, -1, 9, 2), c("2a3a30"))                                           # moño
    d.point((10, 15), TOXICO[1]); d.point((5, 18), TOXICO[0])                        # manchitas
    d.rectangle((11, 14, 12, 17), c("8af0a0"))                                      # tubo de ensayo en la mano
    luz_lateral(img); contorno_suave(img)
    return img

def rata_mapa():
    """Rata del subterráneo: 2 cuadros de 12x8 (corre)."""
    hoja = nuevo(24, 8)
    for f in range(2):
        img = nuevo(12, 8); d = ImageDraw.Draw(img)
        d.ellipse((2, 2, 9, 6), c("5a4e4a")); d.ellipse((7, 2, 11, 5), c("6a5e58"))
        d.point((10, 3), c("ff4a4a")); d.point((8, 1), c("8a6e6a"))
        d.line((2, 4, 0, 2 + f * 2), c("8a6e6a"))                                  # cola
        d.point((4 + f, 7), c("3a302c")); d.point((7 - f, 7), c("3a302c"))
        contorno(img)
        hoja.alpha_composite(img, (f * 12, 0))
    return hoja


# ---------------------------------------------------------------- en combate (32x48)
def vesper_combate():
    piel = c("d8c0a8")
    def extra(d):
        d.polygon([(6, 18), (15, 16), (15, 44), (5, 44)], LAB[0])                   # bata hasta las rodillas
        d.line((9, 18, 9, 44), LAB[2])
        d.rectangle((12, 17, 15, 22), c("2a3a30"))                                  # camisa oscura
        d.rectangle((11, 8, 13, 11), c("2a3a30")); d.rectangle((11, 9, 12, 10), c("6aff8a"))   # gafas
        d.point((7, 30), TOXICO[1]); d.point((8, 38), TOXICO[0])
    def despues(d):
        d.ellipse((13, -1, 19, 4), c("2a3a30")); d.line((18, 1, 22, -1), c("c9c9d1"))  # moño con aguja
        d.rectangle((24, 22, 26, 30), c("8af0a0")); d.rectangle((24, 22, 26, 23), c("e8e8e0"))   # tubo de ensayo verde
        d.point((25, 27), c("e0ffe0"))
        d.line((19, 14, 21, 14), c("6a2a4a"))                                       # sonrisa
    return figura(piel, c("2a3a30"), "corto", LAB[0], LAB[2], c("2a3a30"), c("1a1a1a"), ojos=c("4aaa5a"), extra=extra, despues=despues)

def guardia_org_combate():
    def extra(d):
        d.rectangle((10, 8, 15, 15), c("3a4a3a")); d.rectangle((11, 9, 12, 11), c("8af0a0"))   # máscara de gas
        d.rectangle((12, 13, 15, 16), METAL[1])
        d.line((9, 24, 15, 24), METAL[3])
        d.rectangle((5, 20, 8, 22), c("e6c34a"))                                    # brazalete
    def despues(d):
        d.rectangle((20, 26, 30, 28), METAL[1]); d.rectangle((27, 24, 30, 26), METAL[3])   # arma corta
        d.ellipse((15, 15, 18, 19), METAL[0])                                       # filtro de la máscara
    return figura(c("b88458"), c("1e2420"), "corto", c("2e3e34"), c("223028"), c("2a3028"), c("1a1a18"), ojos=c("8af0a0"), extra=extra, despues=despues)

def cazador_combate():
    def extra(d):
        d.rectangle((9, 1, 15, 8), c("5a6a42")); d.rectangle((8, 4, 9, 18), c("5a6a42"))   # capucha
        d.rectangle((10, 11, 15, 15), c("4a4a3a"))                                  # pañuelo
        d.point((10, 22), c("3e4a2e")); d.point((12, 28), c("6a7a4a")); d.point((7, 25), c("3e4a2e"))
    def despues(d):
        d.line((24, 30, 28, 38), METAL[4]); d.rectangle((23, 28, 25, 30), MADERA[1])   # cuchillo
        d.line((3, 16, 3, 40), MADERA[1]); d.line((2, 16, 4, 16), METAL[3])        # lanza a la espalda
    return figura(c("a87a58"), c("3a3a2a"), "corto", c("5a6a42"), c("3e4a2e"), c("3a3a2a"), c("2a2018"), ojos=c("c8a040"), extra=extra, despues=despues)


# ---------------------------------------------------------------------------
# RETRATOS 48x48
# ---------------------------------------------------------------------------
def retrato_nilo():
    piel = c("a87a58")
    def m(d):
        hombros(d, c("3e5a6a"), c("2e4450"))
        cara_base(d, piel)
        ojo(d, c("3a2a1a"), x=16, y=24)
        ceja(d, c("1e1a18"), "recta", y=21)
        nariz(d, piel); boca(d, piel, "sonrisa")
        d.polygon([(11, 22), (10, 12), (15, 8), (23, 7), (23, 11), (17, 11), (14, 15), (13, 20)], c("1e1a18"))
        d.rectangle((12, 14, 23, 18), c("3a3a40")); d.rectangle((15, 15, 19, 17), CIAN)   # gafas en la frente
        d.point((16, 30), c("4a4238"))
    return retrato48(c("2a3a40"), piel, m)

def retrato_iris():
    piel = c("c8a080")
    def m(d):
        hombros(d, c("2e5a5a"), c("204444"))
        cara_base(d, piel, delgada=1)
        ojo(d, c("6a4a8a"), x=16, y=24)
        ceja(d, c("3a2a4a"), "enojo", y=21)
        nariz(d, piel); boca(d, piel, "seria")
        d.polygon([(10, 28), (10, 14), (15, 9), (23, 8), (23, 12), (16, 13), (13, 18), (12, 28)], c("3a2a4a"))
        d.line((2, 44, 8, 40), VENDA); d.line((3, 46, 9, 42), VENDA_S)
    def despues(d):
        d.point((30, 29), c("6a7a5a"))
    return retrato48(c("2a2a40"), piel, m, despues)

def retrato_sabina():
    piel = c("b88a68")
    def m(d):
        hombros(d, c("3a5a5a"), c("2a4444"))
        d.polygon([(12, 47), (14, 40), (23, 40), (23, 47)], c("6a4a3a"))
        cara_base(d, piel, delgada=1)
        ojo(d, c("4a5a4a"), x=16, y=24)
        d.line((14, 28, 16, 29), oscurecer(piel, 0.78))
        ceja(d, c("8a8a8a"), "recta", y=21)
        nariz(d, piel); boca(d, piel, "seria")
        d.polygon([(5, 44), (8, 24), (11, 13), (17, 8), (23, 7), (23, 11), (16, 13), (12, 20), (11, 36), (9, 44)], c("8a8a8a"))
        d.polygon([(14, 37), (23, 36), (23, 42), (15, 42)], c("4a5a48")); d.ellipse((17, 38, 21, 42), METAL[2])   # máscara al cuello
    return retrato48(c("2a3a34"), piel, m)

def retrato_tula():
    piel = c("8a6248")
    def m(d):
        hombros(d, c("5a4a3a"), c("44382a"))
        cara_base(d, piel, quijada=2)
        ojo(d, c("3a2a1a"), x=16, y=24)
        ceja(d, c("2a2220"), "recta", y=21)
        nariz(d, piel); boca(d, piel, "sonrisa")
        d.polygon([(13, 30), (23, 31), (23, 38), (16, 37), (13, 33)], c("2a2220"))   # barba
        d.polygon([(11, 18), (12, 10), (17, 6), (23, 5), (23, 18)], c("8a3a3a"))      # gorro de lana
        d.line((11, 17, 23, 17), c("6a2a2a"))
    return retrato48(c("3a2a24"), piel, m)

def retrato_guardia_org():
    piel = c("b88458")
    def m(d):
        hombros(d, c("2e3e34"), c("223028"))
        cara_base(d, piel)
        d.polygon([(12, 20), (14, 16), (23, 15), (23, 40), (17, 40), (13, 34)], c("3a4a3a"))   # máscara de gas
        d.ellipse((15, 20, 21, 26), c("1e2a1e")); d.ellipse((16, 21, 20, 25), c("8af0a0")); d.point((17, 22), c("e0ffe8"))
        d.ellipse((17, 31, 23, 39), METAL[1]); d.line((18, 34, 23, 34), METAL[3])
        d.polygon([(11, 16), (12, 9), (17, 6), (23, 5), (23, 15), (14, 16)], c("1e2420"))   # casco
        d.point((3, 44), c("e6c34a")); d.point((4, 45), c("e6c34a"))
    return retrato48(c("1e2a24"), piel, m)

def retrato_cazador():
    piel = c("a87a58")
    def m(d):
        hombros(d, c("5a6a42"), c("3e4a2e"))
        cara_base(d, piel, delgada=1)
        ojo_felino(d, c("c8a040"), x=15, y=23)
        ceja(d, c("3a3a2a"), "enojo", y=21)
        nariz(d, piel)
        d.polygon([(12, 28), (23, 27), (23, 40), (16, 40), (13, 34)], c("4a4a3a"))     # pañuelo sobre la boca
        d.polygon([(6, 40), (8, 18), (12, 8), (18, 4), (23, 3), (23, 8), (16, 10), (12, 18), (11, 40)], c("5a6a42"))   # capucha
        d.point((9, 30), c("3e4a2e")); d.point((10, 22), c("6a7a4a"))
    return retrato48(c("2a2e20"), piel, m)

def retrato_nino():
    piel = c("c0a080")
    def m(d):
        hombros(d, c("5a6a7a"), c("4a5868"))
        cara_base(d, piel, delgada=1)
        ojo(d, c("3a2a1a"), x=16, y=24)
        ceja(d, c("2a2220"), "triste", y=21)
        nariz(d, piel); boca(d, piel, "triste")
        d.polygon([(11, 22), (10, 12), (15, 8), (23, 7), (23, 11), (17, 10), (14, 14), (13, 19)], c("2a2220"))
        d.line((14, 28, 16, 28), c("6a7a5a"))
    return retrato48(c("2a3038"), piel, m)

def retrato_vendado():
    piel = c("b8a080")
    def m(d):
        hombros(d, c("4a5a52"), c("3a4842"))
        cara_base(d, piel)
        ojo(d, c("4a4a3a"), x=16, y=24)
        d.line((15, 27, 21, 27), oscurecer(piel, 0.75))
        ceja(d, c("3a3430"), "triste", y=21)
        nariz(d, piel); boca(d, piel, "triste")
        d.polygon([(11, 20), (12, 12), (17, 8), (23, 7), (23, 16), (13, 17)], VENDA)   # venda en la cabeza
        d.line((12, 14, 23, 13), VENDA_S); d.point((16, 11), c("8a4a3a"))
    def despues(d):
        d.point((31, 30), c("6a7a5a")); d.point((16, 31), c("6a7a5a"))
    return retrato48(c("2a3430"), piel, m, despues)


def generar_personas():
    for nombre, f in (("vendado_mapa", vendado_mapa), ("vendada_mapa", vendada_mapa), ("anciano_mapa", anciano_mapa),
                      ("nino_tos_mapa", nino_tos_mapa), ("nina_tos_mapa", nina_tos_mapa), ("nilo_mapa", nilo_mapa),
                      ("iris_mapa", iris_mapa), ("padre_iris_mapa", padre_iris_mapa), ("sabina_mapa", sabina_mapa),
                      ("tula_mapa", tula_mapa), ("guardia_org_mapa", guardia_org_mapa), ("cazador_mapa", cazador_mapa),
                      ("vesper_mapa", vesper_mapa), ("rata_mapa", rata_mapa), ("vesper_combate", vesper_combate),
                      ("guardia_org_combate", guardia_org_combate), ("cazador_combate", cazador_combate)):
        guardar(f(), f"personajes/{nombre}.png")
    for nombre, f in (("nilo", retrato_nilo), ("iris", retrato_iris), ("sabina", retrato_sabina), ("tula", retrato_tula),
                      ("guardia_org", retrato_guardia_org), ("cazador", retrato_cazador), ("nino", retrato_nino),
                      ("vendado", retrato_vendado)):
        guardar(f(), f"retratos/{nombre}.png")


# ---------------------------------------------------------------------------
# CRIATURAS NUEVAS (64x64, miran a la DERECHA, patas en la fila 60-61)
# ---------------------------------------------------------------------------
LO = c("5a5452"); LO2 = c("3a3634"); LO3 = c("7a7470"); LO_B = c("a8a29c"); BRASA = c("ff7a2a")
def lobo_base(d, img):
    P(d, [(10, 40), (16, 40), (14, 52), (10, 61), (6, 61), (9, 50)], LO2)          # pata trasera de atrás
    P(d, [(36, 42), (42, 42), (42, 54), (40, 61), (36, 61), (37, 52)], LO2)        # pata delantera de atrás
    P(d, [(4, 30), (14, 24), (36, 22), (46, 26), (48, 40), (38, 46), (12, 46), (4, 40)], LO)   # cuerpo
    P(d, [(0, 26), (6, 24), (10, 30), (4, 36), (0, 34)], LO3)                      # cola peluda
    P(d, [(16, 42), (22, 42), (22, 54), (20, 61), (15, 61), (17, 52)], LO)         # pata trasera
    P(d, [(42, 40), (48, 40), (48, 54), (49, 61), (43, 61), (43, 52)], LO)         # pata delantera
    P(d, [(38, 22), (44, 14), (50, 10), (56, 12), (62, 18), (63, 24), (56, 28), (48, 32), (42, 30)], LO)   # cabeza
    P(d, [(44, 14), (46, 4), (50, 10)], LO3); P(d, [(50, 10), (54, 2), (56, 12)], LO3)   # orejas
    P(d, [(18, 22), (24, 16), (30, 18), (36, 16), (40, 22)], LO3)                  # melena erizada

def lobo_det(d, img):
    for pts in (((14, 30), (18, 34), (16, 38)), ((26, 28), (30, 32), (28, 38)), ((38, 30), (40, 36)), ((20, 44), (20, 50))):
        d.line(pts, BRASA)                                                           # grietas de brasa
    d.point((18, 34), c("ffe08a")); d.point((30, 32), c("ffe08a"))
    d.rectangle((54, 15, 56, 16), c("ffb03a")); d.point((56, 15), c("fff0c0"))     # ojo de brasa
    d.line((56, 24, 63, 24), c("2a1a18")); d.polygon([(58, 24), (59, 26), (60, 24)], c("f0e8d8")); d.polygon([(61, 24), (62, 26), (63, 24)], c("f0e8d8"))
    d.point((62, 19), c("1a1414"))                                                  # nariz
    for (x, y) in ((63, 26), (62, 29), (63, 31)):                                   # humo de la boca
        d.point((x, y), c("9a9490"))
    for x in (7, 16, 37, 44):
        d.point((x, 61), LO_B)

CA = c("4a6a3e"); CA2 = c("34502c"); CA3 = c("6a8a52"); CA_B = c("9ab878")
def cazador_base(d, img):
    P(d, [(4, 54), (12, 46), (20, 48), (14, 56), (2, 60)], CA2)                     # cola enroscada
    P(d, [(18, 44), (24, 44), (20, 54), (16, 61), (12, 61), (16, 52)], CA2)         # pierna de atrás (agachado)
    P(d, [(20, 26), (32, 20), (42, 24), (44, 38), (36, 46), (20, 46), (16, 36)], CA)   # torso inclinado
    P(d, [(32, 42), (40, 42), (44, 52), (46, 61), (38, 61), (36, 52)], CA)          # pierna de adelante
    P(d, [(40, 24), (50, 30), (56, 38), (54, 40), (46, 34), (40, 32)], CA2)         # brazo con garras
    P(d, [(36, 12), (46, 8), (56, 12), (60, 18), (54, 24), (42, 24), (36, 20)], CA)   # cabeza alargada
    P(d, [(36, 12), (34, 6), (40, 8)], CA3)                                         # cresta

def cazador_det(d, img):
    rng = random.Random(21)
    for _ in range(30):                                                             # escamas camaleónicas
        x, y = rng.randrange(14, 56), rng.randrange(8, 58)
        if img.getpixel((x, y))[3] > 0:
            d.point((x, y), rng.choice([CA3, CA_B, c("8a6a3a"), c("3a4a6a")]))
    d.ellipse((47, 11, 53, 17), CA3); d.ellipse((49, 13, 52, 16), c("e6c34a")); d.point((50, 14), c("1a1a1a"))   # ojo giratorio
    d.line((56, 20, 63, 22), c("e04a6a")); d.point((63, 22), c("ff8aa0"))           # lengua
    for (x, y) in ((54, 40), (56, 38), (55, 42)):
        d.point((x, y), c("e8e0d0"))                                                # garras
    d.line((22, 30, 30, 26, 38, 30), CA3)

TE = c("2e2240"); TE2 = c("1e1630"); TE3 = c("4a3a66"); TE_B = c("8a6ab0"); HILO = c("c8b0ff")
def tejedor_base(d, img):
    P(d, [(26, 40), (30, 40), (26, 52), (24, 61), (21, 61), (23, 50)], TE2)         # pierna de atrás
    P(d, [(32, 40), (36, 40), (38, 52), (40, 61), (36, 61), (34, 52)], TE)          # pierna de adelante
    P(d, [(26, 18), (36, 18), (38, 30), (36, 42), (26, 42), (24, 30)], TE)          # torso flaco
    P(d, [(26, 20), (18, 28), (10, 36), (6, 34), (14, 26), (24, 18)], TE2)          # brazo largo atrás
    P(d, [(36, 20), (46, 22), (56, 18), (58, 20), (48, 26), (36, 26)], TE)          # brazo extendido
    P(d, [(26, 4), (36, 4), (38, 12), (35, 18), (27, 18), (25, 12)], TE3)           # cabeza sin rostro
    P(d, [(24, 4), (31, 0), (38, 4), (36, 2), (31, 2)], TE2)

def tejedor_det(d, img):
    d.rectangle((32, 9, 34, 10), c("e0a0ff")); d.point((34, 9), c("ffffff"))        # ojo violeta
    d.rectangle((28, 9, 29, 10), c("a070d0"))
    for (x0, y0, x1, y1) in ((58, 20, 63, 6), (58, 20, 63, 34), (57, 19, 50, 4), (6, 34, 0, 20), (6, 34, 2, 50)):
        d.line((x0, y0, x1, y1), HILO)                                               # hilos de sombra
    d.line((63, 6, 63, 34), HILO); d.line((50, 4, 63, 6), HILO)
    for (x, y) in ((60, 13), (60, 27), (3, 27), (4, 42)):
        d.point((x, y), c("ffffff"))
    d.line((28, 24, 34, 24), TE3); d.line((28, 30, 34, 30), TE3); d.line((29, 36, 33, 36), TE3)   # costillas

BU = c("6ac83a"); BU2 = c("4a9a2a"); BU3 = c("9ae05a"); BU_B = c("d8ffb0")
def burbuja_base(d, img):
    P(d, [(4, 61), (6, 44), (14, 30), (26, 22), (40, 22), (52, 30), (60, 44), (62, 61)], BU)   # cuerpo gelatinoso
    P(d, [(2, 61), (10, 56), (54, 56), (63, 61)], BU2)                                # charco a sus pies
    P(d, [(40, 22), (46, 14), (52, 18), (52, 30)], BU)                                # gota que se estira

def burbuja_det(d, img):
    d.ellipse((24, 34, 40, 50), c("2a5a1a")); d.ellipse((27, 37, 37, 47), c("e6f04a")); d.ellipse((30, 40, 34, 44), c("ffffa0"))   # núcleo tóxico
    for (x, y, r) in ((14, 46, 3), (48, 40, 4), (42, 52, 2), (20, 32, 2), (54, 52, 2), (10, 56, 2)):
        d.ellipse((x - r, y - r, x + r, y + r), BU3); d.point((x - r + 1, y - r + 1), BU_B)   # burbujas dentro
    d.ellipse((42, 28, 46, 32), c("1e2a1a")); d.point((43, 29), c("ffffff"))         # ojo
    d.ellipse((50, 28, 53, 31), c("1e2a1a"))
    d.line((16, 28, 26, 23), BU_B); d.line((8, 44, 12, 34), BU_B)                    # brillo de gelatina
    for x in (6, 30, 58):
        d.point((x, 61), BU3)

SI = c("6a6a48"); SI2 = c("4a4a32"); SI3 = c("8a8a5a"); SI_B = c("b8b880")
def sirena_base(d, img):
    P(d, [(0, 61), (4, 52), (20, 48), (44, 48), (60, 52), (63, 61)], c("4a4430"))    # charco de lodo
    P(d, [(16, 50), (20, 38), (26, 30), (38, 30), (40, 40), (36, 50)], SI)           # cola que sale del lodo
    P(d, [(26, 14), (36, 12), (40, 22), (38, 32), (26, 32), (24, 22)], SI)           # torso
    P(d, [(36, 18), (46, 24), (52, 34), (48, 36), (42, 28), (36, 26)], SI2)          # brazo que atrapa
    P(d, [(28, 2), (38, 2), (40, 10), (36, 16), (28, 16), (26, 10)], SI3)            # cabeza
    P(d, [(26, 4), (22, 14), (18, 28), (14, 40), (20, 36), (24, 24), (28, 8)], SI2)  # pelo de lodo que chorrea

def sirena_det(d, img):
    d.rectangle((34, 7, 36, 8), c("e0e08a")); d.point((36, 7), c("ffffff"))          # ojo amarillo
    d.line((36, 12, 39, 12), SI2)
    for (x, y) in ((48, 36), (50, 38), (46, 38)):
        d.point((x, y), c("3a3420"))                                                # dedos de barro
    for (x, y) in ((18, 44), (30, 36), (34, 44), (24, 26)):
        d.point((x, y), SI_B)                                                       # escamas
    for (x, y) in ((8, 56), (52, 55), (40, 58)):
        d.ellipse((x - 2, y - 1, x + 2, y + 1), c("6a6240")); d.point((x, y - 1), c("a8a070"))   # burbujas de lodo
    d.line((14, 40, 12, 50), SI2); d.point((12, 51), c("3a3420"))                  # gota de lodo

GF = c("4a7a3a"); GF2 = c("34582a"); GF3 = c("6a9a4a"); GF_B = c("a8d878"); TRONCO = c("6a4a2e")
def guardian_base(d, img):
    P(d, [(14, 61), (18, 50), (22, 44), (28, 44), (26, 54), (22, 61)], TRONCO)       # pierna-raíz de atrás
    P(d, [(32, 44), (40, 44), (44, 54), (50, 61), (40, 61), (36, 52)], TRONCO)       # pierna-raíz de adelante
    P(d, [(18, 22), (40, 20), (46, 30), (44, 46), (18, 46), (14, 32)], GF)           # torso de hojas
    P(d, [(42, 24), (52, 30), (58, 40), (54, 42), (46, 34)], GF2)                    # brazo-enredadera
    P(d, [(18, 24), (10, 32), (6, 44), (10, 46), (16, 36)], GF2)
    P(d, [(24, 6), (36, 4), (42, 12), (40, 22), (24, 22), (20, 14)], GF3)            # cabeza
    for (x, y, r) in ((22, 6, 5), (38, 4, 4), (30, 2, 4)):                           # copa de hojas
        d.ellipse((x - r, y - r, x + r, y + r), GF)

def guardian_det(d, img):
    rng = random.Random(33)
    for _ in range(22):                                                             # hojas
        x, y = rng.randrange(10, 56), rng.randrange(2, 46)
        if img.getpixel((x, y))[3] > 0:
            d.polygon([(x, y), (x + 2, y - 1), (x + 1, y + 1)], rng.choice([GF_B, GF3, c("3a6a2a")]))
    d.ellipse((30, 26, 38, 34), c("e04a8a")); d.ellipse((32, 28, 36, 32), c("ffd24a"))   # flor-corazón que late
    d.rectangle((34, 11, 36, 12), c("ffe04a")); d.point((36, 11), c("ffffff"))       # ojo
    d.line((58, 40, 63, 46), GF2); d.line((6, 44, 2, 50), GF2)                       # zarcillos
    for (x0, y0, x1, y1) in ((14, 61, 8, 63), (22, 61, 26, 63), (50, 61, 56, 63), (40, 61, 36, 63)):
        d.line((x0, y0, x1, y1), TRONCO)                                            # raíces en el suelo
    d.point((58, 41), c("e04a8a"))

HU = c("c8c0b4"); HU2 = c("a09888"); HU3 = c("dcd6cc"); HU_B = c("f0ece4")
def humanoide_base(d, img):
    P(d, [(22, 40), (28, 40), (28, 54), (26, 61), (21, 61), (22, 52)], HU2)          # pierna de atrás
    P(d, [(32, 40), (38, 40), (40, 54), (42, 61), (36, 61), (34, 52)], HU)           # pierna de adelante
    P(d, [(22, 16), (40, 16), (42, 30), (40, 42), (22, 42), (20, 30)], HU)           # torso de maniquí
    P(d, [(22, 18), (14, 26), (12, 40), (16, 40), (20, 28)], HU2)                    # brazo de atrás
    P(d, [(40, 18), (50, 22), (58, 26), (58, 30), (48, 28), (40, 26)], HU)           # brazo estirado hacia adelante
    P(d, [(24, 2), (36, 2), (38, 10), (36, 16), (26, 16), (24, 10)], HU3)            # cabeza lisa, sin cara

def humanoide_det(d, img):
    for (x0, y0, x1, y1) in ((24, 22, 30, 30), (30, 30, 28, 38), (36, 6, 34, 12), (50, 24, 54, 28), (26, 46, 24, 52)):
        d.line((x0, y0, x1, y1), c("6a9a3a"))                                        # grietas infectadas
    for (x, y) in ((30, 30), (34, 12), (54, 28), (24, 52)):
        d.point((x, y), c("b6f06a"))
    d.line((22, 40, 40, 40), HU2); d.line((30, 16, 30, 40), HU2)                     # costuras de maniquí
    d.line((26, 9, 36, 9), HU2)
    for (x, y) in ((58, 26), (58, 30)):
        d.point((x, y), HU_B)

def generar_criaturas():
    g.criatura("lobo_de_ceniza", lobo_base, lobo_det, LO_B)
    g.criatura("cazador_camuflado", cazador_base, cazador_det, CA_B)
    g.criatura("tejedor_de_sombras", tejedor_base, tejedor_det, TE_B)
    g.criatura("burbuja_toxica", burbuja_base, burbuja_det, BU_B)
    g.criatura("sirena_de_fango", sirena_base, sirena_det, SI_B)
    g.criatura("guardian_de_flora", guardian_base, guardian_det, GF_B)
    g.criatura("humanoide_sin_consciencia", humanoide_base, humanoide_det, HU_B)


# ---------------------------------------------------------------------------
# FONDOS DE COMBATE: el Sumidero, el laboratorio de Vesper y la Autopista Quemada
# ---------------------------------------------------------------------------
W, H = 480, 270

def plataforma_color(img, cx, cy, rx, ry, rng, borde, cara, motas, matas=None):
    d = ImageDraw.Draw(img)
    d.ellipse((cx - rx, cy - ry + 3, cx + rx, cy + ry + 3), borde)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), cara[0])
    d.ellipse((cx - rx + 6, cy - ry + 3, cx + rx - 6, cy + ry - 2), cara[1])
    for _ in range(int(rx * ry * 0.25)):
        a = rng.random() * math.tau
        r = math.sqrt(rng.random())
        img.putpixel((int(cx + math.cos(a) * r * (rx - 6)), int(cy + math.sin(a) * r * (ry - 3))), rng.choice(motas))
    if matas:
        for _ in range(6):
            x = cx + rng.randint(-rx + 10, rx - 10); y = cy + rng.randint(-ry + 4, ry - 4)
            matas(d, x, y)

def suelo_propio(img, rng, hz, base, oscuro, claro, detalles, plat):
    d = ImageDraw.Draw(img)
    d.rectangle((0, hz, W, H), base)
    gradiente(img, (0, hz, W, hz + 20), [claro, base])
    ruido(img, (0, hz + 10, W, H), [oscuro, claro], 0.1, rng)
    detalles(ImageDraw.Draw(img))
    plataforma_color(img, 340, 124, 66, 12, rng, *plat)
    plataforma_color(img, 138, 182, 82, 13, rng, *plat)

def hongo_fondo(d, x, y, alto, col, ancho=None):
    ancho = ancho or alto // 2 + 4
    d.line((x, y, x, y - alto), c("b8b0a0"), 2)
    d.chord((x - ancho, y - alto - ancho // 2, x + ancho, y - alto + ancho // 2), 180, 360, col)
    d.line((x - ancho + 2, y - alto, x + ancho - 2, y - alto), ilum(col, 0.6))
    d.point((x - ancho // 3, y - alto - ancho // 4), ilum(col, 1.5))

def fondo_sumidero():
    """Túneles del metro inundados de lodo tóxico, iluminados por hongos que brillan."""
    rng = random.Random(81)
    hz = 108
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("0e0a14"), c("1a1426"), c("221c34"), c("2a2a3a"), c("2e3a34")])
    d = ImageDraw.Draw(cielo)
    for x in range(0, W, 60):                                                       # arcos del túnel
        d.arc((x - 40, -40, x + 100, 160), 200, 340, c("2e2840"), 3)
    for _ in range(30):                                                             # goteras de ácido brillando
        x, y = rng.randrange(W), rng.randrange(4, 60)
        d.line((x, y, x, y + rng.randint(2, 6)), c("4a6a3a")); d.point((x, y + 7), LODO[4])
    nubes = nubes_capa(rng, [(120, 220, 90, 40), (90, 200, 80, 50), (150, 240, 120, 30)], n=14)   # neblina tóxica
    lejos = nuevo(W, H)
    d = ImageDraw.Draw(lejos)
    d.rectangle((0, hz - 30, W, hz + 6), c("1e1a2a"))
    for x in range(10, W, 70):                                                       # bocas de túnel
        d.rectangle((x, hz - 26, x + 44, hz + 4), c("0a080e"))
        d.chord((x, hz - 44, x + 44, hz - 8), 180, 360, c("0a080e"))
        d.point((x + 22, hz - 12), c("ffdd6a")) if x % 140 == 10 else None         # ojos en la oscuridad
    for x in range(0, W, 8):
        d.line((x, hz - 30, x + 4, hz - 30), c("3a3448"))
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    d.rectangle((0, hz - 52, W, hz - 46), METAL[1]); d.line((0, hz - 52, W, hz - 52), METAL[2])   # tubería grande
    for x in range(30, W, 90):
        d.rectangle((x, hz - 54, x + 6, hz - 44), METAL[3])
    vagon_x = 300                                                                    # vagón volcado
    d.polygon([(vagon_x, hz + 4), (vagon_x + 10, hz - 30), (vagon_x + 120, hz - 20), (vagon_x + 112, hz + 6)], METRO[1])
    for k in range(4):
        x = vagon_x + 20 + k * 24
        d.rectangle((x, hz - 22 + k * 1, x + 14, hz - 12 + k), c("e0b060"))       # ventanas con luz (gente viviendo)
    d.line((vagon_x + 8, hz - 8, vagon_x + 116, hz), c("c9a42a"))
    for (x, alto, col) in ((40, 40, c("4ae0d0")), (70, 24, c("a46ae8")), (190, 34, c("9cf05a")), (250, 20, c("4ae0d0")),
                           (450, 44, c("a46ae8")), (20, 18, c("9cf05a"))):
        hongo_fondo(d, x, hz + 6, alto, col)
    suelo = nuevo(W, H)
    def det(d):
        for k in range(10):                                                          # vetas de lodo
            y = hz + 16 + k * 14
            x0 = rng.randrange(-40, 240)
            for x in range(x0, x0 + rng.randint(80, 220), 2):
                d.point((x, y + int(math.sin(x / 7.0) * 2)), LODO[2])
        for _ in range(16):
            x, y = rng.randrange(W), rng.randrange(hz + 20, H)
            d.ellipse((x - 2, y - 1, x + 2, y + 1), LODO[2]); d.point((x, y - 1), LODO[4])
        d.polygon([(0, 270), (0, 226), (30, 220), (70, 236), (90, 270)], c("2e3a24"))
        d.polygon([(410, 270), (440, 232), (480, 224), (480, 270)], c("2e3a24"))
        for (x, y, col) in ((16, 226, c("4ae0d0")), (452, 230, c("a46ae8")), (60, 240, c("9cf05a"))):
            hongo_fondo(d, x, y, 10, col, 6)
    def matas(d, x, y):
        d.line((x, y, x, y - 3), c("d8d0c0")); d.point((x, y - 4), rng.choice([CIAN, MORADO, VERDE_L]))
    suelo_propio(suelo, rng, hz, c("2c3e1c"), c("1a2810"), c("3a5222"), det,
                 (c("1e2414"), (c("3a4a34"), c("44583a")), [c("2e3a28"), c("56704a"), c("4a6a2a")], matas))
    return cielo, nubes, lejos, medio, suelo, []

def fondo_laboratorio():
    """Dentro del laboratorio de Vesper: blanco, frío, tanques con especímenes y luz verde."""
    rng = random.Random(91)
    hz = 112
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("8a9a94"), c("a8b6b0"), c("c2ccc6"), c("d6ded8"), c("e2e8e2")])
    d = ImageDraw.Draw(cielo)
    for x in range(20, W, 80):                                                       # lámparas del techo
        d.rectangle((x, 0, x + 40, 6), LAB[2]); d.rectangle((x + 2, 6, x + 38, 9), c("f8fff8"))
    nubes = nuevo(960, 110)                                                          # (sin nubes: interior)
    d = ImageDraw.Draw(nubes)
    for _ in range(10):
        x, y = rng.randrange(960), rng.randrange(20, 100)
        for dx in (-960, 0, 960):
            d.ellipse((x + dx, y, x + dx + 60, y + 6), (160, 240, 160, 26))         # vapor verde
    lejos = nuevo(W, H)
    d = ImageDraw.Draw(lejos)
    d.rectangle((0, 18, W, hz + 4), LAB[1])
    d.rectangle((0, hz - 26, W, hz - 22), c("4ad07a"))
    for k, x in enumerate(range(10, W, 58)):                                         # tanques de especímenes
        d.rounded_rectangle((x, 26, x + 34, hz - 4), 6, c("3a6a4a"))
        d.rectangle((x + 3, 34, x + 31, hz - 8), c("6ae07a") if k % 3 else c("8ad0e0"))
        sil = [(x + 10, 60), (x + 24, 56), (x + 26, 80), (x + 8, 84)]
        d.polygon(sil, c("2a4a3a"))
        d.point((x + 20, 62), c("ff4a4a"))
        for b in range(3):
            d.point((x + 6 + b * 9, 44 + b * 12), c("e8ffe8"))
        d.rectangle((x - 2, 24, x + 36, 28), METAL[2]); d.rectangle((x - 2, hz - 6, x + 36, hz - 2), METAL[2])
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    d.rectangle((150, hz - 30, 330, hz + 6), LAB[2]); d.line((150, hz - 30, 330, hz - 30), LAB[4])   # mesa de trabajo
    for x in range(160, 320, 22):
        d.rectangle((x, hz - 42, x + 8, hz - 30), c("c8f0e8")); d.rectangle((x + 1, hz - 38, x + 7, hz - 30), rng.choice([c("6aff8a"), c("c08aff"), c("ffd24a")]))
    d.rectangle((200, hz - 70, 280, hz - 34), c("1e2a24")); d.rectangle((204, hz - 66, 276, hz - 38), c("1a4a2a"))   # monitor
    for k in range(5):
        d.line((208, hz - 60 + k * 5, 208 + rng.randint(20, 60), hz - 60 + k * 5), c("6aff8a"))
    simbolo_vesper(d, 236, hz - 82, c("2a8a4a"))
    suelo = nuevo(W, H)
    def det(d):
        for y in range(hz + 10, H, 18):
            d.line((0, y, W, y), LAB[2])
        for x in range(0, W, 30):
            d.line((x, hz + 8, x - 40, H), LAB[2])
        d.rectangle((0, 236, W, 240), c("4ad07a"))
        for _ in range(8):                                                            # manchas de experimentos
            x, y = rng.randrange(W), rng.randrange(hz + 30, H)
            d.ellipse((x, y, x + 6, y + 3), c("9ad890"))
    def matas(d, x, y):
        d.point((x, y), LAB[3])
    suelo_propio(suelo, rng, hz, LAB[0], LAB[2], LAB[4], det,
                 (LAB[3], (LAB[1], LAB[0]), [LAB[2], LAB[4], c("c8e8d0")], matas))
    return cielo, nubes, lejos, medio, suelo, []

def fondo_autopista():
    """La Autopista Quemada: puentes caídos, autos calcinados, cielo de ceniza."""
    rng = random.Random(71)
    hz = 108
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("221c22"), c("3a2c30"), c("5a3e3a"), c("7a5446"), c("9a6a52")])
    d = ImageDraw.Draw(cielo)
    d.ellipse((70, 36, 96, 62), c("d0805a")); d.ellipse((74, 40, 92, 58), c("e8a070"))   # sol entre la ceniza
    nubes = nubes_capa(rng, [(90, 80, 80, 140), (60, 54, 56, 160), (120, 100, 96, 110)], n=16)
    lejos = nuevo(W, H)
    skyline(lejos, hz - 2, c("2e262a"), rng, alto=(16, 70), ancho=(14, 36), roto=True)
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    d.polygon([(0, hz - 46), (210, hz - 52), (214, hz - 40), (0, hz - 34)], c("5c5955"))   # autopista elevada partida
    d.polygon([(268, hz - 30), (480, hz - 58), (480, hz - 46), (272, hz - 18)], c("5c5955"))
    d.line((0, hz - 46, 210, hz - 52), CONCRETO[3]); d.line((268, hz - 30, 480, hz - 58), CONCRETO[3])
    for x in (60, 150, 360, 440):
        d.rectangle((x, hz - 36, x + 14, hz + 6), CONCRETO[2])
    for (x, y) in ((206, hz - 50), (212, hz - 44), (270, hz - 26)):
        d.line((x, y, x + rng.randint(-6, 6), y + rng.randint(6, 14)), OXIDO[2])     # fierros
    for k, x in enumerate((20, 120, 230, 330, 410)):                                 # autos quemados
        d.rounded_rectangle((x, hz - 8, x + 40, hz + 6), 3, [c("4a3a34"), c("3a3a40"), c("5a3a2a")][k % 3])
        d.polygon([(x + 8, hz - 8), (x + 12, hz - 16), (x + 28, hz - 16), (x + 32, hz - 8)], c("2a2226"))
    suelo = nuevo(W, H)
    def det(d):
        for y in range(hz + 30, H, 40):                                               # líneas de la carretera
            for x in range(0, W, 40):
                d.rectangle((x, y, x + 18, y + 2), c("c8b46a"))
        for _ in range(20):
            x, y = rng.randrange(W), rng.randrange(hz + 10, H)
            d.line((x, y, x + rng.randint(2, 8), y + rng.randint(-1, 2)), c("2a2a30"))
        d.polygon([(0, 270), (0, 220), (40, 214), (80, 232), (96, 270)], c("4a4442"))
        d.polygon([(400, 270), (430, 230), (480, 222), (480, 270)], c("4a4442"))
    def matas(d, x, y):
        d.line((x, y, x - 1, y - 4), c("8a8480")); d.line((x + 1, y, x + 2, y - 3), c("5a5450"))
    suelo_propio(suelo, rng, hz, ASFALTO[0], ASFALTO[3], ASFALTO[2], det,
                 (c("2a2426"), (c("5a5450"), c("6a6460")), [c("4a4442"), c("7a7470"), c("3a3634")], matas))
    return cielo, nubes, lejos, medio, suelo, [(214, hz - 50), (28, hz - 14), (340, hz - 14)]

g.FONDOS_COMBATE.update({"sumidero": fondo_sumidero, "laboratorio": fondo_laboratorio, "autopista": fondo_autopista})


def generar_tiles_subterraneo():
    rng = random.Random(222)
    g.TILES_SUB = {}
    g.armar_atlas(tiles_subterraneo(rng), "tiles/subterraneo.png", g.TILES_SUB)
    return g.TILES_SUB


def generar():
    generar_decorados()
    generar_personas()
    generar_criaturas()
    generar_iconos()
