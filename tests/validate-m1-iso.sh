#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly ISO_PATH="${1:-${REPO_ROOT}/image/flavos-3.0-m1.1-amd64.hybrid.iso}"
readonly MANIFEST_PATH="${FLAVOS_M1_MANIFEST:-${ISO_PATH%.hybrid.iso}.packages}"

fail() {
  printf 'FALHOU: %s\n' "$*" >&2
  exit 1
}

for command_name in \
  awk cmp grep mktemp rm sha512sum stat unsquashfs xorriso; do
  command -v "${command_name}" >/dev/null 2>&1 || \
    fail "${command_name} não está instalado"
done

[[ -f "${ISO_PATH}" ]] || fail "ISO não encontrada: ${ISO_PATH}"
[[ -f "${MANIFEST_PATH}" ]] || \
  fail "manifesto de pacotes não encontrado: ${MANIFEST_PATH}"

readonly TEMP_DIR="$(mktemp -d)"
readonly INTERNAL_MANIFEST="${TEMP_DIR}/filesystem.packages"
readonly SQUASHFS_IMAGE="${TEMP_DIR}/filesystem.squashfs"
readonly SQUASHFS_LISTING="${TEMP_DIR}/filesystem.squashfs.list"
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

grep -Eq 'El Torito boot img :.*BIOS[[:space:]]+y' \
  <<<"${el_torito_report}" || fail 'entrada de boot BIOS ausente'
grep -Eq 'El Torito boot img :.*UEFI[[:space:]]+y' \
  <<<"${el_torito_report}" || fail 'entrada de boot UEFI ausente'
grep -Fq "Volume id    : 'FLAVOS_3_0_M1_1'" \
  <<<"${el_torito_report}" || fail 'volume id inesperado'
grep -Fq 'System area summary: MBR isohybrid' \
  <<<"${system_area_report}" || fail 'área de sistema não é MBR isohybrid'

for required_path in \
  /isolinux/isolinux.bin \
  /boot/grub/efi.img \
  /live/filesystem.squashfs \
  /live/initrd.img \
  /live/vmlinuz; do
  grep -Fq "'${required_path}'" <<<"${iso_files}" || \
    fail "arquivo obrigatório ausente na ISO: ${required_path}"
done

manifest_has_package() {
  local package_name="$1"

  awk -v package_name="${package_name}" \
    '{ candidate = $1; sub(/:[^:]+$/, "", candidate) }
     candidate == package_name { found = 1 }
     END { exit(found ? 0 : 1) }' \
    "${INTERNAL_MANIFEST}"
}

for package_name in \
  linux-image-amd64 \
  live-boot \
  live-config \
  live-config-systemd \
  sudo \
  systemd-sysv \
  user-setup \
  labwc \
  libwlroots-0.18 \
  xwayland \
  foot \
  wayland-utils \
  dbus-user-session \
  libpam-systemd; do
  manifest_has_package "${package_name}" || \
    fail "pacote obrigatório ausente no manifesto: ${package_name}"
done

labwc_version="$(
  awk '$1 == "labwc" { print $2; exit }' "${INTERNAL_MANIFEST}"
)"
if ! grep -Eq '^([0-9]+:)?0[.]8[.][0-9]+([-+~.:].*)?$' \
  <<<"${labwc_version}"; then
  fail "versão do Labwc fora da série 0.8.x: ${labwc_version:-ausente}"
fi

forbidden_package="$(
  awk '
    function forbidden(name) {
      if (name ~ /^(xorg|xserver-xorg|xserver-xorg-core|xserver-xorg-legacy)$/) return 1
      if (name ~ /^(gdm3|greetd|lightdm|lxdm|nodm|sddm|slim|wdm|xdm)$/) return 1
      if (name ~ /^(task-desktop|task-gnome-desktop|task-kde-desktop|task-xfce-desktop|task-lxde-desktop|task-lxqt-desktop|task-cinnamon-desktop|task-mate-desktop)$/) return 1
      if (name ~ /^(gnome|gnome-core|gnome-shell|gnome-session)$/) return 1
      if (name ~ /^(kde-full|kde-standard|kde-plasma-desktop)$/) return 1
      if (name ~ /^(plasma-desktop|plasma-workspace)$/) return 1
      if (name ~ /^(xfce4|lxde|lxqt)$/) return 1
      if (name ~ /^(mate-desktop-environment|mate-panel|mate-session-manager)$/) return 1
      if (name ~ /^(budgie-desktop|cinnamon|cosmic-session)$/) return 1
      if (name == "pipewire") return 1
      if (name == "wireplumber") return 1
      if (name ~ /^(network-manager|network-manager-gnome)$/) return 1
      if (name == "upower") return 1
      if (name ~ /^(pkexec|policykit-1|polkitd)$/) return 1
      if (name ~ /^(xdg-desktop-portal|xdg-desktop-portal-wlr)$/) return 1
      if (name == "seatd") return 1
      return 0
    }

    {
      package_name = $1
      sub(/:[^:]+$/, "", package_name)
    }
    forbidden(package_name) { print $1; exit }
  ' "${INTERNAL_MANIFEST}"
)"

