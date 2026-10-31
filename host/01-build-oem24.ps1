# Build the OEM 24.1 VM from scratch: OL9 (network install), 26ai repository DB, EM 24.1 silent install.
# Takes ~2 h. Needs ~80 GB free on the VM disk's drive while installing (fstrim brings the VDI back to ~50 GB).
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force
$ErrorActionPreference = 'Stop'
$cfg = Get-LabConfig
$vm = 'OEM24'
$dir = Join-Path $cfg.LAB_VM_DIR $vm
$iso = Join-Path $cfg.LAB_ISO_DIR (Split-Path $cfg.OL_BOOT_ISO_URL -Leaf)

Write-LabStep 'SSH key + boot ISO'
if (-not (Test-Path $cfg.LAB_SSH_KEY)) { ssh-keygen -t ed25519 -N '""' -f $cfg.LAB_SSH_KEY -C oem-lab -q }
if (-not (Test-Path $iso)) {
    New-Item -ItemType Directory -Force $cfg.LAB_ISO_DIR | Out-Null
    curl.exe -s -L -o $iso $cfg.OL_BOOT_ISO_URL
}
$ks = Join-Path $env:TEMP 'oem24_ks.cfg'
$pub = (Get-Content "$($cfg.LAB_SSH_KEY).pub").Trim()
[IO.File]::WriteAllText($ks, ((Get-Content (Join-Path $RepoRoot 'kickstart\oem24_ks.cfg') -Raw) -replace '@@LAB_SSH_PUBKEY@@', $pub).Replace("`r`n", "`n"))

Write-LabStep 'NAT network oemnet'
if (-not (VBoxManage list natnets | Select-String 'oemnet')) {
    VBoxManage natnetwork add --netname oemnet --network '192.168.100.0/24' --enable --dhcp off
    VBoxManage natnetwork modify --netname oemnet --port-forward-4 'prm1ssh:tcp:[127.0.0.1]:2223:[192.168.100.11]:22' --port-forward-4 'stb1ssh:tcp:[127.0.0.1]:2224:[192.168.100.12]:22'
}

Write-LabStep "Create VM $vm"
VBoxManage createvm --name $vm --ostype Oracle9_64 --register
VBoxManage modifyvm $vm --memory $cfg.OEM24_MEM_MB --cpus 6 --ioapic on --firmware bios --graphicscontroller vmsvga --vram 16 `
    --nic1 nat --nic2 natnetwork --nat-network2 oemnet --audio-enabled off --usb off --boot1 dvd --boot2 disk --boot3 none --boot4 none
VBoxManage modifyvm $vm --natpf1 'ssh,tcp,127.0.0.1,2222,,22' --natpf1 'emconsole,tcp,127.0.0.1,7803,,7803' `
    --natpf1 'emupload,tcp,127.0.0.1,4903,,4903' --natpf1 'listener,tcp,127.0.0.1,1521,,1521' --natpf1 'wlsadmin,tcp,127.0.0.1,7102,,7102'
VBoxManage createmedium disk --filename "$dir\$vm.vdi" --size 122880 --format VDI --variant Standard
VBoxManage storagectl $vm --name SATA --add sata --controller IntelAhci --portcount 2 --hostiocache on
VBoxManage storageattach $vm --storagectl SATA --port 0 --device 0 --type hdd --medium "$dir\$vm.vdi" --nonrotational on --discard on
VBoxManage storageattach $vm --storagectl SATA --port 1 --device 0 --type dvddrive --medium $iso
VBoxManage unattended install $vm --iso=$iso --user=oracle --password=$($cfg.LAB_PWD) --hostname=oem24.localdomain `
    --time-zone=Asia/Ho_Chi_Minh --locale=en_US --script-template=$ks --start-vm=headless
Wait-LabSsh oem24 -TimeoutSec 1800
VBoxManage storageattach $vm --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive

Write-LabStep 'OS prep + second NIC'
Initialize-LabNodeEnv oem24
Invoke-LabScript oem24 -User root -Script 'common\os_prep_root.sh' -Arguments 'emcdb'
Invoke-LabScript oem24 -User root -Script 'oem24\oemnet_nic_root.sh'

Write-LabStep 'DB home 26ai'
Copy-LabFile oem24 -Path (Join-Path $cfg.LAB_DOWNLOADS $cfg.DB_HOME_ZIP) -Destination '/u01/stage/'
Invoke-LabScript oem24 -Script 'common\db_home_install.sh' -Arguments "/u01/stage/$($cfg.DB_HOME_ZIP)"
Invoke-LabScript oem24 -User root -Script 'common\db_home_root.sh'

Write-LabStep 'Repository DB emcdb/empdb'
Invoke-LabScript oem24 -Script 'oem24\repo_db_create.sh'
Invoke-LabScript oem24 -User root -Script 'common\db_autostart_root.sh' -Arguments 'emcdb'

Write-LabStep 'EM 24.1 install'
foreach ($z in $cfg.EM_ZIPS -split ',') { Copy-LabFile oem24 -Path (Join-Path $cfg.LAB_DOWNLOADS $z) -Destination '/u01/stage/' }
Invoke-LabScript oem24 -Script 'oem24\em_stage_unzip.sh'
Copy-LabFile oem24 -Path (Join-Path $RepoRoot 'guest\oem24\em24_new_install.rsp.tmpl') -Destination '/tmp/'
Invoke-LabScript oem24 -Script 'oem24\em_install.sh'
do {
    Start-Sleep 60
    $tail = Invoke-LabSsh oem24 -Command 'tail -c 600 /u01/stage/em_install.out; pgrep -f em24100 >/dev/null && echo __RUN || echo __STOP'
    ($tail | Select-Object -Last 3) -join ' | '
} while (($tail -join "`n") -match '__RUN')
if (($tail -join "`n") -notmatch 'Successfully installed') { throw 'EM install did not succeed - see /u01/stage/em_install.out' }
Invoke-LabScript oem24 -User root -Script 'oem24\em_post_install_root.sh'

Write-LabStep 'Done: https://localhost:7803/em  (sysman)'
