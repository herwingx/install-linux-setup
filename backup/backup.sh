#!/bin/bash
set -e # Salir inmediatamente si un comando falla

# ==============================================================================
# SCRIPT DE BACKUP DE ENTORNO DE DESARROLLO
# Propósito: Crear un backup completo y portátil de aplicaciones, configuraciones
#            y archivos clave para una migración de sistema.
# ==============================================================================

print_header() {
    echo -e "\n=============================================="
    echo -e "  $1"
    echo -e "==============================================\n"
}

print_header "🚀 Iniciando el proceso de backup de tu entorno"

# --- Detectar gestor de paquetes actual ---
PACKAGE_MANAGER=""
if command -v apt &> /dev/null; then PACKAGE_MANAGER="apt";
elif command -v dnf &> /dev/null; then PACKAGE_MANAGER="dnf";
elif command -v pacman &> /dev/null; then PACKAGE_MANAGER="pacman";
else
    echo "❌ Gestor de paquetes no soportado para crear lista de paquetes."
    PACKAGE_MANAGER="unknown"
fi

# --- Crear directorio de backup ---
backup_parent_dir=$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documentos")
backup_dir="$backup_parent_dir/gnome_backup_$(date +%Y-%m-%d)"
mkdir -p "$backup_dir"
echo "📂 Directorio de backup creado en: $backup_dir"

# --- 1. Backup de Listas de Aplicaciones ---
print_header "📝 Guardando listas de aplicaciones instaladas"
if [ "$PACKAGE_MANAGER" != "unknown" ]; then
    case $PACKAGE_MANAGER in
        apt) apt-mark showmanual > "$backup_dir/pkglist-apt.txt" ;;
        dnf) dnf history userinstalled | sed 's/^[ \t]*//;s/[ \t].*//' | grep -v 'dnf' > "$backup_dir/pkglist-dnf.txt" ;;
        pacman) pacman -Qeq > "$backup_dir/pkglist-pacman.txt" ;;
    esac
    echo "  - Lista de paquetes de '$PACKAGE_MANAGER' guardada."
fi

if command -v flatpak &> /dev/null; then
    flatpak list --app --columns=application > "$backup_dir/pkglist-flatpak.txt"
    echo "  - Lista de aplicaciones Flatpak guardada."
fi

if command -v gnome-extensions &> /dev/null; then
    gnome-extensions list --enabled | cut -d' ' -f1 > "$backup_dir/gnome-extensions-enabled.txt"
    echo "  - Lista de extensiones de GNOME guardada (como referencia)."
fi

# --- 2. Backup de Configuraciones (dconf y dotfiles) ---
print_header "⚙️ Guardando configuraciones del sistema y de usuario"
if command -v dconf &> /dev/null; then
    dconf dump / > "$backup_dir/gnome-settings.dconf"
    echo "  - Configuración de GNOME (dconf) guardada."
fi

echo "  - Copiando archivos de configuración importantes (dotfiles)..."
# Copia los directorios y archivos de config más importantes.
# Excluye cachés y perfiles de navegador grandes para un backup más ligero.
rsync -aiv --prune-empty-dirs \
    --include='/.config/***' \
    --include='/.local/share/fonts/***' \
    --include='/.local/share/themes/***' \
    --include='/.local/share/icons/***' \
    --include='/.ssh/***' \
    --include='/.gitconfig' \
    --include='/.tmux.conf' \
    --exclude='/.config/google-chrome*' \
    --exclude='/.config/BraveSoftware*' \
    --exclude='/.cache' \
    --exclude='/.local/share/Trash' \
    --exclude='/.local/share/Steam' \
    "$HOME" "$backup_dir/dotfiles/"
echo "  - Archivos de configuración (dotfiles) guardados."

echo -e "\n✅ ¡Proceso de backup finalizado con éxito!"
echo "Copia la carpeta completa '$backup_dir' a un disco externo o a la nube."
echo "Contiene todo lo que necesitas para el script de restauración."