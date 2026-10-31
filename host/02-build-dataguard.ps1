# Build prm1 (primary) and stb1 (Active Data Guard standby, linked clone of prm1) with Data Guard Broker.
# Requires host\01-build-oem24.ps1 (NAT network oemnet, boot ISO, SSH key). Takes ~45 min.
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force
$cfg = Get-LabConfig
$iso = Join-Path $cfg.LAB_ISO_DIR (Split-Path $cfg.OL_BOOT_ISO_URL -Leaf)
$tns = Join-Path $RepoRoot 'guest\dataguard\dg_tnsnames.ora'

Write-LabStep 'Create VM prm1 and install OL9'
$ks = Join-Path $env:TEMP 'dg_node_ks.cfg'
$pub = (Get-Content "$($cfg.LAB_SSH_KEY).pub").Trim()
[IO.File]::WriteAllText($ks, ((Get-Content (Join-Path $RepoRoot 'kickstart\dg_node_ks.cfg') -Raw) -replace '@@LAB_SSH_PUBKEY@@', $pub).Replace("`r`n", "`n"))
$dir = Join-Path $cfg.LAB_VM_DIR 'prm1'
VBoxManage createvm --name prm1 --ostype Oracle9_64 --register
VBoxManage modifyvm prm1 --memory $cfg.DG_MEM_MB --cpus 2 --ioapic on --firmware bios --graphicscontroller vmsvga --vram 16 `
    --nic1 natnetwork --nat-network1 oemnet --audio-enabled off --usb off --boot1 dvd --boot2 disk --boot3 none --boot4 none
VBoxManage createmedium disk --filename "$dir\prm1.vdi" --size 61440 --format VDI --variant Standard
VBoxManage storagectl prm1 --name SATA --add sata --controller IntelAhci --portcount 2 --hostiocache on
VBoxManage storageattach prm1 --storagectl SATA --port 0 --device 0 --type hdd --medium "$dir\prm1.vdi" --nonrotational on --discard on
VBoxManage storageattach prm1 --storagectl SATA --port 1 --device 0 --type dvddrive --medium $iso
VBoxManage unattended install prm1 --iso=$iso --user=oracle --password=$($cfg.LAB_PWD) --hostname=prm1.localdomain `
    --time-zone=Asia/Ho_Chi_Minh --locale=en_US --script-template=$ks --start-vm=headless
Wait-LabSsh prm1 -TimeoutSec 2400

Write-LabStep 'prm1: OS prep + 26ai home'
Initialize-LabNodeEnv prm1
Invoke-LabScript prm1 -User root -Script 'common\os_prep_root.sh' -Arguments 'orcl'
Copy-LabFile prm1 -Path (Join-Path $cfg.LAB_DOWNLOADS $cfg.DB_HOME_ZIP) -Destination '/u01/stage/'
Invoke-LabScript prm1 -Script 'common\db_home_install.sh' -Arguments "/u01/stage/$($cfg.DB_HOME_ZIP)"
Invoke-LabScript prm1 -User root -Script 'common\db_home_root.sh'

Write-LabStep 'Snapshot prm1 and linked-clone stb1'
Invoke-LabSsh prm1 -User root -Command 'rm -rf /u01/tmp/*; fstrim -a; systemctl poweroff' 2>$null
Wait-LabVMState prm1 poweroff
VBoxManage storageattach prm1 --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
VBoxManage snapshot prm1 take '26ai-home-installed' --description 'OL9 + 26ai home, before DB creation (base for stb1 linked clone)'
VBoxManage clonevm prm1 --snapshot '26ai-home-installed' --options link --name stb1 --register
VBoxManage startvm stb1 --type headless
Wait-LabSsh prm1        # the clone still answers on prm1's address
Invoke-LabScript prm1 -User root -Script 'dataguard\stb1_reconfig_root.sh'
Start-Sleep 20
VBoxManage startvm prm1 --type headless
Wait-LabSsh stb1; Wait-LabSsh prm1

Write-LabStep 'Listeners + tnsnames'
foreach ($n in 'prm1', 'stb1') {
    Copy-LabFile $n -Path $tns -Destination '/tmp/dg_tnsnames.ora'
    Invoke-LabScript $n -Script 'dataguard\net_config.sh' -Arguments $n
}

Write-LabStep 'Primary database on prm1'
Invoke-LabScript prm1 -Script 'dataguard\primary_create.sh'

Write-LabStep 'Standby stb1 (RMAN duplicate from active database)'
$pw = Join-Path $env:TEMP 'orapworcl'
$o = Get-LabSshArgs
scp @o -P $LabNodes.prm1.Port 'oracle@127.0.0.1:/u01/app/oracle/product/23.0.0/dbhome_1/dbs/orapworcl' $pw
Copy-LabFile stb1 -Path $pw -Destination '/u01/app/oracle/product/23.0.0/dbhome_1/dbs/orapworcl'
Remove-Item $pw
Invoke-LabScript stb1 -Script 'dataguard\standby_create.sh'

Write-LabStep 'Broker + Active Data Guard + autostart'
Invoke-LabScript prm1 -Script 'dataguard\broker_setup.sh'
Invoke-LabScript prm1 -Script 'dataguard\open_adg.sh' -Arguments 'stb1'
foreach ($n in 'prm1', 'stb1') { Invoke-LabScript $n -User root -Script 'common\db_autostart_root.sh' -Arguments 'orcl' }

Write-LabStep 'Role-based services'
Invoke-LabScript prm1 -Script 'dataguard\role_services.sh'
