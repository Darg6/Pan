"""
Arte de la Ciudad 3: CIUDAD NEÓN (Comandante Silas, El Ilusionista) y el camino para llegar
(el Paso del Smog). Lo llama herramientas/generar_pixel_art.py (no hace falta correrlo solo).

  - atlas nuevo "neon" (calles mojadas, aceras, alfombra de casino, smog, paredes con letreros...)
  - construcciones grandes (hologramas de Silas, generadores a pedal, casino, arcade, motel, torres sónicas...)
  - vecinos de Ciudad Neón, Silas (mapa y combate), los hologramas de los padres de Pan y retratos
  - criaturas nuevas: Caballero de Neón y Espectro Sónico
  - iconos (Visor Polarizado, Granada de Luz, carta de Leo) y fondos de combate "smog", "neon" y "casino"
"""
import math
import random

from PIL import Image, ImageDraw

from generar_pixel_art import *   # noqa: F401,F403  (colores y ayudantes: c, nuevo, contorno, sombrear...)
import generar_pixel_art as g
import arte_bastion as ab
import arte_sumidero as asu
from arte_sumidero import ilum, terminar, plataforma_color, suelo_propio, W, H

CIAN_N = c("3af0ff"); MAGENTA = c("ff4ad8"); VIOLETA_N = c("8a3aff"); AMBAR = c("ffb03a")
NOCHE = [c("16121e"), c("1e1828"), c("2a2236"), c("0e0b14"), c("3a3048")]
CALLE = [c("26222e"), c("201c28"), c("2e2a38"), c("18151f")]
ACERA = [c("4a4654"), c("3e3a48"), c("5a5664"), c("302c38")]
LADRILLO = [c("3a2a3a"), c("2e2030"), c("4a3448"), c("221822")]
SMOG = [c("5a5266"), c("4a4456"), c("6a6276"), c("3a3446"), c("7a7086")]

# Letras extra para los carteles (además de las de arte_sumidero)
LETRAS = dict(asu.LETRAS)
LETRAS.update({
    "H": ["101", "101", "111", "101", "101"], "K": ["101", "110", "100", "110", "101"],
    "J": ["001", "001", "001", "101", "010"], "Q": ["010", "101", "101", "110", "011"],
    "W": ["101", "101", "111", "111", "101"], "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"], "2": ["110", "001", "010", "100", "111"],
    "3": ["110", "001", "010", "001", "110"], "6": ["011", "100", "110", "101", "010"],
    "-": ["000", "000", "111", "000", "000"], ".": ["000", "000", "000", "000", "010"],
    ":": ["000", "010", "000", "010", "000"], "?": ["110", "001", "010", "000", "010"],
})


def escribir(d, x, y, texto, col):
    for ch in texto:
        patron = LETRAS.get(ch, LETRAS[" "])
        for fy, fila in enumerate(patron):
            for fx, v in enumerate(fila):
                if v == "1":
                    d.point((x + fx, y + fy), col)
        x += 4
    return x


def ancho(texto):
    return len(texto) * 4 - 1


def neon(d, x, y, texto, col, fondo=c("120e18")):
    """Letrero de neón: tubo de color con un halo más oscuro alrededor."""
    w = ancho(texto)
    d.rectangle((x - 2, y - 2, x + w + 1, y + 6), fondo)
    halo = ilum(col, 0.45)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        escribir(d, x + dx, y + dy, texto, halo)
    escribir(d, x, y, texto, col)


# ---------------------------------------------------------------------------
# TILES DE CIUDAD NEÓN Y DEL PASO DEL SMOG (atlas propio: arte/tiles/neon.png)
# ---------------------------------------------------------------------------
def t_calle(rng, v):
    """Asfalto mojado con reflejos de neón (siempre es de noche)."""
    t = nuevo(T, T, CALLE[0])
    ruido(t, (0, 0, T, T), [CALLE[1], CALLE[2]], 0.2, rng)
    d = ImageDraw.Draw(t)
    if v == 1:   # charquito que refleja un letrero
        d.ellipse((3, 8, 12, 12), CALLE[3]); d.line((5, 10, 10, 10), rng.choice([ilum(CIAN_N, 0.6), ilum(MAGENTA, 0.6)]))
    elif v == 2:  # línea pintada
        d.rectangle((6, 0, 9, 6), c("8a7a4a")); d.rectangle((6, 10, 9, 15), c("8a7a4a"))
    return t

def t_acera(rng, v):
    t = nuevo(T, T, ACERA[0])
    d = ImageDraw.Draw(t)
    d.line((0, 7, T - 1, 7), ACERA[3]); d.line((7, 0, 7, 7), ACERA[3]); d.line((3 if v else 11, 8, 3 if v else 11, T - 1), ACERA[3])
    ruido(t, (0, 0, T, T), [ACERA[1], ACERA[2]], 0.1, rng)
    if v == 1:
        d.point((rng.randrange(T), rng.randrange(T)), ilum(MAGENTA, 0.5))   # papelito brillante
    return t

def t_alfombra(rng, v):
    """Alfombra del casino abandonado (aquí salen criaturas)."""
    base = c("5a1a3a") if v == 0 else c("4a1a4a")
    t = nuevo(T, T, base)
    d = ImageDraw.Draw(t)
    for k in range(0, T, 8):
        d.polygon([(k + 4, 1), (k + 7, 4), (k + 4, 7), (k + 1, 4)], c("8a3a5a"))
        d.polygon([(k + 4, 9), (k + 7, 12), (k + 4, 15), (k + 1, 12)], c("8a3a5a"))
        d.point((k + 4, 4), c("e6c34a")); d.point((k + 4, 12), c("e6c34a"))
    ruido(t, (0, 0, T, T), [c("2a0a1a"), c("3a1a2a")], 0.12, rng)   # mugre y quemaduras
    return t

def t_smog(rng, v):
    """Suelo del Paso del Smog: tierra gris violeta bajo la neblina (aquí salen criaturas)."""
    t = nuevo(T, T, SMOG[1])
    ruido(t, (0, 0, T, T), [SMOG[0], SMOG[3], SMOG[2]], 0.25, rng)
    d = ImageDraw.Draw(t)
    for _ in range(3 + v):
        x, y = rng.randrange(T), rng.randrange(3, T)
        d.line((x, y, x + rng.choice((-1, 1)), y - rng.randint(2, 4)), c("7a6e5a"))   # yerbas secas
    return t

def t_pared(rng, letrero=None):
    """Fachada de ladrillo oscuro con una ventana o un letrerito de neón."""
    t = nuevo(T, T, LADRILLO[0])
    d = ImageDraw.Draw(t)
    for fila, y in enumerate(range(0, T, 4)):
        off = 0 if fila % 2 == 0 else 4
        for x in range(-off, T, 8):
            d.rectangle((x + 1, y + 1, x + 7, y + 3), rng.choice([LADRILLO[0], LADRILLO[2], LADRILLO[1]]))
    if letrero == "ventana":
        d.rectangle((4, 3, 11, 11), c("120e18")); d.rectangle((5, 4, 10, 10), rng.choice([c("3a2a5a"), c("5a3a2a"), c("1e1e2e")]))
        d.line((4, 7, 11, 7), LADRILLO[3])
    elif letrero:
        col = CIAN_N if letrero == "cian" else MAGENTA
        d.rectangle((2, 5, 13, 10), c("120e18"))
        d.line((3, 7, 12, 7), col); d.line((3, 8, 12, 8), ilum(col, 0.6)); d.point((3, 6), col); d.point((12, 9), col)
    d.line((0, T - 1, T - 1, T - 1), LADRILLO[3])
    return t

