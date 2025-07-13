#!/bin/bash

# Configurar variables de entorno para fuentes
export FONTCONFIG_PATH="$HOME/.config/fontconfig"
export QT_QPA_PLATFORMTHEME=gtk3

# Argumentos para Brave con fuentes personalizadas
BRAVE_ARGS=(
    "--font-size=11"
    "--force-device-scale-factor=1.0"
    "--enable-font-antialiasing"
    "--enable-features=WebUIDarkMode"
    "--force-color-profile=srgb"
    "--use-gl=desktop"
)

# Aplicar configuración de fuentes antes de lanzar
gsettings set org.gnome.desktop.interface font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface document-font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code Bold 10'

# Lanzar Brave
exec brave-browser "${BRAVE_ARGS[@]}" "$@"
