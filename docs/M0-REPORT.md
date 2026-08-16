# Flavos OS 3.0 — Relatório de encerramento do M0

> **Resultado:** PASS<br>
> **Data:** 16 de agosto de 2026<br>
> **Commit construído e testado:** `fedc240969fe1a1bba8d694159fb657802bf4b9f`<br>
> **Escopo:** ISO → kernel Linux → systemd → TTY

## Gate cumprido

O M0 foi encerrado após duas construções limpas e independentes da imagem,
seguidas de validação estrutural e boot da ISO de cada passagem em BIOS e UEFI.
Nos quatro boots, o sistema chegou ao mesmo estado mínimo, aceitou um comando
enviado pelo TTY serial e devolveu a resposta esperada.

O resultado não contém desktop, display manager, compositor, instalador ou
política para firmware físico. Secure Boot e Debian Installer permaneceram fora
do escopo. O encerramento deste gate não inicia o M1.

## Proveniência das construções

As duas passagens usaram:

- VM `Debian GNU/Linux 13 (trixie)` amd64, kernel
  `6.12.101+deb13-amd64`;
- worktree limpo (`BUILD_DIRTY=0`);
- commit `fedc240969fe1a1bba8d694159fb657802bf4b9f`;
- `SOURCE_DATE_EPOCH=1786916771`;
- `live-build 20250505+deb13u1`;
- `xorriso 1.5.6` e `mksquashfs 4.6.1`;
- QEMU `10.0.11` no ambiente de build.

| Evidência | Passagem 1 | Passagem 2 |
|---|---|---|
| Início UTC | 2026-08-16 21:47:37 | 2026-08-16 21:53:45 |
| Arquivamento UTC | 2026-08-16 21:53:05 | 2026-08-16 22:00:24 |
| Arquivo original na VM | `fedc240969fe/20260816T215304Z-JQm6eV/` | `fedc240969fe/20260816T220023Z-MQUNwq/` |
| Cópia local ignorada pelo Git | `releases/local/m0/pass1-fedc240969fe/` | `releases/local/m0/pass2-fedc240969fe/` |
| Build concluído | PASS | PASS |
| `sha512sum -c SHA512SUMS` | PASS | PASS |
| `validate-m0-iso.sh` | PASS | PASS |

Os arquivos locais de evidência são deliberadamente ignorados pelo Git; a tabela
registra seus identificadores para auditoria no laboratório em que o M0 foi
executado.

## Artefatos

As duas ISOs têm `341835776` bytes e o nome
`flavos-3.0-m0-amd64.hybrid.iso`.

| Passagem | SHA-512 da ISO |
|---|---|
| 1 | `b027fdcac6e2346e1fe9209953c026f5e94a4a5b82cff235843187e35a7786f92dafc3172eabc7a722646e82838a218576f70669042eb5675c3c3ceb2e22dd38` |
| 2 | `363870614f27b7d48fd246755c851910b756b6124c936205b069f63b9a72519248aec37c6f88dc9c1f3b107c13a968d0ddec567b7e65d74423c857ee0ac6f4ad` |

Em ambas, a validação confirmou:

- volume `FLAVOS_3_0_M0`;
- entrada El Torito BIOS e entrada El Torito UEFI;
- área de sistema MBR isohybrid;
- Syslinux, imagem EFI, kernel, initrd e squashfs;
- manifesto `/live/filesystem.packages` idêntico ao manifesto externo;
- pacotes mínimos obrigatórios presentes e stack gráfica ausente.

## Manifestos e reprodutibilidade

O contrato funcional do M0 foi reproduzido, mas as ISOs não são byte a byte
idênticas.

| Evidência | Passagem 1 | Passagem 2 | Comparação |
|---|---|---|---|
| Pacotes | 178 linhas | 178 linhas | idênticos |
| SHA-512 de `.packages` | `b503958f1999a429945d3bd7613d1fb52923b5f9633a546fa8e738c107c77172940e5ab02ee057643d9e87e4e5692179aa4a887bc301c37ab6f745f19d1fbf6e` | mesmo hash | idênticos |
| Conteúdo por pacote | 303 linhas | 303 linhas | idêntico |
| SHA-512 de `.contents` | `f354a023855d972cc6669558e73833860dcad924febd04e496ca1532ef91ac44692a88b56b21c7295b31f35338ff55803f8e630f8a0fb1586fe259ee8575a92b` | mesmo hash | idênticos |
| Listagem `.files` | 22793 linhas | 22793 linhas | metadados de tempo diferentes |
| SHA-512 de `.files` | `aca7faafcc056cbe37f770d56a5d9dc32e2d9c83f03ea0d3ed098d8e2e05df198ccecb159a2bfebeecb4374e654ceb103aff8d6318ac20daa4c8e279c014a809` | `1dc1c576fb607e1a10adf02f5af46011be12da2f738edc2340af852d90b4057af96ce9e3366944765583108373d5e38b71dfc740798fa879e2730c669f2d7050` | diferentes |

