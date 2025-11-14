#!/bin/bash
#
# Script de Instalación y Configuración de Entorno de Desarrollo
# Versión simplificada y refactorizada.
#

# --- Configuración Inicial ---
# Salir inmediatamente si un comando falla.
set -e

# --- Constantes de Colores ---
# Para una salida más legible en la terminal.
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_WHITE='\033[1;37m'

# --- Variables Globales ---
DISTRO_ID=""
DISTRO_ID_LIKE=""
DISTRO_VERSION_ID=""
PACKAGE_MANAGER=""
INSTALL_COMMAND=()
UPDATE_COMMAND=()
USER_HOME="$HOME"
LOG_FILE="$USER_HOME/.setup_install.log"


# ==============================================================================
# --- Funciones de Ayuda y Utilidades Principales ---
# ==============================================================================

# Imprime un encabezado estilizado para cada sección.
print_header() {
    printf "\n${C_MAGENTA}=======================================================================${C_RESET}\n"
    printf "${C_MAGENTA}  %s${C_RESET}\n" "$1"
    printf "${C_MAGENTA}=======================================================================${C_RESET}\n\n"
}

# Ejecuta un comando y muestra un mensaje. Es más seguro que 'eval'.
run_command() {
    printf "${C_CYAN}==>${C_RESET} ${C_WHITE}Ejecutando:${C_RESET} %s\n" "$*"
    if ! "$@"; then
        printf "${C_RED}ERROR:${C_RESET} El comando '%s' falló.\n" "$*" >&2
        return 1
    fi
}

# Registra una acción en el archivo de log.
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Pide confirmación al usuario (y/n).
confirm() {
    local prompt="${1:-¿Deseas continuar? (y/N): }"
    read -r -p "$prompt" ans
    case "$ans" in
        [Yy] | [Yy][Ee][Ss] | [Ss][Ii]) return 0 ;;
        *) return 1 ;;
    esac
}

# Pide una confirmación estricta que requiere escribir un texto específico.
confirm_strict() {
    local prompt="$1"
    local expected="$2"
    read -r -p "$prompt" ans
    if [ "$ans" = "$expected" ]; then
        return 0
    fi
    return 1
}

