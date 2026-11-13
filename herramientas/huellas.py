"""
Guarda en datos/huellas.json la "huella" (md5) de las escenas, scripts y recursos.
El juego la usa en su autodiagnóstico: si algo falla al iniciar, te dice qué archivos
son distintos a los del repositorio (por ejemplo, si Godot guardó encima una versión vieja).

Correr después de cambiar escenas o scripts:  python herramientas/huellas.py
"""
import hashlib
import json
import os

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CARPETAS = ["scripts", "escenas", "arte"]
EXTENSIONES = (".gd", ".tscn", ".tres", ".gdshader")

huellas = {}
for carpeta in CARPETAS:
    for raiz, _, archivos in os.walk(os.path.join(RAIZ, carpeta)):
        for nombre in sorted(archivos):
            if nombre.endswith(EXTENSIONES):
                ruta = os.path.join(raiz, nombre)
                rel = "res://" + os.path.relpath(ruta, RAIZ).replace(os.sep, "/")
                with open(ruta, "rb") as f:
                    huellas[rel] = hashlib.md5(f.read()).hexdigest()

with open(os.path.join(RAIZ, "datos", "huellas.json"), "w", encoding="utf-8") as f:
    json.dump(huellas, f, indent=1, sort_keys=True)
print(len(huellas), "huellas guardadas en datos/huellas.json")
