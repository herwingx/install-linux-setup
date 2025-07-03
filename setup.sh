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
        DISTRO_ID_LIKE="${ID_LIKE}" # e.g., "debian" for Ubuntu
        DISTRO="${ID}" # e.g., "ubuntu", "fedora", "debian"
        VERSION_ID="${VERSION_ID}" # e.g., "22.04", "11", "39"
        echo "Distribución detectada: $DISTRO (ID_LIKE: $DISTRO_ID_LIKE, Versión: $VERSION_ID)"
    else
        echo "No se pudo detectar la distribución usando /etc/os-release." >&2
        echo "Asumiendo un sistema basado en Debian/Ubuntu como fallback."
        DISTRO="debian" # Fallback
        DISTRO_ID_LIKE="debian"
        VERSION_ID="unknown"
    fi

    if command -v apt &> /dev/null; then
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

    local common_utils=("tree" "unzip" "net-tools" "curl" "wget" "htop" "btop" "grep" "awk" "cut" "paste" "sort" "tr" "head" "tail" "join" "split" "tee" 
"nl" "wc" "expand" "unexpand" "uniq")

    echo "Instalando utilidades comunes..."
    for util in "${common_utils[@]}"; do
        if ! command -v "$util" &> /dev/null; then
            echo "Instalando $util..."
            run_command "$INSTALL_COMMAND $util"
        else
            echo "$util ya está instalado."
        fi
    done

    # Instalación de fastfetch
    echo "Instalando fastfetch..."
    case $DISTRO in
        ubuntu)
            # Para Ubuntu 22.04 o más reciente
            if lsb_release -r -s | grep -qE "^2[2-9]\."; then
                echo "Detectado Ubuntu 22.04+ o superior. Usando PPA para fastfetch."
                run_command "sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y"
                run_command "sudo apt update -y"
                run_command "sudo apt install -y fastfetch"
            else
                echo "Ubuntu versión anterior. Intentando instalar fastfetch desde el repositorio estándar."
                run_command "$INSTALL_COMMAND fastfetch"
            fi
            ;;
        debian)
            # Para Debian 13 o más reciente
            # Usamos VERSION_ID que se obtiene de /etc/os-release
            if [ "$(echo "$VERSION_ID >= 13" | bc -l)" -eq 1 ]; then
                echo "Detectado Debian 13+ o superior. Usando apt install fastfetch."
                run_command "$INSTALL_COMMAND fastfetch"
            else
                echo "Debian versión anterior. Intentando instalar fastfetch desde el repositorio estándar."
                run_command "$INSTALL_COMMAND fastfetch"
            F
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
            run_command "$INSTALL_COMMAND fastfetch"
            ;;
        *)
            echo "Instalación de fastfetch para $DISTRO no implementada con método específico. Intentando instalación genérica."
            run_command "$INSTALL_COMMAND fastfetch"
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
	email = herwingmacias@gmail.com
[init]
	defaultBranch = main
[alias]
	s = status -s -b
	lg = log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim 
white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all
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
        "# some more ls aliases"
        "alias ll='ls -alF'"
        "alias la='ls -A'"
        "alias l='ls -CF'"
        "# alias code='code-insiders'"
        "alias size='du -h --max-depth=1 ~/'"
        "alias storage='df -h'"
        "alias up='sudo apt update && sudo apt upgrade'"
        "alias list-size='du -h --max-depth=1 | sort -hr'"
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
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x ${DISTRO_CODENAME} main" | sudo tee 
/etc/apt/sources.list.d/nodesource.list >/dev/null
            echo "deb-src [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x ${DISTRO_CODENAME} main" | sudo tee -a 
/etc/apt/sources.list.d/nodesource.list >/dev/null
            
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
            run_command "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] 
https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
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
    echo "Descargando y ejecutando el script de instalación oficial de Tailscale..."
    if ! command -v curl &> /dev/null; then
        echo "Error: 'curl' no está instalado. Por favor, instala curl para poder instalar Tailscale." >&2
        return 1
    fi
    run_command "curl -fsSL https://tailscale.com/install.sh | sh"
    echo "Tailscale ha sido instalado."
    echo "Para iniciar y autenticar Tailscale, ejecuta el siguiente comando en tu terminal:"
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

    # 1. Buscar el archivo AppImage en el directorio actual
    local CURSOR_APPIMAGE_SOURCE=$(find . -maxdepth 1 -type f -iname "Cursor*.AppImage" | head -n 1)

    if [ -z "$CURSOR_APPIMAGE_SOURCE" ]; then
        echo "Error: No se encontró ningún archivo Cursor AppImage en el directorio actual." >&2
        echo "Por favor, descarga el AppImage de Cursor (versión x64) desde https://cursor.com/en/downloads"
        echo "y colócalo en el mismo directorio donde ejecutas este script antes de intentar instalarlo."
        return 1
    fi

    echo "AppImage de Cursor encontrado: $CURSOR_APPIMAGE_SOURCE"

    # 2. Instalar dependencia FUSE
    echo "Verificando e instalando dependencia FUSE (libfuse2)..."
    case $PACKAGE_MANAGER in
        apt)
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
            echo "Advertencia: La instalación de FUSE para $PACKAGE_MANAGER no está implementada. Podría ser necesaria la instalación manual de 
