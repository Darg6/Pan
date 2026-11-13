"""
Dibuja los mapas como texto (una letra = un tile de 16x16) en herramientas/mapas/*.txt.
Después herramientas/construir_proyecto.gd los convierte en escenas de Godot con TileMapLayer.

Solo hace falta para regenerar los mapas desde cero. Si prefieres, edita los mapas
directamente en Godot con el editor de TileMap (escenas/mapas/*.tscn).

Leyenda exterior:
  .  tierra        :  tierra oscura   =  asfalto       -  asfalto con línea   c  concreto
  "  pasto seco (aquí aparecen criaturas)              s  arena naranja        T  charco tóxico
  V  abismo        N  borde norte del acantilado      #  muro (arriba)        W  muro (cara)
  o  barril        O  barril tóxico   k  chatarra      n  neumáticos          Y  árbol muerto
  P  cartel        F  fogata          z  cama de cartón v  viga oxidada       |  valla
  [ ]  auto oxidado (2 tiles)         R r  contenedor rojo (techo / cara)
  U u  contenedor azul                { }  portón de Bastión                  H  escotilla del búnker

Leyenda extra de Bastión de Óxido (ciudad 1):
  a  arena oxidada   p q  placas de metal (calles)   d  dunas de óxido (criaturas)   j  chatarral (criaturas)
  D E  puerta de contenedor rojo / azul    w e  ventana de contenedor rojo / azul    L  farol
  b  cinta transportadora    l  charco de aceite    g  fondo seco del puerto    x  reja con púas
"""
import os
import random

AQUI = os.path.dirname(os.path.abspath(__file__))
rng = random.Random(2024)

W, H = 72, 42
m = [["." for _ in range(W)] for _ in range(H)]

def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H:
                m[y][x] = ch

def manchas(x0, y0, x1, y1, ch, prob):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rng.random() < prob and m[y][x] == ".":
                m[y][x] = ch

def blob(cx, cy, rx, ry, ch):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if 0 <= x < W and 0 <= y < H:
                dx = (x - cx) / rx
                dy = (y - cy) / ry
                if dx * dx + dy * dy <= 1.0 + rng.uniform(-0.25, 0.1):
                    m[y][x] = ch

def poner(x, y, ch):
    m[y][x] = ch

# Tierra oscura salpicada
manchas(0, 0, W - 1, H - 1, ":", 0.08)

# Norte: el acantilado (abismo + borde)
rect(0, 0, 51, 1, "V")
rect(0, 2, 51, 2, "N")
# Oeste y sur: ruinas
rect(0, 0, 1, H - 1, "#")
rect(0, H - 3, W - 1, H - 3, "#")
rect(0, H - 2, W - 1, H - 1, "W")

# Bastión de Óxido (noreste): muralla de contenedores con el portón
for x in range(52, W):
    bloque = (x - 52) // 3
    top, cara = ("R", "r") if bloque % 2 == 0 else ("U", "u")
    poner(x, 0, top)
    for y in range(1, 6):
        poner(x, y, cara)
rect(61, 4, 61, 5, "{")
rect(62, 4, 62, 5, "}")
# Arena naranja del desierto alrededor de Bastión
for y in range(6, H - 3):
    for x in range(50, W):
        if x > 55 or rng.random() < (x - 49) / 7:
            if m[y][x] in ".:":
                m[y][x] = "s"
rect(W - 1, 0, W - 1, H - 1, "r")

# Plaza del búnker (oeste)
rect(2, 25, 12, 36, "c")
rect(12, 29, 12, 33, "c")
rect(2, 23, 12, 23, "#")
rect(2, 24, 12, 24, "W")
rect(5, 23, 7, 24, ".")          # hueco en el muro
poner(6, 30, "H")                 # escotilla del Refugio Cero
poner(3, 26, "o")
poner(11, 27, "k")
poner(3, 35, "n")
poner(10, 35, "O")
rect(2, 37, 9, 37, "|")

# Camino principal (oeste -> este) y subida al portón
rect(13, 30, 62, 32, "=")
for x in range(13, 60, 2):
    poner(x, 31, "-")
rect(60, 6, 62, 29, "=")
for y in range(6, 30):
    if rng.random() < 0.15:
        poner(rng.choice((60, 61, 62)), y, "=")

# El gato atrapado bajo la viga (prólogo)
poner(17, 28, "v")
poner(16, 28, "k")
poner(18, 27, "k")
poner(16, 27, "n")

# Cuello de botella: ruinas que bloquean el paso hasta terminar el prólogo
rect(22, 3, 23, 28, "#")
rect(22, 29, 23, 29, "W")
rect(22, 33, 23, 38, "#")
for y in range(4, 28, 3):
    poner(22, y, "W")

