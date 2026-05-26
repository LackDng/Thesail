# 2025-07-23 20:19:43 by RouterOS 7.18.2
# software id = WR6U-ZZFA
#
# model = CCR2004-16G-2S+
# serial number = HK70AMY1466
/interface bridge
add name=bri.lan.trunk protocol-mode=none
/interface ethernet
set [ find default-name=ether1 ] mac-address=F4:1E:57:6D:FA:F0
set [ find default-name=ether2 ] mac-address=F4:1E:57:6D:FA:F1
set [ find default-name=ether3 ] mac-address=F4:1E:57:6D:FA:F2
set [ find default-name=ether4 ] mac-address=F4:1E:57:6D:FA:F3
set [ find default-name=ether5 ] mac-address=F4:1E:57:6D:FA:F4
set [ find default-name=ether6 ] mac-address=F4:1E:57:6D:FA:F5
set [ find default-name=ether7 ] mac-address=F4:1E:57:6D:FA:F6
set [ find default-name=ether8 ] mac-address=F4:1E:57:6D:FA:F7
set [ find default-name=ether9 ] mac-address=F4:1E:57:6D:FA:F8
set [ find default-name=ether10 ] mac-address=F4:1E:57:6D:FA:F9
set [ find default-name=ether11 ] mac-address=F4:1E:57:6D:FA:FA
set [ find default-name=ether12 ] mac-address=F4:1E:57:6D:FA:FB
set [ find default-name=ether13 ] mac-address=F4:1E:57:6D:FA:FC
set [ find default-name=ether14 ] mac-address=F4:1E:57:6D:FA:FD
set [ find default-name=ether15 ] mac-address=F4:1E:57:6D:FA:FE name=\
    ether15-Vnpt1
set [ find default-name=ether16 ] mac-address=F4:1E:57:6D:FA:FF name=\
    ether16-Vnpt2
set [ find default-name=sfp-sfpplus1 ] mac-address=F4:1E:57:6D:FB:01
set [ find default-name=sfp-sfpplus2 ] mac-address=F4:1E:57:6D:FB:00
/interface pppoe-client
add add-default-route=yes default-route-distance=10 disabled=no interface=\
    ether15-Vnpt1 name=pppoe-out1-Vnpt1 user=truongan912.fb.dng
add add-default-route=yes disabled=no interface=ether16-Vnpt2 name=\
    pppoe-out2-Vnpt2 user=truongan91.fb.dng
/interface vlan
add interface=bri.lan.trunk name=vlan16-WFGuest vlan-id=16
add interface=bri.lan.trunk name=vlan21-CCTV vlan-id=21
add interface=bri.lan.trunk name=vlan31-Office vlan-id=31
add interface=bri.lan.trunk name=vlan61-Controller vlan-id=61
/ip hotspot user profile
set [ find default=yes ] keepalive-timeout=3h shared-users=10000
/ip pool
add name=dhcp_pool0 ranges=192.168.11.10-192.168.11.254
add name=dhcp_pool1 ranges=172.16.0.10-172.16.3.250
add name=dhcp_pool2 ranges=192.168.61.10-192.168.61.254
add name=dhcp_pool3 ranges=192.168.21.10-192.168.21.254
add name=dhcp_pool4 ranges=192.168.31.10-192.168.31.254
add name=vpn-pool ranges=192.168.41.0/24
/ip dhcp-server
add address-pool=dhcp_pool0 interface=bri.lan.trunk name=dhcp1
add address-pool=dhcp_pool1 interface=vlan16-WFGuest lease-time=2d name=dhcp2
add address-pool=dhcp_pool2 interface=vlan61-Controller name=dhcp3
add address-pool=dhcp_pool3 interface=vlan21-CCTV name=dhcp4
add address-pool=dhcp_pool4 interface=vlan31-Office name=dhcp5
/port
set 0 name=serial0
/ppp profile
add local-address=192.168.41.1 name=vpn-profile remote-address=vpn-pool
/routing table
add name=to-pppoe1
add name=to-pppoe2
/snmp community
set [ find default=yes ] addresses=101.96.85.0/24
add addresses=101.96.85.0/24 name=netdept
/interface bridge port
add bridge=bri.lan.trunk interface=ether1
add bridge=bri.lan.trunk interface=ether2
add bridge=bri.lan.trunk interface=ether3
add bridge=bri.lan.trunk interface=ether4
add bridge=bri.lan.trunk interface=ether5
/ip firewall connection tracking
set tcp-established-timeout=1h
/interface l2tp-server server
set default-profile=vpn-profile enabled=yes use-ipsec=yes
/interface ovpn-server server
add mac-address=FE:7A:E4:3E:61:46 name=ovpn-server1
/interface pptp-server server
# PPTP connections are considered unsafe, it is suggested to use a more modern VPN protocol instead
set enabled=yes
/ip address
add address=192.168.31.1/24 interface=vlan31-Office network=192.168.31.0
add address=192.168.61.1/24 interface=vlan61-Controller network=192.168.61.0
add address=192.168.21.1/24 interface=vlan21-CCTV network=192.168.21.0
add address=172.16.0.1/22 interface=vlan16-WFGuest network=172.16.0.0
add address=192.168.11.1/24 interface=bri.lan.trunk network=192.168.11.0
add address=10.99.99.2/24 disabled=yes interface=ether16-Vnpt2 network=\
    10.99.99.0
