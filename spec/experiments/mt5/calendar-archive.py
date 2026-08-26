#!/usr/bin/env python3
"""
calendar-archive.py — acumulador append-only del calendario nativo de MT5.

POR QUE EXISTE
--------------
TRADER-CALENDAR.csv es un SNAPSHOT, no una serie. El EA lo reescribe entero
cada 5 minutos (FileOpen con FILE_WRITE) y solo cubre -48h..+96h. SPEC-FUND-001
§5 pide una ventana movil de 10 DIAS HABILES para M3.

Esa ventana no existe en el snapshot y nunca va a existir por mas que el
detector corra perfecto: no es una caida, es el diseno. Los reportes del
2026-08-24, 25 y 26 puntuaron M3 con 0, 2 y 1 dia de datos respectivamente,
y las tres veces se leyo como "el detector fallo". Solo una de esas veces
fue cierto.

Este script convierte la serie de snapshots en el historico que la regla pide.

REGLAS DE INTEGRIDAD (importan mas que el codigo)
-------------------------------------------------
  1. Nunca se degrada has_actual=YES a NO. Si el proveedor deja de mandar el
     actual de un evento viejo, el que ya se observo queda. Es la misma
     familia de error que ticks=0 (FINDINGS-001 §4.7): un dato ausente leido
     como ausencia de dato borra evidencia real.
  2. El 'actual' que puntua es el PRIMERO observado, no el ultimo. Es el que
     movio el mercado. Las revisiones posteriores se guardan en actual_latest
     y se cuentan en 'revisions', pero no pisan al original.
  3. Idempotente. Correrlo mil veces sobre el mismo snapshot no cambia nada.
  4. Si el snapshot falta o esta vencido, NO escribe y lo declara por stderr
     con exit code 0. Un archivo sin novedad es un resultado honesto; rellenar
     el hueco no lo es.
  5. Solo agrega y enriquece. Nunca borra una fila del historico.

USO
---
    calendar-archive.py            merge del snapshot actual al historico
    calendar-archive.py --status   informe de cobertura, no escribe nada
    calendar-archive.py --deploy   copia este script a la ruta que corre el
                                   LaunchAgent (ver STAGING_DIR). Correlo
                                   despues de editar el archivo del repo, que
                                   es la copia versionada pero NO la que corre.
"""

import csv
import os
import sys
from datetime import datetime, timedelta

# MT5 corre bajo Wine y el perfil de usuario NO es estable: el terminal escribe
# unas veces bajo drive_c/users/nachogm y otras bajo drive_c/users/user. El
# 2026-08-26 el detector estaba sano volcando cada 5 min en 'user', mientras el
# reporte MORNING leia 'nachogm' —congelado desde el 25 a las 19:36— y concluyo
# que el detector se habia caido con la Mac dormida. No se habia caido: la ruta
# apuntaba al perfil equivocado.
#
# Por eso aca NO se fija una ruta: se eligen todas las candidatas y gana la mas
# fresca por dumped_at. Si manana Wine cambia de perfil otra vez, esto no se
# entera y sigue funcionando.
WINE_ROOT = os.path.expanduser(
    "~/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/users"
)
COMMON = "AppData/Roaming/MetaQuotes/Terminal/Common/Files"
PROFILES = ("user", "nachogm")

SNAPSHOTS = [os.path.join(WINE_ROOT, u, COMMON, "TRADER-CALENDAR.csv")
             for u in PROFILES]

# Volcado ancho de una sola corrida (TRADER-CALENDAR-BACKFILL.mq5), para
# rellenar los dias que el snapshot de -48h nunca alcanzo. Se mergea igual que
# el snapshot y con las mismas reglas, asi que no puede pisar un actual ya
# observado. Si el archivo no esta, no pasa nada.
BACKFILLS = [os.path.join(WINE_ROOT, u, COMMON,
                          "TRADER-CALENDAR-BACKFILL.csv")
             for u in PROFILES]
# DOS UBICACIONES, y no es por gusto.
#
# El repo vive en ~/Desktop, que macOS protege con TCC. Un LaunchAgent corre
# fuera de la sesion grafica y NO tiene ese permiso: el primer intento de
# agendar esto fallo con "Operation not permitted" al abrir el script en el
# Desktop. Pedir Full Disk Access para python3 seria abrir mucho mas de lo que
# esta tarea necesita.
#
# Entonces el acumulador canonico vive en Application Support —que no esta
# protegido y el agente si puede escribir— y el repo recibe un ESPEJO cada vez
# que corre alguien que si tiene permiso (una sesion de Claude, la tarea
# diaria). Si el espejo falla, no es un error: el dato ya esta a salvo.
STAGING_DIR = os.path.expanduser("~/Library/Application Support/trader-calendar")
ARCHIVE = os.path.join(STAGING_DIR, "calendar-archive.csv")
MIRROR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "calendar-archive.csv")