# Pastizales (zonas de encuentro)
blob(31, 9, 6, 4, '"')
blob(44, 22, 6, 4, '"')
blob(34, 36, 7, 2, '"')
blob(55, 16, 4, 4, '"')

# Decoración del páramo
for (x, y) in ((34, 30), (46, 32), (53, 30)):
    poner(x, y, "[")
    poner(x + 1, y, "]")
for (x, y) in ((27, 16), (39, 14), (48, 8), (26, 25), (40, 37), (14, 12), (8, 8), (17, 18)):
    poner(x, y, "Y")
for (x, y) in ((29, 20), (30, 20), (41, 28), (18, 6), (19, 6), (36, 18)):
    poner(x, y, rng.choice("oknO"))
blob(38, 26, 2, 1, "T")
blob(13, 20, 2, 1, "T")
for (x, y) in ((25, 4), (26, 4), (27, 4), (44, 4), (45, 4)):
    poner(x, y, "k")
# Ruinas sueltas al oeste del cuello de botella
rect(4, 6, 8, 6, "#")
rect(4, 7, 8, 7, "W")
rect(14, 14, 17, 14, "#")
rect(14, 15, 17, 15, "W")

# Campamento de los oprimidos frente a Bastión
poner(57, 11, "F")
poner(55, 11, "z")
poner(58, 13, "z")
poner(64, 8, "P")
poner(66, 12, "o")
poner(67, 12, "k")
poner(68, 18, "n")

def guardar(nombre, mapa):
    ruta = os.path.join(AQUI, "mapas", nombre)
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with open(ruta, "w", encoding="utf-8") as f:
        f.write("\n".join("".join(fila) for fila in mapa) + "\n")

guardar("superficie.txt", m)

# Refugio Cero (interior)
#  # techo   W pared   . , piso   b B cama   m M mesa   L casillero   G generador
#  E estante   H escalera   x caja   a alfombra
refugio = [
    "################",
    "#WWWWWWWWWWWWWW#",
    "#LLE.H....E.GG.#",
    "#..............#",
    "#b......aa....x#",
    "#B......aa.,...#",
    "#..,...........#",
    "#.....mM.....,.#",
    "#..............#",
    "################",
]
guardar("refugio_cero.txt", [list(f) for f in refugio])


# ---------------------------------------------------------------------------
# BASTIÓN DE ÓXIDO (Ciudad 1). Las construcciones grandes (trituradora, buque, grúa,
# tienda, posada...) no son tiles: las pone construir_proyecto.gd encima del mapa.
# ---------------------------------------------------------------------------
rng = random.Random(77)
BW, BH = 60, 46
b = [["a" for _ in range(BW)] for _ in range(BH)]

def brect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < BW and 0 <= y < BH:
                b[y][x] = ch

def bset(x, y, ch):
    if 0 <= x < BW and 0 <= y < BH:
        b[y][x] = ch

def bmanchas(x0, y0, x1, y1, ch, prob, sobre="a"):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if b[y][x] == sobre and rng.random() < prob:
                b[y][x] = ch

def bblob(cx, cy, rx, ry, ch, sobre=None):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if 0 <= x < BW and 0 <= y < BH and (sobre is None or b[y][x] in sobre):
                dx = (x - cx) / rx
                dy = (y - cy) / ry
                if dx * dx + dy * dy <= 1.0 + rng.uniform(-0.25, 0.1):
                    b[y][x] = ch

def casa(x0, y0, ancho, color="R", puerta=None, ventanas=()):
    """Contenedor-casa visto desde arriba: 2 filas de techo y 1 fila de frente con puerta/ventanas."""
    top, cara, pu, ve = ("R", "r", "D", "w") if color == "R" else ("U", "u", "E", "e")
    brect(x0, y0, x0 + ancho - 1, y0 + 1, top)
    brect(x0, y0 + 2, x0 + ancho - 1, y0 + 2, cara)
    if puerta is not None:
        bset(x0 + puerta, y0 + 2, pu)
    for v in ventanas:
        bset(x0 + v, y0 + 2, ve)

