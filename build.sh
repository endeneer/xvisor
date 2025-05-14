#!/bin/sh
set -e

# Build configurations
DIR_PREFIX="$(realpath "$(dirname $(readlink -f "$0"))"/..)"
SHARED_FOLDER=/home/user/Desktop/shared
FLASH_FOLDER=flash_xvisor
FLASH_DIR="$SHARED_FOLDER/$FLASH_FOLDER"

WANT_UPLOAD=1
FPGA_USER=
FPGA_IP=""
FPGA_PASS=
FPGA_FOLDER_PATH="C:\\workspace\\xvisor"

# 1=one_guest_virt64.xscript, 2=two_guest_virt64.xscript
BOOT_XSCRIPT_TYPE=2
# 0 = no L2 guest Image, 1 = add L2 guest Image (used for nested boot)
WANT_L2_GUEST_IMAGE=1

# Environment variables
export ARCH=riscv
export CROSS_COMPILE=riscv64-unknown-linux-gnu-
export CC=${CROSS_COMPILE}gcc

BUILDROOT_DIR="$DIR_PREFIX/buildroot"
BUILDROOT_DEFCONFIG="xvisor_defconfig"
BUILDROOT_TARGET_DIR="$BUILDROOT_DIR/output/target"
BUILDROOT_IMAGES_DIR="$BUILDROOT_DIR/output/images"
BUILDROOT_ROOTFS_CPIO="$BUILDROOT_IMAGES_DIR/rootfs.cpio"
BUILDROOT_TEST_DIR="$BUILDROOT_TARGET_DIR/test"
BUILDROOT_LINUX_DIR=$DIR_PREFIX/buildroot/output/build/linux-custom

XVISOR_DIR="$DIR_PREFIX/xvisor"
XVISOR_DISK_DIR="$XVISOR_DIR/build/disk"
XVISOR_DISK_RISCV64_GUEST_DIR="$XVISOR_DISK_DIR/images/riscv/virt64"
XVISOR_DISK_IMG="$XVISOR_DIR/build/disk.img"

LINUX_DIR="$DIR_PREFIX/linux"
LINUX_DEFCONFIG="xvisor_defconfig"
LINUX_DEFCONFIG_FILE="$LINUX_DIR/arch/riscv/configs/$LINUX_DEFCONFIG"
LINUX_IMAGE="$BUILDROOT_IMAGES_DIR/Image"

OPENSBI_DIR="$DIR_PREFIX/opensbi"
OPENSBI_FW_PAYLOAD_ELF="$OPENSBI_DIR/build/platform/generic/firmware/fw_payload.elf"
OPENSBI_FW_JUMP_ELF="$OPENSBI_DIR/build/platform/generic/firmware/fw_jump.elf"
OPENSBI_FW_JUMP_BIN="$OPENSBI_DIR/build/platform/generic/firmware/fw_jump.bin"

DTC_DIR=$DIR_PREFIX/dtc
KVMTOOL_DIR=$DIR_PREFIX/kvmtool
KVMTOOL_FILE=$KVMTOOL_DIR/lkvm-static

cd "$LINUX_DIR"
# cp "$LINUX_DIR"/arch/riscv/configs/defconfig "$LINUX_DEFCONFIG_FILE"
sed -i '/CONFIG_KVM=/d' "$LINUX_DEFCONFIG_FILE"
echo "CONFIG_KVM=y" >> "$LINUX_DEFCONFIG_FILE"
"$XVISOR_DIR"/tests/common/scripts/update-linux-defconfig.sh -p "$LINUX_DEFCONFIG_FILE" -f "$XVISOR_DIR"/tests/riscv/virt64/linux/linux_extra.config

cd "$DTC_DIR"
make CC=${CC} libfdt
cd "$KVMTOOL_DIR"
# make LIBFDT_DIR=${DIR_PREFIX}/dtc/libfdt clean
make LIBFDT_DIR="${DIR_PREFIX}/dtc/libfdt" lkvm-static
${CROSS_COMPILE}strip lkvm-static
mkdir -p $BUILDROOT_TARGET_DIR/bin
cp "$KVMTOOL_DIR/lkvm-static" "$BUILDROOT_TARGET_DIR/bin/lkvm"

cd "$BUILDROOT_DIR"
sed -i "s|LINUX_OVERRIDE_SRCDIR=.*|LINUX_OVERRIDE_SRCDIR=$LINUX_DIR|g" "$BUILDROOT_DIR/local.mk"
make "$BUILDROOT_DEFCONFIG"
make linux-reconfigure
## Copy binaries needed for nested boot
if [ "$WANT_L2_GUEST_IMAGE" -eq 1 ]; then
	mkdir -p "$BUILDROOT_TARGET_DIR/test"
	cp "$LINUX_IMAGE" "$BUILDROOT_TARGET_DIR/test"
else
	rm -f "$BUILDROOT_TARGET_DIR/test/Image"
fi
make