def t_techo(rng):
    t = nuevo(T, T, NOCHE[2])
    ruido(t, (0, 0, T, T), [NOCHE[1], NOCHE[4]], 0.2, rng)
    d = ImageDraw.Draw(t)
    d.line((0, 3, T - 1, 3), NOCHE[4]); d.line((0, 11, T - 1, 11), NOCHE[1])
    if rng.random() < 0.5:
        d.rectangle((5, 5, 9, 8), METAL[1]); d.point((6, 5), METAL[2])   # ventilación
    return t

def t_linea_neon(rng, col):
    """Franja de luz en el piso (marca el camino al escenario)."""
    t = t_calle(rng, 0)
    d = ImageDraw.Draw(t)
    d.rectangle((0, 6, T - 1, 9), ilum(col, 0.35)); d.line((0, 7, T - 1, 7), col); d.line((0, 8, T - 1, 8), ilum(col, 0.8))
    return t

def t_tarima(rng):
    """Piso del escenario de Silas: tablas negras brillantes."""
    t = nuevo(T, T, c("1a1420"))
    d = ImageDraw.Draw(t)
    for y in range(0, T, 4):
        d.line((0, y, T - 1, y), c("2a2236"))
    d.point((rng.randrange(T), rng.randrange(T)), c("ffe6ff"))   # brillo
    return t

def t_vacio(rng):
    t = nuevo(T, T, NOCHE[3])
    ruido(t, (0, 0, T, T), [c("0a0810"), c("141018")], 0.2, rng)
    return t

def t_rejilla(rng):
    t = t_calle(rng, 0)
    d = ImageDraw.Draw(t)
    d.rectangle((2, 3, 13, 12), METAL[3])
    for x in range(3, 13, 2):
        d.line((x, 4, x, 11), METAL[1])
    d.point((7, 7), c("5a4a6a"))   # vapor
    return t

def t_charco_luz(rng):
    t = t_calle(rng, 0)
    d = ImageDraw.Draw(t)
    d.ellipse((1, 4, 14, 13), c("161220"))
    d.line((3, 8, 12, 8), ilum(MAGENTA, 0.7)); d.line((5, 10, 10, 10), ilum(CIAN_N, 0.7))
    return t

def t_guardarrail(rng):
    t = t_smog(rng, 0)
    d = ImageDraw.Draw(t)
    d.rectangle((0, 6, T - 1, 9), METAL[2]); d.line((0, 6, T - 1, 6), METAL[4]); d.line((0, 9, T - 1, 9), METAL[3])
    d.rectangle((6, 9, 8, 14), METAL[1])
    d.point((rng.randrange(T), 7), OXIDO[1])
    return t

def t_asfalto_smog(rng, v):
    t = nuevo(T, T, c("3a3644"))
    ruido(t, (0, 0, T, T), [c("2e2a38"), c("46424e")], 0.2, rng)
    d = ImageDraw.Draw(t)
    if v == 1:
        x = rng.randrange(2, 12)
        d.line((x, 0, x + 2, 6, x - 1, 11, x + 1, 15), c("221e2a"))
    if v == 2:
        d.rectangle((7, 1, 8, 6), c("8a7a5a")); d.rectangle((7, 10, 8, 14), c("8a7a5a"))
    return t

def t_objeto_n(rng, dibujar, fondo=None):
    base = fondo if fondo is not None else t_calle(rng, 0)
    capa = nuevo(T, T)
    dibujar(ImageDraw.Draw(capa))
    sombrear(capa); contorno(capa)
    base.alpha_composite(capa)
    return base

def dib_arcade(d):
    """Máquina de arcade vacía (sin pantalla: se llevaron los chips)."""
    d.rectangle((3, 1, 12, 15), c("3a2a6a")); d.rectangle((4, 2, 11, 3), MAGENTA)
    d.rectangle((4, 4, 11, 9), c("0e0e14")); d.line((5, 5, 7, 5), c("2a2a3a"))
    d.rectangle((4, 10, 11, 12), c("2a1a4a")); d.point((6, 11), c("ff4a4a")); d.point((9, 11), CIAN_N)

def dib_mesa_casino(d):
    d.ellipse((1, 3, 14, 13), c("1a4a2a")); d.ellipse((1, 3, 14, 13), outline=MADERA[1])
    d.ellipse((5, 6, 10, 10), c("0e2a16"))
    d.point((4, 7), c("e04a4a")); d.point((11, 9), c("f0f0f0")); d.point((7, 11), c("e6c34a"))   # fichas

def dib_cajas_n(d):
    d.rectangle((1, 5, 10, 14), c("4a3a5a")); d.line((1, 5, 10, 5), c("6a5a7a")); d.line((1, 14, 10, 5), c("3a2a4a"))
    d.rectangle((7, 1, 14, 8), c("5a4a6a")); d.line((7, 1, 14, 1), c("7a6a8a"))
    d.point((4, 9), CIAN_N)

def dib_barril_n(d):
    d.rectangle((3, 2, 12, 14), c("3a3a4a")); d.line((3, 5, 12, 5), c("2a2a36")); d.line((3, 11, 12, 11), c("2a2a36"))
    d.ellipse((3, 1, 12, 4), c("4a4a5a"))
    d.line((5, 7, 10, 7), MAGENTA)   # cinta de neón pegada

def dib_basura(d):
    d.ellipse((1, 7, 14, 15), c("2a2a2e")); d.ellipse((3, 4, 9, 10), c("3a3a40")); d.point((6, 6), c("e6c34a"))
    d.line((10, 8, 13, 5), c("c8c8d0"))

def dib_cono(d):
    d.polygon([(7, 2), (11, 13), (3, 13)], c("ff7a2a")); d.line((5, 8, 9, 8), c("f0f0f0"))
    d.rectangle((2, 13, 12, 14), c("2a2a2a"))

def tiles_neon(rng):
    return [
        ("calle_1", t_calle(rng, 0), False), ("calle_2", t_calle(rng, 1), False), ("calle_linea", t_calle(rng, 2), False),
        ("acera_1", t_acera(rng, 0), False), ("acera_2", t_acera(rng, 1), False),
        ("alfombra_1", t_alfombra(rng, 0), False), ("alfombra_2", t_alfombra(rng, 1), False),
        ("smog_1", t_smog(rng, 0), False), ("smog_2", t_smog(rng, 1), False),
        ("pared", t_pared(rng), True), ("pared_ventana", t_pared(rng, "ventana"), True),
        ("pared_cian", t_pared(rng, "cian"), True), ("pared_magenta", t_pared(rng, "magenta"), True),
        ("techo", t_techo(rng), True), ("linea_cian", t_linea_neon(rng, CIAN_N), False),
        ("linea_magenta", t_linea_neon(rng, MAGENTA), False), ("tarima", t_tarima(rng), False),
        ("vacio", t_vacio(rng), True), ("rejilla", t_rejilla(rng), False), ("charco_luz", t_charco_luz(rng), False),
        ("guardarrail", t_guardarrail(rng), True),
        ("asfalto_1", t_asfalto_smog(rng, 0), False), ("asfalto_2", t_asfalto_smog(rng, 1), False),
        ("asfalto_linea", t_asfalto_smog(rng, 2), False),
        ("arcade", t_objeto_n(rng, dib_arcade, t_alfombra(rng, 0)), True),
        ("mesa_casino", t_objeto_n(rng, dib_mesa_casino, t_alfombra(rng, 1)), True),
        ("cajas", t_objeto_n(rng, dib_cajas_n), True), ("barril", t_objeto_n(rng, dib_barril_n), True),
        ("basura", t_objeto_n(rng, dib_basura), True), ("cono", t_objeto_n(rng, dib_cono, t_asfalto_smog(rng, 0)), True),
        ("auto_smog", t_objeto_n(rng, asu_auto, t_asfalto_smog(rng, 0)), True),
    ]

