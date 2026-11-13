"""
Arte de la Ciudad 1: BASTIÓN DE ÓXIDO (Comandante Rictus).
Lo llama herramientas/generar_pixel_art.py (no hace falta correrlo solo).

  - tiles nuevos del exterior (dunas, chatarral, placas, puertas de contenedor, faroles...)
  - construcciones grandes (trituradora, buque encallado, grúa, tienda, posada, trono...)
  - vecinos de la ciudad, Rictus (mapa y combate) y sus retratos
  - criaturas nuevas: Titán de Chatarra, Enjambre Mecánico, Bailarina Eléctrica, Gusano Devorador
  - iconos de la tienda y fondos de combate "dunas" y "bastion"
"""
import math
import random

from PIL import Image, ImageDraw

from generar_pixel_art import *   # noqa: F401,F403  (colores y ayudantes: c, nuevo, contorno, sombrear...)
import generar_pixel_art as g

ARENA_OX = [c("b5653a"), c("9e5632"), c("c97a46"), c("8a4628"), c("d98a52")]
PLACA = [c("5e5a58"), c("4e4a49"), c("726d6a"), c("3c3938"), c("8a8480")]


# ---------------------------------------------------------------------------
# TILES (se agregan al final del atlas exterior: no cambian los que ya existían)
# ---------------------------------------------------------------------------
def tile_duna(rng, v):
    t = nuevo(T, T, ARENA[0])
    ruido(t, (0, 0, T, T), [ARENA[1], ARENA[3]], 0.14, rng)
    px = t.load()
    fase = v * 5
    for base in (4, 11):
        for x in range(T):
            y = base + int(round(math.sin((x + fase + base) / 2.6) * 1.4))
            if 0 <= y < T:
                px[x, y] = ARENA[2]
            if 0 <= y - 1 < T:
                px[x, y - 1] = ARENA[3]
    for _ in range(2):   # granos de óxido
        px[rng.randrange(T), rng.randrange(T)] = OXIDO[1]
    return t

def tile_chatarral(rng, v):
    t = g.tile_tierra(rng, [c("7a5a40"), c("6a4a34"), c("5a3f2c"), c("8a6a4a"), c("4a3424")])
    d = ImageDraw.Draw(t)
    for _ in range(5 + v):
        x, y = rng.randrange(0, T - 3), rng.randrange(1, T - 2)
        col = rng.choice([METAL[0], METAL[2], OXIDO[0], OXIDO[2], c("3a3a40")])
        w = rng.randint(1, 3)
        d.rectangle((x, y, x + w, y + rng.randint(0, 1)), col)
        d.line((x, y + 2, x + w, y + 2), c("3a2a20"))
    d.point((rng.randrange(2, 14), rng.randrange(2, 14)), METAL[4])   # un tornillo que brilla
    return t

def tile_arena_oxido(rng):
    t = nuevo(T, T, ARENA_OX[0])
    ruido(t, (0, 0, T, T), [ARENA_OX[1], ARENA_OX[2]], 0.18, rng)
    ruido(t, (0, 0, T, T), [ARENA_OX[3]], 0.04, rng)
    return t

def tile_placa(rng, v):
    t = nuevo(T, T, PLACA[0])
    ruido(t, (0, 0, T, T), [PLACA[1], PLACA[2]], 0.12, rng)
    d = ImageDraw.Draw(t)
    d.line((0, 0, T - 1, 0), PLACA[3]); d.line((0, 0, 0, T - 1), PLACA[3])
    d.line((1, 1, T - 1, 1), PLACA[4])
    for (x, y) in ((2, 3), (13, 3), (2, 13), (13, 13)):
        d.point((x, y), PLACA[4]); d.point((x + 1, y + 1), PLACA[3])
    if v == 1:   # rayas antideslizantes
        for k in range(4, 13, 3):
            d.line((k, 6, k + 2, 9), PLACA[2])
    ruido(t, (0, 0, T, T), [OXIDO[0], OXIDO[1]], 0.05, rng)
    return t

def tile_puerta(rng, color):
    t = g.tile_contenedor(rng, color)
    d = ImageDraw.Draw(t)
    d.rectangle((4, 2, 11, 15), c("2a2026"))
    d.rectangle((5, 3, 10, 15), oscurecer(color[0], 0.6))
    d.line((7, 3, 7, 15), oscurecer(color[0], 0.45)); d.line((8, 3, 8, 15), oscurecer(color[0], 0.45))
    d.point((6, 9), c("e6c34a"))
    d.rectangle((4, 0, 11, 1), oscurecer(color[0], 0.7))
    return t

def tile_ventana(rng, color, luz):
    t = g.tile_contenedor(rng, color)
    d = ImageDraw.Draw(t)
    d.rectangle((3, 4, 12, 10), c("1e1618"))
    d.rectangle((4, 5, 11, 9), luz)
    d.line((4, 5, 11, 5), aclarar(luz, 1.2))
    d.rectangle((4, 5, 6, 9), c("8a3a3a")); d.rectangle((9, 5, 11, 9), c("8a3a3a"))   # cortinas de trapo
    d.line((3, 11, 12, 11), METAL[3])
    return t

def tile_farol(rng):
    base = tile_placa(rng, 0)
    capa = nuevo(T, T); d = ImageDraw.Draw(capa)
    d.line((7, 15, 7, 3), METAL[3], 2)
    d.line((7, 3, 11, 2), METAL[3])
    d.rectangle((10, 2, 13, 5), c("ffd27a")); d.point((11, 3), c("fff4c8"))
    d.rectangle((5, 13, 9, 15), METAL[1])
    contorno(capa)
    base.alpha_composite(capa)
    return base

def tile_cinta(rng, v):
    t = nuevo(T, T, c("2a2626"))
    d = ImageDraw.Draw(t)
    d.rectangle((0, 2, T - 1, 13), c("3a3434"))
    for y in range(3 + v, 13, 3):
        d.line((1, y, T - 2, y), c("4e4646"))
    d.line((0, 1, T - 1, 1), METAL[4]); d.line((0, 14, T - 1, 14), METAL[3])
    for (x, y) in ((3, 6), (10, 9)):   # chatarra sobre la cinta
        d.rectangle((x, y, x + 3, y + 2), rng.choice([OXIDO[0], METAL[0], OXIDO[2]]))
    return t

def tile_aceite(rng):
    t = tile_placa(rng, 0)
    d = ImageDraw.Draw(t)
    d.ellipse((2, 5, 13, 12), c("1a1a22"))
    d.ellipse((4, 6, 9, 9), c("3a2a5a")); d.point((6, 7), c("5a8a6a")); d.point((10, 9), c("6a4a8a"))
    return t

def tile_lecho(rng, v):
    """Fondo seco del antiguo puerto: barro cuarteado."""
    t = nuevo(T, T, c("8a7a62"))
    ruido(t, (0, 0, T, T), [c("7a6a54"), c("9a8a70")], 0.15, rng)
    d = ImageDraw.Draw(t)
    x, y = rng.randrange(0, 6), 0
    while y < T:
        nx = x + rng.choice((1, 2, 3))
        ny = y + rng.choice((1, 2, 3))
        d.line((x, y, nx, ny), c("5a4c3a"))
        x, y = nx % T, ny
    d.line((0, 8 + v * 3, 6, 9 + v * 3, T, 7 + v * 2), c("5a4c3a"))
    return t

