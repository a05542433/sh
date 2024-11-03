#!/bin/bash

# 执行脚本1
echo 2 | bash <(curl -Ls https://raw.githubusercontent.com/a05542433/rule_list/main/tools/tools.sh)

# 执行脚本2
S=nyanpass bash <(curl -fLSs https://api.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t 16572ae9-049a-43bf-8334-9849f491f413 -u https://ny.nekocat.app"
