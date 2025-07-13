#!/bin/bash

# Script para aplicar fuentes de GNOME Tweaks a todo el sistema en Fedora
# Autor: Script generado para aplicar Cantarell Extra Bold y Fira Code Bold
# Fecha: $(date)

set -e  # Salir en caso de error

echo "🔧 Aplicando fuentes de GNOME Tweaks a todo el sistema en Fedora..."
echo "=================================================="

# Función para mostrar progreso
show_progress() {
    echo "✅ $1"
}

# Función para mostrar errores
show_error() {
    echo "❌ Error: $1"
    exit 1
}

# Verificar si el usuario está ejecutando como root
if [[ $EUID -eq 0 ]]; then
   show_error "No ejecutes este script como root"
fi

# 1. INSTALAR FUENTES NECESARIAS
show_progress "Instalando fuentes necesarias..."

# Instalar fuentes Cantarell y Fira Code
sudo dnf install -y \
    abattis-cantarell-fonts \
    abattis-cantarell-vf-fonts \
    fira-code-fonts \
    google-noto-fonts \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    fontconfig \
    gnome-tweaks

show_progress "Fuentes instaladas correctamente"

# 2. CONFIGURAR GSETTINGS (CONFIGURACIÓN PRINCIPAL)
show_progress "Configurando fuentes del sistema con gsettings..."

gsettings set org.gnome.desktop.interface font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface document-font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code Bold 10'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Cantarell Extra Bold 11'

show_progress "Configuración gsettings aplicada"

# 3. CONFIGURAR FONTCONFIG
show_progress "Configurando fontconfig..."

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
    
    <!-- Configuración específica para aplicaciones -->
    <match target="font">
        <test name="family" qual="any">
            <string>sans-serif</string>
        </test>
        <edit name="family" mode="assign" binding="strong">
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

show_progress "Configuración fontconfig creada"

# 4. CONFIGURAR GTK (APLICACIONES GTK)
show_progress "Configurando GTK..."

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

show_progress "Configuración GTK aplicada"

# 5. CONFIGURAR APLICACIONES FLATPAK
show_progress "Configurando aplicaciones Flatpak..."

# Dar permisos a Flatpak para acceder a fuentes
flatpak override --user --filesystem=~/.config/fontconfig:ro 2>/dev/null || true
flatpak override --user --filesystem=~/.local/share/fonts:ro 2>/dev/null || true

show_progress "Configuración Flatpak aplicada"

# 6. CONFIGURAR VARIABLES DE ENTORNO PARA QT
show_progress "Configurando variables de entorno para aplicaciones Qt..."

# Agregar variables de entorno para Qt si no existen
if ! grep -q "QT_QPA_PLATFORMTHEME=gtk3" ~/.bashrc; then
    echo "export QT_QPA_PLATFORMTHEME=gtk3" >> ~/.bashrc
fi

show_progress "Variables de entorno configuradas"

# 7. CREAR TEMA PERSONALIZADO PARA GNOME SHELL
show_progress "Creando tema personalizado para GNOME Shell..."

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

/* Menú de configuración rápida (WiFi, Bluetooth, etc.) */
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

.popup-menu-item:ltr {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Agregado para el menú de sistema */
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

/* Elementos del workspace */
.workspace-thumbnail {
  font-family: "Cantarell Extra Bold", sans-serif;
  font-size: 11pt;
  font-weight: bold;
}

/* Texto en el lock screen */
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

show_progress "Tema personalizado para GNOME Shell creado"

# 8. HABILITAR EXTENSIÓN USER THEMES Y APLICAR TEMA
show_progress "Habilitando extensión User Themes..."

# Habilitar extensión User Themes
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null || true

# Aplicar tema personalizado
gsettings set org.gnome.shell.extensions.user-theme name 'CustomFont'

show_progress "Tema personalizado aplicado"

# 9. ACTUALIZAR CACHÉ DE FUENTES
show_progress "Actualizando caché de fuentes..."

fc-cache -fv > /dev/null 2>&1

show_progress "Caché de fuentes actualizado"

# 10. APLICAR CONFIGURACIONES ADICIONALES
show_progress "Aplicando configuraciones adicionales..."

# Forzar actualización de configuraciones
dconf update 2>/dev/null || true

# Reaplicar configuraciones gsettings para asegurar persistencia
gsettings set org.gnome.desktop.interface font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface document-font-name 'Cantarell Extra Bold 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code Bold 10'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Cantarell Extra Bold 11'

show_progress "Configuraciones adicionales aplicadas"

# 11. CREAR SCRIPT DE VERIFICACIÓN
show_progress "Creando script de verificación..."

cat > ~/verify-fonts.sh << 'EOF'
#!/bin/bash
echo "🔍 Verificando configuración de fuentes..."
echo "========================================="
echo "Fuente de interfaz: $(gsettings get org.gnome.desktop.interface font-name)"
echo "Fuente de documentos: $(gsettings get org.gnome.desktop.interface document-font-name)"
echo "Fuente monospace: $(gsettings get org.gnome.desktop.interface monospace-font-name)"
echo "Fuente de barra de título: $(gsettings get org.gnome.desktop.wm.preferences titlebar-font)"
echo "Tema del shell: $(gsettings get org.gnome.shell.extensions.user-theme name)"
echo "========================================="
echo "✅ Verificación completada"
EOF

chmod +x ~/verify-fonts.sh

show_progress "Script de verificación creado"

# MENSAJE FINAL
echo ""
echo "🎉 ¡CONFIGURACIÓN COMPLETADA EXITOSAMENTE!"
echo "=========================================="
echo ""
echo "📋 Resumen de configuraciones aplicadas:"
echo "• Fuentes del sistema: Cantarell Extra Bold 11pt"
echo "• Fuente monospace: Fira Code Bold 10pt"
echo "• Configuración fontconfig personalizada"
echo "• Configuración GTK 3 y GTK 4"
echo "• Permisos Flatpak configurados"
echo "• Variables de entorno Qt"
echo "• Tema personalizado para GNOME Shell"
echo "• Extensión User Themes habilitada"
echo ""
echo "🔄 Para aplicar los cambios completamente:"
echo "1. Reinicia tu sesión de GNOME (cerrar sesión y volver a iniciar)"
echo "2. O presiona Alt+F2, escribe 'r' y presiona Enter"
echo ""
echo "🔍 Para verificar la configuración:"
echo "Ejecuta: ~/verify-fonts.sh"
echo ""
echo "💡 Todas las aplicaciones (GTK, Qt, Flatpak, GNOME Shell) ahora usarán las fuentes personalizadas."
echo "   Si alguna aplicación específica no respeta las fuentes, reiníciala completamente."
echo ""
echo "📁 Archivos creados:"
echo "• ~/.config/fontconfig/fonts.conf"
echo "• ~/.config/gtk-3.0/settings.ini"
echo "• ~/.config/gtk-4.0/settings.ini"
echo "• ~/.themes/CustomFont/gnome-shell/gnome-shell.css"
echo "• ~/verify-fonts.sh"
echo ""
echo "🚀 ¡Listo! Tu sistema ahora usa las fuentes de GNOME Tweaks en todas las aplicaciones."