def asu_auto(d):
    """Auto abandonado cubierto de polvo violeta (un solo tile)."""
    d.rounded_rectangle((0, 5, 15, 13), 2, c("4a4a5a")); d.polygon([(3, 5), (5, 1), (11, 1), (13, 5)], c("3a3a48"))
    d.rectangle((5, 2, 10, 4), c("1e1e28")); d.rectangle((1, 12, 4, 15), c("1a1a1e")); d.rectangle((11, 12, 14, 15), c("1a1a1e"))


# ---------------------------------------------------------------------------
# CONSTRUCCIONES GRANDES (arte/decorados/*.png). La base es el suelo.
# ---------------------------------------------------------------------------
def cara_silas(d, cx, cy, s, col, col2):
    """La cara de Silas en grande (para los hologramas): copete, sonrisa y media máscara."""
    d.ellipse((cx - 9 * s, cy - 11 * s, cx + 9 * s, cy + 11 * s), outline=col)
    d.polygon([(cx - 9 * s, cy - 4 * s), (cx - 6 * s, cy - 14 * s), (cx + 4 * s, cy - 17 * s), (cx + 9 * s, cy - 8 * s)], col2)
    d.line((cx - 5 * s, cy - 2 * s, cx - 2 * s, cy - 2 * s), col)
    d.polygon([(cx + 1 * s, cy - 5 * s), (cx + 8 * s, cy - 5 * s), (cx + 7 * s, cy + 1 * s), (cx + 1 * s, cy + 1 * s)], col)   # máscara
    d.arc((cx - 5 * s, cy + 1 * s, cx + 5 * s, cy + 7 * s), 10, 170, col)   # sonrisa
    d.line((cx, cy - 1 * s, cx - 1 * s, cy + 3 * s), col2)

def holograma_silas():
    """Holograma del rostro de Silas que parpadea: 4 cuadros de 48x72 (uno con falla)."""
    hoja = nuevo(48 * 4, 72)
    for f in range(4):
        img = nuevo(48, 72); d = ImageDraw.Draw(img)
        d.rectangle((21, 56, 26, 71), METAL[1]); d.rectangle((16, 66, 31, 71), METAL[3])   # poste y base
        d.ellipse((17, 52, 30, 58), c("1e2a3a")); d.ellipse((19, 53, 28, 57), ilum(CIAN_N, 0.7))   # proyector
        a = 150 if f != 2 else 70
        col = CIAN_N[:3] + (a,); col2 = MAGENTA[:3] + (a,)
        d.polygon([(19, 55), (28, 55), (40, 6), (8, 6)], (60, 220, 255, 26))                  # cono de luz
        cara_silas(d, 24 + (3 if f == 2 else 0), 26, 1.4, col, col2)
        for y in range(4, 50, 3):                                                               # líneas de barrido
            d.line((8, y, 40, y), (60, 240, 255, 22 if (y // 3 + f) % 4 else 50))
        if f == 2:
            d.rectangle((6, 20, 42, 23), (255, 74, 216, 90)); d.rectangle((10, 34, 38, 35), (60, 240, 255, 90))
        hoja.alpha_composite(img, (f * 48, 0))
    return hoja

def generador(con_gente=True):
    """Generador a pedal: una rueda gigante y bicicletas con gente pedaleando. 3 cuadros de 112x64."""
    hoja = nuevo(112 * 3, 64)
    for f in range(3):
        img = nuevo(112, 64); d = ImageDraw.Draw(img)
        d.rectangle((4, 50, 107, 60), METAL[3]); d.line((4, 50, 107, 50), METAL[2])          # plataforma
        cx, cy = 56, 26
        d.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), METAL[1]); d.ellipse((cx - 20, cy - 20, cx + 20, cy + 20), c("1a1a24"))
        for k in range(6):                                                                     # rayos que giran
            a = k * math.pi / 3 + f * 0.35
            d.line((cx, cy, cx + math.cos(a) * 20, cy + math.sin(a) * 20), METAL[2], 2)
        d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), AMBAR)
        d.rectangle((cx - 3, cy + 22, cx + 3, 50), METAL[1])
        for i, x in enumerate((14, 34, 78, 98)):                                               # bicicletas
            d.ellipse((x - 6, 38, x + 2, 46), outline=METAL[2]); d.line((x - 2, 42, x + 4, 34), METAL[2])
            d.line((x + 4, 34, x - 2, 34), METAL[2])
            if con_gente:
                arriba = (f + i) % 2
                piel = [c("c08a60"), c("a87a58"), c("d0a080"), c("8a6248")][i]
                ropa = [c("4a4a5a"), c("5a3a4a"), c("3a4a5a"), c("4a3a3a")][i]
                d.rectangle((x - 3, 22, x + 2, 32), ropa)                                      # torso inclinado
                d.rectangle((x - 2, 16, x + 2, 21), piel); d.rectangle((x - 3, 15, x + 2, 16), c("2a2220"))
                d.line((x, 32, x + (2 if arriba else -1), 40), c("2a2a36"), 2)                 # piernas que pedalean
                d.line((x - 1, 32, x - (1 if arriba else -2), 41), c("2a2a36"), 2)
                d.point((x + 3, 19), c("9ad0ff"))                                              # sudor
        d.line((8, 30, 104, 30), c("3a3a48"))                                                  # cables a la rueda
        luz = [AMBAR, c("ffd24a"), AMBAR][f]
        for x in (8, 104):
            d.rectangle((x - 2, 4, x + 2, 50), METAL[1]); d.ellipse((x - 4, 0, x + 4, 7), luz)  # focos que brillan
        hoja.alpha_composite(terminar(img), (f * 112, 0))
    return hoja

def edificio_neon(ancho_, alto_, cartel, col, seed, puerta=True, extra=None):
    img = nuevo(ancho_, alto_); d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    d.rectangle((2, 10, ancho_ - 3, alto_ - 1), LADRILLO[0])
    for fila, y in enumerate(range(12, alto_ - 2, 4)):
        off = 0 if fila % 2 == 0 else 4
        for x in range(2 - off, ancho_ - 3, 8):
            d.rectangle((max(2, x + 1), y, min(ancho_ - 3, x + 7), y + 2), rng.choice([LADRILLO[0], LADRILLO[2], LADRILLO[1]]))
    d.rectangle((0, 4, ancho_ - 1, 11), NOCHE[2]); d.line((0, 4, ancho_ - 1, 4), NOCHE[4])     # cornisa
    for x in range(10, ancho_ - 14, 22):                                                         # ventanas
        if rng.random() < 0.7:
            d.rectangle((x, 20, x + 10, 30), c("120e18"))
            if rng.random() < 0.4:
                d.rectangle((x + 1, 21, x + 9, 29), rng.choice([c("4a2a6a"), c("2a3a5a"), c("5a2a3a")]))
    w = ancho(cartel)
    cx = (ancho_ - w) // 2
    neon(d, cx, 36 if alto_ > 64 else 14, cartel, col)
    if puerta:
        px = ancho_ // 2
        d.rectangle((px - 8, alto_ - 20, px + 8, alto_ - 1), c("0e0b14"))
        d.rectangle((px - 7, alto_ - 19, px + 7, alto_ - 1), ilum(col, 0.25))
        d.line((px - 9, alto_ - 21, px + 9, alto_ - 21), col)
    if extra:
        extra(d)
    return terminar(img)

