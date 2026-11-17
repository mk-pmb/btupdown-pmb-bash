#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function syslog_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  set -o errexit -o pipefail
  trap 'echo T: "Failed at $BASH_SOURCE line $LINENO: $BASH_COMMAND" >&2' ERR
  local FLAGS=,
  local VAL=
  while [ "$#" -ge 1 ]; do
    VAL="$1"; shift
    case "$VAL" in
      -- ) break;;

      --gz | \
      --uts | \
      -- ) FLAGS+="${VAL#--},";;

      -* ) echo E: "Unsupported CLI option: $VAL" >&2; return 4;;
      * ) set -- "$VAL" "$@"; break;;
    esac
  done

  for VAL in "$@"; do
    [ -e "$VAL" ] || return 4$(
      echo E: "Input filename does not exist: $VAL" >&2)
  done

  local TAG='btupdown-pmb' SED=
  if [ "$#" == 0 ]; then
    cd -- /var/log
    set --
    for VAL in syslog{,.[0-9]*}; do
      [ -f "$VAL" ] || continue
      case "$VAL" in
        *.gz ) [[ "$FLAGS" == *,gz,* ]] || continue;;
      esac
      set -- "$VAL" "$@"
    done
  fi

  # First, start searching syslog:
  exec </dev/null
  exec < <(LANG=C exec zgrep -hFe " $TAG[" -- "$@")

  # Meanwhile, on FD 5 we start the device name alias pipeline because it
  # may take a while depending on how responsive the bluetooth daemon is.
  # (Our timeout command is there only to limit the worst case.)
  exec 5< <(exec timeout 1s bt-device --list 2>/dev/null)
  SED='s~\s~ ~g; s~ \(([0-9A-Fa-f:]+)\)$~\n\U\1\E~p'
  exec 5< <(LANG=C exec <&5 sed -nre "$SED")
  SED='s~[^A-Za-z0-9 :_-]~\\&~g'
  exec 5< <(LANG=C <&5 sed -re "$SED"; echo '\1'; echo '(\S+)')
  SED='N; s~^([^\n]+)\n(\S+)$~s|\v<device=\2\v>|\1|g~'
  exec 5< <(LANG=C exec <&5 sed -re "$SED")
  # <&5 nl -ba;   return 7

  SED='s~^([A-Z][a-z]{2} ² ²:²:² )\S+ '"$TAG"'\[[0-9]+\]: ~\1~p'
  SED="${SED//²/'[ 0-9][0-9]'}"
  exec < <(LANG=C exec sed -rune "$SED")
  exec < <(exec syslog-parse-dates)
  exec < <(LANG=C exec sort -Vu)
  SED='
    s~\t(device \S+) event down$~\t-\1~
    s~\t(device \S+) event up$~\t+\1~
    '
  exec < <(LANG=C exec sed -ure "$SED")
  SED='s~\b(device) ([0-9A-Fa-f:]+)( |$)~\v<\1=\2\v>\3~g'
  exec < <(LANG=C exec sed -ure "$SED")
  LANG=C exec sed -urf /proc/self/fd/5
  exec 5<&-
}










syslog_cli_init "$@"; exit $?
