#!/bin/bash

# Script de Backup de Aplicaciones para Zorin OS
# Autor: Backup automático APT y Flatpak
# Fecha: $(date +%Y-%m-%d)

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuración
BACKUP_BASE_DIR="$HOME/Downloads"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/apps_backup_$TIMESTAMP"
HOSTNAME=$(hostname)

print_status "Iniciando backup de aplicaciones en Zorin OS"
print_status "Directorio de backup: $BACKUP_DIR"

# Crear directorio de backup
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/apt"
mkdir -p "$BACKUP_DIR/flatpak"
mkdir -p "$BACKUP_DIR/sources"
mkdir -p "$BACKUP_DIR/scripts"

# ============================================================
# BACKUP DE APLICACIONES APT
# ============================================================

print_status "Creando backup de aplicaciones APT..."

# Lista de paquetes instalados manualmente
apt-mark showmanual > "$BACKUP_DIR/apt/manual-packages.txt" 2>/dev/null || {
    print_warning "No se pudo obtener la lista de paquetes manuales"
}

# Lista de todos los paquetes instalados
dpkg --get-selections > "$BACKUP_DIR/apt/all-packages.txt" 2>/dev/null || {
    print_warning "No se pudo obtener la lista completa de paquetes"
}

# Lista detallada con versiones
apt list --installed > "$BACKUP_DIR/apt/detailed-packages.txt" 2>/dev/null || {
    print_warning "No se pudo obtener la lista detallada de paquetes"
}

# Información del sistema
echo "# Información del sistema" > "$BACKUP_DIR/apt/system-info.txt"
echo "Hostname: $HOSTNAME" >> "$BACKUP_DIR/apt/system-info.txt"
echo "Fecha: $(date)" >> "$BACKUP_DIR/apt/system-info.txt"
echo "Sistema: $(lsb_release -d | cut -f2)" >> "$BACKUP_DIR/apt/system-info.txt"
echo "Kernel: $(uname -r)" >> "$BACKUP_DIR/apt/system-info.txt"
echo "" >> "$BACKUP_DIR/apt/system-info.txt"

# Backup de repositorios
print_status "Respaldando configuración de repositorios..."
sudo cp /etc/apt/sources.list "$BACKUP_DIR/sources/" 2>/dev/null || print_warning "No se pudo copiar sources.list"
sudo cp -r /etc/apt/sources.list.d/ "$BACKUP_DIR/sources/" 2>/dev/null || print_warning "No se pudo copiar sources.list.d"
sudo cp -r /etc/apt/trusted.gpg* "$BACKUP_DIR/sources/" 2>/dev/null || print_warning "No se pudo copiar claves GPG"

# Cambiar permisos para el usuario
sudo chown -R $USER:$USER "$BACKUP_DIR/sources/" 2>/dev/null || true

print_success "Backup de APT completado"

# ============================================================
# BACKUP DE APLICACIONES FLATPAK
# ============================================================

print_status "Creando backup de aplicaciones Flatpak..."

# Verificar si Flatpak está instalado
if command -v flatpak > /dev/null 2>&1; then
    # Lista de aplicaciones Flatpak de usuario
    flatpak list --user --app --columns=application 2>/dev/null > "$BACKUP_DIR/flatpak/user-apps.txt" || {
        touch "$BACKUP_DIR/flatpak/user-apps.txt"
        print_warning "No hay aplicaciones Flatpak de usuario o error al listarlas"
    }
    
    # Lista de aplicaciones Flatpak del sistema
    flatpak list --system --app --columns=application 2>/dev/null > "$BACKUP_DIR/flatpak/system-apps.txt" || {
        touch "$BACKUP_DIR/flatpak/system-apps.txt"
        print_warning "No hay aplicaciones Flatpak del sistema o error al listarlas"
    }
    
    # Lista detallada con información completa
    flatpak list --app 2>/dev/null > "$BACKUP_DIR/flatpak/detailed-apps.txt" || {
        touch "$BACKUP_DIR/flatpak/detailed-apps.txt"
        print_warning "Error al obtener lista detallada de Flatpak"
    }
    
    # Lista de remotos configurados
    flatpak remotes 2>/dev/null > "$BACKUP_DIR/flatpak/remotes.txt" || {
        touch "$BACKUP_DIR/flatpak/remotes.txt"
        print_warning "Error al obtener remotos de Flatpak"
    }
    
    # Backup de datos de aplicaciones Flatpak (solo si existe)
    if [ -d "$HOME/.var/app" ]; then
        print_status "Respaldando datos de aplicaciones Flatpak... (esto puede tardar un poco)"
        cp -r "$HOME/.var/app" "$BACKUP_DIR/flatpak/app-data" 2>/dev/null || {
            print_warning "No se pudieron respaldar todos los datos de aplicaciones Flatpak"
        }
    else
        print_warning "No se encontraron datos de aplicaciones Flatpak"
        touch "$BACKUP_DIR/flatpak/no-app-data.txt"
    fi
    
    print_success "Backup de Flatpak completado"