def casino():
    """El Palacio Lumen: el casino donde vive Silas. Grande, con marquesina de focos."""
    def extra(d):
        for x in range(8, 184, 8):
            d.ellipse((x - 2, 46, x + 2, 50), AMBAR if x % 16 else c("fff0c0"))                 # focos de marquesina
        d.polygon([(70, 52), (122, 52), (114, 62), (78, 62)], c("2a1a3a"))
        d.line((70, 52, 122, 52), MAGENTA)
        for x in (24, 168):                                                                      # columnas doradas
            d.rectangle((x - 4, 52, x + 4, 111), c("8a6a2a")); d.line((x - 4, 52, x - 4, 111), c("c8a04a"))
        d.polygon([(96, 0), (108, 8), (84, 8)], MAGENTA)                                        # estrella en el techo
    return edificio_neon(192, 112, "PALACIO LUMEN", MAGENTA, 11, True, extra)

def arcade():
    def extra(d):
        for x in (16, 96):
            d.rectangle((x - 6, 52, x + 6, 70), c("3a2a6a")); d.rectangle((x - 5, 54, x + 5, 60), c("0e0e14"))
            d.line((x - 4, 56, x + 2, 56), CIAN_N)
    return edificio_neon(112, 80, "ARCADE", CIAN_N, 12, True, extra)

def motel():
    def extra(d):
        d.rectangle((10, 52, 30, 62), c("120e18")); escribir(d, 12, 55, "CAMAS", AMBAR)
    return edificio_neon(112, 80, "MOTEL", AMBAR, 13, True, extra)

def tienda_neon():
    def extra(d):
        d.rectangle((16, 44, 80, 50), MADERA[0]); d.line((16, 44, 80, 44), MADERA[2])          # mostrador
        for x in range(20, 78, 8):
            d.rectangle((x, 38, x + 4, 44), rng_col(x))
    return edificio_neon(96, 64, "CORAL", c("7aff9a"), 14, False, extra)

def rng_col(x):
    return [c("4ac8e8"), c("e04a5a"), c("7bd13b"), c("e6c34a")][x % 4]

def bar():
    def extra(d):
        d.rectangle((14, 52, 30, 63), c("120e18"))
        d.polygon([(70, 50), (78, 50), (74, 58)], c("e6c34a")); d.line((74, 58, 74, 63), c("e6c34a"))   # copa
    return edificio_neon(96, 64, "COMODIN", c("ffd24a"), 15, True, extra)

def torre_sonica(encendida=True):
    """Barrera sónica: torre con altavoces que zumban para alejar a los monstruos. 2 cuadros 24x80."""
    hoja = nuevo(48, 80)
    for f in range(2):
        img = nuevo(24, 80); d = ImageDraw.Draw(img)
        d.rectangle((9, 10, 14, 79), METAL[1]); d.line((9, 10, 9, 79), METAL[2])
        for y in (12, 34, 56):
            d.rectangle((3, y, 20, y + 14), c("1e1e28")); d.ellipse((6, y + 2, 17, y + 12), METAL[3])
            d.ellipse((9, y + 5, 14, y + 10), (MAGENTA if (encendida and f == 0) else c("3a2a3a")))
        if encendida:
            for k in range(3):
                r = 4 + k * 3 + f * 2
                d.arc((12 - r, 6 - r // 2, 12 + r, 6 + r // 2), 200, 340, ilum(MAGENTA, 0.8 - k * 0.2))
        d.rectangle((5, 74, 18, 79), METAL[3])
        hoja.alpha_composite(terminar(img), (f * 24, 0))
    return hoja

def letrero_aire():
    """Cartel holográfico de Silas: ¡AIRE LETAL! ¡NO SALGAS!"""
    img = nuevo(64, 48); d = ImageDraw.Draw(img)
    for x in (8, 54):
        d.rectangle((x, 26, x + 2, 47), METAL[1])
    d.rectangle((2, 4, 61, 30), c("1a0e14")); d.rectangle((2, 4, 61, 30), outline=c("ff4a4a"))
    escribir(d, 8, 8, "AIRE LETAL", c("ff4a4a"))
    escribir(d, 10, 16, "NO SALGAS", c("ffd24a"))
    escribir(d, 4, 23, "SILAS TE CUIDA", CIAN_N)
    return terminar(img)

def proyector_gas(roto=False):
    """El aparato que hace el "gas mortal" del camino: una nube holográfica verde."""
    img = nuevo(48, 40); d = ImageDraw.Draw(img)
    d.rectangle((18, 28, 30, 39), METAL[1]); d.rectangle((16, 24, 32, 29), METAL[3])
    d.ellipse((20, 20, 28, 27), c("1e2a1e") if roto else c("4ad07a"))
    if roto:
        d.line((18, 22, 30, 30), c("2a2a2a")); d.point((24, 18), c("ffd24a")); d.point((27, 16), c("ff9a3a"))
    else:
        for (x, y, r) in ((10, 10, 8), (24, 6, 9), (38, 10, 8), (24, 14, 7)):
            d.ellipse((x - r, y - r, x + r, y + r), (90, 220, 120, 70))
    return terminar(img)

def escenario():
    """El escenario del casino donde Silas baila: tarima con focos."""
    img = nuevo(128, 40); d = ImageDraw.Draw(img)
    d.rectangle((0, 10, 127, 39), c("1a1420")); d.line((0, 10, 127, 10), MAGENTA)
    for y in range(14, 38, 4):
        d.line((2, y, 125, y), c("2a2236"))
    for x in range(6, 124, 12):
        d.ellipse((x - 3, 4, x + 3, 10), c("fff0c0") if x % 24 else AMBAR)
    d.polygon([(52, 10), (76, 10), (90, 0), (38, 0)], (255, 220, 255, 40))
    return terminar(img)

def puerta_neon(abierta=False):
    """Portón de Ciudad Neón: arco de tubos de luz (cerrado por la barrera sónica)."""
    img = nuevo(96, 72); d = ImageDraw.Draw(img)
    for x in (4, 82):
        d.rectangle((x, 8, x + 9, 71), LADRILLO[0]); d.line((x, 8, x, 71), LADRILLO[2])
    d.rectangle((0, 0, 95, 12), NOCHE[2])
    neon(d, 22, 3, "CIUDAD NEON", CIAN_N)
    d.arc((10, 6, 85, 60), 180, 360, MAGENTA)
    if not abierta:
        for x in range(16, 82, 6):
            d.line((x, 16, x, 71), (255, 74, 216, 120))                                         # rejas de luz
    return terminar(img)

def reja_tunel(abierta=False):
    """Reja de la Organización que cierra el túnel este del Sumidero."""
    img = nuevo(40, 48); d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 39, 6), c("2e3e34")); escribir(d, 6, 1, "ORG", c("e6c34a"))
    if not abierta:
        for x in range(2, 40, 5):
            d.rectangle((x, 6, x + 1, 47), METAL[1])
        d.rectangle((0, 24, 39, 26), METAL[3]); d.rectangle((16, 22, 22, 28), c("e6c34a"))   # candado
    return terminar(img)

def farola_neon(col):
    img = nuevo(16, 48); d = ImageDraw.Draw(img)
    d.rectangle((7, 8, 8, 47), METAL[1]); d.rectangle((4, 44, 11, 47), METAL[3])
    d.rectangle((3, 2, 12, 8), c("1a1a24")); d.rectangle((4, 3, 11, 7), col)
    return terminar(img)