libfuse2/fuse-libs/fuse2."
            ;;
    esac

    # 3. Mover y hacer ejecutable
    echo "Moviendo Cursor AppImage a /opt/cursor.appimage y haciendo ejecutable..."
    run_command "sudo mv \"$CURSOR_APPIMAGE_SOURCE\" /opt/cursor.appimage"
    run_command "sudo chmod +x /opt/cursor.appimage"

    # 4. Crear entrada de escritorio
    echo "Creando entrada de escritorio para Cursor..."
    local CURSOR_DESKTOP_ENTRY="/usr/share/applications/cursor.desktop"
    sudo bash -c "cat > $CURSOR_DESKTOP_ENTRY <<EOF
[Desktop Entry]
Name=Cursor
Exec=/opt/cursor.appimage --no-sandbox # Se añade --no-sandbox por seguridad/compatibilidad
Icon=/opt/cursor.png # Requerirá un icono. Instrucciones para usuario.
Type=Application
Categories=Development;IDE;
EOF"
    run_command "sudo chmod 644 $CURSOR_DESKTOP_ENTRY" # Permisos de lectura

    # 5. Instrucción para el icono
    echo "--- PASO MANUAL PARA EL ICONO ---"
    echo "Para que el icono de Cursor aparezca, necesitas descargar un archivo 'cursor.png' (por ejemplo, el logo de Cursor) y colocarlo en /opt/."
    echo "Comando sugerido (después de descargar el .png en tu carpeta actual):"
    echo "  sudo cp ~/Downloads/cursor.png /opt/cursor.png"
    echo "---------------------------------"

    echo "Cursor instalado. Puede que necesites reiniciar tu sesión para ver el icono en el menú de aplicaciones."
    echo "Para ejecutarlo desde la terminal: /opt/cursor.appimage --no-sandbox"
}

install_docker_cli() {
    print_header "Instalando Docker CLI (Engine, Compose, Buildx, containerd)"

    case $DISTRO in
        ubuntu|debian|kali|parrot)
            echo "Configurando repositorio oficial de Docker para Debian/Ubuntu/Kali/Parrot..."
            run_command "sudo apt-get update"
            run_command "sudo apt-get install -y ca-certificates curl gnupg lsb-release" # lsb-release para UBUNTU_CODENAME
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
            run_command "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu 
${DISTRO_CODENAME} stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
            
            run_command "sudo apt-get update -y"
            echo "Instalando Docker Engine y complementos..."
            run_command "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
            ;;
        fedora)
            echo "Configurando repositorio oficial de Docker para Fedora..."
            run_command "sudo dnf -y install dnf-plugins-core"
            run_command "sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo"
            echo "Instalando Docker Engine y complementos..."
            run_command "sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
            ;;
        arch)
            echo "Instalando Docker CLI y complementos con pacman en Arch Linux..."
            run_command "sudo pacman -S --noconfirm docker docker-compose" # docker-compose es el plugin
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

install_docker_desktop() {
    print_header "Instalando Docker Desktop"

    local DOCKER_DESKTOP_URL=""
    local DOCKER_DESKTOP_PACKAGE=""

    # Verificar arquitectura (asumimos amd64 por los enlaces, pero es buena práctica)
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
            run_command "sudo apt install -y fontconfig"
            ;;
        dnf)
            run_command "sudo dnf install -y fontconfig"
            ;;
        pacman)
            run_command "sudo pacman -S --noconfirm fontconfig"
            ;;
        zypper)
            run_command "sudo zypper install -y fontconfig"
            ;;
        apk)
            run_command "sudo apk add --no-cache fontconfig"
            ;;
    esac

    # Cascadia Code (latest stable release)
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
    echo "Cascadia Code instalado."

    # Caskaydia Cove Nerd Font (patched Cascadia Code) - get latest stable
    echo "Descargando e instalando Caskaydia Cove Nerd Font..."
    local CAS_COVE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CaskaydiaCove.zip"
    local CAS_COVE_ZIP="/tmp/CaskaydiaCove.zip"
    local CAS_COVE_EXTRACT_DIR="/tmp/CaskaydiaCove_extracted"

    if command -v wget &> /dev/null; then
        run_command "wget -q --show-progress -O \"$CAS_COVE_ZIP\" \"$CAS_COVE_URL\""
    elif command -v curl &> /dev/null; then
        run_command "curl -L -o \"$CAS_COVE_ZIP\" \"$CAS_COVE_URL\""
    else
        echo "Error: Ni wget ni curl están instalados. No se pueden descargar las fuentes." >&2
        return 1
    fi

    run_command "unzip -o \"$CAS_COVE_ZIP\" -d \"$CAS_COVE_EXTRACT_DIR\""
    run_command "cp \"$CAS_COVE_EXTRACT_DIR\"/*.ttf \"$FONT_DIR\"/" # Copy TTF files
    run_command "rm -rf \"$CAS_COVE_ZIP\" \"$CAS_COVE_EXTRACT_DIR\""
    echo "Caskaydia Cove Nerd Font instalado."
    
    echo "Actualizando la caché de fuentes..."
    run_command "fc-cache -fv"

    echo "Fuentes Cascadia Code y Caskaydia Cove instaladas."
    echo "Puede que necesites configurar tu terminal o editor para usar estas nuevas fuentes."
    echo "Nota: La instalación de fuentes tipo 'Mac late 2014' no se realiza automáticamente debido a su naturaleza propietaria. Puedes buscar 
