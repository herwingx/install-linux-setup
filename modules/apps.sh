#!/bin/bash

# --- Funciones de Instalación de Aplicaciones ---

install_basic_utilities() {
    print_header "Instalando Utilidades Básicas de Linux y Git"

    local common_utils=("tree" "unzip" "net-tools" "curl" "wget" "htop" "btop" "grep" "awk" "cut" "paste" "sort" "tr" "head" "tail" "join" "split" "tee"
"nl" "wc" "expand" "unexpand" "uniq")

    echo "Instalando utilidades comunes..."
    for util in "${common_utils[@]}"; do
        if ! check_command "$util"; then
            echo "Instalando $util..."
            run_command "$INSTALL_COMMAND $util"
        else
            echo "$util ya está instalado."
        fi
    done

    echo "Instalando fastfetch..."
    if ! check_command fastfetch; then
        if [ "$PACKAGE_MANAGER" == "apt" ]; then
            sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
            sudo apt update
        fi
        run_command "$INSTALL_COMMAND fastfetch"
    else
        echo "fastfetch ya está instalado."
    fi

    echo "Instalando/Actualizando Git a la última versión..."
    case $PACKAGE_MANAGER in
        apt)
            echo "Añadiendo PPA de git-core para la última versión de Git en sistemas Debian/Ubuntu..."
            run_command "sudo apt install -y software-properties-common"
            run_command "sudo add-apt-repository ppa:git-core/ppa -y"
            run_command "sudo apt update -y"
            run_command "sudo apt install -y git"
            ;;
        *)
            if ! check_command git; then
                run_command "$INSTALL_COMMAND git"
            else
                echo "Git ya está instalado."
            fi
            ;;
    esac
    echo "Git instalado/actualizado. Versión actual:"
    git --version || echo "No se pudo obtener la versión de Git."
}

install_nvm_node_npm() {
    print_header "Instalando NVM (Node Version Manager) y Node.js"

    echo "--- Instalando NVM (Node Version Manager) ---"
    if [ ! -d "$USER_HOME/.nvm" ]; then
        echo "NVM no detectado. Descargando e instalando NVM..."
        if check_command curl; then
            run_command "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
        elif check_command wget; then
            run_command "wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
        else
            echo "Error: Ni curl ni wget están instalados. No se puede instalar NVM." >&2
            return 1
        fi

        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        echo "NVM instalado. Para usarlo, reinicia tu terminal o ejecuta: source ~/.nvm/nvm.sh"
    else
        echo "NVM ya está instalado."
        export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${USER_HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        if ! check_command nvm; then
            echo "Advertencia: NVM existe pero no se pudo cargar en la sesión actual. Intentando forzar carga..."
            source "$NVM_DIR/nvm.sh" || { echo "Error: Falló la carga forzada de NVM."; return 1; }
        fi
    fi

    echo "--- Instalando Node.js (última LTS) y NPM con NVM ---"
    if ! nvm list | grep -q "default -> node"; then
        echo "Instalando la última versión LTS de Node.js..."
        run_command "nvm install node"
        run_command "nvm alias default node"
        echo "Node.js y npm instalados y configurados como predeterminados."
    else
        echo "Una versión de Node.js ya está configurada como predeterminada. Omitiendo instalación de Node.js."
        echo "Si necesitas otra versión, usa 'nvm install <version>' manualmente."
    fi
}

install_docker() {
    print_header "Instalando Docker"
    if check_command docker; then
        echo "Docker ya está instalado."
        return 0
    fi

    run_command "curl -fsSL https://get.docker.com -o get-docker.sh"
    run_command "sh get-docker.sh"
    run_command "rm get-docker.sh"

    run_command "sudo systemctl enable --now docker"
    if ! getent group docker &> /dev/null; then
        run_command "sudo groupadd docker"
    fi
    run_command "sudo usermod -aG docker $USER"
}

install_fonts() {
    print_header "Instalando Fuentes: Cascadia Code y Caskaydia Cove"

    local FONT_DIR="$USER_HOME/.local/share/fonts"
    run_command "mkdir -p \"$FONT_DIR\""

    if ! check_command fc-cache; then
        run_command "$INSTALL_COMMAND fontconfig"
    fi

    local fonts_to_install=(
        "https://github.com/microsoft/cascadia-code/releases/download/v2404.23/CascadiaCode-2404.23.zip"
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CascadiaCode.zip"
    )

    for url in "${fonts_to_install[@]}"; do
        local font_name=$(basename "$url" .zip)
        if fc-list | grep -iq "${font_name//-/ }"; then
            echo "$font_name ya está instalada."
            continue
        fi

        echo "Descargando e instalando $font_name..."
        local zip_file="/tmp/$font_name.zip"
        local extract_dir="/tmp/${font_name}_extracted"

        run_command "wget -q --show-progress -O \"$zip_file\" \"$url\""
        run_command "unzip -o \"$zip_file\" -d \"$extract_dir\""
        run_command "find \"$extract_dir\" -name '*.ttf' -exec cp {} \"$FONT_DIR\" \\;"
        run_command "find \"$extract_dir\" -name '*.otf' -exec cp {} \"$FONT_DIR\" \\;"
        run_command "rm -rf \"$zip_file\" \"$extract_dir\""
    done

    run_command "fc-cache -fv"
}

install_vscode() {
    print_header "Instalando Visual Studio Code"
    if check_command code; then
        echo "Visual Studio Code ya está instalado."
        return 0
    fi

    if check_command snap; then
        run_command "sudo snap install --classic code"
    else
        echo "Snap no está instalado. No se puede instalar VS Code." >&2
        return 1
    fi
}

install_warp_terminal() {
    print_header "Instalando Warp Terminal"
    if check_command warp-terminal; then
        echo "Warp Terminal ya está instalado."
        return 0
    fi

    local WARP_DEB_FILE=$(find . -maxdepth 1 -type f -iname "*warp*terminal*.deb" | head -n 1)
    if [ -n "$WARP_DEB_FILE" ]; then
        run_command "sudo dpkg -i \"$WARP_DEB_FILE\""
        run_command "sudo apt-get install -f -y"
        return 0
    fi

    if check_command snap; then
        run_command "sudo snap install warp-terminal"
    else
        echo "Snap no está instalado. No se puede instalar Warp Terminal." >&2
        return 1
    fi
}

install_rustdesk() {
    print_header "Instalando RustDesk"
    if check_command rustdesk; then
        echo "RustDesk ya está instalado."
        return 0
    fi

    if check_command flatpak; then
        run_command "flatpak install flathub com.rustdesk.RustDesk"
    else
        echo "Flatpak no está instalado. No se puede instalar RustDesk." >&2
        return 1
    fi
}

install_chrome_dev() {
    print_header "Instalando Google Chrome Dev"
    if check_command google-chrome-unstable; then
        echo "Google Chrome Dev ya está instalado."
        return 0
    fi

    if check_command flatpak; then
        run_command "flatpak install flathub com.google.ChromeDev"
    else
        echo "Flatpak no está instalado. No se puede instalar Chrome Dev." >&2
        return 1
    fi
}
