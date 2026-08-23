#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly MODE="${1:-all}"
readonly ISO_INPUT="${FLAVOS_M1_ISO:-${REPO_ROOT}/image/flavos-3.0-m1.1-amd64.hybrid.iso}"
readonly OVMF_CODE="${FLAVOS_OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}"
readonly OVMF_VARS="${FLAVOS_OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}"
readonly TIMEOUT_SECONDS="${FLAVOS_M1_BOOT_TIMEOUT:-390}"
readonly MEMORY_MB="${FLAVOS_M1_BOOT_MEMORY_MB:-2048}"
readonly VCPUS="${FLAVOS_M1_BOOT_CPUS:-2}"
readonly DISPLAY_WIDTH=1280
readonly DISPLAY_HEIGHT=800
readonly FOOT_BACKGROUND=123456
readonly EVIDENCE_ROOT="${FLAVOS_M1_EVIDENCE_ROOT:-${REPO_ROOT}/releases/local/m1.1/boot-tests}"

fail() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

case "${MODE}" in
  all) modes=(bios uefi) ;;
  bios | uefi) modes=("${MODE}") ;;
  *) fail "uso: $0 [all|bios|uefi]" ;;
esac

for command_name in qemu-system-x86_64 sha512sum sha256sum mktemp mkfifo \
  realpath install cat sed tail tr grep awk od stat identify convert cmp; do
  command -v "${command_name}" >/dev/null 2>&1 || \
    fail "${command_name} não está instalado"
done

