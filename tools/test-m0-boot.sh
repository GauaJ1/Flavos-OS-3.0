#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly MODE="${1:-all}"
readonly ISO_INPUT="${FLAVOS_M0_ISO:-${REPO_ROOT}/image/flavos-3.0-m0-amd64.hybrid.iso}"
readonly OVMF_CODE="${FLAVOS_OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}"
readonly OVMF_VARS="${FLAVOS_OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}"
readonly TIMEOUT_SECONDS="${FLAVOS_M0_BOOT_TIMEOUT:-180}"
readonly MEMORY_MB="${FLAVOS_M0_BOOT_MEMORY_MB:-1536}"
readonly VCPUS="${FLAVOS_M0_BOOT_CPUS:-2}"
readonly EVIDENCE_ROOT="${FLAVOS_M0_EVIDENCE_ROOT:-${REPO_ROOT}/releases/local/m0/boot-tests}"

fail() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

case "${MODE}" in
  all) modes=(bios uefi) ;;
  bios | uefi) modes=("${MODE}") ;;
  *) fail "uso: $0 [all|bios|uefi]" ;;
esac

for command_name in qemu-system-x86_64 sha512sum mktemp mkfifo realpath install cat sed tail tr grep; do
  command -v "${command_name}" >/dev/null 2>&1 || \
    fail "${command_name} não está instalado"
done

((EUID != 0)) || \
  fail 'execute os testes como usuário normal, nunca com sudo'

