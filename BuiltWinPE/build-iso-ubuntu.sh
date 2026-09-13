#!/bin/bash
ISO_ORIGINAL=$1
WORK_DIR="BuiltWinPE/LinuxWorkSpace"

if [ -z "$ISO_ORIGINAL" ]; then
    echo "ERROR: Debes proporcionar la ruta a una ISO de Windows 10/11."
    echo "Uso: sudo $0 /ruta/a/Windows.iso"
    exit 1
fi

echo "=== Verificando dependencias ==="
for cmd in wimlib-imagex xorriso 7z; do
    if ! command -v $cmd &> /dev/null; then
        apt-get update && apt-get install -y wimtools xorriso p7zip-full
    fi
done

echo "=== Preparando directorios ==="
rm -rf $WORK_DIR
mkdir -p $WORK_DIR/mount $WORK_DIR/iso_content

echo "=== Extrayendo contenido de la ISO original ==="
7z x $ISO_ORIGINAL -o$WORK_DIR/iso_content > /dev/null

BOOT_WIM="$WORK_DIR/iso_content/sources/boot.wim"
if [ ! -f "$BOOT_WIM" ]; then
    echo "ERROR: No se encontró sources/boot.wim en la ISO."
    exit 1
fi

echo "=== Montando boot.wim (índice 2 - WinPE) ==="
wimlib-imagex mountrw $BOOT_WIM 2 $WORK_DIR/mount

echo "=== Inyectando scripts de BitLockerUtility ==="
cp Scripts/BitLockerUtility.ps1 $WORK_DIR/mount/Windows/System32/
cp Scripts/startnet.cmd $WORK_DIR/mount/Windows/System32/startnet.cmd

echo "=== Desmontando y guardando cambios en boot.wim ==="
wimlib-imagex unmount $WORK_DIR/mount --commit

# Limpiamos la basura que deja wimlib a la fuerza
rm -rf "$WORK_DIR/iso_content/sources/boot.wim.staging"* 2>/dev/null

echo "=== Generando nueva ISO WinPE (BIOS + UEFI) ==="
# Se agregó el parámetro -m para excluir los archivos staging
xorriso -as mkisofs \
    -iso-level 4 -l -R -J -D \
    -m "*.staging*" \
    -b "boot/etfsboot.com" \
    -no-emul-boot -boot-load-size 8 -hide boot.catalog \
    -eltorito-alt-boot \
    -eltorito-platform efi \
    -eltorito-boot "efi/boot/bootx64.efi" \
    -no-emul-boot \
    -o "BuiltWinPE/WinPE-ISO/BitLockerUtility_Linux.iso" \
    "$WORK_DIR/iso_content"

if [ $? -eq 0 ]; then
    rm -rf $WORK_DIR
    echo "¡ISO creada exitosamente en BuiltWinPE/WinPE-ISO/BitLockerUtility_Linux.iso!"
else
    echo "Hubo un error al generar la ISO."
fi
