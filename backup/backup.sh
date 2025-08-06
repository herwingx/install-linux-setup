#!/bin/bash
set -e

# ==============================================================================
# SCRIPT DE BACKUP DE IDENTIDAD DE SISTEMA (v3.0)
# Enfocado en: Configs de Sistema, Contraseñas, Atajos y Listas de Apps.
# Omite configuraciones de aplicaciones específicas (VSCode, Chrome, etc.).
# ==============================================================================

print_header() {
    echo -e "\n================================================="
    echo -e "  $1"
    echo -e "=================================================\n"
}

print_header "🚀 Iniciando Backup de Identidad del Sistema"

# --- Detección y Creación de Directorio (sin cambios) ---
PACKAGE_MANAGER=""
if command -v apt &> /dev/null; then PACKAGE_MANAGER="apt";
elif command -v dnf &> /dev/null; then PACKAGE_MANAGER="dnf";
else echo "❌ Gestor de paquetes no soportado."; exit 1;
fi
backup_parent_dir=$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documentos")
backup_dir="$backup_parent_dir/mi_sistema_backup_$(date +%Y-%m-%d)"
mkdir -p "$backup_dir"
echo "📂 Directorio de backup creado en: $backup_dir"

# --- 1. Backup de Listas de Software (sin cambios) ---
print_header "📝 Creando listas de software"
case $PACKAGE_MANAGER in
    apt) apt-mark showmanual > "$backup_dir/pkglist-apt.txt" ;;
    dnf) dnf repoquery --userinstalled --qf '%{name}' > "$backup_dir/pkglist-dnf.txt" ;;
esac
echo "  - Lista de paquetes de '$PACKAGE_MANAGER' guardada."
if command -v flatpak &> /dev/null; then flatpak list --app --columns=application > "$backup_dir/pkglist-flatpak.txt"; echo "  - Lista de Flatpaks guardada."; fi
if command -v gnome-extensions &> /dev/null; then gnome-extensions list --enabled | cut -d' ' -f1 > "$backup_dir/gnome-extensions.txt"; echo "  - Lista de Extensiones de GNOME guardada."; fi

# --- 2. Backup Selectivo de Configuraciones de Sistema ---
print_header "⚙️ Guardando configuraciones de sistema, contraseñas y atajos"

# Atajos y configuración profunda de GNOME
if command -v dconf &> /dev/null; then
    dconf dump / > "$backup_dir/gnome-settings.dconf"
    echo "  - Atajos y configuración de GNOME guardados."
fi

# --- RYSNC QUIRÚRGICO: Solo copia lo esencial ---
echo "  - Copiando archivos de identidad (Contraseñas, SSH, Git, GTK)..."
rsync -aiv --prune-empty-dirs \
    --include='/.ssh/***' \
    --include='/.local/share/keyrings/***' \
    --include='/.config/gtk-3.0/***' \
    --include='/.config/gtk-4.0/***' \
    --include='/.gitconfig' \
    --include='/.bashrc' \
    --exclude='*' \
    "$HOME" "$backup_dir/system_files/"
echo "  - Archivos de identidad guardados."

echo -e "\n✅ ¡Backup finalizado con éxito!"
echo "Copia la carpeta completa '$backup_dir' a un disco externo."