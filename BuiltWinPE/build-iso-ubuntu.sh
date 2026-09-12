#!/bin/bash
# Script para modernizar y crear una ISO de WinPE desde Ubuntu Linux
# Requiere: wimtools, xorriso, 7zip
# Uso: sudo ./build-iso-ubuntu.sh /ruta/a/Windows.iso

ISO_ORIGINAL=$1
WORK_DIR="BuiltWinPE/LinuxWorkSpace"
MOUNT_DIR="$WORK_DIR/mount"
SCRIPTS_DIR="Scripts"

if [ -z "$ISO_ORIGINAL" ]; then
    echo "ERROR: Debes proporcionar la ruta a una ISO de Windows 10/11."
    echo "Uso: sudo $0 /ruta/a/Windows.iso"
    exit 1
fi

echo "=== Verificando dependencias ==="
for cmd in wimlib-imagex xorriso 7z; do
    if ! command -v $cmd &> /dev/null; then
        echo "Falta instalar: $cmd. Instalando..."
        apt-get update && apt-get install -y wimtools xorriso p7zip-full
    fi
done

echo "=== Preparando directorios ==="
rm -rf $WORK_DIR
mkdir -p $MOUNT_DIR $WORK_DIR/extracted $WORK_DIR/iso_content

echo "=== Extrayendo contenido de la ISO original ==="
7z x $ISO_ORIGINAL -o$WORK_DIR/iso_content > /dev/null

# Verificar si existe boot.wim
BOOT_WIM="$WORK_DIR/iso_content/sources/boot.wim"
if [ ! -f "$BOOT_WIM" ]; then
    echo "ERROR: No se encontró sources/boot.wim en la ISO. Asegúrate de que sea una ISO de Windows válida."
    exit 1
fi

echo "=== Montando boot.wim (índice 2 - WinPE) ==="
wimlib-imagex mountrw $BOOT_WIM 2 $MOUNT_DIR

echo "=== Inyectando scripts de BitLockerUtility ==="
cp $SCRIPTS_DIR/BitLockerUtility.ps1 $MOUNT_DIR/Windows/System32/
cp $SCRIPTS_DIR/startnet.cmd $MOUNT_DIR/Windows/System32/startnet.cmd

echo "=== Desmontando y guardando cambios en boot.wim ==="
wimlib-imagex unmount $MOUNT_DIR --commit

echo "=== Generando nueva ISO WinPE ==="
xorriso -as mkisofs \
    -iso-level 4 -l -R -J -D \
    -b "boot/etfsboot.com" \
    -no-emul-boot -boot-load-size 8 -hide boot.catalog \
    -eltorito-platform x86 \
    -o "BuiltWinPE/WinPE-ISO/BitLockerUtility_Linux.iso" \
    "$WORK_DIR/iso_content"

echo "=== Limpiando temporales ==="
rm -rf $WORK_DIR

echo "¡ISO creada exitosamente en BuiltWinPE/WinPE-ISO/BitLockerUtility_Linux.iso!"
