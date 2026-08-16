#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly EXPECTED_SHA512="ce0eeee7b51fdcdbed1e5116668c1fee27e528767bdf488e5f115a67b225e5dfd0afca1d456aaa9408ceb6b8527521ff7b6b5d62fdbe6f8c5faaf8df56a96292"

iso_path="${1:-${FLAVOS_DEBIAN_ISO:-${REPO_ROOT}/image/debian-13.6.0-amd64-netinst.iso}}"

if ! command -v sha512sum >/dev/null 2>&1; then
  printf 'Erro: sha512sum não está disponível.\n' >&2
  exit 1
fi

if [[ ! -f "${iso_path}" ]]; then
  printf 'Erro: ISO não encontrada em %s\n' "${iso_path}" >&2
  exit 1
fi

printf 'Verificando %s...\n' "${iso_path}"
actual_sha512="$(sha512sum -- "${iso_path}" | awk '{print $1}')"

if [[ "${actual_sha512}" != "${EXPECTED_SHA512}" ]]; then
  printf 'Erro: checksum SHA-512 inválido.\n' >&2
  printf 'Esperado: %s\n' "${EXPECTED_SHA512}" >&2
  printf 'Obtido:   %s\n' "${actual_sha512}" >&2
  exit 1
fi

printf 'ISO Debian 13.6.0 amd64 netinst verificada com sucesso.\n'
