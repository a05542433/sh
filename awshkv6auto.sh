#!/bin/bash

# 执行脚本1
bash <(curl -Ls https://raw.githubusercontent.com/sntpPro/rule_list/main/tools/sys.sh)

# 执行脚本2
S=nyanpass bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t ebb2d03f-798a-45ad-8781-0a134096338d -u https://ny.nekocat.app"

# 执行脚本3
S=nyk bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t 3c7b38ed-7139-47f5-82ae-9faef452e4fb -u https://traffic.kinako.one"

# 执行脚本4
S=nyzu bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t 765b1aac-4391-4d30-9f98-d8a349a8eff5 -u https://zumo.moe"
