#!/bin/bash

# --- Funciones de Ayuda ---

print_header() {
    echo -e "\n=============================================="
    echo -e "  $1"
    echo -e "==============================================\n"
}

run_command() {
    if [[ $1 == sudo*install* ]]; then
        local pkg=$(echo "$1" | awk '{print $NF}')
        if dpkg -s "$pkg" &> /dev/null; then
            echo "$pkg ya está instalado."
            return 0
        fi
    fi

    echo "Ejecutando: $1"
    if ! eval "$1"; then
        echo "Error: El comando '$1' falló." >&2
        return 1
    fi
}

check_command() {
    command -v "$1" &> /dev/null
}
