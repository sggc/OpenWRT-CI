#!/bin/bash
# SPDX-License-Identifier: MIT
# 私有扩展脚本：由 Scripts/Packages.sh 末尾自动引入
# 运行目录：./wrt/package/

# ===== 校园网防共享检测（仅 airoha 平台生效） =====
# 检测对抗分工：
#   TTL/hoplimit 统一  -> nft 内核规则（本脚本写入，不依赖任何守护进程）
#   UA 伪装            -> UA3F（GLOBAL 模式为其默认行为）
#   IPID 伪装          -> UA3F（首次开机自动启用，见下方 uci-defaults）
#   防时钟偏移          -> UA3F 删除 TCP 时间戳（首次开机自动启用）
#   Desync/封QUIC      -> 默认关闭，LuCI -> Services -> UA3F 中按需开启
# 注意：TTL 不在 UA3F 中重复启用，避免每个包都过一遍用户态处理；
#       若两者同时开启，目标值一致（64），也不会产生冲突。

if [[ "${WRT_TARGET^^}" == "AIROHA" ]]; then
	CAMPUS_DIR="../files/etc/nftables.d"
	mkdir -p "$CAMPUS_DIR"

	cat > "$CAMPUS_DIR/99-campusfix.nft" <<'RULES'
chain campusfix_postrouting {
	type filter hook postrouting priority mangle - 10; policy accept;
	# 排除内网与回环，有线 WAN 与 PPPoE（pppoe-wan）均覆盖
	oifname != "br-lan" oifname != "lo" ip ttl != 64 counter ip ttl set 64
	oifname != "br-lan" oifname != "lo" ip6 hoplimit != 64 counter ip6 hoplimit set 64
}
RULES

	# UA3F 开箱即用：首次开机自动启用，无需任何手工配置
	UA3F_DIR="../files/etc/uci-defaults"
	mkdir -p "$UA3F_DIR"

	cat > "$UA3F_DIR/99-ua3f-enable" <<'UA3FDEFAULTS'
#!/bin/sh
# 首次开机自动启用 UA3F 校园网防检测
[ -x /usr/bin/ua3f ] || exit 0
uci -q set ua3f.enabled.enabled=1
# IPID 伪装（出站 IP ID 归零，对抗 IPID 指纹检测）
uci -q set ua3f.main.l3_rewrite_ipid=1
# 删除 TCP 时间戳（对抗时钟偏移指纹检测）
uci -q set ua3f.main.l3_rewrite_tcpts=1
uci -q commit ua3f
exit 0
UA3FDEFAULTS

	echo " "
	echo "campus anti-detection (nft TTL + UA3F) has been added to firmware!"
fi
