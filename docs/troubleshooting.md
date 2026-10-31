# Lỗi đã gặp khi dựng lab và cách xử lý

Ghi lại các lỗi thực tế gặp khi dựng lab này, để lần dựng lại không vấp lại.

## EM 24.1 từ chối repository 19.3

```
ERROR: You have provided the Oracle Database version 19.3.0.0.190416 that is not supported.
Ensure to provide Oracle Database version 19.22 or higher to proceed with the installation.
```

EM 24.1 cần repository 19c **từ 19.22** trở lên. Bản 19.22+ chỉ có dưới dạng Release Update trên My Oracle Support
(cần CSI có quyền download). Lab này dùng **Oracle AI Database 26ai (23.26.1)**, tải miễn phí từ edelivery,
và bộ cài EM 24.1 chấp nhận phiên bản này.

> Chưa đối chiếu bảng Certification trên MOS cho tổ hợp EM 24.1.0.0 + repository 26ai.
> Đủ cho lab, nhưng chưa phải cấu hình đã được chứng nhận cho production.

## Cài DB 19.3 trên Oracle Linux 9 lỗi link

Bản gốc 19.3 không được hỗ trợ trên OL9 (cần RU 19.19+ qua `runInstaller -applyRU`). Nếu buộc phải thử:

| Lỗi | Nguyên nhân | Workaround (chỉ cho lab) |
|---|---|---|
| `cannot find /usr/lib64/libpthread_nonshared.a` | glibc 2.34 gộp pthread vào libc | `ar rc /usr/lib64/libpthread_nonshared.a` (archive rỗng) |
| `undefined reference to 'stat'` khi link `orion` | `$ORACLE_HOME/lib/stubs` chứa stub glibc 2.17 | xóa `lib/stubs/libc.so*`, `libc-2.17.0-stub.so` trước khi cài |
| `cannot find -lgcc_s` | xóa **cả** thư mục stubs | chỉ xóa stub libc, giữ phần còn lại |
| `cannot find -lclntshcore` khi cài lại | lần cài lỗi trước làm hỏng home | xóa home, giải nén lại từ đầu |

Bản 26ai được chứng nhận trên OL9 nên không cần workaround nào.

## EM installer: thiếu dung lượng

```
Disk Space Required : 37.3 GB   Disk Space Available : 34.0 GB
```

Installer tính dung lượng trống của `/u01` **sau khi** đã giải nén chính nó vào `java.io.tmpdir`.
Cách xử lý: cho thư mục tạm nằm trên `/` (`-J-Djava.io.tmpdir=/var/tmp/emtmp`), xem `guest/oem24/em_install.sh`.

## EM prereq: `_allow_insert_with_update_check`

Prereq kit báo **Failed** nếu tham số ẩn này chưa là `TRUE`. Không truyền được qua `dbca -initParams`,
phải `alter system set "_allow_insert_with_update_check"=TRUE` sau khi tạo DB (có trong `repo_db_create.sh`).

## Standby không đăng ký service với listener (ORA-12514)

DBCA đặt `local_listener=LISTENER_ORCL`, một alias chỉ có trong `tnsnames.ora` của prm1. Spfile được RMAN duplicate
chép sang stb1 nên instance standby không đăng ký được. Cách xử lý: đặt địa chỉ tường minh
`(ADDRESS=(PROTOCOL=TCP)(HOST=<node>.localdomain)(PORT=1521))` trên cả hai node
(`primary_create.sh` và `set local_listener` trong `standby_create.sh`).

## PDB trên standby không tự mở sau khi restart

`alter pluggable database ... save state` chỉ có tác dụng trên primary. Sau khi restart, ADG standby (hoặc primary cũ
vừa được reinstate) mở CDB READ ONLY nhưng `orclpdb` vẫn MOUNTED, nên service `orclpdb_ro` không lên.
Cách xử lý: trigger `AFTER STARTUP` ở CDB root chạy `alter pluggable database all open` (trong `role_services.sh`).

Sau khi standby restart bằng `STARTUP` thường, Broker mất khoảng **1 phút** để bật lại redo apply. Trong khoảng đó
apply lag tăng và FSFO tạm báo target chưa đồng bộ. Đây là hành vi bình thường.

## Switchover báo ORA-01017 khi khởi động lại primary cũ

```
Operation requires start up of instance "orcl" on database "stb1"
Starting instance "orcl"...
ORA-01017: invalid credential or not authorized; logon denied
```

