#!/bin/bash

MODULE_NAME=$(cat MODULE_NAME)
VERSION=$(cat VERSION)
OVERLAY_DIR=$( [ -d /boot/overlays ] && echo /boot/overlays || echo /boot/firmware/overlays )

dts_files=( "$MODULE_NAME"*.dts )
echo "${dts_files[0]%.dts}" > DTS_NAME

dkms add .
for k in $(find /lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' |
    grep 'rpt-rpi-' |
    sed 's/.*rpt-rpi-//' |
    sort -u |
    while read -r flavor; do
        find /lib/modules -mindepth 1 -maxdepth 1 -type d \
            -name "*rpt-rpi-$flavor" -printf '%f\n' |
            sort -V | tail -1
    done
); do
    dkms build --force -m "$MODULE_NAME" -v "$VERSION" -k "$k"
    dkms install --force -m "$MODULE_NAME" -v "$VERSION" -k "$k"
done

rm DTS_NAME

if [ ${#dts_files[@]} -gt 1 ]; then
    rm -f "$OVERLAY_DIR/$MODULE_NAME.dtbo"
    for dts in "${dts_files[@]}"; do
        DTS_NAME="${dts%.dts}"
        make dtbo DTS_NAME="$DTS_NAME" MODULE_NAME="$DTS_NAME"
        install -D -m 644 -c "$DTS_NAME.dtbo" "$OVERLAY_DIR/$DTS_NAME.dtbo"
    done
fi
