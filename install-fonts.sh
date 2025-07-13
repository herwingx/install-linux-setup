#!/bin/bash

# Script para instalar y configurar fuentes Cantarell Extra Bold en Fedora GNOME
# Versión: 1.0
# Autor: Sistema de configuración de fuentes
# Fecha: $(date +"%Y-%m-%d")

echo "🔧 Instalando y configurando fuentes Cantarell Extra Bold..."
echo "===================================================="
echo ""

# Verificar si el usuario está ejecutando como root
if [[ $EUID -eq 0 ]]; then
   echo "❌ No ejecutes este script como root"
   exit 1
fi

# 0. INSTALAR DEPENDENCIAS
echo "📦 Instalando dependencias..."
sudo dnf install -y \
    abattis-cantarell-fonts \
    abattis-cantarell-vf-fonts \
    fira-code-fonts \
    fontconfig \
    gnome-tweaks \
    gnome-shell-extension-user-theme || {
    echo "⚠️  Error instalando dependencias, continuando..."
}

echo "✅ Dependencias instaladas"
echo ""

# 1. Configurar gsettings con el nombre correcto
echo "📝 Aplicando configuración gsettings..."
gsettings set org.gnome.desktop.interface font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface document-font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code Bold 10'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Cantarell Extra Bold 11'

# 2. Corregir configuración fontconfig
echo "📝 Corrigiendo fontconfig..."
mkdir -p ~/.config/fontconfig

cat > ~/.config/fontconfig/fonts.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <!-- Configuración para aplicar fuentes por defecto -->
    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>Cantarell Extra Bold</family>
        </prefer>
    </alias>
    
    <alias>
        <family>serif</family>
        <prefer>
            <family>Cantarell Extra Bold</family>
        </prefer>
    </alias>
    
    <alias>
        <family>monospace</family>
        <prefer>
            <family>Fira Code Bold</family>
        </prefer>
    </alias>
    
    <!-- Fuentes por defecto del sistema -->
    <match target="pattern">
        <test qual="any" name="family">
            <string>system-ui</string>
        </test>
        <edit name="family" mode="prepend" binding="strong">
            <string>Cantarell Extra Bold</string>
        </edit>
    </match>
    
    <!-- Mapear Cantarell normal a Extra Bold -->
    <match target="pattern">
        <test name="family" qual="any">
            <string>Cantarell</string>
        </test>
        <edit name="family" mode="assign" binding="strong">
            <string>Cantarell Extra Bold</string>
        </edit>
    </match>
</fontconfig>
EOF

# 3. Corregir configuración GTK
echo "📝 Corrigiendo GTK..."
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

# GTK 3
cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-font-name=Cantarell Extra Bold 11
EOF

# GTK 4
cat > ~/.config/gtk-4.0/settings.ini << 'EOF'
[Settings]
gtk-font-name=Cantarell Extra Bold 11
EOF

# 4. Corregir tema personalizado para GNOME Shell
echo "📝 Corrigiendo tema del shell..."
mkdir -p ~/.themes/CustomFont/gnome-shell

cat > ~/.themes/CustomFont/gnome-shell/gnome-shell.css << 'EOF'
/* Aplicar fuentes personalizadas al shell de GNOME */
@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

/* Fuente principal para el shell */
stage {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Panel superior */
#panel {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Menú del panel */
.panel-button {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Menú de configuración rápida */
.quick-settings {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

.quick-settings-item {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

.quick-toggle {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Elementos del menú */
.popup-menu-item {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Menú de sistema */
.system-menu-action {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Menú de actividades */
.overview-controls {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Texto general */
.shell-generic-container {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Botones del shell */
.button {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Notificaciones */
.notification {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* OSD (On Screen Display) */
.osd-window {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Workspace */
.workspace-thumbnail {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Lock screen */
.unlock-dialog {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Dash to dock compatibility */
.dash-item-container {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}
EOF

# 5. Habilitar extensión User Themes y aplicar tema
echo "📝 Aplicando tema personalizado..."

# Verificar si la extensión está instalada
if ! gnome-extensions list | grep -q "user-theme"; then
    echo "⚠️  Instalando extensión User Themes..."
    sudo dnf install -y gnome-shell-extension-user-theme
fi

# Habilitar extensión
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com

# Aplicar tema personalizado
gsettings set org.gnome.shell.extensions.user-theme name 'CustomFont'

# 6. Actualizar caché de fuentes
echo "📝 Actualizando caché de fuentes..."
fc-cache -fv > /dev/null 2>&1

# 7. Aplicar configuraciones
echo "📝 Aplicando configuraciones..."
dconf update

# 8. Reiniciar GNOME Shell
echo "🔄 Reiniciando GNOME Shell..."
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Sesión Wayland detectada. Presiona Alt+F2, escribe 'r' y presiona Enter para reiniciar el shell."
else
    killall -HUP gnome-shell &
    echo "Shell reiniciado."
fi

echo ""
echo "✅ Configuración corregida!"
echo "📝 Para ver los cambios:"
echo "   1. Presiona Alt+F2"
echo "   2. Escribe 'r' y presiona Enter"
echo "   3. O reinicia tu sesión"
echo ""
echo "🔍 Para verificar: gsettings get org.gnome.desktop.interface font-name"

