"""
Genera la música y los sonidos provisionales de Pan (estilo chiptune / ambiente sencillo).
Requiere Python 3 + numpy, y ffmpeg para convertir a .ogg:
    pip install numpy
    python herramientas/generar_audio.py

Cuando tengas tu propia música o sonidos, reemplaza los .ogg en audio/ con el MISMO nombre.
"""
import os
import subprocess
import wave

import numpy as np

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
AUDIO = os.path.join(RAIZ, "audio")
SR = 32000
rng = np.random.default_rng(7)


def t_de(seg):
    return np.arange(int(seg * SR)) / SR


def nota(m):
    """Número MIDI -> frecuencia (69 = La 440)."""
    return 440.0 * 2 ** ((m - 69) / 12)


def seno(f, seg, fase=0.0):
    return np.sin(2 * np.pi * f * t_de(seg) + fase)


def triangulo(f, seg):
    x = (t_de(seg) * f) % 1.0
    return 4 * np.abs(x - 0.5) - 1


def cuadrada(f, seg, ciclo=0.5):
    return np.where((t_de(seg) * f) % 1.0 < ciclo, 1.0, -1.0)


def ruido(seg):
    return rng.uniform(-1, 1, int(seg * SR))


def env(n, a=0.01, d=0.1, s=0.6, r=0.2):
    """Envolvente ADSR (en segundos) para n muestras."""
    total = n / SR
    a, d, r = min(a, total), min(d, total), min(r, total)
    s_seg = max(0.0, total - a - d - r)
    partes = [np.linspace(0, 1, int(a * SR), endpoint=False),
              np.linspace(1, s, int(d * SR), endpoint=False),
              np.full(int(s_seg * SR), s),
              np.linspace(s, 0, int(r * SR))]
    e = np.concatenate(partes)
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def campana(n, decaimiento=3.0):
    t = np.arange(n) / SR
    return np.exp(-t * decaimiento) * np.minimum(1, t * 400)


def pasabajos(x, corte):
    """Filtro pasabajos de un polo (suaviza el sonido)."""
    a = np.exp(-2 * np.pi * corte / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def eco(x, retardo=0.3, fb=0.35, mezcla=0.35):
    d = int(retardo * SR)
    y = x.copy()
    for i in range(d, len(y)):
        y[i] += y[i - d] * fb
    return x * (1 - mezcla) + y * mezcla


def poner(pista, x, inicio_seg, vol=1.0):
    i = int(inicio_seg * SR)
    fin = min(len(pista), i + len(x))
    pista[i:fin] += x[: fin - i] * vol


def bucle_suave(x, cruce=1.0):
    """Hace que el final empalme con el principio (para que el bucle no tenga corte)."""
    n = int(cruce * SR)
    cabeza, cola = x[:n].copy(), x[-n:]
    rampa = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = cabeza * rampa + cola * (1 - rampa)
    return x


def guardar(x, ruta, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    datos = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    destino = os.path.join(AUDIO, ruta)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    wav = destino + ".wav"
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos.tobytes())
    ogg = destino + ".ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(wav)


# ---------------------------------------------------------------------------
# MÚSICA
# ---------------------------------------------------------------------------
def pad(acorde, seg, corte=900):
    x = np.zeros(int(seg * SR))
    for m in acorde:
        for desafinado in (-0.12, 0.12):
            x += triangulo(nota(m + desafinado), seg)
    x = pasabajos(x, corte)
    return x * env(len(x), a=seg * 0.35, d=0.1, s=1.0, r=seg * 0.4)


def musica_recuerdo():
    """Intro y título: lenta y triste (La menor, 70 bpm)."""
    negra = 60 / 70
    compas = negra * 4
    acordes = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [52, 56, 59]]  # Am F C E
    largo = compas * 2 * len(acordes)
    pista = np.zeros(int(largo * SR) + SR * 2)
    melodia = [76, 74, 72, 71, 72, 69, None, 67, 69, 72, 71, 69, 68, None, 71, 76]
    for i, ac in enumerate(acordes):
        inicio = i * compas * 2
        poner(pista, pad(ac, compas * 2.3), inicio, 0.5)
        poner(pista, seno(nota(ac[0] - 12), compas * 2) * env(int(compas * 2 * SR), 0.3, 0.2, 0.8, 1.0), inicio, 0.5)
    for j, m in enumerate(melodia):
        if m is None:
            continue
        dur = negra * 2
        tono = seno(nota(m), dur) + 0.3 * seno(nota(m) * 2, dur)
        poner(pista, tono * campana(len(tono), 2.2), j * negra * 2, 0.35)
    pista = eco(pista, negra * 0.75, 0.4, 0.4)
    guardar(bucle_suave(pista[: int(largo * SR) + SR], 1.0), "musica/recuerdo", 0.55)


