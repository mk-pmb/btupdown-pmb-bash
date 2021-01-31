#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function btupdown_lurk () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  # cd -- "$SELFPATH" || return $?
  cd / || return $?

  local LURK_PID="$$"
  local PROG_NAME='btupdown-pmb'
  local CFG_DIR="${XDG_CONFIG_DIR:-$HOME/.config}/bluetooth/$PROG_NAME"

  local RUN_DIR="$XDG_RUNTIME_DIR"
  [ -n "$RUN_DIR" ] || RUN_DIR="/run/user/${UID:-E_NO_UID}"
  export XDG_RUNTIME_DIR="$RUN_DIR"
  local STATE_DIR="$RUN_DIR/$PROG_NAME"
  mkdir --parents -- "$STATE_DIR/by-mac" || return $?
  local PID_FILE="$STATE_DIR/lurk.pid"
  echo "$LURK_PID" >"$PID_FILE" || return $?

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


function check_pid_file () {
  [ "$(cat -- "$PID_FILE"; echo :)" == "$LURK_PID"$'\n:' ] && return 0
  echo "W: $PROG_NAME[$LURK_PID]: pidfile was modified! flinching!" >&2
  return 2
}


function btupdown_ensure_lurking () {
  [ -n "$BTC_PID" ] && kill -0 "$BTC_PID" 2>/dev/null && return 0
  check_pid_file || return $?
  local BTC_FD=
  exec {BTC_FD}< <(exec < <(
    exec sleep 9009d
    ) stdbuf -i0 -o0 -e0 bluetoothctl 2>&1)
  BTC_PID="$!"
  # ps hu "$BTC_PID"
  exec < <(exec <&"$BTC_FD" "$SELFPATH"/de-zalgo.sed)
  exec {BTC_FD}<&-
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
  local PROPS_FILE="$STATE_DIR/by-mac"
  mkdir --parents -- "$PROPS_FILE" || return $?
  PROPS_FILE+="/$LC_MAC"

  local TRIG=
  if [ "$MSG" == 'Connected: yes' ]; then
    TRIG='up'
    [ ! -f "$PROPS_FILE" ] || rm -- "$PROPS_FILE" || return $?
    printf 'ConnectedSince: %(%s)T\n' -1 >"$PROPS_FILE" || return $?
  fi
  echo "$MSG" >>"$PROPS_FILE" || return $?
  if [ "$MSG" == 'Connected: no' ]; then
    TRIG='down'
    printf 'ConnectedUntil: %(%s)T\n' -1 >>"$PROPS_FILE" || return $?
  fi
  [ -z "$TRIG" ] || run_event_hooks || return $?
  [ "$TRIG" != down ] || rm -- "$PROPS_FILE" || return $?
}


function run_event_hooks () {
  check_pid_file || return $?
  logger --id --tag "$PROG_NAME" <<<"device $DEV_MAC event $TRIG"
  local HOOKS=(
    "$CFG_DIR"/[0-9A-Za-z]*/[0-9A-Za-z]*.{"$LC_MAC",any-mac}.{"$TRIG",any}
    )
  local HOOK=
  for HOOK in "${HOOKS[@]}"; do
    [ -x "$HOOK" ] || continue
    run_one_event_hook "$HOOK"
  done
}


function run_one_event_hook () {
  # The outer parens is required to ensure the stdin redirection is done
  # before the "&" forking. If we would rely on the forked child for the
  # redirection, a race condition may occurr: In the short time the child
  # needs for startup, we might already have processed new events for the
  # same device, and thus might have deleted or replaced the file path.
  ( (
      export BT_MAC="$DEV_MAC"
      export BT_EVENT="$TRIG"
      export BT_PROPS="$PROPS_FILE"
      exec "$@" "$DEV_MAC" "$TRIG" "$PROPS_FILE"
    ) &
    disown $!
  ) <"$PROPS_FILE"
}










btupdown_lurk "$@"; exit $?