[[ -z "${forbidden_package}" ]] || \
  fail "pacote fora do escopo do M1.1 presente: ${forbidden_package}"

xorriso -osirrox on -indev "${ISO_PATH}" \
  -extract /live/filesystem.squashfs "${SQUASHFS_IMAGE}" \
  >/dev/null 2>&1 || fail 'não foi possível extrair o squashfs da ISO'

unsquashfs -ll "${SQUASHFS_IMAGE}" >"${SQUASHFS_LISTING}" 2>/dev/null || \
  fail 'não foi possível listar o conteúdo do squashfs'

squashfs_has_regular_file() {
  local image_path="$1"

  awk -v expected="squashfs-root${image_path}" '
    $NF == expected && substr($1, 1, 1) == "-" { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "${SQUASHFS_LISTING}"
}

squashfs_has_executable() {
  local image_path="$1"

  awk -v expected="squashfs-root${image_path}" '
    $NF == expected && $1 == "-rwxr-xr-x" { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "${SQUASHFS_LISTING}"
}

squashfs_has_symlink() {
  local image_path="$1"
  local expected_target="$2"

  awk \
    -v expected="squashfs-root${image_path}" \
    -v target="${expected_target}" '
      substr($1, 1, 1) == "l" && $(NF - 2) == expected &&
        $(NF - 1) == "->" && $NF == target { found = 1 }
      END { exit(found ? 0 : 1) }
    ' "${SQUASHFS_LISTING}"
}

for required_path in \
  /etc/flavos-release \
  /usr/local/bin/flavos-m1-session \
  /usr/local/libexec/flavos-m1-session-runner \
  /usr/local/libexec/flavos-m1-autostart \
  /usr/local/libexec/flavos-m1-foot-challenge \
  /usr/local/libexec/flavos-m1-tty-challenge \
  /usr/local/libexec/flavos-m1-probe \
  /etc/profile.d/flavos-m1.sh \
  /etc/flavos/labwc/rc.xml \
  /etc/flavos/labwc/autostart \
  /etc/flavos/foot-m1.ini \
  /etc/systemd/system/flavos-m1-probe.service \
  /etc/systemd/system/flavos-m1-probe.timer; do
  squashfs_has_regular_file "${required_path}" || \
    fail "arquivo obrigatório ausente no squashfs: ${required_path}"
done

for executable_path in \
  /usr/local/bin/flavos-m1-session \
  /usr/local/libexec/flavos-m1-session-runner \
  /usr/local/libexec/flavos-m1-autostart \
  /usr/local/libexec/flavos-m1-foot-challenge \
  /usr/local/libexec/flavos-m1-tty-challenge \
  /usr/local/libexec/flavos-m1-probe \
  /etc/flavos/labwc/autostart \
  /etc/flavos/labwc/shutdown; do
  squashfs_has_executable "${executable_path}" || \
    fail "script obrigatório não é executável no squashfs: ${executable_path}"
done

squashfs_has_symlink \
  /etc/systemd/system/multi-user.target.wants/flavos-m1-probe.timer \
  ../flavos-m1-probe.timer || \
  fail 'timer do probe M1.1 não está habilitado corretamente no squashfs'

if grep -Eiq -- \
  'squashfs-root/.*(flavos-m0-probe|flavos-m0-autologin)|squashfs-root/etc/systemd/system/flavos-m0-probe[.](service|timer)' \
  "${SQUASHFS_LISTING}"; then
  fail 'probe, timer ou autologin do M0 permaneceu no squashfs M1.1'
fi

session_script="$(
  unsquashfs -cat "${SQUASHFS_IMAGE}" \
    /usr/local/bin/flavos-m1-session 2>/dev/null
)" || fail 'não foi possível ler o launcher da sessão no squashfs'
probe_script="$(
  unsquashfs -cat "${SQUASHFS_IMAGE}" \
    /usr/local/libexec/flavos-m1-probe 2>/dev/null
)" || fail 'não foi possível ler o probe M1.1 no squashfs'
foot_challenge="$(
  unsquashfs -cat "${SQUASHFS_IMAGE}" \
    /usr/local/libexec/flavos-m1-foot-challenge 2>/dev/null
)" || fail 'não foi possível ler o challenge Foot no squashfs'
session_runner="$(
  unsquashfs -cat "${SQUASHFS_IMAGE}" \
    /usr/local/libexec/flavos-m1-session-runner 2>/dev/null
)" || fail 'não foi possível ler o runner da sessão no squashfs'
autostart_helper="$(
  unsquashfs -cat "${SQUASHFS_IMAGE}" \
    /usr/local/libexec/flavos-m1-autostart 2>/dev/null
)" || fail 'não foi possível ler o autostart M1.1 no squashfs'
tty_challenge="$(
  unsquashfs -cat "${SQUASHFS_IMAGE}" \
    /usr/local/libexec/flavos-m1-tty-challenge 2>/dev/null
)" || fail 'não foi possível ler o challenge TTY no squashfs'
probe_service="$(
  unsquashfs -cat "${SQUASHFS_IMAGE}" \
    /etc/systemd/system/flavos-m1-probe.service 2>/dev/null
)" || fail 'não foi possível ler o serviço do probe M1.1 no squashfs'

