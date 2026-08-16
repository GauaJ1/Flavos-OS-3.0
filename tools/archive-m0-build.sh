#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly IMAGE_DIR="${REPO_ROOT}/image"
readonly ISO_PATH="${FLAVOS_M0_ISO:-${IMAGE_DIR}/flavos-3.0-m0-amd64.hybrid.iso}"
readonly BUILD_LOG="${IMAGE_DIR}/build.log"
readonly ARCHIVE_ROOT="${FLAVOS_M0_ARCHIVE_ROOT:-${REPO_ROOT}/releases/local/m0}"
readonly ARCHIVE_MARKER="${IMAGE_DIR}/.m0-last-archive"

for command_name in git sha512sum mktemp; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Erro: %s não está disponível.\n' "${command_name}" >&2
    exit 1
  fi
done

[[ -f "${ISO_PATH}" ]] || {
  printf 'Erro: ISO M0 não encontrada em %s\n' "${ISO_PATH}" >&2
  exit 1
}
[[ -f "${BUILD_LOG}" ]] || {
  printf 'Erro: log do build não encontrado em %s\n' "${BUILD_LOG}" >&2
  exit 1
}

shopt -s nullglob
manifest_candidates=(
  "${IMAGE_DIR}"/*.packages
  "${IMAGE_DIR}"/*.packages.*
  "${IMAGE_DIR}"/*.files
  "${IMAGE_DIR}"/*.contents
)
shopt -u nullglob

if ((${#manifest_candidates[@]} == 0)); then
  printf 'Erro: nenhum manifesto produzido pelo live-build foi encontrado.\n' >&2
  exit 1
fi

build_commit="$(sed -n 's/^FLAVOS_BUILD_COMMIT=//p' "${BUILD_LOG}" | sed -n '1p')"
build_dirty="$(sed -n 's/^FLAVOS_BUILD_DIRTY=//p' "${BUILD_LOG}" | sed -n '1p')"
source_date_epoch="$(sed -n 's/^SOURCE_DATE_EPOCH=//p' "${BUILD_LOG}" | sed -n '1p')"

if [[ ! "${build_commit}" =~ ^[0-9a-f]{40,64}$ ]] || \
  ! git -C "${REPO_ROOT}" cat-file -e "${build_commit}^{commit}"; then
  printf 'Erro: o log não contém um commit de build válido.\n' >&2
  exit 1
fi

short_commit="${build_commit:0:12}"
archive_parent="${ARCHIVE_ROOT}/${short_commit}"
archive_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p -- "${archive_parent}"
archive_dir="$(mktemp -d "${archive_parent}/${archive_timestamp}-XXXXXX")"

cp -- "${ISO_PATH}" "${BUILD_LOG}" "${manifest_candidates[@]}" "${archive_dir}/"

iso_name="$(basename -- "${ISO_PATH}")"
iso_sha512="$(sha512sum -- "${archive_dir}/${iso_name}" | awk '{print $1}')"

(
  cd "${archive_dir}"
  sha512sum -- "${iso_name}" >SHA512SUMS
)

{
  printf 'BUILD_COMMIT=%s\n' "${build_commit}"
  printf 'BUILD_DIRTY=%s\n' "${build_dirty:-desconhecido}"
  printf 'SOURCE_DATE_EPOCH=%s\n' "${source_date_epoch:-desconhecido}"
  printf 'ARCHIVED_AT_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'ISO_FILE=%s\n' "${iso_name}"
  printf 'ISO_SHA512=%s\n' "${iso_sha512}"
} >"${archive_dir}/metadata.txt"

{
  printf 'live-build: '
  lb --version 2>/dev/null || printf 'indisponível\n'
  qemu-system-x86_64 --version 2>/dev/null | sed -n '1p' || true
  xorriso -version 2>/dev/null | sed -n '1p' || true
  mksquashfs -version 2>/dev/null | sed -n '1p' || true
} >"${archive_dir}/tool-versions.txt"

{
  printf 'ISO_SHA512=%s\n' "${iso_sha512}"
  printf 'ARCHIVE_DIR=%s\n' "${archive_dir}"
  printf 'BUILD_COMMIT=%s\n' "${build_commit}"
} >"${ARCHIVE_MARKER}"

printf 'Build M0 preservado em: %s\n' "${archive_dir}"
printf 'SHA-512: %s\n' "${iso_sha512}"
