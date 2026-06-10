# Cấu hình Router The Sail Hotel

> **Trạng thái**: Tài liệu cấu hình sau khi áp dụng `optimize.rsc`
> **Router**: MikroTik CCR2004-16G-2S+ · RouterOS 7.18.2
> **Identity**: `TheSail-Router`

---

## 1. Phần cứng & hệ thống

| Mục | Giá trị |
|-----|---------|
| Model | MikroTik CCR2004-16G-2S+ |
| RouterOS | 7.18.2 |
| Serial | HK70AMY1466 |
| Identity | `TheSail-Router` |
| Timezone | Asia/Ho_Chi_Minh |
| NTP servers | time.google.com, vn.pool.ntp.org, time.cloudflare.com |
| Winbox port | 6035 (custom) |

---

## 2. Interface vật lý

| Interface | Vai trò | MAC |
|-----------|---------|-----|
| ether1 → ether5 | LAN bridge ports (`bri.lan.trunk`) | F4:1E:57:6D:FA:F0–F4 |
| ether6 → ether14 | Không dùng (dự phòng) | F4:1E:57:6D:FA:F5–FD |
| ether15-Vnpt1 | WAN PPPoE line 1 | F4:1E:57:6D:FA:FE |
| ether16-Vnpt2 | WAN PPPoE line 2 | F4:1E:57:6D:FA:FF |
| sfp-sfpplus1/2 | Không dùng | F4:1E:57:6D:FB:00–01 |

---

## 3. WAN — Dual PPPoE VNPT

| Interface | Type | User | Vai trò | Distance |
|-----------|------|------|---------|----------|
| `pppoe-out2-Vnpt2` | PPPoE / ether16 | truongan91.fb.dng | **PRIMARY** (line nhanh) | 1 |
| `pppoe-out1-Vnpt1` | PPPoE / ether15 | truongan912.fb.dng | **BACKUP** (dự phòng) | 2 |

- `keepalive-timeout=10s`, `add-default-route=no` cho cả 2 (default route quản lý bằng static recursive route).
- **Chế độ**: Failover thuần (KHÔNG load-balance) vì 2 line chênh tốc độ.
- Vnpt2 chết → tự chuyển Vnpt1. Vnpt2 hồi → tự khôi phục về Vnpt2.

---

## 4. LAN & VLAN

| Interface | VLAN ID | Subnet | Gateway | DHCP Pool |
|-----------|---------|--------|---------|-----------|
| `bri.lan.trunk` | native | 192.168.11.0/24 | 192.168.11.1 | .10 - .254 |
| `vlan21-CCTV` | 21 | 192.168.21.0/24 | 192.168.21.1 | .10 - .254 |
| `vlan31-Office` | 31 | 192.168.31.0/24 | 192.168.31.1 | .10 - .254 |
| `vlan61-Controller` | 61 | 192.168.61.0/24 | 192.168.61.1 | .10 - .254 |
| `wg-vpn` (WireGuard) | — | 10.10.10.0/24 | 10.10.10.1 | static peer |

**DHCP options**: DNS = `192.168.11.1, 8.8.8.8, 8.8.4.4`

---

## 5. VPN — WireGuard

### Server

| Mục | Giá trị |
|-----|---------|
| Interface name | `wg-vpn` |
| Listen port | **12579** (UDP) |
| Address | 10.10.10.1/24 |
| Public key | `xJ1o9SaZp3RDWpocKJzlUX3ATGdpvHzuL5baXUUBQSE=` |
| Endpoint DDNS | `<id>.sn.mynetname.net:12579` |

### Peers

| Name | Allowed-Address | Public key |
|------|-----------------|------------|
| peer-client1 | 10.10.10.2/32 | `2uVcVTwyr8b+CH+E9pqVYOoAFGL6imKvt0nj56q0TiE=` |

Persistent keepalive: 25s

### Client config mẫu

```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.10.10.2/32
DNS = 192.168.11.1, 8.8.8.8

[Peer]
PublicKey = xJ1o9SaZp3RDWpocKJzlUX3ATGdpvHzuL5baXUUBQSE=
Endpoint = <id>.sn.mynetname.net:12579
AllowedIPs = 10.10.10.0/24, 192.168.11.0/24, 192.168.31.0/24, 192.168.61.0/24, 192.168.21.0/24
PersistentKeepalive = 25
```