def microfono():
    """Micrófono escondido de Silas (en postes, macetas y letreros)."""
    img = nuevo(10, 14); d = ImageDraw.Draw(img)
    d.rectangle((4, 6, 5, 13), METAL[1]); d.ellipse((2, 0, 7, 6), METAL[3]); d.point((4, 2), c("ff4a4a"))
    contorno(img)
    return img

def generar_decorados():
    guardar(holograma_silas(), "decorados/holograma_silas.png")
    guardar(generador(), "decorados/generador.png")
    guardar(generador(False), "decorados/generador_vacio.png")
    guardar(casino(), "decorados/casino.png")
    guardar(arcade(), "decorados/arcade.png")
    guardar(motel(), "decorados/motel.png")
    guardar(tienda_neon(), "decorados/tienda_neon.png")
    guardar(bar(), "decorados/bar_comodin.png")
    guardar(torre_sonica(), "decorados/torre_sonica.png")
    guardar(torre_sonica(False), "decorados/torre_sonica_apagada.png")
    guardar(letrero_aire(), "decorados/letrero_aire.png")
    guardar(proyector_gas(), "decorados/proyector_gas.png")
    guardar(proyector_gas(True), "decorados/proyector_roto.png")
    guardar(escenario(), "decorados/escenario.png")
    guardar(puerta_neon(), "decorados/puerta_neon.png")
    guardar(puerta_neon(True), "decorados/puerta_neon_abierta.png")
    guardar(reja_tunel(), "decorados/reja_tunel.png")
    guardar(farola_neon(CIAN_N), "decorados/farola_cian.png")
    guardar(farola_neon(MAGENTA), "decorados/farola_magenta.png")
    guardar(microfono(), "objetos/microfono.png")


# ---------------------------------------------------------------------------
# PERSONAS DE CIUDAD NEÓN (16x24): ojeras, ropa de pedalear, sonrisas forzadas
# ---------------------------------------------------------------------------
pf = g.persona_frente

def pedalero_mapa():
    def extra(d, dy):
        d.rectangle((3, 11, 7, 14), c("7a7a86"))                                    # camiseta sin mangas
        d.point((2, 13 + dy), c("c08a60")); d.point((5, 8 + dy), c("6a4a5a"))      # ojeras
        d.line((3, 15, 7, 15), MAGENTA)                                             # brazalete de turno
    return pf(c("c08a60"), c("2a2220"), "corto", c("5a5a66"), c("44444e"), c("2a2a36"), c("1a1a20"), extra=extra)

def pedalera_mapa():
    def extra(d, dy):
        d.point((5, 8 + dy), c("6a4a5a")); d.line((3, 15, 7, 15), CIAN_N)
    def despues(d, dy):
        d.point((10, 9 + dy), c("ffffff"))                                          # sonrisa forzada (dientes)
    return pf(c("d0a080"), c("6a2a4a"), "largo", c("4a3a5a"), c("3a2a48"), c("2a2a36"), c("1a1a20"), extra=extra, despues=despues)

def tobi_mapa():
    def extra(d):
        d.line((4, 15, 7, 15), MAGENTA); d.point((5, 10), c("6a4a5a"))
    return ab.nino_frente(c("c8a080"), c("1e1a22"), c("3a4a6a"), c("2a3a5a"), c("2a2a36"), c("1a1a20"), extra=extra)

def rina_mapa():
    """Rina, técnica de luces: gafas de soldar en la frente, chaqueta con cables."""
    def extra(d, dy):
        d.rectangle((3, 2, 7, 3), c("2a2a30")); d.point((4, 2), CIAN_N)
        d.line((3, 12, 7, 16), c("e6c34a")); d.point((6, 13), CIAN_N)
    return pf(c("b88a68"), c("e0e0f0"), "largo", c("3a3a5a"), c("2a2a44"), c("2a2a36"), c("1a1a20"), extra=extra)

def coral_mapa():
    def extra(d, dy):
        d.rectangle((3, 12, 7, 16), c("2a5a4a")); d.point((5, 13), c("7aff9a"))
    def despues(d, dy):
        d.point((11, 3 + dy), c("7aff9a")); d.point((4, 3 + dy), c("7aff9a"))     # aretes de luz
    return pf(c("8a6248"), c("2a1a2a"), "corto", c("3a5a4a"), c("2a4438"), c("2a2a36"), c("1a1a20"), extra=extra, despues=despues)

def mara_mapa():
    def extra(d, dy):
        d.point((5, 8 + dy), c("6a4a5a")); d.line((3, 15, 7, 15), MAGENTA)
    return pf(c("c09070"), c("3a2a1a"), "largo", c("6a3a4a"), c("4a2a36"), c("2a2a36"), c("1a1a20"), extra=extra)

def leo_mapa():
    """Leo, el pedalero que escapó: pañuelo en la cara (cree que el aire lo va a matar)."""
    def extra(d, dy):
        d.rectangle((4, 7 + dy, 7, 10 + dy), c("8a8a7a")); d.point((5, 7 + dy), c("6a6a5a"))
        d.line((3, 15, 7, 15), MAGENTA)
    return pf(c("c08a60"), c("4a3a2a"), "corto", c("5a5a66"), c("44444e"), c("2a2a36"), c("1a1a20"), extra=extra, encorvado=True)

def ciro_mapa():
    def extra(d, dy):
        d.rectangle((4, 8 + dy, 7, 10 + dy), c("c8c4bc"))                          # bigote blanco
    def despues(d, dy):
        d.line((12, 13, 13, 23), METAL[2])                                          # bastón de metal
    return pf(c("a89070"), c("d0ccc4"), "corto", c("4a4a5a"), c("3a3a48"), c("2a2a36"), c("1a1a20"), extra=extra, despues=despues, encorvado=True)

def silas_mapa():
    """Silas: traje morado brillante, copete, media máscara de neón. Se mueve como bailarín."""
    piel = c("e2b496")
    img = nuevo(16, 24); d = ImageDraw.Draw(img)
    d.rectangle((4, 18, 6, 21), c("2a1036")); d.rectangle((4, 22, 6, 23), c("0e0e14"))
    d.polygon([(2, 11), (7, 11), (7, 18), (3, 18)], c("4a2060"))                   # saco
    d.line((4, 11, 7, 17), MAGENTA)                                                 # solapa de neón
    d.rectangle((4, 3, 7, 10), piel)
    d.polygon([(3, 5), (4, 0), (7, 0), (7, 3)], c("6a2a9a"))                        # copete
    d.point((5, 7), c("c070ff"))
    espejar(img)
    d = ImageDraw.Draw(img)
    d.rectangle((9, 5, 11, 8), c("1a1a2a")); d.point((10, 6), CIAN_N)               # media máscara
    d.line((12, 11, 14, 8), c("4a2060")); d.point((14, 7), piel)                    # brazo arriba (pose de baile)
    d.polygon([(8, 0), (11, -1), (9, 2)], c("6a2a9a"))
    luz_lateral(img); contorno_suave(img)
    return img

def holograma_mapa(fuente, col):
    """Versión holográfica (traslúcida, con rayas) de una persona: las ilusiones de Silas."""
    img = fuente.copy(); px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, gg, b, a = px[x, y]
            if a == 0:
                continue
            lum = (r + gg + b) / 3 / 255
            k = 0.5 + lum * 0.7
            px[x, y] = (int(col[0] * k), int(col[1] * k), int(col[2] * k), 150 if y % 3 else 90)
    return img