((EUID != 0)) || fail 'execute os testes como usuário normal, nunca com sudo'
[[ "${TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]] || \
  fail 'FLAVOS_M1_BOOT_TIMEOUT deve ser um inteiro positivo'
[[ "${MEMORY_MB}" =~ ^[1-9][0-9]*$ ]] || \
  fail 'FLAVOS_M1_BOOT_MEMORY_MB deve ser um inteiro positivo'
[[ "${VCPUS}" =~ ^[1-9][0-9]*$ ]] || \
  fail 'FLAVOS_M1_BOOT_CPUS deve ser um inteiro positivo'
[[ -f "${ISO_INPUT}" ]] || fail "ISO não encontrada: ${ISO_INPUT}"

if [[ "${MODE}" != bios ]]; then
  [[ -f "${OVMF_CODE}" ]] || fail "OVMF CODE ausente: ${OVMF_CODE}"
  [[ -f "${OVMF_VARS}" ]] || fail "OVMF VARS ausente: ${OVMF_VARS}"
fi

readonly ISO_PATH="$(realpath -- "${ISO_INPUT}")"
readonly ISO_SHA512_BEFORE="$(sha512sum -- "${ISO_PATH}" | awk '{print $1}')"
readonly SHORT_SHA="${ISO_SHA512_BEFORE:0:12}"

mkdir -p -- "${EVIDENCE_ROOT}/${SHORT_SHA}"
readonly RUN_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
readonly EVIDENCE_DIR="$(mktemp -d "${EVIDENCE_ROOT}/${SHORT_SHA}/${RUN_TIMESTAMP}-XXXXXX")"
readonly TEMP_DIR="$(mktemp -d)"

qemu_pid=
monitor_fd=
serial_fd=
serial_reader_pid=

wait_for_stop() {
  local pid=$1
  local attempt
  for ((attempt = 0; attempt < 20; attempt++)); do
    kill -0 "${pid}" 2>/dev/null || return 0
    sleep 0.1
  done
  return 1
}

reap_process_bounded() {
  local pid=$1
  local label=$2

  if wait_for_stop "${pid}"; then
    wait "${pid}" 2>/dev/null || true
    return
  fi
  kill -TERM "${pid}" 2>/dev/null || true
  if wait_for_stop "${pid}"; then
    wait "${pid}" 2>/dev/null || true
    return
  fi
  kill -KILL "${pid}" 2>/dev/null || true
  if wait_for_stop "${pid}"; then
    wait "${pid}" 2>/dev/null || true
    return
  fi
  printf 'Aviso: %s %s não encerrou após SIGKILL.\n' "${label}" "${pid}" >&2
  disown "${pid}" 2>/dev/null || true
}

print_log_tail_escaped() {
  local file_path=$1
  local line_count=$2
  [[ -f "${file_path}" ]] || return 0
  tail -n "${line_count}" -- "${file_path}" | LC_ALL=C sed -n 'l'
}

stop_active_vm() {
  if [[ -n "${monitor_fd:-}" ]]; then
    printf 'quit\n' >&"${monitor_fd}" 2>/dev/null || true
    exec {monitor_fd}>&- 2>/dev/null || true
    monitor_fd=
  fi
  if [[ -n "${serial_fd:-}" ]]; then
    exec {serial_fd}>&- 2>/dev/null || true
    serial_fd=
  fi
  if [[ -n "${qemu_pid:-}" ]]; then
    reap_process_bounded "${qemu_pid}" QEMU
    qemu_pid=
  fi
  if [[ -n "${serial_reader_pid:-}" ]]; then
    reap_process_bounded "${serial_reader_pid}" 'leitor serial'
    serial_reader_pid=
  fi
}

on_exit() {
  local exit_code=$?
  set +e
  stop_active_vm
  rm -rf -- "${TEMP_DIR}"
  if ((exit_code != 0)); then
    printf 'Evidências preservadas em: %s\n' "${EVIDENCE_DIR}" >&2
  fi
  trap - EXIT
  exit "${exit_code}"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  accel_args=(-accel kvm -cpu host)
  accel_name=kvm
else
  accel_args=(-accel tcg,thread=multi -cpu max)
  accel_name=tcg
fi

{
  printf 'MILESTONE=M1.1\n'
  printf 'ISO=%s\n' "${ISO_PATH}"
  printf 'ISO_SHA512=%s\n' "${ISO_SHA512_BEFORE}"
  printf 'STARTED_AT_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'ACCELERATOR=%s\n' "${accel_name}"
  printf 'MEMORY_MB=%s\n' "${MEMORY_MB}"
  printf 'VCPUS=%s\n' "${VCPUS}"
  printf 'DISPLAY=%sx%s virtio-vga DRM scanout\n' "${DISPLAY_WIDTH}" "${DISPLAY_HEIGHT}"
  printf 'INPUT_VALIDATION=qemu-emulated-mouse-and-keyboard-through-labwc-and-foot\n'
  printf 'QEMU_SANDBOX=enabled\n'
  printf 'QEMU_VERSION=%s\n' "$(qemu-system-x86_64 --version | sed -n '1p')"
} >"${EVIDENCE_DIR}/metadata.txt"

new_nonce() {
  local raw
  raw="$(od -An -N4 -tu4 /dev/urandom | tr -d '[:space:]')"
  printf '%010u' "${raw}"
}

type_digits() {
  local value=$1
  local digit
  local index
  for ((index = 0; index < ${#value}; index++)); do
    digit="${value:index:1}"
    printf 'sendkey %s 20\n' "${digit}" >&"${monitor_fd}"
    sleep 0.06
  done
  printf 'sendkey ret 20\n' >&"${monitor_fd}"
}

wait_for_screendump() {
  local file_path=$1
  local attempt current_size previous_size=0 stable_reads=0
  for ((attempt = 0; attempt < 80; attempt++)); do
    if [[ -s "${file_path}" ]] && identify "${file_path}" >/dev/null 2>&1; then
      current_size="$(stat -c %s -- "${file_path}")"
      if [[ "${current_size}" == "${previous_size}" ]]; then
        stable_reads=$((stable_reads + 1))
        ((stable_reads >= 2)) && return 0
      else
        stable_reads=0
        previous_size="${current_size}"
      fi
    fi
    sleep 0.1
  done
  return 1
}

validate_graphical_screenshot() {
  local mode=$1
  local ppm_path=$2
  local png_path="${EVIDENCE_DIR}/screen-${mode}-labwc.png"
  local histogram_path="${EVIDENCE_DIR}/screen-${mode}-histogram.txt"
  local dimensions width height total_pixels color_count

  dimensions="$(identify -format '%w %h' "${ppm_path}")" || return 1
  read -r width height <<<"${dimensions}"
  [[ "${width}" == "${DISPLAY_WIDTH}" && "${height}" == "${DISPLAY_HEIGHT}" ]] || {
    printf 'Screenshot %s tem dimensão inesperada: %s.\n' "${mode}" "${dimensions}" >&2
    return 1
  }

  convert "${ppm_path}" -format %c histogram:info:- >"${histogram_path}"
  color_count="$(awk -v color="#${FOOT_BACKGROUND}" '
    index(toupper($0), toupper(color)) {
      count=$1
      sub(/:$/, "", count)
      print count
      exit
    }
  ' "${histogram_path}")"
  [[ "${color_count:-}" =~ ^[0-9]+$ ]] || {
    printf 'A cor de fundo técnica do Foot não apareceu no screenshot %s.\n' \
      "${mode}" >&2
    return 1
  }

  total_pixels=$((width * height))
  ((color_count * 100 >= total_pixels * 55)) || {
    printf 'Foot não ocupa o scanout %s: cor técnica cobre só %s/%s pixels.\n' \
      "${mode}" "${color_count}" "${total_pixels}" >&2
    return 1
  }

  convert "${ppm_path}" "${png_path}"
  {
    printf 'DIMENSIONS=%sx%s\n' "${width}" "${height}"
    printf 'FOOT_BACKGROUND=#%s\n' "${FOOT_BACKGROUND}"
    printf 'FOOT_BACKGROUND_PIXELS=%s\n' "${color_count}"
    printf 'TOTAL_PIXELS=%s\n' "${total_pixels}"
    printf 'PPM_SHA256=%s\n' "$(sha256sum "${ppm_path}" | awk '{print $1}')"
    printf 'PNG_SHA256=%s\n' "$(sha256sum "${png_path}" | awk '{print $1}')"
  } >"${EVIDENCE_DIR}/screen-${mode}-metadata.txt"
}

validate_tty_screenshot() {
  local mode=$1
  local ppm_path=$2
  local png_path="${EVIDENCE_DIR}/screen-${mode}-tty.png"
  local histogram_path="${EVIDENCE_DIR}/screen-${mode}-tty-histogram.txt"
  local dimensions width height total_pixels black_pixels non_black_pixels

  dimensions="$(identify -format '%w %h' "${ppm_path}")" || return 1
  read -r width height <<<"${dimensions}"
  [[ "${width}" == "${DISPLAY_WIDTH}" && "${height}" == "${DISPLAY_HEIGHT}" ]] || {
    printf 'Screenshot TTY %s tem dimensão inesperada: %s.\n' \
      "${mode}" "${dimensions}" >&2
    return 1
  }

  convert "${ppm_path}" -format %c histogram:info:- >"${histogram_path}"
  black_pixels="$(awk '
    index(toupper($0), "#000000") {
      count=$1
      sub(/:$/, "", count)
      print count
      exit
    }
  ' "${histogram_path}")"
  [[ "${black_pixels:-}" =~ ^[0-9]+$ ]] || {
    printf 'O framebuffer TTY %s não contém o fundo preto esperado.\n' \
      "${mode}" >&2
    return 1
  }

  total_pixels=$((width * height))
  non_black_pixels=$((total_pixels - black_pixels))
  ((black_pixels * 100 >= total_pixels * 60)) || {
    printf 'O framebuffer TTY %s não é predominantemente preto.\n' \
      "${mode}" >&2
    return 1
  }
  ((non_black_pixels >= 200)) || {
    printf 'O framebuffer TTY %s não contém pixels suficientes de texto.\n' \
      "${mode}" >&2
    return 1
  }

  convert "${ppm_path}" "${png_path}"
  {
    printf 'DIMENSIONS=%sx%s\n' "${width}" "${height}"
    printf 'BLACK_PIXELS=%s\n' "${black_pixels}"
    printf 'NON_BLACK_PIXELS=%s\n' "${non_black_pixels}"
    printf 'TOTAL_PIXELS=%s\n' "${total_pixels}"
    printf 'PPM_SHA256=%s\n' "$(sha256sum "${ppm_path}" | awk '{print $1}')"
    printf 'PNG_SHA256=%s\n' "$(sha256sum "${png_path}" | awk '{print $1}')"
  } >"${EVIDENCE_DIR}/screen-${mode}-tty-metadata.txt"
}

validate_ready_line() {
  local mode=$1
  local line=$2
  local token
  for token in \
    'stage=MOUSE_READY' \
    "firmware=${mode}" \
    'drm=present' \
    'input=present' \
    'driver=virtio_gpu'; do
    [[ " ${line} " == *" ${token} "* ]] || {
      printf 'Sentinela gráfica %s sem token: %s\n' "${mode}" "${token}" >&2
      return 1
    }
  done
}

validate_final_line() {
  local mode=$1
  local line=$2
  local token
  for token in \
    'result=PASS' \
    "firmware=${mode}" \
    'pid1=systemd' \
    'arch=x86_64' \
    'hostname=flavos' \
    'multi_user=active' \
    'tty1=active' \
    'identity=ok' \
    'logind=ok' \
    'seat=seat0' \
    'vt=1' \
    'active_vt=tty1' \
    'drm=ok' \
    'driver=virtio_gpu' \
    'wayland=ok' \
    'labwc=ok' \
    'foot=ok' \
    'xwayland=available' \
    'dbus_user=ok' \
    'systemd_user=ok' \
    'mouse=ok' \
    'keyboard=ok' \
    'logout=ok' \
    'return_tty=ok' \
    'failures=none'; do
    [[ " ${line} " == *" ${token} "* ]] || {
      printf 'Probe final %s sem token: %s\n' "${mode}" "${token}" >&2
      return 1
    }
  done
}

run_mode() {
  local mode=$1
  local serial_log="${EVIDENCE_DIR}/serial-${mode}.log"
  local qemu_log="${EVIDENCE_DIR}/qemu-${mode}.log"
  local monitor_fifo="${TEMP_DIR}/monitor-${mode}.in"
  local serial_prefix="${TEMP_DIR}/serial-${mode}"
  local serial_input="${TEMP_DIR}/serial-${mode}.in"
  local serial_output="${TEMP_DIR}/serial-${mode}.out"
  local graphical_ppm="${EVIDENCE_DIR}/screen-${mode}-labwc.ppm"
  local tty_ppm="${EVIDENCE_DIR}/screen-${mode}-tty.ppm"
  local graphical_nonce tty_nonce elapsed next_enter ready_line final_line
  local mouse_sent=0 keyboard_sent=0 tty_sent=0 screen_validated=0
  local kernel_started=0
  local -a firmware_args=()

  graphical_nonce="$(new_nonce)"
  tty_nonce="$(new_nonce)"
  printf '%s\n' "${graphical_nonce}" >"${EVIDENCE_DIR}/challenge-${mode}-graphical.txt"
  printf '%s\n' "${tty_nonce}" >"${EVIDENCE_DIR}/challenge-${mode}-tty.txt"

  if [[ "${mode}" == uefi ]]; then
    local vars_copy="${TEMP_DIR}/OVMF_VARS_4M-${mode}.fd"
    install -m 0600 -- "${OVMF_VARS}" "${vars_copy}"
    firmware_args=(
      -drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE}"
      -drive "if=pflash,format=raw,unit=1,file=${vars_copy}"
    )
  fi

  mkfifo -- "${monitor_fifo}" "${serial_input}" "${serial_output}"
  exec {monitor_fd}<>"${monitor_fifo}"
  exec {serial_fd}<>"${serial_input}"
  cat "${serial_output}" >"${serial_log}" &
  serial_reader_pid=$!

  printf 'Testando M1.1 %s com %s...\n' "${mode^^}" "${accel_name}"
  qemu-system-x86_64 \
    -name "flavos-m1-${mode}" \
    -machine q35 \
    -no-user-config \
    "${accel_args[@]}" \
    -m "${MEMORY_MB}" \
    -smp "${VCPUS}" \
    -boot once=d,menu=off \
    -drive "file=${ISO_PATH},media=cdrom,format=raw,readonly=on" \
    -nic none \
    -device virtio-rng-pci \
    -vga none \
    -device "virtio-vga,xres=${DISPLAY_WIDTH},yres=${DISPLAY_HEIGHT},max_outputs=1" \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -display none \
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny \
    -fw_cfg "name=opt/flavos.m1.graphical_nonce,string=${graphical_nonce}" \
    -fw_cfg "name=opt/flavos.m1.tty_nonce,string=${tty_nonce}" \
    -chardev "pipe,id=m1serial,path=${serial_prefix}" \
    -serial chardev:m1serial \
    -monitor stdio \
    -no-reboot \
    -rtc base=utc \
    "${firmware_args[@]}" \
    <"${monitor_fifo}" >"${qemu_log}" 2>&1 &
  qemu_pid=$!

  elapsed=0
  next_enter=1
  while ((elapsed < TIMEOUT_SECONDS)); do
    if ! kill -0 "${qemu_pid}" 2>/dev/null; then
      printf 'QEMU %s encerrou antes da confirmação M1.1.\n' "${mode}" >&2
      print_log_tail_escaped "${qemu_log}" 100 >&2 || true
      return 1
    fi

    if [[ -f "${serial_log}" ]] && \
      grep -Fq 'FLAVOS_M1_1_PROBE result=FAIL' "${serial_log}"; then
      print_log_tail_escaped "${serial_log}" 80 >&2 || true
      return 1
    fi

    if ((kernel_started == 0)) && [[ -f "${serial_log}" ]] && \
      grep -Fq 'Linux version ' "${serial_log}"; then
      kernel_started=1
    fi

    if ((mouse_sent == 0)) && [[ -f "${serial_log}" ]]; then
      ready_line="$(grep -F 'FLAVOS_M1_1_STAGE stage=MOUSE_READY' \
        "${serial_log}" | tail -n 1 | tr -d '\r' || true)"
      if [[ -n "${ready_line}" ]]; then
        validate_ready_line "${mode}" "${ready_line}"
        printf '%s\n' "${ready_line}" >"${EVIDENCE_DIR}/ready-${mode}.txt"
        kernel_started=1
        printf 'screendump "%s"\n' "${graphical_ppm}" >&"${monitor_fd}"
        wait_for_screendump "${graphical_ppm}" || {
          printf 'QEMU não produziu o screenshot gráfico %s.\n' "${mode}" >&2
          return 1
        }
        validate_graphical_screenshot "${mode}" "${graphical_ppm}"
        screen_validated=1
        printf 'mouse_move 12 8\n' >&"${monitor_fd}"
        printf 'mouse_button 1\n' >&"${monitor_fd}"
        mouse_sent=1
      fi
    fi

    if ((mouse_sent == 1 && keyboard_sent == 0)) && [[ -f "${serial_log}" ]] && \
      grep -Fq 'FLAVOS_M1_1_STAGE stage=KEYBOARD_READY' "${serial_log}"; then
      printf 'mouse_button 0\n' >&"${monitor_fd}"
      sleep 0.2
      type_digits "${graphical_nonce}"
      keyboard_sent=1
    fi

    if ((keyboard_sent == 1 && tty_sent == 0)) && [[ -f "${serial_log}" ]] && \
      grep -Fq 'FLAVOS_M1_1_STAGE stage=TTY_READY' "${serial_log}"; then
      printf 'screendump "%s"\n' "${tty_ppm}" >&"${monitor_fd}"
      wait_for_screendump "${tty_ppm}" || {
        printf 'QEMU não produziu o screenshot de retorno ao TTY %s.\n' "${mode}" >&2
        return 1
      }
      cmp -s -- "${graphical_ppm}" "${tty_ppm}" && {
        printf 'O framebuffer %s não mudou após o logout do Labwc.\n' "${mode}" >&2
        return 1
      }
      validate_tty_screenshot "${mode}" "${tty_ppm}"
      type_digits "${tty_nonce}"
      tty_sent=1
    fi

    if ((tty_sent == 1)) && [[ -f "${serial_log}" ]]; then
      final_line="$(grep -F 'FLAVOS_M1_1_PROBE result=PASS' \
        "${serial_log}" | tail -n 1 | tr -d '\r' || true)"
      if [[ -n "${final_line}" ]]; then
        ((screen_validated == 1)) || return 1
        validate_final_line "${mode}" "${final_line}"
        printf '%s\n' "${final_line}" >"${EVIDENCE_DIR}/probe-${mode}.txt"
        printf '%s=PASS\n' "${mode^^}" >>"${EVIDENCE_DIR}/results.txt"
        printf '%s aprovado: DRM/Wayland/Labwc/Foot, mouse, teclado e retorno ao TTY.\n' \
          "${mode^^}"
        stop_active_vm
        return 0
      fi
    fi

    if ((kernel_started == 0 && elapsed >= next_enter)); then
      printf 'sendkey ret 20\n' >&"${monitor_fd}" || true
      next_enter=$((next_enter + 2))
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  printf 'Timeout de %ss esperando a aceitação M1.1 em %s.\n' \
    "${TIMEOUT_SECONDS}" "${mode}" >&2
  print_log_tail_escaped "${serial_log}" 160 >&2 || true
  print_log_tail_escaped "${qemu_log}" 100 >&2 || true
  return 1
}

for mode in "${modes[@]}"; do
  run_mode "${mode}"
done

iso_sha512_after="$(sha512sum -- "${ISO_PATH}" | awk '{print $1}')"
[[ "${iso_sha512_after}" == "${ISO_SHA512_BEFORE}" ]] || \
  fail 'a ISO foi alterada durante os testes M1.1'

{
  printf 'FINISHED_AT_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'ISO_SHA512_AFTER=%s\n' "${iso_sha512_after}"
} >>"${EVIDENCE_DIR}/metadata.txt"

printf 'Testes de boot M1.1 concluídos com sucesso.\n'
printf 'Evidências: %s\n' "${EVIDENCE_DIR}"
