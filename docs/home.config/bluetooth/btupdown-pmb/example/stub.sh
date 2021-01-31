#!/bin/sh
# -*- coding: utf-8, tab-width: 2 -*-
( echo "
  BT device $BT_MAC event $BT_EVENT

  hook script: $0
  hook params: $*

  props file: $BT_PROPS"
  nl -ba
  echo
) | xmessage -title "$0" -file - ; exit $?
