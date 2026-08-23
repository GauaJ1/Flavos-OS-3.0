#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly M0_COMMIT='fedc240969fe1a1bba8d694159fb657802bf4b9f'

fail() {
  printf 'FALHOU: %s\n' "$*" >&2
  exit 1
}

for command_name in git mkdir mktemp rm tar; do
  command -v "${command_name}" >/dev/null 2>&1 || \
    fail "${command_name} não está instalado"
done

# Este validador é deliberadamente histórico. A árvore ativa evoluiu para M1.1,
# portanto não deve ser apresentada como se ainda satisfizesse o contrato M0.
# Extraímos a revisão efetivamente construída e aprovada no M0 e executamos o
# validador que pertence àquela própria revisão, sem incorporar arquivos atuais.
git -C "${REPO_ROOT}" cat-file -e "${M0_COMMIT}^{commit}" 2>/dev/null || \
  fail "commit histórico do M0 não está disponível: ${M0_COMMIT}"

readonly TEMP_DIR="$(mktemp -d)"
readonly ARCHIVE_PATH="${TEMP_DIR}/m0.tar"
readonly HISTORICAL_TREE="${TEMP_DIR}/tree"
trap 'rm -rf -- "${TEMP_DIR}"' EXIT

mkdir -m 0700 -- "${HISTORICAL_TREE}"
git -C "${REPO_ROOT}" archive \
  --format=tar \
  --output="${ARCHIVE_PATH}" \
  "${M0_COMMIT}" || fail 'não foi possível arquivar a revisão histórica do M0'
tar -xf "${ARCHIVE_PATH}" -C "${HISTORICAL_TREE}" || \
  fail 'não foi possível extrair a revisão histórica do M0'

historical_validator="${HISTORICAL_TREE}/tests/validate-m0-config.sh"
[[ -x "${historical_validator}" ]] || \
  fail 'validador histórico do M0 está ausente ou não executável no commit aprovado'

(
  cd -- "${HISTORICAL_TREE}"
  exec ./tests/validate-m0-config.sh
) || fail "invariantes do M0 falharam no commit aprovado ${M0_COMMIT}"

printf 'Guarda histórica do M0 validada no commit %s.\n' "${M0_COMMIT}"
printf 'A árvore ativa M1.1 não foi tratada como uma configuração M0.\n'