def musica_paramo():
    """Exploración: arpegios tranquilos en Re menor, con aire de western desolado."""
    negra = 60 / 84
    corchea = negra / 2
    progresion = [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52]]  # Dm Bb C A
    compas = negra * 4
    largo = compas * 2 * len(progresion)
    pista = np.zeros(int(largo * SR) + SR * 2)
    for i, ac in enumerate(progresion):
        inicio = i * compas * 2
        poner(pista, pad([m + 12 for m in ac], compas * 2.2, 700), inicio, 0.25)
        for k in range(16):  # arpegio
            m = ac[[0, 1, 2, 1][k % 4]] + (12 if k % 8 >= 4 else 0) + 12
            tono = triangulo(nota(m), corchea * 1.5)
            poner(pista, tono * campana(len(tono), 6), inicio + k * corchea, 0.22)
        for k in range(4):  # bajo
            b = triangulo(nota(ac[0] - 12), negra * 1.8)
            poner(pista, pasabajos(b, 400) * env(len(b), 0.01, 0.2, 0.5, 0.3), inicio + k * negra * 2, 0.6)
    lead = [74, None, 72, 69, None, 67, 69, None, 70, None, 69, 65, None, 64, 61, None]
    for j, m in enumerate(lead):
        if m is not None:
            d = negra * 1.9
            vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t_de(d))
            tono = cuadrada(nota(m), d, 0.25) * 0.5 + triangulo(nota(m), d) * 0.5
            poner(pista, pasabajos(tono, 2200) * env(len(tono), 0.05, 0.2, 0.6, 0.5) * vib, j * negra * 2, 0.16)
    pista = eco(pista, corchea * 3, 0.3, 0.3)
    guardar(bucle_suave(pista[: int(largo * SR) + SR], 0.5), "musica/paramo", 0.55)


def bombo(seg=0.25):
    t = t_de(seg)
    f = 120 * np.exp(-t * 18) + 40
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 10)


def caja(seg=0.18):
    return pasabajos(ruido(seg), 5000) * np.exp(-t_de(seg) * 22) + 0.3 * seno(190, seg) * np.exp(-t_de(seg) * 30)


def platillo(seg=0.06):
    x = ruido(seg)
    return (x - pasabajos(x, 6000)) * np.exp(-t_de(seg) * 60)


