#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

readonly MODE="${1:-install}"
readonly VM_DIR="${FLAVOS_VM_DIR:-${REPO_ROOT}/image/.vm/flavos-build-trixie}"
readonly VM_DISK="${VM_DIR}/system.qcow2"
readonly VM_VARS="${VM_DIR}/OVMF_VARS_4M.fd"
readonly ISO_PATH="${FLAVOS_DEBIAN_ISO:-${REPO_ROOT}/image/debian-13.6.0-amd64-netinst.iso}"
readonly OVMF_CODE="${FLAVOS_OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}"
readonly MEMORY_MB="${FLAVOS_VM_MEMORY_MB:-4096}"
readonly VCPUS="${FLAVOS_VM_CPUS:-4}"
readonly SSH_PORT="${FLAVOS_VM_SSH_PORT:-2222}"
readonly DISPLAY_MODE="${FLAVOS_VM_DISPLAY:-gtk}"

case "${MODE}" in
  install | boot) ;;
  *)
    printf 'Uso: %s [install|boot]\n' "$0" >&2
    exit 2
    ;;
esac

for command_name in qemu-system-x86_64 qemu-img; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Erro: %s não está instalado.\n' "${command_name}" >&2
    exit 1
  fi
done

if [[ ! "${MEMORY_MB}" =~ ^[1-9][0-9]*$ ]] || [[ ! "${VCPUS}" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Erro: memória e número de CPUs devem ser inteiros positivos.\n' >&2
  exit 1
fi

if [[ ! "${SSH_PORT}" =~ ^[1-9][0-9]*$ ]] || ((SSH_PORT > 65535)); then
  printf 'Erro: FLAVOS_VM_SSH_PORT deve ser uma porta TCP válida.\n' >&2
  exit 1
fi

if [[ ! -f "${OVMF_CODE}" ]]; then
  printf 'Erro: firmware OVMF não encontrado em %s\n' "${OVMF_CODE}" >&2
  exit 1
fi

if [[ "${MODE}" == "install" ]]; then
  "${SCRIPT_DIR}/verify-debian-iso.sh" "${ISO_PATH}"
  "${SCRIPT_DIR}/create-build-vm.sh"
elif [[ ! -f "${VM_DISK}" || ! -f "${VM_VARS}" ]]; then
  printf 'Erro: a VM ainda não existe. Execute %s install primeiro.\n' "$0" >&2
  exit 1
fi

qemu-img check -q -- "${VM_DISK}"

if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  accel_args=(-accel kvm -cpu host)
  printf 'Aceleração: KVM.\n'
else
  accel_args=(-accel tcg,thread=multi -cpu max)
  printf 'Aviso: /dev/kvm não está acessível; usando TCG, que é muito mais lento.\n' >&2
fi

case "${DISPLAY_MODE}" in
  gtk)
    if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
      printf 'Erro: sessão gráfica indisponível. Use FLAVOS_VM_DISPLAY=vnc.\n' >&2
      exit 1
    fi
    display_args=(-display gtk,gl=off)
    ;;
  vnc)
    display_args=(-display vnc=127.0.0.1:1)
    printf 'Display VNC: vnc://127.0.0.1:5901\n'
    ;;
  *)
    printf 'Erro: FLAVOS_VM_DISPLAY deve ser gtk ou vnc.\n' >&2
    exit 2
    ;;
esac

media_args=()
if [[ "${MODE}" == "install" ]]; then
  media_args=(
    -drive "file=${ISO_PATH},media=cdrom,format=raw,readonly=on"
    -boot once=d,menu=on
  )
else
  media_args=(-boot order=c,menu=on)
fi

printf 'Iniciando flavos-build-trixie em modo %s com %s MiB e %s vCPUs.\n' \
  "${MODE}" "${MEMORY_MB}" "${VCPUS}"
printf 'SSH após a instalação: ssh -p %s <usuario>@127.0.0.1\n' "${SSH_PORT}"

exec qemu-system-x86_64 \
  -name flavos-build-trixie \
  -machine q35 \
  "${accel_args[@]}" \
  -smp "${VCPUS}" \
  -m "${MEMORY_MB}" \
  -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}" \
  -drive "if=pflash,format=raw,file=${VM_VARS}" \
  -drive "file=${VM_DISK},if=virtio,format=qcow2,discard=unmap" \
  "${media_args[@]}" \
  -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci \
  -rtc base=utc \
  "${display_args[@]}"