A investigação binária localizou toda a divergência em
`/live/filesystem.squashfs` e, por consequência, na linha correspondente de
`/sha256sum.txt`; kernel, initrd, bootloaders, catálogo El Torito e os demais
arquivos da ISO são byte-idênticos. Dentro do squashfs, somente três arquivos
regulares mudaram: dois caches binários do APT e o `InRelease` de
`trixie-updates`. O espelho renovou a data, validade e assinatura do `InRelease`
entre as passagens, sem alterar os índices de pacotes. Nos caches, a única
diferença lógica é o horário da pseudo-origem `now`.

O squashfs ocupa `280408064` bytes nas duas ISOs. Seu SHA-256 é
`0e56a39407c651113861e481f7371c2da0bfb623aa95e765efb6bfdd7eebfaa8` na
passagem 1 e `1578b4cdf9c180f8d54a63b23b6dcbbae574beccee01df1d3467350b152a58b8`
na passagem 2. Os parâmetros de compressão, as contagens estruturais e o
`mkfs_time` são iguais; `bytes_used` e offsets internos mudam com o conteúdo
comprimido.

O `SOURCE_DATE_EPOCH` foi respeitado pelo `xorriso`, mas não fixa metadados de um
repositório móvel nem normaliza esses caches do APT. Essa é a causa registrada
para o hash diferente; a seleção e as versões dos pacotes não mudaram.

Pelo critério definido para o M0, as duas passagens são equivalentes: partiram da
mesma revisão limpa, preservaram a mesma seleção e versões de pacotes e passaram
nos mesmos boots. Reprodutibilidade byte a byte exigirá normalização adicional e
uma decisão futura sobre snapshots/pinning dos repositórios; ela não é alegada
neste relatório.

## Aceitação de boot

Os testes foram executados no host Linux Mint 22.3, kernel
`6.14.0-37-generic`, com QEMU `8.2.2`, KVM, 1536 MiB, 2 vCPUs, ISO somente
leitura, rede desabilitada e sandbox do QEMU ativado.

| Passagem | Evidência local | BIOS | UEFI | Intervalo UTC |
|---|---|---|---|---|
| 1 | `releases/local/m0/boot-tests/b027fdcac6e2/20260816T220136Z-K8GVum/` | PASS | PASS | 22:01:36–22:02:04 |
| 2 | `releases/local/m0/boot-tests/363870614f27/20260816T220213Z-M2AwkN/` | PASS | PASS | 22:02:13–22:02:39 |

Cada probe confirmou:

```text
kernel=6.12.101+deb13-amd64
pid1=systemd
arch=x86_64
hostname=flavos
multi_user=active
tty1=active
ttyS0=active
identity=ok
live_user=ok
graphics=absent
graphical_target=inactive
cmdline=ok
failures=none
```

Os desafios TTY normalizados foram:

```text
FLAVOS_M0_TTY nonce=b027fdcac6e2_bios_106368_11 user=flavos pid1=systemd
FLAVOS_M0_TTY nonce=b027fdcac6e2_uefi_106368_14 user=flavos pid1=systemd
FLAVOS_M0_TTY nonce=363870614f27_bios_106697_11 user=flavos pid1=systemd
FLAVOS_M0_TTY nonce=363870614f27_uefi_106697_13 user=flavos pid1=systemd
```

O harness enquadra a resposta com bytes RS/US para distingui-la do eco do
comando. A revisão testada do harness é o próprio commit do build; o SHA-512 de
`tools/test-m0-boot.sh` é
`b267861f82bb1f57d393e95fa9f60a7ccdfeb02650a5d277aae6dbc9522ecd59f6810245e5994bda8da72c5adb58a6d2ef25cd2dd63e4159abca3d9e4cfabd74`.

## UEFI e limites do laboratório

O teste UEFI usou OVMF `2024.02-2ubuntu0.9` com uma cópia nova do template VARS
em cada execução:

- `OVMF_CODE_4M.fd` SHA-512:
  `544f03ea886ea0919f6d149901795255b60213074e805e5de2aab80e97d0a96eeaf964f7c361e129f7dd52462043f554339d0eedc6b14cdee4ea635fef681a77`;
- `OVMF_VARS_4M.fd` SHA-512:
  `448412fd7ba267b4180db8ade6edb67af467e5b9b3e3ff8dfd583a2fded4070f6951667297e6896ce8bd9f4d2ec3dd8a5a70b6e9a2f686efec9a57124fec512a`.

O console serial, o probe `flavos.m0.probe=1` e o autologin de `flavos` em
`ttyS0` são instrumentação exclusiva desta imagem técnica. Eles comprovam o TTY,
mas não estabelecem uma política de autenticação para o produto.

## Conclusão

O gate estabelecido para **M0 — Bootstrap** foi cumprido. A fundação gera uma ISO
híbrida Debian Trixie amd64 que inicializa por BIOS e UEFI até kernel, systemd e
TTY, de forma funcionalmente repetível nas duas passagens registradas.

**M0 concluído. M1 não iniciado.**
