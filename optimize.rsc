# =============================================================
# OPTIMIZE CONFIG - DAD|TheSail-WFCX-NetNamRouter
# RouterOS 7.18.2 | CCR2004-16G-2S+
# Target: Hardened firewall, PCC load-balance, WireGuard-only VPN
#
# GOLDEN RULE: Bat Safe Mode (Ctrl+X) truoc moi PHASE,
# kiem tra ket qua, roi Ctrl+X lan nua de commit.
# Neu mat ket noi -> ROUTER TU REVERT sau 9 phut.
# =============================================================


# -------------------------------------------------------------
# PHASE 0 - BACKUP (BAT BUOC chay truoc tien)
# -------------------------------------------------------------
/system backup save name=before-optimize-2026-06-09
/export file=before-optimize-2026-06-09
# Tai 2 file nay ve may ngay sau khi chay


# -------------------------------------------------------------
# PHASE 1 - DON DEP VPN CU (PPTP/L2TP/OVPN khong dung)
# Rui ro remote: THAP. Chi tat service, khong dong firewall chinh.
# -------------------------------------------------------------

# Tat PPTP (unsafe, da co WireGuard thay the)
/interface pptp-server server set enabled=no

# Tat L2TP/IPsec (da co WireGuard)
/interface l2tp-server server set enabled=no

# Xoa OpenVPN server cau hinh lung
/interface ovpn-server server remove [find name=ovpn-server1]

# Xoa user L2TP cu (nho doi pass admin neu can)
/ppp secret remove [find name=Tuanthesail]

# Bo subnet L2TP cu khoi Lan-Local
/ip firewall address-list remove [find address=192.168.41.0/24 list=Lan-Local]

# Them WireGuard subnet vao Lan-Local
/ip firewall address-list add address=10.10.10.0/24 list=Lan-Local comment="WireGuard VPN"


# -------------------------------------------------------------
# PHASE 2 - DON DEP ROUTE
# Rui ro remote: TRUNG BINH. Lam trong Safe Mode.
# -------------------------------------------------------------

# Xoa tat ca default route TINH (giu route dynamic cua PPPoE)
/ip route remove [find dst-address=0.0.0.0/0 static]

# Dat lai distance cho 2 PPPoE: line 1 = chinh, line 2 = du phong
/interface pppoe-client set [find name=pppoe-out1-Vnpt1] \
    default-route-distance=1 keepalive-timeout=10
/interface pppoe-client set [find name=pppoe-out2-Vnpt2] \
    default-route-distance=2 keepalive-timeout=10

# Comment 2 route cua NetNam (giu cho vendor)
/ip route comment [find dst-address=172.16.68.0/24] "NetNam mgmt tunnel - keep"
/ip route comment [find dst-address=192.168.100.0/24] "NetNam mgmt - keep"


# -------------------------------------------------------------
# PHASE 3 - INTERFACE LIST (chuan bi cho firewall + PCC)
# Rui ro remote: THAP.
# -------------------------------------------------------------

/interface list
add name=WAN comment="All WAN uplinks"
add name=LAN comment="LAN + VPN trust"

/interface list member
add interface=pppoe-out1-Vnpt1 list=WAN
add interface=pppoe-out2-Vnpt2 list=WAN
add interface=ether15-Vnpt1    list=WAN
add interface=ether16-Vnpt2    list=WAN

add interface=bri.lan.trunk     list=LAN
add interface=vlan21-CCTV       list=LAN
add interface=vlan31-Office     list=LAN
add interface=vlan61-Controller list=LAN
add interface=wg-vpn            list=LAN

# Guest VLAN (vlan16-WFGuest) KHONG cho vao LAN list


# -------------------------------------------------------------
# PHASE 4 - PCC LOAD BALANCE
# Rui ro remote: TRUNG BINH-CAO. PHAI Safe Mode + giu IP DDNS.
# -------------------------------------------------------------

# 4.1. Mangle: gan mark connection cho moi connection moi tu LAN
/ip firewall mangle
add chain=prerouting action=accept dst-address-list=Lan-Local \
    comment="LAN-to-LAN bypass PCC"

# Mark connection cho traffic vao tu LAN/VPN, di ra Internet
add chain=prerouting action=mark-connection new-connection-mark=Vnpt1_conn \
    connection-mark=no-mark dst-address-type=!local \
    src-address-list=Lan-Local connection-state=new \
    per-connection-classifier=both-addresses-and-ports:2/0 \
    comment="PCC: half to Vnpt1"