def musica_combate():
    """Combate: chiptune rápido (150 bpm) en La menor."""
    negra = 60 / 150
    corchea = negra / 2
    semi = negra / 4
    progresion = [57, 53, 55, 52]  # A F G E (raíces)
    compas = negra * 4
    largo = compas * 2 * len(progresion)
    pista = np.zeros(int(largo * SR) + SR)
    escalas = {57: [57, 60, 64, 69], 53: [53, 57, 60, 65], 55: [55, 59, 62, 67], 52: [52, 56, 59, 64]}
    for i, raiz in enumerate(progresion):
        inicio = i * compas * 2
        for k in range(16):  # bajo en corcheas, octavando
            m = raiz - 24 + (12 if k % 2 else 0)
            b = cuadrada(nota(m), corchea * 0.9, 0.5)
            poner(pista, pasabajos(b, 900) * env(len(b), 0.002, 0.05, 0.7, 0.03), inicio + k * corchea, 0.45)
        for k in range(32):  # arpegio en semicorcheas
            m = escalas[raiz][k % 4] + 12
            a = cuadrada(nota(m), semi * 0.8, 0.125)
            poner(pista, a * env(len(a), 0.002, 0.04, 0.4, 0.02), inicio + k * semi, 0.12)
        for k in range(8):  # batería
            poner(pista, platillo(), inicio + k * negra + corchea, 0.25)
            if k % 2 == 0:
                poner(pista, bombo(), inicio + k * negra, 0.9)
            else:
                poner(pista, caja(), inicio + k * negra, 0.5)
    melodia = [69, 72, 76, 74, 72, 71, 72, 69, 65, 69, 72, 71, 69, 67, 64, 68]
    for j, m in enumerate(melodia):
        d = negra * 1.9
        tono = cuadrada(nota(m), d, 0.5) * (1 + 0.003 * np.sin(2 * np.pi * 6 * t_de(d)))
        poner(pista, pasabajos(tono, 3000) * env(len(tono), 0.01, 0.1, 0.6, 0.15), j * negra * 2, 0.18)
    guardar(pista[: int(largo * SR)], "musica/combate", 0.6)


# ---------------------------------------------------------------------------
# AMBIENTE (bucles)
# ---------------------------------------------------------------------------
def ambiente_viento():
    seg = 14
    x = pasabajos(ruido(seg), 500)
    rafagas = 0.55 + 0.45 * np.sin(2 * np.pi * t_de(seg) / 7.0) * np.sin(2 * np.pi * t_de(seg) / 3.1 + 1)
    silbido = pasabajos(ruido(seg), 1400) - pasabajos(ruido(seg), 900)
    x = x * rafagas + silbido * 0.3 * np.clip(rafagas - 0.6, 0, 1)
    guardar(bucle_suave(x, 2.0), "ambiente/viento", 0.5)


def ambiente_bunker():
    seg = 10
    t = t_de(seg)
    zumbido = 0.6 * np.sin(2 * np.pi * 50 * t) + 0.3 * np.sin(2 * np.pi * 100 * t) + 0.1 * np.sin(2 * np.pi * 150 * t)
    zumbido *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.3 * t)
    aire = pasabajos(ruido(seg), 300) * 0.6
    x = zumbido * 0.4 + aire
    for inicio in (1.7, 6.3):  # gotas
        g = seno(900, 0.12) * np.exp(-t_de(0.12) * 40) * 0.5
        g[: int(0.08 * SR)] += seno(1400, 0.08) * np.exp(-t_de(0.08) * 60)
        poner(x, g, inicio, 0.5)
    guardar(bucle_suave(x, 1.5), "ambiente/bunker", 0.45)


