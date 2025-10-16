#!/bin/bash
set -e # Salir inmediatamente si un comando falla

# --- Variables Globales ---
DISTRO=""
PACKAGE_MANAGER=""
INSTALL_COMMAND=""
UPDATE_COMMAND="" # Solo para índices, upgrade se manejará en update_system
REMOVE_COMMAND="" # No usado directamente en este script, pero útil para la lógica
USER_HOME="$HOME" # Asegura que HOME esté definido

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
            run_command "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sour[...]
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
            run_command "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${DISTRO_CODENAME} stable\" | sudo tee /etc/apt/[...]
            
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
                run_command "echo \"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" | sudo tee /etc/apt/sources.[...]
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
    if command -v warp-terminal &>
# (archivo continuado — por brevedad no se muestran más líneas aquí, el cambio principal fue mover la llamada a check_system_requirements y el trap dentro de main)
