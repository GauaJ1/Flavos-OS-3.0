#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly AUTO_DIR="${REPO_ROOT}/image/auto"
readonly CONFIG_DIR="${REPO_ROOT}/image/config"
readonly PACKAGE_LIST="${CONFIG_DIR}/package-lists/flavos-m0.list.chroot"

fail() {
  printf 'FALHOU: %s\n' "$*" >&2
  exit 1
}

for file_path in \
  "${AUTO_DIR}/config" \
  "${AUTO_DIR}/build" \
  "${AUTO_DIR}/clean"; do
  [[ -x "${file_path}" ]] || fail "script ausente ou não executável: ${file_path}"
done

sh -n "${AUTO_DIR}/config" "${AUTO_DIR}/clean"
bash -n "${AUTO_DIR}/build"
bash -n "${REPO_ROOT}/tools/archive-m0-build.sh"

[[ -x "${REPO_ROOT}/tools/archive-m0-build.sh" ]] || \
  fail 'script de arquivamento ausente ou não executável'

required_options=(
  '--ignore-system-defaults'
  '--distribution trixie'
  '--architecture amd64'
  '--binary-image iso-hybrid'
  '--system live'
  '--initramfs live-boot'
  '--initsystem systemd'
  '--bootloaders "syslinux grub-efi"'
  '--debian-installer none'
  '--firmware-chroot false'
  '--firmware-binary false'
  '--uefi-secure-boot disable'
  '--image-name flavos-3.0-m0'
)

for option in "${required_options[@]}"; do
  grep -Fq -- "${option}" "${AUTO_DIR}/config" || \
    fail "opção obrigatória ausente: ${option}"
done

if grep -Eq -- '--(architectures|binary-images)\b' "${AUTO_DIR}/config"; then
  fail 'a configuração usa opções plurais antigas do live-build'
fi

[[ -f "${PACKAGE_LIST}" ]] || fail "lista de pacotes ausente: ${PACKAGE_LIST}"

expected_packages="$(
  printf '%s\n' \
    linux-image-amd64 \
    live-boot \
    live-config \
    live-config-systemd \
    sudo \
    systemd-sysv \
    user-setup | LC_ALL=C sort
)"
actual_packages="$(
  sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "${PACKAGE_LIST}" | \
    LC_ALL=C sort
)"

if [[ "${actual_packages}" != "${expected_packages}" ]]; then
  printf '%s\n' 'Pacotes esperados:' >&2
  printf '%s\n' "${expected_packages}" >&2
  printf '%s\n' 'Pacotes encontrados:' >&2
  printf '%s\n' "${actual_packages}" >&2
  fail 'a lista mínima do M0 foi alterada sem atualizar sua validação'
fi

if grep -Eiq '(xorg|wayland|gnome|kde|plasma|xfce|lxqt|sddm|gdm|lightdm)' \
  "${PACKAGE_LIST}"; then
  fail 'um componente gráfico apareceu na lista mínima do M0'
fi

[[ -f "${CONFIG_DIR}/includes.chroot/etc/flavos-release" ]] || \
  fail 'identidade /etc/flavos-release ausente'
[[ -f "${CONFIG_DIR}/includes.chroot/etc/issue" ]] || \
  fail 'banner /etc/issue ausente'
[[ ! -e "${CONFIG_DIR}/includes.chroot/etc/os-release" ]] || \
  fail 'o M0 não deve sobrescrever /etc/os-release diretamente'

grep -Fq 'MILESTONE="M0"' \
  "${CONFIG_DIR}/includes.chroot/etc/flavos-release" || \
  fail 'milestone incorreto em /etc/flavos-release'

grep -Fq 'config/package-lists/live.list.chroot' \
  "${REPO_ROOT}/.gitignore" || \
  fail 'lista live gerada pelo lb config não está ignorada'
grep -Fq 'find "${hook_dir}" -maxdepth 1 -type l -delete' \
  "${AUTO_DIR}/config" || \
  fail 'auto/config não descarta links upstream antigos antes de regenerar'
grep -Fq 'FLAVOS_BUILD_COMMIT=' "${AUTO_DIR}/build" || \
  fail 'auto/build não registra o commit no log'
grep -Fq 'archive-m0-build.sh' "${AUTO_DIR}/clean" || \
  fail 'auto/clean não protege a ISO ainda não arquivada'

printf 'Configuração estática do M0 validada com sucesso.\n'
