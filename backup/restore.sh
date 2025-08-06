#!/bin/bash

# ==============================================================================
# SCRIPT DE RESTAURACIÓN DE ENTORNO DE DESARROLLO
# Propósito: Restaurar configuraciones y reinstalar aplicaciones desde un backup,
#            con capacidad de traducción entre distribuciones.
# ==============================================================================

print_header() {
    echo -e "\n=============================================="
    echo -e "  $1"
    echo -e "==============================================\n"
}

# --- Detección del nuevo sistema ---
PACKAGE_MANAGER=""
INSTALL_COMMAND=""
UPDATE_COMMAND=""
if command -v apt &> /dev/null; then PACKAGE_MANAGER="apt"; INSTALL_COMMAND="sudo apt install -y"; UPDATE_COMMAND="sudo apt update";
elif command -v dnf &> /dev/null; then PACKAGE_MANAGER="dnf"; INSTALL_COMMAND="sudo dnf install -y"; UPDATE_COMMAND="sudo dnf makecache";
elif command -v pacman &> /dev/null; then PACKAGE_MANAGER="pacman"; INSTALL_COMMAND="sudo pacman -S --noconfirm"; UPDATE_COMMAND="sudo pacman -Sy";
else echo "❌ Error: Sistema operativo no soportado."; exit 1;
fi

# --- Funciones de Restauración ---

install_essential_utilities() {
    print_header "🔧 Instalando Utilidades Esenciales de Terminal"
    read -p "❓ ¿Deseas instalar un conjunto de utilidades de terminal recomendadas? (s/n): " choice
    if [[ ! "$choice" =~ ^[Ss]$ ]]; then return; fi

    # Lista curada de utilidades. 'build-essential' y 'base-devel' son grupos clave.
    local essential_pkgs
    case $PACKAGE_MANAGER in
        apt) essential_pkgs="build-essential git curl wget tree htop btop tmux net-tools unzip neofetch" ;;
        dnf) essential_pkgs="@development-tools git curl wget tree htop btop tmux net-tools unzip neofetch" ;;
        pacman) essential_pkgs="base-devel git curl wget tree htop btop tmux net-tools unzip neofetch" ;;
    esac

    # Herramientas adicionales que no siempre están en los grupos base
    local additional_utils="ctop" # ctop a menudo es una instalación manual o de terceros

    echo "Instalando: $essential_pkgs"
    $UPDATE_COMMAND
    $INSTALL_COMMAND $essential_pkgs

    echo "Intentando instalar utilidades adicionales..."
    $INSTALL_COMMAND $additional_utils || echo "ℹ️ Algunas utilidades adicionales como 'ctop' pueden requerir instalación manual."
}

restore_dotfiles() {
    local backup_path=$1
    if [ ! -d "$backup_path/dotfiles" ]; then return; fi
    
    print_header "⚙️ Restaurando Configuraciones de Usuario (Dotfiles)"
    read -p "❓ ¿Restaurar configuraciones (.config, .ssh, .gitconfig, etc.)? (s/n): " choice
    if [[ "$choice" =~ ^[Ss]$ ]]; then
        echo "Copiando archivos de configuración..."
        rsync -aiv "$backup_path/dotfiles/" "$HOME/"
    fi
}

restore_gnome_settings() {
    local backup_path=$1
    if [ ! -f "$backup_path/gnome-settings.dconf" ]; then return; fi
    
    print_header "🎨 Restaurando Configuraciones de GNOME"
    read -p "❓ ¿Restaurar apariencia, atajos y configuraciones de GNOME? (s/n): " choice
    if [[ "$choice" =~ ^[Ss]$ ]]; then
        echo "Cargando configuraciones de dconf..."
        dconf load / < "$backup_path/gnome-settings.dconf"
        echo "¡Hecho! Puede que necesites reiniciar sesión para ver todos los cambios."
    fi
}

