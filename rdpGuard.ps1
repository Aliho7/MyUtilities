$LogFile = "C:\IT\Scripts\Logs\log.txt"
$BlockedIPsFile = "C:\IT\Scripts\blocked_ips.txt"
$BlockedIPs = @{}

$rdpPort = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "PortNumber" | Select-Object -ExpandProperty PortNumber
# Load previously blocked IPs and their blocked time from the file
if (Test-Path $BlockedIPsFile) {
    $BlockedIPsData = Get-Content -Path $BlockedIPsFile
    $BlockedIPsData | ForEach-Object {
        $BlockedIP, $BlockedTime = $_.Split(",")
        $BlockedIPs[$BlockedIP] = [DateTime]::ParseExact($BlockedTime, 'yyyy-MM-dd HH:mm:ss', $null)
    }
}

$StartTime = (Get-Date).AddMinutes(-5)
$EndTime = Get-Date

$EventLog = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4625
    StartTime = $StartTime
    EndTime = $EndTime
} -ErrorAction SilentlyContinue

if ($null -ne $EventLog) {
    $FailedIPs = $EventLog | Where-Object {
        $_.Message -match 'Logon Type:\s+3' -and
        $_.Message -match 'Status:\s+0xc000006d'
    } | ForEach-Object {
        $_.Properties[19].Value
    } | Select-Object -Unique

    foreach ($IP in $FailedIPs) {
        if (-not $BlockedIPs.ContainsKey($IP)) {
            # Block the IP using Windows Firewall or any other method you prefer
            # For example, you can use the following command to block the IP using Windows Firewall:
            netsh advfirewall firewall add rule name="Block RDP ($IP)" dir=in action=block protocol=TCP localport=$rdpPort remoteip=$IP
            Write-Host "Blocked IP: $IP"
            $BlockedIPs[$IP] = Get-Date

            # Log the blocked IP to the log file
            $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Blocked IP: $IP"
            Add-Content -Path $LogFile -Value $LogMessage
        }
    }
} else {
    Write-Host "No events found within the specified time range."
}

# Check if any previously blocked IPs need to be unblocked
$IPsToUnblock = @()
foreach ($BlockedIP in $BlockedIPs.Keys) {
    $BlockedTime = $BlockedIPs[$BlockedIP]
    $ElapsedTime = New-TimeSpan -Start $BlockedTime -End (Get-Date)
    if ($ElapsedTime.TotalHours -ge 2) {
        $IPsToUnblock += $BlockedIP
    }
}

foreach ($IP in $IPsToUnblock) {
    # Unblock the IP using Windows Firewall or any other method you used for blocking
    # For example, you can use the following command to unblock the IP using Windows Firewall:
    netsh advfirewall firewall delete rule name="Block RDP ($IP)" dir=in remoteip=$IP
    Write-Host "Unblocked IP: $IP"
    $BlockedIPs.Remove($IP)

    # Log the unblocked IP to the log file
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Unblocked IP: $IP"
    Add-Content -Path $LogFile -Value $LogMessage
}

# Save the updated list of blocked IPs and their blocked time to the file
$BlockedIPsData = $BlockedIPs.GetEnumerator() | ForEach-Object { '{0},{1}' -f $_.Key, $_.Value.ToString('yyyy-MM-dd HH:mm:ss') }
$BlockedIPsData | Out-File -FilePath $BlockedIPsFile -Force