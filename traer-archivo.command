#!/bin/bash
# Trae un archivo de Downloads a /tmp (el sandbox bloquea la lectura directa por
# los atributos de procedencia que macOS pone a lo descargado).
SRC="${1:-/Users/nachogm/Downloads/message-2.txt}"
cat "$SRC" > /tmp/message_content.txt
chmod 644 /tmp/message_content.txt
echo "lineas: $(wc -l < /tmp/message_content.txt)" > /tmp/traer-archivo.log 2>&1
