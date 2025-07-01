# ================================================
# PerfMon Snapshot Script – Clean v7 with Clear-Host
# ================================================

# Retrieve CPU model and total physical memory
$cpuName = (Get-CimInstance Win32_Processor).Name
$totalMB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB, 2)

Write-Host "Monitoring on: $cpuName"
Write-Host "Total Physical Memory (MB): $totalMB`n"

# Prompt until valid mode is entered
do {
    $mode = Read-Host "Select monitoring option ('CPU','Memory','Both')"
    $mode = $mode.Trim().ToLower()
    if ($mode -notin 'cpu','memory','both') {
        Write-Host "Invalid selection. Please enter CPU, Memory, or Both.`n"
    }
} while ($mode -notin 'cpu','memory','both')

Write-Host "`nSelected mode: $mode`n"

# Define performance counters to snapshot
$counters = @(
    "\Processor(_Total)\% Processor Time",
    "\Memory\Available MBytes",
    "\Memory\Committed Bytes",
    "\Memory\% Committed Bytes In Use",
    "\Memory\Page Faults/sec",
    "\Paging File(_Total)\% Usage",
    "\PhysicalDisk(_Total)\Avg. Disk sec/Read",
    "\PhysicalDisk(_Total)\Avg. Disk sec/Write",
    "\PhysicalDisk(_Total)\Current Disk Queue Length",
    "\Network Interface(*)\Bytes Total/sec"
)

# Wait 60 seconds with progress bar
for ($i = 1; $i -le 60; $i++) {
    $pct = [math]::Round(($i / 60) * 100, 0)
    Write-Progress -Activity "Waiting 60s before snapshot" -Status "$((60 - $i))s remaining" -PercentComplete $pct
    Start-Sleep -Seconds 1
}
Write-Progress -Activity "Waiting 60s before snapshot" -Completed

# Take one snapshot of all counters at once
try {
    $dump    = Get-Counter -Counter $counters -ErrorAction Stop
    $samples = $dump.CounterSamples
} catch {
    Write-Host "`nERROR: Failed to capture performance counters:`n$_"
    return
}

# Helper function to get a single sample value
function Get-SampleValue($pattern) {
    $item = $samples | Where-Object { $_.Path -like $pattern } | Select-Object -First 1
    if ($item) { return $item.CookedValue } else { return $null }
}

# Parse overall metrics
$cpuVal    = Get-SampleValue "*Processor(_Total)*"
$availMB   = Get-SampleValue "*Available MBytes*"
$commBytes = Get-SampleValue "*Committed Bytes*"
$commPct   = Get-SampleValue "*% Committed Bytes In Use*"
$pfaults   = Get-SampleValue "*Page Faults/sec*"
$pagePct   = Get-SampleValue "*Paging File*% Usage*"
$dRead     = Get-SampleValue "*Avg. Disk sec/Read*"
$dWrite    = Get-SampleValue "*Avg. Disk sec/Write*"
$dQueue    = Get-SampleValue "*Current Disk Queue Length*"
$netVals   = $samples | Where-Object { $_.Path -like "*Bytes Total/sec*" } | Select-Object -ExpandProperty CookedValue
$netMBps   = if ($netVals) { [math]::Round(($netVals | Measure-Object -Sum).Sum / 1MB, 2) } else { 0 }

$usedMB    = if ($availMB -ne $null) { [math]::Round($totalMB - $availMB, 2) } else { 0 }
$memPct    = if ($usedMB -ne $null) { [math]::Round(($usedMB / $totalMB) * 100, 2) } else { 0 }

# Build overall PSCustomObject
$overall = [PSCustomObject]@{
    Timestamp               = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    'CPU Usage (%)'         = if ($cpuVal    -ne $null) { [math]::Round($cpuVal, 2) } else { 'N/A' }
    'Available Memory (MB)' = if ($availMB   -ne $null) { [math]::Round($availMB, 2) } else { 'N/A' }
    'Total Memory (MB)'     = $totalMB
    'Memory Used (MB)'      = $usedMB
    'Memory Usage (%)'      = $memPct
    'Committed Memory (MB)' = if ($commBytes -ne $null) { [math]::Round($commBytes/1MB, 2) } else { 'N/A' }
    'Committed (%)'         = if ($commPct   -ne $null) { [math]::Round($commPct, 2) } else { 'N/A' }
    'PageFaults/sec'        = if ($pfaults   -ne $null) { [math]::Round($pfaults, 2) } else { 'N/A' }
    'PageFile (%)'          = if ($pagePct   -ne $null) { [math]::Round($pagePct, 2) } else { 'N/A' }
    'DiskReadLat (s)'       = if ($dRead     -ne $null) { [math]::Round($dRead, 4) } else { 'N/A' }
    'DiskWriteLat (s)'      = if ($dWrite    -ne $null) { [math]::Round($dWrite, 4) } else { 'N/A' }
    'DiskQueueLen'          = if ($dQueue    -ne $null) { [math]::Round($dQueue, 2) } else { 'N/A' }
    'NetThroughput (MB/s)'  = $netMBps
}