restore_packages() {
    local backup_path=$1
    local source_pkg_list
    source_pkg_list=$(find "$backup_path" -maxdepth 1 -name "pkglist-*.txt" ! -name "pkglist-flatpak.txt" | head -n 1)

    if [ -z "$source_pkg_list" ]; then return; fi

    local source_pm
    source_pm=$(basename "$source_pkg_list" | sed -e 's/pkglist-//' -e 's/.txt//')
    
    print_header "📦 Reinstalando Paquetes del Sistema"
    echo "Se encontró una lista de paquetes de '$source_pm'. Tu sistema actual usa '$PACKAGE_MANAGER'."

    read -p "❓ ¿Proceder con la instalación de paquetes? (s/n): " choice
    if [[ ! "$choice" =~ ^[Ss]$ ]]; then return; fi
    
    # --- El Diccionario de Traducción ---
    declare -A PKG_MAP
    if [ "$source_pm" = "dnf" ] && [ "$PACKAGE_MANAGER" = "apt" ]; then
        PKG_MAP=(
            ["httpd"]="apache2" ["nginx-mainline"]="nginx" ["mariadb-server"]="mariadb-server"
            ["@development-tools"]="build-essential" ["gcc-c++"]="g++" ["openssl-devel"]="libssl-dev"
            ["libxml2-devel"]="libxml2-dev" ["zlib-devel"]="zlib1g-dev" ["python3-pip"]="python3-pip"
            ["golang"]="golang-go" ["nodejs"]="nodejs" ["npm"]="npm" ["dnf-plugins-core"]="apt-file"
        )
    fi # Puedes añadir más bloques 'elif' para otras conversiones, ej. apt -> dnf

    local packages_to_install=()
    local packages_failed=()

    while IFS= read -r pkg; do
        if [ -n "$pkg" ]; then
            local target_pkg="$pkg"
            if [ -n "${PKG_MAP[$pkg]}" ]; then
                target_pkg=${PKG_MAP[$pkg]}
                echo "맵 Mapeado: '$pkg' -> '$target_pkg'"
            fi
            packages_to_install+=($target_pkg)
        fi
    done < "$source_pkg_list"

    echo -e "\nInstalando ${#packages_to_install[@]} paquetes. Esto puede tardar..."
    $UPDATE_COMMAND
    
    for pkg_to_try in "${packages_to_install[@]}"; do
        if ! $INSTALL_COMMAND "$pkg_to_try" &>/dev/null; then
            packages_failed+=("$pkg_to_try")
        fi
    done

    if [ ${#packages_failed[@]} -ne 0 ]; then
        echo -e "\n--- ⚠️ Paquetes que Fallaron ---"
        echo "Los siguientes paquetes no se pudieron instalar automáticamente:"
        printf "  - %s\n" "${packages_failed[@]}"
        echo "Revisa los nombres y búscalos manualmente en tu nueva distro."
    else
        echo -e "\n✅ ¡Todos los paquetes de la lista se instalaron o ya existían!"
    fi
}

restore_flatpaks() {
    local backup_path=$1
    if [ ! -f "$backup_path/pkglist-flatpak.txt" ]; then return; fi

    print_header "🚀 Reinstalando Aplicaciones Flatpak"
    read -p "❓ ¿Reinstalar todas las aplicaciones Flatpak del backup? (s/n): " choice
    if [[ "$choice" =~ ^[Ss]$ ]]; then
        echo "Instalando Flatpaks..."
        xargs -a "$backup_path/pkglist-flatpak.txt" -r flatpak install -y --noninteractive || true
    fi
}


# --- Script Principal de Restauración ---
main() {
    print_header "Bienvenido al Script de Restauración de Entorno"
    read -ep "Por favor, introduce la ruta COMPLETA a tu carpeta de backup: " backup_path

    if [ ! -d "$backup_path" ]; then
        echo "❌ Error: El directorio '$backup_path' no existe."
        exit 1
    fi
    
    # Flujo de restauración
    install_essential_utilities
    restore_dotfiles "$backup_path"
    restore_gnome_settings "$backup_path"
    restore_packages "$backup_path"
    restore_flatpaks "$backup_path"

    # --- Instrucciones Finales ---
    print_header "✅ ¡Restauración Completada!"
    echo "Se han realizado los siguientes pasos:"
    echo "  - Se instalaron utilidades de terminal esenciales."
    echo "  - Se restauraron tus archivos de configuración."
    echo "  - Se restauraron las configuraciones de GNOME."
    echo "  - Se intentó reinstalar tus paquetes y Flatpaks."
    echo ""
    echo "Tareas manuales recomendadas:"
    echo "  1. Revisa la lista de 'Paquetes que Fallaron' (si la hubo) e instálalos manualmente."
    echo "  2. Abre la tienda de extensiones de GNOME y revisa el archivo"
    echo "     'gnome-extensions-enabled.txt' en tu carpeta de backup para reinstalar tus favoritas."
    echo "  3. **¡REINICIA TU SISTEMA!** Es crucial para que todos los cambios surtan efecto."
}

# Ejecutar el script
main