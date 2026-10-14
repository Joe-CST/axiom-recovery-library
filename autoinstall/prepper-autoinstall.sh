#!/usr/bin/env bash
set -Eeuo pipefail

BOOT_DIR=/boot/firmware
[[ -d "${BOOT_DIR}" ]] || BOOT_DIR=/boot
STATE_DIR=/var/lib/prepper-autoinstall
PAYLOAD_DIR=/opt/prepper-autoinstall
BUILDER_DIR=/opt/prepper-image-builder
LOG_DIR=/var/log/prepper-library
LOG_FILE="${LOG_DIR}/autoinstall.log"

install -d -m 0755 "${STATE_DIR}" "${BUILDER_DIR}" "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}" "${BOOT_DIR}/PREPPER-INSTALL.log") 2>&1

failed() {
  local code=$?
  trap - ERR
  printf '\n[%s] Automatic installation failed with exit code %s.\n' "$(date --iso-8601=seconds)" "${code}"
  printf 'Leave Ethernet connected and reboot; completed downloads will be reused.\n'
  cat >"${BOOT_DIR}/PREPPER_FAILED.txt" <<EOF
Prepper Library automatic installation failed.
Time: $(date --iso-8601=seconds)
Exit code: ${code}

Leave Ethernet connected and reboot the Raspberry Pi. The installer is
resumable and will retry automatically. Details are in PREPPER-INSTALL.log.
EOF
  sync
  exit "${code}"
}
trap failed ERR

source "${PAYLOAD_DIR}/prepper-autoinstall.env"
source "${PAYLOAD_DIR}/prepper-config.env"
rm -f "${BOOT_DIR}/PREPPER_FAILED.txt" "${BOOT_DIR}/PREPPER_READY.txt"

printf '\n[%s] Prepper Library automatic installation starting\n' "$(date --iso-8601=seconds)"
printf 'The selected knowledge and map downloads can take many hours. Do not remove power.\n'

network_ready=false
for _attempt in $(seq 1 180); do
  if getent ahostsv4 deb.debian.org >/dev/null 2>&1 && \
     getent ahostsv4 download.kiwix.org >/dev/null 2>&1 && \
     getent ahostsv4 build.protomaps.com >/dev/null 2>&1; then
    network_ready=true
    break
  fi
  sleep 10
done
[[ "${network_ready}" == true ]] || {
  printf 'Ethernet internet was not available after 30 minutes.\n' >&2
  exit 20
}

python3 - "${PAYLOAD_DIR}/prepper-builder.zip" "${BUILDER_DIR}" <<'PY'
from pathlib import Path
from zipfile import ZipFile
import sys

archive = Path(sys.argv[1])
destination = Path(sys.argv[2])
with ZipFile(archive) as bundle:
    names = bundle.namelist()
    top = {name.split('/', 1)[0] for name in names if name and not name.startswith('/')}
    if len(top) != 1:
        raise SystemExit('Builder ZIP must contain one top-level directory')
    bundle.extractall(destination.parent)
    extracted = destination.parent / next(iter(top))
    if extracted != destination:
        for item in extracted.iterdir():
            target = destination / item.name
            if target.exists():
                continue
            item.rename(target)
PY

install -m 0600 "${PAYLOAD_DIR}/prepper-config.env" "${BUILDER_DIR}/config.env"
bash "${BUILDER_DIR}/install.sh"

/usr/local/sbin/prepper-download-all "${CONTENT_PROFILE}"
/usr/local/sbin/prepper-firstboot
/usr/local/sbin/prepper-healthcheck

touch "${STATE_DIR}/complete"
systemctl disable prepper-autoinstall.service

ACTUAL_SSID="$(cat /var/lib/prepper-library/ssid 2>/dev/null || printf '%s' "${HOTSPOT_SSID}")"
cat >"${BOOT_DIR}/PREPPER_READY.txt" <<EOF
PREPPER LIBRARY IS READY
Completed: $(date --iso-8601=seconds)
Wi-Fi name: ${ACTUAL_SSID}
Portal: http://10.10.10.1
Offline map: http://10.10.10.1/maps/

The Wi-Fi and local administrator passwords are in the credentials text file
that was supplied with this image.
EOF
rm -f "${BOOT_DIR}/PREPPER_FAILED.txt"
sync
trap - ERR

printf '\n[%s] Installation complete. Rebooting into offline-library mode.\n' "$(date --iso-8601=seconds)"
systemctl reboot --no-block
exit 0