add chain=prerouting action=mark-connection new-connection-mark=Vnpt2_conn \
    connection-mark=no-mark dst-address-type=!local \
    src-address-list=Lan-Local connection-state=new \
    per-connection-classifier=both-addresses-and-ports:2/1 \
    comment="PCC: half to Vnpt2"

# Mark routing tuong ung
add chain=prerouting action=mark-routing new-routing-mark=to-Vnpt1 \
    connection-mark=Vnpt1_conn src-address-list=Lan-Local
add chain=prerouting action=mark-routing new-routing-mark=to-Vnpt2 \
    connection-mark=Vnpt2_conn src-address-list=Lan-Local

# Cho traffic do CHINH ROUTER khoi tao (probe, NTP, DNS...) di theo main table
add chain=output action=mark-routing new-routing-mark=to-Vnpt1 \
    connection-mark=Vnpt1_conn
add chain=output action=mark-routing new-routing-mark=to-Vnpt2 \
    connection-mark=Vnpt2_conn

# 4.2. Routing tables (da co san to-pppoe1/2 - doi ten cho dong nhat)
/routing table remove [find name~"to-pppoe"]
/routing table
add name=to-Vnpt1 fib
add name=to-Vnpt2 fib

# 4.3. Routes cho 2 routing-table
/ip route
add dst-address=0.0.0.0/0 gateway=pppoe-out1-Vnpt1 routing-table=to-Vnpt1 \
    check-gateway=ping comment="PCC primary on table 1"
add dst-address=0.0.0.0/0 gateway=pppoe-out2-Vnpt2 routing-table=to-Vnpt1 \
    distance=2 comment="failover for table 1"
add dst-address=0.0.0.0/0 gateway=pppoe-out2-Vnpt2 routing-table=to-Vnpt2 \
    check-gateway=ping comment="PCC primary on table 2"
add dst-address=0.0.0.0/0 gateway=pppoe-out1-Vnpt1 routing-table=to-Vnpt2 \
    distance=2 comment="failover for table 2"

# Main table van co default tu PPPoE (distance 1 va 2 nhu cau hinh PPPoE-client)
# -> Router itself dung Vnpt1, neu Vnpt1 chet thi Vnpt2


# -------------------------------------------------------------
# PHASE 5 - FIREWALL INPUT (HARDENING)
# Rui ro remote: CAO!!! BAT BUOC Safe Mode.
# Neu sai -> mat ket noi nhung tu phuc hoi sau 9 phut.
# -------------------------------------------------------------

# Xoa rule input cu (cu the - khong xoa rule forward)
/ip firewall filter remove [find chain=input dst-port=1723 protocol=tcp]
/ip firewall filter remove [find chain=input protocol=gre]
/ip firewall filter remove [find chain=input comment="Trust netnam"]
/ip firewall filter remove [find chain=input comment="Drop untrust"]
/ip firewall filter remove [find chain=input comment="WireGuard VPN"]

# Bo rule placeholder hotspot khong dung
/ip firewall filter remove [find chain=unused-hs-chain]

# Them rule input theo thu tu chuan
/ip firewall filter
add chain=input action=accept connection-state=established,related \
    comment="accept est/rel"
add chain=input action=drop connection-state=invalid \
    comment="drop invalid"
add chain=input action=accept protocol=icmp limit=50,5:packet \
    comment="accept ICMP rate-limited"
add chain=input action=drop protocol=icmp \
    comment="drop ICMP flood"
add chain=input action=accept in-interface-list=LAN \
    comment="accept all from LAN/VPN"
add chain=input action=accept protocol=udp dst-port=12579 in-interface-list=WAN \
    comment="WireGuard"
add chain=input action=accept protocol=tcp dst-port=22,6035 \
    src-address-list=Trust comment="mgmt SSH+Winbox from Trust"
add chain=input action=accept protocol=tcp dst-port=8291 \
    src-address-list=Trust comment="Winbox default port (if used) from Trust"
add chain=input action=drop comment="DROP ALL ELSE"


# -------------------------------------------------------------
# PHASE 6 - FIREWALL FORWARD + GUEST ISOLATION
# Rui ro remote: TRUNG BINH.
# -------------------------------------------------------------

# Xoa rule forward cu (chua chac dung dau)
/ip firewall filter remove [find chain=forward src-address=192.168.41.0/24]
/ip firewall filter remove [find chain=forward comment~"WG"]