cd "$XVISOR_DIR"
make clean
# make generic-64b-defconfig
make -j$(nproc)
make -C tests/riscv/virt64/basic
# Xvisor disk image
mkdir -p "$XVISOR_DIR"/build/disk/tmp
mkdir -p "$XVISOR_DIR"/build/disk/system
cp -f "$XVISOR_DIR"/docs/banner/roman.txt "$XVISOR_DIR"/build/disk/system/banner.txt
cp -f "$XVISOR_DIR"/docs/logo/xvisor_logo_name.ppm "$XVISOR_DIR"/build/disk/system/logo.ppm
mkdir -p "$XVISOR_DIR"/build/disk/images/riscv/virt64
## virt64-guest.dtb is for hypervisor to create emulated hardware
dtc -q -I dts -O dtb -o "$FLASH_DIR/my_xvisor.dtb" "$XVISOR_DIR"/tests/riscv/virt64/my_xvisor.dts
## virt64-guest.dtb is for hypervisor to create emulated hardware
dtc -q -I dts -O dtb -o "$XVISOR_DIR"/build/disk/images/riscv/virt64-guest.dtb "$XVISOR_DIR"/tests/riscv/virt64/virt64-guest.dts
cp -f "$XVISOR_DIR"/build/tests/riscv/virt64/basic/firmware.bin "$XVISOR_DIR"/build/disk/images/riscv/virt64/firmware.bin
cp -f "$XVISOR_DIR"/tests/riscv/virt64/linux/nor_flash.list "$XVISOR_DIR"/build/disk/images/riscv/virt64/nor_flash.list
cp -f "$XVISOR_DIR"/tests/riscv/virt64/linux/cmdlist "$XVISOR_DIR"/build/disk/images/riscv/virt64/cmdlist
if [ "$BOOT_XSCRIPT_TYPE" -eq 1 ]; then
	cp -f "$XVISOR_DIR"/tests/riscv/virt64/xscript/one_guest_virt64.xscript "$XVISOR_DIR"/build/disk/boot.xscript
elif [ "$BOOT_XSCRIPT_TYPE" -eq 2 ]; then
	cp -f "$XVISOR_DIR"/tests/riscv/virt64/xscript/two_guest_virt64.xscript "$XVISOR_DIR"/build/disk/boot.xscript
fi
cp -f "$LINUX_IMAGE" "$XVISOR_DIR"/build/disk/images/riscv/virt64/Image
## virt64.dtb is for guest linux
dtc -q -I dts -O dtb -o "$XVISOR_DIR"/build/disk/images/riscv/virt64/virt64.dtb "$XVISOR_DIR"/tests/riscv/virt64/linux/virt64.dts
cp -f "$BUILDROOT_ROOTFS_CPIO" "$XVISOR_DIR"/build/disk/images/riscv/virt64/rootfs.img
# DISK_IMG_SIZE=96
DISK_IMG_SIZE=52
echo "Generating disk.img (initrd of guest) of size $DISK_IMG_SIZE MB"
genext2fs -B 1024 -b $(( $DISK_IMG_SIZE*1024 )) -d "$XVISOR_DIR"/build/disk "$XVISOR_DISK_IMG"
## NOTE: Do not allocate just enough, because guest needs some space for creating files in the disk.img 
## Here we calculate how many MB needed for build/disk and then add another DISK_IMG_EXTRA_SIZE to it
# DISK_IMG_EXTRA_SIZE=20
# DISK_IMG_SIZE=$(( $(du -s "$XVISOR_DIR"/build/disk | cut -f1) / 1024 + $DISK_IMG_EXTRA_SIZE ))
# echo "Generating disk.img (initrd of guest) of size $DISK_IMG_SIZE MB"
# genext2fs -B 1024 -b $(( $DISK_IMG_SIZE*1024 )) -d "$XVISOR_DIR"/build/disk "$XVISOR_DIR"/build/disk.img

cd "$OPENSBI_DIR"
make distclean
make -j PLATFORM=generic FW_PAYLOAD_PATH="$XVISOR_DIR/build/vmm.bin" FW_TEXT_START=0x80000000

case $WANT_UPLOAD in
	1)
		echo "Copying"
		mkdir -p "$FLASH_DIR"
		cp "$OPENSBI_FW_PAYLOAD_ELF" "$FLASH_DIR"
		cp "$BOOTJUMP_BIN" "$FLASH_DIR/rom_pre.bin"
		cp "$XVISOR_DISK_IMG" "$FLASH_DIR"
		## my_xvisor.dtb already output in FLASH_DIR when dtc compiles it

		echo "Uploading"
		sshpass -p "$FPGA_PASS" scp "$OPENSBI_FW_PAYLOAD_ELF" "$FPGA_USER@$FPGA_IP:$FPGA_FOLDER_PATH"
		sshpass -p "$FPGA_PASS" scp "$BOOTJUMP_BIN" "$FPGA_USER@$FPGA_IP:$FPGA_FOLDER_PATH\\rom_pre.bin"
		sshpass -p "$FPGA_PASS" scp "$XVISOR_DISK_IMG" "$FPGA_USER@$FPGA_IP:$FPGA_FOLDER_PATH"
		sshpass -p "$FPGA_PASS" scp "$FLASH_DIR/my_xvisor.dtb" "$FPGA_USER@$FPGA_IP:$FPGA_FOLDER_PATH"
		;;
esac


echo "QEMU"
qemu-system-riscv64 \
	-M virt,aia=aplic-imsic -nographic \
	-smp 4 -cpu rv64,h=true \
	-m 8G \
	-bios "$OPENSBI_FW_JUMP_BIN" \
	-kernel "$XVISOR_DIR"/build/vmm.bin \
	-append 'vmm.bootcmd="vfs mount initrd /;vfs run /boot.xscript;vfs cat /system/banner.txt"' \
	-initrd "$XVISOR_DISK_IMG"

	# -M virt -nographic \
	# -M sifive_u -nographic \
	# -s -S \

# echo "SPIKE"
# spike -m512 --isa rv64gch --initrd $XVISOR_DIR/build/disk.img --bootargs 'vmm.bootcmd="vfs mount initrd /;vfs run /boot.xscript;vfs cat /system/banner.txt"' $OPENSBI_DIR/build/platform/generic/firmware/fw_payload.elf