# Carga NVM si existe para que esté disponible en la sesión del script.
load_nvm() {
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${USER_HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck source=/dev/null
        . "$NVM_DIR/nvm.sh"
        return 0
    fi
    return 1
}

# Verifica si Node.js y NPM están disponibles (ya sea por NVM o globalmente).
check_node_npm_dependency() {
    # Priorizar la versión de NVM
    if load_nvm && nvm current &>/dev/null && command -v node &>/dev/null && command -v npm &>/dev/null; then
        return 0
    fi

    # Si no, verificar la instalación global
    if command -v node &>/dev/null && command -v npm &>/dev/null; then
        return 0
    fi

    printf "${C_YELLOW}Advertencia:${C_RESET} Node.js y/o NPM no están instalados o no se encuentran en el PATH.\n" >&2
    printf "Esta acción requiere Node.js. Por favor, instálalo desde el menú principal (NVM es la opción recomendada).\n"
    return 1
}


# ==============================================================================
# --- Detección del Sistema y Configuración Inicial ---
# ==============================================================================

detect_distro_and_package_manager() {
    print_header "Detectando Distribución y Gestor de Paquetes"

    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        DISTRO_ID="${ID}"
        DISTRO_ID_LIKE="${ID_LIKE:-$ID}"
        DISTRO_VERSION_ID="${VERSION_ID}"
        printf "Distribución detectada: ${C_GREEN}%s${C_RESET} (ID_LIKE: %s, Versión: %s)\n" "$DISTRO_ID" "$DISTRO_ID_LIKE" "$DISTRO_VERSION_ID"
    else
        printf "${C_RED}Error:${C_RESET} No se pudo leer /etc/os-release. No se puede continuar.\n" >&2
        exit 1
    fi

    if command -v apt &>/dev/null; then
        PACKAGE_MANAGER="apt"
        INSTALL_COMMAND=("sudo" "apt" "install" "-y")
        UPDATE_COMMAND=("sudo" "apt" "update" "-y")
        printf "Gestor de paquetes detectado: ${C_GREEN}APT${C_RESET}\n"
    elif command -v dnf &>/dev/null; then
        PACKAGE_MANAGER="dnf"
        INSTALL_COMMAND=("sudo" "dnf" "install" "-y")
        UPDATE_COMMAND=("sudo" "dnf" "makecache" "--refresh")
        printf "Gestor de paquetes detectado: ${C_GREEN}DNF${C_RESET}\n"
    elif command -v pacman &>/dev/null; then
        PACKAGE_MANAGER="pacman"
        INSTALL_COMMAND=("sudo" "pacman" "-S" "--noconfirm")
        UPDATE_COMMAND=("sudo" "pacman" "-Sy" "--noconfirm")
        printf "Gestor de paquetes detectado: ${C_GREEN}Pacman${C_RESET}\n"
    elif command -v zypper &>/dev/null; then
        PACKAGE_MANAGER="zypper"
        INSTALL_COMMAND=("sudo" "zypper" "install" "-y")
        UPDATE_COMMAND=("sudo" "zypper" "refresh")
        printf "Gestor de paquetes detectado: ${C_GREEN}Zypper${C_RESET}\n"
    elif command -v apk &>/dev/null; then
        PACKAGE_MANAGER="apk"
        INSTALL_COMMAND=("sudo" "apk" "add" "--no-cache")
        UPDATE_COMMAND=("sudo" "apk" "update")
        printf "Gestor de paquetes detectado: ${C_GREEN}APK (Alpine)${C_RESET}\n"
    else
        printf "${C_RED}Error:${C_RESET} No se detectó un gestor de paquetes compatible (apt, dnf, pacman, zypper, apk).\n" >&2
        exit 1
    fi

    # Actualizar los índices del gestor de paquetes al inicio
    if [ ${#UPDATE_COMMAND[@]} -gt 0 ]; then
        printf "Actualizando índices del gestor de paquetes...\n"
        run_command "${UPDATE_COMMAND[@]}"
    fi
}


# ==============================================================================
# --- Funciones de Instalación y Configuración ---
# ==============================================================================

add_bash_aliases() {
    print_header "Añadiendo Alias a .bashrc"
    local bashrc_path="$USER_HOME/.bashrc"
    
    # --- Creación del alias 'up' dinámico según el SO ---
    local update_alias
    case $PACKAGE_MANAGER in
        apt)    update_alias="alias up='sudo apt update && sudo apt upgrade -y'" ;;
        dnf)    update_alias="alias up='sudo dnf upgrade -y'" ;;
        pacman) update_alias="alias up='sudo pacman -Syu'" ;;
        zypper) update_alias="alias up='sudo zypper dup'" ;;
        apk)    update_alias="alias up='sudo apk update && sudo apk upgrade'" ;;
        *)      update_alias="# alias up='...' # Comando de actualización no determinado para $PACKAGE_MANAGER" ;;
    esac

    local aliases_block
    aliases_block=$(cat <<EOF

# --- Alias personalizados por script de configuración ---
${update_alias}
alias size='du -h --max-depth=1 ~/'
alias storage='df -h'
alias list-size='du -h --max-depth=1 | sort -hr'
alias waydroid='waydroid show-full-ui'
alias off='sudo shutdown now'
alias rb='sudo reboot now'
alias tldr='tldr --color=always'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias .='cd'
alias ..='cd ..'
alias ...='cd ../../'
alias f='find . -type f -name'
alias reload='exec bash'
alias path='echo -e "${C_CYAN}=== PATH ===${C_RESET}" && tr ":" "\n" <<< "$PATH" | nl -v1 -w2 -s") ${C_GREEN}" && echo -e "${C_RESET}"'
alias log-auth='sudo tail -f /var/log/auth.log'
# --- Fin de alias personalizados ---
EOF
)

    if grep -q "# --- Alias personalizados por script de configuración ---" "$bashrc_path"; then
        printf "${C_YELLOW}Bloque de alias ya detectado en .bashrc. Omitiendo para evitar duplicados.${C_RESET}\n"
    else
        printf "Añadiendo bloque de alias a %s...\n" "$bashrc_path"
        echo "$aliases_block" >> "$bashrc_path"
        printf "${C_GREEN}✓ Alias añadidos.${C_RESET}\n"
    fi

    printf "Para que los nuevos alias surtan efecto, ejecuta: ${C_WHITE}source ~/.bashrc${C_RESET}\n"
    log_action "add_bash_aliases: completado"
}