[[ "${TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]] || \
  fail 'FLAVOS_M0_BOOT_TIMEOUT deve ser um inteiro positivo'
[[ "${MEMORY_MB}" =~ ^[1-9][0-9]*$ ]] || \
  fail 'FLAVOS_M0_BOOT_MEMORY_MB deve ser um inteiro positivo'
[[ "${VCPUS}" =~ ^[1-9][0-9]*$ ]] || \
  fail 'FLAVOS_M0_BOOT_CPUS deve ser um inteiro positivo'
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
    if ! kill -0 "${pid}" 2>/dev/null; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

reap_process_bounded() {
  local pid=$1
  local label=$2

  if wait_for_stop "${pid}"; then
    wait "${pid}" 2>/dev/null || true
    return 0
  fi

  kill -TERM "${pid}" 2>/dev/null || true
  if wait_for_stop "${pid}"; then
    wait "${pid}" 2>/dev/null || true
    return 0
  fi

  kill -KILL "${pid}" 2>/dev/null || true
  if wait_for_stop "${pid}"; then
    wait "${pid}" 2>/dev/null || true
    return 0
  fi

  printf 'Aviso: %s %s não encerrou após SIGKILL; não aguardando indefinidamente.\n' \
    "${label}" "${pid}" >&2
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
  exit_code=$?
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
  printf 'ISO=%s\n' "${ISO_PATH}"
  printf 'ISO_SHA512=%s\n' "${ISO_SHA512_BEFORE}"
  printf 'STARTED_AT_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'ACCELERATOR=%s\n' "${accel_name}"
  printf 'MEMORY_MB=%s\n' "${MEMORY_MB}"
  printf 'VCPUS=%s\n' "${VCPUS}"
  printf 'TTY_VALIDATION=bidirectional-serial-command\n'
  printf 'QEMU_SANDBOX=enabled\n'
  printf 'QEMU_VERSION=%s\n' "$(qemu-system-x86_64 --version | sed -n '1p')"
} >"${EVIDENCE_DIR}/metadata.txt"

validate_probe_line() {
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
    'ttyS0=active' \
    'identity=ok' \
    'live_user=ok' \
    'graphics=absent' \
    'graphical_target=inactive' \
    'cmdline=ok' \
    'failures=none'; do
    [[ " ${line} " == *" ${token} "* ]] || {
      printf 'Probe %s sem token obrigatório: %s\n' "${mode}" "${token}" >&2
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
  local elapsed next_enter probe_line tty_nonce tty_expected tty_frame guest_command
  local tty_attempt
  local -a firmware_args=()

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

  printf 'Testando %s com %s...\n' "${mode^^}" "${accel_name}"
  qemu-system-x86_64 \
    -name "flavos-m0-${mode}" \
    -machine q35 \
    -no-user-config \
    "${accel_args[@]}" \
    -m "${MEMORY_MB}" \
    -smp "${VCPUS}" \
    -boot once=d,menu=off \
    -drive "file=${ISO_PATH},media=cdrom,format=raw,readonly=on" \
    -nic none \
    -device virtio-rng-pci \
    -display none \
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny \
    -chardev "pipe,id=m0serial,path=${serial_prefix}" \
    -serial chardev:m0serial \
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
      printf 'QEMU %s encerrou antes da confirmação do boot.\n' "${mode}" >&2
      print_log_tail_escaped "${qemu_log}" 80 >&2 || true
      return 1
    fi

    if [[ -f "${serial_log}" ]]; then
      if grep -Fq 'FLAVOS_M0_PROBE result=FAIL' "${serial_log}"; then
        print_log_tail_escaped "${serial_log}" 20 >&2 || true
        return 1
      fi

      probe_line="$(grep -F 'FLAVOS_M0_PROBE result=PASS' "${serial_log}" | tail -n 1 | tr -d '\r' || true)"
      if [[ -n "${probe_line}" ]]; then
        validate_probe_line "${mode}" "${probe_line}"
        printf '%s\n' "${probe_line}" >"${EVIDENCE_DIR}/probe-${mode}.txt"

        tty_nonce="${SHORT_SHA}_${mode}_$$_${elapsed}"
        tty_expected="FLAVOS_M0_TTY nonce=${tty_nonce} user=flavos pid1=systemd"
        tty_frame=$'\036'"${tty_expected}"$'\037'
        guest_command="printf '\\036%s%s nonce=${tty_nonce} user=%s pid1=%s\\037\\n' 'FLAVOS_M0_' 'TTY' \"\$(id -un)\" \"\$(cat /proc/1/comm)\""

        for ((tty_attempt = 1; tty_attempt <= 8; tty_attempt++)); do
          printf '\r%s\r' "${guest_command}" >&"${serial_fd}"
          sleep 1
          if LC_ALL=C grep -aFq -- "${tty_frame}" "${serial_log}"; then
            break
          fi
        done

        if ! LC_ALL=C grep -aFq -- "${tty_frame}" "${serial_log}"; then
          printf 'O TTY %s não executou o desafio enviado pela serial.\n' \
            "${mode}" >&2
          print_log_tail_escaped "${serial_log}" 120 >&2 || true
          return 1
        fi

        printf '%s\n' "${tty_expected}" >"${EVIDENCE_DIR}/tty-${mode}.txt"
        printf '%s=PASS\n' "${mode^^}" >>"${EVIDENCE_DIR}/results.txt"
        printf '%s aprovado: kernel, systemd, TTY bidirecional e identidade confirmados.\n' \
          "${mode^^}"
        stop_active_vm
        return 0
      fi
    fi

    if ((elapsed >= next_enter && next_enter <= 21)); then
      printf 'sendkey ret\n' >&"${monitor_fd}" || true
      next_enter=$((next_enter + 2))
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  printf 'Timeout de %ss esperando o probe no modo %s.\n' \
    "${TIMEOUT_SECONDS}" "${mode}" >&2
  print_log_tail_escaped "${serial_log}" 120 >&2 || true
  print_log_tail_escaped "${qemu_log}" 80 >&2 || true
  return 1
}

for mode in "${modes[@]}"; do
  run_mode "${mode}"
done

iso_sha512_after="$(sha512sum -- "${ISO_PATH}" | awk '{print $1}')"
[[ "${iso_sha512_after}" == "${ISO_SHA512_BEFORE}" ]] || \
  fail 'a ISO foi alterada durante os testes de boot'

{
  printf 'FINISHED_AT_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'ISO_SHA512_AFTER=%s\n' "${iso_sha512_after}"
} >>"${EVIDENCE_DIR}/metadata.txt"

printf 'Testes de boot M0 concluídos com sucesso.\n'
printf 'Evidências: %s\n' "${EVIDENCE_DIR}"
