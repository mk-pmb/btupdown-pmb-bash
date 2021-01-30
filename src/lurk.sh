#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function btupdown_lurk () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  # cd -- "$SELFPATH" || return $?
  cd / || return $?

  local PROG_NAME='btupdown-pmb'
  local RUN_DIR="$XDG_RUNTIME_DIR"
  [ -n "$RUN_DIR" ] || RUN_DIR="/run/user/${UID:-E_NO_UID}"
  export XDG_RUNTIME_DIR="$RUN_DIR"
  local STATE_DIR="$RUN_DIR/$PROG_NAME"
  mkdir --parents "$STATE_DIR/by-mac" || return $?

  local BTC_PID=
  while true; do
    btupdown_ensure_lurking || return $?
    IFS= read -r LN || continue
    # printf '%(%T)T << %s >>\n' -1 "${LN//$'\r'/«}"
    case "$LN" in
      *$'\r' ) ;;
      $'\r[CHG] Device '* ) dev_prop_chg "${LN#* * }" || return $?;;
    esac
  done
}


function btupdown_ensure_lurking () {
  [ -n "$BTC_PID" ] && kill -0 "$BTC_PID" 2>/dev/null && return 0
  exec 14< <(exec < <(exec sleep 10m) stdbuf -i0 -o0 -e0 bluetoothctl 2>&1)
  BTC_PID="$!"
  ps hu "$BTC_PID"
  exec < <(exec <&14 sed -ure '
    s~\x1B\[[0-9;]*[KmP]~~g
    s~\x1B~<!!>~g
    s~\r\s*~\r\n\r~g
    s~\x01\x02~~g
    s~[\x00-\x08\x0B\x0C\x0E-\x1F]~<"&">~g
    ')
  exec 14<&-
  sleep 1s
}


function dev_prop_chg () {
  local MSG="$1"
  case "${MSG//[1-9A-Fa-f]/0}" in
    '00:00:00:00:00:00 '*': '* ) ;;
    * )
      echo "W: $PROG_NAME: $FUNCNAME: unexpected input: '$MSG'" >&2
      return 0;;
  esac
  local DEV_MAC="${MSG%% *}"; MSG="${MSG#* }"
  local LC_MAC="${DEV_MAC,,}"
  LC_MAC="${LC_MAC//:/}"
  local STATE_FILE="$STATE_DIR/by-mac"
  mkdir --parents "$STATE_FILE" || return $?
  STATE_FILE+="/$LC_MAC"

  local TRIG=
  if [ "$MSG" == 'Connected: yes' ]; then
    TRIG='up'
    [ ! -f "$STATE_FILE" ] || rm -- "$STATE_FILE" || return $?
    printf 'ConnectedSince: %(%s)T\n' -1 >"$STATE_FILE" || return $?
  fi
  echo "$MSG" >>"$STATE_FILE" || return $?
  if [ "$MSG" == 'Connected: no' ]; then
    TRIG='down'
    printf 'ConnectedUntil: %(%s)T\n' -1 >>"$STATE_FILE" || return $?
  fi
  [ -z "$TRIG" ] || run_event_hooks || return $?
  [ "$TRIG" != down ] || rm -- "$STATE_FILE" || return $?
}


function run_event_hooks () {
  echo "! $DEV_MAC $TRIG $STATE_FILE !"

  # The outer parens is required to ensure the stdin redirection is done
  # before the "&" forking. If we would rely on the forked child for the
  # redirection, a race condition may occurr: In the short time the child
  # needs for startup, we might already have processed new events for the
  # same device, and thus might have deleted or replaced the file path.
  ( ( sleep 2s
      ls -l /proc/self/fd
      nl -ba
    ) &
    disown $!
  ) <"$STATE_FILE"
}










btupdown_lurk "$@"; exit $?