FIELDS = [
    "event_time_server", "currency", "importance", "event",
    "actual", "actual_seen_at", "actual_latest", "revisions",
    "forecast", "previous", "has_actual",
    "first_seen", "last_seen",
]

TS = "%Y.%m.%d %H:%M"


def key(row):
    """Un evento se identifica por cuando ocurre, que moneda y su nombre.
    El nombre entra porque un mismo horario trae varios releases (las tres
    lecturas del Ifo, el nivel y el m/m de New Home Sales)."""
    return (row["event_time_server"], row["currency"], row["event"])


def parse_ts(s):
    for fmt in (TS + ":%S", TS):
        try:
            return datetime.strptime(s.strip(), fmt)
        except (ValueError, AttributeError):
            continue
    return None


def load_archive():
    if not os.path.exists(ARCHIVE):
        return {}
    with open(ARCHIVE, newline="", encoding="utf-8") as f:
        return {key(r): r for r in csv.DictReader(f)}


def read_snapshot(path):
    if not os.path.exists(path):
        return None
    with open(path, newline="", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if r.get("event_time_server")]
    return rows or None


def load_snapshot():
    """Gana el perfil de Wine con el dumped_at mas reciente, no un path fijo."""
    best, best_rows, best_ts = None, None, None
    for path in SNAPSHOTS:
        rows = read_snapshot(path)
        if not rows:
            continue
        ts = parse_ts(max((r.get("dumped_at") or "").strip() for r in rows))
        if ts and (best_ts is None or ts > best_ts):
            best, best_rows, best_ts = path, rows, ts

    if not best_rows:
        return None, None, "ningun snapshot legible en los perfiles de Wine"
    return best_rows, best, None


def merge(archive, rows):
    """Devuelve (nuevos, actuals_nuevos, revisiones). Muta archive."""
    new = actuals = revisions = 0
    for r in rows:
        k = key(r)
        dumped = r.get("dumped_at", "").strip()
        incoming_actual = (r.get("actual") or "").strip()
        incoming_has = (r.get("has_actual") or "NO").strip().upper()

        if k not in archive:
            archive[k] = {
                "event_time_server": r["event_time_server"],
                "currency": r["currency"],
                "importance": r["importance"],
                "event": r["event"],
                "actual": incoming_actual,
                "actual_seen_at": dumped if incoming_has == "YES" else "",
                "actual_latest": incoming_actual,
                "revisions": "0",
                "forecast": (r.get("forecast") or "").strip(),
                "previous": (r.get("previous") or "").strip(),
                "has_actual": incoming_has,
                "first_seen": dumped,
                "last_seen": dumped,
            }
            new += 1
            if incoming_has == "YES":
                actuals += 1
            continue

        a = archive[k]
        a["last_seen"] = dumped

        # forecast/previous se completan si estaban vacios; el proveedor a veces
        # publica el forecast tarde.
        for fld in ("forecast", "previous"):
            incoming = (r.get(fld) or "").strip()
            if incoming and not (a.get(fld) or "").strip():
                a[fld] = incoming

        if incoming_has != "YES":
            # Regla 1: no se degrada. Si ya teniamos el actual, se conserva.
            continue

        if a["has_actual"] != "YES":
            # Primera vez que aparece el actual: este es el que puntua.
            a["actual"] = incoming_actual
            a["actual_seen_at"] = dumped
            a["actual_latest"] = incoming_actual
            a["has_actual"] = "YES"
            actuals += 1
        elif incoming_actual and incoming_actual != a["actual_latest"]:
            # Regla 2: revision. Se registra sin pisar el print original.
            a["actual_latest"] = incoming_actual
            a["revisions"] = str(int(a.get("revisions") or 0) + 1)
            revisions += 1

    return new, actuals, revisions


def write_archive(archive):
    rows = sorted(archive.values(),
                  key=lambda r: (r["event_time_server"], r["currency"],
                                 r["event"]))
    os.makedirs(STAGING_DIR, exist_ok=True)
    tmp = ARCHIVE + ".tmp"
    with open(tmp, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in FIELDS})
    os.replace(tmp, ARCHIVE)   # atomico: un lector nunca ve el archivo a medias
    return mirror_to_repo()


