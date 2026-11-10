# OEM HA/DR Failover Lab

Lab Oracle Enterprise Manager 24.1 giám sát cặp **Active Data Guard** có **Fast-Start Failover**,
chạy trên VirtualBox (Windows). Toàn bộ được dựng và vận hành bằng script.

```
oem24  (192.168.100.10)  EM 24.1 + repository 26ai + FSFO observer
   │
   ├── prm1 (.11)  PRIMARY  ──── SYNC redo ────▶  stb1 (.12)  STANDBY, READ ONLY WITH APPLY
   │               service orclpdb_rw                         service orclpdb_ro
```

- Oracle Linux 9.8, Oracle AI Database 26ai (23.26.1), EM 24.1.0.0
- Data Guard Broker, MaxAvailability, Fast-Start Failover (Zero Data Loss, ngưỡng 30 s, tự reinstate)
- Service theo vai trò: ứng dụng không phải đổi chuỗi kết nối sau failover
- Cảnh báo EM cho độ trễ Data Guard và database ngừng hoạt động → incident + script thông báo
- Monitoring as code: Metric Extension tự viết (tuổi backup, transaction treo), rule set, tự xử lý FRA bằng EM job

> **Trạng thái (10/11/2026):** lab đã ngừng, các VM bị xóa khi cài lại Windows. Repo giữ nguyên để dựng lại.
> Diễn tập monitoring 1–4 đạt; 5 (đổi vai trò) và 6 (gỡ rồi triển khai lại) chưa làm.

## Yêu cầu

- Windows + VirtualBox 7, Git, RAM 24 GB, ổ trống ~80 GB
- Trong `~/Downloads` (edelivery.oracle.com, không cần MOS): `LINUX.X64_2326100_db_home.zip`,
  `V1046951-01.zip` … `V1046955-01.zip`

## Dựng lab

```powershell
Copy-Item config\lab.env.example config\lab.env   # đặt mật khẩu LAB_PWD
.\host\01-build-oem24.ps1       # VM oem24, repository DB, EM 24.1      (~2 h)
.\host\02-build-dataguard.ps1   # prm1, stb1, Broker, Active Data Guard  (~45 m)
.\host\03-register-em.ps1       # agent + target trong EM                (~15 m)
.\host\04-enable-fsfo.ps1       # Fast-Start Failover + observer         (~3 m)
.\host\05-em-alerting.ps1       # ngưỡng, thông báo, incident rule set   (~2 m)
.\host\06-em-monitoring.ps1     # Metric Extension, DB Health Rules, tự xử lý FRA
```

Bước 06 cần làm tay một lần trên Console: deploy Metric Extension lên `orcl_prm1`/`orcl_stb1` (emcli 24.1 không có lệnh deploy). Xem [docs/em-monitoring.md](docs/em-monitoring.md).

## Dùng hằng ngày

```powershell
.\host\start-lab.ps1             # bật lab (oem24 → stb1 → prm1)
.\host\status.ps1                # trạng thái nhanh
.\host\report.ps1 -Label xyz     # báo cáo Markdown vào docs/reports/
.\host\stop-lab.ps1              # tắt lab đúng thứ tự
.\host\test-failover.ps1 -SwitchBack   # diễn tập sự cố primary
.\host\test-alerting.ps1               # diễn tập cảnh báo apply lag
.\host\test-monitoring.ps1 -Drill backup   # diễn tập ME tuổi backup (hoặc -Drill txn)
.\host\test-corrective-action.ps1          # diễn tập tự xử lý FRA (thêm -FailCase: trường hợp thất bại)
```

EM Console: https://localhost:7803/em (`sysman`). SSH: cổng `2222` (oem24), `2223` (prm1), `2224` (stb1).

## Tài liệu

- [docs/runbook.md](docs/runbook.md): switchover, failover, reinstate, kết quả diễn tập
- [docs/em-alerting.md](docs/em-alerting.md): cảnh báo và incident trên EM
- [docs/em-monitoring.md](docs/em-monitoring.md): Metric Extension, tự xử lý FRA, kết quả diễn tập
- [docs/troubleshooting.md](docs/troubleshooting.md): các lỗi đã gặp và cách xử lý
- [docs/reports/](docs/reports/): báo cáo trạng thái

## Lưu ý

- Lab dùng repository 26ai vì EM 24.1 yêu cầu 19c từ 19.22 trở lên (phải tải từ MOS). Chưa đối chiếu bảng Certification.
- Active Data Guard là option phải trả phí trên production.
- `stb1` là linked clone của snapshot `26ai-home-installed` trên prm1. Đừng xóa snapshot này.
