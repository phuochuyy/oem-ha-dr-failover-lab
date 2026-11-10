# Diễn tập monitoring, 05/11 và 10/11/2026

Target `orcl_prm1` (PRIMARY). Giờ lấy theo timestamp trong repository EM (giờ Việt Nam). "+N s" tính từ lúc gây lỗi. Host: 24 GB RAM, 3 VM chạy cùng lúc.

## Diễn tập 1: backup quá hạn — 05/11, đạt

Ngưỡng tạm `ME$BACKUP_AGE` warning 0,2 giờ (bình thường 26 / 50). RAM trống 0,4 GB.

| Mốc | Giờ |
|---|---|
| Hạ ngưỡng | 19:32:21 |
| Alert Warning (`BACKUP_AGE_HOURS` = 1) | 19:37:02 (+281 s) |
| Incident 210 + thông báo `DG_LAB_LOG` | 19:37:04 |
| Chạy `rman_backup.sh` (718 MB) | ~19:44:40 |
| Alert clear, incident 210 đóng | 19:47:02 (149 s sau khi bắt đầu backup) |

Ghi chú: script đo không thấy dòng incident trong lúc chờ (lọc theo cửa sổ thời gian), nhưng kết quả cuối cho thấy incident 210 được tạo và tự đóng.

## Diễn tập 2: transaction treo — 05/11, đạt

Mở một transaction không commit trên `orclpdb`, ngưỡng tạm `ME$LONG_TXN` warning 1 phút.

| Mốc | Giờ |
|---|---|
| Mở transaction, hạ ngưỡng | 19:48:22 |
| Alert Warning (1,3 phút), incident 211, thông báo | 19:49:43 (+81 s) |
| Kết thúc session → rollback | ~19:50:15 |
| Alert clear, incident 211 đóng | 19:54:43 |

## Diễn tập 3: FRA cao, tự xử lý thành công — 10/11, đạt ở lần 3

Hai lần trước (05/11 21:37 và 10/11 19:07) chuỗi alert → job chạy đúng nhưng alert không clear: FRA chỉ giảm 15,70 → 14,58 % và 14,49 → 13,36 %, vẫn trên ngưỡng 11 %. Nguyên nhân: ngưỡng đặt theo giá trị trước khi tăng (10,77 %), trong khi việc sinh redo cũng tạo thêm flashback log không thu hồi được, và standby đang đuổi lag nên 2 archive log bị giữ (RMAN-08120). Sửa: ngưỡng = làm tròn lên của `sau khi tăng − archive log + 0,2`.

Lần 3: FRA 13,36 → 14,49 % (archive log 1,22 %), mức sàn dự đoán 13,27 %, ngưỡng warning 14. RAM trống 0,5 GB.

| Mốc | Giờ |
|---|---|
| Tăng FRA, đặt ngưỡng 14 | 19:28:36 |
| Alert Warning 14,49 % | 19:30:46 (+130 s) |
| Thông báo + `FRA_RELIEF_DISPATCH` tạo job | 19:30:47 / 19:30:50 |
| Job `FRA_RELIEF_20261110_193047` chạy | 19:30:50 → 19:30:58, Succeeded |
| FRA sau xử lý | 13,28 % (dự đoán 13,27 %) |
| Alert clear | 19:35:46 (lần thu thập kế tiếp) |

## Diễn tập 4: tự xử lý thất bại — 10/11, đạt

`/u01/backup` đặt chỉ đọc (`chmod 555`). Cần 2 vòng tăng FRA mới có số nguyên phù hợp: 13,28 → 18,10 %, mức sàn 15,88 %, ngưỡng 17. RAM trống 0,4 GB.

| Mốc | Giờ |
|---|---|
| Khóa ghi, đặt ngưỡng 17 | 19:49:05 |
| Alert Warning 18,10 % + thông báo | 19:53:44 (+279 s) |
| Job `FRA_RELIEF_20261110_195344` | 19:53:47 → 19:53:52, **Failed** (rman rc=1) |
| Sau một chu kỳ thu thập | Alert vẫn Warning, không clear |
| Mở lại thư mục, chạy dọn | 20:00:06 → 20:00:17, FRA 18,11 → 15,88 % |

Sau diễn tập: ngưỡng FRA trả về 85 / 97; Data Guard `SUCCESS`.

## Ghi nhận khác

- Lúc khởi động lab sau 5 ngày tắt: incident apply lag Critical (421 697 s) trên `orcl_stb1`, tự hết khi standby đuổi kịp. `ME$BACKUP_AGE` Critical (119 giờ) vì không backup trong thời gian tắt, đây là cảnh báo đúng.
- Ổ C: của host tụt dưới 5 GB trong diễn tập 4 do pagefile phình khi RAM cạn; `Assert-LabDisk` đã chặn một lần chạy.