# ---------------------------------------------------------------------------
# EFECTOS
# ---------------------------------------------------------------------------
def sfx():
    # golpe normal y fuerte
    g = pasabajos(ruido(0.16), 2500) * np.exp(-t_de(0.16) * 28) + bombo(0.16) * 0.8
    guardar(g, "sfx/golpe", 0.8)
    gf = pasabajos(ruido(0.3), 1800) * np.exp(-t_de(0.3) * 14) + bombo(0.3) * 1.2 + cuadrada(70, 0.3) * np.exp(-t_de(0.3) * 20) * 0.3
    guardar(gf, "sfx/golpe_fuerte", 0.9)
    # lanzar (silbido que cruza)
    t = t_de(0.28)
    w = ruido(0.28)
    w = pasabajos(w, 3000) - pasabajos(w, 800)
    guardar(w * np.sin(np.pi * t / 0.28) ** 2, "sfx/lanzar", 0.6)
    # captura: arpegio que sube
    x = np.zeros(int(0.7 * SR))
    for i, m in enumerate([72, 76, 79, 84, 88]):
        n = cuadrada(nota(m), 0.2, 0.25)
        poner(x, n * env(len(n), 0.002, 0.05, 0.5, 0.1), i * 0.08, 0.5)
    guardar(eco(x, 0.12, 0.3, 0.3), "sfx/captura", 0.6)
    # fallo / la carta se rompe
    x = np.zeros(int(0.45 * SR))
    for i, m in enumerate([67, 63, 58]):
        n = cuadrada(nota(m), 0.14, 0.5)
        poner(x, n * env(len(n), 0.002, 0.05, 0.5, 0.05), i * 0.12, 0.5)
    guardar(x, "sfx/fallo", 0.5)
    # aparecer (la criatura sale de la carta)
    t = t_de(0.35)
    f = 500 + 1500 * t / 0.35
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6) + pasabajos(ruido(0.35), 4000) * np.exp(-t * 12) * 0.4
    guardar(x, "sfx/aparecer", 0.5)
    # caer (derrotado)
    t = t_de(0.5)
    f = 400 * np.exp(-t * 4) + 60
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * np.exp(-t * 4) * 0.5 + bombo(0.5) * 0.8
    guardar(pasabajos(x, 2000), "sfx/caer", 0.6)
    # botón
    b = cuadrada(1200, 0.04, 0.5) * np.exp(-t_de(0.04) * 90)
    guardar(b, "sfx/boton", 0.35)
    # letra del diálogo (muy suave)
    d = triangulo(520, 0.035) * np.exp(-t_de(0.035) * 80)
    guardar(d, "sfx/dialogo", 0.25)
    # escotilla / puerta de metal
    t = t_de(0.7)
    x = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((180, 6), (431, 9), (797, 12), (1230, 16)))
    x += pasabajos(ruido(0.7), 1500) * np.exp(-t * 25)
    guardar(x, "sfx/metal", 0.6)
    # objeto obtenido
    x = np.zeros(int(0.6 * SR))
    for i, m in enumerate([79, 84, 88]):
        n = triangulo(nota(m), 0.3) + 0.4 * seno(nota(m) * 2, 0.3)
        poner(x, n * campana(len(n), 7), i * 0.09, 0.5)
    guardar(x, "sfx/objeto", 0.5)
    # aviso "!" / encuentro
    x = np.zeros(int(0.35 * SR))
    for i, m in enumerate([76, 83]):
        n = cuadrada(nota(m), 0.12, 0.25)
        poner(x, n * env(len(n), 0.002, 0.03, 0.6, 0.04), i * 0.1, 0.5)
    guardar(x, "sfx/alerta", 0.45)


# ---------------------------------------------------------------------------
# CIUDAD 1: BASTIÓN DE ÓXIDO
# (usan su propio generador aleatorio para no cambiar los sonidos de arriba)
# ---------------------------------------------------------------------------
rng_b = np.random.default_rng(1101)


def ruido_b(seg):
    return rng_b.uniform(-1, 1, int(seg * SR))


def golpe_metal(seg=0.35, f=420):
    """Un golpe sobre metal oxidado (para el ritmo de la ciudad)."""
    t = t_de(seg)
    x = sum(np.sin(2 * np.pi * f * k * t) * np.exp(-t * (14 + k * 6)) / k for k in (1, 2.76, 5.4))
    return x + pasabajos(ruido_b(seg), 3000) * np.exp(-t * 40) * 0.4


def musica_bastion():
    """Bastión de Óxido: ritmo cansado de fábrica (la trituradora) y una melodía triste en Mi menor."""
    negra = 60 / 92
    corchea = negra / 2
    progresion = [[52, 55, 59], [48, 52, 55], [50, 54, 57], [47, 51, 54]]  # Em C D B
    compas = negra * 4
    largo = compas * 2 * len(progresion)
    pista = np.zeros(int(largo * SR) + SR * 2)
    for i, ac in enumerate(progresion):
        inicio = i * compas * 2
        poner(pista, pad(ac, compas * 2.2, 600), inicio, 0.22)
        for k in range(8):  # bajo pesado en negras
            b = triangulo(nota(ac[0] - 12), negra * 0.9)
            poner(pista, pasabajos(b, 350) * env(len(b), 0.005, 0.15, 0.4, 0.2), inicio + k * negra, 0.55)
        for k in range(16):  # la trituradora: golpes de metal
            if k % 4 in (0, 3):
                poner(pista, pasabajos(golpe_metal(0.3, 300 if k % 4 == 0 else 460), 2500), inicio + k * corchea, 0.22)
            poner(pista, platillo(0.04), inicio + k * corchea, 0.08)
    lead = [64, 67, 71, 69, 67, 66, 64, None, 60, 64, 67, 66, 62, 63, 66, None]
    for j, m in enumerate(lead):
        if m is not None:
            d = negra * 1.9
            vib = 1 + 0.005 * np.sin(2 * np.pi * 4.5 * t_de(d))
            tono = triangulo(nota(m + 12), d) * 0.7 + cuadrada(nota(m + 12), d, 0.25) * 0.3
            poner(pista, pasabajos(tono, 1800) * env(len(tono), 0.06, 0.2, 0.55, 0.5) * vib, j * negra * 2, 0.15)
    pista = eco(pista, corchea * 3, 0.25, 0.25)
    guardar(bucle_suave(pista[: int(largo * SR) + SR], 0.5), "musica/bastion", 0.55)


