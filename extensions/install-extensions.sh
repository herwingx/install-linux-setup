#!/bin/bash

# Script para instalar extensiones de GNOME Shell desde backup
BACKUP_FILE="gnome-extensions-backup.txt"

# Verificar si el archivo de backup existe
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: No se encontró el archivo de backup '$BACKUP_FILE'"
    echo "Ejecuta primero: ./backup-extensions.sh"
    exit 1
fi

echo "Restaurando extensiones de GNOME Shell desde $BACKUP_FILE..."

# Contador de extensiones procesadas
processed=0
enabled=0
disabled=0
errors=0

# Leer el archivo línea por línea
while IFS=':' read -r extension_id status; do
    if [ -n "$extension_id" ] && [ -n "$status" ]; then
        echo "Procesando: $extension_id ($status)"
        
        # Verificar si la extensión ya está instalada
        if gnome-extensions list | grep -q "^$extension_id$"; then
            echo "  ✓ Extensión ya instalada: $extension_id"
        else
            echo "  → Instalando extensión: $extension_id"
            # Aquí podrías agregar lógica para instalar desde extensiones.gnome.org
            # Por ahora solo mostramos que se debería instalar
            echo "  ⚠ Extensión no instalada. Instálala manualmente desde https://extensions.gnome.org/"
        fi
        
        # Aplicar el estado (habilitado/deshabilitado)
        case "$status" in
            "enabled")
                if gnome-extensions enable "$extension_id" 2>/dev/null; then
                    echo "  ✓ Extensión habilitada: $extension_id"
                    ((enabled++))
                else
                    echo "  ✗ Error al habilitar: $extension_id"
                    ((errors++))
                fi
                ;;
            "disabled")
                if gnome-extensions disable "$extension_id" 2>/dev/null; then
                    echo "  ✓ Extensión deshabilitada: $extension_id"
                    ((disabled++))
                else
                    echo "  ✗ Error al deshabilitar: $extension_id"
                    ((errors++))
                fi
                ;;
            *)
                echo "  ⚠ Estado desconocido: $status"
                ((errors++))
                ;;
        esac
        
        ((processed++))
        echo ""
    fi
done < "$BACKUP_FILE"

echo "Restauración completada."
echo ""
echo "Resumen:"
echo "- Extensiones procesadas: $processed"
echo "- Habilitadas: $enabled"
echo "- Deshabilitadas: $disabled"
echo "- Errores: $errors"
echo ""
echo "Nota: Si alguna extensión no está instalada, deberás instalarla manualmente desde:"
echo "https://extensions.gnome.org/"
echo ""
echo "Luego puedes ejecutar este script nuevamente para aplicar los estados correctos."