# One-screen lab status: VM states, Data Guard / FSFO (via the observer host), host RAM.
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force

Write-LabStep 'VMs'
foreach ($vm in 'OEM24', 'prm1', 'stb1') { '{0,-6} {1}' -f $vm, (Get-LabVMState $vm) }

if ((Get-LabVMState OEM24) -eq 'running') {
    Write-LabStep 'Data Guard (from oem24)'
    Invoke-LabScript oem24 -Script 'dataguard\dg_status.sh'
    Write-LabStep 'Observer service'
    Invoke-LabSsh oem24 -User root -Command 'systemctl is-active dg-observer.service'
}

$os = Get-CimInstance Win32_OperatingSystem
Write-LabStep ('Host RAM free: {0:N1} GB' -f ($os.FreePhysicalMemory / 1MB))