def tile_reja(rng):
    t = g.tile_arena(rng) if False else tile_arena_oxido(rng)
    capa = nuevo(T, T); d = ImageDraw.Draw(capa)
    d.rectangle((0, 3, T - 1, 13), (0, 0, 0, 0))
    for x in range(1, T, 3):
        d.line((x, 2, x, 14), METAL[2])
    d.line((0, 3, T - 1, 3), METAL[4]); d.line((0, 13, T - 1, 13), METAL[3])
    for x in range(0, T, 2):   # alambre de púas
        d.point((x, 1), METAL[4]); d.point((x + 1, 0), METAL[3])
    contorno(capa)
    t.alpha_composite(capa)
    return t

def aclarar(col, f):
    return (min(255, int(col[0] * f)), min(255, int(col[1] * f)), min(255, int(col[2] * f)), col[3] if len(col) > 3 else 255)

def tiles(rng):
    rojo = (OXIDO[0], OXIDO[1], OXIDO[4])
    azul = (c("3f5f73"), c("2f4757"), c("5f8399"))
    return [
        ("duna_1", tile_duna(rng, 0), False), ("duna_2", tile_duna(rng, 1), False),
        ("chatarral_1", tile_chatarral(rng, 0), False), ("chatarral_2", tile_chatarral(rng, 2), False),
        ("arena_oxido", tile_arena_oxido(rng), False),
        ("placa_1", tile_placa(rng, 0), False), ("placa_2", tile_placa(rng, 1), False),
        ("puerta_roja", tile_puerta(rng, rojo), True), ("puerta_azul", tile_puerta(rng, azul), True),
        ("ventana_roja", tile_ventana(rng, rojo, c("e0a050")), True), ("ventana_azul", tile_ventana(rng, azul, c("d8b060")), True),
        ("farol", tile_farol(rng), True),
        ("cinta_1", tile_cinta(rng, 0), True), ("cinta_2", tile_cinta(rng, 1), True),
        ("aceite", tile_aceite(rng), False),
        ("lecho_1", tile_lecho(rng, 0), False), ("lecho_2", tile_lecho(rng, 1), False),
        ("reja", tile_reja(rng), True),
    ]


# ---------------------------------------------------------------------------
# CONSTRUCCIONES GRANDES (arte/decorados/*.png). La base de la imagen es el "suelo".
# ---------------------------------------------------------------------------
def terminar_decor(img):
    sombrear(img, 1.12, 0.75)
    contorno(img)
    return img

def remaches(d, x0, x1, y, col=METAL[4], paso=6):
    for x in range(x0, x1, paso):
        d.point((x, y), col)

def trituradora(cuadro):
    """La trituradora del centro de Bastión. 2 cuadros: los dientes giran."""
    W2, H2 = 96, 80
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    # sombra en el piso
    d.ellipse((6, 70, 92, 79), (0, 0, 0, 80))
    # cuerpo principal
    d.polygon([(12, 74), (12, 34), (20, 26), (76, 26), (84, 34), (84, 74)], OXIDO[1])
    d.rectangle((16, 36, 80, 72), OXIDO[0])
    for y in range(40, 72, 8):
        d.line((16, y, 80, y), OXIDO[3])
    remaches(d, 18, 80, 38); remaches(d, 18, 80, 70)
    # tolva (embudo) arriba
    d.polygon([(22, 26), (14, 6), (82, 6), (74, 26)], METAL[1])
    d.polygon([(26, 24), (20, 9), (76, 9), (70, 24)], c("2a2226"))
    d.line((14, 6, 82, 6), METAL[4])
    # dientes que giran
    for k in range(6):
        x = 28 + k * 8 + (4 if cuadro else 0)
        if x < 70:
            d.polygon([(x, 22), (x + 3, 14), (x + 6, 22)], METAL[2])
            d.point((x + 3, 15), METAL[4])
    for k in range(5):
        x = 30 + k * 8 + (0 if cuadro else 4)
        d.polygon([(x, 12), (x + 3, 18), (x + 6, 12)], METAL[0])
    # chatarra cayendo dentro
    for (x, y, col) in ((34, 10, OXIDO[2]), (50, 8, METAL[2]), (62, 11, OXIDO[4])):
        d.rectangle((x, y + (2 if cuadro else 0), x + 4, y + 2 + (2 if cuadro else 0)), col)
    # boca de salida y la luz roja de advertencia
    d.rectangle((38, 52, 58, 72), c("1e1618"))
    for k in range(4):
        d.line((40 + k * 5, 54, 40 + k * 5, 72), METAL[3])
    d.ellipse((76, 30, 82, 36), c("ff4a3a") if cuadro else c("a02a22"))
    d.ellipse((14, 30, 20, 36), c("a02a22") if cuadro else c("ff4a3a"))
    # cartel "CUOTA" pintado
    d.rectangle((22, 42, 34, 48), c("e6c34a")); d.line((24, 45, 32, 45), CONTORNO)
    # chimenea
    d.rectangle((70, 0, 78, 8), METAL[3]); d.rectangle((69, 0, 79, 2), METAL[1])
    return terminar_decor(img)

def generar_trituradora():
    hoja = nuevo(96 * 2, 80)
    for k in range(2):
        hoja.alpha_composite(trituradora(k), (96 * k, 0))
    guardar(hoja, "decorados/trituradora.png")

