#!/bin/bash

# --- Funciones de Sistema ---

detect_distro_and_package_manager() {
    print_header "Detectando Distribución y Gestor de Paquetes..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID_LIKE="${ID_LIKE}"
        DISTRO="${ID}"
        VERSION_ID="${VERSION_ID}"
        echo "Distribución detectada: $DISTRO (ID_LIKE: $DISTRO_ID_LIKE, Versión: $VERSION_ID)"
    else
        echo "No se pudo detectar la distribución usando /etc/os-release." >&2
        echo "Asumiendo un sistema basado en Debian/Ubuntu como fallback."
        DISTRO="debian"
        DISTRO_ID_LIKE="debian"
        VERSION_ID="unknown"
    fi

    if check_command apt; then
        PACKAGE_MANAGER="apt"
        INSTALL_COMMAND="sudo apt install -y"
        UPDATE_COMMAND="sudo apt update -y"
        REMOVE_COMMAND="sudo apt remove -y"
        echo "Gestor de paquetes detectado: APT"
    elif check_command dnf; then
        PACKAGE_MANAGER="dnf"
        INSTALL_COMMAND="sudo dnf install -y"
        UPDATE_COMMAND="sudo dnf makecache --refresh"
        REMOVE_COMMAND="sudo dnf remove -y"
        echo "Gestor de paquetes detectado: DNF"
    elif check_command pacman; then
        PACKAGE_MANAGER="pacman"
        INSTALL_COMMAND="sudo pacman -S --noconfirm"
        UPDATE_COMMAND="sudo pacman -Sy --noconfirm"
        REMOVE_COMMAND="sudo pacman -R --noconfirm"
        echo "Gestor de paquetes detectado: Pacman"
    elif check_command yum; then
        PACKAGE_MANAGER="yum"
        INSTALL_COMMAND="sudo yum install -y"
        UPDATE_COMMAND="sudo yum makecache fast"
        REMOVE_COMMAND="sudo yum remove -y"
        echo "Gestor de paquetes detectado: YUM"
    elif check_command zypper; then
        PACKAGE_MANAGER="zypper"
        INSTALL_COMMAND="sudo zypper install -y"
        UPDATE_COMMAND="sudo zypper refresh"
        REMOVE_COMMAND="sudo zypper remove -y"
        echo "Gestor de paquetes detectado: Zypper"
    elif check_command apk; then
        PACKAGE_MANAGER="apk"
        INSTALL_COMMAND="sudo apk add --no-cache"
        UPDATE_COMMAND="sudo apk update"
        REMOVE_COMMAND="sudo apk del"
        echo "Gestor de paquetes detectado: APK (Alpine)"
    else
        echo "Error: No se detectó un gestor de paquetes compatible (apt, dnf, pacman, yum, zypper, apk)." >&2
        exit 1
    fi

    if [ -n "$UPDATE_COMMAND" ]; then
        echo "Actualizando índices del gestor de paquetes..."
        run_command "$UPDATE_COMMAND"
    fi
}

update_system() {
    print_header "Actualizando el Sistema"
    echo "Esto actualizará los índices de paquetes y luego realizará un upgrade completo."
    case $PACKAGE_MANAGER in
        apt)
            run_command "sudo apt update -y && sudo apt upgrade -y"
            run_command "sudo apt autoremove -y && sudo apt autoclean"
            ;;
        dnf)
            run_command "sudo dnf update -y"
            run_command "sudo dnf autoremove -y"
            ;;
        pacman)
            run_command "sudo pacman -Syu --noconfirm"
            ;;
        yum)
            run_command "sudo yum update -y"
            run_command "sudo yum autoremove -y"
            ;;
        zypper)
            run_command "sudo zypper refresh && sudo zypper update -y"
            run_command "sudo zypper clean --all"
            ;;
        apk)
            run_command "sudo apk update && sudo apk upgrade"
            ;;
        *)
            echo "El gestor de paquetes '$PACKAGE_MANAGER' no es compatible con la actualización automática." >&2
            echo "Por favor, actualiza tu sistema manualmente."
            return 1
            ;;
    esac
    echo "Sistema actualizado."
}