else
    print_warning "Flatpak no está instalado en el sistema"
    echo "Flatpak no instalado" > "$BACKUP_DIR/flatpak/not-installed.txt"
fi

# ============================================================
# CREAR SCRIPTS DE RESTAURACIÓN
# ============================================================

print_status "Creando scripts de restauración..."

# Script de restauración para APT
cat > "$BACKUP_DIR/scripts/restore_apt.sh" << 'EOF'
#!/bin/bash

# Script de restauración APT
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

BACKUP_DIR="$(dirname "$(dirname "$(realpath "$0")")")"

print_status "Iniciando restauración de aplicaciones APT..."
print_warning "ADVERTENCIA: Este script modificará tu sistema."
read -p "¿Continuar? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    print_error "Restauración cancelada"
    exit 1
fi

# Restaurar repositorios
print_status "Restaurando repositorios..."
if [ -f "$BACKUP_DIR/sources/sources.list" ]; then
    sudo cp "$BACKUP_DIR/sources/sources.list" /etc/apt/
    print_success "sources.list restaurado"
fi

if [ -d "$BACKUP_DIR/sources/sources.list.d" ]; then
    sudo cp -r "$BACKUP_DIR/sources/sources.list.d/"* /etc/apt/sources.list.d/ 2>/dev/null || true
    print_success "sources.list.d restaurado"
fi

# Actualizar cache
print_status "Actualizando cache de paquetes..."
sudo apt update

# Instalar paquetes
if [ -f "$BACKUP_DIR/apt/manual-packages.txt" ]; then
    print_status "Instalando paquetes..."
    while read -r package; do
        if [ -n "$package" ]; then
            print_status "Instalando: $package"
            sudo apt install -y "$package" || print_warning "No se pudo instalar: $package"
        fi
    done < "$BACKUP_DIR/apt/manual-packages.txt"
    print_success "Instalación de paquetes APT completada"
else
    print_error "No se encontró la lista de paquetes manuales"
fi
EOF

# Script de restauración para Flatpak
cat > "$BACKUP_DIR/scripts/restore_flatpak.sh" << 'EOF'
#!/bin/bash

# Script de restauración Flatpak
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

BACKUP_DIR="$(dirname "$(dirname "$(realpath "$0")")")"

print_status "Iniciando restauración de aplicaciones Flatpak..."

# Verificar si Flatpak está instalado
if ! command -v flatpak > /dev/null 2>&1; then
    print_error "Flatpak no está instalado. Instálalo primero con: sudo apt install flatpak"
    exit 1
fi

