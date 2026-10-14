#!/usr/bin/env bash
set -Eeuo pipefail

BOOT_DIR=/boot/firmware
[[ -d "${BOOT_DIR}" ]] || BOOT_DIR=/boot
SOURCE_DIR="${BOOT_DIR}/prepper-autoinstall"
TARGET_DIR=/opt/prepper-autoinstall

exec >>"${BOOT_DIR}/PREPPER-STAGE1.log" 2>&1
printf '\n[%s] Staging Prepper Library installer\n' "$(date --iso-8601=seconds)"

for required in \
  prepper-builder.zip prepper-config.env prepper-autoinstall.env \
  prepper-autoinstall.sh prepper-autoinstall.service; do
  [[ -f "${SOURCE_DIR}/${required}" ]] || {
    printf 'Missing payload file: %s\n' "${SOURCE_DIR}/${required}" >&2
    exit 1
  }
done

install -d -m 0700 "${TARGET_DIR}"
install -m 0600 "${SOURCE_DIR}/prepper-builder.zip" "${TARGET_DIR}/prepper-builder.zip"
install -m 0600 "${SOURCE_DIR}/prepper-config.env" "${TARGET_DIR}/prepper-config.env"
install -m 0600 "${SOURCE_DIR}/prepper-autoinstall.env" "${TARGET_DIR}/prepper-autoinstall.env"
install -m 0755 "${SOURCE_DIR}/prepper-autoinstall.sh" "${TARGET_DIR}/prepper-autoinstall.sh"
install -m 0644 "${SOURCE_DIR}/prepper-autoinstall.service" /etc/systemd/system/prepper-autoinstall.service

systemctl daemon-reload
systemctl enable prepper-autoinstall.service
systemctl start --no-block prepper-autoinstall.service

printf '[%s] Installer staged and started\n' "$(date --iso-8601=seconds)"