# Clear and display overall metrics
Clear-Host
Write-Host "=== Overall System Metrics ===`n"
$overall | Format-List *

# Capture process snapshot
$allProcs = Get-Process

# Gather user session summaries via quser
$sessionLines = quser 2>$null | Select-Object -Skip 1
$usersMem = @(); $usersCpu = @()
foreach ($line in $sessionLines) {
    if ($line -match '^\s*(\S+)\s+\S+\s+(\d+)\s+Active') {
        $user  = $matches[1]
        $sess  = [int]$matches[2]
        $procs = $allProcs | Where-Object SessionId -eq $sess
        if ($procs) {
            $memList = $procs | ForEach-Object { $_.WorkingSet / 1MB }
            $cpuList = $procs | ForEach-Object { $_.CPU }
            $usersMem += [PSCustomObject]@{
                'User Name'     = $user
                'MaxMem (MB)'   = [math]::Round(($memList | Measure-Object -Maximum).Maximum, 2)
                'AvgMem (MB)'   = [math]::Round(($memList | Measure-Object -Average).Average, 2)
                'TotalMem (MB)' = [math]::Round(($memList | Measure-Object -Sum).Sum, 2)
            }
            $usersCpu += [PSCustomObject]@{
                'User Name'   = $user
                'MaxCPU (s)'  = [math]::Round(($cpuList | Measure-Object -Maximum).Maximum, 2)
                'AvgCPU (s)'  = [math]::Round(($cpuList | Measure-Object -Average).Average, 2)
                'TotalCPU (s)'= [math]::Round(($cpuList | Measure-Object -Sum).Sum, 2)
            }
        }
    }
}

# Display user summaries
if ($mode -in 'memory','both') {
    Write-Host "`n=== User Memory Usage Summary ===`n"
    if ($usersMem) { $usersMem | Format-Table -AutoSize } else { Write-Host "No active user sessions detected." }
}
if ($mode -in 'cpu','both') {
    Write-Host "`n=== User CPU Usage Summary ===`n"
    if ($usersCpu) { $usersCpu | Format-Table -AutoSize } else { Write-Host "No active user sessions detected." }
}

# Display top processes
if ($mode -in 'cpu','both') {
    Write-Host "`n=== Top 5 Processes by CPU ===`n"
    $allProcs |
      Where-Object { $_.CPU -gt 0 } |
      Sort-Object CPU -Descending |
      Select-Object -First 5 `
         @{Name='ProcessName';Expression={$_.ProcessName}},
         @{Name='PID';Expression={$_.Id}},
         @{Name='CPU(s)';Expression={[math]::Round($_.CPU,2)}},
         @{Name='Threads';Expression={$_.Threads.Count}},
         @{Name='Handles';Expression={$_.HandleCount}} |
      Format-Table -AutoSize
}

if ($mode -in 'memory','both') {
    Write-Host "`n=== Top 5 Processes by Memory ===`n"
    $allProcs |
      Sort-Object WorkingSet -Descending |
      Select-Object -First 5 `
         @{Name='ProcessName';Expression={$_.ProcessName}},
         @{Name='PID';Expression={$_.Id}},
         @{Name='CurrMem(MB)';Expression={[math]::Round($_.WorkingSet/1MB,2)}},
         @{Name='MaxMem(MB)';Expression={[math]::Round($_.PeakWorkingSet64/1MB,2)}},
         @{Name='AvgMem(MB)';Expression={[math]::Round((($_.WorkingSet + $_.PeakWorkingSet64)/2)/1MB,2)}},
         @{Name='Threads';Expression={$_.Threads.Count}},
         @{Name='Handles';Expression={$_.HandleCount}} |
      Format-Table -AutoSize
}
