# Shared helpers for driving the lab VMs from the Windows host (Windows PowerShell 5.1).
# Guest scripts are copied with scp and run with bash; passing scripts as files avoids
# PowerShell 5.1 mangling quotes in native arguments and prefixing stdin with a BOM.

$script:RepoRoot = Split-Path $PSScriptRoot -Parent

# name -> SSH port forwarded on 127.0.0.1, lab IP on NAT network "oemnet"
$script:LabNodes = @{
    oem24 = @{ Port = 2222; Ip = '192.168.100.10' }
    prm1  = @{ Port = 2223; Ip = '192.168.100.11' }
    stb1  = @{ Port = 2224; Ip = '192.168.100.12' }
}

function Get-LabConfig {
    $file = Join-Path $script:RepoRoot 'config\lab.env'
    if (-not (Test-Path $file)) { throw "Missing $file - copy config\lab.env.example to config\lab.env and edit it." }
    $cfg = @{}
    foreach ($line in Get-Content $file) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $k, $v = $line -split '=', 2
        $v = $v.Trim()
        if ($v.StartsWith('~')) { $v = $env:USERPROFILE + $v.Substring(1) }
        $cfg[$k.Trim()] = $v
    }
    $cfg
}

function Get-LabSshArgs {
    $cfg = Get-LabConfig
    @('-i', $cfg.LAB_SSH_KEY, '-o', 'UserKnownHostsFile=NUL', '-o', 'StrictHostKeyChecking=no',
      '-o', 'BatchMode=yes', '-o', 'LogLevel=ERROR', '-o', 'ConnectTimeout=10')
}

function Invoke-LabSsh {
    param([Parameter(Mandatory)][string]$Node, [string]$User = 'oracle', [Parameter(Mandatory)][string]$Command)
    $o = Get-LabSshArgs
    ssh @o -p $script:LabNodes[$Node].Port "$User@127.0.0.1" $Command
}

function Copy-LabFile {
    param([Parameter(Mandatory)][string]$Node, [string]$User = 'oracle',
          [Parameter(Mandatory)][string[]]$Path, [Parameter(Mandatory)][string]$Destination)
    $o = Get-LabSshArgs
    scp @o -P $script:LabNodes[$Node].Port @Path "$User@127.0.0.1:$Destination"
}

# Push ~/.lab.env (LAB_PWD etc.) to oracle and root on a node; guest scripts source it.
function Initialize-LabNodeEnv {
    param([Parameter(Mandatory)][string]$Node)
    $cfg = Get-LabConfig
    $tmp = Join-Path $env:TEMP "lab.env.$Node"
    [IO.File]::WriteAllText($tmp, "LAB_PWD='$($cfg.LAB_PWD)'`n")
    try {
        foreach ($u in 'root', 'oracle') {
            Copy-LabFile -Node $Node -User $u -Path $tmp -Destination '~/.lab.env'
            Invoke-LabSsh -Node $Node -User $u -Command 'chmod 600 ~/.lab.env' | Out-Null
        }
    } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

# Copy a guest script (path relative to guest/) to the node and run it with ~/.lab.env loaded.
function Invoke-LabScript {
    param([Parameter(Mandatory)][string]$Node, [string]$User = 'oracle',
          [Parameter(Mandatory)][string]$Script, [string[]]$Arguments = @())
    $src = Join-Path $script:RepoRoot "guest\$Script"
    $name = Split-Path $src -Leaf
    Copy-LabFile -Node $Node -User $User -Path $src -Destination "/tmp/$name"
    $argStr = ($Arguments | ForEach-Object { "'$_'" }) -join ' '
    Invoke-LabSsh -Node $Node -User $User -Command "sed -i 's/\r$//' /tmp/$name; set -a; [ -f ~/.lab.env ] && . ~/.lab.env; set +a; bash /tmp/$name $argStr; rc=`$?; rm -f /tmp/$name; exit `$rc"
}

function Wait-LabSsh {
    param([Parameter(Mandatory)][string]$Node, [int]$TimeoutSec = 600)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Invoke-LabSsh -Node $Node -User root -Command 'true' 2>$null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep 10
    }
    throw "Timed out waiting for SSH on $Node"
}

function Get-LabVMState {
    param([Parameter(Mandatory)][string]$Name)
    $line = VBoxManage showvminfo $Name --machinereadable 2>$null | Select-String '^VMState='
    if ($line) { ($line.ToString() -split '=')[1].Trim('"') } else { 'unknown' }
}

function Wait-LabVMState {
    param([Parameter(Mandatory)][string]$Name, [string]$State = 'poweroff', [int]$TimeoutSec = 300)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if ((Get-LabVMState $Name) -eq $State) { return }
        Start-Sleep 5
    }
    throw "Timed out waiting for $Name to reach state $State"
}

function Write-LabStep { param([string]$Text) Write-Host "`n== $Text" -ForegroundColor Cyan }

# VM disks and the pagefile share C:, and VDI files only grow. Stop before the host runs out of space.
function Assert-LabDisk {
    param([double]$MinFreeGB = 5)
    $free = (Get-PSDrive C).Free / 1GB
    if ($free -lt $MinFreeGB) { throw ('C: has {0:N1} GB free, below the {1} GB limit' -f $free, $MinFreeGB) }
    'C: free {0:N1} GB' -f $free
}

Export-ModuleMember -Function * -Variable LabNodes, RepoRoot
