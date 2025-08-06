# Kit de Herramientas para Migración de Entorno Linux
*Scripts de Backup y Restauración para "Distro-Hoppers"*

Este kit contiene dos scripts de Bash (`backup.sh` y `restore.sh`) diseñados para simplificar drásticamente el proceso de migrar tu entorno de desarrollo personalizado entre diferentes distribuciones de Linux, especialmente aquellas que utilizan el escritorio GNOME.

El objetivo es automatizar la tediosa tarea de reinstalar aplicaciones y reconfigurar tu sistema cada vez que cambias de distro, permitiéndote tener un entorno familiar y productivo en cuestión de minutos.

---

## Características Principales

*   **Backup Inteligente (`backup.sh`):**
    *   Crea un respaldo limpio y organizado en un único directorio.
    *   Guarda tus configuraciones de usuario más importantes (dotfiles de `.config`, `.ssh`, `.gitconfig`, etc.).
    *   Exporta toda tu configuración del escritorio GNOME (atajos, temas, apariencia) usando `dconf`.
    *   Genera listas de tus aplicaciones instaladas, distinguiendo entre paquetes del sistema (`apt`, `dnf`, `pacman`) y Flatpaks.
    *   Guarda una lista de tus extensiones de GNOME como referencia.

*   **Restauración Robusta (`restore.sh`):**
    *   Detecta automáticamente la nueva distribución y su gestor de paquetes.
    *   Instala un conjunto curado de **utilidades de terminal esenciales** para empezar a trabajar de inmediato.
    *   Restaura tus configuraciones de usuario y del escritorio GNOME de forma selectiva.
    *   **Traducción Cross-Distro:** Intenta mapear y traducir los nombres de los paquetes si migras entre familias de distribuciones (ej. de Fedora a Ubuntu).
    *   Reinstala automáticamente todas tus aplicaciones Flatpak.
    *   Te informa de los paquetes que no pudo instalar para que los revises manualmente.

---

## Cómo Utilizar el Kit

El proceso se divide en dos fases sencillas:

### Fase 1: Creando el Backup (En tu sistema ANTIGUO)

1.  **Coloca el script:** Guarda el archivo `backup.sh` en cualquier lugar de tu sistema actual (ej. en tu carpeta `~/Documentos`).
2.  **Dale permisos:** Abre una terminal en esa ubicación y ejecuta:
    ```bash
    chmod +x backup.sh
    ```
3.  **Ejecuta el script:**
    ```bash
    ./backup.sh
    ```
4.  **¡Copia el resultado!** El script creará una carpeta llamada `gnome_backup_YYYY-MM-DD` dentro de tu directorio de Documentos. **Copia esta carpeta completa a un disco duro externo o a un servicio en la nube.** Este es tu respaldo vital.

### Fase 2: Restaurando el Entorno (En tu sistema NUEVO)

1.  **Instala tu nueva distro:** Realiza una instalación limpia de tu nueva distribución de Linux.
2.  **Coloca el script:** Copia el archivo `restore.sh` a tu nuevo sistema.
3.  **Dale permisos:**
    ```bash
    chmod +x restore.sh
    ```
4.  **Ejecuta el script:**
    ```bash
    ./restore.sh
    ```
5.  **Sigue las instrucciones:** El script te guiará de forma interactiva. Primero, te pedirá la ruta a la carpeta de backup que guardaste en el paso anterior.
    *   *Ejemplo de ruta:* `/media/tu_usuario/MiUSB/gnome_backup_2025-08-07`
6.  **Reinicia:** Una vez que el script termine, es **altamente recomendable reiniciar tu sistema** para que todos los cambios (especialmente los de GNOME y los grupos de usuario) surtan efecto correctamente.

---

## Personalización

Este kit está diseñado para ser personalizable:

*   **Añadir más paquetes a la traducción:** Si descubres que un paquete tiene un nombre diferente, puedes añadirlo fácilmente al "diccionario". Abre `restore.sh` y busca la sección `declare -A PKG_MAP`. Añade tu propia línea, por ejemplo:
    ```bash
    # dentro de PKG_MAP
    ["nombre_viejo_en_dnf"]="nombre_nuevo_en_apt"
    ```
*   **Añadir más utilidades esenciales:** En `restore.sh`, puedes añadir tus herramientas favoritas a la lista `essential_pkgs` dentro de la función `install_essential_utilities`.
*   **Respaldar más archivos de configuración:** En `backup.sh`, puedes añadir más rutas a la sección `--include` del comando `rsync` para respaldar otros archivos o carpetas de configuración que consideres importantes.

---

## Notas Importantes y Descargo de Responsabilidad

*   **Usa bajo tu propio riesgo.** Estos scripts realizan cambios en el sistema y ejecutan comandos con `sudo`. Revisa siempre el código antes de ejecutarlo.
*   **Esto NO es un backup de datos.** Este kit está diseñado para respaldar **configuraciones y listas de aplicaciones**, no tus archivos personales (`~/Documentos`, `~/Imágenes`, etc.). Siempre ten un backup completo y separado de tus datos importantes.
*   La traducción de paquetes no es perfecta y depende del diccionario manual. Siempre habrá paquetes que requieran una búsqueda e instalación manual.