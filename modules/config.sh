#!/bin/bash

# --- Funciones de Configuración ---

configure_gitconfig() {
    print_header "Configurando .gitconfig"
    local GITCONFIG_PATH="$USER_HOME/.gitconfig"

    if [ -f "$GITCONFIG_PATH" ]; then
        echo "Archivo $GITCONFIG_PATH existente detectado. Se borrará y reemplazará."
        run_command "rm -f \"$GITCONFIG_PATH\""
    else
        echo "Archivo $GITCONFIG_PATH no encontrado. Se creará uno nuevo."
    fi

    cat > "$GITCONFIG_PATH" <<EOF
[user]
	name = Eduardo Macias
	email = herwingmacias@gmail.com
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
}

generate_ssh_key() {
    print_header "Generando Clave SSH"
    local SSH_KEY_PATH="$USER_HOME/.ssh/id_rsa"

    if [ -f "$SSH_KEY_PATH" ]; then
        echo "Advertencia: Ya existe una clave SSH en $SSH_KEY_PATH."
        read -p "¿Deseas sobreescribirla? (y/N): " overwrite_key
        if [[ ! "$overwrite_key" =~ ^[Yy]$ ]]; then
            echo "Generación de clave SSH cancelada."
            return 0
        fi
        run_command "rm -f \"$SSH_KEY_PATH\" \"${SSH_KEY_PATH}.pub\""
    fi

    read -p "Por favor, introduce tu dirección de correo electrónico para la clave SSH: " SSH_EMAIL

    if [ -z "$SSH_EMAIL" ]; then
        echo "Error: Correo electrónico no proporcionado." >&2
        return 1
    fi

    run_command "ssh-keygen -t rsa -b 4096 -C \"$SSH_EMAIL\""
    echo "Clave SSH generada en $SSH_KEY_PATH"
}

add_bash_aliases() {
    print_header "Añadiendo Alias a .bashrc"
    local BASHRC_PATH="$USER_HOME/.bashrc"
    local aliases=(
        "alias ll='ls -alF'"
        "alias la='ls -A'"
        "alias l='ls -CF'"
        "alias size='du -h --max-depth=1 ~/'"
        "alias storage='df -h'"
        "alias up='sudo apt update && sudo apt upgrade'"
        "alias list-size='du -h --max-depth=1 | sort -hr'"
    )

    for alias_line in "${aliases[@]}"; do
        if ! grep -qF "$alias_line" "$BASHRC_PATH"; then
            echo "$alias_line" >> "$BASHRC_PATH"
        fi
    done
}

configure_firewall_ssh() {
    print_header "Configurando Firewall para SSH (Puerto 22)"

    if ! check_command sshd; then
        if [ "$PACKAGE_MANAGER" == "apt" ]; then
            run_command "$INSTALL_COMMAND openssh-server"
        else
            run_command "$INSTALL_COMMAND openssh"
        fi
    fi

    local SSH_SERVICE_NAME="sshd"
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        SSH_SERVICE_NAME="ssh"
    fi
    run_command "sudo systemctl enable --now $SSH_SERVICE_NAME"

    if check_command ufw; then
        run_command "sudo ufw allow ssh"
        run_command "sudo ufw --force enable"
    elif check_command firewalld; then
        run_command "sudo firewall-cmd --permanent --add-service=ssh"
        run_command "sudo firewall-cmd --reload"
    else
        echo "No se detectó UFW ni FirewallD."
    fi
}