# Asegurar que Flathub esté añadido
print_status "Verificando repositorio Flathub..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Restaurar aplicaciones de usuario
if [ -f "$BACKUP_DIR/flatpak/user-apps.txt" ] && [ -s "$BACKUP_DIR/flatpak/user-apps.txt" ]; then
    print_status "Restaurando aplicaciones Flatpak de usuario..."
    while read -r app; do
        if [ -n "$app" ] && [[ ! "$app" =~ ^# ]]; then
            print_status "Instalando aplicación de usuario: $app"
            flatpak install --user flathub "$app" -y || print_warning "No se pudo instalar: $app"
        fi
    done < "$BACKUP_DIR/flatpak/user-apps.txt"
    print_success "Aplicaciones de usuario restauradas"
else
    print_warning "No se encontraron aplicaciones Flatpak de usuario para restaurar"
fi

# Restaurar aplicaciones del sistema
if [ -f "$BACKUP_DIR/flatpak/system-apps.txt" ] && [ -s "$BACKUP_DIR/flatpak/system-apps.txt" ]; then
    print_status "Restaurando aplicaciones Flatpak del sistema..."
    while read -r app; do
        if [ -n "$app" ] && [[ ! "$app" =~ ^# ]]; then
            print_status "Instalando aplicación del sistema: $app"
            sudo flatpak install flathub "$app" -y || print_warning "No se pudo instalar: $app"
        fi
    done < "$BACKUP_DIR/flatpak/system-apps.txt"
    print_success "Aplicaciones del sistema restauradas"
else
    print_warning "No se encontraron aplicaciones Flatpak del sistema para restaurar"
fi

# Restaurar datos de aplicaciones
if [ -d "$BACKUP_DIR/flatpak/app-data" ]; then
    print_status "¿Deseas restaurar los datos de las aplicaciones? (configuraciones, archivos guardados, etc.)"
    read -p "Esto sobrescribirá datos actuales (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        print_status "Restaurando datos de aplicaciones..."
        mkdir -p "$HOME/.var"
        cp -r "$BACKUP_DIR/flatpak/app-data" "$HOME/.var/app" || print_warning "Error parcial al restaurar datos"
        print_success "Datos de aplicaciones restaurados"
    fi
else
    print_warning "No se encontraron datos de aplicaciones para restaurar"
fi

print_success "Restauración de Flatpak completada"
EOF

# Hacer ejecutables los scripts de restauración
chmod +x "$BACKUP_DIR/scripts/restore_apt.sh"
chmod +x "$BACKUP_DIR/scripts/restore_flatpak.sh"

# ============================================================
# CREAR ARCHIVO DE INFORMACIÓN
# ============================================================

cat > "$BACKUP_DIR/README.txt" << EOF
=================================================================
BACKUP DE APLICACIONES - ZORIN OS
=================================================================

Fecha de creación: $(date)
Sistema: $(lsb_release -d | cut -f2)
Usuario: $USER
Hostname: $HOSTNAME

CONTENIDO DEL BACKUP:
--------------------

📁 apt/
   - manual-packages.txt     : Paquetes instalados manualmente
   - all-packages.txt        : Todos los paquetes instalados
   - detailed-packages.txt   : Lista detallada con versiones
   - system-info.txt         : Información del sistema

📁 flatpak/
   - user-apps.txt          : Aplicaciones Flatpak de usuario
   - system-apps.txt        : Aplicaciones Flatpak del sistema
   - detailed-apps.txt      : Lista detallada de aplicaciones
   - remotes.txt           : Repositorios remotos configurados
   - app-data/             : Datos y configuraciones de aplicaciones

📁 sources/
   - sources.list          : Repositorios APT principales
   - sources.list.d/       : Repositorios APT adicionales
   - trusted.gpg*          : Claves GPG de repositorios

📁 scripts/
   - restore_apt.sh        : Script para restaurar aplicaciones APT
   - restore_flatpak.sh    : Script para restaurar aplicaciones Flatpak

CÓMO RESTAURAR:
--------------

Para restaurar APT:
   ./scripts/restore_apt.sh

Para restaurar Flatpak:
   ./scripts/restore_flatpak.sh

Para restaurar todo:
   ./scripts/restore_apt.sh && ./scripts/restore_flatpak.sh

NOTAS IMPORTANTES:
-----------------
- Los scripts de restauración requieren permisos de administrador
- Se recomienda hacer esto en un sistema limpio o recién instalado
- Los datos de aplicaciones Flatpak se restaurarán preguntando primero
- Siempre haz un backup del sistema antes de restaurar

¡Guarda este backup en un lugar seguro!
EOF

# ============================================================
# CREAR ARCHIVO COMPRIMIDO
# ============================================================

print_status "Creando archivo comprimido..."
cd "$BACKUP_BASE_DIR"
tar -czf "apps_backup_$TIMESTAMP.tar.gz" "apps_backup_$TIMESTAMP" || {
    print_warning "No se pudo crear el archivo comprimido"
}

# ============================================================
# RESUMEN FINAL
# ============================================================

print_success "¡Backup completado!"
echo
echo "============================================="
echo "RESUMEN DEL BACKUP"
echo "============================================="
echo "📁 Directorio: $BACKUP_DIR"
echo "📦 Archivo comprimido: $BACKUP_BASE_DIR/apps_backup_$TIMESTAMP.tar.gz"
echo
echo "APT:"
if [ -f "$BACKUP_DIR/apt/manual-packages.txt" ]; then
    APT_COUNT=$(wc -l < "$BACKUP_DIR/apt/manual-packages.txt")
    echo "   ✓ $APT_COUNT paquetes manuales respaldados"
else
    echo "   ⚠ No se pudieron respaldar paquetes APT"
fi

echo
echo "FLATPAK:"
if command -v flatpak > /dev/null 2>&1; then
    if [ -f "$BACKUP_DIR/flatpak/user-apps.txt" ]; then
        USER_COUNT=$(wc -l < "$BACKUP_DIR/flatpak/user-apps.txt")
        echo "   ✓ $USER_COUNT aplicaciones de usuario respaldadas"
    fi
    if [ -f "$BACKUP_DIR/flatpak/system-apps.txt" ]; then
        SYSTEM_COUNT=$(wc -l < "$BACKUP_DIR/flatpak/system-apps.txt")
        echo "   ✓ $SYSTEM_COUNT aplicaciones del sistema respaldadas"
    fi
    if [ -d "$BACKUP_DIR/flatpak/app-data" ]; then
        echo "   ✓ Datos de aplicaciones respaldados"
    fi
else
    echo "   ⚠ Flatpak no está instalado"
fi

echo
echo "Para restaurar en otro sistema:"
echo "1. Copia el archivo apps_backup_$TIMESTAMP.tar.gz"
echo "2. Extrae: tar -xzf apps_backup_$TIMESTAMP.tar.gz"
echo "3. Ejecuta: cd apps_backup_$TIMESTAMP"
echo "4. Ejecuta: ./scripts/restore_apt.sh"
echo "5. Ejecuta: ./scripts/restore_flatpak.sh"
echo
print_success "¡Tus aplicaciones están respaldadas de forma segura!"