# Them rule forward theo thu tu chuan
/ip firewall filter
add chain=forward action=fasttrack-connection connection-state=established,related \
    hw-offload=yes comment="fasttrack for performance"
add chain=forward action=accept connection-state=established,related,untracked \
    comment="accept est/rel"
add chain=forward action=drop connection-state=invalid \
    comment="drop invalid"

# Guest VLAN -> internet ONLY, KHONG cho vao LAN
add chain=forward action=drop src-address=172.16.0.0/22 \
    dst-address-list=Lan-Local comment="block Guest -> LAN"

# Inter-VLAN: Lan-Local di lai voi nhau OK (controller, office, mgmt, VPN)
add chain=forward action=accept src-address-list=Lan-Local \
    dst-address-list=Lan-Local comment="Lan-Local inter-VLAN"

# Giu rule cu: Controller -> Office
# (da co san - rule dst-address=192.168.31.0/24 src-address=192.168.61.0/24)
# Bo qua neu da bi xoa o tren

# LAN/VPN/Guest -> Internet
add chain=forward action=accept in-interface-list=LAN out-interface-list=WAN \
    comment="LAN -> WAN"
add chain=forward action=accept in-interface=vlan16-WFGuest \
    out-interface-list=WAN comment="Guest -> WAN"

# Drop unsolicited tu WAN
add chain=forward action=drop connection-state=new \
    connection-nat-state=!dstnat in-interface-list=WAN \
    comment="drop unsolicited from WAN"

add chain=forward action=drop comment="DROP ALL ELSE"


# -------------------------------------------------------------
# PHASE 7 - NAT (kiem tra + dam bao Guest cung duoc NAT qua ca 2 line)
# Rui ro remote: THAP.
# -------------------------------------------------------------

# Rule masquerade hotspot cu (172.16.0.0/22) co the bo - se duoc bao boi rule duoi
# /ip firewall nat remove [find comment="masquerade hotspot network"]

# Dam bao co 2 rule masquerade cho 2 WAN cho TAT CA (gom Guest)
# Kiem tra: /ip firewall nat print
# Neu chua co rule with src-address=172.16.0.0/22 trong Lan-Local thi them:
/ip firewall address-list add address=172.16.0.0/22 list=GuestNet comment="hotspot"

/ip firewall nat
add chain=srcnat action=masquerade out-interface=pppoe-out1-Vnpt1 \
    src-address=172.16.0.0/22 comment="Guest NAT via Vnpt1"
add chain=srcnat action=masquerade out-interface=pppoe-out2-Vnpt2 \
    src-address=172.16.0.0/22 comment="Guest NAT via Vnpt2"


# -------------------------------------------------------------
# PHASE 8 - SYSTEM HARDENING
# Rui ro remote: THAP.
# -------------------------------------------------------------

# DNS: cho phep VPN clients dung router lam DNS
/ip dns set allow-remote-requests=yes cache-size=4096KiB

# Timezone chuan
/system clock set time-zone-name=Asia/Ho_Chi_Minh

# NTP them server (giu 101.96.85.22 cua NetNam)
/system ntp client set servers=time.google.com,vn.pool.ntp.org,101.96.85.22

# SNMP: disable default community
/snmp community set [find default=yes] disabled=yes

# IP cloud DDNS (cho WireGuard endpoint khong can phu thuoc IP)
/ip cloud set ddns-enabled=yes update-time=yes

# Tang security cho hotspot user admin (PHAI doi password!)
# /ip hotspot user set [find name=admin] password=<DAT_MAT_KHAU_MANH>

# Connection tracking - giu nguyen tcp-established=1h (phu hop hotel)

# IPsec profile - giu nguyen (khong con dung nhung de do gay troubleshoot)


# -------------------------------------------------------------
# PHASE 9 - VERIFY (chay sau khi ap dung)
# -------------------------------------------------------------

# Chay tung lenh sau de xac nhan:
# /ip route print where dst-address=0.0.0.0/0
# /ip firewall filter print
# /ip firewall mangle print
# /interface list member print
# /interface wireguard peers print stats
# /ping 8.8.8.8 count=4
# /ping 1.1.1.1 count=4 routing-table=to-Vnpt2
# /tool traceroute 8.8.8.8 count=1


# -------------------------------------------------------------
# ROLLBACK neu can:
# /system backup load name=before-optimize-2026-06-09
# (router se reboot va khoi phuc nguyen trang)
# -------------------------------------------------------------
