#!/bin/bash

# 执行脚本1
echo 2 | bash <(curl -Ls https://raw.githubusercontent.com/a05542433/rule_list/main/tools/tools.sh)

# 执行脚本2
S=nyanpass bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t ebb2d03f-798a-45ad-8781-0a134096338d -u https://ny.nekocat.app"
