#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE=""
OUTPUT=""

usage() {
  cat <<'EOF'
Usage: sudo ./capture-master.sh --source /dev/sdX --output prepper-pi4.img

Reads a powered-down, unmounted master SSD, shrinks the image with PiShrink,
then creates prepper-pi4.img.zst. It never writes to the source device.
EOF
}

while (( $# )); do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

[[ ${EUID} -eq 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
[[ -n "${SOURCE}" && -n "${OUTPUT}" ]] || { usage; exit 2; }
[[ "${SOURCE}" == /dev/* && -b "${SOURCE}" ]] || { printf 'Source is not a block device: %s\n' "${SOURCE}" >&2; exit 2; }
[[ "${OUTPUT}" == *.img ]] || { printf 'Output must end in .img\n' >&2; exit 2; }
[[ ! -e "${OUTPUT}" && ! -e "${OUTPUT}.zst" ]] || { printf 'Output already exists; refusing to overwrite it.\n' >&2; exit 2; }

for command in lsblk findmnt ddrescue zstd pishrink.sh; do
  command -v "${command}" >/dev/null || {
    printf 'Missing command: %s\n' "${command}" >&2
    if [[ "${command}" == "pishrink.sh" ]]; then
      printf 'Install PiShrink from https://github.com/Drewsif/PiShrink and put pishrink.sh in PATH.\n' >&2
    else
      printf 'On Debian/Ubuntu, install gddrescue and zstd.\n' >&2
    fi
    exit 2
  }
done

if lsblk -nrpo MOUNTPOINTS "${SOURCE}" | grep -qE '/|[[:alnum:]]'; then
  printf 'A source partition appears mounted. Unmount every partition first.\n' >&2
  lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINTS "${SOURCE}"
  exit 2
fi

ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
if [[ "${ROOT_SOURCE}" == "${SOURCE}"* ]]; then
  printf 'Refusing to capture the computer running this script.\n' >&2
  exit 2
fi

printf '\nSelected source (READ ONLY):\n'
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS "${SOURCE}"
printf '\nOutput image: %s\n' "$(readlink -m "${OUTPUT}")"
printf 'A raw intermediate as large as the source disk is required.\n'
printf 'Type CAPTURE to continue: '
read -r answer
[[ "${answer}" == "CAPTURE" ]] || { printf 'Cancelled.\n'; exit 1; }

MAPFILE="${OUTPUT}.map"
ddrescue --force --no-scrape "${SOURCE}" "${OUTPUT}" "${MAPFILE}"
pishrink.sh -a "${OUTPUT}"
zstd -T0 -19 --rm "${OUTPUT}"
rm -f "${MAPFILE}"
printf 'Created %s.zst\n' "${OUTPUT}"

