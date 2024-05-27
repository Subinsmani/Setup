# DownloadISO.ps1

function Get-WindowsServerEditions {
    return @(
        "Windows Server 2019",
        "Windows Server 2022",
        "Windows Server 2016",
        "Windows Server 2012 R2"
    )
}

function Get-DownloadUrl {
    param (
        [string]$edition
    )

    switch ($edition) {
        "Windows Server 2019" { return "https://software-download.microsoft.com/download/pr/20348.1.210507-1500.fe_release_SERVER_EVAL_x64FRE_en-us.iso" }
        "Windows Server 2022" { return "https://software-download.microsoft.com/download/pr/20348.1.210507-1500.fe_release_SERVER_EVAL_x64FRE_en-us.iso" }
        "Windows Server 2016" { return "https://software-download.microsoft.com/download/pr/20348.1.210507-1500.fe_release_SERVER_EVAL_x64FRE_en-us.iso" }
        "Windows Server 2012 R2" { return "https://software-download.microsoft.com/download/pr/20348.1.210507-1500.fe_release_SERVER_EVAL_x64FRE_en-us.iso" }
        default { throw "Invalid edition selected." }
    }
}

function Download-ISO {
    param (
        [string]$url,
        [string]$destinationFolder,
        [string]$edition
    )

    $fileName = ($edition -replace ' ', '-') + ".iso"
    $destinationPath = Join-Path -Path $destinationFolder -ChildPath $fileName

    $webRequest = [System.Net.HttpWebRequest]::Create($url)
    $webRequest.Method = "GET"
    $response = $webRequest.GetResponse()
    $totalSize = $response.ContentLength
    $buffer = New-Object byte[] 8192
    $downloadedSize = 0
    $startTime = Get-Date

    try {
        Write-Host "Starting download..."
        if (Test-Path $destinationPath) {
            Remove-Item $destinationPath -ErrorAction Ignore
        }
        $fileStream = [System.IO.File]::Create($destinationPath)
        $responseStream = $response.GetResponseStream()

        while (($read = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $downloadedSize += $read
            $elapsedTime = (Get-Date) - $startTime
            $speed = [math]::Round(($downloadedSize / 1MB) / $elapsedTime.TotalSeconds, 2)
            $progress = [math]::Round(($downloadedSize / $totalSize) * 100, 2)
            Write-Host ("`rDownloaded: {0:N2} MB of {1:N2} MB ({2:N2} MB/s) - {3}% Complete" -f ($downloadedSize / 1MB), ($totalSize / 1MB), $speed, $progress) -NoNewline
        }

        Write-Host "`nDownload completed. File saved to $destinationPath"
    } catch {
        Write-Host "`nAn error occurred during the download: $_"
    } finally {
        $fileStream.Close()
        $responseStream.Close()
    }
}

function Main {
    while ($true) {
        $editions = Get-WindowsServerEditions

        Write-Host "Available Windows Server editions:"
        for ($i = 0; $i -lt $editions.Count; $i++) {
            Write-Host "$($i + 1). $($editions[$i])"
        }
        Write-Host "$($editions.Count + 1). Back"

        $selection = Read-Host "Select the edition to download (1-$($editions.Count + 1))"
        if ($selection -match '^\d+$') {
            $selection = [int]$selection
            if ($selection -ge 1 -and $selection -le $editions.Count) {
                $selectedEdition = $editions[$selection - 1]
                $downloadUrl = Get-DownloadUrl -edition $selectedEdition
                $rootFolder = (Get-Location).Path
                $downloadFolder = Join-Path -Path $rootFolder -ChildPath "Downloads"

                if (-not (Test-Path -Path $downloadFolder)) {
                    New-Item -ItemType Directory -Path $downloadFolder
                }

                Download-ISO -url $downloadUrl -destinationFolder $downloadFolder -edition $selectedEdition
            } elseif ($selection -eq $editions.Count + 1) {
                return # Back to the previous menu
            } else {
                Write-Host "Invalid selection. Please select a number between 1 and $($editions.Count + 1)."
            }
        } else {
            Write-Host "Invalid input. Please enter a number."
        }
    }
}

Main