---

## 6. Address Lists

### Trust (quyền vào quản trị)

```
192.168.70.0/24
119.15.175.0/24
119.17.222.0/24
```

### Lan-Local (zone tin cậy nội bộ)

```
192.168.11.0/24    ← mgmt
192.168.21.0/24    ← CCTV
192.168.31.0/24    ← Office
192.168.61.0/24    ← Controller
10.10.10.0/24      ← WireGuard VPN
```

---

## 7. Interface Lists

| List | Members |
|------|---------|
| `WAN` | pppoe-out1-Vnpt1, pppoe-out2-Vnpt2, ether15-Vnpt1, ether16-Vnpt2 |
| `LAN` | bri.lan.trunk, vlan21-CCTV, vlan31-Office, vlan61-Controller, wg-vpn |

---

## 8. Firewall — Chain INPUT

| # | Action | Match | Comment |
|---|--------|-------|---------|
| 1 | accept | established,related | est/rel |
| 2 | drop | invalid | |
| 3 | accept | icmp limit=50,5:packet | ICMP rate-limited |
| 4 | drop | icmp | drop ICMP flood |
| 5 | accept | in-list=LAN | LAN/VPN full trust |
| 6 | accept | udp/12579 in-list=WAN | WireGuard |
| 7 | accept | tcp/22,6035 src-list=Trust | SSH + Winbox |
| 8 | **drop** | **all else** | **default deny** |

---

## 9. Firewall — Chain FORWARD

| # | Action | Match | Comment |
|---|--------|-------|---------|
| 1 | fasttrack-connection | est,rel | hw-offload performance |
| 2 | accept | est,rel,untracked | |
| 3 | drop | invalid | |
| 4 | accept | src-list=Lan-Local dst-list=Lan-Local | inter-VLAN |
| 5 | accept | in-list=LAN out-list=WAN | LAN → Internet |
| 6 | drop | new !dstnat in-list=WAN | chặn WAN scan |
| 7 | **drop** | **all else** | **default deny** |

---

## 10. NAT

```
chain=srcnat
  masquerade  out=pppoe-out1-Vnpt1  src-list=Lan-Local
  masquerade  out=pppoe-out2-Vnpt2  src-list=Lan-Local
```

---

## 11. Failover — Recursive Routing

> KHÔNG dùng PCC/mangle. Default route quản lý bằng static recursive route + `check-gateway=ping`.

**Cơ chế phát hiện lỗi** (bắt cả 2 trường hợp: PPPoE rớt + internet phía VNPT chết):

| Probe | Ghim qua line | Đích ping | check-gateway |
|-------|---------------|-----------|---------------|
| probe-PRIMARY | pppoe-out2-Vnpt2 | 8.8.8.8/32 | ping |
| probe-BACKUP | pppoe-out1-Vnpt1 | 1.0.0.1/32 | ping |

Khi không ping được → probe route INACTIVE → default route tương ứng INACTIVE → chuyển sang line còn lại.

---

## 12. Routing Tables & Routes

### Tables

| Table | Mục đích |
|-------|---------|
| `main` | Tất cả traffic (failover, không phân nhánh) |

### Routes (failover recursive)

```
Probe routes (pin + ping-check):
  8.8.8.8/32   gateway=pppoe-out2-Vnpt2  scope=10  check-gateway=ping   [probe primary]
  1.0.0.1/32   gateway=pppoe-out1-Vnpt1  scope=10  check-gateway=ping   [probe backup]

Default routes (recursive):
  0.0.0.0/0    gateway=8.8.8.8  distance=1  target-scope=10   [PRIMARY via Vnpt2]
  0.0.0.0/0    gateway=1.0.0.1  distance=2  target-scope=10   [BACKUP  via Vnpt1]

Connected routes:
  10.10.10.0/24    wg-vpn
  192.168.11.0/24  bri.lan.trunk
  192.168.21.0/24  vlan21-CCTV
  192.168.31.0/24  vlan31-Office
  192.168.61.0/24  vlan61-Controller
```

> **Lưu ý**: traffic người dùng đến đúng IP `8.8.8.8` sẽ luôn đi qua Vnpt2 (primary), đến `1.0.0.1` luôn qua Vnpt1 — do 2 IP này bị ghim làm probe. Không ảnh hưởng traffic khác.

---

