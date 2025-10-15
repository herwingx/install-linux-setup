#!/bin/bash
set -e # Salir inmediatamente si un comando falla

# --- Variables Globales ---
DISTRO=""
PACKAGE_MANAGER=""
INSTALL_COMMAND=""
UPDATE_COMMAND="" # Solo para índices, upgrade se manejará en update_system
REMOVE_COMMAND="" # No usado directamente en este script, pero útil para la lógica
USER_HOME="$HOME" # Asegura que HOME esté definido

# Verificar requisitos al inicio
check_system_requirements

# Asegurar limpieza al salir
trap cleanup_temp_files EXIT

# --- Funciones de Ayuda ---

check_system_requirements() {
    print_header "Verificando requisitos del sistema"
    
    # Verificar arquitectura
    local ARCH=$(uname -m)
    echo "Arquitectura detectada: $ARCH"
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
        echo "⚠️  Advertencia: Este script está optimizado para arquitecturas x86_64/amd64."
        echo "    Algunas funciones podrían no estar disponibles en $ARCH."
        read -p "¿Deseas continuar? (y/N): " continue_arch
        if [[ ! "$continue_arch" =~ ^[Yy]$ ]]; then
            echo "Instalación cancelada por el usuario."
            exit 1
        fi
    fi

    # Verificar espacio en disco
    local SPACE_AVAILABLE=$(df -k / | tail -1 | awk '{print $4}')
    local SPACE_GB=$((SPACE_AVAILABLE / 1024 / 1024))
    echo "Espacio disponible: ${SPACE_GB}GB"
    if [ $SPACE_GB -lt 10 ]; then
        echo "⚠️  Advertencia: Se recomienda tener al menos 10GB de espacio libre."
        echo "    Espacio actual: ${SPACE_GB}GB"
        read -p "¿Deseas continuar? (y/N): " continue_space
        if [[ ! "$continue_space" =~ ^[Yy]$ ]]; then
            echo "Instalación cancelada por el usuario."
            exit 1
        fi
    fi

    # Verificar memoria RAM
    local TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    echo "Memoria RAM total: ${TOTAL_RAM}GB"
    if [ $TOTAL_RAM -lt 4 ]; then
        echo "⚠️  Advertencia: Se recomienda tener al menos 4GB de RAM."
        echo "    RAM actual: ${TOTAL_RAM}GB"
        read -p "¿Deseas continuar? (y/N): " continue_ram
        if [[ ! "$continue_ram" =~ ^[Yy]$ ]]; then
            echo "Instalación cancelada por el usuario."
            exit 1
        fi
    fi

    echo "✓ Verificación de requisitos completada."
}

cleanup_temp_files() {
    print_header "Limpiando archivos temporales"
    
    # Limpiar archivos temporales
    local temp_files=(
        "/tmp/CascadiaCode.zip"
        "/tmp/CascadiaCodeNerd.zip"
        "/tmp/CascadiaCode_extracted"
        "/tmp/CascadiaCodeNerd_extracted"
        "/tmp/packages.microsoft.gpg"
    )

    for file in "${temp_files[@]}"; do
        if [ -e "$file" ]; then
            echo "Eliminando $file..."
            rm -rf "$file"
        fi
    done

    echo "✓ Limpieza completada."
}

print_header() {
    echo -e "\n=============================================="
    echo -e "  $1"
    echo -e "==============================================\n"
}

run_command() {
    echo "Ejecutando: $1"
    if ! eval "$1"; then
        echo "Error: El comando '$1' falló." >&2
        return 1
    fi
}

detect_distro_and_package_manager() {
    print_header "Detectando Distribución y Gestor de Paquetes..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID_LIKE="${ID_LIKE:-$ID}" # Use ID_LIKE or fallback to ID
        DISTRO="${ID}" # e.g., "ubuntu", "fedora", "debian", "zorin"
        VERSION_ID="${VERSION_ID}" # e.g., "22.04", "11", "39"
        echo "Distribución detectada: $DISTRO (ID_LIKE: $DISTRO_ID_LIKE, Versión: $VERSION_ID)"
    else
        echo "No se pudo detectar la distribución usando /etc/os-release." >&2
        echo "Asumiendo un sistema basado en Debian/Ubuntu como fallback."
        DISTRO="debian" # Fallback
        DISTRO_ID_LIKE="debian"
        VERSION_ID="unknown"
    fi

    # Special case for Zorin OS
    if [ -f /etc/os-release ] && grep -qi "zorin" /etc/os-release; then
        DISTRO="zorin"
        DISTRO_ID_LIKE="debian"
        PACKAGE_MANAGER="apt"
        INSTALL_COMMAND="sudo apt install -y"
        UPDATE_COMMAND="sudo apt update -y"
        REMOVE_COMMAND="sudo apt remove -y"
        echo "Distribución detectada: Zorin OS"
        echo "Gestor de paquetes: APT"
    elif [ "$DISTRO" = "zorin" ] || [ "$DISTRO_ID_LIKE" = "zorin" ]; then
        echo "Detectado Zorin OS por ID o ID_LIKE"
        DISTRO="zorin"
        DISTRO_ID_LIKE="debian"
        PACKAGE_MANAGER="apt"
        INSTALL_COMMAND="sudo apt install -y"
        UPDATE_COMMAND="sudo apt update -y"
        REMOVE_COMMAND="sudo apt remove -y"
    elif command -v apt &> /dev/null; then
        PACKAGE_MANAGER="apt"
        INSTALL_COMMAND="sudo apt install -y"
        UPDATE_COMMAND="sudo apt update -y"
        REMOVE_COMMAND="sudo apt remove -y"
        echo "Gestor de paquetes detectado: APT"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
        INSTALL_COMMAND="sudo dnf install -y"
        UPDATE_COMMAND="sudo dnf makecache --refresh" # Only refresh cache for dnf
        REMOVE_COMMAND="sudo dnf remove -y"
        echo "Gestor de paquetes detectado: DNF"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
        INSTALL_COMMAND="sudo pacman -S --noconfirm"
        UPDATE_COMMAND="sudo pacman -Sy --noconfirm" # Sync only, update_system will do full sync+upgrade
        REMOVE_COMMAND="sudo pacman -R --noconfirm"
        echo "Gestor de paquetes detectado: Pacman"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
        INSTALL_COMMAND="sudo yum install -y"
        UPDATE_COMMAND="sudo yum makecache fast"
        REMOVE_COMMAND="sudo yum remove -y"
        echo "Gestor de paquetes detectado: YUM"
    elif command -v zypper &> /dev/null; then
        PACKAGE_MANAGER="zypper"
        INSTALL_COMMAND="sudo zypper install -y"
        UPDATE_COMMAND="sudo zypper refresh" # Only refresh, update_system will do full
        REMOVE_COMMAND="sudo zypper remove -y"
        echo "Gestor de paquetes detectado: Zypper"
    elif command -v apk &> /dev/null; then
        PACKAGE_MANAGER="apk"
        INSTALL_COMMAND="sudo apk add --no-cache"
        UPDATE_COMMAND="sudo apk update"
        REMOVE_COMMAND="sudo apk del"
        echo "Gestor de paquetes detectado: APK (Alpine)"
    else
        echo "Error: No se detectó un gestor de paquetes compatible (apt, dnf, pacman, yum, zypper, apk)." >&2
        exit 1
    fi

    # Actualizar los índices del gestor de paquetes al inicio
    if [ -n "$UPDATE_COMMAND" ]; then
        echo "Actualizando índices del gestor de paquetes..."
        run_command "$UPDATE_COMMAND"
    fi
}

# --- Funciones de Instalación de Aplicaciones y Configuración ---

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

install_basic_utilities() {
    print_header "Instalando Utilidades Básicas de Linux y Git"

    local common_utils=(
        "tree" "unzip" "net-tools" "curl" "wget" "htop" "btop" "grep" "awk" "cut" "paste" "sort" "tr"
        "head" "tail" "join" "split" "tee" "nl" "wc" "expand" "unexpand" "uniq"
    )

    echo "Instalando utilidades comunes..."
    for util in "${common_utils[@]}"; do
        if ! command -v "$util" &> /dev/null; then
            echo "Instalando $util..."
            run_command "$INSTALL_COMMAND $util"
        else
            echo "$util ya está instalado."
        fi
    done

    # --- TLDR ---
    if ! command -v tldr &> /dev/null; then
        echo "tldr no encontrado, intentando instalar..."
        case $PACKAGE_MANAGER in
            apt|dnf|zypper|pacman|yum|apk)
                run_command "$INSTALL_COMMAND tldr" || true
                ;;
        esac
        if ! command -v tldr &> /dev/null; then
            echo "tldr no disponible en repositorio, intentando instalar con pipx..."
            if ! command -v pipx &> /dev/null; then
                run_command "$INSTALL_COMMAND pipx" || run_command "$INSTALL_COMMAND python3-pip"
                python3 -m pip install --user pipx
                python3 -m pipx ensurepath
                export PATH="$HOME/.local/bin:$PATH"
            fi
            pipx install tldr || python3 -m pip install --user tldr
        fi
    fi
    if command -v tldr &> /dev/null; then
        echo "Actualizando caché de tldr..."
        tldr --update || true
    fi

    # --- SCRCPY ---
    if ! command -v scrcpy &> /dev/null; then
        echo "scrcpy no encontrado, intentando instalar..."
        case $PACKAGE_MANAGER in
            apt|dnf|zypper|pacman|yum|apk)
                run_command "$INSTALL_COMMAND scrcpy" || true
                ;;
        esac
        if ! command -v scrcpy &> /dev/null; then
            echo "scrcpy no disponible en repositorio. Instalando versión portable 64 bits..."
            LATEST_URL=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | grep "browser_download_url.*linux64" | cut -d '"' -f 4 | head -n1)
            if [ -n "$LATEST_URL" ]; then
                TMP_DIR=$(mktemp -d)
                cd "$TMP_DIR"
                curl -LO "$LATEST_URL"
                tar xzf scrcpy-*-linux64.tar.gz
                sudo cp scrcpy-*-linux64/scrcpy /usr/local/bin/
                sudo chmod +x /usr/local/bin/scrcpy
                cd -
                rm -rf "$TMP_DIR"
                echo "scrcpy instalado en /usr/local/bin"
            else
                echo "No se pudo descargar scrcpy. Instálalo manualmente desde https://github.com/Genymobile/scrcpy"
            fi
        fi
    fi

    # Instalación de fastfetch
    echo "Instalando fastfetch..."
    case $DISTRO in
        ubuntu|zorin)
            if lsb_release -r -s | grep -qE "^2[2-9]\." || [ "$DISTRO" = "zorin" ]; then
                echo "Detectado $DISTRO basado en Ubuntu 22.04+ o superior. Usando PPA para fastfetch."
                run_command "sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y"
                run_command "sudo apt update -y"
                run_command "sudo apt install -y fastfetch"
            else
                echo "Versión anterior de $DISTRO. Intentando instalar fastfetch desde el repositorio estándar."
                run_command "$INSTALL_COMMAND fastfetch"
            fi
            ;;
        debian)
            if [ "$(echo "$VERSION_ID >= 13" | bc -l)" -eq 1 ]; then
                echo "Detectado Debian 13+ o superior. Usando apt install fastfetch."
                run_command "$INSTALL_COMMAND fastfetch"
            else
                echo "Debian versión anterior. Instalando fastfetch desde el repositorio backports."
                run_command "sudo apt install -t $(lsb_release -cs)-backports fastfetch -y"
            fi
            ;;
        fedora)
            run_command "$INSTALL_COMMAND fastfetch"
            ;;
        arch)
            run_command "$INSTALL_COMMAND fastfetch"
            ;;
        opensuse)
            run_command "$INSTALL_COMMAND fastfetch"
            ;;
        alpine)
            run_command "apk add fastfetch"
            ;;
        *)
            echo "Distribución no soportada específicamente. Intentando instalación genérica de fastfetch..."
            if command -v apt &> /dev/null; then
                run_command "$INSTALL_COMMAND fastfetch"
            elif command -v dnf &> /dev/null; then
                run_command "$INSTALL_COMMAND fastfetch"
            elif command -v pacman &> /dev/null; then
                run_command "$INSTALL_COMMAND fastfetch"
            else
                echo "No se pudo determinar el gestor de paquetes. Por favor, instala fastfetch manualmente."
                echo "Puedes encontrarlo en: https://github.com/fastfetch-cli/fastfetch"
            fi
            ;;
    esac

    # Instalación/Actualización de Git a la última versión
    echo "Instalando/Actualizando Git a la última versión..."
    case $PACKAGE_MANAGER in
        apt)
            echo "Añadiendo PPA de git-core para la última versión de Git en sistemas Debian/Ubuntu..."
            run_command "sudo apt install -y software-properties-common"
            run_command "sudo add-apt-repository ppa:git-core/ppa -y"
            run_command "sudo apt update -y"
            run_command "sudo apt install -y git"
            ;;
        dnf)
            echo "Instalando/Actualizando Git con dnf en Fedora/RHEL..."
            run_command "sudo dnf install -y git"
            ;;
        pacman)
            echo "Instalando/Actualizando Git con pacman en Arch Linux..."
            run_command "sudo pacman -S --noconfirm git"
            ;;
        zypper)
            echo "Instalando/Actualizando Git con zypper en openSUSE..."
            run_command "sudo zypper install -y git"
            ;;
        apk)
            echo "Instalando/Actualizando Git con apk en Alpine..."
            run_command "sudo apk add --no-cache git"
            ;;
        *)
            echo "Gestor de paquetes $PACKAGE_MANAGER para Git no soportado para la última versión (intentando versión predeterminada)."
            run_command "$INSTALL_COMMAND git"
            ;;
    esac
    echo "Git instalado/actualizado. Versión actual:"
    git --version || echo "No se pudo obtener la versión de Git."
}