def musica_jefe():
    """Combate contra un comandante: más rápido y pesado que el combate normal (Re menor, 164 bpm)."""
    negra = 60 / 164
    corchea = negra / 2
    semi = negra / 4
    progresion = [50, 46, 48, 45, 50, 46, 43, 45]  # Dm Bb C A Dm Bb G A
    compas = negra * 4
    largo = compas * len(progresion)
    pista = np.zeros(int(largo * SR) + SR)
    for i, raiz in enumerate(progresion):
        inicio = i * compas
        for k in range(8):  # bajo galopante
            m = raiz - 12 + (7 if k % 4 == 3 else 0)
            b = cuadrada(nota(m), corchea * 0.85, 0.5) + 0.5 * triangulo(nota(m - 12), corchea * 0.85)
            poner(pista, pasabajos(b, 800) * env(len(b), 0.002, 0.04, 0.7, 0.03), inicio + k * corchea, 0.5)
        tercera = 3 if raiz in (50, 43) else (4 if raiz in (46, 48) else 4)
        for k in range(16):
            m = raiz + 12 + [0, tercera, 7, 12][k % 4]
            a = cuadrada(nota(m), semi * 0.8, 0.125)
            poner(pista, a * env(len(a), 0.002, 0.03, 0.4, 0.02), inicio + k * semi, 0.1)
        for k in range(4):
            poner(pista, bombo(), inicio + k * negra, 0.9)
            if k % 2:
                poner(pista, bombo(), inicio + k * negra + corchea * 1.5, 0.4)
                poner(pista, caja(), inicio + k * negra, 0.55)
                poner(pista, golpe_metal(0.2, 520), inicio + k * negra, 0.15)
            poner(pista, platillo(), inicio + k * negra + corchea, 0.25)
    melodia = [74, 77, 76, 74, 73, 69, 70, 73, 74, 81, 79, 77, 76, 74, 73, 76]
    for j, m in enumerate(melodia):
        d = negra * 1.9
        tono = cuadrada(nota(m), d, 0.5) * (1 + 0.004 * np.sin(2 * np.pi * 6 * t_de(d)))
        poner(pista, pasabajos(tono, 2600) * env(len(tono), 0.01, 0.1, 0.6, 0.15), j * negra * 2, 0.17)
    guardar(pista[: int(largo * SR)], "musica/jefe", 0.62)


def ambiente_ciudad():
    """Bastión: viento suave, la trituradora a lo lejos y algún golpe de metal."""
    seg = 12
    t = t_de(seg)
    viento = pasabajos(ruido_b(seg), 450) * (0.6 + 0.3 * np.sin(2 * np.pi * t / 6.0))
    motor = pasabajos(np.sin(2 * np.pi * 38 * t) + 0.5 * cuadrada(19, seg, 0.3), 200)
    motor *= 0.7 + 0.3 * (np.sin(2 * np.pi * t * 1.5) > 0)
    x = viento + motor * 0.35
    for inicio, f in ((1.1, 380), (4.7, 520), (8.2, 300), (10.1, 460)):
        poner(x, pasabajos(golpe_metal(0.4, f), 1500), inicio, 0.25)
    guardar(bucle_suave(x, 1.5), "ambiente/ciudad", 0.45)


