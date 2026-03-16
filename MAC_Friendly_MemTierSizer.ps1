<#
.SYNOPSIS
    VMware 9.1 Memory Tiering Assessment Tool (Cross-Platform CLI)

.EXAMPLE
    ./MemorySizer.ps1 -vCenter "vc.lab.local" -ClusterName "Compute-Cluster-01" -Ratio "1:1"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage="Enter one or more vCenter servers (comma-separated)")]
    [string[]]$vCenter,

    [Parameter(Mandatory=$true, HelpMessage="Enter the name of the Cluster to analyze")]
    [string]$ClusterName,

    [Parameter(Mandatory=$false, HelpMessage="Select your hardware tier ratio")]
    [ValidateSet("1:1", "1:2", "1:4")]
    [string]$Ratio = "1:1",

    [Parameter(Mandatory=$false, HelpMessage="Path to export the CSV report")]
    [string]$ExportPath = "$HOME/Desktop/vSphere9_MemoryTier_Final.csv"
)

$WarningPreference = 'SilentlyContinue'

# ==========================================
# --- PRE-FLIGHT MODULE CHECK ---
# ==========================================
$powerCliInstalled = Get-Module -ListAvailable -Name VMware.VimAutomation.Core
if ($null -eq $powerCliInstalled) {
    Write-Host "ERROR: VMware PowerCLI is missing." -ForegroundColor Red
    Write-Host "Please run: Install-Module VMware.PowerCLI -Scope CurrentUser" -ForegroundColor Yellow
    exit
}

# ==========================================
# --- AUTHENTICATION ---
# ==========================================
Write-Host "`n[1/4] Connecting to vCenter(s)..." -ForegroundColor Cyan
foreach ($vc in $vCenter) {
    if (-not ($global:DefaultVIServers.Name -contains $vc)) {
        try {
            # This triggers the secure cross-platform credential prompt in your Mac Terminal
            Connect-VIServer -Server $vc -ErrorAction Stop | Out-Null
            Write-Host "Successfully connected to $vc" -ForegroundColor Green
        } catch {
            Write-Host "Failed to connect to $vc. $($_.Exception.Message)" -ForegroundColor Red
            exit
        }
    }
}

# ==========================================
# --- CLUSTER AND HOST ANALYSIS ---
# ==========================================
Write-Host "`n[2/4] Analyzing Cluster '$ClusterName'..." -ForegroundColor Cyan

$cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
if (-not $cluster) {
    Write-Host "ERROR: Cluster '$ClusterName' not found." -ForegroundColor Red
    exit
}

$hosts = Get-VMHost -Location $cluster

# Determine Divisor
$divisor = 2 
if ($Ratio -eq "1:2") { $divisor = 3 }
if ($Ratio -eq "1:4") { $divisor = 5 }

$totalDramGB_Sum = 0
$tieringActiveGlobally = $false

foreach ($h in $hosts) {
    $hostIsTiered = $false
    
    try {
        $esxcli = Get-EsxCli -VMHost $h -V2 -ErrorAction SilentlyContinue
        $memStatus = $esxcli.memtier.status.get.Invoke()
        if ($memStatus.Status -eq "Enabled") {
            $hostIsTiered = $true
            $tieringActiveGlobally = $true
        }
    } catch { }

    $hv = $h | Get-View -Property Hardware
    $rawTotalGB = $hv.Hardware.MemorySize / 1GB
    
    if ($hostIsTiered) {
        $hostDramGB = $rawTotalGB / $divisor
    } else {
        $hostDramGB = $rawTotalGB
    }
    
    $totalDramGB_Sum += $hostDramGB
}

$finalDramGB = [math]::Round($totalDramGB_Sum, 2)

# ==========================================
# --- VM WORKLOAD ANALYSIS ---
# ==========================================
Write-Host "[3/4] Calculating active VM workloads..." -ForegroundColor Cyan

$vms = Get-VM -Location $cluster | Where-Object {$_.PowerState -eq "PoweredOn"}
$totalActiveGB = 0
$results = New-Object System.Collections.Generic.List[PSObject]

foreach ($vm in $vms) {
    $activeGB = [math]::Round($vm.ExtensionData.Summary.QuickStats.GuestMemoryUsage / 1024, 2)
    $totalActiveGB += $activeGB
    $results.Add([PSCustomObject]@{
        VMName         = $vm.Name
        Provisioned_GB = [math]::Round($vm.MemoryGB, 2)
        Active_GB      = $activeGB
        Active_Pct     = if ($vm.MemoryGB -gt 0) { [math]::Round(($activeGB / $vm.MemoryGB) * 100, 2) } else { 0 }
    })
}

$sortedResults = $results | Sort-Object Active_Pct -Descending
$utilizationRatio = if ($finalDramGB -gt 0) { [math]::Round(($totalActiveGB / $finalDramGB) * 100, 2) } else { 0 }

# ==========================================
# --- EXPORT & REPORTING ---
# ==========================================
Write-Host "[4/4] Generating Assessment..." -ForegroundColor Cyan

# Export to CSV
$sortedResults | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "`nDetailed VM Report saved to: $ExportPath" -ForegroundColor DarkGray

# Print Summary to Terminal
Write-Host "============================================="
Write-Host " MEMORY TIERING ASSESSMENT RESULTS"
Write-Host "============================================="
Write-Host "Cluster Name : $ClusterName"
Write-Host "Total DRAM   : $finalDramGB GB"
Write-Host "Active Load  : $totalActiveGB GB ($utilizationRatio%)"

if ($tieringActiveGlobally) {
    Write-Host "Tier Status  : ENABLED (Ratio calculated at $Ratio)"
} else {
    Write-Host "Tier Status  : DISABLED (Standard RAM)"
}

Write-Host "---------------------------------------------"

if ($utilizationRatio -le 50) {
    Write-Host "RESULT: PASS" -ForegroundColor Green
    if ($tieringActiveGlobally) {
        Write-Host "Active workload occupies $utilizationRatio% of the configured DRAM tier." -ForegroundColor Green
    } else {
        Write-Host "This cluster is a GREAT candidate for Memory Tiering - active workload is 50% or under from total DRAM size." -ForegroundColor Green
    }
} else {
    Write-Host "RESULT: FAIL" -ForegroundColor Red
    if ($tieringActiveGlobally) {
        Write-Host "Active workload occupies $utilizationRatio% of the configured DRAM tier. (Exceeds 50% Threshold)" -ForegroundColor Red
    } else {
        Write-Host "Not recommended for Memory Tiering. Active workload ($utilizationRatio%) exceeds the 50% safe threshold." -ForegroundColor Red
    }
}
Write-Host "=============================================`n"