configure_gitconfig() {
    print_header "Configurando .gitconfig"
    local GITCONFIG_PATH="$USER_HOME/.gitconfig"

    if [ -f "$GITCONFIG_PATH" ]; then
        echo "Archivo $GITCONFIG_PATH existente detectado. Se borrará y reemplazará."
        run_command "rm -f \"$GITCONFIG_PATH\""
    else
        echo "Archivo $GITCONFIG_PATH no encontrado. Se creará uno nuevo."
    fi

    # Usar un email y nombre predefinidos, como solicitó el usuario.
    cat > "$GITCONFIG_PATH" <<EOF
[user]
	name = Eduardo Macias
	email = herwingbussiness@gmail.com
[init]
	defaultBranch = main
[alias]
	s = status -s -b
	lg = log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all
	edit = commit --amend
	clone-shallow = clone --depth 1
[pull]
	rebase = true
[core]
	editor = code --wait
EOF

    echo "Configuración .gitconfig creada/actualizada en $GITCONFIG_PATH"
    echo "Verifica con: cat ~/.gitconfig"
}

generate_ssh_key() {
    print_header "Generando Clave SSH"
    local SSH_KEY_PATH="$USER_HOME/.ssh/id_rsa"
    
    if [ -f "$SSH_KEY_PATH" ]; then
        echo "Advertencia: Ya existe una clave SSH en $SSH_KEY_PATH."
        read -p "¿Deseas sobreescribirla? (y/N): " overwrite_key
        if [[ ! "$overwrite_key" =~ ^[Yy]$ ]]; then
            echo "Generación de clave SSH cancelada. Usando clave existente."
            return 0
        fi
        echo "Sobreescribiendo clave existente..."
        run_command "rm -f \"$SSH_KEY_PATH\" \"${SSH_KEY_PATH}.pub\""
    fi

    read -p "Por favor, introduce tu dirección de correo electrónico para la clave SSH (ej. your_email@example.com): " SSH_EMAIL
    
    if [ -z "$SSH_EMAIL" ]; then
        echo "Error: Correo electrónico no proporcionado. La generación de clave SSH fue cancelada." >&2
        return 1
    fi

    echo "Generando clave SSH RSA de 4096 bits para $SSH_EMAIL..."
    run_command "ssh-keygen -t rsa -b 4096 -C \"$SSH_EMAIL\""

    echo "Clave SSH generada en $SSH_KEY_PATH"
    echo "Para añadir tu clave SSH al agente y usarla:"
    echo "  eval \"\$(ssh-agent -s)\""
    echo "  ssh-add ~/.ssh/id_rsa"
    echo "Para añadir tu clave pública a servicios como GitHub/GitLab/Bitbucket, copia el contenido de:"
    echo "  cat ~/.ssh/id_rsa.pub"
    echo "Y pégalo en la sección de claves SSH de tu perfil."
}

add_bash_aliases() {
    print_header "Añadiendo Alias a .bashrc"
    local BASHRC_PATH="$USER_HOME/.bashrc"
    local aliases=(
        "# System utilities"
        "alias size='du -h --max-depth=1 ~/'"
        "alias storage='df -h'"
        "alias up='sudo apt update && sudo apt upgrade -y'"
        "alias list-size='du -h --max-depth=1 | sort -hr'"
        "alias waydroid='waydroid show-full-ui'"
        "alias off='sudo shutdown now'"
        "alias rb='sudo reboot now'"
        "alias tldr='tldr --color=always'"
        "
        # Git aliases"
        "alias gs='git status'"
        "alias ga='git add'"
        "alias gc='git commit -m'"
        "alias gp='git push'"
        "alias gl='git pull'"
    )

    echo "Añadiendo alias a $BASHRC_PATH..."
    for alias_line in "${aliases[@]}"; do
        if ! grep -qF "$alias_line" "$BASHRC_PATH"; then
            echo "$alias_line" >> "$BASHRC_PATH"
            echo "  Añadido: $alias_line"
        else
            echo "  Ya existe: $alias_line (omitido)"
        fi
    done

    echo "Alias añadidos/verificados en .bashrc."
    echo "Para que los nuevos alias surtan efecto en la sesión actual, ejecuta: source ~/.bashrc"
}

install_nvm_node_npm() {
    print_header "Instalando NVM (Node Version Manager) y Node.js"

    echo "--- Instalando NVM (Node Version Manager) ---"
    if [ ! -d "$USER_HOME/.nvm" ]; then
        echo "NVM no detectado. Descargando e instalando NVM..."
        if command -v curl &> /dev/null; then
            run_command "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
        elif command -v wget &> /dev/null; then
            run_command "wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
        else
            echo "Error: Ni curl ni wget están instalados. No se puede instalar NVM." >&2
            return 1
        fi

        # Cargar NVM para que esté disponible en esta sesión de script
        export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${USER_HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # Esto carga nvm
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # Esto carga nvm bash_completion

        echo "NVM instalado. Cargando NVM en la sesión actual..."
        if ! command -v nvm &> /dev/null; then
            echo "Error: NVM no se pudo cargar en la sesión actual. Por favor, reinicia tu terminal o verifica la instalación manual." >&2
            return 1
        fi
        echo "NVM cargado exitosamente."
    else
        echo "NVM ya está instalado."
        # Asegurarse de que NVM esté cargado si ya existía
        export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${USER_HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        if ! command -v nvm &> /dev/null; then
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

    echo "Para que NVM y Node.js estén disponibles en nuevas sesiones de terminal, es posible que necesites reiniciar tu terminal o ejecutar 'source 
~/.bashrc' (o tu archivo de configuración de shell)."
}

install_nodejs_global_without_nvm() {
    print_header "Instalando Node.js y NPM Globalmente (sin NVM)"
    echo "¡Advertencia! Esta opción instala Node.js directamente con el gestor de paquetes de tu sistema."
    echo "No se recomienda usarla si ya estás utilizando NVM, ya que puede causar conflictos."
    echo "Asegúrate de que esta es la opción que deseas."
    read -p "¿Deseas continuar? (y/N): " confirm_global_node
    if [[ ! "$confirm_global_node" =~ ^[Yy]$ ]]; then
        echo "Instalación de Node.js global cancelada."
        return 1
    fi

    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "Configurando repositorio NodeSource para Node.js LTS en Debian/Ubuntu..."
            run_command "sudo apt-get update"
            run_command "sudo apt-get install -y ca-certificates curl gnupg lsb-release"
            
            # Limpiar cualquier configuración NodeSource previa para evitar duplicados
            if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
                echo "Eliminando configuración NodeSource previa..."
                run_command "sudo rm /etc/apt/sources.list.d/nodesource.list"
            fi
            if [ -f /etc/apt/keyrings/nodesource.gpg ]; then
                echo "Eliminando clave GPG NodeSource previa..."
                run_command "sudo rm /etc/apt/keyrings/nodesource.gpg"
            fi

            # Añadir nueva clave GPG de NodeSource (usando la nueva ruta para keyrings)
            run_command "sudo mkdir -p /etc/apt/keyrings"
            run_command "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.d/nodesource.gpg | sudo tee /etc/apt/keyrings/nodesource.gpg 
>/dev/null"
            run_command "sudo chmod a+r /etc/apt/keyrings/nodesource.gpg"

            # Detectar codename
            local DISTRO_CODENAME=""
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO_CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
            fi

            if [ -z "$DISTRO_CODENAME" ]; then
                echo "Error: No se pudo determinar el codename de la distribución. La instalación de Node.js podría fallar." >&2
                return 1
            fi

            # Añadir repositorio NodeSource
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x ${DISTRO_CODENAME} main" | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null
            echo "deb-src [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x ${DISTRO_CODENAME} main" | sudo tee -a /etc/apt/sources.list.d/nodesource.list >/dev/null
            
            run_command "sudo apt-get update -y"
            run_command "sudo apt-get install -y nodejs" # Esto instala nodejs y npm
            ;;
        fedora)
            echo "Instalando Node.js y NPM con DNF en Fedora..."
            run_command "sudo dnf install -y nodejs npm"
            ;;
        arch)
            echo "Instalando Node.js y NPM con pacman en Arch Linux..."
            run_command "sudo pacman -S --noconfirm nodejs npm"
            ;;
        opensuse)
            echo "Instalando Node.js y NPM con zypper en openSUSE..."
            run_command "sudo zypper install -y nodejs npm"
            ;;
        alpine)
            echo "Instalando Node.js y NPM con apk en Alpine..."
            run_command "sudo apk add --no-cache nodejs npm"
            ;;
        *)
            echo "Instalación de Node.js global para $DISTRO no implementada con este método." >&2
            return 1
            ;;
    esac
    echo "Node.js y NPM instalados globalmente. Versiones:"
    node -v || true
    npm -v || true
    echo "Recuerda que Node.js instalado globalmente podría entrar en conflicto con NVM."
}


