#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly AUTO_DIR="${REPO_ROOT}/image/auto"
readonly CONFIG_DIR="${REPO_ROOT}/image/config"
readonly INCLUDES_DIR="${CONFIG_DIR}/includes.chroot"
readonly SYSTEMD_DIR="${INCLUDES_DIR}/etc/systemd/system"

readonly M0_PACKAGE_LIST="${CONFIG_DIR}/package-lists/flavos-m0.list.chroot"
readonly M1_PACKAGE_LIST="${CONFIG_DIR}/package-lists/flavos-m1-display.list.chroot"
readonly FLAVOS_RELEASE="${INCLUDES_DIR}/etc/flavos-release"
readonly ISSUE="${INCLUDES_DIR}/etc/issue"

readonly SESSION="${INCLUDES_DIR}/usr/local/bin/flavos-m1-session"
readonly SESSION_RUNNER="${INCLUDES_DIR}/usr/local/libexec/flavos-m1-session-runner"
readonly AUTOSTART_HELPER="${INCLUDES_DIR}/usr/local/libexec/flavos-m1-autostart"
readonly FOOT_CHALLENGE="${INCLUDES_DIR}/usr/local/libexec/flavos-m1-foot-challenge"
readonly TTY_CHALLENGE="${INCLUDES_DIR}/usr/local/libexec/flavos-m1-tty-challenge"
readonly PROBE="${INCLUDES_DIR}/usr/local/libexec/flavos-m1-probe"
readonly PROFILE="${INCLUDES_DIR}/etc/profile.d/flavos-m1.sh"

readonly LABWC_DIR="${INCLUDES_DIR}/etc/flavos/labwc"
readonly LABWC_RC="${LABWC_DIR}/rc.xml"
readonly LABWC_AUTOSTART="${LABWC_DIR}/autostart"
readonly LABWC_SHUTDOWN="${LABWC_DIR}/shutdown"
readonly LABWC_ENVIRONMENT="${LABWC_DIR}/environment"
readonly FOOT_CONFIG="${INCLUDES_DIR}/etc/flavos/foot-m1.ini"

readonly PROBE_SERVICE="${SYSTEMD_DIR}/flavos-m1-probe.service"
readonly PROBE_TIMER="${SYSTEMD_DIR}/flavos-m1-probe.timer"
readonly PROBE_WANT="${SYSTEMD_DIR}/multi-user.target.wants/flavos-m1-probe.timer"

readonly ADR="${REPO_ROOT}/docs/adr/ADR-002-display-stack.md"
readonly ADR_INDEX="${REPO_ROOT}/docs/adr/README.md"

fail() {
  printf 'FALHOU: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "arquivo obrigatório ausente: $1"
}

require_executable() {
  [[ -f "$1" && -x "$1" ]] || \
    fail "script obrigatório ausente ou não executável: $1"
}

require_literal() {
  local needle=$1
  local file_path=$2
  local description=$3

  grep -Fq -- "${needle}" "${file_path}" || \
    fail "${description}: texto obrigatório ausente: ${needle}"
}

reject_pattern() {
  local pattern=$1
  local file_path=$2
  local description=$3

  if grep -Eiq -- "${pattern}" "${file_path}"; then
    fail "${description}: padrão proibido encontrado: ${pattern}"
  fi
}

reject_active_pattern() {
  local pattern=$1
  local file_path=$2
  local description=$3

  if sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "${file_path}" | \
    grep -Eiq -- "${pattern}"; then
    fail "${description}: padrão proibido encontrado: ${pattern}"
  fi
}

check_shell_syntax() {
  local file_path=$1
  local first_line

  require_executable "${file_path}"
  IFS= read -r first_line < "${file_path}" || true

  case "${first_line}" in
    '#!/bin/sh'|'#!/usr/bin/sh')
      sh -n "${file_path}"
      ;;
    '#!/bin/bash'|'#!/usr/bin/bash'|'#!/usr/bin/env bash')
      bash -n "${file_path}"
      ;;
    *)
      fail "shebang shell ausente ou não suportado: ${file_path}"
      ;;
  esac
}

normalized_packages() {
  sed \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' \
    -e '/^#/d' \
    -e '/^$/d' \
    "$1" | LC_ALL=C sort
}

for auto_script in config build clean; do
  require_executable "${AUTO_DIR}/${auto_script}"
done

sh -n "${AUTO_DIR}/config" "${AUTO_DIR}/clean"
bash -n "${AUTO_DIR}/build"