def silas_combate():
    piel = c("e2b496")
    def extra(d):
        d.polygon([(6, 17), (15, 16), (15, 32), (7, 32)], c("4a2060"))             # saco morado
        d.line((10, 17, 15, 28), MAGENTA)                                          # solapa
        d.rectangle((9, 30, 15, 31), c("e6c34a"))                                  # cinturón dorado
        d.polygon([(9, 3), (12, -1), (16, 0), (15, 5)], c("6a2a9a"))               # copete
    def despues(d):
        d.rectangle((16, 8, 21, 12), c("1a1a2a")); d.line((16, 8, 21, 8), CIAN_N); d.point((19, 10), CIAN_N)   # máscara
        d.line((22, 18, 28, 10), c("4a2060"), 2); d.point((28, 9), piel); d.point((29, 8), piel)   # mano arriba
        d.line((17, 14, 19, 14), c("a03a6a"))                                       # sonrisa
        for (x, y) in ((27, 4), (4, 12), (26, 30)):
            d.point((x, y), c("ffe6ff"))                                            # destellos
    return figura(piel, c("6a2a9a"), "corto", c("4a2060"), c("2a1036"), c("2a1036"), c("0e0e14"), ojos=c("c070ff"), extra=extra, despues=despues)

def retrato_simple(piel, pelo, ropa, ropa2, fondo, iris=c("3a2a1a"), forma_ceja="recta", forma_boca="seria", detalles=None, pelo_largo=False, ojeras=False):
    def m(d):
        hombros(d, ropa, ropa2)
        cara_base(d, piel)
        ojo(d, iris, x=16, y=23)
        if ojeras:
            d.line((16, 26, 21, 26), oscurecer(piel, 0.74))
        ceja(d, oscurecer(pelo, 0.8), forma_ceja, y=20)
        nariz(d, piel)
        boca(d, piel, forma_boca)
        if pelo_largo:
            d.polygon([(10, 36), (10, 14), (14, 8), (23, 6), (23, 11), (16, 12), (13, 17), (13, 36)], pelo)
        else:
            d.polygon([(11, 22), (11, 13), (15, 8), (23, 7), (23, 12), (17, 13), (14, 16), (13, 21)], pelo)
    return retrato48(fondo, piel, m, detalles)

def retrato_rina():
    def det(d):
        d.rectangle((14, 9, 33, 12), c("2a2a30")); d.rectangle((16, 10, 20, 11), CIAN_N); d.rectangle((27, 10, 31, 11), CIAN_N)
    return retrato_simple(c("b88a68"), c("e0e0f0"), c("3a3a5a"), c("2a2a44"), c("1a1a3a"), c("3a8aaa"), "recta", "seria", det, True)

def retrato_coral():
    def det(d):
        d.point((11, 27), c("7aff9a")); d.point((36, 27), c("7aff9a"))
    return retrato_simple(c("8a6248"), c("2a1a2a"), c("3a5a4a"), c("2a4438"), c("0e2a24"), c("2a1a10"), "fina", "sonrisa", det)

def retrato_tobi():
    return retrato_simple(c("c8a080"), c("1e1a22"), c("3a4a6a"), c("2a3a5a"), c("1a1a2a"), c("2a1a10"), "triste", "triste", None, False, True)

def retrato_mara():
    return retrato_simple(c("c09070"), c("3a2a1a"), c("6a3a4a"), c("4a2a36"), c("2a1a2a"), c("3a2a10"), "triste", "seria", None, True, True)

def retrato_leo():
    def det(d):
        d.rectangle((16, 30, 31, 38), c("8a8a7a")); d.line((16, 30, 31, 30), c("6a6a5a"))
    return retrato_simple(c("c08a60"), c("4a3a2a"), c("5a5a66"), c("44444e"), c("2a2830"), c("3a2a10"), "triste", "seria", det, False, True)

def retrato_pedalero():
    def det(d):
        d.point((32, 24), c("9ad0ff")); d.point((33, 26), c("9ad0ff"))
    return retrato_simple(c("c08a60"), c("2a2220"), c("5a5a66"), c("44444e"), c("1e1a2a"), c("2a1a10"), "triste", "dientes", det, False, True)

def generar_personas():
    for nombre, f in (("pedalero_mapa", pedalero_mapa), ("pedalera_mapa", pedalera_mapa), ("tobi_mapa", tobi_mapa),
                      ("rina_mapa", rina_mapa), ("coral_mapa", coral_mapa), ("mara_mapa", mara_mapa), ("leo_mapa", leo_mapa),
                      ("ciro_mapa", ciro_mapa), ("silas_mapa", silas_mapa), ("silas_combate", silas_combate)):
        guardar(f(), f"personajes/{nombre}.png")
    # Las ilusiones de Silas: los padres de Pan como hologramas (cian y magenta)
    papa = pf(c("c08c62"), c("0c0c10"), "corto", c("1e1e24"), c("101014"), c("1e1e24"), c("101014"))
    mama = pf(c("f6dccb"), c("2a1614"), "largo", c("c8323a"), c("8e2028"), c("1e1e24"), c("101014"))
    guardar(holograma_mapa(papa, CIAN_N), "personajes/holo_papa_mapa.png")
    guardar(holograma_mapa(mama, MAGENTA), "personajes/holo_mama_mapa.png")
    for nombre, f in (("rina", retrato_rina), ("coral", retrato_coral), ("tobi", retrato_tobi), ("mara", retrato_mara),
                      ("leo", retrato_leo), ("pedalero", retrato_pedalero)):
        guardar(f(), f"retratos/{nombre}.png")


# ---------------------------------------------------------------------------
# CRIATURAS NUEVAS (64x64, miran a la DERECHA, patas en la fila 60-61)
# ---------------------------------------------------------------------------
CN = c("2a2a4a"); CN2 = c("1a1a34"); CN3 = c("3a3a66"); CN_B = c("9ff0ff")
def caballero_base(d, img):
    P(d, [(24, 42), (30, 42), (30, 54), (28, 61), (22, 61), (24, 52)], CN2)                # pierna de atrás
    P(d, [(34, 42), (40, 42), (42, 54), (44, 61), (36, 61), (36, 52)], CN)                 # pierna de adelante
    P(d, [(22, 18), (42, 18), (44, 32), (42, 44), (22, 44), (20, 32)], CN)                 # armadura del torso
    P(d, [(20, 20), (12, 28), (8, 40), (12, 42), (18, 30)], CN2)                           # brazo con escudo
    P(d, [(4, 26), (14, 24), (16, 44), (6, 46)], CN3)                                      # escudo
    P(d, [(42, 20), (50, 26), (52, 32), (48, 34), (42, 28)], CN)                           # brazo con lanza
    P(d, [(24, 2), (38, 2), (40, 10), (38, 18), (26, 18), (24, 10)], CN3)                  # yelmo

def caballero_det(d, img):
    d.line((48, 32, 63, 6), c("e0ffff")); d.line((49, 32, 63, 8), CN_B)                   # lanza de luz
    d.polygon([(60, 4), (63, 0), (63, 8)], CN_B)
    d.line((26, 10, 38, 10), CIAN_N); d.line((26, 11, 38, 11), ilum(CIAN_N, 0.6))         # visera que brilla
    for y in (22, 30, 38):
        d.line((24, y, 40, y), CIAN_N)                                                     # líneas de neón de la armadura
    d.line((32, 18, 32, 44), MAGENTA)
    d.line((6, 30, 14, 30), CIAN_N); d.line((10, 26, 10, 42), CIAN_N)                    # cruz en el escudo
    d.point((10, 30), c("ffffff"))
    for x in (22, 28, 36, 44):
        d.point((x, 61), CN_B)

