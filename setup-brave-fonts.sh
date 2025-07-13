#!/bin/bash

echo "Configurando fuentes personalizadas para Brave Browser..."

# Asegurar que Brave está cerrado
pkill -f brave-browser 2>/dev/null

# Esperar un momento para que se cierre completamente
sleep 2

# Aplicar configuraciones de fuentes del sistema
echo "Aplicando configuraciones de fuentes del sistema..."
gsettings set org.gnome.desktop.interface font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface document-font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code Bold 10'

# Actualizar caché de fuentes
echo "Actualizando caché de fuentes..."
fc-cache -f

# Configurar variables de entorno
echo "Configurando variables de entorno..."
export FONTCONFIG_PATH="$HOME/.config/fontconfig"
export QT_QPA_PLATFORMTHEME=gtk3

# Crear configuración de fuentes para Brave
echo "Creando configuración específica para Brave..."
mkdir -p ~/.config/BraveSoftware/Brave-Browser/Default

# Configurar fuentes en las preferencias de Brave
BRAVE_PREFS='{"webkit":{"webprefs":{"fonts":{"standard":{"Zyyy":"Cantarell Extra Bold"},"sansserif":{"Zyyy":"Cantarell Extra Bold"},"serif":{"Zyyy":"Cantarell Extra Bold"},"fixed":{"Zyyy":"Fira Code Bold"},"cursive":{"Zyyy":"Cantarell Extra Bold"},"fantasy":{"Zyyy":"Cantarell Extra Bold"}},"default_font_size":16,"default_fixed_font_size":13,"minimum_font_size":0,"minimum_logical_font_size":6,"default_encoding":"UTF-8"}}}'

# Escribir configuración si no existe
if [ ! -f ~/.config/BraveSoftware/Brave-Browser/Default/Preferences ]; then
    echo "$BRAVE_PREFS" > ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
fi

echo "✅ Configuración completada!"
echo ""
echo "🔧 Opciones para usar Brave con fuentes personalizadas:"
echo "1. Usar el lanzador personalizado: ~/launch-brave-with-fonts.sh"
echo "2. Buscar 'Brave Browser (Custom Fonts)' en el menú de aplicaciones"
echo "3. Lanzar Brave normalmente (las fuentes se aplicarán automáticamente)"
echo ""
echo "💡 Tip: Para mejores resultados, cierra Brave completamente antes de volver a abrirlo."
