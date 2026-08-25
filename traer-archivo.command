#!/bin/bash
# Trae el contenido de un archivo de Downloads a /tmp, que es la unica ruta que
# la sesion puede leer sin tropezar con los atributos de procedencia que macOS
# adjunta a lo descargado (com.apple.quarantine / com.apple.provenance).
cat "/Users/nachogm/Downloads/message.txt" > /tmp/message_content.txt
chmod 644 /tmp/message_content.txt
xattr -c /tmp/message_content.txt 2>/dev/null
{
  echo "lineas: $(wc -l < /tmp/message_content.txt)"
  echo "bytes : $(wc -c < /tmp/message_content.txt)"
  echo "xattrs: [$(xattr /tmp/message_content.txt 2>/dev/null | tr '\n' ' ')]"
} > /tmp/traer-archivo.log 2>&1
