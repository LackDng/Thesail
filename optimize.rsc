# =============================================================
# OPTIMIZE CONFIG - The Sail Hotel Router
# RouterOS 7.18.2 | CCR2004-16G-2S+
# Target: Hardened firewall, PCC load-balance, WireGuard-only VPN,
#         Loai bo hoan toan NetNam legacy + Hotspot khong dung
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
# PHASE 1A - DON DEP VPN CU (PPTP/L2TP/OVPN khong dung)
# Rui ro remote: THAP
# -------------------------------------------------------------

/interface pptp-server server set enabled=no
/interface l2tp-server server set enabled=no
/interface ovpn-server server remove [find name=ovpn-server1]
/ppp secret remove [find name=Tuanthesail]
/ppp profile remove [find name=vpn-profile]
/ip pool remove [find name=vpn-pool]

# Bo subnet L2TP cu khoi Lan-Local, them WireGuard
/ip firewall address-list remove [find address=192.168.41.0/24 list=Lan-Local]
/ip firewall address-list add address=10.10.10.0/24 list=Lan-Local comment="WireGuard VPN"


# -------------------------------------------------------------
# PHASE 1B - DON SACH NETNAM LEGACY
# Rui ro remote: THAP-TRUNG BINH
# Truoc khi chay - DAM BAO IP ban dang remote KHONG thuoc 172.16.68.0/24
# hoac 192.168.100.0/24 (la NetNam mgmt subnet)
# -------------------------------------------------------------

# Xoa route NetNam (khong con dung)
/ip route remove [find dst-address=172.16.68.0/24 gateway=172.16.68.1]
/ip route remove [find dst-address=192.168.100.0/24 gateway=172.16.68.1]

# Xoa NetNam IP khoi Trust list
/ip firewall address-list remove [find address=172.16.68.0/24 list=Trust]
/ip firewall address-list remove [find address=192.168.100.0/24 list=Trust]

# Xoa RADIUS NetNam (khong con dung cho hotspot - hotspot cung se bi xoa)
/radius remove [find address=202.151.175.25]
/radius remove [find address=202.151.175.17]

# Xoa SNMP community netdept + disable default
/snmp community remove [find name=netdept]
/snmp community set [find default=yes] disabled=yes
/snmp set enabled=no trap-community=public trap-version=2

# Xoa NTP NetNam (gan NTP moi o Phase 8)
/system ntp client servers remove [find address=101.96.85.22]

# Xoa walled-garden NetNam (tat ca dang disabled)
/ip hotspot walled-garden remove [find]

# Doi identity va note
/system identity set name=TheSail-Router
/system note set note="" show-at-login=no


# -------------------------------------------------------------
# PHASE 1C - XOA HOTSPOT + GUEST VLAN (khong con dung)
# Rui ro remote: THAP (Guest VLAN tach biet voi mgmt)
# -------------------------------------------------------------

# Xoa hotspot service + user
/ip hotspot remove [find]
/ip hotspot user remove [find]
# Reset user profile mac dinh ve default
/ip hotspot user profile set [find default=yes] keepalive-timeout=00:00:00 shared-users=1

# Xoa DHCP cho guest
/ip dhcp-server remove [find name=dhcp2]
/ip dhcp-server network remove [find address=172.16.0.0/22]
/ip pool remove [find name=dhcp_pool1]

# Xoa IP va VLAN guest
/ip address remove [find interface=vlan16-WFGuest]
/interface vlan remove [find name=vlan16-WFGuest]

# Xoa NAT rule hotspot
/ip firewall nat remove [find comment="masquerade hotspot network"]


# -------------------------------------------------------------
# PHASE 2 - DON DEP ROUTE
# Rui ro remote: TRUNG BINH
# -------------------------------------------------------------

# Xoa tat ca default route TINH (giu route dynamic cua PPPoE)
/ip route remove [find dst-address=0.0.0.0/0 static]

# Dat distance cho 2 PPPoE: line 1 = chinh, line 2 = du phong
/interface pppoe-client set [find name=pppoe-out1-Vnpt1] \
    default-route-distance=1 keepalive-timeout=10
/interface pppoe-client set [find name=pppoe-out2-Vnpt2] \
    default-route-distance=2 keepalive-timeout=10


# -------------------------------------------------------------
# PHASE 3 - INTERFACE LIST (chuan bi cho firewall + PCC)
# Rui ro remote: THAP
# -------------------------------------------------------------

/interface list
add name=WAN comment="All WAN uplinks"
add name=LAN comment="LAN + VPN trust zones"

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


# -------------------------------------------------------------
# PHASE 4 - PCC LOAD BALANCE
# Rui ro remote: TRUNG BINH-CAO. PHAI Safe Mode + giu IP DDNS
# -------------------------------------------------------------

# Mangle: gan mark connection cho moi connection moi tu LAN
/ip firewall mangle
add chain=prerouting action=accept dst-address-list=Lan-Local \
    comment="LAN-to-LAN bypass PCC"

# Mark connection - PCC chia traffic 50/50
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

# Output mark cho traffic do CHINH ROUTER khoi tao (probe, NTP, DNS, DDNS)
add chain=output action=mark-routing new-routing-mark=to-Vnpt1 \
    connection-mark=Vnpt1_conn
add chain=output action=mark-routing new-routing-mark=to-Vnpt2 \
    connection-mark=Vnpt2_conn