ES = c("6a5a8a"); ES2 = c("4a3a6a"); ES3 = c("8a7aaa"); ES_B = c("f0d0ff")
def espectro_base(d, img):
    P(d, [(16, 12), (30, 4), (44, 8), (52, 20), (50, 36), (44, 48), (36, 58), (32, 50), (26, 60), (22, 48), (16, 54), (14, 40), (10, 26)], ES)   # cuerpo de humo
    P(d, [(10, 26), (2, 30), (6, 36), (14, 34)], ES2)                                     # brazo fantasmal
    P(d, [(50, 22), (60, 18), (62, 24), (52, 30)], ES2)

def espectro_det(d, img):
    d.ellipse((24, 14, 30, 20), c("1a1028")); d.ellipse((36, 14, 42, 20), c("1a1028"))   # cuencas
    d.point((27, 17), ES_B); d.point((39, 17), ES_B)
    d.ellipse((28, 26, 38, 36), c("1a1028"))                                              # boca que grita
    for k in range(3):                                                                    # ondas de sonido
        r = 6 + k * 5
        d.arc((44 - r, 31 - r, 44 + r, 31 + r), 300, 60, ilum(ES_B, 1.0 - k * 0.25))
    for (x, y) in ((20, 40), (40, 44), (16, 22)):
        d.point((x, y), ES3)
    d.line((18, 12, 28, 6), ES3)

BL = c("7a6a5a"); BL2 = c("5a4c40"); BL3 = c("9a8a74"); BL_B = c("c8b8a0")
def blindada_base(d, img):
    P(d, [(12, 48), (18, 48), (18, 60), (12, 60)], BL2)                                    # patas
    P(d, [(40, 48), (46, 48), (46, 60), (40, 60)], BL2)
    P(d, [(4, 50), (8, 32), (18, 20), (34, 16), (48, 22), (56, 34), (58, 50)], BL)         # caparazón
    P(d, [(52, 40), (60, 36), (63, 44), (60, 52), (52, 50)], BL3)                          # cabeza
    P(d, [(20, 50), (26, 50), (26, 60), (20, 60)], BL)
    P(d, [(34, 50), (40, 50), (40, 60), (34, 60)], BL)
    P(d, [(0, 46), (6, 44), (6, 50), (0, 52)], BL2)                                        # cola

def blindada_det(d, img):
    for k, x in enumerate(range(12, 52, 8)):                                              # placas del caparazón
        d.arc((x - 8, 16, x + 8, 56), 200, 340, BL2)
        d.line((x, 20 + abs(k - 2) * 2, x, 48), BL2)
    for (x, y) in ((16, 30), (30, 24), (44, 30), (24, 40), (38, 38)):
        d.point((x, y), BL_B)                                                             # remaches de hueso
    d.point((59, 42), c("1a1414")); d.point((60, 41), c("ffd24a"))                        # ojo
    d.line((62, 46, 63, 48), c("3a2a20"))
    d.line((8, 34, 18, 22), METAL[2])                                                     # chatarra incrustada
    d.rectangle((26, 18, 30, 21), METAL[1])
    for x in (12, 22, 36, 44):
        d.point((x, 60), BL_B)

VC = c("8a8478"); VC2 = c("6a6458"); VC3 = c("aaa496"); VC_B = c("e8e2d4")
def vigilante_base(d, img):
    P(d, [(24, 42), (30, 42), (30, 54), (28, 61), (22, 61), (24, 52)], VC2)
    P(d, [(34, 42), (40, 42), (42, 54), (44, 61), (36, 61), (36, 52)], VC)
    P(d, [(22, 16), (42, 16), (44, 30), (42, 44), (22, 44), (20, 30)], c("3a3a44"))         # túnica oscura
    P(d, [(20, 18), (14, 30), (16, 42), (20, 40), (20, 28)], c("2a2a34"))
    P(d, [(42, 18), (50, 22), (54, 30), (50, 32), (44, 26)], c("2a2a34"))                  # brazo con bastón
    P(d, [(26, 2), (38, 2), (40, 10), (38, 16), (26, 16), (24, 10)], VC3)                  # cabeza

def vigilante_det(d, img):
    d.rectangle((24, 7, 40, 10), c("d8d0c0")); d.line((24, 10, 40, 10), c("a89a7a"))     # venda en los ojos
    d.line((40, 8, 46, 14), c("d8d0c0")); d.line((40, 9, 45, 16), c("d8d0c0"))           # puntas de la venda
    d.line((52, 30, 60, 4), MADERA[1]); d.line((53, 30, 61, 4), MADERA[2])                # bastón largo
    d.ellipse((57, 0, 63, 6), c("e6c34a"))                                                # campanita
    d.polygon([(30, 20), (34, 20), (32, 30)], c("e6c34a"))                                # balanza en el pecho
    d.line((26, 22, 38, 22), c("e6c34a"))
    d.line((30, 13, 34, 13), VC2)                                                          # boca
    for x in (22, 28, 36, 44):
        d.point((x, 61), VC_B)

def generar_criaturas():
    g.criatura("caballero_de_neon", caballero_base, caballero_det, CN_B)
    g.criatura("espectro_sonico", espectro_base, espectro_det, ES_B)
    g.criatura("bestia_blindada", blindada_base, blindada_det, BL_B)
    g.criatura("vigilante_ciego", vigilante_base, vigilante_det, VC_B)


# ---------------------------------------------------------------------------
# ICONOS
# ---------------------------------------------------------------------------
def icono_visor():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((1, 6, 14, 10), c("2a2a34")); d.rectangle((2, 7, 6, 9), c("6a3aaa")); d.rectangle((9, 7, 13, 9), c("6a3aaa"))
    d.point((3, 7), CIAN_N); d.point((10, 7), CIAN_N); d.line((0, 7, 1, 6), METAL[2]); d.line((14, 6, 15, 7), METAL[2])
    contorno(img)
    return img

def icono_granada_luz():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.ellipse((3, 4, 12, 13), c("e0e8f0")); d.rectangle((6, 1, 9, 4), METAL[2]); d.point((5, 6), c("ffffff"))
    d.line((7, 7, 9, 10), CIAN_N)
    contorno(img)
    return img

def icono_carta_leo():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((2, 4, 13, 12), c("e8e0c8")); d.line((2, 4, 7, 9), c("a8a088")); d.line((13, 4, 7, 9), c("a8a088"))
    d.point((7, 11), c("e04a4a"))
    contorno(img)
    return img

def generar_iconos():
    guardar(icono_visor(), "objetos/visor_polarizado.png")
    guardar(icono_granada_luz(), "objetos/granada_luz.png")
    guardar(icono_carta_leo(), "objetos/carta_leo.png")