# Muralla de contenedores alrededor de toda la ciudad
for x in range(BW):
    col = "R" if (x // 3) % 2 == 0 else "U"
    bset(x, 0, col); bset(x, 1, col.lower())
    bset(x, BH - 2, col); bset(x, BH - 1, col.lower())
for y in range(BH):
    bset(0, y, "R"); bset(BW - 1, y, "U")

# Puerta sur (de vuelta al páramo)
brect(28, BH - 2, 31, BH - 1, "p")
bset(27, BH - 2, "{"); bset(27, BH - 1, "{"); bset(32, BH - 2, "}"); bset(32, BH - 1, "}")

# --- Puerto seco (norte): el buque encallado y el trono de Rictus
brect(10, 2, 44, 10, "g")
bmanchas(10, 2, 44, 10, "G", 0.35, "g")
brect(29, 4, 37, 9, "p")                 # plataforma del trono
for x in range(29, 38, 2):
    bset(x, 4, "q")
bset(29, 9, "L"); bset(37, 9, "L")
brect(30, 10, 32, 23, "p")               # Avenida del Impuesto (puerto -> plaza)
for y in range(11, 23, 3):
    bset(31, y, "q")
bset(29, 12, "L"); bset(33, 18, "L")
# contenedores a los lados de la avenida
casa(24, 11, 5, "R", puerta=2)
casa(24, 15, 5, "U", ventanas=(1, 3))
casa(24, 19, 5, "R", puerta=1, ventanas=(3,))
casa(34, 11, 5, "U", ventanas=(2,))
casa(34, 15, 5, "R", puerta=3, ventanas=(1,))
casa(34, 19, 5, "U", puerta=2)
brect(10, 11, 23, 11, "x")               # reja del puerto (oeste)
brect(39, 11, 45, 11, "x")               # reja del puerto (este)

# --- Plaza central
brect(19, 24, 41, 33, "c")
for (x, y) in ((19, 24), (41, 24), (19, 33), (41, 33)):
    bset(x, y, "L")
bset(23, 30, "l"); bset(38, 32, "l")
# La trituradora (oeste de la plaza) y la cinta que la alimenta desde el vertedero
brect(11, 23, 18, 30, "p")
brect(14, 13, 15, 22, "b")
brect(13, 13, 13, 22, "p"); brect(16, 13, 16, 22, "p")
for y in range(13, 23, 2):
    bset(14, y, "B"); bset(15, y + 1, "B")
# Calle sur (plaza -> puerta)
brect(28, 34, 31, BH - 3, "p")
for y in range(35, BH - 3, 3):
    bset(29, y, "q")
bset(27, 38, "L"); bset(32, 41, "L")
# Calle este (plaza -> dunas) y oeste (plaza -> barrio oeste)
brect(42, 25, 46, 27, "p")
brect(11, 31, 18, 33, "p")

# --- Barrio oeste: casas de contenedores
casa(2, 14, 4, "U", puerta=1)
casa(2, 18, 6, "R", puerta=2, ventanas=(4,))
casa(2, 22, 5, "U", ventanas=(1, 3))
casa(2, 26, 6, "R", puerta=4, ventanas=(1,))
casa(2, 31, 6, "U", ventanas=(3,))          # aquí está el mural
casa(2, 36, 5, "R", puerta=2)
casa(2, 40, 6, "U", puerta=1, ventanas=(4,))
brect(8, 13, 10, 43, "p")
bset(9, 20, "L"); bset(9, 34, "L")
# --- Barrio este (al sur de la tienda)
casa(36, 35, 5, "R", puerta=2)
casa(36, 39, 5, "U", ventanas=(1, 3))
casa(42, 35, 4, "U", puerta=1)
casa(42, 39, 4, "R", ventanas=(2,))
brect(33, 34, 46, 34, "p")

# --- Vertedero (noroeste): chatarral donde salen criaturas
brect(1, 2, 9, 10, "a")
bblob(5, 6, 4, 4, "j")
bmanchas(1, 2, 9, 10, "J", 0.25, "j")
for (x, y) in ((2, 3), (8, 3), (3, 9), (7, 8)):
    bset(x, y, rng.choice("knok"))
brect(1, 11, 9, 11, "a")
brect(10, 12, 12, 12, "p")

# --- Dunas de óxido (este), separadas por una muralla con un paso
for y in range(2, BH - 2):
    if not (24 <= y <= 27):
        bset(47, y, "U" if y % 6 < 3 else "R")
brect(48, 2, 58, BH - 3, "s")
bblob(53, 8, 4, 4, "d", "s")             # alrededor de las torres del norte
bblob(52, 20, 5, 6, "d", "s")
bblob(54, 34, 4, 6, "d", "s")
bmanchas(48, 2, 58, BH - 3, "d", 0.12, "s")
bmanchas(48, 2, 58, BH - 3, "S", 0.3, "d")
for (x, y) in ((50, 14), (57, 28), (49, 40), (56, 4)):
    bset(x, y, rng.choice("kn"))

# --- Detalles
for (x, y) in ((20, 34), (12, 12), (44, 30), (25, 9), (40, 3), (18, 40), (46, 22)):
    if b[y][x] in "ap":
        bset(x, y, rng.choice("onk"))
bset(12, 40, "F")                        # fogata junto a la posada
bmanchas(1, 2, BW - 2, BH - 3, ":", 0.06, "a")

guardar("bastion_oxido.txt", b)
print("Mapas escritos en", os.path.join(AQUI, "mapas"))