def mirror_to_repo():
    """Copia al repo si hay permiso. Que falle es normal bajo launchd (TCC)
    y no se trata como error: el canonico ya quedo escrito."""
    try:
        with open(ARCHIVE, encoding="utf-8") as src:
            data = src.read()
        with open(MIRROR, "w", encoding="utf-8") as dst:
            dst.write(data)
        return True
    except OSError:
        return False


def status(archive):
    """Cobertura real de la ventana que pide SPEC-FUND-001 §5: 10 dias habiles."""
    done = [r for r in archive.values() if r["has_actual"] == "YES"]
    if not done:
        print("historico vacio de actuals: M3 no tiene con que puntuar")
        return

    by_day = {}
    for r in done:
        t = parse_ts(r["event_time_server"])
        if t:
            by_day.setdefault(t.date(), []).append(r)

    print(f"archivo      {ARCHIVE}")
    print(f"eventos      {len(archive)} totales, {len(done)} con actual")
    print(f"revisiones   {sum(int(r.get('revisions') or 0) for r in done)}")
    print()

    # los 10 dias habiles hacia atras desde hoy
    wanted, d = [], datetime.now().date()
    while len(wanted) < 10:
        if d.weekday() < 5:
            wanted.append(d)
        d -= timedelta(days=1)

    have = sum(1 for d in wanted if d in by_day)
    print(f"ventana M3   {have}/10 dias habiles cubiertos")
    for d in sorted(wanted):
        n = len(by_day.get(d, []))
        mark = "OK  " if n else "HUECO"
        print(f"  {mark} {d}  {n} eventos con actual")


def deploy():
    """El LaunchAgent no puede leer el Desktop (TCC), asi que corre una copia
    del script en STAGING_DIR. Esta es la copia versionada; aquella es la que
    se ejecuta. Sin este paso, editar el repo no cambia lo que corre."""
    os.makedirs(STAGING_DIR, exist_ok=True)
    target = os.path.join(STAGING_DIR, os.path.basename(__file__))
    me = os.path.abspath(__file__)
    if os.path.abspath(target) == me:
        print("ya estas corriendo la copia desplegada, nada que hacer")
        return 0
    with open(me, encoding="utf-8") as src:
        code = src.read()
    with open(target, "w", encoding="utf-8") as dst:
        dst.write(code)
    os.chmod(target, 0o755)
    print(f"desplegado   {target}")
    return 0


def main():
    if "--deploy" in sys.argv:
        return deploy()

    archive = load_archive()

    if "--status" in sys.argv:
        status(archive)
        return 0

    rows, src, err = load_snapshot()
    if err:
        print(f"sin merge: {err}", file=sys.stderr)
        return 0

    dumps = {r.get("dumped_at", "").strip() for r in rows}
    dumped = max(dumps) if dumps else ""
    age = None
    t = parse_ts(dumped)
    if t:
        # dumped_at viene en hora del SERVER (UTC+3), no local. Comparar contra
        # la hora local sin convertir fue exactamente el error que hizo que el
        # reporte MORNING del 26-08 declarara 8.5h de atraso cuando eran 14.5h.
        age = (datetime.utcnow() + timedelta(hours=3)) - t

    before = len(archive)
    new, actuals, revisions = merge(archive, rows)

    # El backfill entra despues del snapshot en vivo: si ambos traen el mismo
    # evento, el que ya se observo manda y las reglas de merge lo protegen.
    for path in BACKFILLS:
        bf = read_snapshot(path)
        if not bf:
            continue
        n, a, r = merge(archive, bf)
        new, actuals, revisions = new + n, actuals + a, revisions + r
        print(f"backfill     {os.path.relpath(path, WINE_ROOT).split(os.sep)[0]}"
              f": {len(bf)} filas, +{n} eventos, +{a} actuals")

    mirrored = None
    if new or actuals or revisions:
        mirrored = write_archive(archive)
    elif not os.path.exists(MIRROR) or os.path.exists(ARCHIVE):
        mirrored = mirror_to_repo()   # sin novedad, pero el espejo puede faltar

    stale = " [VENCIDO]" if age and age > timedelta(hours=1) else ""
    aged = f"{age}" if age else "?"
    profile = os.path.relpath(src, WINE_ROOT).split(os.sep)[0] if src else "?"
    print(f"snapshot     {dumped} server, antiguedad {aged}{stale}")
    print(f"perfil wine  {profile}")
    print(f"historico    {before} -> {len(archive)} eventos")
    print(f"nuevos {new}  actuals nuevos {actuals}  revisiones {revisions}")
    if mirrored is not None:
        print(f"espejo repo  {'ok' if mirrored else 'sin permiso (TCC), normal bajo launchd'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
