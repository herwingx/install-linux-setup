#!/bin/bash

# --- Funciones de Instalación de Nuevas Aplicaciones ---

install_postman() {
    print_header "Instalando Postman"
    if check_command postman; then
        echo "Postman ya está instalado."
        return 0
    fi

    if check_command snap; then
        run_command "sudo snap install postman"
    else
        echo "Snap no está instalado. No se puede instalar Postman." >&2
        return 1
    fi
}

install_dbeaver() {
    print_header "Instalando DBeaver"
    if check_command dbeaver; then
        echo "DBeaver ya está instalado."
        return 0
    fi

    if check_command snap; then
        run_command "sudo snap install dbeaver-ce"
    else
        echo "Snap no está instalado. No se puede instalar DBeaver." >&2
        return 1
    fi
}

install_github_desktop() {
    print_header "Instalando GitHub Desktop"
    if check_command github-desktop; then
        echo "GitHub Desktop ya está instalado."
        return 0
    fi

    if check_command snap; then
        run_command "sudo snap install github-desktop"
    else
        echo "Snap no está instalado. No se puede instalar GitHub Desktop." >&2
        return 1
    fi
}

install_gnome_tweaks() {
    print_header "Instalando Gnome Tweaks"
    if check_command gnome-tweaks; then
        echo "Gnome Tweaks ya está instalado."
        return 0
    fi

    run_command "$INSTALL_COMMAND gnome-tweaks"
}

install_discord() {
    print_header "Instalando Discord"
    if check_command discord; then
        echo "Discord ya está instalado."
        return 0
    fi

    if check_command snap; then
        run_command "sudo snap install discord"
    else
        echo "Snap no está instalado. No se puede instalar Discord." >&2
        return 1
    fi
}

install_spotify() {
    print_header "Instalando Spotify"
    if check_command spotify; then
        echo "Spotify ya está instalado."
        return 0
    fi

    if check_command snap; then
        run_command "sudo snap install spotify"
    else
        echo "Snap no está instalado. No se puede instalar Spotify." >&2
        return 1
    fi
}

install_protonvpn() {
    print_header "Instalando ProtonVPN"
    if check_command protonvpn-cli; then
        echo "ProtonVPN ya está instalado."
        return 0
    fi

    run_command "wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.3_all.deb -O /tmp/protonvpn.deb"
    run_command "sudo dpkg -i /tmp/protonvpn.deb"
    run_command "sudo apt update"
    run_command "sudo apt install -y protonvpn-cli"
    run_command "rm /tmp/protonvpn.deb"
}

install_nordvpn() {
    print_header "Instalando NordVPN"
    if check_command nordvpn; then
        echo "NordVPN ya está instalado."
        return 0
    fi

    run_command "wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh | sh"
}
