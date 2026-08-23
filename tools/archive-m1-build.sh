#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly IMAGE_DIR="${REPO_ROOT}/image"
readonly ARTIFACT_BASE='flavos-3.0-m1.1-amd64'
readonly ISO_PATH="${IMAGE_DIR}/${ARTIFACT_BASE}.hybrid.iso"
readonly PACKAGE_MANIFEST="${IMAGE_DIR}/${ARTIFACT_BASE}.packages"
readonly BUILD_LOG="${IMAGE_DIR}/build.log"
readonly VALIDATOR="${REPO_ROOT}/tests/validate-m1-iso.sh"
readonly ARCHIVE_MARKER="${IMAGE_DIR}/.m1-last-archive"

archive_root_input="${FLAVOS_M1_ARCHIVE_ROOT:-${REPO_ROOT}/releases/local/m1.1}"
if [[ "${archive_root_input}" == /* ]]; then
  archive_root_path="${archive_root_input}"
else
  archive_root_path="${REPO_ROOT}/${archive_root_input}"
fi

readonly -a REQUIRED_ARTIFACTS=(
  "${ISO_PATH}"
  "${BUILD_LOG}"
  "${IMAGE_DIR}/chroot.files"
  "${IMAGE_DIR}/chroot.packages.install"
  "${IMAGE_DIR}/chroot.packages.live"
  "${IMAGE_DIR}/${ARTIFACT_BASE}.contents"
  "${IMAGE_DIR}/${ARTIFACT_BASE}.files"
  "${PACKAGE_MANIFEST}"
)

fail() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

read_log_value() {
  local key=$1
  local -a values=()

  mapfile -t values < <(sed -n "s/^${key}=//p" "${BUILD_LOG}")
  ((${#values[@]} == 1)) || \
    fail "build.log deve conter exatamente um campo ${key}"
  printf '%s' "${values[0]}"
}

for command_name in \
  awk basename cmp cp date git grep mkdir mktemp mv rm sed sha512sum; do
  command -v "${command_name}" >/dev/null 2>&1 || \
    fail "${command_name} não está disponível"
done

[[ -x "${VALIDATOR}" ]] || fail "validador M1.1 ausente: ${VALIDATOR}"
[[ -n "${archive_root_path}" && "${archive_root_path}" != / ]] || \
  fail 'FLAVOS_M1_ARCHIVE_ROOT é inválido'

for artifact_path in "${REQUIRED_ARTIFACTS[@]}"; do
  [[ -f "${artifact_path}" ]] || \
    fail "artefato obrigatório M1.1 ausente: ${artifact_path}"
done

grep -Fxq 'P: Build completed successfully' "${BUILD_LOG}" || \
  fail 'o log não registra um build M1.1 concluído com sucesso'

build_commit="$(read_log_value FLAVOS_BUILD_COMMIT)"
build_dirty="$(read_log_value FLAVOS_BUILD_DIRTY)"
source_date_epoch="$(read_log_value SOURCE_DATE_EPOCH)"
build_started="$(read_log_value BUILD_STARTED_UTC)"
build_finished="$(read_log_value BUILD_FINISHED_UTC)"

[[ "${build_commit}" =~ ^[0-9a-f]{40,64}$ ]] || \
  fail 'o log não contém um commit de build válido'
git -c safe.directory="${REPO_ROOT}" -C "${REPO_ROOT}" \
  cat-file -e "${build_commit}^{commit}" || \
  fail 'o commit registrado no build.log não existe neste repositório'
current_head="$(git -c safe.directory="${REPO_ROOT}" -C "${REPO_ROOT}" rev-parse HEAD)"
[[ "${current_head}" == "${build_commit}" ]] || \
  fail 'o checkout atual não corresponde ao commit que produziu o build'
current_status="$(
  git -c safe.directory="${REPO_ROOT}" -C "${REPO_ROOT}" \
    status --porcelain --untracked-files=normal
)"
[[ -z "${current_status}" ]] || \
  fail 'o arquivamento oficial exige o mesmo worktree limpo usado no build'
[[ "${build_dirty}" == 0 ]] || \
  fail 'somente builds com FLAVOS_BUILD_DIRTY=0 podem ser arquivados oficialmente'
[[ "${source_date_epoch}" =~ ^[0-9]+$ ]] || \
  fail 'SOURCE_DATE_EPOCH inválido no build.log'

for marker in \
  BUILD_ENVIRONMENT_BEGIN BUILD_ENVIRONMENT_END \
  LIVE_BUILD_EFFECTIVE_CONFIG_BEGIN LIVE_BUILD_EFFECTIVE_CONFIG_END \
  LIVE_BUILD_CONFIG_SHA512_BEGIN LIVE_BUILD_CONFIG_SHA512_END \
  LIVE_BUILD_GENERATED_INPUTS_BEGIN LIVE_BUILD_GENERATED_INPUTS_END; do
  [[ "$(grep -Fxc "${marker}" "${BUILD_LOG}")" == 1 ]] || \
    fail "marcador de proveniência ausente ou duplicado no build.log: ${marker}"
done

effective_config="$({
  awk '
    /^LIVE_BUILD_EFFECTIVE_CONFIG_BEGIN$/ { capture = 1; next }
    /^LIVE_BUILD_EFFECTIVE_CONFIG_END$/ { capture = 0 }
    capture { print }
  ' "${BUILD_LOG}"
})"

for expected_line in \
  'LB_MODE=debian' \
  'LB_DISTRIBUTION=trixie' \
  'LB_ARCHITECTURE=amd64' \
  'LB_IMAGE_TYPE=iso-hybrid' \
  'LB_IMAGE_NAME=flavos-3.0-m1.1' \
  'LB_ISO_VOLUME=FLAVOS_3_0_M1_1' \
  'LB_DEBIAN_INSTALLER=none' \
  'LB_UEFI_SECURE_BOOT=disable'; do
  grep -Fxq "${expected_line}" <<<"${effective_config}" || \
    fail "configuração efetiva obrigatória ausente do build.log: ${expected_line}"
done

logged_config_checksums="$({
  awk '
    /^LIVE_BUILD_CONFIG_SHA512_BEGIN$/ { capture = 1; next }
    /^LIVE_BUILD_CONFIG_SHA512_END$/ { capture = 0 }
    capture { print }
  ' "${BUILD_LOG}"
})"

current_config_checksums="$({
  cd "${IMAGE_DIR}"
  sha512sum -- \
    config/common \
    config/bootstrap \
    config/chroot \
    config/binary \
    config/source
})"

[[ "${logged_config_checksums}" == "${current_config_checksums}" ]] || \
  fail 'a configuração efetiva mudou depois do build'

FLAVOS_M1_MANIFEST="${PACKAGE_MANIFEST}" \
  "${VALIDATOR}" "${ISO_PATH}"

source_iso_sha512="$(sha512sum -- "${ISO_PATH}" | awk '{print $1}')"
short_commit="${build_commit:0:12}"
archive_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p -- "${archive_root_path}"
readonly ARCHIVE_ROOT="$(cd -- "${archive_root_path}" && pwd -P)"
[[ "${ARCHIVE_ROOT}" != / ]] || \
  fail 'FLAVOS_M1_ARCHIVE_ROOT não pode resolver para a raiz do sistema'
case "${ARCHIVE_ROOT}/" in
  "${IMAGE_DIR}/"*)
    fail 'FLAVOS_M1_ARCHIVE_ROOT não pode ficar dentro de image/'
    ;;
esac
archive_parent="${ARCHIVE_ROOT}/${short_commit}"
mkdir -p -- "${archive_parent}"

partial_dir=
marker_tmp=

cleanup_partial() {
  local exit_code=$?
  set +e
  [[ -z "${marker_tmp}" || ! -e "${marker_tmp}" ]] || rm -f -- "${marker_tmp}"
  [[ -z "${partial_dir}" || ! -d "${partial_dir}" ]] || rm -rf -- "${partial_dir}"
  trap - EXIT
  exit "${exit_code}"
}
trap cleanup_partial EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

partial_dir="$(mktemp -d "${archive_parent}/.partial-${archive_timestamp}-XXXXXX")"
partial_name="$(basename -- "${partial_dir}")"
archive_name="${partial_name#.partial-}"
archive_dir="${archive_parent}/${archive_name}"
[[ ! -e "${archive_dir}" ]] || fail "destino de arquivo já existe: ${archive_dir}"

for artifact_path in "${REQUIRED_ARTIFACTS[@]}"; do
  cp -- "${artifact_path}" "${partial_dir}/"
done

for artifact_path in "${REQUIRED_ARTIFACTS[@]}"; do
  artifact_name="$(basename -- "${artifact_path}")"
  cmp -s -- "${artifact_path}" "${partial_dir}/${artifact_name}" || \
    fail "a cópia arquivada diverge da origem: ${artifact_name}"
done

iso_name="$(basename -- "${ISO_PATH}")"
copied_iso_sha512="$(sha512sum -- "${partial_dir}/${iso_name}" | awk '{print $1}')"
[[ "${copied_iso_sha512}" == "${source_iso_sha512}" ]] || \
  fail 'a ISO copiada falhou na validação SHA-512'

{
  printf 'MILESTONE=M1.1\n'
  printf 'BUILD_COMMIT=%s\n' "${build_commit}"
  printf 'BUILD_DIRTY=%s\n' "${build_dirty}"
  printf 'SOURCE_DATE_EPOCH=%s\n' "${source_date_epoch}"
  printf 'BUILD_STARTED_UTC=%s\n' "${build_started}"
  printf 'BUILD_FINISHED_UTC=%s\n' "${build_finished}"
  printf 'ARCHIVED_AT_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'ISO_FILE=%s\n' "${iso_name}"
  printf 'ISO_SHA512=%s\n' "${copied_iso_sha512}"
  printf 'VALIDATOR_COMMIT=%s\n' "${current_head}"
  printf 'VALIDATOR_SHA512=%s\n' "$(sha512sum -- "${VALIDATOR}" | awk '{print $1}')"
} >"${partial_dir}/metadata.txt"

sed -n \
  '/^BUILD_ENVIRONMENT_BEGIN$/,/^BUILD_ENVIRONMENT_END$/p' \
  "${BUILD_LOG}" >"${partial_dir}/tool-versions.txt"

checksum_names=()
for artifact_path in "${REQUIRED_ARTIFACTS[@]}"; do
  checksum_names+=("$(basename -- "${artifact_path}")")
done
checksum_names+=(metadata.txt tool-versions.txt)

(
  cd "${partial_dir}"
  sha512sum -- "${checksum_names[@]}" >SHA512SUMS
  sha512sum -c SHA512SUMS
)

mv -- "${partial_dir}" "${archive_dir}"
partial_dir=

marker_tmp="$(mktemp "${IMAGE_DIR}/.m1-last-archive.XXXXXX")"
{
  printf 'ISO_SHA512=%s\n' "${copied_iso_sha512}"
  printf 'ARCHIVE_DIR=%s\n' "${archive_dir}"
  printf 'BUILD_COMMIT=%s\n' "${build_commit}"
} >"${marker_tmp}"
mv -f -- "${marker_tmp}" "${ARCHIVE_MARKER}"
marker_tmp=

trap - EXIT
printf 'Build M1.1 preservado em: %s\n' "${archive_dir}"
printf 'SHA-512: %s\n' "${copied_iso_sha512}"