required_base_options=(
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
  '--image-name flavos-3.0-m1.1'
  '--iso-application "Flavos OS 3.0 M1.1"'
  '--iso-volume "FLAVOS_3_0_M1_1"'
  'boot=live components hostname=flavos username=flavos systemd.unit=multi-user.target console=tty0 console=ttyS0,115200n8 flavos.m1.probe=1'
)

for option in "${required_base_options[@]}"; do
  require_literal "${option}" "${AUTO_DIR}/config" \
    'configuração live-build da M1.1 incompleta'
done

if grep -Eq -- '--(architectures|binary-images)\b' "${AUTO_DIR}/config"; then
  fail 'a configuração usa opções plurais antigas do live-build'
fi

reject_pattern \
  'systemd\.unit=graphical\.target|flavos\.m0\.probe=1|WLR_BACKENDS[[:space:]]*=[[:space:]]*headless' \
  "${AUTO_DIR}/config" \
  'o boot técnico precisa continuar em multi-user/TTY e usar o probe M1'

require_file "${M0_PACKAGE_LIST}"
require_file "${M1_PACKAGE_LIST}"

expected_m0_packages="$({
  printf '%s\n' \
    linux-image-amd64 \
    live-boot \
    live-config \
    live-config-systemd \
    sudo \
    systemd-sysv \
    user-setup
} | LC_ALL=C sort)"
actual_m0_packages="$(normalized_packages "${M0_PACKAGE_LIST}")"

if [[ "${actual_m0_packages}" != "${expected_m0_packages}" ]]; then
  printf '%s\n' 'Pacotes M0 esperados:' >&2
  printf '%s\n' "${expected_m0_packages}" >&2
  printf '%s\n' 'Pacotes M0 encontrados:' >&2
  printf '%s\n' "${actual_m0_packages}" >&2
  fail 'a lista mínima de sete pacotes do M0 foi alterada'
fi

expected_m1_packages="$({
  printf '%s\n' \
    dbus-user-session \
    foot \
    labwc \
    libpam-systemd \
    wayland-utils \
    xwayland
} | LC_ALL=C sort)"
actual_m1_packages="$(normalized_packages "${M1_PACKAGE_LIST}")"

if [[ "${actual_m1_packages}" != "${expected_m1_packages}" ]]; then
  printf '%s\n' 'Pacotes M1.1 esperados:' >&2
  printf '%s\n' "${expected_m1_packages}" >&2
  printf '%s\n' 'Pacotes M1.1 encontrados:' >&2
  printf '%s\n' "${actual_m1_packages}" >&2
  fail 'a lista de display da M1.1 não corresponde ao contrato de seis pacotes'
fi

mapfile -d '' package_lists < <(
  find "${CONFIG_DIR}/package-lists" -maxdepth 1 -type f \
    -name '*.list.chroot' ! -name 'live.list.chroot' -print0 | LC_ALL=C sort -z
)