def buque():
    """Buque de carga encallado en el fondo seco del puerto (inclinado y oxidado)."""
    W2, H2 = 240, 104
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((10, 92, 236, 103), (0, 0, 0, 70))
    # casco inclinado
    casco = [(4, 52), (232, 40), (226, 78), (210, 96), (24, 98), (10, 82)]
    d.polygon(casco, OXIDO[3])
    d.polygon([(8, 56), (230, 44), (224, 74), (12, 80)], OXIDO[1])
    d.line((8, 56, 230, 44), OXIDO[4])
    for k in range(10):   # chorreados de óxido
        x = 20 + k * 20
        d.line((x, 58 - k, x + 1, 86 - k // 2), OXIDO[0])
    d.polygon([(10, 82), (226, 74), (210, 96), (24, 98)], c("3a2a24"))   # quilla en sombra
    # contenedores sobre cubierta
    cols = [(OXIDO[0], OXIDO[1]), (c("3f5f73"), c("2f4757")), (c("6a7a3a"), c("4a5a2a")), (OXIDO[2], OXIDO[0])]
    for k in range(7):
        x = 26 + k * 24
        y = 52 - k * 1.7
        a, b = cols[k % 4]
        d.rectangle((x, y - 16, x + 20, y), a)
        for xx in range(x + 2, x + 20, 3):
            d.line((xx, y - 15, xx, y - 1), b)
        if k % 2 == 0:
            d.rectangle((x + 2, y - 30, x + 18, y - 16), cols[(k + 1) % 4][0])
    # puente de mando
    d.rectangle((188, 6, 222, 42), c("c9c0a8"))
    d.rectangle((192, 12, 218, 20), c("2a3a44")); d.rectangle((192, 26, 218, 32), c("2a3a44"))
    d.rectangle((200, 0, 206, 6), METAL[1])
    for x in range(194, 218, 6):
        d.line((x, 12, x, 20), c("4a5a64"))
    # nombre del barco medio borrado y agujeros
    d.rectangle((40, 66, 70, 70), c("d9d0b8"))
    for (x, y) in ((120, 70), (150, 64), (90, 74)):
        d.ellipse((x, y, x + 8, y + 6), c("1e1618"))
    d.line((4, 52, 0, 100), OXIDO[3], 3)   # ancla caída
    return terminar_decor(img)

def grua():
    """Grúa del puerto, doblada. En la punta anidan las Aves Negras (misión de Bruno)."""
    W2, H2 = 96, 128
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((14, 118, 60, 127), (0, 0, 0, 70))
    col = c("c98a2a"); col2 = c("8a5a1e")
    # torre
    d.rectangle((26, 30, 46, 124), col2)
    d.rectangle((28, 30, 44, 124), col)
    for y in range(34, 124, 10):
        d.line((28, y, 44, y + 10), col2); d.line((44, y, 28, y + 10), col2)
    # cabina
    d.rectangle((22, 18, 50, 34), c("d0c6a8")); d.rectangle((26, 22, 46, 28), c("2a3a44"))
    # brazo doblado hacia la derecha y abajo
    d.polygon([(46, 22), (90, 10), (94, 16), (48, 30)], col)
    for x in range(50, 90, 8):
        d.line((x, 26 - (x - 50) // 4, x + 4, 18 - (x - 50) // 4), col2)
    d.line((90, 14, 92, 60), METAL[3]); d.rectangle((86, 60, 96, 66), METAL[1])   # gancho
    # contrapeso
    d.polygon([(26, 22), (4, 30), (4, 38), (26, 32)], col2)
    d.rectangle((2, 36, 14, 46), CONCRETO[2])
    # nido de aves negras
    d.ellipse((60, 4, 82, 16), c("4a3a2a"))
    for k in range(6):
        d.line((60 + k * 4, 8, 64 + k * 3, 14), c("2a2018"))
    for (x, y) in ((64, 2), (72, 0), (78, 4)):
        d.polygon([(x, y + 4), (x + 3, y), (x + 6, y + 4), (x + 3, y + 3)], c("23202c"))
        d.point((x + 3, y + 2), c("ff4a3a"))
    return terminar_decor(img)

def tanque():
    W2, H2 = 48, 56
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((4, 48, 44, 55), (0, 0, 0, 70))
    for x in (8, 38):
        d.rectangle((x, 30, x + 3, 52), METAL[3])
    d.rectangle((6, 6, 42, 36), c("3f6f83"))
    d.ellipse((6, 2, 42, 10), c("5f8fa3"))
    for y in range(12, 36, 6):
        d.line((6, y, 42, y), c("2f5767"))
    d.rectangle((14, 16, 34, 26), c("e6c34a"))   # placa de la Organización
    d.polygon([(24, 17), (32, 25), (16, 25)], c("8c2f2f"))
    d.rectangle((40, 32, 46, 34), METAL[2]); d.rectangle((44, 34, 46, 38), METAL[2])   # grifo
    d.point((45, 40), c("6ac8ff"))
    d.rectangle((2, 40, 6, 52), METAL[1]); d.line((2, 40, 6, 40), METAL[4])   # candado
    d.rectangle((1, 44, 7, 48), c("e6c34a"))
    return terminar_decor(img)

def tienda():
    W2, H2 = 80, 64
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((2, 56, 78, 63), (0, 0, 0, 70))
    d.rectangle((6, 18, 74, 58), c("3f5f73"))
    for x in range(8, 74, 3):
        d.line((x, 20, x, 57), c("2f4757"))
    d.rectangle((14, 34, 66, 58), c("2a2026"))   # hueco de la tienda
    d.rectangle((16, 36, 64, 46), c("5a4030"))   # estantes
    for x in range(18, 62, 6):
        d.rectangle((x, 38, x + 3, 44), [c("7bd13b"), c("ff6a4a"), c("e6c34a"), c("6ac8ff")][(x // 6) % 4])
    d.rectangle((12, 48, 68, 58), MADERA[0]); d.line((12, 48, 68, 48), MADERA[2])   # mostrador
    # toldo a rayas
    for k in range(9):
        col = c("c42e34") if k % 2 == 0 else c("e8dcc0")
        d.polygon([(4 + k * 8, 18), (12 + k * 8, 18), (12 + k * 8, 30), (4 + k * 8, 30)], col)
        d.polygon([(4 + k * 8, 30), (8 + k * 8, 33), (12 + k * 8, 30)], col)
    # letrero
    d.rectangle((20, 2, 60, 14), MADERA[1]); d.rectangle((22, 4, 58, 12), c("e6c34a"))
    for k, x in enumerate(range(25, 56, 6)):   # "TIENDA" en puntitos
        d.rectangle((x, 6, x + 3, 9), c("3a2418"))
    d.line((24, 14, 24, 18), METAL[3]); d.line((56, 14, 56, 18), METAL[3])
    return terminar_decor(img)

def posada():
    W2, H2 = 88, 56
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((2, 48, 86, 55), (0, 0, 0, 60))
    for x in (6, 82):
        d.line((x, 14, x, 52), MADERA[1], 2)
    d.polygon([(0, 16), (44, 4), (88, 16), (84, 22), (44, 12), (4, 22)], c("6a7a5a"))   # lona
    d.polygon([(4, 22), (44, 12), (84, 22), (84, 26), (4, 26)], c("4e5a42"))
    for x in range(8, 84, 10):
        d.line((x, 18, x + 4, 24), c("8a9a72"))
    # camas de cartón
    for x in (12, 36, 60):
        d.rectangle((x, 36, x + 18, 50), c("a07a4a"))
        d.line((x, 42, x + 18, 42), c("7d5d36"))
        d.rectangle((x + 1, 37, x + 6, 41), c("c9c0a8"))
        d.rectangle((x + 7, 43, x + 17, 49), [c("6b5a7a"), c("7a4a3a"), c("4a6a6a")][x // 24 % 3])
    d.rectangle((40, 28, 48, 34), c("e6c34a"))   # farolito
    d.point((44, 30), c("fff4c8"))
    return terminar_decor(img)

def trono():
    W2, H2 = 64, 64
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((4, 54, 60, 63), (0, 0, 0, 80))
    d.polygon([(6, 60), (10, 46), (54, 46), (58, 60)], METAL[1])   # base de chatarra
    for (x, y, col) in ((8, 50, OXIDO[0]), (20, 52, METAL[0]), (40, 50, OXIDO[2]), (48, 54, c("3a3a40"))):
        d.rectangle((x, y, x + 10, y + 5), col)
    d.rectangle((16, 14, 48, 48), OXIDO[1])                        # respaldo
    d.polygon([(16, 14), (12, 2), (22, 10), (32, 0), (42, 10), (52, 2), (48, 14)], OXIDO[0])   # puntas
    d.rectangle((22, 20, 42, 40), c("8c2f2f"))                    # estandarte rojo
    d.polygon([(32, 23), (39, 36), (25, 36)], c("1e1618"))
    d.rectangle((14, 34, 22, 48), METAL[0]); d.rectangle((42, 34, 50, 48), METAL[0])   # apoyabrazos
    d.rectangle((22, 40, 42, 46), METAL[2])
    for (x, y) in ((8, 40), (52, 38)):   # neumáticos
        d.ellipse((x - 6, y, x + 6, y + 8), c("1e1a1e")); d.ellipse((x - 2, y + 3, x + 2, y + 5), c("3a3438"))
    # palanca de la trituradora (Pan la baja al ganar)
    d.line((56, 46, 60, 30), METAL[3], 2); d.ellipse((57, 26, 63, 32), c("c42e34"))
    return terminar_decor(img)

def estatua():
    W2, H2 = 40, 64
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((2, 56, 38, 63), (0, 0, 0, 70))
    d.rectangle((6, 48, 34, 60), CONCRETO[2]); d.line((6, 48, 34, 48), CONCRETO[3])
    d.rectangle((14, 52, 26, 56), c("e6c34a"))
    # Rictus de chatarra con los brazos en jarra
    d.rectangle((14, 30, 26, 48), METAL[0])
    d.rectangle((10, 30, 13, 40), METAL[1]); d.rectangle((27, 30, 30, 40), METAL[1])
    d.rectangle((15, 16, 25, 29), METAL[2])
    d.rectangle((18, 4, 22, 17), c("8c2f2f"))   # cresta pintada de rojo
    d.rectangle((17, 20, 19, 22), c("1e1618")); d.rectangle((21, 20, 24, 23), c("2a2a2a"))   # ojo y parche
    d.line((17, 26, 23, 26), c("1e1618"))
    d.polygon([(8, 30), (14, 28), (14, 34), (6, 36)], OXIDO[1])   # hombrera
    remaches(d, 15, 26, 40, METAL[4], 4)
    return terminar_decor(img)

def torre_alta():
    W2, H2 = 40, 104
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((4, 96, 36, 103), (0, 0, 0, 60))
    col = c("4a4448"); col2 = c("6a6268")
    d.line((6, 100, 18, 8), col, 2); d.line((34, 100, 22, 8), col, 2)
    for k in range(9):
        y = 100 - k * 10
        a = 6 + k * 1.3; b = 34 - k * 1.3
        d.line((a, y, b, y - 10), col); d.line((b, y, a, y - 10), col)
        d.line((a, y, b, y), col2)
    d.line((0, 18, 40, 18), col, 2); d.line((4, 30, 36, 30), col, 2)
    for x in (1, 39, 5, 35):
        d.line((x, 18 if x in (1, 39) else 30, x, 22 if x in (1, 39) else 34), c("d0d0d8"))
    d.point((20, 6), c("ff4a3a"))
    # chispas en los cables (aquí viven las Bailarinas Eléctricas)
    for (x, y) in ((2, 23), (37, 35)):
        d.point((x, y), c("9ff0ff")); d.point((x + 1, y + 1), c("ffffff"))
    return terminar_decor(img)

def mural():
    """Mural pintado hace años en un contenedor: un gato y una mariposa (como el collar y el aro de Pan)."""
    W2, H2 = 32, 24
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 31, 23), (0, 0, 0, 0))
    # gato (silueta morada)
    d.polygon([(3, 20), (4, 12), (6, 8), (7, 4), (9, 7), (11, 4), (12, 8), (14, 12), (14, 20)], c("9b6fd1"))
    d.point((8, 9), c("e6c34a")); d.point((11, 9), c("e6c34a"))
    d.line((14, 18, 18, 14, 17, 10), c("9b6fd1"))
    # mariposa dorada
    d.polygon([(22, 8), (18, 3), (17, 9), (22, 11)], c("e6c34a")); d.polygon([(23, 8), (27, 3), (28, 9), (23, 11)], c("e6c34a"))
    d.polygon([(22, 11), (19, 16), (22, 14)], c("d9a030")); d.polygon([(23, 11), (26, 16), (23, 14)], c("d9a030"))
    d.line((22, 7, 22, 15), c("3a2418")); d.line((23, 7, 23, 15), c("3a2418"))
    # letras borrosas: "CONSTRUYE"
    for x in range(2, 30, 3):
        d.point((x, 22), c("f0e6d2"))
    return img

def tablon():
    W2, H2 = 32, 36
    img = nuevo(W2, H2); d = ImageDraw.Draw(img)
    d.ellipse((4, 30, 28, 35), (0, 0, 0, 60))
    d.line((6, 34, 6, 18), MADERA[1], 2); d.line((26, 34, 26, 18), MADERA[1], 2)
    d.rectangle((2, 2, 30, 22), MADERA[0]); d.rectangle((4, 4, 28, 20), c("d8cdb0"))
    for y in range(6, 19, 3):
        d.line((6, y, 6 + (y * 7) % 18, y), c("5a4a3a"))
        d.point((26, y), c("c42e34"))
    d.rectangle((20, 4, 28, 9), c("8c2f2f"))
    return terminar_decor(img)

def generar_decorados():
    generar_trituradora()
    guardar(buque(), "decorados/buque.png")
    guardar(grua(), "decorados/grua.png")
    guardar(tanque(), "decorados/tanque.png")
    guardar(tienda(), "decorados/tienda.png")
    guardar(posada(), "decorados/posada.png")
    guardar(trono(), "decorados/trono.png")
    guardar(estatua(), "decorados/estatua.png")
    guardar(torre_alta(), "decorados/torre.png")
    guardar(mural(), "decorados/mural.png")
    guardar(tablon(), "decorados/tablon.png")
    # objetos chicos para investigar
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((2, 6, 13, 14), c("4a4a3a")); d.rectangle((4, 8, 8, 12), c("2a2a2a"))
    for y in (8, 10, 12):
        d.line((10, y, 12, y), METAL[4])
    d.line((11, 6, 14, 1), METAL[3]); d.point((14, 1), c("ff4a3a"))
    sombrear(img); contorno(img)
    guardar(img, "objetos/radio.png")
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((2, 7, 13, 14), c("c42e34")); d.rectangle((2, 7, 13, 9), c("e04a40"))
    d.rectangle((6, 4, 9, 7), METAL[2]); d.line((6, 4, 9, 4), METAL[4])
    sombrear(img); contorno(img)
    guardar(img, "objetos/caja_herramientas.png")
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((4, 4, 11, 14), c("8a7a5a")); d.ellipse((4, 2, 11, 6), c("aa9a7a"))
    d.ellipse((5, 3, 10, 5), c("3a5a7a"))
    sombrear(img); contorno(img)
    guardar(img, "objetos/balde.png")


# ---------------------------------------------------------------------------
# PERSONAS DE BASTIÓN (16x24 en el mapa)
# ---------------------------------------------------------------------------
def nino_frente(piel, pelo, ropa, ropa2, pantalon, bota, ojo=c("2a2018"), extra=None, despues=None, coletas=False):
    """Niño/niña: más bajito (la cabeza empieza más abajo)."""
    img = nuevo(16, 24); d = ImageDraw.Draw(img)
    d.rectangle((5, 19, 6, 21), pantalon); d.rectangle((5, 22, 6, 23), bota)
    d.rectangle((4, 13, 7, 18), ropa)
    d.rectangle((3, 14, 3, 17), ropa2); d.point((3, 18), piel)
    d.rectangle((4, 6, 7, 12), piel)
    d.rectangle((3, 4, 7, 6), pelo); d.point((3, 7), pelo)
    if coletas:
        d.rectangle((2, 7, 3, 10), pelo)
    d.point((5, 9), ojo)
    if extra:
        extra(d)
    espejar(img)
    d = ImageDraw.Draw(img)
    if despues:
        despues(d)
    luz_lateral(img); contorno_suave(img)
    return img

def mila_mapa():
    """Mila, la comerciante: gafas de soldador en la frente, delantal de cuero."""
    def extra(d, dy):
        d.rectangle((3, 3, 7, 4), c("3a3a40")); d.point((5, 3), c("9ff0ff"))   # gafas
        d.rectangle((4, 13, 7, 17), c("7a4e2a"))                              # delantal
        d.point((5, 15), c("e6c34a"))
    return persona_frente(c("d8a878"), c("c46a2a"), "largo", c("4a6a5a"), c("3a5448"), c("3a3328"), c("2a2018"), extra=extra)

def odila_mapa():
    """Odila, la de la posada: pañuelo en la cabeza, cansada."""
    def extra(d, dy):
        d.rectangle((3, 1 + dy, 7, 3 + dy), c("6a4a7a")); d.point((3, 4 + dy), c("6a4a7a"))
        d.point((5, 8 + dy), c("9a6a52"))
    return persona_frente(c("c08a60"), c("3a2a24"), "largo", c("7a5a4a"), c("5a4236"), c("3e3a33"), c("2a2620"), extra=extra, encorvado=True)

def bruno_mapa():
    """Bruno, viejo operador de grúas: gorra, barba blanca, overol."""
    def extra(d, dy):
        d.rectangle((3, 1, 7, 3), c("c98a2a")); d.line((2, 3, 7, 3), c("8a5a1e"))   # gorra
        d.rectangle((4, 8, 7, 10), c("e0dcd4")); d.point((4, 7), c("e0dcd4"))      # barba
        d.rectangle((4, 11, 7, 17), c("3f5f73"))                                   # overol
        d.point((4, 12), c("e6c34a"))
    return persona_frente(c("b88458"), c("d0ccc4"), "corto", c("6a6458"), c("4e483f"), c("3f5f73"), c("2a2018"), extra=extra, encorvado=True)

def rosa_mapa():
    """Rosa, la anciana del mural: chal y pelo blanco recogido."""
    def extra(d, dy):
        d.rectangle((3, 0, 6, 2), c("e8e4dc"))
        d.polygon([(2, 11 + dy), (7, 11 + dy), (7, 16), (3, 15)], c("8a4a5a"))   # chal
    return persona_frente(c("d0a07a"), c("e8e4dc"), "corto", c("5a5a6a"), c("4a4a58"), c("4a4440"), c("2a2620"), extra=extra, encorvado=True)

def lia_mapa():
    return nino_frente(c("d8a878"), c("6a3a24"), c("c9a24a"), c("a8843a"), c("5a4a3a"), c("3a2a20"), coletas=True)

def tavo_mapa():
    def extra(d):
        d.point((4, 15), c("4a4238")); d.point((6, 17), c("4a4238"))   # hollín
    def despues(d):
        d.line((12, 13, 14, 9), METAL[2]); d.point((14, 8), OXIDO[2])     # lleva un fierro
    return nino_frente(c("b88458"), c("2a2220"), c("6a7a3a"), c("4a5a2a"), c("4a4038"), c("2a2018"), extra=extra, despues=despues)

def vecina_mapa():
    def extra(d, dy):
        d.point((4, 14), c("4a4238")); d.point((5, 9 + dy), c("8a6a52"))
    return persona_frente(c("e0b088"), c("4a3428"), "largo", c("8a6a5a"), c("6a4e42"), c("4a4038"), c("2a2620"), extra=extra, encorvado=True)

def rictus_mapa():
    """Rictus en el mapa: cresta roja, hombrera de chatarra, parche."""
    piel = c("b07a50")
    img = nuevo(16, 24); d = ImageDraw.Draw(img)
    d.rectangle((3, 18, 6, 21), c("3a3328")); d.rectangle((3, 22, 6, 23), c("2a2018"))
    d.rectangle((2, 10, 7, 17), OXIDO[1])
    d.rectangle((1, 11, 1, 16), OXIDO[3]); d.point((1, 17), piel)
    d.line((2, 17, 7, 17), METAL[3])
    d.rectangle((4, 3, 7, 9), piel)
    d.rectangle((3, 3, 3, 6), oscurecer(piel, 0.85))
    d.point((5, 6), c("8a5a2a"))
    d.line((5, 8, 7, 8), oscurecer(piel, 0.6))
    espejar(img)
    d = ImageDraw.Draw(img)
    d.rectangle((7, 0, 8, 4), c("c43a3a")); d.point((7, 0), c("e05a4a"))   # cresta
    d.rectangle((9, 5, 11, 7), c("2a2a2a"))                                 # parche
    d.polygon([(10, 9), (15, 9), (15, 13), (10, 12)], METAL[1])             # hombrera
    d.point((12, 10), METAL[4]); d.point((14, 11), METAL[4])
    d.point((6, 9), c("e6c34a"))                                            # diente de oro
    luz_lateral(img); contorno_suave(img)
    return img

def rictus_combate():
    """Rictus en combate (32x48): grandote, brazos en jarra, hombrera de chatarra."""
    piel = c("b07a50")
    def extra(d):
        d.rectangle((9, 2, 15, 6), oscurecer(piel, 0.85))   # cabeza rapada
        d.rectangle((10, 4, 15, 6), oscurecer(piel, 0.85))
        d.line((14, 13, 15, 13), c("e6c34a"))               # diente de oro
        d.rectangle((7, 30, 15, 32), METAL[3])              # cinturón
        d.point((13, 31), c("e6c34a"))
    def despues(d):
        d.rectangle((15, 0, 17, 6), c("c43a3a")); d.line((16, 0, 16, 5), c("e05a4a"))   # cresta roja
        d.rectangle((18, 8, 21, 11), c("2a2a2a")); d.point((19, 9), METAL[4])            # parche
        d.line((19, 6, 21, 12), c("e0b090"))                                               # cicatriz
        d.polygon([(20, 16), (29, 15), (30, 22), (22, 23)], METAL[1])                      # hombrera de chatarra
        d.line((20, 16, 29, 15), METAL[4]); d.point((24, 18), METAL[4]); d.point((27, 19), METAL[4])
        d.polygon([(26, 14), (28, 9), (30, 15)], OXIDO[2])                                 # púa oxidada
        d.rectangle((25, 34, 28, 40), METAL[0])                                            # llave inglesa colgando
        d.rectangle((24, 40, 29, 42), METAL[2])
    return figura(piel, c("1e1612"), "calvo", OXIDO[1], OXIDO[3], c("3a3328"), c("2a2018"), ojos=c("8a5a2a"), extra=extra, despues=despues)

def generar_personas():
    guardar(mila_mapa(), "personajes/mila_mapa.png")
    guardar(odila_mapa(), "personajes/odila_mapa.png")
    guardar(bruno_mapa(), "personajes/bruno_mapa.png")
    guardar(rosa_mapa(), "personajes/rosa_mapa.png")
    guardar(lia_mapa(), "personajes/lia_mapa.png")
    guardar(tavo_mapa(), "personajes/tavo_mapa.png")
    guardar(vecina_mapa(), "personajes/vecina_mapa.png")
    guardar(rictus_mapa(), "personajes/rictus_mapa.png")
    guardar(rictus_combate(), "personajes/rictus_combate.png")


# ---------------------------------------------------------------------------
# RETRATOS 48x48 de los vecinos
# ---------------------------------------------------------------------------
def retrato_mila():
    piel = c("d8a878")
    def m(d):
        hombros(d, c("4a6a5a"), c("3a5448"))
        d.polygon([(8, 47), (12, 38), (18, 37), (18, 47)], c("7a4e2a"))                # delantal
        d.polygon([(4, 46), (7, 24), (11, 12), (17, 6), (23, 5), (23, 9), (16, 12), (12, 20), (11, 36), (9, 46)], c("c46a2a"))   # pelo largo
        cara_base(d, piel)
        ojo(d, c("4a8a5a"), x=16, y=23)
        ceja(d, c("8a4a1e"), "recta", y=20)
        nariz(d, piel)
        boca(d, piel, "sonrisa")
        d.rectangle((13, 13, 23, 16), c("3a3a40")); d.rectangle((15, 14, 19, 15), c("9ff0ff"))   # gafas de soldador
    def despues(d):
        d.point((30, 27), c("c07a5a")); d.point((17, 27), c("c07a5a"))   # pecas
    return retrato48(c("2f4757"), piel, m, despues)

def retrato_odila():
    piel = c("c08a60")
    def m(d):
        hombros(d, c("7a5a4a"), c("5a4236"))
        cara_base(d, piel, delgada=1)
        ojo(d, c("5a3a24"), x=16, y=24)
        d.line((15, 27, 21, 27), oscurecer(piel, 0.75))   # ojeras
        ceja(d, c("3a2a24"), "triste", y=21)
        nariz(d, piel)
        boca(d, piel, "triste")
        d.polygon([(6, 30), (8, 16), (13, 9), (23, 6), (23, 13), (15, 14), (12, 20), (11, 32)], c("6a4a7a"))   # pañuelo
        d.line((9, 18, 14, 11), c("8a6a9a"))
    return retrato48(c("3e3248"), piel, m)

def retrato_bruno():
    piel = c("b88458")
    def m(d):
        hombros(d, c("3f5f73"), c("2f4757"))
        cara_base(d, piel, quijada=1)
        ojo(d, c("4a5a6a"), x=16, y=24)
        ceja(d, c("d0ccc4"), "recta", y=21)
        nariz(d, piel)
        d.polygon([(13, 29), (23, 30), (23, 40), (17, 39), (13, 34)], c("e0dcd4"))   # barba
        d.line((18, 31, 23, 31), oscurecer(piel, 0.6))
        d.polygon([(11, 16), (12, 10), (23, 8), (23, 16)], c("c98a2a"))             # gorra
        d.polygon([(10, 16), (23, 16), (23, 19), (8, 19)], c("8a5a1e"))
    return retrato48(c("4a3a24"), piel, m)

def retrato_rosa():
    piel = c("d0a07a")
    def m(d):
        hombros(d, c("8a4a5a"), c("6a3a48"))
        cara_base(d, piel, delgada=1)
        ojo(d, c("6a5a4a"), x=16, y=24)
        d.line((14, 27, 16, 28), oscurecer(piel, 0.78)); d.line((13, 21, 15, 20), oscurecer(piel, 0.85))   # arrugas
        ceja(d, c("c8c4bc"), "triste", y=21)
        nariz(d, piel)
        boca(d, piel, "sonrisa")
        d.polygon([(11, 22), (11, 14), (15, 9), (23, 7), (23, 12), (16, 13), (13, 18)], c("e8e4dc"))
        d.ellipse((17, 2, 23, 8), c("e8e4dc"))   # moño
    return retrato48(c("4a3a40"), piel, m)

def retrato_lia():
    piel = c("d8a878")
    def m(d):
        hombros(d, c("c9a24a"), c("a8843a"))
        cara_base(d, piel, delgada=1)
        ojo(d, c("5a3a24"), x=16, y=24)
        ceja(d, c("6a3a24"), "recta", y=21)
        nariz(d, piel)
        boca(d, piel, "sonrisa")
        d.polygon([(11, 24), (11, 14), (15, 9), (23, 8), (23, 12), (16, 13), (13, 18)], c("6a3a24"))
        d.rectangle((6, 22, 10, 34), c("6a3a24")); d.rectangle((7, 34, 9, 36), c("c42e34"))   # coleta con cinta
    def despues(d):
        d.point((16, 29), c("e08a7a")); d.point((31, 29), c("e08a7a"))
    return retrato48(c("5a4a2a"), piel, m, despues)

def retrato_tavo():
    piel = c("b88458")
    def m(d):
        hombros(d, c("6a7a3a"), c("4a5a2a"))
        cara_base(d, piel)
        ojo(d, c("3a2a1a"), x=16, y=24)
        ceja(d, c("2a2220"), "recta", y=21)
        nariz(d, piel)
        boca(d, piel, "sonrisa")
        d.polygon([(11, 22), (10, 12), (15, 7), (23, 6), (23, 11), (17, 10), (14, 14), (13, 19)], c("2a2220"))
        d.point((18, 30), c("4a4238")); d.point((14, 20), c("4a4238"))   # hollín
    return retrato48(c("3a3a2a"), piel, m)

def generar_retratos_bastion():
    for nombre, f in (("mila", retrato_mila), ("odila", retrato_odila), ("bruno", retrato_bruno),
                      ("rosa", retrato_rosa), ("lia", retrato_lia), ("tavo", retrato_tavo)):
        guardar(f(), f"retratos/{nombre}.png")


# ---------------------------------------------------------------------------
# CRIATURAS NUEVAS (64x64, miran a la DERECHA, patas en la fila 60-61)
# ---------------------------------------------------------------------------
TI = OXIDO[1]; TI2 = OXIDO[3]; TI3 = OXIDO[0]; TI_B = OXIDO[4]
def titan_base(d, img):
    P(d, [(12, 46), (22, 46), (23, 61), (11, 61)], METAL[1])                      # pierna de atrás
    P(d, [(34, 44), (46, 44), (48, 61), (33, 61)], TI)                            # pierna de adelante
    P(d, [(6, 44), (8, 22), (16, 12), (40, 10), (52, 18), (54, 40), (48, 50), (10, 50)], TI)   # torso
    P(d, [(24, 4), (40, 3), (44, 12), (38, 18), (26, 18), (22, 12)], METAL[0])   # cabeza
    P(d, [(46, 18), (58, 20), (62, 34), (60, 46), (52, 48), (50, 34)], TI3)       # brazo-martillo
    P(d, [(50, 44), (63, 44), (63, 54), (50, 54)], METAL[1])                      # puño de chatarra
    P(d, [(2, 20), (12, 16), (14, 34), (6, 40), (0, 34)], TI3)                    # brazo de atrás

def titan_det(d, img):
    for (x0, y0, x1, y1, col) in ((12, 20, 26, 32, METAL[0]), (28, 16, 44, 26, OXIDO[2]), (14, 34, 30, 46, METAL[1]),
                                 (32, 30, 46, 44, OXIDO[0])):
        d.rectangle((x0, y0, x1, y1), col)
        d.line((x0, y0, x1, y0), aclarar(col, 1.3))
        for (x, y) in ((x0 + 1, y0 + 1), (x1 - 1, y0 + 1), (x0 + 1, y1 - 1), (x1 - 1, y1 - 1)):
            d.point((x, y), METAL[4])
    d.ellipse((24, 26, 34, 36), c("1e1618")); d.ellipse((26, 28, 32, 34), c("ff7a1a")); d.point((28, 29), c("ffe08a"))   # núcleo
    d.rectangle((34, 8, 40, 11), c("ff5a2a")); d.point((39, 9), c("ffe08a"))   # visor
    d.line((24, 14, 42, 14), METAL[3])
    for (x, y) in ((52, 46), (56, 46), (60, 46), (54, 51), (59, 51)):
        d.point((x, y), METAL[4])
    d.line((8, 22, 4, 16), METAL[3]); d.line((40, 10, 44, 2), METAL[3]); d.point((44, 2), c("ff4a3a"))   # antenas/varillas
    for x in (12, 16, 20, 36, 40, 45):
        d.point((x, 61), METAL[4])

EN = c("4e5660"); EN2 = c("2f353d"); EN_B = c("9aa6b3")
def enjambre_base(d, img):
    rng = random.Random(5)
    # nube de nanobots con forma de remolino
    for k in range(60):
        a = k * 0.55
        r = 4 + k * 0.42
        x = int(32 + math.cos(a) * r * 1.1)
        y = int(34 + math.sin(a) * r * 0.75)
        s = rng.randint(1, 3)
        P(d, [(x, y), (x + s, y - 1), (x + s + 1, y + s), (x, y + s)], rng.choice([EN, EN2, METAL[1], OXIDO[1]]))
    P(d, [(26, 28), (34, 24), (42, 30), (38, 40), (28, 40)], EN)   # núcleo

def enjambre_det(d, img):
    rng = random.Random(9)
    d.ellipse((29, 29, 37, 37), c("1e1618")); d.ellipse((31, 31, 35, 35), c("ff3a2a")); d.point((32, 32), c("ffd0a0"))
    for _ in range(40):
        x, y = rng.randrange(6, 60), rng.randrange(12, 58)
        if img.getpixel((x, y))[3] > 0:
            d.point((x, y), rng.choice([EN_B, c("ff6a3a"), METAL[4]]))
    for (x, y) in ((8, 20), (56, 16), (58, 50), (4, 46), (48, 6)):   # bots sueltos
        d.rectangle((x, y, x + 1, y + 1), EN); d.point((x + 1, y), c("ff6a3a"))

BA = c("2a3a5a"); BA2 = c("1a2440"); BA_L = c("9ff0ff"); BA_P = c("d8e8f0")
def bailarina_base(d, img):
    P(d, [(26, 40), (30, 40), (24, 52), (20, 61), (17, 61), (22, 50)], BA2)        # pierna de atrás (punta)
    P(d, [(32, 40), (36, 40), (44, 50), (50, 52), (49, 55), (40, 52)], BA)         # pierna levantada
    P(d, [(24, 40), (40, 40), (44, 46), (20, 46)], c("4a6a9a"))                    # tutú de cables
    P(d, [(27, 22), (37, 22), (38, 40), (26, 40)], BA)                             # torso
    P(d, [(36, 24), (46, 16), (54, 6), (56, 8), (48, 20), (38, 28)], BA)           # brazo arriba
    P(d, [(27, 24), (16, 26), (6, 22), (6, 25), (16, 29), (27, 28)], BA2)          # brazo extendido
    P(d, [(28, 8), (36, 8), (38, 16), (35, 22), (29, 22), (26, 16)], BA_P)         # cabeza de porcelana
    P(d, [(26, 10), (30, 4), (38, 4), (40, 12), (36, 8), (28, 12)], BA2)           # moño

def bailarina_det(d, img):
    d.rectangle((33, 13, 35, 14), BA_L); d.point((35, 13), c("ffffff"))            # ojo eléctrico
    d.line((34, 18, 36, 18), c("6a7a8a"))
    for pts in (((40, 44), (44, 40), (46, 46)), ((18, 44), (14, 40), (16, 36)), ((54, 6), (58, 2), (60, 8)),
                ((6, 22), (2, 18), (3, 26)), ((30, 42), (32, 48), (35, 44))):
        d.line(pts, BA_L)
        d.point(pts[1], c("ffffff"))
    d.line((29, 26, 35, 26), c("4a6a9a")); d.line((29, 32, 35, 32), c("4a6a9a"))
    d.point((32, 29), BA_L)
    d.point((18, 61), BA_L); d.point((49, 54), BA_L)

GU = c("b07848"); GU2 = c("8a5a34"); GU3 = c("d8a068"); GU_B = c("e8c090")
def gusano_base(d, img):
    # sale de la arena: montículo abajo, cuerpo anillado que se curva hacia la derecha
    P(d, [(0, 61), (6, 52), (20, 48), (40, 50), (56, 54), (63, 61)], ARENA[1])
    segs = [(14, 50, 12), (16, 40, 12), (20, 31, 11), (27, 23, 11), (36, 18, 10), (45, 17, 10)]
    for (x, y, r) in segs:
        d.ellipse((x - r, y - r, x + r, y + r), GU)
    P(d, [(44, 8), (58, 10), (63, 18), (60, 28), (48, 28), (40, 20)], GU2)         # cabeza
    P(d, [(56, 14), (63, 12), (63, 26), (56, 24)], c("5a2a24"))                    # boca abierta

def gusano_det(d, img):
    segs = [(14, 50, 12), (16, 40, 12), (20, 31, 11), (27, 23, 11), (36, 18, 10)]
    for (x, y, r) in segs:
        d.arc((x - r, y - r, x + r, y + r), 200, 340, GU2)
        d.point((x - 3, y - r + 2), GU_B)
    for k in range(5):   # dientes en anillo
        d.polygon([(57, 13 + k * 3), (61, 14 + k * 3), (58, 15 + k * 3)], c("f0e8d8"))
    for (x, y) in ((50, 14), (47, 18), (52, 22)):   # ojitos ciegos
        d.point((x, y), c("ffcf6a"))
    for _ in range(8):
        x = random.randrange(2, 62)
        d.point((x, random.randrange(54, 61)), ARENA[3])
    d.line((2, 58, 10, 56), ARENA[2]); d.line((44, 56, 58, 58), ARENA[2])

def generar_criaturas_bastion():
    g.criatura("titan_de_chatarra", titan_base, titan_det, TI_B)
    g.criatura("enjambre_mecanico", enjambre_base, enjambre_det, EN_B)
    g.criatura("bailarina_electrica", bailarina_base, bailarina_det, BA_L)
    random.seed(4)
    g.criatura("gusano_devorador", gusano_base, gusano_det, GU_B)


# ---------------------------------------------------------------------------
# ICONOS DE LA TIENDA (16x16)
# ---------------------------------------------------------------------------
def icono_jeringa(liquido, tam):
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.polygon([(3, 12), (10, 5), (12, 7), (5, 14)], c("d8e0e8"))
    largo = {1: 2, 2: 4, 3: 6}[tam]
    d.polygon([(4, 12), (4 + largo, 12 - largo), (6 + largo, 14 - largo), (6, 14)], liquido)
    d.line((11, 4, 14, 1), METAL[4]); d.line((9, 4, 13, 8), METAL[2])
    d.line((2, 13, 1, 14), METAL[3])
    sombrear(img); contorno(img)
    return img

def icono_frasco(liquido, grande):
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((6, 1, 9, 4), MADERA[1])
    d.rounded_rectangle((3 if grande else 4, 4, 12 if grande else 11, 14), 2, c("c8e0e8"))
    d.rectangle((4 if grande else 5, 7, 11 if grande else 10, 13), liquido)
    d.point((5, 6), c("ffffff"))
    d.rectangle((6, 9, 9, 10), c("ffffff")); d.rectangle((7, 8, 8, 11), c("ffffff"))   # cruz
    sombrear(img); contorno(img)
    return img

def icono_potenciador(col, doble):
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rounded_rectangle((4, 3, 11, 14), 2, METAL[1])
    d.rectangle((5, 5, 10, 12), col)
    d.polygon([(7, 6), (9, 6), (8, 9), (10, 9), (6, 12), (7, 9), (6, 9)], c("fff4c8"))   # rayo
    if doble:
        d.line((2, 4, 2, 13), col); d.line((13, 4, 13, 13), col)
    sombrear(img); contorno(img)
    return img

def icono_pina():
    img = nuevo(16, 16); d = ImageDraw.Draw(img)
    d.rectangle((3, 5, 12, 14), c("c9c9d1"))
    d.rectangle((3, 7, 12, 12), c("e6c34a"))
    for x in range(4, 12, 3):
        d.point((x, 9), c("8a6a1e")); d.point((x + 1, 10), c("8a6a1e"))
    d.polygon([(6, 5), (5, 1), (8, 3), (11, 0), (10, 5)], c("4f9a24"))
    d.line((3, 5, 12, 5), METAL[4])
    sombrear(img); contorno(img)
    return img

def generar_iconos():
    guardar(icono_jeringa(c("7bd13b"), 1), "objetos/cura_40.png")
    guardar(icono_frasco(c("4fb0e0"), False), "objetos/cura_50.png")
    guardar(icono_frasco(c("e04a5a"), True), "objetos/cura_80.png")
    guardar(icono_potenciador(c("e06a3a"), False), "objetos/potenciador_20.png")
    guardar(icono_potenciador(c("c42e34"), True), "objetos/potenciador_70.png")
    guardar(icono_pina(), "objetos/racion.png")


# ---------------------------------------------------------------------------
# FONDOS DE COMBATE: dunas de óxido y la plaza de Bastión
# ---------------------------------------------------------------------------
W, H = 480, 270

def fondo_dunas():
    """Dunas de óxido: arena naranja, torres de alta tensión enterradas y polvo."""
    rng = random.Random(51)
    hz = 108
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("4a2a2a"), c("8a4a2e"), c("c0703a"), c("e09a52"), c("f0c070")])
    d = ImageDraw.Draw(cielo)
    d.ellipse((380, 30, 412, 62), c("ffe0a0")); d.ellipse((386, 36, 406, 56), c("fff0c8"))
    lejos = nuevo(W, H)
    montanas(lejos, rng, hz - 4, (10, 34), c("a8603a"), rugosidad=0.4)        # dunas lejanas
    montanas(lejos, rng, hz + 2, (4, 18), c("c07a46"), rugosidad=0.35)
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    for (x, alto, inclinada) in ((170, 70, 0), (300, 56, 6), (440, 64, -4)):
        torre_electrica(d, x + inclinada, hz + 4, alto, c("4a3436"))
    d.line((170, hz - 64, 236, hz - 44, 306, hz - 50), c("4a3436")); d.line((306, hz - 50, 372, hz - 34, 436, hz - 58), c("4a3436"))
    for (x, y) in ((236, hz - 44), (372, hz - 34)):
        d.point((x, y), c("9ff0ff")); d.point((x + 1, y + 1), c("ffffff"))   # chispas
    d.polygon([(40, hz + 4), (52, hz - 20), (70, hz - 26), (84, hz - 8), (90, hz + 4)], c("5a3428"))   # casco de barco enterrado
    d.line((52, hz - 20, 70, hz - 26), OXIDO[2])
    suelo = nuevo(W, H)
    def det(d):
        for k in range(14):   # ondas de la arena
            y = hz + 14 + k * 11
            x0 = rng.randrange(-40, 200)
            for x in range(x0, x0 + rng.randint(80, 240), 2):
                d.point((x, y + int(math.sin(x / 9.0) * 2)), c("c98a52"))
        d.polygon([(0, 270), (0, 228), (40, 220), (90, 240), (110, 270)], c("a8603a"))
        d.polygon([(400, 270), (440, 232), (480, 226), (480, 270)], c("a8603a"))
    suelo_combate(suelo, rng, hz, c("c07a46"), c("9a5a32"), c("d89a62"), det)
    nubes = nubes_capa(rng, [(230, 150, 90, 120), (200, 110, 70, 140), (250, 180, 120, 100)], n=12)
    return cielo, nubes, lejos, medio, suelo, []

def fondo_bastion():
    """Dentro de Bastión: contenedores apilados, la trituradora humeando y el buque al fondo."""
    rng = random.Random(63)
    hz = 112
    cielo = nuevo(W, H)
    gradiente(cielo, (0, 0, W, hz + 12), [c("1e1418"), c("4a2420"), c("7a3822"), c("b0582a"), c("d07a34")])
    lejos = nuevo(W, H)
    d = ImageDraw.Draw(lejos)
    # el buque encallado al fondo
    d.polygon([(250, hz - 30), (480, hz - 46), (480, hz - 8), (262, hz - 4)], c("4a2620"))
    for k in range(8):
        x = 266 + k * 26
        d.rectangle((x, hz - 52 - k * 2, x + 22, hz - 32 - k * 2), [c("5a2a22"), c("3a3a44"), c("4a4a2a")][k % 3])
    d.rectangle((440, hz - 90, 470, hz - 50), c("6a6058"))
    skyline(lejos, hz - 4, c("3a2220"), rng, alto=(10, 40), ancho=(20, 40), ventanas=c("d08a3a"), roto=False)
    medio = nuevo(W, H)
    d = ImageDraw.Draw(medio)
    # contenedores apilados (casas)
    cols = [OXIDO[0], c("3f5f73"), OXIDO[2], c("4a5a3a"), OXIDO[1]]
    x = -10
    while x < W:
        w = rng.randint(34, 50)
        pisos = rng.randint(1, 3)
        for p in range(pisos):
            col = rng.choice(cols)
            y1 = hz + 4 - p * 16
            if 150 < x < 330 and p > 0:
                break
            d.rectangle((x, y1 - 16, x + w, y1), col)
            for xx in range(x + 2, x + w, 3):
                d.line((xx, y1 - 15, xx, y1 - 1), tuple(int(v * 0.8) for v in col[:3]) + (255,))
            if rng.random() < 0.5:
                d.rectangle((x + w // 2 - 3, y1 - 11, x + w // 2 + 3, y1 - 6), c("e0a050"))
        x += w + rng.randint(0, 4)
    # la trituradora en el centro
    d.polygon([(190, hz + 4), (190, hz - 40), (200, hz - 50), (270, hz - 50), (280, hz - 40), (280, hz + 4)], c("5a2a1a"))
    d.polygon([(200, hz - 50), (190, hz - 74), (280, hz - 74), (270, hz - 50)], c("3a3a40"))
    for k in range(7):
        d.polygon([(204 + k * 10, hz - 52), (208 + k * 10, hz - 62), (212 + k * 10, hz - 52)], c("6a7380"))
    d.ellipse((268, hz - 46, 274, hz - 40), c("ff4a3a"))
    chimenea(d, 262, hz - 74, 30, c("2a1a18"), ancho=6)
    # estandarte de Rictus
    d.line((120, hz + 4, 120, hz - 70), c("2a1a18"), 2)
    d.polygon([(122, hz - 70), (150, hz - 66), (122, hz - 50)], c("8c2f2f"))
    suelo = nuevo(W, H)
    def det(d):
        for _ in range(30):   # placas de metal remachadas
            x, y = rng.randrange(0, W), rng.randrange(hz + 8, H)
            w, h = rng.randint(12, 30), rng.randint(5, 10)
            d.rectangle((x, y, x + w, y + h), rng.choice([c("5e5a58"), c("4e4a49"), c("6a5040")]))
            d.line((x, y, x + w, y), c("8a8480"))
            d.point((x + 1, y + 2), c("8a8480")); d.point((x + w - 1, y + 2), c("8a8480"))
        d.polygon([(0, 270), (0, 222), (20, 214), (44, 226), (56, 270)], c("4a2a22"))
        d.polygon([(420, 270), (436, 232), (470, 224), (480, 230), (480, 270)], c("4a2a22"))
    suelo_combate(suelo, rng, hz, c("6a5444"), c("4a3a30"), c("8a7058"), det)
    nubes = nubes_capa(rng, [(60, 30, 30, 160), (100, 50, 30, 130), (40, 24, 24, 180)])
    return cielo, nubes, lejos, medio, suelo, [(265, hz - 108)]

g.FONDOS_COMBATE.update({"dunas": fondo_dunas, "bastion": fondo_bastion})


def generar():
    generar_decorados()
    generar_personas()
    generar_retratos_bastion()
    generar_criaturas_bastion()
    generar_iconos()
