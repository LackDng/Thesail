# =============================================================
# FAILOVER CONFIG - The Sail Hotel Router
# RouterOS 7.18.2 | CCR2004-16G-2S+
#
# MUC TIEU:
#   - PRIMARY  = pppoe-out2-Vnpt2  (line NHANH)
#   - BACKUP   = pppoe-out1-Vnpt1  (line YEU, du phong)
#   - Vnpt2 chet  -> tu dong chuyen sang Vnpt1
#   - Vnpt2 hoi   -> tu dong khoi phuc ve Vnpt2
#
# Phat hien loi bang recursive routing + check-gateway=ping
#   => bat duoc CA HAI truong hop:
#      (1) PPPoE rot han
#      (2) PPPoE con "up" nhung internet phia VNPT chet
#
# !!! BAT SAFE MODE (Ctrl+X) TRUOC KHI CHAY !!!
#     Neu mat ket noi -> router tu revert sau ~9 phut.
# =============================================================


# -------------------------------------------------------------
# BUOC 0 - BACKUP
# -------------------------------------------------------------
/system backup save name=before-failover-2026-06-10
/export file=before-failover-2026-06-10


# -------------------------------------------------------------
# BUOC 1 - GO BO PCC LOAD BALANCE (neu da ap dung truoc do)
# -------------------------------------------------------------

# Xoa cac mangle rule cua PCC
/ip firewall mangle remove [find comment~"PCC"]
/ip firewall mangle remove [find comment="LAN-to-LAN bypass PCC"]
/ip firewall mangle remove [find new-routing-mark="to-Vnpt1"]
/ip firewall mangle remove [find new-routing-mark="to-Vnpt2"]
/ip firewall mangle remove [find connection-mark="Vnpt1_conn"]
/ip firewall mangle remove [find connection-mark="Vnpt2_conn"]

# Xoa route thuoc 2 bang PCC, roi xoa bang
/ip route remove [find routing-table="to-Vnpt1"]
/ip route remove [find routing-table="to-Vnpt2"]
/routing table remove [find name="to-Vnpt1"]
/routing table remove [find name="to-Vnpt2"]


# -------------------------------------------------------------
# BUOC 2 - PPPoE: TAT default route tu dong, bat keepalive nhanh
#   Quan ly default route hoan toan bang static recursive route
# -------------------------------------------------------------

/interface pppoe-client set [find name=pppoe-out2-Vnpt2] \
    add-default-route=no keepalive-timeout=10
/interface pppoe-client set [find name=pppoe-out1-Vnpt1] \
    add-default-route=no keepalive-timeout=10


# -------------------------------------------------------------
# BUOC 3 - XOA SACH default route cu con sot lai
# -------------------------------------------------------------
/ip route remove [find dst-address="0.0.0.0/0"]


# -------------------------------------------------------------
# BUOC 4 - PROBE ROUTE (ghim moi probe vao DUNG 1 line + ping-check)
#   - Probe primary: ping 8.8.8.8 BAT BUOC qua Vnpt2
#   - Probe backup : ping 1.0.0.1 BAT BUOC qua Vnpt1
#   check-gateway=ping: neu khong ping duoc -> route INACTIVE
# -------------------------------------------------------------
/ip route
add dst-address=8.8.8.8/32 gateway=pppoe-out2-Vnpt2 scope=10 \
    check-gateway=ping comment="probe-PRIMARY-Vnpt2"
add dst-address=1.0.0.1/32 gateway=pppoe-out1-Vnpt1 scope=10 \
    check-gateway=ping comment="probe-BACKUP-Vnpt1"


# -------------------------------------------------------------
# BUOC 5 - DEFAULT ROUTE DE QUY (recursive)
#   - Primary: 0.0.0.0/0 -> nexthop 8.8.8.8 (resolve qua probe Vnpt2)
#     distance=1 => uu tien
#   - Backup : 0.0.0.0/0 -> nexthop 1.0.0.1 (resolve qua probe Vnpt1)
#     distance=2 => chi active khi primary inactive
#
#   Co che:
#     Vnpt2 chet -> probe 8.8.8.8 inactive -> default primary inactive
#                -> default backup (Vnpt1) active  => CHUYEN
#     Vnpt2 hoi  -> probe 8.8.8.8 active   -> default primary active
#                => KHOI PHUC ve Vnpt2
# -------------------------------------------------------------
add dst-address=0.0.0.0/0 gateway=8.8.8.8 distance=1 target-scope=10 \
    comment="DEFAULT PRIMARY via Vnpt2"
add dst-address=0.0.0.0/0 gateway=1.0.0.1 distance=2 target-scope=10 \
    comment="DEFAULT BACKUP via Vnpt1"


# -------------------------------------------------------------
# BUOC 6 - NAT (giu nguyen - masquerade theo out-interface)
#   Da co san 2 rule:
#     masquerade out=pppoe-out1-Vnpt1 src-list=Lan-Local
#     masquerade out=pppoe-out2-Vnpt2 src-list=Lan-Local
#   => Khi failover, traffic ra interface nao thi masquerade interface do.
#   Kiem tra: /ip firewall nat print
# -------------------------------------------------------------


# -------------------------------------------------------------
# BUOC 7 - KIEM TRA
# -------------------------------------------------------------
# /ip route print where dst-address="0.0.0.0/0"
#   -> Phai thay:
#      DAd  0.0.0.0/0  8.8.8.8  distance=1   (ACTIVE - dang chay Vnpt2)
#       Db  0.0.0.0/0  1.0.0.1  distance=2   (backup, chua active)
#
# /ip route print where dst-address~"8.8.8.8 or 1.0.0.1"
#   -> 2 probe route, probe Vnpt2 phai ACTIVE
#
# /ping 8.8.8.8 count=4
# /tool traceroute 8.8.8.8 count=1   (xem hop dau ra dung Vnpt2)
#
# TEST FAILOVER (lam khi co the chiu gian doan vai giay):
#   Rut day Vnpt2 (hoac /interface pppoe-client disable pppoe-out2-Vnpt2)
#   -> sau ~10-15s default backup active, internet van chay qua Vnpt1
#   Cam lai / enable Vnpt2
#   -> sau ~10-15s tu dong khoi phuc ve Vnpt2


# -------------------------------------------------------------
# ROLLBACK:
#   /system backup load name=before-failover-2026-06-10
# -------------------------------------------------------------
