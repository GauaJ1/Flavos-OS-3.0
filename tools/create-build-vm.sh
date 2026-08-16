#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

readonly VM_DIR="${FLAVOS_VM_DIR:-${REPO_ROOT}/image/.vm/flavos-build-trixie}"
readonly VM_DISK="${VM_DIR}/system.qcow2"
readonly VM_VARS="${VM_DIR}/OVMF_VARS_4M.fd"
readonly DISK_SIZE="${FLAVOS_VM_DISK_SIZE:-40G}"
readonly OVMF_VARS_TEMPLATE="${FLAVOS_OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}"

if ! command -v qemu-img >/dev/null 2>&1; then
  printf 'Erro: qemu-img não está instalado.\n' >&2
  exit 1
fi

if [[ ! -f "${OVMF_VARS_TEMPLATE}" ]]; then
  printf 'Erro: template OVMF VARS não encontrado em %s\n' "${OVMF_VARS_TEMPLATE}" >&2
  exit 1
fi

if [[ ! "${DISK_SIZE}" =~ ^[1-9][0-9]*[GgMm]$ ]]; then
  printf 'Erro: FLAVOS_VM_DISK_SIZE deve usar o formato 40G ou 40960M.\n' >&2
  exit 1
fi

if [[ -L "${VM_DIR}" ]]; then
  printf 'Erro: o diretório da VM não pode ser um link simbólico: %s\n' \
    "${VM_DIR}" >&2
  exit 1
fi

mkdir -p -- "${VM_DIR}"
chmod 0700 -- "${VM_DIR}"

if [[ -e "${VM_DISK}" ]]; then
  if [[ -L "${VM_DISK}" || ! -f "${VM_DISK}" ]]; then
    printf 'Erro: %s deve ser um arquivo regular, nunca um link.\n' \
      "${VM_DISK}" >&2
    exit 1
  fi

  chmod 0600 -- "${VM_DISK}"
  printf 'Reutilizando disco existente: %s\n' "${VM_DISK}"
  qemu-img info -- "${VM_DISK}"
  qemu-img check -q -- "${VM_DISK}"
else
  printf 'Criando disco QCOW2 esparso de %s...\n' "${DISK_SIZE}"
  qemu-img create -f qcow2 -o lazy_refcounts=on "${VM_DISK}" "${DISK_SIZE}"
  chmod 0600 -- "${VM_DISK}"
fi

if [[ -e "${VM_VARS}" ]]; then
  if [[ -L "${VM_VARS}" || ! -f "${VM_VARS}" ]]; then
    printf 'Erro: %s deve ser um arquivo regular, nunca um link.\n' \
      "${VM_VARS}" >&2
    exit 1
  fi
  chmod 0600 -- "${VM_VARS}"
  printf 'Reutilizando estado UEFI existente: %s\n' "${VM_VARS}"
else
  install -m 0600 -- "${OVMF_VARS_TEMPLATE}" "${VM_VARS}"
  printf 'Estado UEFI criado em: %s\n' "${VM_VARS}"
fi

printf 'VM flavos-build-trixie preparada com sucesso.\n'
