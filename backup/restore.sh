#!/bin/bash

# ==============================================================================
# SCRIPT DE RESTAURACIÓN DE ENTORNO PERSONALIZADO (v2.1 - con Extensiones GNOME)
# ==============================================================================

print_header() {
    echo -e "\n================================================="
    echo -e "  $1"
    echo -e "=================================================\n"
}

# --- Detección del nuevo sistema ---
PACKAGE_MANAGER=""
INSTALL_COMMAND=""
if command -v apt &> /dev/null; then PACKAGE_MANAGER="apt"; INSTALL_COMMAND="sudo apt install -y";
elif command -v dnf &> /dev/null; then PACKAGE_MANAGER="dnf"; INSTALL_COMMAND="sudo dnf install -y";
else echo "❌ Error: Sistema operativo no soportado."; exit 1;
fi

# --- Funciones de Restauración ---

restore_configs_and_passwords() {
    # ... (Esta función no cambia) ...
    local backup_path=$1
    print_header "⚙️ Restaurando Configuraciones, Contraseñas y Atajos"
    if [ -d "$backup_path/dotfiles" ]; then rsync -aiv "$backup_path/dotfiles/" "$HOME/"; fi
    if [ -f "$backup_path/gnome-settings.dconf" ]; then dconf load / < "$backup_path/gnome-settings.dconf"; fi
    echo "¡Hecho! Puede que necesites reiniciar sesión para ver todos los cambios."
}

restore_system_packages() {
    # ... (Esta función no cambia) ...
    local backup_path=$1; local source_pkg_list; source_pkg_list=$(find "$backup_path" -maxdepth 1 -name "pkglist-*.txt" ! -name "pkglist-flatpak.txt" | head -n 1); if [ -z "$source_pkg_list" ]; then return; fi
    local source_pm; source_pm=$(basename "$source_pkg_list" | sed -e 's/pkglist-//' -e 's/.txt//'); print_header "📦 Reinstalando Paquetes del Sistema (APT/DNF)"; echo "Se encontró lista de '$source_pm'. Tu sistema usa '$PACKAGE_MANAGER'."
    declare -A PKG_MAP; if [ "$source_pm" = "dnf" ] && [ "$PACKAGE_MANAGER" = "apt" ]; then PKG_MAP=( ["httpd"]="apache2" ["@development-tools"]="build-essential" ); elif [ "$source_pm" = "apt" ] && [ "$PACKAGE_MANAGER" = "dnf" ]; then PKG_MAP=( ["apache2"]="httpd" ["build-essential"]="@development-tools" ); fi
    local packages_to_install=(); local packages_failed=(); while IFS= read -r pkg; do if [ -n "$pkg" ]; then local target_pkg="$pkg"; [ -n "${PKG_MAP[$pkg]}" ] && target_pkg=${PKG_MAP[$pkg]}; packages_to_install+=($target_pkg); fi; done < "$source_pkg_list"
    echo -e "\nSe intentarán instalar ${#packages_to_install[@]} paquetes."; sudo $PACKAGE_MANAGER update; for pkg_to_try in "${packages_to_install[@]}"; do if ! $INSTALL_COMMAND "$pkg_to_try" &>/dev/null; then packages_failed+=("$pkg_to_try"); fi; done
    if [ ${#packages_failed[@]} -ne 0 ]; then echo -e "\n--- ⚠️ Paquetes que Requieren Revisión Manual ---"; printf "  - %s\n" "${packages_failed[@]}"; fi
}

restore_flatpaks() {
    # ... (Esta función no cambia) ...
    local backup_path=$1; if [ ! -f "$backup_path/pkglist-flatpak.txt" ]; then return; fi
    print_header "🚀 Reinstalando Aplicaciones Flatpak"; xargs -a "$backup_path/pkglist-flatpak.txt" -r flatpak install -y --noninteractive || true
}

# --- NUEVO: GUÍA PARA RESTAURAR EXTENSIONES DE GNOME ---
restore_gnome_extensions() {
    local backup_path=$1
    if [ ! -f "$backup_path/gnome-extensions.txt" ]; then return; fi

    print_header "🧩 Guía para Reinstalar Extensiones de GNOME"
    echo "Se ha encontrado una lista de tus extensiones de GNOME."
    echo "Debido a posibles problemas de compatibilidad, la reinstalación es un proceso manual guiado."
    echo ""
    echo "--- Extensiones que tenías habilitadas ---"
    cat "$backup_path/gnome-extensions.txt"
    echo "----------------------------------------"
    echo ""
    echo "Para reinstalarlas de forma segura:"
    echo "  1. Abre tu navegador (Firefox o Chrome)."
    echo "  2. Instala el complemento 'GNOME Shell Integration' desde la tienda de complementos de tu navegador."
    echo "  3. Visita el sitio web oficial de extensiones de GNOME:"
    echo "     ➡️  https://extensions.gnome.org/"
    echo "  4. Busca cada una de las extensiones de la lista de arriba y actívalas con el interruptor en la página."
    echo ""
    echo "Este método asegura que obtendrás la versión correcta y compatible para tu nuevo sistema."
}


# --- Script Principal de Restauración ---
main() {
    print_header "Bienvenido al Script de Restauración de Entorno"
    read -ep "Introduce la ruta COMPLETA a tu carpeta de backup: " backup_path

    if [ ! -d "$backup_path" ]; then echo "❌ Error: Directorio no existe."; exit 1; fi
    
    # Flujo de restauración actualizado
    restore_configs_and_passwords "$backup_path"
    restore_system_packages "$backup_path"
    restore_flatpaks "$backup_path"
    restore_gnome_extensions "$backup_path" # <--- Nuevo paso

    print_header "✅ ¡Restauración Completada!"
    echo "Revisa la lista de 'Paquetes que Requieren Revisión Manual' y la guía de extensiones."
    echo "Para que todos los cambios surtan efecto, es **muy importante** que reinicies tu sistema ahora."
}

# Ejecutar el script
main