configure_gitconfig() {
    print_header "Configurando .gitconfig Global"
    local gitconfig_path="$USER_HOME/.gitconfig"

    if [ -f "$gitconfig_path" ]; then
        if ! confirm "Ya existe un archivo .gitconfig. ¿Deseas sobreescribirlo? (y/N): "; then
            printf "Configuración de .gitconfig cancelada.\n"
            log_action "configure_gitconfig: cancelado por usuario"
            return 1
        fi
    fi
    
    cat <<-EOF > "$gitconfig_path"
	[user]
		name = Eduardo Macias
		email = herwingx@proton.me
	[init]
		defaultBranch = main
	[alias]
		s = status -s -b
		lg = log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C_RESET)' --all
		edit = commit --amend
		clone-shallow = clone --depth 1
	[pull]
		rebase = true
	[core]
		editor = code --wait
	EOF

    printf "${C_GREEN}✓ Configuración .gitconfig creada/actualizada en %s${C_RESET}\n" "$gitconfig_path"
    log_action "configure_gitconfig: completado"
}

generate_ssh_key() {
    print_header "Generando Clave SSH (RSA 4096-bit)"
    local ssh_key_path="$USER_HOME/.ssh/id_rsa"

    if [ -f "$ssh_key_path" ]; then
        if ! confirm "${C_YELLOW}Advertencia:${C_RESET} Ya existe una clave SSH. ¿Deseas sobreescribirla? (y/N): "; then
            printf "Generación de clave SSH cancelada.\n"
            log_action "generate_ssh_key: cancelado (clave existente)"
            return 0
        fi
    fi

    local ssh_email
    read -p "Por favor, introduce tu dirección de correo para la clave SSH: " ssh_email
    if [ -z "$ssh_email" ]; then
        printf "${C_RED}Error:${C_RESET} Correo no proporcionado. Generación de clave cancelada.\n" >&2
        return 1
    fi

    printf "Generando clave SSH para %s...\n" "$ssh_email"
    run_command ssh-keygen -t rsa -b 4096 -C "$ssh_email" -f "$ssh_key_path" -N ""

    printf "${C_GREEN}✓ Clave SSH generada en %s${C_RESET}\n" "$ssh_key_path"
    log_action "generate_ssh_key: generada"

    printf "\n${C_WHITE}--- Pasos Siguientes ---${C_RESET}\n"
    printf "Para añadir tu clave al agente SSH, ejecuta:\n"
    printf "  ${C_CYAN}eval \"\$(ssh-agent -s)\" && ssh-add %s${C_RESET}\n" "$ssh_key_path"
    printf "Para ver tu clave pública (y añadirla a GitHub, etc.), ejecuta:\n"
    printf "  ${C_CYAN}cat %s.pub${C_RESET}\n" "$ssh_key_path"
}

install_basic_utilities() {
    print_header "Instalando Utilidades Básicas y Git"

    local common_utils=(
        "tree" "unzip" "net-tools" "curl" "wget" "htop" "btop" "git"
    )

    printf "Instalando utilidades comunes...\n"
    run_command "${INSTALL_COMMAND[@]}" "${common_utils[@]}"

    printf "${C_GREEN}Git instalado. Versión actual:${C_RESET}\n"
    git --version

    log_action "install_basic_utilities: completado"
}

install_bitwarden_cli() {
    print_header "Instalando Bitwarden CLI (bw)"
    if ! check_node_npm_dependency; then return 1; fi
    printf "Instalando Bitwarden CLI vía npm...\n"
    run_command npm install -g @bitwarden/cli
    printf "${C_GREEN}✓ Bitwarden CLI (bw) instalado.${C_RESET} Ejecuta 'bw --help'.\n"
    log_action "install_bitwarden_cli: completado"
}

install_brave_browser() {
    print_header "Instalando Navegador Brave"
    if command -v brave-browser &>/dev/null; then
        if ! confirm "Brave Browser ya está instalado. ¿Deseas reinstalar? (y/N): "; then
            return 0
        fi
    fi
    printf "Instalando Brave Browser usando el script oficial...\n"
    if ! run_command curl -fsS https://dl.brave.com/install.sh -o /tmp/install-brave.sh; then
        printf "${C_RED}Error al descargar el script de Brave.${C_RESET}\n"
        return 1
    fi
    
    # El script oficial de Brave maneja sudo internamente.
    run_command sudo sh /tmp/install-brave.sh
    rm /tmp/install-brave.sh

    printf "${C_GREEN}✓ Navegador Brave instalado correctamente.${C_RESET}\n"
    log_action "install_brave_browser: completado"
}

