#!/bin/bash
set -e

# ==============================================================================
# SCRIPT DE BACKUP DE ENTORNO PERSONALIZADO (v2.1 - con Extensiones GNOME)
# ==============================================================================

print_header() {
    echo -e "\n================================================="
    echo -e "  $1"
    echo -e "=================================================\n"
}

print_header "🚀 Iniciando Backup de Entorno Personal"

# --- Detectar Gestor de Paquetes ---
PACKAGE_MANAGER=""
if command -v apt &> /dev/null; then PACKAGE_MANAGER="apt";
elif command -v dnf &> /dev/null; then PACKAGE_MANAGER="dnf";
else echo "❌ Gestor de paquetes no soportado."; exit 1;
fi

# --- Crear Directorio de Backup ---
backup_parent_dir=$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documentos")
backup_dir="$backup_parent_dir/mi_entorno_backup_$(date +%Y-%m-%d)"
mkdir -p "$backup_dir"
echo "📂 Directorio de backup creado en: $backup_dir"

# --- 1. Backup de Listas de Aplicaciones y Extensiones ---
print_header "📝 Creando listas de software"
case $PACKAGE_MANAGER in
    apt) apt-mark showmanual > "$backup_dir/pkglist-apt.txt" ;;
    dnf) dnf repoquery --userinstalled --qf '%{name}' > "$backup_dir/pkglist-dnf.txt" ;;
esac
echo "  - Lista de paquetes de '$PACKAGE_MANAGER' guardada."

if command -v flatpak &> /dev/null; then
    flatpak list --app --columns=application > "$backup_dir/pkglist-flatpak.txt"
    echo "  - Lista de aplicaciones Flatpak guardada."
fi

# --- NUEVO: GUARDAR EXTENSIONES DE GNOME ---
if command -v gnome-extensions &> /dev/null; then
    gnome-extensions list --enabled | cut -d' ' -f1 > "$backup_dir/gnome-extensions.txt"
    echo "  - Lista de extensiones de GNOME guardada."
fi

# --- 2. Backup de Configuraciones, Contraseñas y Atajos ---
print_header "⚙️ Guardando configuraciones, contraseñas y atajos"
if command -v dconf &> /dev/null; then
    dconf dump / > "$backup_dir/gnome-settings.dconf"
    echo "  - Atajos y configuración de GNOME guardados."
fi

echo "  - Copiando archivos de configuración (dotfiles) y llaveros (contraseñas)..."
rsync -aiv --prune-empty-dirs \
    --include='/.config/***' \
    --include='/.local/share/keyrings/***' \
    --include='/.ssh/***' \
    --include='/.gitconfig' \
    --exclude='/.cache' \
    --exclude='/.local/share/Trash' \
    "$HOME" "$backup_dir/dotfiles/"
echo "  - Archivos de configuración y contraseñas guardados."

echo -e "\n✅ ¡Backup finalizado con éxito!"
echo "Copia la carpeta completa '$backup_dir' a un disco externo."