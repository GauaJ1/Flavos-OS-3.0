#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly ISO_PATH="${1:-${REPO_ROOT}/image/flavos-3.0-m0-amd64.hybrid.iso}"
readonly MANIFEST_PATH="${FLAVOS_M0_MANIFEST:-${ISO_PATH%.hybrid.iso}.packages}"

fail() {
  printf 'FALHOU: %s\n' "$*" >&2
  exit 1
}

for command_name in xorriso sha512sum mktemp cmp grep stat awk; do
  command -v "${command_name}" >/dev/null 2>&1 || \
    fail "${command_name} não está instalado"
done

[[ -f "${ISO_PATH}" ]] || fail "ISO não encontrada: ${ISO_PATH}"
[[ -f "${MANIFEST_PATH}" ]] || \
  fail "manifesto de pacotes não encontrado: ${MANIFEST_PATH}"

readonly TEMP_DIR="$(mktemp -d)"
readonly INTERNAL_MANIFEST="${TEMP_DIR}/filesystem.packages"
trap 'rm -rf -- "${TEMP_DIR}"' EXIT

xorriso -osirrox on -indev "${ISO_PATH}" \
  -extract /live/filesystem.packages "${INTERNAL_MANIFEST}" \
  >/dev/null 2>&1 || fail 'manifesto interno ausente na ISO'

cmp -s -- "${INTERNAL_MANIFEST}" "${MANIFEST_PATH}" || \
  fail 'o manifesto externo não corresponde ao manifesto interno da ISO'

el_torito_report="$(xorriso -indev "${ISO_PATH}" -report_el_torito plain 2>&1)" || \
  fail 'xorriso não conseguiu ler o catálogo El Torito'
system_area_report="$(xorriso -indev "${ISO_PATH}" -report_system_area plain 2>&1)" || \
  fail 'xorriso não conseguiu ler a área de sistema híbrida'
iso_files="$(xorriso -indev "${ISO_PATH}" -find / -type f -exec lsdl 2>&1)" || \
  fail 'xorriso não conseguiu listar os arquivos da ISO'

grep -Eq 'El Torito boot img :.*BIOS[[:space:]]+y' <<<"${el_torito_report}" || \
  fail 'entrada de boot BIOS ausente'
grep -Eq 'El Torito boot img :.*UEFI[[:space:]]+y' <<<"${el_torito_report}" || \
  fail 'entrada de boot UEFI ausente'
grep -Fq "Volume id    : 'FLAVOS_3_0_M0'" <<<"${el_torito_report}" || \
  fail 'volume id inesperado'
grep -Fq 'System area summary: MBR isohybrid' <<<"${system_area_report}" || \
  fail 'área de sistema não é MBR isohybrid'

for required_path in \
  /isolinux/isolinux.bin \
  /boot/grub/efi.img \
  /live/filesystem.squashfs \
  /live/initrd.img \
  /live/vmlinuz; do
  grep -Fq "'${required_path}'" <<<"${iso_files}" || \
    fail "arquivo obrigatório ausente na ISO: ${required_path}"
done

for package_name in \
  linux-image-amd64 \
  live-boot \
  live-config \
  live-config-systemd \
  sudo \
  systemd-sysv \
  user-setup; do
  grep -Eq "^${package_name}[[:space:]]" "${INTERNAL_MANIFEST}" || \
    fail "pacote obrigatório ausente no manifesto: ${package_name}"
done

if grep -Eiq \
  '^(xserver|xorg|wayland|libwayland|gnome|gdm|kde|plasma|sddm|lightdm|xfce|lxqt|weston|sway|cage|labwc|kwin)' \
  "${INTERNAL_MANIFEST}"; then
  fail 'o manifesto contém um componente gráfico fora do escopo do M0'
fi

iso_sha512="$(sha512sum -- "${ISO_PATH}" | awk '{print $1}')"
iso_size="$(stat -c %s -- "${ISO_PATH}")"

printf 'Estrutura da ISO M0 validada com sucesso.\n'
printf 'ISO: %s\n' "${ISO_PATH}"
printf 'Tamanho: %s bytes\n' "${iso_size}"
printf 'SHA-512: %s\n' "${iso_sha512}"
printf 'Boot: BIOS + UEFI, ISO híbrida, kernel/initrd/squashfs presentes.\n'
