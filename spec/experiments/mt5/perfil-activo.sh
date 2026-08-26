#!/bin/bash
# Devuelve la ruta Common/Files del perfil Wine ACTIVO.
#
# Por que existe: MT5 corre bajo Wine y alterna entre los perfiles `nachogm` y
# `user` entre arranques. Mirar una ruta fija lleva a leer un archivo congelado
# hace horas y a declarar el detector caido cuando en realidad esta escribiendo
# sano en el otro perfil. Paso el 2026-08-26, dos veces en el mismo dia.
#
#   uso:  RUTA=$(./perfil-activo.sh)
#         ./perfil-activo.sh --todos     # lista los dos con su antiguedad
W="/Users/nachogm/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/users"
REF="TRADER-ALERT-001-state.txt"

mejor=""; mejor_ts=0
for d in "$W"/*/AppData/Roaming/MetaQuotes/Terminal/Common/Files; do
  [ -f "$d/$REF" ] || continue
  ts=$(stat -f '%m' "$d/$REF" 2>/dev/null) || continue
  if [ "$ts" -gt "$mejor_ts" ]; then mejor_ts=$ts; mejor="$d"; fi
done

if [ "$1" = "--todos" ]; then
  ahora=$(date +%s)
  for d in "$W"/*/AppData/Roaming/MetaQuotes/Terminal/Common/Files; do
    [ -f "$d/$REF" ] || continue
    ts=$(stat -f '%m' "$d/$REF")
    p=$(echo "$d" | sed 's|.*/users/\([^/]*\)/.*|\1|')
    printf "  %-10s hace %5d s   %s\n" "$p" "$((ahora-ts))" \
           "$([ "$d" = "$mejor" ] && echo '<-- ACTIVO')"
  done
  exit 0
fi

[ -n "$mejor" ] || { echo "ERROR: ningun perfil tiene $REF" >&2; exit 1; }
echo "$mejor"