install_copilot_cli() {
    print_header "Instalando GitHub Copilot CLI"
    if ! check_node_npm_dependency; then return 1; fi
    printf "Instalando GitHub Copilot CLI vía npm...\n"
    run_command npm install -g @githubnext/github-copilot-cli
    
    printf "${C_GREEN}✓ GitHub Copilot CLI instalado.${C_RESET}\n"
    printf "Para empezar, autentícate con: ${C_WHITE}github-copilot-cli auth${C_RESET}\n"
    printf "Alias recomendados:\n"
    printf "  ${C_CYAN}alias '??'='github-copilot-cli what-the-shell'${C_RESET}\n"
    printf "  ${C_CYAN}alias 'git?'='github-copilot-cli git-assist'${C_RESET}\n"
    log_action "install_copilot_cli: completado"
}

install_docker() {
    print_header "Instalando Docker Engine (CLI)"
    if command -v docker &>/dev/null; then
        if ! confirm "Docker ya está instalado. ¿Deseas reinstalar? (y/N): "; then
            return 0
        fi
    fi

    printf "Instalando Docker Engine usando el script oficial...\n"
    if ! run_command curl -fsSL https://get.docker.com -o /tmp/get-docker.sh; then
        printf "${C_RED}Error al descargar el script de Docker.${C_RESET}\n"
        return 1
    fi
    
    run_command sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh

    printf "Añadiendo usuario '%s' al grupo 'docker'...\n" "$USER"
    run_command sudo usermod -aG docker "$USER"

    printf "${C_GREEN}✓ Docker instalado.${C_RESET}\n"
    printf "${C_YELLOW}¡IMPORTANTE! Debes reiniciar tu sesión (o el sistema) para usar Docker sin 'sudo'.${C_RESET}\n"
    log_action "install_docker: completado"
}

install_gemini_cli() {
    print_header "Instalando Gemini CLI"
    if ! check_node_npm_dependency; then return 1; fi
    printf "Instalando Gemini CLI vía npm...\n"
    run_command npm install -g @google/gemini-cli
    printf "${C_GREEN}✓ Gemini CLI instalado.${C_RESET} Ejecuta 'gemini --help'.\n"
    log_action "install_gemini_cli: completado"
}

install_github_cli() {
    print_header "Instalando GitHub CLI (gh)"
    if command -v gh &>/dev/null; then
        if ! confirm "GitHub CLI ya está instalado. ¿Reinstalar? (y/N): "; then
            return 0
        fi
    fi
    
    printf "Instalando GitHub CLI usando el gestor de paquetes del sistema...\n"
    # El paquete se llama 'gh' en los repositorios principales de Debian/Ubuntu y Fedora.
    if ! run_command "${INSTALL_COMMAND[@]}" "gh"; then
        printf "${C_RED}Error:${C_RESET} No se pudo instalar 'gh'.\n"
        printf "Puede que necesites añadir un repositorio manualmente o que el paquete se llame 'github-cli'.\n"
        return 1
    fi

    printf "${C_GREEN}✓ GitHub CLI (gh) instalado.${C_RESET}\n"
    printf "Para empezar, ejecuta: ${C_WHITE}gh auth login${C_RESET}\n"
    log_action "install_github_cli: completado"
}

install_nvm_node_npm() {
    print_header "Instalando NVM (Node Version Manager) y Node.js"
    if [ -d "$USER_HOME/.nvm" ]; then
        printf "NVM ya está instalado. Omitiendo descarga.\n"
    else
        printf "Instalando NVM...\n"
        run_command curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi
    
    load_nvm
    
    printf "Instalando la última versión LTS de Node.js con NVM...\n"
    run_command nvm install --lts
    run_command nvm alias default 'lts/*'
    
    printf "${C_GREEN}✓ NVM, Node.js y NPM instalados.${C_RESET}\n"
    printf "Versiones actuales: Node -> ${C_WHITE}%s${C_RESET}, NPM -> ${C_WHITE}%s${C_RESET}\n" "$(node -v)" "$(npm -v)"
    printf "Reinicia tu terminal para que NVM esté disponible globalmente.\n"
    log_action "install_nvm_node_npm: completado"
}