check_node_npm_dependency() {
    # Preferimos la versión de Node.js de NVM si está instalada y cargada
    if command -v nvm &> /dev/null && [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh" # Asegurar que NVM esté cargado en la subshell
        if nvm current &> /dev/null && command -v node &> /dev/null && command -v npm &> /dev/null; then
            return 0
        fi
    fi

    # Si NVM no está presente o no tiene Node.js, verificar la instalación global
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        return 0
    fi

    echo "Advertencia: Node.js y/o NPM no están instalados o no se encuentran en el PATH." >&2
    echo "Esta aplicación requiere Node.js. Por favor, instala Node.js (se recomienda usar NVM o la opción Global)."
    echo "Puedes seleccionarlo en el menú principal."
    return 1
}

install_gemini_cli() {
    print_header "Instalando Gemini CLI"
    if ! check_node_npm_dependency; then
        return 1
    fi
    echo "Node.js y NPM detectados. Procediendo con la instalación de Gemini CLI via npm."
    run_command "npm install -g @google/gemini-cli"
    echo "Gemini CLI instalado. Ejecuta 'gemini --help' para empezar."
}

install_github_cli() {
    print_header "Instalando GitHub CLI (gh)"
    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "Instalando GitHub CLI para distros basadas en Debian/Ubuntu..."
            # Asegurar que wget esté instalado
            if ! command -v wget &> /dev/null; then
                run_command "sudo apt update && sudo apt install wget -y"
            fi
            run_command "sudo mkdir -p -m 755 /etc/apt/keyrings"
            TEMP_KEYRING_FILE=$(mktemp)
            run_command "wget -nv -O$TEMP_KEYRING_FILE https://cli.github.com/packages/githubcli-archive-keyring.gpg"
            run_command "cat $TEMP_KEYRING_FILE | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null"
            run_command "rm $TEMP_KEYRING_FILE"
            run_command "sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg"
            run_command "sudo mkdir -p -m 755 /etc/apt/sources.list.d"
            run_command "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
            run_command "sudo apt update -y"
            run_command "sudo apt install -y gh"
            ;;
        fedora)
            echo "Instalando GitHub CLI para Fedora..."
            run_command "sudo dnf install -y dnf-plugins-core" # dnf-command(config-manager)
            if command -v dnf5 &> /dev/null; then
                echo "Detectado DNF5."
                run_command "sudo dnf5 config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo"
                run_command "sudo dnf5 install -y gh --repo gh-cli"
            else
                echo "Detectado DNF4."
                run_command "sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo"
                run_command "sudo dnf install -y gh --repo gh-cli"
            fi
            ;;
        arch)
            echo "Instalando GitHub CLI con pacman en Arch Linux..."
            run_command "sudo pacman -S --noconfirm github-cli"
            ;;
        opensuse)
            echo "Instalando GitHub CLI con zypper en openSUSE..."
            run_command "sudo zypper install -y github-cli"
            ;;
        *)
            echo "Instalación de GitHub CLI para $DISTRO no implementada o no oficial." >&2
            return 1
            ;;
    esac
    echo "GitHub CLI (gh) instalado. Ejecuta 'gh --version' para verificar."
}

install_bitwarden_cli() {
    print_header "Instalando Bitwarden CLI"
    if ! check_node_npm_dependency; then
        return 1
    fi
    echo "Node.js y NPM detectados. Procediendo con la instalación de Bitwarden CLI via npm."
    run_command "npm install -g @bitwarden/cli"
    echo "Bitwarden CLI (bw) instalado. Ejecuta 'bw --help' para empezar."
}

install_tailscale() {
    print_header "Instalando Tailscale"
    
    case $DISTRO in
        ubuntu|debian|kali|parrot|zorin)
            echo "Instalando Tailscale para Debian/Ubuntu/Zorin usando repositorio oficial..."
            
            # Instalar dependencias necesarias
            run_command "sudo apt update -y"
            run_command "sudo apt install -y curl gpg software-properties-common apt-transport-https"
            
            # Añadir clave GPG de Tailscale usando el nuevo método
            echo "Añadiendo clave GPG de Tailscale..."
            run_command "curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null"
            
            # Añadir repositorio de Tailscale
            echo "Configurando repositorio de Tailscale..."
            run_command "curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list"
            
            # Actualizar e instalar Tailscale
            run_command "sudo apt update -y"
            run_command "sudo apt install -y tailscale"
            ;;
            
        fedora)
            echo "Instalando Tailscale para Fedora..."
            run_command "sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo"
            run_command "sudo dnf install -y tailscale"
            ;;
            
        arch|manjaro)
            echo "Instalando Tailscale para Arch Linux..."
            run_command "sudo pacman -S --noconfirm tailscale"
            ;;
            
        opensuse|sles)
            echo "Instalando Tailscale para openSUSE..."
            run_command "sudo zypper addrepo https://pkgs.tailscale.com/stable/opensuse/15.4/tailscale.repo"
            run_command "sudo zypper refresh"
            run_command "sudo zypper install -y tailscale"
            ;;
            
        alpine)
            echo "Instalando Tailscale para Alpine Linux..."
            run_command "echo 'https://pkgs.tailscale.com/stable/alpine/tailscale.repo' | sudo tee -a /etc/apk/repositories"
            run_command "wget -qO /etc/apk/keys/pkgs.tailscale.com.rsa.pub https://pkgs.tailscale.com/stable/alpine/tailscale.rsa.pub"
            run_command "sudo apk update"
            run_command "sudo apk add --no-cache tailscale"
            ;;
            
        *)
            echo "Distribución $DISTRO no soportada específicamente. Usando script de instalación oficial..."
            if ! command -v curl &> /dev/null; then
                echo "Error: 'curl' no está instalado. Por favor, instala curl para poder instalar Tailscale." >&2
                return 1
            fi
            run_command "curl -fsSL https://tailscale.com/install.sh | sh"
            ;;
    esac
    
    # Habilitar el servicio
    echo "Habilitando servicio de Tailscale..."
    run_command "sudo systemctl enable --now tailscaled"
    
    echo "✓ Tailscale ha sido instalado correctamente."
    echo "Para iniciar y autenticar Tailscale, ejecuta:"
    echo "  sudo tailscale up"
    echo "Sigue las instrucciones en el navegador para autenticarte con tu cuenta de Tailscale."
}

install_brave_browser() {
    print_header "Instalando Brave Browser"
    echo "Descargando y ejecutando el script de instalación oficial de Brave..."
    if ! command -v curl &> /dev/null; then
        echo "Error: 'curl' no está instalado. Por favor, instala curl para poder instalar Brave Browser." >&2
        return 1
    fi
    run_command "curl -fsS https://dl.brave.com/install.sh | sh"
    echo "Brave Browser ha sido instalado."
    echo "Puedes iniciarlo desde el menú de aplicaciones o ejecutando 'brave-browser' en la terminal."
}

install_cursor_appimage() {
    print_header "Instalando Cursor (AI Code Editor) AppImage"
    
    echo "📁 NOTA: Esta función busca archivos AppImage de Cursor en el directorio actual."
    echo ""
    echo "💾 Para instalar Cursor necesitas:"
    echo "  • Archivo AppImage de Cursor (ej: Cursor-*.AppImage)"
    echo "  • Descarga desde: https://cursor.com/en/downloads"
    echo "  • Coloca el archivo en este directorio: $(pwd)"
    echo ""
    echo "📋 Nombres de archivo esperados:"
    echo "  • Cursor-0.x.x-x86_64.AppImage"
    echo "  • cursor-latest.AppImage"
    echo "  • Cursor.AppImage"
    echo ""

    # Verificar si Cursor ya está instalado
    if [ -f "/opt/cursor.appimage" ]; then
        echo "✓ Cursor ya está instalado en /opt/cursor.appimage"
        read -p "¿Deseas reinstalar Cursor? (y/N): " reinstall_cursor
        if [[ ! "$reinstall_cursor" =~ ^[Yy]$ ]]; then
            echo "Instalación de Cursor cancelada."
            return 0
        fi
        echo "Procediendo con la reinstalación..."
        echo ""
    fi

    # 1. Buscar el archivo AppImage en el directorio actual
    local CURSOR_APPIMAGE_SOURCE=$(find . -maxdepth 1 -type f -iname "Cursor*.AppImage" | head -n 1)

    if [ -z "$CURSOR_APPIMAGE_SOURCE" ]; then
        echo "❌ Error: No se encontró ningún archivo Cursor AppImage en el directorio actual."
        echo ""
        echo "📥 Para instalar Cursor:"
        echo "1. Visita https://cursor.com/en/downloads"
        echo "2. Descarga la versión AppImage para Linux (x64)"
        echo "3. Coloca el archivo en este directorio: $(pwd)"
        echo "4. Ejecuta nuevamente esta opción"
        echo ""
        echo "🔍 El script buscará archivos con nombres como:"
        echo "  • Cursor-*.AppImage"
        echo "  • cursor*.AppImage (cualquier variación)"
        echo ""
        echo "💡 Tip: Asegúrate de que el archivo tenga permisos de lectura"
        echo "       y no esté corrupto (debería ser ~100MB o más)"
        return 1
    fi

    echo "✓ AppImage de Cursor encontrado: $CURSOR_APPIMAGE_SOURCE"
    
    # Verificar tamaño del archivo (AppImage de Cursor debe ser relativamente grande)
    local file_size=$(du -m "$CURSOR_APPIMAGE_SOURCE" | cut -f1)
    if [ "$file_size" -lt 50 ]; then
        echo "⚠️  Advertencia: El archivo es muy pequeño ($file_size MB)."
        echo "    Un AppImage típico de Cursor debería ser ~100MB o más."
        read -p "¿Deseas continuar de todos modos? (y/N): " continue_small
        if [[ ! "$continue_small" =~ ^[Yy]$ ]]; then
            echo "Instalación cancelada. Verifica que descargaste el archivo correcto."
            return 1
        fi
    else
        echo "✓ Tamaño del archivo verificado: ${file_size}MB"
    fi
    echo ""

    # 2. Instalar dependencia FUSE
    echo "=== Instalando dependencias necesarias ==="
    echo "Verificando e instalando dependencia FUSE (requerida para AppImages)..."
    case $PACKAGE_MANAGER in
        apt)
            run_command "sudo apt update -y"
            run_command "sudo apt install -y libfuse2"
            ;;
        dnf)
            run_command "sudo dnf install -y fuse-libs" # Para Fedora/RHEL
            ;;
        pacman)
            run_command "sudo pacman -S --noconfirm fuse2" # Para Arch
            ;;
        zypper)
            run_command "sudo zypper install -y fuse-libs" # Para openSUSE
            ;;
        apk)
            run_command "sudo apk add --no-cache fuse2-libs" # Para Alpine
            ;;
        *)
            echo "⚠️  Advertencia: La instalación automática de FUSE para $PACKAGE_MANAGER no está implementada."
            echo "    Podría ser necesaria la instalación manual de libfuse2/fuse-libs/fuse2."
            echo "    Si Cursor no funciona después de la instalación, instala FUSE manualmente."
            ;;
    esac

    # 3. Mover y hacer ejecutable
    echo ""
    echo "=== Instalando Cursor AppImage ==="
    echo "Moviendo Cursor AppImage a /opt/cursor.appimage..."
    
    # Hacer backup si ya existe
    if [ -f "/opt/cursor.appimage" ]; then
        run_command "sudo mv /opt/cursor.appimage /opt/cursor.appimage.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✓ Backup del Cursor anterior creado"
    fi
    
    run_command "sudo mv \"$CURSOR_APPIMAGE_SOURCE\" /opt/cursor.appimage"
    run_command "sudo chmod +x /opt/cursor.appimage"
    echo "✓ Cursor AppImage instalado en /opt/cursor.appimage"

    # 4. Crear symlink para comando global
    echo "Creando comando global 'cursor'..."
    if [ -L "/usr/local/bin/cursor" ] || [ -f "/usr/local/bin/cursor" ]; then
        run_command "sudo rm -f /usr/local/bin/cursor"
    fi
    run_command "sudo ln -sf /opt/cursor.appimage /usr/local/bin/cursor"
    echo "✓ Comando 'cursor' disponible globalmente"

    # 5. Crear entrada de escritorio
    echo "Creando entrada de escritorio para Cursor..."
    local CURSOR_DESKTOP_ENTRY="/usr/share/applications/cursor.desktop"
    sudo bash -c "cat > $CURSOR_DESKTOP_ENTRY << EOF
