# EM: cảnh báo và incident cho Data Guard

```powershell
.\host\05-em-alerting.ps1     # script thông báo + ngưỡng + phương thức thông báo + import rule set
.\host\test-alerting.ps1      # tắt apply trên standby ~8 phút, theo dõi cảnh báo/incident/thông báo, bật lại
```

## Thành phần

| Thành phần | Cấu hình | Cách tạo | Trạng thái |
|---|---|---|---|
| Ngưỡng | *Data Guard Performance*: Apply Lag và Transport Lag, Warning 30 s / Critical 60 s | `emcli modify_threshold` | ✅ đã kiểm chứng |
| Lịch thu thập | collection `dataguard_11gR2` mỗi 1 phút (mặc định 5 phút) | `emcli modify_collection_schedule -force` | ✅ |
| Incident | Cảnh báo Critical → incident, tự đóng khi lag về 0 | rule mặc định của Oracle `METRIC_ALERT_INCIDENT_CREATION` | ✅ |
| Phương thức thông báo | OS Command `DG_LAB_LOG` → `/u01/app/oracle/em_notify/dg_event_log.sh` | API của trang *Scripts and SNMP Traps* (`EMD_NOTIFICATION.ADD_PROGRAM_DEVICE`) | đã tạo |
| Rule set | `DG Lab Rules` (Enterprise) cho `orcl_prm1`, `orcl_stb1`: cảnh báo metric Warning/Critical và sự kiện availability → incident + `DG_LAB_LOG` | `emcli import_incident_rule_set` từ [config/em/DG_Lab_Rules.xml](../config/em/DG_Lab_Rules.xml) | ⚠️ đã import, **chưa khớp event** |

## Kết quả diễn tập (2026-10-31, tắt apply trên stb1)

| Lượt | Warning | Critical | Incident | Clear | Thông báo `DG_LAB_LOG` |
|---|---|---|---|---|---|
| 1 | 17:25 (39 s) | 17:26 (98 s) | #170 | 17:35 | — (rule set lúc đó dựng bằng PL/SQL, không dùng nữa) |
| 2 | 17:38 (31 s) | 17:39 (91 s) | #171 | 17:46 | — |
| 3 | — | 17:59 (89 s) | #175 | 18:06 | không (rule set đã import) |
| 4 | 18:16 (59 s) | 18:17 (119 s) | #187 | 18:24 | không (sau khi khởi động lại OMS) |

Mọi incident đều do rule mặc định của Oracle tạo. `DG Lab Rules` không có ghi chú nào trên event, và hàng đợi
thông báo (`EM_NOTIFY_Q`, `MGMT_NOTIFY_LOG`) trống.

## Bước còn lại (trên giao diện)

Khi import, emcli in ra: *"Rule set is disabled by default during import operation. Review it and enable before saving
the rule set."* Bước chuẩn tiếp theo là mở rule set trên giao diện và lưu lại:

1. **Setup → Incidents → Incident Rules**, chọn `DG Lab Rules` → **Edit...**
2. Kiểm tra tab **Targets** (orcl_prm1, orcl_stb1) và tab **Rules** (2 rule). Có thể sửa *DG metric alerts* thành
   **Specific metric alerts** → Data Guard Performance (Apply Lag, Transport Lag) + Data Guard Status, để chỉ báo
   các metric Data Guard.
3. **Save**.
4. Export lại để repo luôn giữ bản đã được giao diện chuẩn hóa:
   ```
   emcli export_incident_rule_set -rule_set_name="DG Lab Rules" -rule_set_owner=SYSMAN -export_file=/tmp/
   ```
   rồi chép file về `config/em/DG_Lab_Rules.xml`.
5. Chạy `.\host\test-alerting.ps1`. Thành công khi `events.log` có dòng `| Critical | orcl_stb1 |`.

## Giới hạn: metric độ trễ chỉ có trên target từng là standby

EM gán bộ metric Data Guard theo vai trò của database **lúc được discover**. `orcl_stb1` có *Data Guard Performance*
(`dataguard_sperf_112`); `orcl_prm1` (discover khi là primary) chỉ có `dataguard` (Data Guard Status) và
`dataguard_pperf`. Khi prm1 làm standby, EM không cảnh báo được apply lag của nó. Script ngưỡng tự bỏ qua target
chưa có metric; rediscover prm1 khi nó đang là standby sẽ khắc phục được.

## Kiểm tra nhanh

```powershell
Import-Module .\host\lab.psm1
Invoke-LabScript oem24 -Script 'em\alert_status.sh' -Arguments 30   # incident, lịch sử cảnh báo lag, events.log
```

`MGMT$INCIDENTS` và `MGMT$EVENTS` lưu giờ theo **UTC**; `alert_status.sh` đã quy đổi về giờ Việt Nam.
