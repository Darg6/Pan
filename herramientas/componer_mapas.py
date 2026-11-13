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
print("Mapas escritos en", os.path.join(AQUI, "mapas"))
