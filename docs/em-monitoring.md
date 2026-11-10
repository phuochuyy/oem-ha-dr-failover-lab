# Monitoring as code trên EM 24.1

Phần này mở rộng lab Data Guard bằng các metric tự viết, rule cảnh báo, và một bước tự xử lý sự cố (corrective action) cho FRA. Cấu hình nằm trong Git, kết quả được đo bằng diễn tập.

Trạng thái: diễn tập 1–4 đạt; diễn tập 5–6 chưa làm (xem cuối file). Chỉ dùng tính năng có sẵn trong EM Base, metric chỉ đọc `V$`, không dùng `DBA_HIST_*`/ASH.

## Thành phần

| Thành phần | File | Ghi chú |
|---|---|---|
| ME `ME$BACKUP_AGE` | `guest/monitoring/metrics/backup_age.sql`, `config/em/monitoring/metric_extensions/BACKUP_AGE/` | Số giờ từ lần backup DB thành công gần nhất. Ngưỡng 26 / 50 giờ. Không trả dòng nào khi là standby |
| ME `ME$LONG_TXN` | `guest/monitoring/metrics/long_txn.sql`, `.../LONG_TXN/` | Số phút của transaction mở lâu nhất (`V$TRANSACTION`). Ngưỡng 30 / 60 phút. Không trả dòng khi là standby |
| FRA | metric có sẵn **Recovery Area Used Space (%)** (`Recovery_Area`) | Đã tính phần reclaimable nên không cần ME thứ ba. Chu kỳ thu thập hạ từ 15 xuống 5 phút |
| Rule set `DB Health Rules` | `config/em/monitoring/DB_Health_Rules.xml` | Alert của ME → incident + `DG_LAB_LOG`; alert FRA → `FRA_RELIEF_DISPATCH` |
| Tự xử lý FRA | `guest/monitoring/ca/fra_relief_dispatch.sh`, `ca/fra_relief.sh` | Xem phần dưới |
| RMAN | `guest/monitoring/backup/rman_setup.sh`, `rman_backup.sh` | Backup nén ra `/u01/backup` (ngoài FRA), redundancy 1, deletion policy `APPLIED ON ALL STANDBY BACKED UP 1 TIMES` |
| Giảm nhiễu ORA-600 | `guest/monitoring/noise_cdbjob.sh` | Tắt collection `cdbjob_status` trên target standby (truy vấn `CDB_*` song song gây ORA-600 `[ktpStSlTx:!Tmppxid]` trên ADG) |
| Triển khai | `host/06-em-monitoring.ps1` → `guest/monitoring/setup.sh` | Chạy lại được nhiều lần |
| Diễn tập | `host/test-monitoring.ps1`, `host/test-corrective-action.ps1`, `guest/monitoring/drill/` | Hạ ngưỡng tạm thời, đo mốc thời gian, trả ngưỡng về |

## Luồng tự xử lý FRA

```
Recovery Area Used Space vượt ngưỡng (thu thập mỗi 5 phút)
  → incident rule "FRA relief" (DB Health Rules)
  → notification method OS Command FRA_RELIEF_DISPATCH (trên OMS)
  → emcli create_job: job OSCommand trên host của DB đang báo động, dùng named credential
  → fra_relief.sh:
       chỉ chạy khi là PRIMARY và giữ được flock
       backup archive log chưa backup ra /u01/backup
       delete archivelog theo deletion policy (không FORCE)
       lỗi → exit khác 0 → job Failed, alert vẫn mở
```

Vì sao không dùng Corrective Action gắn vào metric: emcli 24.1 không có lệnh gắn CA vào ngưỡng, và trên Console việc lưu CA cho `orcl_prm1` không giữ được. Dùng rule + job thì toàn bộ là script, và job hiện trong EM kèm output.

An toàn: không bao giờ xóa archive log chưa apply trên standby hoặc chưa backup. RMAN-08120 (log bị giữ vì chưa apply) được coi là cảnh báo, không phải lỗi.

## Kết quả diễn tập

Chi tiết từng mốc: [reports/2026-11-10-monitoring-drills.md](reports/2026-11-10-monitoring-drills.md).

| # | Diễn tập | Kết quả | Số đo |
|---|---|---|---|
| 1 | Backup quá hạn (`ME$BACKUP_AGE`, ngưỡng tạm 0,2 giờ) | Đạt | Alert + incident + thông báo; chạy backup → clear sau 149 s |
| 2 | Transaction treo (`ME$LONG_TXN`, ngưỡng tạm 1 phút) | Đạt | Alert, incident, thông báo cùng lúc (+81 s); rollback → clear ở lần thu thập kế tiếp |
| 3 | FRA cao, tự xử lý thành công | Đạt (lần 3) | Alert → job xong trong 12 s; FRA 14,49 → 13,28 %; tự clear ở lần thu thập kế tiếp |
| 4 | Tự xử lý thất bại (`/u01/backup` chỉ đọc) | Đạt | Job Failed (rman rc=1), alert vẫn mở, có thông báo |
| 5 | Đổi vai trò (`test-failover.ps1 -SwitchBack`) | Chưa làm | |
| 6 | Gỡ và triển khai lại | Chưa làm | |

Data Guard báo `SUCCESS`, lag 0 sau mỗi diễn tập.

## Bài học

- **FRA có "mức sàn".** Online redo (9,1 %) và flashback log trong `db_flashback_retention_target` (24 giờ) không thu hồi được. Bản thân việc sinh redo để giả lập cũng làm flashback log tăng. Hai lần đầu diễn tập 3 không clear vì ngưỡng đặt theo giá trị *trước* khi tăng. Cách đúng: ngưỡng phải lớn hơn `giá trị sau khi tăng − phần archive log`, tức mức tự xử lý có thể đạt tới. Trên production, tự xử lý bằng cách xóa archive log không giải quyết được FRA đầy do flashback log.
- Ngưỡng của metric `Recovery_Area` phải là số nguyên (ORA-13900 với số thập phân).
- Với metric có key, CA/rule gắn ở dòng "All others" (key `" ;"`); đặt key `RECOVERY AREA;` sẽ tạo một dòng riêng không có hành động.
- Incident rule dùng mã mức độ của event model: 8 = WARNING, 16 = CRITICAL.
- emcli 24.1 có import/export/draft/publish cho ME nhưng không có lệnh tạo mới hay deploy lên target: lần deploy đầu làm trên Console. Monitoring template nhập từ XML viết tay không hiện trên Console và không có lệnh xóa, nên đã bỏ template.
- Sau khi lab tắt nhiều ngày, standby phải đuổi lag lúc khởi động; tự xử lý chạy lúc đó sẽ bị RMAN-08120 giữ log lại. `fra_raise.sh` giờ chờ standby apply xong mới báo kết quả.

## Giới hạn

- Thời gian phát hiện phụ thuộc chu kỳ thu thập 5 phút (0–5 phút).
- Host chỉ có 24 GB RAM, lúc đo còn 0,4–1,2 GB trống; số đo trên máy đủ RAM có thể nhanh hơn.
- Diễn tập dùng ngưỡng hạ tạm thời, không làm FRA đầy thật.
- Không có recovery catalog: sau failover, primary mới không thấy backup của primary cũ → `ME$BACKUP_AGE` báo động. Đây là cảnh báo đúng.
- Chưa có số đo xử lý thủ công để so sánh, nên không nêu "giảm từ X xuống Y phút".
