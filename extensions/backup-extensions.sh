#!/bin/bash

# Script para hacer backup de las extensiones de GNOME Shell
# Archivo de salida para la lista de extensiones
OUTPUT_FILE="gnome-extensions-backup.txt"

echo "Creando backup de las extensiones de GNOME Shell..."

# Limpiar archivo previo si existe
> "$OUTPUT_FILE"

# Obtener lista de extensiones instaladas con su estado
gnome-extensions list --enabled | while read -r extension; do
    echo "$extension:enabled" >> "$OUTPUT_FILE"
done

gnome-extensions list --disabled | while read -r extension; do
    echo "$extension:disabled" >> "$OUTPUT_FILE"
done

echo "Backup completado. Lista de extensiones guardada en $OUTPUT_FILE"
echo "Total de extensiones: $(wc -l < "$OUTPUT_FILE")"

# Mostrar resumen
echo ""
echo "Resumen:"
echo "- Habilitadas: $(grep -c ':enabled' "$OUTPUT_FILE")"
echo "- Deshabilitadas: $(grep -c ':disabled' "$OUTPUT_FILE")"
echo "- Archivo: $OUTPUT_FILE"