alternativas open source como Fira Code, Hack o Roboto Mono."
}

configure_firewall_ssh() {
    print_header "Configurando Firewall para SSH (Puerto 22)"
    echo "Intentando configurar el firewall para permitir conexiones SSH (puerto 22)."

    if command -v ufw &> /dev/null; then
        echo "UFW detectado. Configurando UFW..."
        if sudo ufw status | grep -q "inactive"; then
            echo "UFW está inactivo. Habilitándolo y permitiendo OpenSSH."
            run_command "sudo ufw allow OpenSSH"
            run_command "sudo ufw enable"
        else
            echo "UFW está activo. Asegurando que OpenSSH esté permitido."
            run_command "sudo ufw allow OpenSSH"
            run_command "sudo ufw reload"
        fi
        echo "UFW configurado para SSH."
    elif command -v firewall-cmd &> /dev/null; then
        echo "FirewallD detectado. Configurando FirewallD..."
        if sudo systemctl is-active --quiet firewalld; then
            echo "FirewallD está activo. Añadiendo servicio SSH y recargando."
            run_command "sudo firewall-cmd --permanent --add-service=ssh"
            run_command "sudo firewall-cmd --reload"
        else
            echo "FirewallD está inactivo. Habilitando y añadiendo servicio SSH."
            run_command "sudo systemctl enable --now firewalld"
            run_command "sudo firewall-cmd --permanent --add-service=ssh"
            run_command "sudo firewall-cmd --reload"
        fi
        echo "FirewallD configurado para SSH."
    else
        echo "No se detectó UFW ni FirewallD. No se puede configurar el firewall automáticamente."
        echo "Si utilizas otro firewall (ej. iptables), deberás configurarlo manualmente para permitir el puerto 22."
        echo "  Ejemplo para iptables (permitir SSH):"
        echo "    sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"
        echo "    sudo iptables -A OUTPUT -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT"
        echo "  (Recuerda guardar las reglas de iptables para que persistan tras el reinicio)."
    fi
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
    echo " 13) Instalar Cursor (AI Code Editor) AppImage"
    echo " 14) Instalar Docker CLI (Engine, Compose, Buildx)"
    echo " 15) Instalar Docker Desktop"
    echo " 16) Instalar Fuentes (Cascadia Code, Caskaydia Cove Nerd Font)"
    echo " 17) Configurar Firewall para SSH (Puerto 22)"
    echo " 18) Instalar TODAS las herramientas (usa NVM para Node.js)"
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
            15) install_docker_desktop ;;
            16) install_fonts ;;
            17) configure_firewall_ssh ;;
            18)
                print_header "Instalando TODAS las herramientas"
                echo "Nota: La opción 'Instalar Node.js y NPM Globalmente (sin NVM)' NO se incluye en 'Instalar TODAS las herramientas' para evitar 
conflictos."
                echo "Además, Docker CLI y Docker Desktop son mutuamente excluyentes en la instalación automática 'Todo'. Se instalará Docker CLI."
                sleep 2
                
                # Priorizar actualizaciones y utilidades base
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
                install_docker_cli || echo "Advertencia: Fallo en Docker CLI. Continuando con otras instalaciones."
                configure_firewall_ssh || echo "Advertencia: Fallo en la configuración del firewall. Continuando con otras instalaciones."
                install_fonts || echo "Advertencia: Fallo en la instalación de fuentes. Continuando con otras instalaciones."

                echo -e "\n=============================================="
                echo -e "  ¡Instalación de TODAS las herramientas completada!"
                echo -e "  Por favor, revisa los mensajes anteriores para cualquier advertencia o paso manual."
                echo -e "  Recuerda reiniciar tu sesión o sistema para que todos los cambios surtan efecto (especialmente Docker, NVM y alias)."
                echo -e "==============================================\n"
                break
                ;;
            0)
                echo "Saliendo del script. ¡Adiós!"
                exit 0
                ;;
            *)
                echo "Opción inválida. Por favor, intenta de nuevo."
                ;;
        esac
        echo -e "\nPresiona Enter para continuar..."
        read -r -s
    done
}

# Ejecutar el menú principal
main