/ip cloud
set update-time=no
/ip dhcp-server network
add address=172.16.0.0/22 dns-server=8.8.8.8,8.8.4.4 gateway=172.16.0.1
add address=192.168.11.0/24 dns-server=8.8.8.8,8.8.4.4 gateway=192.168.11.1
add address=192.168.21.0/24 dns-server=8.8.8.8,8.8.4.4 gateway=192.168.21.1
add address=192.168.31.0/24 dns-server=8.8.8.8,8.8.4.4 gateway=192.168.31.1
add address=192.168.61.0/24 dns-server=8.8.8.8,8.8.4.4 gateway=192.168.61.1
/ip dns
set servers=8.8.8.8,8.8.4.4
/ip firewall address-list
add address=192.168.70.0/24 list=Trust
add address=119.15.175.0/24 list=Trust
add address=119.17.222.0/24 list=Trust
add address=172.16.68.0/24 list=Trust
add address=192.168.100.0/24 list=Trust
add address=192.168.11.0/24 list=Lan-Local
add address=192.168.21.0/24 list=Lan-Local
add address=192.168.31.0/24 list=Lan-Local
add address=192.168.61.0/24 list=Lan-Local
add address=192.168.41.0/24 list=Lan-Local
/ip firewall filter
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=accept chain=forward dst-address-list=Lan-Local src-address=\
    192.168.41.0/24
add action=accept chain=forward dst-address=192.168.31.0/24 src-address=\
    192.168.61.0/24
add action=accept chain=input dst-port=1723 protocol=tcp
add action=accept chain=input protocol=gre
add action=accept chain=input comment="Trust netnam" dst-address-type=local \
    dst-port=22,23,8291,80 protocol=tcp src-address-list=Trust
add action=drop chain=input comment="Drop untrust" dst-address-type=local \
    dst-port=22,23,8291,80 protocol=tcp src-address-list=!Trust
/ip firewall nat
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=masquerade chain=srcnat comment="masquerade hotspot network" \
    src-address=172.16.0.0/22
add action=masquerade chain=srcnat out-interface=pppoe-out1-Vnpt1 \
    src-address-list=Lan-Local
add action=masquerade chain=srcnat out-interface=pppoe-out2-Vnpt2 \
    src-address-list=Lan-Local
/ip firewall service-port
set irc disabled=no
set sip disabled=yes
set rtsp disabled=no
/ip hotspot
add address-pool=dhcp_pool1 idle-timeout=3d interface=vlan16-WFGuest name=\
    https://locthien.vn/welcome-to-da-nang/ profile=*1
/ip hotspot user
add name=admin
/ip hotspot walled-garden
add disabled=yes dst-host=hsia.netnam.com
add disabled=yes dst-host=wifi-hsia.netnam.com
add disabled=yes dst-host=api-hsia.netnam.com
add disabled=yes dst-host=static-hsia.netnam.com
add disabled=yes dst-host=analytics.hsia.netnam.com
add disabled=yes dst-host=*.netnam.com
add disabled=yes dst-host=use.fontawesome.com dst-port=443
add disabled=yes dst-host=maxcdn.bootstrapcdn.com dst-port=443
add disabled=yes dst-host=fonts.googleapis.com dst-port=443
add disabled=yes dst-host=vinpearl-netnam.s3.ap-southeast-1.amazonaws.com
add disabled=yes dst-host=*.amazonaws.com
add disabled=yes dst-host=locthien.vn
add disabled=yes dst-host=translate.google.com
add disabled=yes dst-host=maps.googleapis.com
add disabled=yes dst-host=maps.gstatic.com
add disabled=yes dst-host=www.google.com
/ip ipsec profile
set [ find default=yes ] dpd-interval=2m dpd-maximum-failures=5
/ip route
add disabled=no distance=1 dst-address=192.168.100.0/24 gateway=172.16.68.1 \
    routing-table=main scope=30 suppress-hw-offload=no target-scope=10
add disabled=no distance=1 dst-address=172.16.68.0/24 gateway=172.16.68.1 \
    routing-table=main scope=30 suppress-hw-offload=no target-scope=10
add distance=1 dst-address=0.0.0.0/0 gateway=pppoe-out1-Vnpt1
/ip service
set telnet address=119.17.222.0/24,192.168.70.0/24,119.15.175.0/24 disabled=\
    yes
set ftp disabled=yes
set www address=119.17.222.0/24,192.168.70.0/24,119.15.175.0/24 disabled=yes
set ssh address=119.17.222.0/24,192.168.70.0/24,119.15.175.0/24 disabled=yes
set api disabled=yes
set winbox port=6035
set api-ssl disabled=yes
/ip ssh
set strong-crypto=yes
/ppp secret
add name=Tuanthesail profile=vpn-profile service=l2tp
/radius
add address=202.151.175.25 require-message-auth=no service=hotspot timeout=\
    10s
add address=202.151.175.17 require-message-auth=no service=hotspot timeout=\
    10s
/snmp
set contact=DAD|TheSailHotel enabled=yes location=DAD|TheSail-Server \
    trap-community=netdept trap-version=2
/system clock
set time-zone-name=Asia/Bangkok
/system identity
set name=DAD|TheSail-WFCX-NetNamRouter
/system note
set note=PowerByNetNam@2024 show-at-login=no
/system ntp client
set enabled=yes
/system ntp client servers
add address=101.96.85.22
/system routerboard settings
set enter-setup-on=delete-key
