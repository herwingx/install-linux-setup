#!/bin/bash

echo "Reiniciando GNOME Shell para aplicar cambios de fuentes..."

# Reiniciar el shell en Wayland
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Sesión Wayland detectada. Aplicando configuraciones..."
    
    # Aplicar configuraciones de fuentes
    gsettings set org.gnome.desktop.interface font-name 'Cantarell Extra Bold 11'
    gsettings set org.gnome.desktop.interface document-font-name 'Cantarell Extra Bold 11'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code Bold 10'
    gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Cantarell Extra Bold 11'
    
    # Aplicar tema personalizado
    gsettings set org.gnome.shell.extensions.user-theme name 'CustomFont'
    
    # Forzar recarga de configuraciones
    dconf update
    
    echo "Configuraciones aplicadas. Para ver los cambios completos, reinicia la sesión o presiona Alt+F2 y escribe 'r' para reiniciar el shell."
    
else
    echo "Sesión X11 detectada. Reiniciando shell..."
    
    # Aplicar configuraciones de fuentes
    gsettings set org.gnome.desktop.interface font-name 'Cantarell Extra Bold 11'
    gsettings set org.gnome.desktop.interface document-font-name 'Cantarell Extra Bold 11'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code Bold 10'
    gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Cantarell Extra Bold 11'
    
    # Aplicar tema personalizado
    gsettings set org.gnome.shell.extensions.user-theme name 'CustomFont'
    
    # Reiniciar el shell en X11
    killall -HUP gnome-shell &
    
    echo "Shell reiniciado. Los cambios deberían aplicarse inmediatamente."
fi

echo "¡Listo! Las fuentes personalizadas han sido aplicadas al menú del sistema."