def ambiente_tormenta():
    """Tormenta de óxido: viento fuerte con arena que golpea el metal."""
    seg = 12
    t = t_de(seg)
    base = pasabajos(ruido_b(seg), 900)
    rafagas = 0.7 + 0.3 * np.sin(2 * np.pi * t / 3.3) * np.sin(2 * np.pi * t / 1.7 + 2)
    silbido = pasabajos(ruido_b(seg), 2200) - pasabajos(ruido_b(seg), 1300)
    arena = ruido_b(seg) - pasabajos(ruido_b(seg), 4000)
    arena *= (rng_b.uniform(0, 1, len(arena)) > 0.6) * 0.25
    x = base * rafagas + silbido * 0.5 * rafagas + arena
    guardar(bucle_suave(x, 2.0), "ambiente/tormenta", 0.55)


def sfx_aplausos():
    """Una multitud aplaudiendo y celebrando (dura unos 2.6 segundos)."""
    seg = 2.6
    x = np.zeros(int(seg * SR))
    for _ in range(260):  # cada aplauso es un chasquido de ruido filtrado
        d = 0.05
        c = ruido_b(d)
        c = (c - pasabajos(c, rng_b.uniform(700, 1400))) * np.exp(-t_de(d) * rng_b.uniform(70, 110))
        poner(x, c, rng_b.uniform(0, seg - d), rng_b.uniform(0.4, 1.0))
    murmullo = pasabajos(ruido_b(seg), 600) * 0.15
    x = (x + murmullo) * env(len(x), 0.15, 0.2, 0.9, 0.7)
    guardar(x, "sfx/aplausos", 0.6)


def bastion():
    musica_bastion()
    musica_jefe()
    ambiente_ciudad()
    ambiente_tormenta()
    sfx_aplausos()


# ---------------------------------------------------------------------------
# CIUDAD 2: EL SUMIDERO (túneles del metro, agua envenenada, la Dra. Vesper)
# ---------------------------------------------------------------------------
rng_s = np.random.default_rng(2202)


def ruido_s(seg):
    return rng_s.uniform(-1, 1, int(seg * SR))


def gota(f=1300, seg=0.25):
    """Una gota que cae en un charco (pling con un poquito de tono que sube)."""
    t = t_de(seg)
    fr = f * (1 + 0.6 * np.exp(-t * 30))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 22)


def burbuja_sonido(seg=0.18, f=260):
    """Burbuja que revienta en el lodo (tono que sube rápido)."""
    t = t_de(seg)
    fr = f * (1 + 2.5 * t / seg)
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.sin(np.pi * t / seg) ** 2


def musica_sumidero():
    """El Sumidero: lenta y húmeda. Arpegios en Do# menor frigio, bajo profundo y gotas (72 bpm)."""
    negra = 60 / 72
    progresion = [[49, 52, 56], [50, 53, 57], [49, 52, 56], [45, 49, 52], [47, 50, 54], [50, 53, 57]]  # C#m D C#m A Bm D
    compas = negra * 4
    largo = compas * len(progresion) * 2
    pista = np.zeros(int(largo * SR) + SR * 2)
    for i, ac in enumerate(progresion * 2):
        inicio = i * compas
        poner(pista, pad(ac, compas * 1.3, 500), inicio, 0.2)
        b = seno(nota(ac[0] - 24), compas * 0.95) + 0.3 * triangulo(nota(ac[0] - 12), compas * 0.95)
        poner(pista, pasabajos(b, 220) * env(len(b), 0.3, 0.4, 0.6, 0.6), inicio, 0.5)
        for k in range(8):  # arpegio de campanitas (como agua que gotea)
            m = ac[[0, 1, 2, 1, 2, 0, 1, 2][k]] + 24
            n = triangulo(nota(m), negra * 0.6) + 0.3 * seno(nota(m) * 3, negra * 0.6)
            poner(pista, n * campana(len(n), 6), inicio + k * negra / 2, 0.07 if k % 2 else 0.1)
    for inicio in np.arange(0.4, largo - 1, 2.3):  # gotas sueltas
        poner(pista, gota(rng_s.uniform(1100, 1900)), inicio + rng_s.uniform(0, 0.8), 0.12)
    melodia = [None, 68, 69, 68, 64, None, 61, 62, None, 64, 66, 64, 62, 61, None, None,
               None, 73, 74, 73, 69, None, 68, 66, None, 64, 62, 61, 62, 64, 61, None]
    for j, m in enumerate(melodia):
        if m is not None:
            d = negra * 1.4
            vib = 1 + 0.006 * np.sin(2 * np.pi * 5 * t_de(d))
            tono = seno(nota(m), d) * 0.6 + triangulo(nota(m), d) * 0.4
            poner(pista, pasabajos(tono * vib, 1500) * env(len(tono), 0.08, 0.2, 0.5, 0.5), j * negra * 1.5, 0.16)
    pista = eco(pista, negra * 0.75, 0.35, 0.35)
    guardar(bucle_suave(pista[: int(largo * SR) + SR], 0.8), "musica/sumidero", 0.55)


