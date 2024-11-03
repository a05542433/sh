#!/bin/bash

# 执行脚本1
echo 2 | bash <(curl -Ls https://raw.githubusercontent.com/a05542433/rule_list/main/tools/tools.sh)

# 执行脚本2
S=nyanpass bash <(curl -fLSs https://api.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t 6e3a6323-b1cd-48c9-a326-c67d29ef6e79 -u https://ny.nekocat.app"