install_nodejs_global_without_nvm() {
    print_header "Instalando Node.js Globalmente (Sin NVM)"
    if ! confirm "${C_YELLOW}Advertencia:${C_RESET} Esto puede entrar en conflicto con NVM. ¿Estás seguro? (y/N): "; then
        return 1
    fi
    
    case $PACKAGE_MANAGER in
        apt)
            printf "Configurando repositorio de NodeSource...\n"
            run_command curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            run_command sudo apt-get install -y nodejs
            ;;
        *)
            printf "Instalando Node.js usando el gestor de paquetes...\n"
            run_command "${INSTALL_COMMAND[@]}" "nodejs" "npm"
            ;;
    esac
    printf "${C_GREEN}✓ Node.js y NPM instalados globalmente.${C_RESET}\n"
    log_action "install_nodejs_global_without_nvm: completado"
}

install_oh_my_posh() {
    print_header "Instalando y Configurando Oh My Posh"
    local bashrc_path="$USER_HOME/.bashrc"

    printf "Instalando Oh My Posh...\n"
    if ! run_command curl -s https://ohmyposh.dev/install.sh -o /tmp/install-omp.sh; then
        printf "${C_RED}Error al descargar el script de Oh My Posh.${C_RESET}\n"
        return 1
    fi
    run_command bash /tmp/install-omp.sh
    rm /tmp/install-omp.sh
    
    printf "Configurando Oh My Posh en .bashrc...\n"
    local omp_block=$(cat <<EOF

# --- Configuración Oh My Posh ---
eval "\$(oh-my-posh init bash --config 'powerline')"
# --- Fin de Configuración Oh My Posh ---
EOF
)

    if grep -q "# --- Configuración Oh My Posh ---" "$bashrc_path"; then
        printf "${C_YELLOW}Configuración de Oh My Posh ya detectada en .bashrc. Omitiendo.${C_RESET}\n"
    else
        printf "Añadiendo configuración de Oh My Posh a %s...\n" "$bashrc_path"
        echo "$omp_block" >> "$bashrc_path"
        printf "${C_GREEN}✓ Configuración de Oh My Posh añadida a .bashrc.${C_RESET}\n"
    fi

    printf "Para que Oh My Posh surta efecto, ejecuta: ${C_WHITE}exec bash${C_RESET} o reinicia tu terminal.\n"
    log_action "install_oh_my_posh: completado"
}


update_system() {
    print_header "Actualizando el Sistema"
    if ! confirm "¿Proceder con la actualización completa del sistema? (y/N): "; then
        log_action "update_system: cancelado"
        return 1
    fi

    log_action "update_system: iniciado"
    case $PACKAGE_MANAGER in
        apt)
            run_command sudo apt update -y
            run_command sudo apt upgrade -y
            run_command sudo apt autoremove -y && sudo apt autoclean
            ;;
        dnf)
            run_command sudo dnf upgrade -y
            run_command sudo dnf autoremove -y
            ;;
        pacman)
            run_command sudo pacman -Syu --noconfirm
            ;;
        zypper)
            run_command sudo zypper refresh
            run_command sudo zypper update -y
            ;;
        apk)
            run_command sudo apk update
            run_command sudo apk upgrade
            ;;
    esac
    printf "${C_GREEN}✓ Sistema actualizado.${C_RESET}\n"
    log_action "update_system: completado"
}


# ==============================================================================
# --- Función de Instalación Completa ---
# ==============================================================================

run_install_step() {
    local step_name="$1"
    local is_critical="${2:-false}"
    shift 2
    
    print_header "Paso: ${step_name}"
    if "$@"; then
        log_action "${step_name}: completado"
        return 0
    else
        log_action "${step_name}: falló"
        if [ "$is_critical" = "true" ]; then
            printf "${C_RED}--- ❌ ERROR CRÍTICO: Falló el paso '%s'. Abortando. ---${C_RESET}\n" "$step_name" >&2
            return 1
        else
            printf "${C_YELLOW}--- ⚠️  ADVERTENCIA: Falló el paso '%s'. Continuando... ---${C_RESET}\n" "$step_name" >&2
            return 0
        fi
    fi
}