# Routing tables (xoa ten cu, dat ten dong nhat)
/routing table remove [find name~"to-pppoe"]
/routing table
add name=to-Vnpt1 fib
add name=to-Vnpt2 fib

# Routes cho 2 routing-table
/ip route
add dst-address=0.0.0.0/0 gateway=pppoe-out1-Vnpt1 routing-table=to-Vnpt1 \
    check-gateway=ping comment="PCC primary on table 1"
add dst-address=0.0.0.0/0 gateway=pppoe-out2-Vnpt2 routing-table=to-Vnpt1 \
    distance=2 comment="failover for table 1"
add dst-address=0.0.0.0/0 gateway=pppoe-out2-Vnpt2 routing-table=to-Vnpt2 \
    check-gateway=ping comment="PCC primary on table 2"
add dst-address=0.0.0.0/0 gateway=pppoe-out1-Vnpt1 routing-table=to-Vnpt2 \
    distance=2 comment="failover for table 2"

# Main table van co default tu PPPoE (distance 1, 2) cho router itself


# -------------------------------------------------------------
# PHASE 5 - FIREWALL INPUT (HARDENING)
# Rui ro remote: CAO!!! BAT BUOC Safe Mode.
#
# QUAN TRONG: Truoc khi chay, BAT BUOC them IP public cua ban
# vao Trust list neu chua co (vi 2 subnet NetNam vua bi xoa):
#   /ip firewall address-list add address=<YOUR_IP>/32 list=Trust comment="Admin"
# -------------------------------------------------------------

# Xoa rule input cu
/ip firewall filter remove [find chain=input dst-port=1723 protocol=tcp]
/ip firewall filter remove [find chain=input protocol=gre]
/ip firewall filter remove [find chain=input comment="Trust netnam"]
/ip firewall filter remove [find chain=input comment="Drop untrust"]
/ip firewall filter remove [find chain=input comment="WireGuard VPN"]
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
add chain=input action=drop comment="DROP ALL ELSE"


# -------------------------------------------------------------
# PHASE 6 - FIREWALL FORWARD
# Rui ro remote: TRUNG BINH
# -------------------------------------------------------------

# Xoa rule forward cu
/ip firewall filter remove [find chain=forward src-address=192.168.41.0/24]
/ip firewall filter remove [find chain=forward comment~"WG"]
/ip firewall filter remove [find chain=unused-hs-chain]

# Them rule forward theo thu tu chuan
/ip firewall filter
add chain=forward action=fasttrack-connection connection-state=established,related \
    hw-offload=yes comment="fasttrack performance"
add chain=forward action=accept connection-state=established,related,untracked \
    comment="accept est/rel"
add chain=forward action=drop connection-state=invalid \
    comment="drop invalid"

# Inter-VLAN: Lan-Local di lai voi nhau
add chain=forward action=accept src-address-list=Lan-Local \
    dst-address-list=Lan-Local comment="Lan-Local inter-VLAN"

# LAN/VPN -> Internet
add chain=forward action=accept in-interface-list=LAN out-interface-list=WAN \
    comment="LAN -> WAN"

# Drop unsolicited tu WAN
add chain=forward action=drop connection-state=new \
    connection-nat-state=!dstnat in-interface-list=WAN \
    comment="drop unsolicited from WAN"

add chain=forward action=drop comment="DROP ALL ELSE"


# -------------------------------------------------------------
# PHASE 7 - NAT (don gian hoa - chi 2 rule cho 2 WAN)
# Rui ro remote: THAP
# -------------------------------------------------------------

# Giu 2 rule masquerade cho 2 WAN (cho LAN/VPN)
# Cau hinh hien tai da co - kiem tra:
# /ip firewall nat print

# Neu chua sach, lam lai:
/ip firewall nat remove [find chain=unused-hs-chain]
# (Khong xoa 2 rule masquerade hien co - giu nguyen)


# -------------------------------------------------------------
# PHASE 8 - SYSTEM HARDENING
# Rui ro remote: THAP
# -------------------------------------------------------------

# DNS: cho phep VPN clients dung router lam DNS
/ip dns set allow-remote-requests=yes cache-size=4096KiB

# Timezone chuan VN
/system clock set time-zone-name=Asia/Ho_Chi_Minh

# NTP - dung server cong cong (da xoa 101.96.85.22 cua NetNam)
/system ntp client set servers=time.google.com,vn.pool.ntp.org,time.cloudflare.com

# IP cloud DDNS (cho WireGuard endpoint khong phu thuoc IP)
/ip cloud set ddns-enabled=yes update-time=yes

# Connection tracking - giu mac dinh (con su dung tcp-established=1h cu cung OK)


# -------------------------------------------------------------
# PHASE 9 - VERIFY (chay sau khi ap dung)
# -------------------------------------------------------------

# /ip route print where dst-address=0.0.0.0/0
# /ip firewall filter print
# /ip firewall mangle print
# /ip firewall nat print
# /interface list member print
# /interface wireguard peers print stats
# /radius print
# /snmp community print
# /system ntp client print
# /ip cloud print
# /ping 8.8.8.8 count=4
# /ping 1.1.1.1 count=4 routing-table=to-Vnpt2
# /tool traceroute 8.8.8.8 count=1


# -------------------------------------------------------------
# ROLLBACK neu can:
# /system backup load name=before-optimize-2026-06-09
# (router reboot va khoi phuc nguyen trang)
# -------------------------------------------------------------