grep -Fq 'DBUS_SESSION_BUS_ADDRESS="unix:path=${bus_socket}"' \
  <<<"${session_script}" || fail 'launcher não exige o D-Bus canônico no squashfs'
if grep -Ev '^[[:space:]]*(#|$)' <<<"${session_script}" | \
  grep -Eq '(^|[;&|[:space:]])dbus-run-session([[:space:]]|$)'; then
  fail 'launcher usa dbus-run-session privado no squashfs'
fi
grep -Fq '/sys/class/tty/tty0/active' <<<"${probe_script}" || \
  fail 'probe não comprova o VT ativo no squashfs'
grep -Fq 'active_vt=tty1' <<<"${probe_script}" || \
  fail 'sentinela do probe não registra o VT ativo no squashfs'
grep -Fq 'TimeoutStartSec=360s' <<<"${probe_service}" || \
  fail 'serviço do probe não possui timeout de 360 segundos no squashfs'
grep -Fq 'opt/flavos.m1.${name}' <<<"${probe_script}" || \
  fail 'probe root não possui o caminho fw_cfg no squashfs'
grep -Fq 'read_nonce graphical_nonce' <<<"${probe_script}" || \
  fail 'probe root não lê o nonce gráfico fw_cfg no squashfs'
grep -Fq 'read_nonce tty_nonce' <<<"${probe_script}" || \
  fail 'probe root não lê o nonce TTY fw_cfg no squashfs'
if grep -Fq 'qemu_fw_cfg' <<<"${foot_challenge}" || \
  grep -Fq 'qemu_fw_cfg' <<<"${tty_challenge}"; then
  fail 'challenge do usuário tenta ler nonce fw_cfg root-only no squashfs'
fi
if grep -Fq 'finish-request' <<<"${probe_script}" || \
  grep -Fq 'finish-request' <<<"${foot_challenge}"; then
  fail 'marker root finish-request permaneceu no squashfs'
fi

for atomic_writer in \
  "${session_runner}" \
  "${autostart_helper}" \
  "${foot_challenge}" \
  "${tty_challenge}"; do
  grep -Fq 'temporary="${destination}.tmp.$$"' <<<"${atomic_writer}" || \
    fail 'script publica markers sem arquivo temporário no squashfs'
  grep -Fq 'mv -f -- "${temporary}" "${destination}"' \
    <<<"${atomic_writer}" || \
    fail 'script publica markers sem rename atômico no squashfs'
done

if grep -Eq \
  'publish_text[[:space:]].*\$\{state_dir\}|(^|[;&|[:space:]])(touch|install|mkdir|mkfifo|ln|mv|cp|truncate)[[:space:]].*\$\{state_dir\}|>[[:space:]]*"?\$\{state_dir\}' \
  <<<"${probe_script}"; then
  fail 'probe root grava markers no diretório de estado do usuário no squashfs'
fi

flavos_release="$(
  unsquashfs -cat "${SQUASHFS_IMAGE}" /etc/flavos-release 2>/dev/null
)" || fail 'não foi possível ler /etc/flavos-release no squashfs'

for identity_line in \
  'NAME="Flavos OS"' \
  'VERSION="3.0"' \
  'MILESTONE="M1.1"' \
  'BASE="Debian 13 (trixie)"' \
  'ARCHITECTURE="amd64"'; do
  grep -Fxq "${identity_line}" <<<"${flavos_release}" || \
    fail "identidade incorreta em /etc/flavos-release: ${identity_line}"
done

iso_sha512="$(sha512sum -- "${ISO_PATH}" | awk '{print $1}')"
iso_size="$(stat -c %s -- "${ISO_PATH}")"

printf 'Estrutura da ISO M1.1 validada com sucesso.\n'
printf 'ISO: %s\n' "${ISO_PATH}"
printf 'Tamanho: %s bytes\n' "${iso_size}"
printf 'SHA-512: %s\n' "${iso_sha512}"
printf 'Boot: BIOS + UEFI, ISO híbrida, kernel/initrd/squashfs presentes.\n'
printf 'Stack: Labwc %s, Wayland/Foot/XWayland e instrumentos M1.1 presentes.\n' \
  "${labwc_version}"