def musica_vesper():
    """Combate contra la Dra. Vesper: inquietante y frío. Tritono, compás que tropieza y burbujas (148 bpm)."""
    negra = 60 / 148
    corchea = negra / 2
    semi = negra / 4
    progresion = [45, 45, 51, 50, 45, 45, 48, 44]  # Am Am Eb(tritono) D Am Am C G#
    compas = negra * 4
    largo = compas * len(progresion)
    pista = np.zeros(int(largo * SR) + SR)
    for i, raiz in enumerate(progresion):
        inicio = i * compas
        for k in range(8):  # bajo con un golpe "cojo" (3+3+2)
            if k in (0, 3, 6):
                b = cuadrada(nota(raiz - 12), corchea * (2.7 if k < 6 else 1.8), 0.3)
                poner(pista, pasabajos(b, 700) * env(len(b), 0.002, 0.05, 0.6, 0.05), inicio + k * corchea, 0.5)
        for k in range(16):  # arpegio frío de laboratorio
            m = raiz + 24 + [0, 3, 6, 10][k % 4]
            a = triangulo(nota(m), semi * 0.8) + 0.3 * cuadrada(nota(m), semi * 0.8, 0.125)
            poner(pista, a * env(len(a), 0.002, 0.03, 0.3, 0.02), inicio + k * semi, 0.09)
        for k in range(8):
            if k in (0, 3, 6):
                poner(pista, bombo(), inicio + k * corchea, 0.85)
            if k in (2, 6):
                poner(pista, caja(), inicio + k * corchea, 0.45)
            poner(pista, platillo(0.03), inicio + k * corchea, 0.15)
        poner(pista, burbuja_sonido(0.2, rng_s.uniform(200, 320)), inicio + corchea * 5, 0.25)
    melodia = [69, 72, 75, 74, 69, None, 68, 69, 72, 75, 78, 77, 75, 74, 72, 68]
    for j, m in enumerate(melodia):
        if m is not None:
            d = negra * 1.8
            vib = 1 + 0.01 * np.sin(2 * np.pi * 7 * t_de(d))
            tono = cuadrada(nota(m), d, 0.25) * 0.5 + seno(nota(m) * 1.01, d) * 0.5
            poner(pista, pasabajos(tono * vib, 2200) * env(len(tono), 0.02, 0.1, 0.55, 0.2), j * negra * 2, 0.16)
    guardar(pista[: int(largo * SR)], "musica/vesper", 0.62)