run_full_installation() {
    print_header "Iniciando Instalación Completa"
    if ! confirm_strict "Esto instalará y configurará múltiples herramientas. Escribe 'INSTALL' para confirmar: " "INSTALL"; then
        printf "Instalación completa cancelada.\n"
        return 1
    fi

    run_install_step "Actualizar Sistema" false update_system
    run_install_step "Instalar Utilidades Básicas" true install_basic_utilities || exit 1
    run_install_step "Configurar .gitconfig" false configure_gitconfig
    run_install_step "Generar Clave SSH" false generate_ssh_key
    run_install_step "Añadir Alias a .bashrc" false add_bash_aliases
    run_install_step "Instalar NVM y Node.js" true install_nvm_node_npm || exit 1
    run_install_step "Instalar Gemini CLI" false install_gemini_cli
    run_install_step "Instalar GitHub CLI" false install_github_cli
    run_install_step "Instalar Bitwarden CLI" false install_bitwarden_cli
    run_install_step "Instalar GitHub Copilot CLI" false install_copilot_cli
    run_install_step "Instalar Docker" false install_docker
    run_install_step "Instalar Navegador Brave" false install_brave_browser
    run_install_step "Instalar Oh My Posh" false install_oh_my_posh

    print_header "🎉 ¡Instalación Completa Finalizada! 🎉"
    printf "Revisa los mensajes anteriores para cualquier advertencia.\n"
    printf "${C_YELLOW}Es altamente recomendable que reinicies tu sesión o el sistema para que todos los cambios surtan efecto.${C_RESET}\n"
}


# ==============================================================================
# --- Menú Principal y Ejecución ---
# ==============================================================================

show_menu() {
    while true; do
        printf "\n${C_BLUE}======================================================${C_RESET}\n"
        printf "${C_WHITE}  Menú de Instalación y Configuración de Desarrollo${C_RESET}\n"
        printf "${C_BLUE}======================================================${C_RESET}\n"
        printf " ${C_CYAN}1)${C_RESET} Actualizar Sistema\n"
        printf " ${C_CYAN}2)${C_RESET} Instalar Utilidades Básicas y Git\n"
        printf " ${C_CYAN}3)${C_RESET} Configurar .gitconfig\n"
        printf " ${C_CYAN}4)${C_RESET} Generar Clave SSH\n"
        printf " ${C_CYAN}5)${C_RESET} Añadir Alias a .bashrc\n"
        printf " ${C_CYAN}6)${C_RESET} Instalar NVM y Node.js (Recomendado)\n"
        printf " ${C_CYAN}7)${C_RESET} Instalar Node.js Globalmente (Sin NVM)\n"
        printf " ${C_CYAN}8)${C_RESET} Instalar Gemini CLI\n"
        printf " ${C_CYAN}9)${C_RESET} Instalar GitHub CLI (gh)\n"
        printf "${C_CYAN}10)${C_RESET} Instalar Bitwarden CLI\n"
        printf "${C_CYAN}11)${C_RESET} Instalar Docker Engine (CLI)\n"
        printf "${C_CYAN}12)${C_RESET} Instalar GitHub Copilot CLI\n"
        printf "${C_CYAN}13)${C_RESET} Instalar Navegador Brave\n"
        printf "${C_CYAN}14)${C_RESET} Instalar Oh My Posh\n"
        printf "\n${C_YELLOW}15)${C_RESET} ${C_WHITE}INSTALAR TODO${C_RESET}\n"
        printf "${C_RED} 0)${C_RESET} Salir\n"
        printf "${C_BLUE}======================================================${C_RESET}\n"

        read -r -p "Tu elección: " choice
        
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
            11) install_docker ;;
            12) install_copilot_cli ;;
            13) install_brave_browser ;;
            14) install_oh_my_posh ;;
            15) run_full_installation ;;
            0)
                printf "Saliendo...\n"
                exit 0
                ;;
            *)
                printf "${C_RED}Opción no válida. Intenta de nuevo.${C_RESET}\n"
                ;;
        esac
        
        printf "\n${C_WHITE}Presiona cualquier tecla para volver al menú...${C_RESET}"
        read -n 1 -s
    done
}


# --- Punto de Entrada del Script ---
main() {
    clear
    detect_distro_and_package_manager
    show_menu
}

main "$@"