if ((${#package_lists[@]} != 2)); then
  printf '%s\n' 'Listas versionadas encontradas:' >&2
  printf '  %s\n' "${package_lists[@]}" >&2
  fail 'somente as listas explícitas M0 e M1.1 podem compor esta imagem'
fi

all_direct_packages="$(
  normalized_packages "${M0_PACKAGE_LIST}"
  normalized_packages "${M1_PACKAGE_LIST}"
)"

if grep -Eiq -- \
  '^(xorg|xserver-xorg(|-core|-legacy|-video-all|-input-all)|gdm3|lightdm|sddm|lxdm|slim|gnome(|-core|-shell)|kde-(full|standard)|plasma-desktop|xfce4|lxqt|cinnamon|mate-desktop-environment|pipewire(|-audio)|wireplumber|network-manager|upower|polkitd|xdg-desktop-portal(|-wlr))$' \
  <<< "${all_direct_packages}"; then
  fail 'a imagem inclui Xorg completo, DE, display manager ou componente reservado à M1.2'
fi

require_file "${FLAVOS_RELEASE}"
require_file "${ISSUE}"
require_literal 'NAME="Flavos OS"' "${FLAVOS_RELEASE}" 'identidade Flavos'
require_literal 'VERSION="3.0"' "${FLAVOS_RELEASE}" 'versão Flavos'
require_literal 'MILESTONE="M1.1"' "${FLAVOS_RELEASE}" 'milestone Flavos'
require_literal 'M1.1' "${ISSUE}" 'banner do sistema'

shell_scripts=(
  "${SESSION}"
  "${SESSION_RUNNER}"
  "${AUTOSTART_HELPER}"
  "${FOOT_CHALLENGE}"
  "${TTY_CHALLENGE}"
  "${PROBE}"
  "${LABWC_AUTOSTART}"
  "${LABWC_SHUTDOWN}"
)

for shell_script in "${shell_scripts[@]}"; do
  check_shell_syntax "${shell_script}"
done

project_scripts=(
  "${REPO_ROOT}/tools/archive-m1-build.sh"
  "${REPO_ROOT}/tools/test-m1-boot.sh"
  "${REPO_ROOT}/tests/validate-m1-iso.sh"
  "${REPO_ROOT}/tests/validate-m1-config.sh"
)

for project_script in "${project_scripts[@]}"; do
  check_shell_syntax "${project_script}"
done

require_literal 'FLAVOS_BUILD_COMMIT=' "${AUTO_DIR}/build" \
  'proveniência do build M1.1'
require_literal 'LIVE_BUILD_GENERATED_INPUTS_BEGIN' "${AUTO_DIR}/build" \
  'inventário dos inputs gerados do live-build'
require_literal 'config/package-lists/live.list.chroot' "${AUTO_DIR}/build" \
  'validação da lista live gerada'
require_literal 'hook ignorado não reconhecido' "${AUTO_DIR}/config" \
  'rejeição de hooks ignorados desconhecidos'
require_literal 'archive-m1-build.sh' "${AUTO_DIR}/clean" \
  'proteção da ISO M1.1 antes da limpeza'
require_literal 'current_head=' "${REPO_ROOT}/tools/archive-m1-build.sh" \
  'vínculo do arquivamento ao commit construído'
require_literal 'status --porcelain --untracked-files=normal' \
  "${REPO_ROOT}/tools/archive-m1-build.sh" \
  'worktree limpo durante o arquivamento'

require_file "${LABWC_ENVIRONMENT}"
require_file "${LABWC_RC}"
require_file "${FOOT_CONFIG}"
require_file "${PROFILE}"
[[ -r "${PROFILE}" ]] || fail "profile M1.1 ausente ou não legível: ${PROFILE}"
sh -n "${PROFILE}"
sh -n "${LABWC_ENVIRONMENT}"

require_literal '/usr/local/libexec/flavos-m1-session-runner' "${SESSION}" \
  'launcher da sessão'
require_literal 'bus_socket="${runtime_dir}/bus"' "${SESSION}" \
  'socket canônico do D-Bus do usuário'
require_literal 'DBUS_SESSION_BUS_ADDRESS="unix:path=${bus_socket}"' "${SESSION}" \
  'endereço canônico do D-Bus do usuário'
require_literal 'labwc' "${SESSION_RUNNER}" 'runner da sessão'
require_literal '/etc/flavos/labwc' "${SESSION_RUNNER}" \
  'diretório de configuração do Labwc'

require_literal '/proc/cmdline' "${PROFILE}" 'gate do profile de laboratório'
require_literal 'flavos.m1.probe=1' "${PROFILE}" 'gate do profile de laboratório'
require_literal 'tty1' "${PROFILE}" 'restrição do profile ao TTY gráfico'
require_literal '/usr/local/bin/flavos-m1-session' "${PROFILE}" \
  'início da sessão a partir do login PAM'

require_literal '/usr/local/libexec/flavos-m1-autostart' "${LABWC_AUTOSTART}" \
  'autostart do Labwc'
require_literal 'foot' "${AUTOSTART_HELPER}" 'aplicação Wayland de prova'
require_literal '/etc/flavos/foot-m1.ini' "${AUTOSTART_HELPER}" \
  'configuração técnica do Foot'
require_literal '/usr/local/libexec/flavos-m1-foot-challenge' \
  "${AUTOSTART_HELPER}" 'challenge executado dentro do Foot'
require_literal '/usr/local/libexec/flavos-m1-tty-challenge' "${SESSION_RUNNER}" \
  'challenge executado após o retorno ao TTY'
require_literal 'opt/flavos.m1.${name}' "${PROBE}" \
  'caminho fw_cfg lido pelo probe root'
require_literal 'read_nonce graphical_nonce' "${PROBE}" \
  'nonce gráfico lido pelo probe root'
for marker in mouse-ready mouse-ok keyboard-ready keyboard-ok; do
  require_literal "${marker}" "${FOOT_CHALLENGE}" \
    'marker do challenge Foot'
done
require_literal 'labwc --exit' "${FOOT_CHALLENGE}" \
  'logout solicitado pelo challenge Foot'
require_literal 'read_nonce tty_nonce' "${PROBE}" \
  'nonce TTY lido pelo probe root'
for marker in tty-ready tty-ok; do
  require_literal "${marker}" "${TTY_CHALLENGE}" \
    'marker do challenge TTY'
done
require_literal 'FLAVOS_M1_1_PROBE result=' "${PROBE}" \
  'sentinela do probe M1.1'
require_literal 'systemctl --user' "${AUTOSTART_HELPER}" \
  'verificação da sessão systemd --user'
require_literal 'systemd-user.status' "${PROBE}" \
  'consumo do resultado de systemd --user pelo probe'
require_literal 'systemd_user=ok' "${PROBE}" \
  'resultado de systemd --user no probe'
require_literal 'DBUS_SESSION_BUS_ADDRESS' "${AUTOSTART_HELPER}" \
  'captura da sessão D-Bus do usuário'
require_literal 'systemd_deadline=$((SECONDS + 15))' "${AUTOSTART_HELPER}" \
  'espera pela importação assíncrona do ambiente Labwc'
require_literal 'grep -Fxq "WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"' \
  "${AUTOSTART_HELPER}" 'confirmação do ambiente systemd --user'
require_literal '[[ "${dbus_address}" == "unix:path=${runtime_dir}/bus" ]]' \
  "${PROBE}" 'validação do D-Bus canônico pelo probe'
require_literal '/sys/class/tty/tty0/active' "${PROBE}" \
  'validação do VT ativo após o logout'
require_literal 'active_vt=tty1' "${PROBE}" \
  'resultado do VT ativo na sentinela final'
require_literal 'drm_node="${fd_target##*/}"' "${PROBE}" \
  'correlação do card DRM com o descritor aberto pelo Labwc'
require_literal 'for status_path in "${card_path}"-*/status' "${PROBE}" \
  'correlação do conector com o card DRM usado pelo Labwc'
require_literal 'for virtio_device in "${card_device}"/virtio*' "${PROBE}" \
  'resolução do driver funcional no filho do transporte virtio-pci'
require_literal '[[ "${drm_driver}" == virtio_gpu ]]' "${PROBE}" \
  'driver gráfico virtio_gpu comprovado pelo probe'
require_literal '[[ "${drm_transport}" == virtio-pci ]]' "${PROBE}" \
  'transporte virtio-pci comprovado separadamente pelo probe'

for atomic_writer in \
  "${SESSION_RUNNER}" \
  "${AUTOSTART_HELPER}" \
  "${FOOT_CHALLENGE}" \
  "${TTY_CHALLENGE}"; do
  require_literal 'temporary="${destination}.tmp.$$"' "${atomic_writer}" \
    'publicação atômica de estado da sessão'
  require_literal 'mv -f -- "${temporary}" "${destination}"' "${atomic_writer}" \
    'publicação atômica de estado da sessão'
done

for runtime_file in \
  "${SESSION}" \
  "${SESSION_RUNNER}" \
  "${AUTOSTART_HELPER}" \
  "${FOOT_CHALLENGE}" \
  "${TTY_CHALLENGE}" \
  "${PROBE}"; do
  reject_active_pattern \
    '(^|[;&|[:space:]])dbus-run-session([[:space:]]|$)' \
    "${runtime_file}" \
    'um barramento D-Bus privado não pode substituir /run/user/UID/bus'
  reject_pattern 'finish-request' "${runtime_file}" \
    'o challenge do usuário deve encerrar o Labwc sem marker gravado por root'
done

for user_challenge in "${FOOT_CHALLENGE}" "${TTY_CHALLENGE}"; do
  reject_pattern 'qemu_fw_cfg' "${user_challenge}" \
    'somente o probe root pode ler os nonces fw_cfg 0400'
done

reject_pattern \
  'publish_text[[:space:]].*\$\{state_dir\}|(^|[;&|[:space:]])(touch|install|mkdir|mkfifo|ln|mv|cp|truncate)[[:space:]].*\$\{state_dir\}|>[[:space:]]*"?\$\{state_dir\}' \
  "${PROBE}" \
  'o probe root deve somente observar os markers publicados pelo usuário'

require_literal '<labwc_config' "${LABWC_RC}" 'raiz da configuração Labwc'
require_literal '</labwc_config>' "${LABWC_RC}" 'fechamento da configuração Labwc'

for runtime_file in \
  "${SESSION}" \
  "${SESSION_RUNNER}" \
  "${AUTOSTART_HELPER}" \
  "${LABWC_AUTOSTART}" \
  "${LABWC_ENVIRONMENT}"; do
  reject_pattern \
    "^[[:space:]]*(export[[:space:]]+)?WLR_RENDERER[[:space:]]*=[[:space:]]*[\"']?pixman|^[[:space:]]*(export[[:space:]]+)?WLR_BACKENDS[[:space:]]*=[[:space:]]*[\"']?headless" \
    "${runtime_file}" \
    'renderer Pixman e backend headless não podem ser defaults do M1.1'
done

require_file "${PROBE_SERVICE}"
require_file "${PROBE_TIMER}"
[[ -L "${PROBE_WANT}" ]] || fail 'timer do probe M1.1 não está habilitado'
[[ "$(readlink -- "${PROBE_WANT}")" == '../flavos-m1-probe.timer' ]] || \
  fail 'link de habilitação do probe M1.1 aponta para o destino errado'

require_literal '[Service]' "${PROBE_SERVICE}" 'unidade do probe M1.1'
require_literal 'ConditionKernelCommandLine=flavos.m1.probe=1' \
  "${PROBE_SERVICE}" 'condição da unidade do probe M1.1'
require_literal 'ExecStart=/usr/local/libexec/flavos-m1-probe' \
  "${PROBE_SERVICE}" 'comando da unidade do probe M1.1'
require_literal 'TimeoutStartSec=360s' "${PROBE_SERVICE}" \
  'timeout total do gate M1.1'
require_literal '[Timer]' "${PROBE_TIMER}" 'timer do probe M1.1'
require_literal 'ConditionKernelCommandLine=flavos.m1.probe=1' \
  "${PROBE_TIMER}" 'condição do timer do probe M1.1'
require_literal 'Unit=flavos-m1-probe.service' "${PROBE_TIMER}" \
  'serviço acionado pelo timer M1.1'

if find "${SYSTEMD_DIR}" -maxdepth 1 -type f \
  \( -name 'flavos-m1-*.service' -o -name 'flavos-m1-*.timer' \) \
  ! -name 'flavos-m1-probe.service' ! -name 'flavos-m1-probe.timer' \
  -print -quit | grep -q .; then
  fail 'o probe/timer deve ser o único par de unidades próprio da M1.1'
fi

[[ ! -e "${SYSTEMD_DIR}/flavos-m1-session.service" ]] || \
  fail 'Labwc deve nascer do login PAM em tty1/seat0, não de um serviço root'
[[ ! -e "${SYSTEMD_DIR}/display-manager.service" ]] || \
  fail 'display manager está fora do escopo da M1.1'

legacy_m0_paths=(
  "${INCLUDES_DIR}/usr/local/libexec/flavos-m0-probe"
  "${SYSTEMD_DIR}/flavos-m0-probe.service"
  "${SYSTEMD_DIR}/flavos-m0-probe.timer"
  "${SYSTEMD_DIR}/multi-user.target.wants/flavos-m0-probe.timer"
  "${SYSTEMD_DIR}/serial-getty@ttyS0.service.d/flavos-m0-autologin.conf"
)

for legacy_path in "${legacy_m0_paths[@]}"; do
  [[ ! -e "${legacy_path}" && ! -L "${legacy_path}" ]] || \
    fail "instrumentação M0 permaneceu na árvore M1.1: ${legacy_path}"
done

if grep -RIEq -- \
  'flavos[.]m0[.]probe|FLAVOS_M0_PROBE|flavos-m0-probe|flavos-m0-autologin' \
  "${INCLUDES_DIR}"; then
  fail 'probe, timer ou autologin do M0 permaneceu no conteúdo da M1.1'
fi

require_file "${ADR}"
require_file "${ADR_INDEX}"
require_literal '# ADR-002' "${ADR}" 'título da decisão gráfica'
require_literal '**Estado:** Aceito' "${ADR}" 'estado da decisão gráfica'
for decision in Wayland Labwc wlroots XWayland Pixman Xorg; do
  grep -Eiq -- "${decision}" "${ADR}" || \
    fail "ADR-002 não registra a decisão obrigatória: ${decision}"
done
require_literal '[ADR-002](ADR-002-display-stack.md)' "${ADR_INDEX}" \
  'índice de ADRs'
grep -Eq -- '^\| \[ADR-002\]\(ADR-002-display-stack\.md\) \| Aceito \|' \
  "${ADR_INDEX}" || fail 'ADR-002 não está indexado como Aceito'

printf 'Configuração estática da M1.1 validada com sucesso.\n'