def ambiente_subterraneo():
    """Túneles del metro: zumbido grave, lodo que burbujea, gotas y un tren fantasma muy lejos."""
    seg = 14
    t = t_de(seg)
    eco_tunel = pasabajos(ruido_s(seg), 180) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 9.0))
    zumbido = 0.5 * np.sin(2 * np.pi * 55 * t) + 0.25 * np.sin(2 * np.pi * 82.5 * t)
    zumbido *= 0.6 + 0.4 * np.sin(2 * np.pi * t / 5.0) ** 2
    x = eco_tunel + zumbido * 0.15
    for inicio in np.arange(0.3, seg - 0.5, 0.9):
        if rng_s.uniform() < 0.6:
            poner(x, gota(rng_s.uniform(900, 1800)), inicio + rng_s.uniform(0, 0.5), rng_s.uniform(0.08, 0.2))
    for inicio in np.arange(0.5, seg - 0.5, 0.7):
        if rng_s.uniform() < 0.5:
            poner(x, burbuja_sonido(rng_s.uniform(0.1, 0.22), rng_s.uniform(120, 260)), inicio, 0.12)
    x = eco(x, 0.21, 0.3, 0.3)
    guardar(bucle_suave(x, 1.5), "ambiente/subterraneo", 0.5)


def sfx_sumidero():
    # tos (dos golpes de aire áspero)
    x = np.zeros(int(0.6 * SR))
    for i, f in enumerate((900, 700)):
        c = pasabajos(ruido_s(0.18), f * 2) - pasabajos(ruido_s(0.18), f * 0.5)
        c += 0.3 * cuadrada(140 - i * 20, 0.18, 0.3)
        poner(x, c * env(int(0.18 * SR), 0.005, 0.04, 0.5, 0.1), i * 0.24, 0.8 - i * 0.2)
    guardar(x, "sfx/tos", 0.5)
    # gota de ácido que sisea al caer
    g = np.zeros(int(0.5 * SR))
    poner(g, gota(1500, 0.2), 0, 0.8)
    siseo = (ruido_s(0.4) - pasabajos(ruido_s(0.4), 3000)) * np.exp(-t_de(0.4) * 8)
    poner(g, siseo, 0.05, 0.35)
    guardar(g, "sfx/goteo", 0.5)
    # burbuja de lodo
    x = np.zeros(int(0.4 * SR))
    poner(x, burbuja_sonido(0.16, 220), 0, 1.0)
    poner(x, burbuja_sonido(0.12, 300), 0.15, 0.6)
    guardar(x, "sfx/burbuja", 0.5)
    # humo / gas que sale (un "pfff")
    t = t_de(0.7)
    h = (pasabajos(ruido_s(0.7), 2500) - pasabajos(ruido_s(0.7), 400)) * np.exp(-t * 4) * np.minimum(1, t * 30)
    guardar(h, "sfx/humo", 0.5)
    # puerta del laboratorio (neumática: siseo + golpe suave)
    t = t_de(0.6)
    p = (ruido_s(0.6) - pasabajos(ruido_s(0.6), 2000)) * np.exp(-t * 6) * 0.6
    poner(p, bombo(0.2) * 0.6, 0.35)
    poner(p, seno(220, 0.25) * np.exp(-t_de(0.25) * 18) * 0.3, 0.35)
    guardar(p, "sfx/puerta", 0.5)
    # curar (destellos que suben)
    x = np.zeros(int(0.6 * SR))
    for i, m in enumerate([76, 81, 85, 88]):
        n = seno(nota(m), 0.3) + 0.3 * seno(nota(m) * 2, 0.3)
        poner(x, n * campana(len(n), 9), i * 0.07, 0.4)
    guardar(eco(x, 0.09, 0.3, 0.3), "sfx/curar", 0.5)
    # quemar (fuego que prende)
    t = t_de(0.6)
    q = pasabajos(ruido_s(0.6), 1800) * (np.minimum(1, t * 12) * np.exp(-t * 3))
    q += (rng_s.uniform(0, 1, len(q)) > 0.995) * rng_s.uniform(-1, 1, len(q)) * 0.8  # chispas
    guardar(q, "sfx/quemar", 0.55)


def sumidero():
    musica_sumidero()
    musica_vesper()
    ambiente_subterraneo()
    sfx_sumidero()


if __name__ == "__main__":
    musica_recuerdo()
    musica_paramo()
    musica_combate()
    ambiente_viento()
    ambiente_bunker()
    sfx()
    bastion()
    sumidero()
    print("Audio listo en", AUDIO)
