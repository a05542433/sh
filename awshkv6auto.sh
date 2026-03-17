#!/bin/bash

# 执行脚本1
bash <(curl -Ls https://raw.githubusercontent.com/sntpPro/rule_list/main/tools/sys.sh)

# 执行脚本2
S=nyanpass bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t ebb2d03f-798a-45ad-8781-0a134096338d -u https://ny.nekocat.app --default-weight 3"

# 执行脚本3
S=nywapp bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t adbe7fa8-e9fe-47c5-955f-4e2f9748e2ae -u https://ny.awseyun.com"

# 执行脚本4
S=nywaco bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_nodeclient "-o -t d8a6501d-a59b-4f53-adbf-004881b48bb5 -u https://ny.awseyun.com"
