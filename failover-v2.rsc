# =============================================================
# FAILOVER CONFIG V2 - The Sail Hotel Router
# RouterOS 7.18.2 | CCR2004-16G-2S+
#
# MUC TIEU:
#   - PRIMARY  = pppoe-out2-Vnpt2  (line NHANH)
#   - BACKUP   = pppoe-out1-Vnpt1  (line YEU, du phong)
#   - Vnpt2 chet  -> tu dong chuyen sang Vnpt1
#   - Vnpt2 hoi   -> tu dong khoi phuc ve Vnpt2
#
# CACH TIEP CAN: Netwatch + thay doi distance cua PPPoE
#   - Ping probe 1.1.1.1 GHIM qua Vnpt2 (route /32 khong check-gateway)
#   - Khi probe DOWN  -> set distance Vnpt2 = 99  => Vnpt1 thang
#   - Khi probe UP    -> set distance Vnpt2 = 1   => Vnpt2 thang lai
#
# UU DIEM SO VOI V1 (recursive routing):
#   - Khong co chicken-and-egg (default route luon ton tai tu PPPoE)
#   - Phat hien duoc CA HAI: PPPoE rot + internet phia VNPT chet
#   - Don gian, de debug
#
# !!! BAT SAFE MODE (Ctrl+X) TRUOC KHI CHAY !!!
# =============================================================


# -------------------------------------------------------------
# BUOC 0 - BACKUP
# -------------------------------------------------------------
/system backup save name=before-failover-v2-2026-06-10
/export file=before-failover-v2-2026-06-10


# -------------------------------------------------------------
# BUOC 1 - CLEANUP (xoa tan du V1 + PCC neu co)
# -------------------------------------------------------------

# Xoa probe route cua V1
/ip route remove [find dst-address="8.8.8.8/32"]
/ip route remove [find dst-address="1.0.0.1/32"]
/ip route remove [find comment~"probe"]
/ip route remove [find comment~"PRIMARY"]
/ip route remove [find comment~"BACKUP"]

# Xoa mangle PCC neu con
/ip firewall mangle remove [find comment~"PCC"]
/ip firewall mangle remove [find comment="LAN-to-LAN bypass PCC"]
/ip firewall mangle remove [find new-routing-mark="to-Vnpt1"]
/ip firewall mangle remove [find new-routing-mark="to-Vnpt2"]

# Xoa routing-table PCC neu con
/ip route remove [find routing-table="to-Vnpt1"]
/ip route remove [find routing-table="to-Vnpt2"]
/routing table remove [find name="to-Vnpt1"]
/routing table remove [find name="to-Vnpt2"]


# -------------------------------------------------------------
# BUOC 2 - PPPOE: dat distance & keepalive
#   PPPoE TU sinh default route -> KHONG can quan ly thu cong
# -------------------------------------------------------------

/interface pppoe-client set [find name=pppoe-out2-Vnpt2] \
    add-default-route=yes default-route-distance=1 keepalive-timeout=10

/interface pppoe-client set [find name=pppoe-out1-Vnpt1] \
    add-default-route=yes default-route-distance=2 keepalive-timeout=10


# -------------------------------------------------------------
# BUOC 3 - GHIM PROBE ROUTE (de netwatch ping DUNG line)
#   Distance = 1 (cao hon default 0.0.0.0/0) de uu tien
#   KHONG dat check-gateway -> chi don thuan ghim duong
# -------------------------------------------------------------

/ip route
add dst-address=1.1.1.1/32 gateway=pppoe-out2-Vnpt2 distance=1 \
    comment="probe-pin-Vnpt2"
add dst-address=9.9.9.9/32 gateway=pppoe-out1-Vnpt1 distance=1 \
    comment="probe-pin-Vnpt1-keepalive"


# -------------------------------------------------------------
# BUOC 4 - NETWATCH: theo doi PRIMARY + tu dong failover/restore
# -------------------------------------------------------------

# Watchdog Vnpt2 (primary)
/tool netwatch
add disabled=no host=1.1.1.1 type=icmp interval=10s timeout=2s \
    comment="watchdog-Vnpt2-primary" \
    up-script=":log info \"[FAILOVER] Vnpt2 UP - restore primary\"; /interface pppoe-client set [find name=pppoe-out2-Vnpt2] default-route-distance=1" \
    down-script=":log warning \"[FAILOVER] Vnpt2 DOWN - switch to Vnpt1\"; /interface pppoe-client set [find name=pppoe-out2-Vnpt2] default-route-distance=99"

# Keepalive ping Vnpt1 (giu link am, khong trigger script gi)
add disabled=no host=9.9.9.9 type=icmp interval=30s timeout=2s \
    comment="keepalive-Vnpt1-backup"


# -------------------------------------------------------------
# BUOC 5 - KIEM TRA
# -------------------------------------------------------------
# /ip route print where dst-address="0.0.0.0/0"
#   Phai thay:
#     DAd  0.0.0.0/0  pppoe-out2-Vnpt2  distance=1   <- ACTIVE (Vnpt2)
#      Dd  0.0.0.0/0  pppoe-out1-Vnpt1  distance=2   <- standby (Vnpt1)
#
# /tool netwatch print
#   -> status cua watchdog-Vnpt2-primary phai = up
#
# /ip route print where dst-address~"1.1.1.1 or 9.9.9.9"
#   -> 2 probe route phai ACTIVE
#
# /ping 8.8.8.8 count=4    -> phai thong
#
# TEST FAILOVER (chiu gian doan vai giay):
#   Cach 1: /interface pppoe-client disable [find name=pppoe-out2-Vnpt2]
#   Cach 2: rut day Vnpt2
#   -> Sau ~10-30s: netwatch phat hien down -> log warning
#      -> distance Vnpt2 = 99 -> default route chuyen sang Vnpt1
#      -> /ip route print -> Vnpt1 thanh ACTIVE
#   Bat Vnpt2 lai (enable / cam day):
#   -> Sau ~10-30s: netwatch UP -> log info
#      -> distance Vnpt2 = 1 -> default tu khoi phuc ve Vnpt2


# -------------------------------------------------------------
# ROLLBACK (neu can):
# /system backup load name=before-failover-v2-2026-06-10
# -------------------------------------------------------------