# ---------------------------------------------------------------------------
# FONDOS DE COMBATE: el Paso del Smog, las calles de Neón y el escenario del casino
# ---------------------------------------------------------------------------
def fondo_smog():
    """Carretera bajo un smog violeta denso; a lo lejos, el resplandor de Ciudad Neón."""
    rng = random.Random(301)
    hz = 108
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("1a1424"), c("2a2236"), c("3a3048"), c("4a3e58"), c("5a4e66")])
    capa = nuevo(W, H); d = ImageDraw.Draw(capa)
    d.ellipse((360, 60, 480, 130), (255, 74, 216, 40)); d.ellipse((380, 70, 470, 120), (60, 240, 255, 40))   # resplandor de Neón
    cielo.alpha_composite(capa)
    nubes = g.nubes_capa(rng, [(110, 100, 130, 110), (90, 80, 110, 130), (130, 110, 150, 90)], n=18)
    lejos = nuevo(W, H)
    g.skyline(lejos, hz - 2, c("241e30"), rng, alto=(20, 80), ancho=(12, 30), roto=False)
    d = ImageDraw.Draw(lejos)
    for _ in range(40):
        x, y = rng.randrange(330, W), rng.randrange(hz - 70, hz - 4)
        d.point((x, y), rng.choice([CIAN_N, MAGENTA, AMBAR]))                         # ventanas de neón lejanas
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    for x in (60, 250):                                                                # carteles de "aire letal"
        d.rectangle((x, hz - 40, x + 3, hz + 4), METAL[1])
        d.rectangle((x - 20, hz - 54, x + 24, hz - 36), c("1a0e14")); d.rectangle((x - 20, hz - 54, x + 24, hz - 36), outline=c("ff4a4a"))
        escribir(d, x - 16, hz - 48, "PELIGRO", c("ff4a4a"))
    for (x, y, r) in ((160, hz - 10, 30), (360, hz - 6, 26)):
        d.ellipse((x - r, y - r // 2, x + r, y + r // 2), (90, 220, 120, 40))         # "gas" holográfico
    suelo = nuevo(W, H)
    def det(d):
        for y in range(hz + 30, H, 40):
            for x in range(0, W, 40):
                d.rectangle((x, y, x + 18, y + 2), c("8a7a5a"))
        for _ in range(14):
            x, y = rng.randrange(W), rng.randrange(hz + 10, H)
            d.line((x, y, x + rng.randint(2, 8), y + rng.randint(-1, 2)), c("2a2632"))
    def matas(d, x, y):
        d.line((x, y, x - 1, y - 4), c("7a6e5a")); d.line((x + 1, y, x + 2, y - 3), c("5a5244"))
    suelo_propio(suelo, rng, hz, c("3a3644"), c("2a2632"), c("4a4656"), det,
                 (c("221e2a"), (c("4a4656"), c("565262")), [c("3a3644"), c("6a6276"), c("2e2a38")], matas))
    return cielo, nubes, lejos, medio, suelo, []

def fondo_neon():
    """Calle angosta de Ciudad Neón: siempre de noche, letreros y hologramas de Silas."""
    rng = random.Random(311)
    hz = 108
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("0a0812"), c("120e1e"), c("1a1428"), c("221a32"), c("2a2038")])
    nubes = g.nubes_capa(rng, [(60, 40, 80, 80), (80, 50, 100, 60)], n=10)
    lejos = nuevo(W, H)
    d = ImageDraw.Draw(lejos)
    x = 0
    while x < W:
        w = rng.randint(30, 60); alto = rng.randint(50, 100)
        d.rectangle((x, hz - alto, x + w, hz + 4), c("1a1424"))
        for yy in range(hz - alto + 6, hz - 4, 8):
            for xx in range(x + 4, x + w - 4, 7):
                if rng.random() < 0.35:
                    d.rectangle((xx, yy, xx + 3, yy + 3), rng.choice([c("3a2a5a"), c("5a2a4a"), c("2a3a5a")]))
        if rng.random() < 0.6:
            col = rng.choice([CIAN_N, MAGENTA, AMBAR])
            d.rectangle((x + 4, hz - alto + 10, x + 8, hz - alto + 40), ilum(col, 0.7))   # letrero vertical
        x += w + rng.randint(0, 6)
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    cara_silas(d, 240, 44, 2, (60, 240, 255, 110), (255, 74, 216, 110))                  # holograma gigante
    d.polygon([(232, 96), (248, 96), (300, 4), (180, 4)], (60, 240, 255, 18))
    for x in (40, 420):
        d.rectangle((x - 2, hz - 60, x + 2, hz + 4), METAL[1]); d.ellipse((x - 6, hz - 66, x + 6, hz - 56), ilum(MAGENTA, 0.8))
    suelo = nuevo(W, H)
    def det(d):
        for _ in range(20):
            x, y = rng.randrange(W), rng.randrange(hz + 10, H)
            d.line((x, y, x + rng.randint(6, 20), y), rng.choice([ilum(CIAN_N, 0.4), ilum(MAGENTA, 0.4)]))   # reflejos en el asfalto
    def matas(d, x, y):
        d.point((x, y), rng.choice([CIAN_N, MAGENTA]))
    suelo_propio(suelo, rng, hz, CALLE[0], CALLE[3], CALLE[2], det,
                 (c("120e18"), (c("2e2a38"), c("3a3646")), [c("26222e"), c("4a4654"), ilum(MAGENTA, 0.5)], matas))
    return cielo, nubes, lejos, medio, suelo, []

def fondo_casino():
    """El escenario de Silas en el Palacio Lumen: cortinas, focos y luces que mareaban."""
    rng = random.Random(321)
    hz = 112
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("140a1a"), c("200e28"), c("2a1234"), c("34163e"), c("3e1a48")])
    d = ImageDraw.Draw(cielo)
    for x in range(0, W, 12):                                                          # cortina
        d.rectangle((x, 0, x + 6, hz - 20), c("5a1028")); d.line((x, 0, x, hz - 20), c("7a1a3a"))
    nubes = nuevo(960, 110)
    d = ImageDraw.Draw(nubes)
    for _ in range(14):                                                                # haces de luz que barren
        x = rng.randrange(960)
        for dx in (-960, 0, 960):
            d.polygon([(x + dx, 0), (x + dx + 10, 0), (x + dx + 40, 110), (x + dx + 20, 110)], (255, 220, 255, 22))
    lejos = nuevo(W, H)
    d = ImageDraw.Draw(lejos)
    for x in range(10, W, 30):
        d.ellipse((x - 4, 4, x + 4, 12), rng.choice([AMBAR, c("fff0c0"), MAGENTA]))  # focos
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    d.rectangle((140, hz - 50, 340, hz - 44), c("e6c34a"))
    neon(d, 190, hz - 70, "SILAS SHOW", MAGENTA)
    for x in (120, 360):
        d.rectangle((x - 8, hz - 70, x + 8, hz + 4), c("1a1a24"))
        d.ellipse((x - 6, hz - 66, x + 6, hz - 54), METAL[3]); d.ellipse((x - 3, hz - 63, x + 3, hz - 57), MAGENTA)   # altavoces
    suelo = nuevo(W, H)
    def det(d):
        for y in range(hz + 10, H, 14):
            d.line((0, y, W, y), c("2a2236"))
        for _ in range(10):
            x, y = rng.randrange(W), rng.randrange(hz + 20, H)
            d.point((x, y), c("ffe6ff"))
    def matas(d, x, y):
        d.point((x, y), c("ffe6ff"))
    suelo_propio(suelo, rng, hz, c("1a1420"), c("120e18"), c("2a2236"), det,
                 (c("0e0b12"), (c("2a2236"), c("3a3048")), [c("1a1420"), MAGENTA, c("4a3a5a")], matas))
    return cielo, nubes, lejos, medio, suelo, []

g.FONDOS_COMBATE.update({"smog": fondo_smog, "neon": fondo_neon, "casino": fondo_casino})


def generar_tiles_neon():
    rng = random.Random(333)
    g.TILES_NEON = {}
    g.armar_atlas(tiles_neon(rng), "tiles/neon.png", g.TILES_NEON)
    return g.TILES_NEON


def generar():
    generar_decorados()
    generar_personas()
    generar_criaturas()
    generar_iconos()
