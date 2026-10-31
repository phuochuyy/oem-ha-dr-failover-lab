# Runbook: switchover, failover, reinstate

Các lệnh chạy trên **oem24** với user `oracle`, dùng `TNS_ADMIN` của observer (có wallet SYS cho `prm1` và `stb1`):

```bash
export ORACLE_HOME=/u01/app/oracle/product/23.0.0/dbhome_1
export TNS_ADMIN=/u01/app/oracle/dgobs/network
dgmgrl /@prm1          # hoặc /@stb1 nếu prm1 đang chết
```

Từ Windows, dùng các script trong `host/` (chúng gọi các script tương ứng trong `guest/dataguard/`).

## Kiểm tra trạng thái

```powershell
.\host\status.ps1
```
```
DGMGRL> show configuration
DGMGRL> show fast_start failover
DGMGRL> show database stb1
```

Trạng thái bình thường: `Configuration Status: SUCCESS`, `Fast-Start Failover: Enabled in Zero Data Loss Mode`,
`Observer: obs_oem24`, apply lag và transport lag bằng 0.

## Switchover (có kế hoạch, không mất dữ liệu)

```powershell
Import-Module .\host\lab.psm1
Invoke-LabScript oem24 -Script 'dataguard\switchover.sh' -Arguments stb1      # stb1 lên primary
Invoke-LabScript oem24 -Script 'dataguard\adg_reopen.sh' -Arguments prm1, stb1   # mở ADG trên standby mới
```

- Phải kết nối DGMGRL bằng **`sys/<password>`**. Nếu kết nối bằng wallet `/@db`, Broker không tự khởi động lại được
  instance của primary cũ (ORA-01017) và bạn phải `startup` bằng tay.
- Service `orclpdb_rw` và `orclpdb_ro` tự đổi node nhờ trigger `AFTER DB_ROLE_CHANGE` và `AFTER STARTUP`.

## Failover tự động (Fast-Start Failover)

Không cần thao tác gì. Khi primary mất liên lạc với cả observer lẫn standby quá `FastStartFailoverThreshold`
(30 giây), observer sẽ failover sang target.

Kết quả diễn tập ngày 2026-10-31 (`host\test-failover.ps1`, tắt nóng VM bằng `VBoxManage controlvm poweroff`):

| Mốc | Lần 1 (prm1 sập) | Lần 2 (prm1 sập) | Lần 3 (stb1 sập) |
|---|---|---|---|
| Tắt nóng primary → standby thành primary mới | 47 s | 58 s | 49 s |
| Bật lại primary cũ → được reinstate làm standby | 74 s | (*) | 68 s |
| Dữ liệu mất | 0 | 0 | 0 |

(*) Lần 2, reinstate vẫn thành công, nhưng script lúc đó so khớp sai dòng trạng thái `(*) Physical standby` nên không
ghi nhận được thời gian. Lỗi script đã được sửa.

Khoảng 35 s đầu là ngưỡng `FastStartFailoverThreshold` (30 s) cộng nhịp ping của observer. Phần còn lại là thời gian
failover và mở database. Sau 3 lần failover và 3 lần switchover, bảng `dg_probe` vẫn đủ 13/13 dòng
(MaxAvailability + SYNC, *Zero Data Loss Mode*).

## Failover thủ công (khi không có observer)

```
DGMGRL> connect sys/<password>@stb1
DGMGRL> failover to stb1;                 -- zero data loss nếu standby đã nhận đủ redo
DGMGRL> failover to stb1 immediate;       -- chỉ khi không thể apply hết redo (CÓ THỂ MẤT DỮ LIỆU)
```

## Reinstate primary cũ

Khi bật FSFO với `FastStartFailoverAutoReinstate=TRUE`, observer tự reinstate khi primary cũ khởi động lại
(cần Flashback Database, đã bật trên cả hai node). Nếu làm bằng tay:

```
SQL> startup mount          -- trên primary cũ
DGMGRL> reinstate database prm1;
```

Sau khi reinstate, standby ở trạng thái MOUNTED. Mở lại Active Data Guard:

```powershell
Invoke-LabScript oem24 -Script 'dataguard\adg_reopen.sh' -Arguments prm1, stb1
```

## Bảo trì: tạm tắt FSFO

```
DGMGRL> disable fast_start failover;
DGMGRL> enable fast_start failover;
```

`host\stop-lab.ps1` tắt observer trước khi tắt các database. Observer không failover khi primary được
`shutdown immediate`, nhưng tắt trước sẽ tránh cảnh báo thừa.

## Kết nối ứng dụng

Alias trong `guest/dataguard/dg_tnsnames.ora` liệt kê cả hai host, nên ứng dụng không phải đổi gì sau failover:

| Alias | Service | Chạy ở |
|---|---|---|
| `ORCLPDB_RW` | `orclpdb_rw.localdomain` | node đang là PRIMARY |
| `ORCLPDB_RO` | `orclpdb_ro.localdomain` | node đang là STANDBY (Active Data Guard) |

`guest/dataguard/app_probe.sh` ghi qua RW, đọc qua RO và in ra node nào đã phục vụ từng kết nối.