[Desktop Entry]
Name=Cursor
Comment=AI-powered code editor
Exec=/opt/cursor.appimage --no-sandbox %F
Icon=cursor
Type=Application
Categories=Development;IDE;TextEditor;
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;
StartupNotify=true
StartupWMClass=cursor
EOF"
    run_command "sudo chmod 644 $CURSOR_DESKTOP_ENTRY"
    echo "✓ Entrada de escritorio creada"

    # 6. Intentar extraer icono (opcional)
    echo ""
    echo "=== Configuración adicional ==="
    echo "Intentando configurar icono de Cursor..."
    
    # Verificar si AppImage tiene herramientas de extracción
    if /opt/cursor.appimage --appimage-help &>/dev/null; then
        echo "Extrayendo icono desde el AppImage..."
        if /opt/cursor.appimage --appimage-extract "*.png" 2>/dev/null | head -1; then
            local ICON_FILE=$(find squashfs-root -name "*.png" | head -1)
            if [ -n "$ICON_FILE" ]; then
                run_command "sudo cp \"$ICON_FILE\" /opt/cursor.png"
                echo "✓ Icono extraído y configurado"
                run_command "rm -rf squashfs-root"
            fi
        fi
    else
        echo "📋 Configuración manual del icono (opcional):"
        echo "   Para añadir un icono personalizado:"
        echo "   1. Descarga un icono PNG de Cursor"
        echo "   2. Ejecuta: sudo cp /ruta/al/icono.png /opt/cursor.png"
        echo "   3. Edita: sudo nano /usr/share/applications/cursor.desktop"
        echo "   4. Cambia 'Icon=cursor' por 'Icon=/opt/cursor.png'"
    fi

    echo ""
    echo "=== Instalación completada ==="
    echo "✅ Cursor (AI Code Editor) instalado exitosamente"
    echo ""
    echo "🚀 Para usar Cursor:"
    echo "  • Desde terminal: cursor"
    echo "  • Desde terminal (directo): /opt/cursor.appimage"
    echo "  • Desde el menú de aplicaciones: Cursor"
    echo "  • Para abrir un proyecto: cursor /ruta/al/proyecto"
    echo ""
    echo "🎯 Características principales de Cursor:"
    echo "  • Editor de código con IA integrada"
    echo "  • Autocompletado inteligente con AI"
    echo "  • Chat con IA sobre tu código"
    echo "  • Refactoring asistido por IA"
    echo "  • Compatible con extensiones de VS Code"
    echo "  • Interfaz familiar para usuarios de VS Code"
    echo ""
    echo "⚠️  Nota: En el primer inicio, Cursor podría solicitar permisos"
    echo "   adicionales y descargar componentes necesarios."
    echo ""
    echo "🔧 Si experimentas problemas:"
    echo "   • Verifica que FUSE esté instalado"
    echo "   • Ejecuta con: /opt/cursor.appimage --no-sandbox"
    echo "   • Consulta logs en: ~/.config/cursor/"
}

# Función para mostrar el menú de selección de Docker
choose_docker_installation() {
    echo "Se detectó que deseas instalar herramientas de Docker."
    echo "Por favor, selecciona UNA de las siguientes opciones:"
    echo "  1) Docker CLI solamente (Engine, Compose, Buildx) - Recomendado para servidores"
    echo "  2) Docker Desktop (incluye GUI y Docker CLI) - Recomendado para desarrollo"
    echo "  0) Omitir instalación de Docker"
    echo -n "Tu elección (1-2): "
    read -r docker_choice
    
    case $docker_choice in
        1)
            install_docker_cli
            ;;
        2)
            install_docker_desktop_with_dependencies
            ;;
        0)
            echo "Omitiendo instalación de Docker."
            ;;
        *)
            echo "Opción inválida. Omitiendo instalación de Docker."
            ;;
    esac
}

install_docker_cli() {
    print_header "Instalando Docker CLI (Engine, Compose, Buildx, containerd)"

    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "Configurando repositorio oficial de Docker para Debian/Ubuntu/Kali/Parrot..."
            run_command "sudo apt-get update"
            run_command "sudo apt-get install -y ca-certificates curl gnupg lsb-release"
            run_command "sudo install -m 0755 -d /etc/apt/keyrings"
            run_command "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
            run_command "sudo chmod a+r /etc/apt/keyrings/docker.asc"

            local DISTRO_CODENAME=""
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO_CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
            fi

            if [ -z "$DISTRO_CODENAME" ]; then
                echo "Error: No se pudo determinar el codename de la distribución (ej. 'jammy', 'bookworm'). La instalación de Docker podría fallar." >&2
                return 1
            fi

            echo "Añadiendo repositorio de Docker para $DISTRO_CODENAME..."
            run_command "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${DISTRO_CODENAME} stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
            
            run_command "sudo apt-get update -y"
            echo "Instalando Docker Engine y complementos..."
            run_command "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
            ;;
        fedora)
            echo "Configurando repositorio oficial de Docker para Fedora..."
            run_command "sudo dnf -y install dnf-plugins-core"
            
            # Usar curl en lugar de dnf config-manager para mejor compatibilidad
            echo "Añadiendo repositorio de Docker..."
            run_command "sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo"
            
            run_command "sudo dnf makecache"
            echo "Instalando Docker Engine y complementos..."
            run_command "sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
            ;;
        arch)
            echo "Instalando Docker CLI y complementos con pacman en Arch Linux..."
            run_command "sudo pacman -S --noconfirm docker docker-compose"
            ;;
        opensuse)
            echo "Instalando Docker CLI y complementos con zypper en openSUSE..."
            run_command "sudo zypper install -y docker docker-compose"
            ;;
        alpine)
            echo "Instalando Docker CLI y complementos con apk en Alpine..."
            run_command "sudo apk add --no-cache docker docker-compose"
            ;;
        *)
            echo "Instalación de Docker CLI para $DISTRO no implementada con los repositorios oficiales." >&2
            return 1
            ;;
    esac

    echo "Habilitando y arrancando el servicio de Docker..."
    run_command "sudo systemctl enable --now docker"

    echo "Añadiendo usuario '$USER' al grupo 'docker'..."
    if ! getent group docker &> /dev/null; then
        run_command "sudo groupadd docker"
    fi
    run_command "sudo usermod -aG docker $USER"

    echo "Docker CLI y complementos instalados."
    echo "Verificando la instalación..."
    docker --version || echo "Docker CLI no en PATH aún. Reinicia la sesión."
    docker compose version || echo "Docker Compose no en PATH aún. Reinicia la sesión."
    docker buildx version || echo "Docker Buildx no en PATH aún. Reinicia la sesión."

    echo "Ejecutando contenedor de prueba 'hello-world' (puede que necesites reiniciar la sesión para usar 'docker' sin sudo):"
    run_command "sudo docker run hello-world"
    
    echo "¡IMPORTANTISIMO! Para usar Docker sin 'sudo', debes:"
    echo "  Reiniciar tu sesión (cerrar y volver a iniciar) o reiniciar el sistema."
}

