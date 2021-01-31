#!/bin/sed -urf
# -*- coding: UTF-8, tab-width: 2 -*-
s~\x1B\[[0-9;]*[KmP]~~g
s~\x1B~<!!>~g
s~\r\s*~\r\n\r~g
s~\x01\x02~~g
s~[\x00-\x08\x0B\x0C\x0E-\x1F]~<"&">~g
