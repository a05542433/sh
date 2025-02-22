#!/bin/bash

# 执行脚本1
bash <(curl -Ls https://raw.githubusercontent.com/sntpPro/rule_list/main/tools/sys.sh)

# 执行脚本2
S=nyanpass bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t a5f39c2a-b6a6-4ec0-b775-e0af45a790f2 -u https://ny.nekocat.app"
