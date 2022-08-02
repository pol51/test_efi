#!/bin/bash

BUILD_PATH=build
RUN_PATH=build/qemu

OVMF_CODE_IMG=/usr/share/edk2-ovmf/OVMF_CODE.fd
OVMF_VARS_IMG=/usr/share/edk2-ovmf/OVMF_VARS.fd
BINARY_PATH=${BUILD_PATH}/bin/cppefi.efi
DISK_PATH=${RUN_PATH}/uefi.img
EFI_VARS=${RUN_PATH}/OVMF_VARS.fd


# clean previous
rm -rf ${BUILD_PATH}

# build
mkdir -p ${BUILD_PATH}
cd ${BUILD_PATH}
cmake ..
make
cd ..

# make image
mkdir -p ${RUN_PATH}

## prepare files for efi partition (application binary + startup script)
dd if=/dev/zero of=/tmp/part.img bs=512 count=91669
mformat -i /tmp/part.img -h 32 -t 32 -n 64 -c 1

mcopy -i /tmp/part.img ${BINARY_PATH} ::app.efi
echo app.efi > startup.nsh
mcopy -i /tmp/part.img startup.nsh ::/

## make full image (with format and efi partition)
dd if=/dev/zero of=${DISK_PATH} bs=512 count=93750
parted ${DISK_PATH} -s -a minimal mklabel gpt
parted ${DISK_PATH} -s -a minimal mkpart EFI FAT16 2048s 93716s
parted ${DISK_PATH} -s -a minimal toggle 1 boot
## copy files into the image
dd if=/tmp/part.img of=${DISK_PATH} bs=512 count=91669 seek=2048 conv=notrunc

# copy efi vars
cp ${OVMF_VARS_IMG} ${EFI_VARS}

# run
qemu-system-x86_64 \
  -cpu qemu64 \
  -enable-kvm \
  -net none \
  -global driver=cfi.pflash01,property=secure,value=on \
  -drive if=pflash,format=raw,unit=0,file=${OVMF_CODE_IMG},readonly=on \
  -drive if=pflash,format=raw,unit=1,file=${EFI_VARS} \
  -drive if=ide,format=raw,file=${DISK_PATH}
