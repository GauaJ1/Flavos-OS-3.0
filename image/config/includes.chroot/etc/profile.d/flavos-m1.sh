# Instrumentação da ISO técnica M1.1. Fora do modo probe, o usuário permanece no
# TTY e pode iniciar manualmente `flavos-m1-session`.
case $- in
  *i*) ;;
  *) return ;;
esac

if [ "$(id -un 2>/dev/null || true)" = flavos ] && \
  [ "$(tty 2>/dev/null || true)" = /dev/tty1 ] && \
  grep -Fqw 'flavos.m1.probe=1' /proc/cmdline 2>/dev/null && \
  [ -e /sys/firmware/qemu_fw_cfg/by_name/opt/flavos.m1.graphical_nonce/raw ] && \
  [ -e /sys/firmware/qemu_fw_cfg/by_name/opt/flavos.m1.tty_nonce/raw ] && \
  [ "${FLAVOS_M1_SESSION_STARTED:-0}" != 1 ]; then
  export FLAVOS_M1_SESSION_STARTED=1
  exec /usr/local/bin/flavos-m1-session
fi
