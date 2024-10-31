# Check if the script is running as administrator
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    # Relaunch the script with administrator privileges
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -ArgumentList $args -Verb RunAs
    exit
}

# Time interval for switching locations (in seconds)
$CHANGE_EVERY = 30 # seconds. 1800 = 30 minutes
$RegexRegion = '([A-Za-z]+(?: [A-Za-z]+)*(?: \(.*?\))?(?: - [A-Za-z]+(?: [A-Za-z]+)*)?(?: - \d+)?)'

# Function to get and echo the current public IP
function Echo-PublicIP {
    try {
        $MY_INTERNET_IP = Invoke-RestMethod -Uri "http://whatismyip.akamai.com/"
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] The public IP is $MY_INTERNET_IP."
    } catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Unable to retrieve the public IP."
    }
}

# __MAIN__

Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Welcome to the VPN script to auto-switch IP every $CHANGE_EVERY seconds."

# Path to ExpressVPN.CLI.exe
$expressVPNPath = "C:\Program Files (x86)\ExpressVPN\services\ExpressVPN.CLI.exe"  # Change this to your actual path

# Disconnect any active VPN connection
& $expressVPNPath disconnect | Out-Null
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Connection to VPN reset. The public IP without VPN is:"
Echo-PublicIP

while ($true) {
    # Select a random VPN location from the available ones
    $vpnLocations = & $expressVPNPath list | Select-String -Pattern '^[\t ]+(.*)' | ForEach-Object {
        if ($_ -match $RegexRegion) { 
            $matches[1] 
        }
    } | Where-Object { $_ -ne $null } # Filter out null values

    if ($vpnLocations.Count -eq 0) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] No VPN locations found. Retrying in $CHANGE_EVERY seconds..."
        Start-Sleep -Seconds $CHANGE_EVERY
        continue
    }

    $VPN_LOCATION = Get-Random -InputObject $vpnLocations
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] New VPN location selected: '$VPN_LOCATION'."
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Connecting to the location. Please wait up to 15 seconds..."
    
    # Connect to the selected VPN location
    & $expressVPNPath connect $VPN_LOCATION
    Start-Sleep -Seconds 2 # Just to be safe if expressvpn has some latency.
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Connected to $VPN_LOCATION."
    Echo-PublicIP
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Waiting for $CHANGE_EVERY seconds before switching location."
    Start-Sleep -Seconds $CHANGE_EVERY
    
    # Disconnect the current VPN
    & $expressVPNPath disconnect
    Start-Sleep -Seconds 2 # Just to be safe if expressvpn has some latency.
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Disconnected."
}
