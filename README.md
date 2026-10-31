# OEM HA/DR Failover Lab

Lab Oracle Enterprise Manager 24.1 giám sát cặp **Active Data Guard** có **Fast-Start Failover**, chạy trên
VirtualBox trong một máy Windows. Toàn bộ lab được dựng bằng script (PowerShell trên host, bash trong VM).

```
                Windows host (VirtualBox)            NAT network "oemnet" 192.168.100.0/24
 ┌──────────────────────────────────────────────────────────────────────────────────────┐
 │  oem24  .10   OEM 24.1 (OMS + agent)                                                  │
 │               repository: 26ai CDB emcdb / PDB empdb                                  │
 │               FSFO observer "obs_oem24" (systemd: dg-observer)                        │
 │                     │ ping / failover                     │ ping                      │
 │                     ▼                                     ▼                           │
 │  prm1  .11   PRIMARY  CDB orcl / PDB orclpdb  ──SYNC redo──▶  stb1  .12  PHYSICAL STANDBY│
 │              service orclpdb_rw                              READ ONLY WITH APPLY (ADG)│
 │              EM agent                                        service orclpdb_ro       │
 │                                                              EM agent                 │
 └──────────────────────────────────────────────────────────────────────────────────────┘
```

| Thành phần | Cấu hình |
|---|---|
| OS | Oracle Linux 9.8 (kickstart, cài qua mạng từ yum.oracle.com) |
| Database | Oracle AI Database 26ai 23.26.1 EE (tất cả các node) |
| EM | Enterprise Manager Cloud Control 24.1.0.0, deployment Small |
| Data Guard | Broker config `dgconf`, MaxAvailability, `LogXptMode=SYNC` |
| FSFO | Zero Data Loss Mode, threshold 30 s, auto-reinstate, observer trên oem24 |
| Ứng dụng | Service theo vai trò `orclpdb_rw` / `orclpdb_ro` + alias TNS có cả hai host |

## Yêu cầu

- Windows 10/11 + VirtualBox 7.x (`VBoxManage` trong PATH), OpenSSH client có sẵn, Git
- RAM **24 GB** (OEM24 12 GB + prm1 4 GB + stb1 4 GB), ổ trống **~80 GB** khi dựng (~60 GB sau khi `fstrim`)
- Trong `~/Downloads` (tải từ edelivery.oracle.com, không cần MOS):
  - `LINUX.X64_2326100_db_home.zip` (Oracle AI Database 26ai)
  - `V1046951-01.zip` … `V1046955-01.zip` (EM 24.1 cho Linux x86-64)

Boot ISO Oracle Linux được script tự tải về.

## Dựng lab

```powershell
Copy-Item config\lab.env.example config\lab.env     # đặt LAB_PWD và đường dẫn; file này bị gitignore
.\host\01-build-oem24.ps1        # ~2 h : VM oem24, repository DB, EM 24.1
.\host\02-build-dataguard.ps1    # ~45 m: prm1, stb1 (linked clone), Broker, ADG, role services
.\host\03-register-em.ps1        # ~15 m: agent lên prm1/stb1, target database + listener
.\host\04-enable-fsfo.ps1        # ~3 m : MaxAvailability, FSFO, observer trên oem24
```

> Các bước trong `01`–`03` được rút ra từ lần dựng lab thật, nhưng **chưa được chạy lại từ đầu bằng chính
> các script này**. `04`, `start-lab`, `stop-lab`, `status` và `test-failover` đã chạy thử trên lab đang hoạt động.

## Vận hành hằng ngày

```powershell
.\host\start-lab.ps1             # oem24 → stb1 → prm1; DB, EM, observer tự khởi động qua systemd
.\host\start-lab.ps1 -EmOnly     # chỉ bật oem24
.\host\status.ps1                # trạng thái VM, Data Guard, FSFO, observer, RAM host
.\host\stop-lab.ps1              # OMS → observer → primary → standby → repository DB → tắt VM
```

| Truy cập | |
|---|---|
| EM Console | https://localhost:7803/em (`sysman`) |
| WebLogic Admin | https://localhost:7102/console (`weblogic`) |
| SSH | `ssh -i ~/.ssh/oem24_ed25519 -p 2222` (oem24), `2223` (prm1), `2224` (stb1), user `oracle` hoặc `root` |

## Diễn tập sự cố

```powershell
.\host\test-failover.ps1 -SwitchBack
```

Script sẽ tắt nóng primary hiện tại, chờ observer failover, kiểm tra đường đi của ứng dụng, bật lại primary cũ,
chờ observer reinstate, mở lại Active Data Guard rồi switchover trở về. Kết quả và các lệnh thủ công nằm trong
[docs/runbook.md](docs/runbook.md).

## Cấu trúc repo

```
config/      lab.env.example (mẫu cấu hình; lab.env thật bị gitignore)
host/        PowerShell trên Windows: lab.psm1 (ssh/scp helper), 01–04 build, start/stop/status, test-failover
guest/       bash chạy trong VM, được scp lên rồi chạy với ~/.lab.env
  common/      chuẩn bị OS, cài DB home, autostart (systemd)
  oem24/       repository DB, cài EM, mạng oemnet
  dataguard/   primary/standby, Broker, ADG, role services, FSFO, observer, probe, switchover
  em/          emcli: cài agent, thêm target, kiểm tra vai trò Data Guard
kickstart/   file kickstart cho VBoxManage unattended
docs/        runbook.md, troubleshooting.md
```

## Lưu ý

- **License:** Active Data Guard và Fast-Start Failover dùng cho học tập trong lab. Trên production,
  Active Data Guard là option phải trả phí.
- **Chứng nhận:** chưa đối chiếu với MOS rằng EM 24.1.0.0 hỗ trợ repository 26ai. Lab dùng 26ai vì bản 19c cần
  RU 19.22+ (phải tải từ MOS). Xem [docs/troubleshooting.md](docs/troubleshooting.md).
- **Mật khẩu:** một mật khẩu chung `LAB_PWD` cho mọi tài khoản, chỉ phù hợp với lab.
- `stb1` là **linked clone** của snapshot `26ai-home-installed` trên prm1. Đừng xóa snapshot này.