## 13. DNS

| Mục | Giá trị |
|-----|---------|
| servers | 8.8.8.8, 8.8.4.4 |
| allow-remote-requests | yes |
| cache-size | 4096 KiB |

> Firewall input default-drop chặn UDP/53 từ WAN → DNS resolver chỉ phục vụ LAN/VPN.

---

## 14. Services

| Service | Port | Trạng thái | Access |
|---------|------|-----------|--------|
| Winbox | **6035** | enabled | từ Trust |
| SSH | 22 | enabled | từ Trust |
| Telnet | 23 | disabled | — |
| FTP | 21 | disabled | — |
| WWW | 80 | disabled | — |
| API | 8728 | disabled | — |
| API-SSL | 8729 | disabled | — |

SSH: `strong-crypto=yes`

---

## 15. Cloud / DDNS

```
ddns-enabled: yes
update-time:  yes
hostname:     <auto>.sn.mynetname.net
```

---

## 16. SNMP

**Disabled hoàn toàn** (`/snmp set enabled=no`).

---

## 17. Đã loại bỏ trong quá trình tối ưu

| Hạng mục | Lý do |
|----------|-------|
| PPTP server | Unsafe protocol |
| L2TP/IPsec server | Thay bằng WireGuard |
| OpenVPN server | Cấu hình lửng, không dùng |
| PPP user `Tuanthesail` | Legacy L2TP user |
| Pool `vpn-pool` (192.168.41.0/24) | L2TP cũ |
| Hotspot service + user `admin` | Decommissioned |
| VLAN `vlan16-WFGuest` (172.16.0.0/22) | Guest WiFi không dùng |
| DHCP guest pool (172.16.0.10-172.16.3.250) | Guest không dùng |
| Route NetNam (172.16.68.0/24, 192.168.100.0/24) | Vendor cũ |
| Trust list NetNam IPs | Vendor không còn quản lý |
| RADIUS `202.151.175.25/.17` | NetNam hotspot auth |
| SNMP community `netdept` + default | NetNam monitoring |
| NTP `101.96.85.22` | NetNam NTP |
| Walled-garden `*.netnam.com` (16 entries) | Portal cũ |
| Identity `DAD\|TheSail-WFCX-NetNamRouter` | Đổi → `TheSail-Router` |
| System note `PowerByNetNam@2024` | Bỏ |
| Routing tables `to-pppoe1/2` | Đổi tên → `to-Vnpt1/2` |

---

## 18. Sơ đồ mạng

```
                    Internet
                  /         \
            VNPT1            VNPT2
           (backup)        (PRIMARY)
              |                |
         ether15           ether16
        (pppoe-out1)     (pppoe-out2)
         distance=2       distance=1
              \  failover  /
               \  (auto)  /
                \        /
              TheSail-Router
                 |   |   |   |
            ┌────┴───┴───┴───┴───────────────┐
            | bri.lan.trunk (192.168.11.0/24)|
            │  ╔═══════╦════════╦══════════╗ │
            │  ║vlan21 ║ vlan31 ║ vlan61   ║ │
            │  ║ CCTV  ║ Office ║Controller║ │
            │  ║.21.0  ║ .31.0  ║  .61.0   ║ │
            │  ╚═══════╩════════╩══════════╝ │
            └────────────────────────────────┘

                wg-vpn (10.10.10.0/24)
                  ↕ WireGuard tunnel ↕
                IT Admin (10.10.10.2)
```

---

## 19. Files liên quan trên Git

Branch `claude/bold-dirac-X4lrM`:

| File | Mô tả |
|------|-------|
| `thesail.txt.rsc` | Config gốc của router (reference) |
| `optimize.rsc` | Script triển khai 9 phases |
| `CONFIG.md` | Tài liệu này |

---

## 20. Liên hệ / lưu ý vận hành

- **Backup định kỳ**: `/system backup save name=YYYY-MM-DD` mỗi tuần
- **Export config**: `/export file=YYYY-MM-DD-config` mỗi khi có thay đổi
- **Theo dõi WireGuard**: `/interface wireguard peers print stats`
- **Kiểm tra failover**: ngắt cáp pppoe-out1 → traffic phải tự chuyển sang pppoe-out2 trong <30s
- **Đổi WireGuard port nếu bị ISP chặn**: 13231, 33445, 51194, 4500
