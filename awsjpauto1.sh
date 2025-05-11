#!/bin/bash

# 执行脚本1
bash <(curl -Ls https://raw.githubusercontent.com/sntpPro/rule_list/main/tools/sys.sh)

# 执行脚本2
S=nyanpass bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t a5f39c2a-b6a6-4ec0-b775-e0af45a790f2 -u https://ny.nekocat.app"

# 执行脚本3
S=nydk bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t 6302276c-5510-4c17-8c35-5f749f2eb2f9 -u https://zumo.moe"

# 执行脚本4
S=nykt bash <(curl -fLSs https://dispatch.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t 051b2c0d-5568-441c-928d-7e44bd8e1fe1 -u https://traffic.kinako.one"