Switchover vẫn hoàn tất, nhưng primary cũ bị để ở trạng thái tắt. Nguyên nhân là DGMGRL đăng nhập bằng wallet
(`dgmgrl /@prm1`): Broker coi đó là xác thực ngoài nên không dùng để khởi động instance từ xa.
Cách xử lý: switchover bằng `dgmgrl sys/<password>@db` (`switchover.sh`). Nếu đã lỡ, `startup` instance đó bằng tay.

## EM: "Data Guard Internal Error" khi bấm Switchover

Trên giao diện chỉ hiện `Data Guard Internal Error : Refer to the Management Server Logs for more information`.
Trong `gc_inst/em/EMGC_OMS1/sysman/log/emoms.trc` có:

```
ERROR em.dataguard onEvent.2159 - java.lang.NullPointerException
    at oracle.sysman.db.dg.SwitchoverBean.preChecks(SwitchoverBean.java:1346)
```

Xem bytecode bằng `javap` (`guest/em/inspect_dg_precheck.sh`) thì thấy bước pre-check đọc thuộc tính Broker
**`DbDisplayName`** của primary và standby, rồi so sánh với tên target EM mà không kiểm tra null. Khi cấu hình
Data Guard được tạo bằng wizard của EM, EM tự điền thuộc tính này. Cấu hình tạo bằng DGMGRL thì để trống (`''`).

Cách xử lý (`guest/em/set_dg_display_names.sh`, chạy ở cuối `04-enable-fsfo.ps1`):

```
DGMGRL> edit database prm1 set property DbDisplayName='orcl_prm1';
DGMGRL> edit database stb1 set property DbDisplayName='orcl_stb1';
```

Giá trị phải **trùng tên target database trong EM**.

## EM: incident rule set tạo ngoài giao diện không chạy

- Rule set tạo bằng API PL/SQL của repository (`EM_INCIDENT_RULES`) không khớp event: thiếu phần biên dịch của
  tầng Java, dễ thành loại *Personal*, và điều kiện lưu khác với giao diện. **Đừng dùng cách này.**
- Cách chuẩn: tạo rule set trên giao diện → `emcli export_incident_rule_set` → lưu XML →
  `emcli import_incident_rule_set` (+ `modify_incident_rule -action=enable`).
- Rule set mới import vào ở trạng thái disabled; emcli nhắc *"Review it and enable before saving"*. Trong lab, rule set
  import rồi enable bằng emcli vẫn chưa khớp event; xem bước lưu trên giao diện trong [em-alerting.md](em-alerting.md).
- `-overwrite_existing_ruleset` lên một rule set lỗi báo `JBO-25028 ... Overflow Exception`: xóa rule set đó trước.

## EM: truy vấn incident/event "không thấy gì"

`MGMT$INCIDENTS` và `MGMT$EVENTS` lưu giờ **UTC**. Lọc bằng `sysdate - x` (giờ +07) sẽ loại bỏ dữ liệu mới.
Dùng `cast(sys_extract_utc(systimestamp) as date) - x`.

## PowerShell 5.1 → ssh

- Dấu `"` trong tham số truyền cho `ssh.exe` bị PowerShell 5.1 nuốt mất, ví dụ `"_allow_insert_with_update_check"`
  biến thành `_allow...` và gây ORA-00911.
- Pipe chuỗi vào `ssh ... bash -s` bị chèn BOM vào đầu dòng (`﻿source: command not found`),
  kể cả khi đã đặt `$OutputEncoding` không BOM.

Cách xử lý thống nhất trong repo: **scp file script rồi chạy bằng `bash`**
(`Invoke-LabScript` trong `host/lab.psm1`).

Không dùng `$ErrorActionPreference = 'Stop'` trong các script host: `VBoxManage` in tiến độ (`0%...100%`) ra stderr,
và dưới `Stop` thì PowerShell 5.1 coi đó là lỗi nghiêm trọng rồi dừng script. Lần diễn tập đầu đã bị ngắt ngay sau
khi tắt primary vì lỗi này.

## emcli submit_add_host: "host names are invalid"

Danh sách host phải ngăn cách bằng `;`, không phải `,`:
`-host_names="prm1.localdomain;stb1.localdomain"`.

## Dung lượng ổ host

File VDI chỉ tăng chứ không tự co lại khi xóa file trong VM. Ổ ảo được gắn với `--discard on`, nên chạy
`fstrim -a` trong VM sau khi xóa file lớn để trả lại dung lượng cho Windows (lần đầu thu hồi được khoảng 12 GB).
