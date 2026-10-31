# Write a Markdown status report of the lab to docs/reports/<timestamp>-<label>.md
# (VMs, Data Guard / FSFO, per-database role and lag, role services, application probe, EM view, host).
param([string]$Label = 'status')
Import-Module (Join-Path $PSScriptRoot 'lab.psm1') -Force

$now = Get-Date
$dir = Join-Path $RepoRoot 'docs\reports'
New-Item -ItemType Directory -Force $dir | Out-Null
$file = Join-Path $dir ('{0:yyyy-MM-dd-HHmm}-{1}.md' -f $now, $Label)

function ConvertTo-MdSections([string[]]$Lines) {
    # "### Title" lines start a section; everything else goes into that section's code block
    $out = New-Object System.Collections.Generic.List[string]
    $open = $false
    foreach ($l in $Lines) {
        if ($l -match '^### (.+)$') {
            if ($open) { $out.Add('```') }
            $out.Add(''); $out.Add("### $($Matches[1])"); $out.Add(''); $out.Add('```'); $open = $true
        } elseif ($open) { $out.Add($l.TrimEnd()) }
    }
    if ($open) { $out.Add('```') }
    $out
}

$vms = foreach ($vm in 'OEM24', 'prm1', 'stb1') { '| {0} | {1} |' -f $vm, (Get-LabVMState $vm) }
$dg = Invoke-LabScript oem24 -Script 'dataguard\dg_report.sh' 2>&1 | ForEach-Object { "$_" }
$em = Invoke-LabScript oem24 -Script 'em\check_dg.sh' 2>&1 | ForEach-Object { "$_" } | Where-Object { $_.Trim() }

$primary = ($dg | Select-String '^\s*(prm1|stb1) - Primary database' | Select-Object -First 1)
$primary = if ($primary) { $primary.Matches[0].Groups[1].Value } else { 'unknown' }
$cfgStatus = ($dg | Select-String '^(SUCCESS|WARNING|ERROR)' | Select-Object -First 1)
$fsfo = ($dg | Select-String 'Fast-Start Failover:\s+(.+)$' | Select-Object -First 1)
$os = Get-CimInstance Win32_OperatingSystem
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$md = @(
    "# Lab status report: $Label"
    ''
    ('Generated {0:yyyy-MM-dd HH:mm:ss} (host time) by `host/report.ps1`.' -f $now)
    ''
    '## Summary'
    ''
    '| Item | Value |'
    '|---|---|'
    "| Primary | **$primary** |"
    ('| Broker configuration status | {0} |' -f $(if ($cfgStatus) { $cfgStatus.Line.Trim() } else { 'unknown' }))
    ('| Fast-Start Failover | {0} |' -f $(if ($fsfo) { $fsfo.Matches[0].Groups[1].Value.Trim() } else { 'unknown' }))
    ('| Host RAM free | {0:N1} GB |' -f ($os.FreePhysicalMemory / 1MB))
    ('| Host C: free | {0:N1} GB |' -f ($disk.FreeSpace / 1GB))
    ''
    '## VMs'
    ''
    '| VM | State |'
    '|---|---|'
    $vms
    ''
    '## Data Guard'
    (ConvertTo-MdSections $dg)
    ''
    '## Enterprise Manager view'
    ''
    '```'
    $em
    '```'
)
[IO.File]::WriteAllText($file, (($md | ForEach-Object { $_ }) -join "`n") + "`n")
"report: $file"
