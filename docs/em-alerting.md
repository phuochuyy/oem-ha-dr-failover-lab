# EM: cảnh báo và incident cho Data Guard

```powershell
.\host\05-em-alerting.ps1     # script thông báo + ngưỡng + phương thức thông báo + import rule set
.\host\test-alerting.ps1      # tắt apply trên standby, chờ cảnh báo → incident → thông báo, rồi bật lại
```

## Thành phần

| Thành phần | Cấu hình | Cách tạo |
|---|---|---|
| Ngưỡng | *Data Guard Performance*: Apply Lag, Transport Lag; Warning 30 s / Critical 60 s | `emcli modify_threshold` |
| Lịch thu thập | collection `dataguard_11gR2` mỗi 1 phút (mặc định 5 phút) | `emcli modify_collection_schedule -force` |
| Phương thức thông báo | OS Command `DG_LAB_LOG` → `/u01/app/oracle/em_notify/dg_event_log.sh` | API của trang *Scripts and SNMP Traps* (`EMD_NOTIFICATION.ADD_PROGRAM_DEVICE`); không có emcli |
| Rule set | `DG Lab Rules` cho `orcl_prm1`, `orcl_stb1` | `emcli import_incident_rule_set` từ [config/em/DG_Lab_Rules.xml](../config/em/DG_Lab_Rules.xml) |
| Rule 1 | **DG metric alerts**: Apply Lag, Transport Lag, Data Guard Status; mức Warning/Critical → incident + `DG_LAB_LOG` | trong XML |
| Rule 2 | **DG target down**: database ngừng hoạt động → incident + `DG_LAB_LOG` | trong XML |

`dg_event_log.sh` ghi mỗi thông báo thành một dòng trong `/u01/app/oracle/em_notify/events.log`; biến môi trường
EM truyền vào được lưu ở `events/<thời điểm>.env`.

## Kết quả

Diễn tập 2026-10-31 19:33 (tắt apply trên stb1). Ghi chú của event trong EM:

```
Incident created by rule (Name= DG Lab Rules, DG metric alerts; Owner=SYSMAN).
The following notifications will be sent:  1 os command(s)
Called DG_LAB_LOG:/u01/app/oracle/em_notify/dg_event_log.sh (Rule Owner=SYSMAN, Rule Name=DG Lab Rules,DG metric alerts). Command exited with code=0
```

`events.log`:

```
2026-10-31 19:33:57 | Warning  | orcl_stb1  | Metric Alert | The standby database is approximately 46 seconds behind the primary database. | incident=...
```

Incident tự đóng khi lag về 0 (Clear lúc 19:35).

Diễn tập đầy đủ bằng `test-alerting.ps1` với ngưỡng chuẩn 30/60 (19:37–19:41):

| Thời điểm | Cảnh báo | Incident | `events.log` |
|---|---|---|---|
| 19:38:32 | Warning (41 s) | #200 tạo bởi `DG Lab Rules` | `Warning \| orcl_stb1` |
| 19:39:32 | Critical (101 s) | #200 nâng lên Critical | `Critical \| orcl_stb1` |
| 19:40:32 | Clear | #200 tự đóng | (không gửi khi Clear) |

## Định dạng XML (khi cần sửa tay)

File theo đúng định dạng `export_incident_rule_set` của EM 24.1:

- Mỗi rule cần `<EventClass>` (`metric_alert`, `target_availability`). Thiếu phần tử này thì giao diện không sửa được
  rule (ô *Type* bị khóa, báo "please select type").
- Mỗi metric cụ thể là một `<EventClassSpecificAttributeGroup>`; tên thuộc tính trong nhóm có dạng
  `<thuộc tính>|<event class>` (`metric_group|metric_alert`, `metric_column|metric_alert`); `sys_target_type` giữ
  nguyên. Sai tên → `JBO-27014: Attribute AttrId ... is required`.
- **`sys_severity` dùng mã của mô hình event**: `8` = WARNING, `16` = CRITICAL, `32` = FATAL, `0` = CLEAR
  (bảng `EM_EVENT_ATTR_ENUM`). Mã cảnh báo kiểu cũ `20`/`25` (`MGMT_GLOBAL.G_SEVERITY_*`) vẫn import và biên dịch được
  nhưng **không bao giờ khớp event**: rule im lặng, không lỗi gì.
- Cách an toàn nhất để thay đổi: sửa trên giao diện (Setup → Incidents → Incident Rules) rồi
  `emcli export_incident_rule_set` ghi đè file này.

## Giới hạn: metric độ trễ chỉ có trên target từng là standby

EM gán bộ metric Data Guard theo vai trò của database **lúc được discover**. `orcl_stb1` có *Data Guard Performance*
(`dataguard_sperf_112`); `orcl_prm1` (discover khi là primary) chỉ có `dataguard` (Data Guard Status) và
`dataguard_pperf`. Khi prm1 làm standby, EM không cảnh báo được apply lag của nó (rule *Data Guard Status* vẫn chạy).
Script ngưỡng tự bỏ qua target chưa có metric; rediscover prm1 khi nó đang là standby sẽ khắc phục được.

## Kiểm tra nhanh

```powershell
Import-Module .\host\lab.psm1
Invoke-LabScript oem24 -Script 'em\alert_status.sh' -Arguments 30   # incident, lịch sử cảnh báo lag, events.log
```

`MGMT$INCIDENTS` và `MGMT$EVENTS` lưu giờ theo **UTC**; `alert_status.sh` đã quy đổi về giờ Việt Nam.
Ghi chú trên event (`MGMT$EVENT_ANNOTATION`, join theo `EVENT_SEQ_ID`) cho biết rule nào đã khớp và thông báo nào
đã được gửi — đây là chỗ nhìn đầu tiên khi rule "không chạy".