install_docker_desktop_with_dependencies() {
    print_header "Instalando Docker Desktop (incluye Docker CLI como dependencia)"

    # Primero instalar Docker CLI si no está presente
    if ! command -v docker &> /dev/null; then
        echo "Docker CLI no detectado. Instalando primero Docker CLI..."
        install_docker_cli
        if [ $? -ne 0 ]; then
            echo "Error: Fallo al instalar Docker CLI. Docker Desktop requiere Docker CLI." >&2
            return 1
        fi
    fi

    local DOCKER_DESKTOP_URL=""
    local DOCKER_DESKTOP_PACKAGE=""

    # Verificar arquitectura
    local ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
    if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "x86_64" ]; then
        echo "Advertencia: Docker Desktop se está intentando instalar en una arquitectura ($ARCH) no AMD64." >&2
        echo "Los enlaces proporcionados son para amd64. La instalación podría fallar."
        sleep 2
    fi

    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "Descargando Docker Desktop para Debian/Ubuntu..."
            DOCKER_DESKTOP_PACKAGE="docker-desktop-amd64.deb"
            DOCKER_DESKTOP_URL="https://desktop.docker.com/linux/main/amd64/$DOCKER_DESKTOP_PACKAGE?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-linux-amd64"
            
            run_command "wget -q --show-progress -O /tmp/$DOCKER_DESKTOP_PACKAGE \"$DOCKER_DESKTOP_URL\""
            echo "Instalando paquete Docker Desktop..."
            run_command "sudo apt install -y /tmp/$DOCKER_DESKTOP_PACKAGE"
            run_command "rm /tmp/$DOCKER_DESKTOP_PACKAGE"
            ;;
        fedora)
            echo "Descargando Docker Desktop para Fedora..."
            DOCKER_DESKTOP_PACKAGE="docker-desktop-x86_64.rpm"
            DOCKER_DESKTOP_URL="https://desktop.docker.com/linux/main/amd64/$DOCKER_DESKTOP_PACKAGE?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-linux-amd64"
            
            run_command "wget -q --show-progress -O /tmp/$DOCKER_DESKTOP_PACKAGE \"$DOCKER_DESKTOP_URL\""
            echo "Instalando paquete Docker Desktop..."
            run_command "sudo dnf install -y /tmp/$DOCKER_DESKTOP_PACKAGE"
            run_command "rm /tmp/$DOCKER_DESKTOP_PACKAGE"
            ;;
        *)
            echo "Instalación de Docker Desktop para $DISTRO no implementada con los enlaces proporcionados." >&2
            return 1
            ;;
    esac

    echo "Añadiendo usuario '$USER' al grupo 'docker'..."
    if ! getent group docker &> /dev/null; then
        run_command "sudo groupadd docker"
    fi
    run_command "sudo usermod -aG docker $USER"

    echo "Docker Desktop instalado."
    echo "¡IMPORTANTE! Para que los cambios de Docker surtan efecto (usar Docker sin sudo), debes:"
    echo "  1. Reiniciar tu sesión (cerrar y volver a iniciar) o reiniciar el sistema."
    echo "  2. Iniciar Docker Desktop desde tu menú de aplicaciones."
    echo "Puedes verificar la instalación abriendo una nueva terminal y ejecutando 'docker run hello-world'."
}
install_fonts() {
    print_header "Instalando Fuentes: Cascadia Code y Caskaydia Cove"

    local FONT_DIR="$USER_HOME/.local/share/fonts"
    run_command "mkdir -p \"$FONT_DIR\""

    # Install fontconfig for managing fonts if not present
    case $PACKAGE_MANAGER in
        apt)
            if ! command -v fc-cache &> /dev/null; then
                run_command "sudo apt install -y fontconfig"
            fi
            ;;
        dnf)
            if ! command -v fc-cache &> /dev/null; then
                run_command "sudo dnf install -y fontconfig"
            fi
            ;;
        pacman)
            if ! command -v fc-cache &> /dev/null; then
                run_command "sudo pacman -S --noconfirm fontconfig"
            fi
            ;;
        zypper)
            if ! command -v fc-cache &> /dev/null; then
                run_command "sudo zypper install -y fontconfig"
            fi
            ;;
        apk)
            if ! command -v fc-cache &> /dev/null; then
                run_command "sudo apk add --no-cache fontconfig"
            fi
            ;;
    esac

    # Check if Cascadia Code is already installed
    echo "Verificando si Cascadia Code ya está instalada..."
    if fc-list | grep -i "cascadia code" &> /dev/null; then
        echo "✓ Cascadia Code ya está instalada. Omitiendo descarga."
    else
        echo "Descargando e instalando Cascadia Code..."
        local CASCADIA_URL="https://github.com/microsoft/cascadia-code/releases/download/v2404.23/CascadiaCode-2404.23.zip"
        local CASCADIA_ZIP="/tmp/CascadiaCode.zip"
        local CASCADIA_EXTRACT_DIR="/tmp/CascadiaCode_extracted"

        if command -v wget &> /dev/null; then
            run_command "wget -q --show-progress -O \"$CASCADIA_ZIP\" \"$CASCADIA_URL\""
        elif command -v curl &> /dev/null; then
            run_command "curl -L -o \"$CASCADIA_ZIP\" \"$CASCADIA_URL\""
        else
            echo "Error: Ni wget ni curl están instalados. No se pueden descargar las fuentes." >&2
            return 1
        fi

        run_command "unzip -o \"$CASCADIA_ZIP\" -d \"$CASCADIA_EXTRACT_DIR\""
        run_command "cp \"$CASCADIA_EXTRACT_DIR\"/ttf/*.ttf \"$FONT_DIR\"/" # Copy TTF files
        run_command "rm -rf \"$CASCADIA_ZIP\" \"$CASCADIA_EXTRACT_DIR\""
        echo "✓ Cascadia Code instalado."
    fi

    # Check if Caskaydia Cove Nerd Font is already installed
    echo "Verificando si Caskaydia Cove Nerd Font ya está instalada..."
    if fc-list | grep -i "cascadia.*nf\|caskaydia" &> /dev/null; then
        echo "✓ Caskaydia Cove Nerd Font ya está instalada. Omitiendo descarga."
    else
        echo "Descargando e instalando Caskaydia Cove Nerd Font..."
        # Updated URL to use the correct release and naming
        local CAS_COVE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CascadiaCode.zip"
        local CAS_COVE_ZIP="/tmp/CascadiaCodeNerd.zip"
        local CAS_COVE_EXTRACT_DIR="/tmp/CascadiaCodeNerd_extracted"

        if command -v wget &> /dev/null; then
            run_command "wget -q --show-progress -O \"$CAS_COVE_ZIP\" \"$CAS_COVE_URL\""
        elif command -v curl &> /dev/null; then
            run_command "curl -L -o \"$CAS_COVE_ZIP\" \"$CAS_COVE_URL\""
        else
            echo "Error: Ni wget ni curl están instalados. No se pueden descargar las fuentes." >&2
            return 1
        fi

        run_command "unzip -o \"$CAS_COVE_ZIP\" -d \"$CAS_COVE_EXTRACT_DIR\""
        # Copy only TTF files (Nerd Fonts typically include both TTF and OTF)
        if ls "$CAS_COVE_EXTRACT_DIR"/*.ttf &> /dev/null; then
            run_command "cp \"$CAS_COVE_EXTRACT_DIR\"/*.ttf \"$FONT_DIR\"/"
        fi
        # Also copy OTF files if they exist
        if ls "$CAS_COVE_EXTRACT_DIR"/*.otf &> /dev/null; then
            run_command "cp \"$CAS_COVE_EXTRACT_DIR\"/*.otf \"$FONT_DIR\"/"
        fi
        run_command "rm -rf \"$CAS_COVE_ZIP\" \"$CAS_COVE_EXTRACT_DIR\""
        echo "✓ Caskaydia Cove Nerd Font instalado."
    fi
    
    echo "Actualizando la caché de fuentes..."
    run_command "fc-cache -fv"

    echo ""
    echo "=== Resumen de fuentes instaladas ==="
    echo "Verificando fuentes de Cascadia disponibles:"
    fc-list | grep -i cascadia || echo "  No se encontraron fuentes de Cascadia (esto podría ser normal si el nombre interno es diferente)"
    
    echo ""
    echo "✓ Instalación de fuentes completada."
    echo "Para usar estas fuentes en tu terminal o editor:"
    echo "  - Cascadia Code: 'Cascadia Code'"
    echo "  - Caskaydia Cove Nerd Font: 'CaskaydiaCove Nerd Font' o 'Cascadia Code NF'"
    echo ""
    echo "Nota: Puede que necesites reiniciar tu terminal o editor para ver las nuevas fuentes."
}

install_vscode() {
    print_header "Instalando Visual Studio Code"

    # Verificar arquitectura soportada
    local ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
    case "$ARCH" in
        amd64|x86_64)
            echo "✓ Arquitectura $ARCH soportada"
            ;;
        arm64|aarch64)
            echo "✓ Arquitectura $ARCH soportada"
            ;;
        *)
            echo "❌ Error: Arquitectura $ARCH no soportada oficialmente por VS Code."
            echo "    VS Code está disponible principalmente para amd64 y arm64."
            return 1
            ;;
    esac
    
    # Verificar si VS Code ya está instalado
    if command -v code &> /dev/null; then
        echo "✓ Visual Studio Code ya está instalado."
        echo "Versión actual: $(code --version | head -n1)"
        read -p "¿Deseas reinstalar o actualizar VS Code? (y/N): " reinstall_vscode
        if [[ ! "$reinstall_vscode" =~ ^[Yy]$ ]]; then
            echo "Instalación de VS Code cancelada."
            return 0
        fi
        echo "Procediendo con la instalación/actualización..."
    fi
    
    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "Instalando VS Code para Debian/Ubuntu usando repositorio oficial de Microsoft..."
            
            # Instalar dependencias necesarias
            run_command "sudo apt update -y"
            run_command "sudo apt install -y wget gpg software-properties-common apt-transport-https"
            
            # Añadir clave GPG de Microsoft
            echo "Añadiendo clave GPG de Microsoft..."
            if [ ! -f /etc/apt/keyrings/packages.microsoft.gpg ]; then
                run_command "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg"
                run_command "sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/"
                run_command "rm packages.microsoft.gpg"
            else
                echo "✓ Clave GPG de Microsoft ya existe."
            fi
            
            # Añadir repositorio de VS Code
            echo "Configurando repositorio de VS Code..."
            if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
                run_command "echo \"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" | sudo tee /etc/apt/sources.list.d/vscode.list"
            else
                echo "✓ Repositorio de VS Code ya está configurado."
            fi
            
            # Actualizar e instalar
            run_command "sudo apt update -y"
            run_command "sudo apt install -y code"
            ;;
            
        fedora)
            echo "Instalando VS Code para Fedora usando repositorio oficial de Microsoft..."
            
            # Importar clave GPG de Microsoft
            echo "Importando clave GPG de Microsoft..."
            run_command "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc"
            
            # Añadir repositorio de VS Code
            echo "Configurando repositorio de VS Code..."
            if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
                sudo bash -c 'cat > /etc/yum.repos.d/vscode.repo << EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF'
                echo "✓ Repositorio de VS Code configurado."
            else
                echo "✓ Repositorio de VS Code ya existe."
            fi
            
            # Instalar VS Code
            run_command "sudo dnf install -y code"
            ;;
            
        arch|manjaro)
            echo "Instalando VS Code para Arch Linux..."
            
            # VS Code está disponible en AUR, usando el paquete visual-studio-code-bin
            if command -v yay &> /dev/null; then
                echo "Usando yay para instalar desde AUR..."
                run_command "yay -S --noconfirm visual-studio-code-bin"
            elif command -v paru &> /dev/null; then
                echo "Usando paru para instalar desde AUR..."
                run_command "paru -S --noconfirm visual-studio-code-bin"
            else
                echo "⚠️  No se encontró un helper de AUR (yay/paru)."
                echo "Instalando desde el paquete snap como alternativa..."
                if command -v snap &> /dev/null; then
                    run_command "sudo snap install --classic code"
                else
                    echo "Error: Ni AUR helpers ni snap están disponibles." >&2
                    echo "Por favor, instala VS Code manualmente desde https://code.visualstudio.com/"
                    return 1
                fi
            fi
            ;;
            
        opensuse|sles)
            echo "Instalando VS Code para openSUSE usando repositorio oficial de Microsoft..."
            
            # Importar clave GPG
            run_command "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc"
            
            # Añadir repositorio
            echo "Configurando repositorio de VS Code..."
            if ! sudo zypper lr | grep -q "vscode"; then
                run_command "sudo zypper addrepo https://packages.microsoft.com/yumrepos/vscode vscode"
                run_command "sudo zypper refresh"
            else
                echo "✓ Repositorio de VS Code ya existe."
            fi
            
            # Instalar VS Code
            run_command "sudo zypper install -y code"
            ;;
            
        alpine)
            echo "Instalando VS Code para Alpine Linux usando snap..."
            
            # Alpine no tiene un repositorio oficial, usamos snap
            if ! command -v snap &> /dev/null; then
                echo "Instalando snapd primero..."
                run_command "sudo apk add --no-cache snapd"
                run_command "sudo systemctl enable --now snapd"
                run_command "sudo systemctl enable --now snapd.apparmor"
            fi
            
            run_command "sudo snap install --classic code"
            ;;
            
        *)
            echo "Distribución $DISTRO no reconocida. Intentando instalación universal con snap..."
            
            if command -v snap &> /dev/null; then
                run_command "sudo snap install --classic code"
            else
                echo "Error: Distribución no soportada y snap no está disponible." >&2
                echo "Por favor, descarga VS Code manualmente desde:"
                echo "  https://code.visualstudio.com/download"
                return 1
            fi
            ;;
    esac
    
    # Verificar instalación
    echo ""
    echo "=== Verificando instalación ==="
    if command -v code &> /dev/null; then
        echo "✓ Visual Studio Code instalado correctamente."
        echo "Versión: $(code --version | head -n1)"
        echo ""
        echo "Para abrir VS Code:"
        echo "  - Desde terminal: code"
        echo "  - Desde terminal con carpeta: code ."
        echo "  - Desde el menú de aplicaciones: Visual Studio Code"
        echo ""
        echo "Extensiones recomendadas para desarrollo:"
        echo "  - GitLens"
        echo "  - Prettier - Code formatter"
        echo "  - Auto Rename Tag"
        echo "  - Bracket Pair Colorizer 2"
        echo "  - Material Icon Theme"
        echo "  - Thunder Client (alternativa a Postman)"
        echo ""
        echo "Para instalar extensiones desde terminal:"
        echo "  code --install-extension ms-vscode.vscode-json"
    else
        echo "❌ Error: VS Code no se instaló correctamente."
        return 1
    fi
}
install_warp_terminal() {
    print_header "Instalando Warp Terminal"
    
    echo "📁 NOTA: Esta función busca archivos de instalación locales de Warp Terminal"
    echo "en el mismo directorio donde ejecutas este script."
    echo ""
    echo "Para instalar Warp Terminal necesitas:"
    echo "  • Para Ubuntu/Debian: archivo .deb (ej: warp-terminal_*.deb)"
    echo "  • Para Fedora/RHEL: archivo .rpm (ej: warp-terminal_*.rpm)"
    echo ""
    echo "Descarga el archivo apropiado desde https://www.warp.dev/ y colócalo"
    echo "en este directorio antes de ejecutar esta opción."
    echo ""
    
    # Verificar si Warp Terminal ya está instalado
    if command -v warp-terminal &> /dev/null || command -v warp &> /dev/null; then
        echo "✓ Warp Terminal ya está instalado."
        echo "Versión actual: $(warp-terminal --version 2>/dev/null || warp --version 2>/dev/null || echo 'No disponible')"
        read -p "¿Deseas reinstalar Warp Terminal? (y/N): " reinstall_warp
        if [[ ! "$reinstall_warp" =~ ^[Yy]$ ]]; then
            echo "Instalación de Warp Terminal cancelada."
            return 0
        fi
        echo "Procediendo con la reinstalación..."
        echo ""
    fi
    
    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "=== Buscando archivo .deb de Warp Terminal ==="
            
            # Buscar archivos .deb de Warp Terminal en el directorio actual
            local WARP_DEB_FILE=$(find . -maxdepth 1 -type f -iname "*warp*terminal*.deb" -o -iname "*warp*.deb" | head -n 1)
            
            if [ -z "$WARP_DEB_FILE" ]; then
                echo "❌ Error: No se encontró ningún archivo .deb de Warp Terminal en el directorio actual."
                echo ""
                echo "📥 Para instalar Warp Terminal:"
                echo "1. Visita https://www.warp.dev/"
                echo "2. Descarga el archivo .deb para Linux"
                echo "3. Coloca el archivo en este directorio: $(pwd)"
                echo "4. Ejecuta nuevamente esta opción"
                echo ""
                echo "Ejemplo de nombres de archivo esperados:"
                echo "  • warp-terminal_1.0.0_amd64.deb"
                echo "  • warp_terminal-latest.deb"
                echo "  • warp-linux.deb"
                return 1
            fi
            
            echo "✓ Archivo de Warp Terminal encontrado: $WARP_DEB_FILE"
            echo ""
            
            # Verificar que el archivo es un DEB válido
            if file "$WARP_DEB_FILE" | grep -q "Debian binary package"; then
                echo "✓ Archivo .deb válido confirmado."
                
                # Instalar dependencias necesarias
                echo "Instalando dependencias necesarias..."
                run_command "sudo apt update -y"
                run_command "sudo apt install -y libfuse2" # FUSE podría ser necesario
                
                # Instalar Warp Terminal
                echo "Instalando Warp Terminal..."
                run_command "sudo dpkg -i \"$WARP_DEB_FILE\""
                
                # Resolver dependencias si es necesario
                echo "Resolviendo dependencias..."
                run_command "sudo apt-get install -f -y"
                
                echo "✓ Instalación de Warp Terminal completada."
            else
                echo "❌ Error: El archivo '$WARP_DEB_FILE' no es un paquete .deb válido."
                echo "Por favor, verifica que descargaste el archivo correcto desde https://www.warp.dev/"
                return 1
            fi
            ;;
            
        fedora|centos|rhel)
            echo "=== Buscando archivo .rpm de Warp Terminal ==="
            
            # Buscar archivos .rpm de Warp Terminal en el directorio actual
            local WARP_RPM_FILE=$(find . -maxdepth 1 -type f -iname "*warp*terminal*.rpm" -o -iname "*warp*.rpm" | head -n 1)
            
            if [ -z "$WARP_RPM_FILE" ]; then
                echo "❌ Error: No se encontró ningún archivo .rpm de Warp Terminal en el directorio actual."
                echo ""
                echo "📥 Para instalar Warp Terminal:"
                echo "1. Visita https://www.warp.dev/"
                echo "2. Descarga el archivo .rpm para Linux"
                echo "3. Coloca el archivo en este directorio: $(pwd)"
                echo "4. Ejecuta nuevamente esta opción"
                echo ""
                echo "Ejemplo de nombres de archivo esperados:"
                echo "  • warp-terminal-1.0.0.x86_64.rpm"
                echo "  • warp_terminal-latest.rpm"
                echo "  • warp-linux.rpm"
                return 1
            fi
            
            echo "✓ Archivo de Warp Terminal encontrado: $WARP_RPM_FILE"
            echo ""
            
            # Verificar que el archivo es un RPM válido
            if file "$WARP_RPM_FILE" | grep -q "RPM"; then
                echo "✓ Archivo .rpm válido confirmado."
                
                # Instalar Warp Terminal
                echo "Instalando Warp Terminal..."
                if command -v dnf &> /dev/null; then
                    run_command "sudo dnf install -y \"$WARP_RPM_FILE\""
                else
                    run_command "sudo rpm -i \"$WARP_RPM_FILE\""
                fi
                
                echo "✓ Instalación de Warp Terminal completada."
            else
                echo "❌ Error: El archivo '$WARP_RPM_FILE' no es un paquete .rpm válido."
                echo "Por favor, verifica que descargaste el archivo correcto desde https://www.warp.dev/"
                return 1
            fi
            ;;
            
        arch|manjaro)
            echo "=== Instalación para Arch Linux ==="
            echo ""
            echo "Para Arch Linux se recomienda usar AUR:"
            echo ""
            if command -v yay &> /dev/null; then
                echo "Usando yay para instalar desde AUR..."
                run_command "yay -S --noconfirm warp-terminal-bin"
            elif command -v paru &> /dev/null; then
                echo "Usando paru para instalar desde AUR..."
                run_command "paru -S --noconfirm warp-terminal-bin"
            else
                echo "⚠️  No se encontró un helper de AUR (yay/paru)."
                echo ""
                echo "Instalación manual requerida:"
                echo "1. Instala yay: pacman -S yay"
                echo "2. Ejecuta: yay -S warp-terminal-bin"
                echo ""
                echo "Alternativamente, puedes colocar un archivo .tar.xz de Warp Terminal"
                echo "en este directorio y ejecutar nuevamente esta opción."
                return 1
            fi
            ;;
            
        *)
            echo "=== Distribución no soportada oficialmente ==="
            echo ""
            echo "Para distribuciones no estándar, buscaremos archivos genéricos:"
            echo ""
            
            # Buscar cualquier archivo de instalación de Warp
            local WARP_FILE=$(find . -maxdepth 1 -type f \( -iname "*warp*terminal*" -o -iname "*warp*" \) \( -name "*.deb" -o -name "*.rpm" -o -name "*.tar.gz" -o -name "*.tar.xz" -o -name "*.AppImage" \) | head -n 1)
            
            if [ -z "$WARP_FILE" ]; then
                echo "❌ Error: No se encontró ningún archivo de instalación de Warp Terminal."
                echo ""
                echo "📥 Archivos soportados:"
                echo "  • .deb (Debian/Ubuntu)"
                echo "  • .rpm (Fedora/RHEL)"
                echo "  • .tar.gz/.tar.xz (Genérico)"
                echo "  • .AppImage (Universal)"
                echo ""
                echo "Descarga desde https://www.warp.dev/ y coloca el archivo aquí."
                return 1
            fi
            
            echo "✓ Archivo encontrado: $WARP_FILE"
            echo "⚠️  Instalación manual requerida para esta distribución."
            echo "Por favor, instala manualmente el archivo encontrado."
            ;;
    esac
    
    # Verificar instalación
    echo ""
    echo "=== Verificando instalación ==="
    if command -v warp-terminal &> /dev/null; then
        echo "✓ Warp Terminal instalado correctamente."
        echo "Versión: $(warp-terminal --version 2>/dev/null || echo 'Disponible')"
        echo ""
        echo "Para abrir Warp Terminal:"
        echo "  - Desde terminal: warp-terminal"
        echo "  - Desde el menú de aplicaciones: Warp Terminal"
        echo ""
        echo "🎉 Características de Warp Terminal:"
        echo "  • Terminal moderno con IA integrada"
        echo "  • Autocompletado inteligente"
        echo "  • Colaboración en tiempo real"
        echo "  • Historial de comandos mejorado"
        echo "  • Interfaz moderna y personalizable"
        echo "  • Bloques de comandos organizados"
    elif command -v warp &> /dev/null; then
        echo "✓ Warp Terminal instalado correctamente."
        echo "Comando disponible: warp"
        echo ""
        echo "Para abrir Warp Terminal:"
        echo "  - Desde terminal: warp"
        echo "  - Desde el menú de aplicaciones: Warp"
    else
        echo "⚠️  Warp Terminal podría haberse instalado pero no está en el PATH."
        echo "Intenta reiniciar tu terminal o buscar 'Warp' en el menú de aplicaciones."
        echo ""
        echo "Si el problema persiste:"
        echo "1. Verifica que el archivo descargado sea compatible con tu sistema"
        echo "2. Consulta la documentación oficial en https://www.warp.dev/"
        echo "3. Considera usar una alternativa como Alacritty o Kitty"
    fi
}

install_alacritty_alternative() {
    echo ""
    echo "=== Instalando Alacritty (Alternativa moderna a Warp) ==="
    
    case $PACKAGE_MANAGER in
        apt)
            run_command "sudo apt update -y"
            run_command "sudo apt install -y alacritty"
            ;;
        dnf)
            run_command "sudo dnf install -y alacritty"
            ;;
        pacman)
            run_command "sudo pacman -S --noconfirm alacritty"
            ;;
        zypper)
            run_command "sudo zypper install -y alacritty"
            ;;
        apk)
            run_command "sudo apk add --no-cache alacritty"
            ;;
        *)
            echo "Gestor de paquetes no soportado para Alacritty."
            return 1
            ;;
    esac
    
    if command -v alacritty &> /dev/null; then
        echo "✓ Alacritty instalado correctamente."
        echo ""
        echo "Para usar Alacritty:"
        echo "  - Desde terminal: alacritty"
        echo "  - Desde el menú de aplicaciones: Alacritty"
        echo ""
        echo "Características de Alacritty:"
        echo "  - Terminal extremadamente rápido (GPU-accelerated)"
        echo "  - Configuración via YAML"
        echo "  - Multiplataforma"
        echo "  - Soporte para ligaduras de fuentes"
        echo "  - Configuración altamente personalizable"
    else
        echo "❌ Error al instalar Alacritty."
        return 1
    fi
}

install_kitty_alternative() {
    echo ""
    echo "=== Instalando Kitty (Alternativa moderna a Warp) ==="
    
    case $PACKAGE_MANAGER in
        apt)
            run_command "sudo apt update -y"
            run_command "sudo apt install -y kitty"
            ;;
        dnf)
            run_command "sudo dnf install -y kitty"
            ;;
        pacman)
            run_command "sudo pacman -S --noconfirm kitty"
            ;;
        zypper)
            run_command "sudo zypper install -y kitty"
            ;;
        apk)
            run_command "sudo apk add --no-cache kitty"
            ;;
        *)
            echo "Gestor de paquetes no soportado para Kitty."
            return 1
            ;;
    esac
    
    if command -v kitty &> /dev/null; then
        echo "✓ Kitty instalado correctamente."
        echo ""
        echo "Para usar Kitty:"
        echo "  - Desde terminal: kitty"
        echo "  - Desde el menú de aplicaciones: Kitty"
        echo ""
        echo "Características de Kitty:"
        echo "  - Terminal con aceleración GPU"
        echo "  - Soporte para imágenes y gráficos"
        echo "  - Múltiples pestañas y ventanas"
        echo "  - Ligaduras de fuentes"
        echo "  - Scripting avanzado"
    else
        echo "❌ Error al instalar Kitty."
        return 1
    fi
}

install_wezterm_alternative() {
    echo ""
    echo "=== Instalando WezTerm (Alternativa moderna a Warp) ==="
    
    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "Instalando WezTerm para Ubuntu/Debian..."
            
            # Añadir repositorio oficial de WezTerm
            run_command "curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg"
            run_command "echo 'deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list"
            run_command "sudo apt update -y"
            run_command "sudo apt install -y wezterm"
            ;;
        fedora)
            echo "Instalando WezTerm para Fedora..."
            run_command "sudo dnf copr enable -y wezterm/wezterm-nightly"
            run_command "sudo dnf install -y wezterm"
            ;;
        arch|manjaro)
            echo "Instalando WezTerm para Arch Linux..."
            if command -v yay &> /dev/null; then
                run_command "yay -S --noconfirm wezterm"
            elif command -v paru &> /dev/null; then
                run_command "paru -S --noconfirm wezterm"
            else
                run_command "sudo pacman -S --noconfirm wezterm"
            fi
            ;;
        *)
            echo "Distribución no soportada para WezTerm con repositorio oficial."
            echo "Intentando instalación con Flatpak..."
            if command -v flatpak &> /dev/null; then
                run_command "flatpak install -y flathub org.wezfurlong.wezterm"
            else
                echo "Flatpak no disponible. Instalación manual requerida."
                return 1
            fi
            ;;
    esac
    
    if command -v wezterm &> /dev/null; then
        echo "✓ WezTerm instalado correctamente."
        echo ""
        echo "Para usar WezTerm:"
        echo "  - Desde terminal: wezterm"
        echo "  - Desde el menú de aplicaciones: WezTerm"
        echo ""
        echo "Características de WezTerm:"
        echo "  - Terminal multiplataforma moderno"
        echo "  - Configuración con Lua"
        echo "  - Múltiples pestañas y paneles"
        echo "  - Ligaduras de fuentes avanzadas"
        echo "  - Rendimiento optimizado"
    else
        echo "❌ Error al instalar WezTerm."
        return 1
    fi
}

show_manual_warp_instructions() {
    echo ""
    echo "=== Instalación manual de Warp Terminal ==="
    echo ""
    echo "Warp Terminal está principalmente disponible para macOS."
    echo "Para Linux, puedes:"
    echo ""
    echo "1. Únete a la lista de espera de Warp para Linux:"
    echo "   https://www.warp.dev/"
    echo ""
    echo "2. Usar alternativas modernas recomendadas:"
    echo "   - Alacritty: Terminal rápido con aceleración GPU"
    echo "   - Kitty: Terminal con características avanzadas"
    echo "   - WezTerm: Terminal multiplataforma moderno"
    echo "   - Hyper: Terminal basado en Electron"
    echo "   - Terminator: Terminal con múltiples paneles"
    echo ""
    echo "3. Comandos de instalación rápida:"
    echo "   sudo apt install alacritty    # Para Alacritty"
    echo "   sudo apt install kitty        # Para Kitty"
    echo "   sudo apt install terminator   # Para Terminator"
    echo ""
    echo "Todas estas alternativas ofrecen características modernas"
    echo "similares a las que buscarías en Warp Terminal."
}

install_warp_snap() {
    echo "Intentando instalación con snap..."
    
    # Verificar si snap está disponible
    if ! command -v snap &> /dev/null; then
        echo "Instalando snapd..."
        case $PACKAGE_MANAGER in
            apt)
                run_command "sudo apt update -y" || return 1
                run_command "sudo apt install -y snapd" || return 1
                ;;
            dnf)
                run_command "sudo dnf install -y snapd" || return 1
                run_command "sudo systemctl enable --now snapd" || return 1
                run_command "sudo ln -sf /var/lib/snapd/snap /snap" || return 1
                ;;
            pacman)
                echo "⚠️  Para Arch Linux, instala snapd manualmente con:"
                echo "    yay -S snapd"
                echo "    sudo systemctl enable --now snapd"
                return 1
                ;;
            zypper)
                echo "Configurando snap para openSUSE..."
                run_command "sudo zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Leap_15.6 snappy" || return 1
                run_command "sudo zypper --gpg-auto-import-keys refresh" || return 1
                run_command "sudo zypper install -y snapd" || return 1
                run_command "sudo systemctl enable --now snapd" || return 1
                ;;
            apk)
                echo "⚠️  Snap no está disponible oficialmente para Alpine Linux."
                return 1
                ;;
            *)
                echo "⚠️  No se puede instalar snapd automáticamente en esta distribución."
                return 1
                ;;
        esac
        
        # Esperar a que snapd se inicie completamente
        echo "Esperando a que snapd se inicie..."
        sleep 3
    fi
    
    # Instalar Warp con snap
    echo "Instalando Warp Terminal con snap..."
    if run_command "sudo snap install warp-terminal"; then
        echo "✓ Warp Terminal instalado vía snap."
        return 0
    else
        echo "❌ Falló la instalación con snap."
        return 1
    fi
}

install_warp_flatpak() {
    echo "Intentando instalación con Flatpak..."
    
    # Verificar si flatpak está disponible
    if ! command -v flatpak &> /dev/null; then
        echo "Instalando Flatpak..."
        case $PACKAGE_MANAGER in
            apt)
                run_command "sudo apt update -y" || return 1
                run_command "sudo apt install -y flatpak" || return 1
                ;;
            dnf)
                run_command "sudo dnf install -y flatpak" || return 1
                ;;
            pacman)
                run_command "sudo pacman -S --noconfirm flatpak" || return 1
                ;;
            zypper)
                run_command "sudo zypper install -y flatpak" || return 1
                ;;
            apk)
                run_command "sudo apk add --no-cache flatpak" || return 1
                ;;
            *)
                echo "⚠️  No se puede instalar Flatpak automáticamente en esta distribución."
                return 1
                ;;
        esac
    fi
    
    # Añadir Flathub si no está presente
    if ! flatpak remotes 2>/dev/null | grep -q flathub; then
        echo "Añadiendo repositorio Flathub..."
        run_command "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo" || return 1
    fi
    
    # Instalar Warp con Flatpak
    echo "Instalando Warp Terminal con Flatpak..."
    if run_command "flatpak install -y flathub dev.warp.Warp"; then
        echo "✓ Warp Terminal instalado vía Flatpak."
        return 0
    else
        echo "❌ Falló la instalación con Flatpak."
        return 1
    fi
}

show_warp_info() {
    echo ""
    echo "Para abrir Warp Terminal:"
    if command -v warp-terminal &> /dev/null; then
        echo "  - Desde terminal: warp-terminal"
    elif command -v warp &> /dev/null; then
        echo "  - Desde terminal: warp"
    elif snap list 2>/dev/null | grep -q warp-terminal; then
        echo "  - Desde terminal: warp-terminal"
    elif flatpak list 2>/dev/null | grep -q warp; then
        echo "  - Desde terminal: flatpak run dev.warp.Warp"
    fi
    echo "  - Desde el menú de aplicaciones: Warp"
    echo ""
    echo "Características principales de Warp:"
    echo "  - Terminal moderno con IA integrada"
    echo "  - Autocompletado inteligente"
    echo "  - Colaboración en tiempo real"
    echo "  - Historial de comandos mejorado"
    echo "  - Interfaz moderna y personalizable"
}

show_manual_warp_instructions() {
    echo ""
    echo "=== Instalación manual de Warp Terminal ==="
    echo ""
    echo "Métodos alternativos de instalación:"
    echo ""
    echo "1. Descargar desde el sitio oficial:"
    echo "   https://www.warp.dev/"
    echo ""
    echo "2. Usar snap (si está disponible):"
    echo "   sudo snap install warp-terminal"
    echo ""
    echo "3. Usar Flatpak (si está disponible):"
    echo "   flatpak install flathub dev.warp.Warp"
    echo ""
    echo "4. Para Arch Linux con AUR:"
    echo "   yay -S warp-terminal-bin"
    echo ""
    echo "Nota: Warp Terminal está en desarrollo activo para Linux"
    echo "y la disponibilidad puede variar según la distribución."
}

install_warp_snap() {
    echo "Instalando Warp Terminal usando snap..."
    
    # Verificar si snap está disponible
    if ! command -v snap &> /dev/null; then
        echo "Instalando snapd..."
        case $PACKAGE_MANAGER in
            apt)
                run_command "sudo apt update -y"
                run_command "sudo apt install -y snapd"
                ;;
            dnf)
                run_command "sudo dnf install -y snapd"
                run_command "sudo systemctl enable --now snapd"
                run_command "sudo ln -sf /var/lib/snapd/snap /snap"
                ;;
            pacman)
                echo "⚠️  Para Arch Linux, instala snapd manualmente:"
                echo "    yay -S snapd"
                echo "    sudo systemctl enable --now snapd"
                return 1
                ;;
            zypper)
                run_command "sudo zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Leap_15.2 snappy"
                run_command "sudo zypper --gpg-auto-import-keys refresh"
                run_command "sudo zypper dup --from snappy"
                run_command "sudo zypper install snapd"
                ;;
            apk)
                echo "⚠️  Snap no está disponible oficialmente para Alpine Linux."
                echo "Por favor, instala Warp manualmente desde https://www.warp.dev/"
                return 1
                ;;
        esac
    fi
    
    # Instalar Warp con snap
    echo "Instalando Warp Terminal con snap..."
    run_command "sudo snap install warp-terminal"
    
    echo "✓ Warp Terminal instalado vía snap."
}

install_warp_appimage() {
    echo "Instalando Warp Terminal como AppImage..."
    
    # Crear directorio para AppImages
    local APPIMAGE_DIR="/opt"
    local WARP_APPIMAGE="$APPIMAGE_DIR/warp-terminal.appimage"
    
    # Instalar FUSE si es necesario
    echo "Verificando dependencias para AppImage..."
    case $PACKAGE_MANAGER in
        apt)
            run_command "sudo apt install -y libfuse2"
            ;;
        dnf)
            run_command "sudo dnf install -y fuse-libs"
            ;;
        pacman)
            run_command "sudo pacman -S --noconfirm fuse2"
            ;;
        zypper)
            run_command "sudo zypper install -y fuse-libs"
            ;;
        apk)
            run_command "sudo apk add --no-cache fuse2-libs"
            ;;
    esac
    
    # Descargar AppImage
    echo "Descargando Warp Terminal AppImage..."
    if command -v wget &> /dev/null; then
        run_command "sudo wget -q --show-progress -O $WARP_APPIMAGE 'https://app.warp.dev/get_warp?package=appimage'"
    elif command -v curl &> /dev/null; then
        run_command "sudo curl -L -o $WARP_APPIMAGE 'https://app.warp.dev/get_warp?package=appimage'"
    else
        echo "Error: Ni wget ni curl están instalados." >&2
        return 1
    fi
    
    # Hacer ejecutable
    run_command "sudo chmod +x $WARP_APPIMAGE"
    
    # Crear entrada de escritorio
    echo "Creando entrada de escritorio..."
    local DESKTOP_ENTRY="/usr/share/applications/warp-terminal.desktop"
    sudo bash -c "cat > $DESKTOP_ENTRY << EOF
[Desktop Entry]
Name=Warp Terminal
Exec=$WARP_APPIMAGE
Icon=warp-terminal
Type=Application
Categories=Development;TerminalEmulator;
Terminal=false
Comment=A modern terminal built for developers
EOF"
    
    run_command "sudo chmod 644 $DESKTOP_ENTRY"
    
    # Crear symlink para comando
    if [ ! -L /usr/local/bin/warp-terminal ]; then
        run_command "sudo ln -sf $WARP_APPIMAGE /usr/local/bin/warp-terminal"
    fi
    
    echo "✓ Warp Terminal AppImage instalado en $WARP_APPIMAGE"
    echo "✓ Comando disponible: warp-terminal"
}

install_chrome_dev() {
    print_header "Instalando Google Chrome Dev"
    
    # Verificar si Chrome Dev ya está instalado
    if command -v google-chrome-unstable &> /dev/null; then
        echo "✓ Google Chrome Dev ya está instalado."
        echo "Versión actual: $(google-chrome-unstable --version 2>/dev/null || echo 'No disponible')"
        read -p "¿Deseas reinstalar o actualizar Chrome Dev? (y/N): " reinstall_chrome
        if [[ ! "$reinstall_chrome" =~ ^[Yy]$ ]]; then
            echo "Instalación de Chrome Dev cancelada."
            return 0
        fi
        echo "Procediendo con la instalación/actualización..."
    fi
    
    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "Instalando Google Chrome Dev para Debian/Ubuntu..."
            
            # Instalar dependencias
            run_command "sudo apt update -y"
            run_command "sudo apt install -y wget gpg software-properties-common apt-transport-https"
            
            # Añadir clave GPG de Google
            echo "Añadiendo clave GPG de Google..."
            if [ ! -f /etc/apt/keyrings/google-chrome.gpg ]; then
                run_command "wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg"
            else
                echo "✓ Clave GPG de Google ya existe."
            fi
            
            # Añadir repositorio de Chrome
            echo "Configurando repositorio de Google Chrome..."
            if [ ! -f /etc/apt/sources.list.d/google-chrome.list ]; then
                run_command "echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main\" | sudo tee /etc/apt/sources.list.d/google-chrome.list"
            else
                echo "✓ Repositorio de Google Chrome ya está configurado."
            fi
            
            # Actualizar e instalar Chrome Dev
            run_command "sudo apt update -y"
            run_command "sudo apt install -y google-chrome-unstable"
            ;;
            
        fedora)
            echo "Instalando Google Chrome Dev para Fedora..."
            
            # Añadir repositorio de Google Chrome
            if [ ! -f /etc/yum.repos.d/google-chrome.repo ]; then
                sudo bash -c 'cat > /etc/yum.repos.d/google-chrome.repo << EOF
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF'
                echo "✓ Repositorio de Google Chrome configurado."
            else
                echo "✓ Repositorio de Google Chrome ya existe."
            fi
            
            # Instalar Chrome Dev
            run_command "sudo dnf install -y google-chrome-unstable"
            ;;
            
        arch|manjaro)
            echo "Instalando Google Chrome Dev para Arch Linux..."
            
            if command -v yay &> /dev/null; then
                echo "Usando yay para instalar desde AUR..."
                run_command "yay -S --noconfirm google-chrome-dev"
            elif command -v paru &> /dev/null; then
                echo "Usando paru para instalar desde AUR..."
                run_command "paru -S --noconfirm google-chrome-dev"
            else
                echo "⚠️  No se encontró un helper de AUR (yay/paru)."
                echo "Instalando desde snap como alternativa..."
                if command -v snap &> /dev/null; then
                    run_command "sudo snap install chromium --edge"
                    echo "⚠️  Se instaló Chromium Edge en lugar de Chrome Dev (no disponible en snap)."
                else
                    echo "Error: Ni AUR helpers ni snap están disponibles." >&2
                    echo "Por favor, instala Chrome Dev manualmente desde https://www.google.com/chrome/dev/"
                    return 1
                fi
            fi
            ;;
            
        opensuse|sles)
            echo "Instalando Google Chrome Dev para openSUSE..."
            
            # Importar clave GPG
            run_command "sudo rpm --import https://dl.google.com/linux/linux_signing_key.pub"
            
            # Añadir repositorio
            if ! sudo zypper lr | grep -q "google-chrome"; then
                run_command "sudo zypper addrepo http://dl.google.com/linux/chrome/rpm/stable/x86_64 google-chrome"
                run_command "sudo zypper refresh"
            else
                echo "✓ Repositorio de Google Chrome ya existe."
            fi
            
            # Instalar Chrome Dev
            run_command "sudo zypper install -y google-chrome-unstable"
            ;;
            
        alpine)
            echo "Instalando Chromium (alternativa a Chrome) para Alpine..."
            echo "⚠️  Google Chrome no está disponible oficialmente para Alpine Linux."
            run_command "sudo apk add --no-cache chromium"
            echo "✓ Chromium instalado como alternativa a Chrome Dev."
            ;;
            
        *)
            echo "Distribución $DISTRO no reconocida. Intentando descarga directa..."
            
            # Descarga directa del paquete DEB
            echo "Descargando Google Chrome Dev directamente..."
            local TEMP_DIR="/tmp/chrome_install"
            run_command "mkdir -p $TEMP_DIR"
            
            if command -v wget &> /dev/null; then
                run_command "wget -q --show-progress -O $TEMP_DIR/google-chrome-unstable.deb https://dl.google.com/linux/direct/google-chrome-unstable_current_amd64.deb"
            elif command -v curl &> /dev/null; then
                run_command "curl -L -o $TEMP_DIR/google-chrome-unstable.deb https://dl.google.com/linux/direct/google-chrome-unstable_current_amd64.deb"
            else
                echo "Error: Ni wget ni curl están instalados." >&2
                return 1
            fi
            
            # Intentar instalación directa
            if [ -f "$TEMP_DIR/google-chrome-unstable.deb" ]; then
                run_command "sudo dpkg -i $TEMP_DIR/google-chrome-unstable.deb"
                run_command "sudo apt-get install -f -y" # Resolver dependencias
            fi
            
            run_command "rm -rf $TEMP_DIR"
            ;;
    esac
    
    # Verificar instalación
    echo ""
    echo "=== Verificando instalación ==="
    if command -v google-chrome-unstable &> /dev/null; then
        echo "✓ Google Chrome Dev instalado correctamente."
        echo "Versión: $(google-chrome-unstable --version 2>/dev/null || echo 'Disponible')"
        echo ""
        echo "Para abrir Chrome Dev:"
        echo "  - Desde terminal: google-chrome-unstable"
        echo "  - Desde el menú de aplicaciones: Google Chrome (Dev)"
        echo ""
        echo "Características de Chrome Dev:"
        echo "  - Últimas funcionalidades experimentales"
        echo "  - Herramientas de desarrollo más recientes"
        echo "  - APIs web más nuevas"
        echo "  - Ideal para desarrollo web"
    elif command -v chromium &> /dev/null; then
        echo "✓ Chromium instalado correctamente (alternativa a Chrome Dev)."
        echo "Versión: $(chromium --version 2>/dev/null || echo 'Disponible')"
    else
        echo "❌ Error: Chrome Dev no se instaló correctamente."
        echo ""
        echo "Métodos alternativos:"
        echo "1. Descargar manualmente desde: https://www.google.com/chrome/dev/"
        echo "2. Usar Flatpak: flatpak install flathub com.google.Chrome"
        return 1
    fi
}
# Funciones para herramientas adicionales

install_oh_my_posh() {
    print_header "Instalando Oh My Posh"
    
    # Verificar si ya está instalado
    if command -v oh-my-posh &> /dev/null; then
        echo "Oh My Posh ya está instalado."
        return 0
    fi

    # Instalar dependencias necesarias
    echo "Instalando dependencias..."
    run_command "$INSTALL_COMMAND wget unzip fonts-powerline"
    
    # Descargar e instalar Oh My Posh
    echo "Descargando Oh My Posh..."
    run_command "wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /tmp/oh-my-posh"
    run_command "chmod +x /tmp/oh-my-posh"
    run_command "sudo mv /tmp/oh-my-posh /usr/local/bin/"
    
    # Crear directorio para temas si no existe
    run_command "mkdir -p ~/.cache/oh-my-posh/themes"
    
    # Descargar tema powerline
    echo "Descargando tema powerline..."
    run_command "wget https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/powerline.omp.json -O ~/.cache/oh-my-posh/themes/powerline.omp.json"
    
    # Configurar .bashrc
    local bashrc_path="$HOME/.bashrc"
    local oh_my_posh_config="# Oh My Posh Configuration\nexport PATH=\$PATH:~/.local/bin\neval \"\$(oh-my-posh init bash --config ~/.cache/oh-my-posh/themes/powerline.omp.json)\""
    
    if ! grep -q "Oh My Posh Configuration" "$bashrc_path"; then
        echo -e "\n$oh_my_posh_config" >> "$bashrc_path"
        echo "Configuración de Oh My Posh añadida a $bashrc_path"
    else
        echo "La configuración de Oh My Posh ya existe en $bashrc_path"
    fi
    
    echo "¡Oh My Posh instalado correctamente!"
    echo "Por favor, reinicia tu terminal o ejecuta 'source ~/.bashrc' para ver los cambios."
}

install_copilot_cli() {
    print_header "Instalando GitHub Copilot CLI"
    
    # Verificar si ya está instalado
    if command -v github-copilot-cli &> /dev/null; then
        echo "GitHub Copilot CLI ya está instalado."
        return 0
    fi
    
    # Verificar si Node.js está instalado
    if ! command -v node &> /dev/null; then
        echo "Node.js no está instalado. Instalando Node.js..."
        install_nvm_node_npm
        if ! command -v node &> /dev/null; then
            echo "Error: No se pudo instalar Node.js. Por favor, instálalo manualmente."
            return 1
        fi
    fi
    
    # Instalar GitHub Copilot CLI
    echo "Instalando GitHub Copilot CLI..."
    run_command "npm install -g @githubnext/github-copilot-cli"
    
    # Configuración inicial
    echo "Configurando GitHub Copilot CLI..."
    echo "Por favor, sigue las instrucciones para autenticarte con GitHub."
    run_command "github-copilot-cli auth"
    
    echo "¡GitHub Copilot CLI instalado correctamente!"
    echo "Puedes usarlo con los comandos:"
    echo "  - github-copilot-cli what-the-shell [comando] - Explicar un comando"
    echo "  - github-copilot-cli suggest - Generar sugerencias de comandos"
}

# --- Menú Principal ---

show_menu() {
    print_header "Menú de Instalación y Configuración de Herramientas de Desarrollo"
    echo "Por favor, selecciona una opción:"
    echo "  1) Actualizar el Sistema (apt update & upgrade, dnf update, pacman -Syu, etc.)"
    echo "  2) Instalar Utilidades Básicas de Linux y Git"
    echo "  3) Configurar .gitconfig (Eduardo Macias, herwingmacias@gmail.com)"
    echo "  4) Generar Clave SSH (RSA 4096-bit)"
    echo "  5) Añadir Alias Personalizados a .bashrc"
    echo "  6) Instalar NVM (Node Version Manager) y Node.js (Recomendado para desarrollo)"
    echo "  7) Instalar Node.js y NPM Globalmente (sin NVM - ¡Advertencia de conflicto!)"
    echo "  8) Instalar Gemini CLI"
    echo "  9) Instalar GitHub CLI (gh)"
    echo " 10) Instalar Bitwarden CLI"
    echo " 11) Instalar Tailscale"
    echo " 12) Instalar Brave Browser"
    echo " 13) Instalar Cursor (AI Code Editor) - Requiere AppImage local"
    echo " 14) Instalar Docker CLI (Engine, Compose, Buildx)"
    echo " 15) Instalar Docker Desktop"
    echo " 16) Instalar Fuentes (Cascadia Code, Caskaydia Cove Nerd Font)"
    echo " 17) Instalar Visual Studio Code"
    echo " 18) Instalar Warp Terminal - Requiere archivo .deb/rpm local"
    echo " 19) Instalar Google Chrome Dev"
    echo " 20) Instalar Oh My Posh (Terminal personalizada)"
    echo " 21) Instalar GitHub Copilot CLI"
    echo " 22) Instalar TODAS las herramientas (usa NVM para Node.js)"
    echo "  0) Salir"
    echo -n "Tu elección: "
}

main() {
    detect_distro_and_package_manager

    while true; do
        show_menu
        read -r choice
        echo ""

        case $choice in
            1) update_system ;;
            2) install_basic_utilities ;;
            3) configure_gitconfig ;;
            4) generate_ssh_key ;;
            5) add_bash_aliases ;;
            6) install_nvm_node_npm ;;
            7) install_nodejs_global_without_nvm ;;
            8) install_gemini_cli ;;
            9) install_github_cli ;;
            10) install_bitwarden_cli ;;
            11) install_tailscale ;;
            12) install_brave_browser ;;
            13) install_cursor_appimage ;;
            14) install_docker_cli ;;
            15) install_docker_desktop_with_dependencies ;;
            16) install_fonts ;;
            17) install_vscode ;;
            18) install_warp_terminal ;;
            19) install_chrome_dev ;;
            20) install_oh_my_posh ;;
            21) install_copilot_cli ;;
            22)
                echo "Instalando todas las herramientas..."
                update_system || { echo "Advertencia: Fallo al actualizar el sistema. Continuando con otras instalaciones."; }
                install_basic_utilities || { echo "Fallo en utilidades básicas. Abortando 'Instalar Todo'."; exit 1; }
                
                # Configuraciones fundamentales
                configure_gitconfig || echo "Advertencia: Fallo en la configuración de .gitconfig. Continuando con otras instalaciones."
                generate_ssh_key || echo "Advertencia: Fallo en la generación de clave SSH. Continuando con otras instalaciones."
                add_bash_aliases || echo "Advertencia: Fallo al añadir alias a .bashrc. Continuando con otras instalaciones."
                
                # Entorno de desarrollo (Node.js como dependencia clave)
                install_nvm_node_npm || { echo "Fallo en NVM/Node.js. Abortando 'Instalar Todo'."; exit 1; }
                install_gemini_cli || echo "Advertencia: Fallo en Gemini CLI. Continuando con otras instalaciones."
                install_bitwarden_cli || echo "Advertencia: Fallo en Bitwarden CLI. Continuando con otras instalaciones."
                
                # Otras herramientas
                install_github_cli || echo "Advertencia: Fallo en GitHub CLI. Continuando con otras instalaciones."
                install_tailscale || echo "Advertencia: Fallo en Tailscale. Continuando con otras instalaciones."
                install_brave_browser || echo "Advertencia: Fallo en Brave Browser. Continuando con otras instalaciones."
                install_cursor_appimage || echo "Advertencia: Fallo en Cursor AppImage. Asegúrate de que el AppImage esté en el directorio del script."
                install_vscode || echo "Advertencia: Fallo en VS Code. Continuando con otras instalaciones."
                install_warp_terminal || echo "Advertencia: Fallo en Warp Terminal. Continuando con otras instalaciones."
                install_chrome_dev || echo "Advertencia: Fallo en Chrome Dev. Continuando con otras instalaciones."
                install_rustdesk || echo "Advertencia: Fallo en RustDesk. Continuando con otras instalaciones."
                choose_docker_installation || echo "Advertencia: Fallo en la instalación de Docker. Continuando con otras instalaciones."
                configure_firewall_ssh || echo "Advertencia: Fallo en la configuración del firewall. Continuando con otras instalaciones."
                install_fonts || echo "Advertencia: Fallo en la instalación de fuentes. Continuando con otras instalaciones."
                install_oh_my_posh || echo "Advertencia: Fallo al instalar Oh My Posh. Continuando con otras instalaciones."
                install_copilot_cli || echo "Advertencia: Fallo al instalar GitHub Copilot CLI. Continuando con otras instalaciones."
                
                echo -e "\n=============================================="
                echo -e "  ¡Instalación de TODAS las herramientas completada!"
                echo -e "  Por favor, revisa los mensajes anteriores para cualquier advertencia o paso manual."
                echo -e "  Recuerda reiniciar tu sesión o sistema para que todos los cambios surtan efecto (especialmente Docker, NVM y alias)."
                ;;
            0) 
                echo "Saliendo..."
                exit 0 
                ;;
            *)
                echo "Opción no válida. Intenta de nuevo."
                ;;
        esac
        echo -e "\nPresiona Enter para continuar..."
        read -r -s
    done
}

# Ejecutar el menú principal
main
