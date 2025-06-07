function Test-NetworkConnectivity {
    param(
        [string[]]$Hosts = @("8.8.8.8", "1.1.1.1", "google.com"),
        [int]$Count = 4
    )

    $verboseMode = Get-Setting -Key "core.verbose"

    Write-Host "Network Connectivity Test" -ForegroundColor Blue
    Write-Host "=========================" -ForegroundColor Blue
    Write-Host ""

    foreach ($host in $Hosts) {
        Write-Host "Testing connectivity to " -NoNewline -ForegroundColor White
        Write-Host $host -ForegroundColor Cyan

        try {
            $pingResult = Test-Connection -ComputerName $host -Count $Count -ErrorAction Stop
            $avgResponseTime = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
            $packetLoss = (($Count - $pingResult.Count) / $Count) * 100

            Write-Host "  Status: " -NoNewline -ForegroundColor White
            Write-Host "Connected" -ForegroundColor Green
            Write-Host "  Average Response Time: " -NoNewline -ForegroundColor White
            Write-Host "${avgResponseTime}ms" -ForegroundColor Yellow
            Write-Host "  Packet Loss: " -NoNewline -ForegroundColor White

            if ($packetLoss -eq 0) {
                Write-Host "${packetLoss}%" -ForegroundColor Green
            } elseif ($packetLoss -lt 25) {
                Write-Host "${packetLoss}%" -ForegroundColor Yellow
            } else {
                Write-Host "${packetLoss}%" -ForegroundColor Red
            }

            if ($verboseMode) {
                Write-Host "  Details:" -ForegroundColor DarkGray
                foreach ($ping in $pingResult) {
                    Write-Host "    $($ping.Address): $($ping.ResponseTime)ms" -ForegroundColor DarkGray
                }
            }
        }
        catch {
            Write-Host "  Status: " -NoNewline -ForegroundColor White
            Write-Host "Failed" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
}

function Test-DNSResolution {
    param(
        [string[]]$Domains = @("google.com", "microsoft.com", "github.com"),
        [string[]]$DNSServers = @("8.8.8.8", "1.1.1.1")
    )

    Write-Host "DNS Resolution Test" -ForegroundColor Blue
    Write-Host "===================" -ForegroundColor Blue
    Write-Host ""

    foreach ($domain in $Domains) {
        Write-Host "Resolving " -NoNewline -ForegroundColor White
        Write-Host $domain -ForegroundColor Cyan

        foreach ($dnsServer in $DNSServers) {
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $result = Resolve-DnsName -Name $domain -Server $dnsServer -ErrorAction Stop
                $stopwatch.Stop()

                $ipAddresses = $result | Where-Object { $_.Type -eq "A" } | Select-Object -ExpandProperty IPAddress

                Write-Host "  DNS Server: " -NoNewline -ForegroundColor White
                Write-Host $dnsServer -NoNewline -ForegroundColor Yellow
                Write-Host " (${($stopwatch.ElapsedMilliseconds)}ms)" -ForegroundColor DarkGray
                Write-Host "  IP Addresses: " -NoNewline -ForegroundColor White
                Write-Host ($ipAddresses -join ", ") -ForegroundColor Green
            }
            catch {
                Write-Host "  DNS Server: " -NoNewline -ForegroundColor White
                Write-Host $dnsServer -NoNewline -ForegroundColor Yellow
                Write-Host " - " -NoNewline
                Write-Host "Failed" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
}

function Test-NetworkSpeed {
    param(
        [string]$TestUrl = "",
        [int]$TimeoutSeconds = 30,
        [int]$TestDurationSeconds = 25
    )

    Write-Host "Network Speed Test" -ForegroundColor Blue
    Write-Host "==================" -ForegroundColor Blue
    Write-Host ""

    # List of fallback test URLs - larger files for better speed testing
    $testUrls = @(
        "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US",
        "https://nodejs.org/dist/v20.9.0/node-v20.9.0-x64.msi",
        "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
    )

    # Use provided URL or try fallback URLs
    $urlsToTry = if ($TestUrl) { @($TestUrl) + $testUrls } else { $testUrls }

    $testSuccessful = $false

    foreach ($url in $urlsToTry) {
        Write-Host "Testing download speed..." -ForegroundColor White
        Write-Host "Test URL: " -NoNewline -ForegroundColor DarkGray
        Write-Host $url -ForegroundColor DarkGray
        Write-Host "Test Duration: " -NoNewline -ForegroundColor DarkGray
        Write-Host "${TestDurationSeconds} seconds" -ForegroundColor DarkGray
        Write-Host ""

        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Create HttpWebRequest for better timeout control
            $request = [System.Net.HttpWebRequest]::Create($url)
            $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            $request.Timeout = $TimeoutSeconds * 1000
            $request.ReadWriteTimeout = $TimeoutSeconds * 1000

            # Add headers to appear more like a regular browser
            $request.Accept = "*/*"
            $request.Headers.Add("Accept-Language", "en-US,en;q=0.9")
            $request.Headers.Add("Accept-Encoding", "gzip, deflate")

            $response = $request.GetResponse()
            $responseStream = $response.GetResponseStream()

            # Read data for a specific duration to get speed measurement
            $buffer = New-Object byte[] 32768  # 32KB buffer for faster reading
            $totalBytesRead = 0
            $bytesRead = 0
            $testDurationMs = $TestDurationSeconds * 1000

            Write-Host "Downloading..." -ForegroundColor Yellow

            do {
                $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -gt 0) {
                    $totalBytesRead += $bytesRead

                    # Show progress every 1MB
                    if ($totalBytesRead % (1024 * 1024) -lt $bytesRead) {
                        $currentMB = [Math]::Round($totalBytesRead / 1MB, 1)
                        $currentSpeed = [Math]::Round(($totalBytesRead * 8) / ($stopwatch.ElapsedMilliseconds * 1000), 1)
                        Write-Host "`r  Downloaded: ${currentMB} MB - Current Speed: ${currentSpeed} Mbps" -NoNewline -ForegroundColor Cyan
                    }
                }
            } while ($bytesRead -gt 0 -and $stopwatch.ElapsedMilliseconds -lt $testDurationMs)

            Write-Host "" # New line after progress

            # Clean up
            $responseStream.Close()
            $response.Close()

            $stopwatch.Stop()

            $fileSizeBytes = $totalBytesRead
            $fileSizeMB = [Math]::Round($fileSizeBytes / 1MB, 2)
            $timeSeconds = $stopwatch.ElapsedMilliseconds / 1000
            $speedMbps = [Math]::Round(($fileSizeBytes * 8) / ($timeSeconds * 1000000), 2)
            $speedMBps = [Math]::Round($fileSizeBytes / ($timeSeconds * 1000000), 2)

            Write-Host ""
            Write-Host "Download Test Results:" -ForegroundColor Green
            Write-Host "  Data Downloaded: " -NoNewline -ForegroundColor White
            Write-Host "${fileSizeMB} MB" -ForegroundColor Cyan
            Write-Host "  Test Duration: " -NoNewline -ForegroundColor White
            Write-Host "${timeSeconds} seconds" -ForegroundColor Cyan
            Write-Host "  Download Speed: " -NoNewline -ForegroundColor White
            Write-Host "${speedMbps} Mbps" -NoNewline -ForegroundColor Yellow
            Write-Host " (${speedMBps} MB/s)" -ForegroundColor Yellow

            # Provide speed assessment
            if ($speedMbps -gt 100) {
                Write-Host "  Assessment: " -NoNewline -ForegroundColor White
                Write-Host "Excellent" -ForegroundColor Green
            } elseif ($speedMbps -gt 50) {
                Write-Host "  Assessment: " -NoNewline -ForegroundColor White
                Write-Host "Very Good" -ForegroundColor Green
            } elseif ($speedMbps -gt 25) {
                Write-Host "  Assessment: " -NoNewline -ForegroundColor White
                Write-Host "Good" -ForegroundColor Yellow
            } elseif ($speedMbps -gt 10) {
                Write-Host "  Assessment: " -NoNewline -ForegroundColor White
                Write-Host "Fair" -ForegroundColor Yellow
            } else {
                Write-Host "  Assessment: " -NoNewline -ForegroundColor White
                Write-Host "Slow" -ForegroundColor Red
            }

            $testSuccessful = $true
            break # Exit the loop on successful test
        }
        catch [System.Net.WebException] {
            $statusCode = ""
            if ($_.Exception.Response) {
                $statusCode = " (HTTP $([int]$_.Exception.Response.StatusCode) - $($_.Exception.Response.StatusCode))"
            }

            Write-Host "Download test failed: " -NoNewline -ForegroundColor Red
            if ($_.Exception.Status -eq [System.Net.WebExceptionStatus]::Timeout) {
                Write-Host "Connection timed out after $TimeoutSeconds seconds" -ForegroundColor Red
            } else {
                Write-Host "$($_.Exception.Message)$statusCode" -ForegroundColor Red
            }

            if ($url -ne $urlsToTry[-1]) {
                Write-Host "Trying alternative URL..." -ForegroundColor Yellow
                Write-Host ""
            }
        }
        catch {
            Write-Host "Download test failed: " -NoNewline -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            if ($url -ne $urlsToTry[-1]) {
                Write-Host "Trying alternative URL..." -ForegroundColor Yellow
                Write-Host ""
            }
        }
        finally {
            if ($responseStream) {
                $responseStream.Close()
                $responseStream.Dispose()
            }
            if ($response) {
                $response.Close()
            }
        }
    }

    if (-not $testSuccessful) {
        Write-Host "All speed test URLs failed. Network speed test could not be completed." -ForegroundColor Red
    }

    Write-Host ""
}

function Get-NetworkConfiguration {
    Write-Host "Network Configuration" -ForegroundColor Blue
    Write-Host "=====================" -ForegroundColor Blue
    Write-Host ""

    try {
        # Get network adapters
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

        Write-Host "Active Network Adapters:" -ForegroundColor Green
        foreach ($adapter in $adapters) {
            Write-Host "  Name: " -NoNewline -ForegroundColor White
            Write-Host $adapter.Name -ForegroundColor Cyan
            Write-Host "  Description: " -NoNewline -ForegroundColor White
            Write-Host $adapter.InterfaceDescription -ForegroundColor White
            Write-Host "  Link Speed: " -NoNewline -ForegroundColor White
            Write-Host $adapter.LinkSpeed -ForegroundColor Yellow

            # Get IP configuration
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($ipConfig) {
                Write-Host "  IPv4 Address: " -NoNewline -ForegroundColor White
                Write-Host $ipConfig.IPAddress -ForegroundColor Green
                Write-Host "  Subnet: " -NoNewline -ForegroundColor White
                Write-Host "$($ipConfig.IPAddress)/$($ipConfig.PrefixLength)" -ForegroundColor Green
            }

            # Get default gateway
            $gateway = Get-NetRoute -InterfaceIndex $adapter.InterfaceIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
            if ($gateway) {
                Write-Host "  Default Gateway: " -NoNewline -ForegroundColor White
                Write-Host $gateway.NextHop -ForegroundColor Green
            }

            Write-Host ""
        }

        # Get DNS servers
        $dnsServers = Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 -and $_.ServerAddresses.Count -gt 0 }
        if ($dnsServers) {
            Write-Host "DNS Servers:" -ForegroundColor Green
            foreach ($dns in $dnsServers) {
                Write-Host "  Interface: " -NoNewline -ForegroundColor White
                Write-Host $dns.InterfaceAlias -NoNewline -ForegroundColor Cyan
                Write-Host " - Servers: " -NoNewline -ForegroundColor White
                Write-Host ($dns.ServerAddresses -join ", ") -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "Failed to retrieve network configuration: " -NoNewline -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function Invoke-NetworkDiagnostics {
    param(
        [switch]$SkipSpeed,
        [switch]$Full,
        [string[]]$TestHosts,
        [string[]]$TestDomains
    )

    $verboseMode = Get-Setting -Key "core.verbose"

    Write-Host "PowerTool Network Diagnostics" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""

    # Network Configuration
    if ($Full) {
        Get-NetworkConfiguration
        Write-Host ""
    }

    # Connectivity Test
    $hosts = if ($TestHosts) { $TestHosts } else { @("8.8.8.8", "1.1.1.1", "google.com") }
    Test-NetworkConnectivity -Hosts $hosts

    # DNS Resolution Test
    $domains = if ($TestDomains) { $TestDomains } else { @("google.com", "microsoft.com", "github.com") }
    Test-DNSResolution -Domains $domains

    # Speed Test (optional)
    if (-not $SkipSpeed) {
        Test-NetworkSpeed
    }

    Write-Host "Network diagnostics completed." -ForegroundColor Green
}

# Add the command to the existing SystemUtils module commands
if (-not $script:ModuleCommands) {
    $script:ModuleCommands = @{}
}

$script:ModuleCommands = @{
    "network" = @{
        Aliases = @("net", "nettest", "speedtest")
        Action = {
            $skipSpeed = $PSBoundParameters.ContainsKey('SkipSpeed') -and $SkipSpeed
            $fullTest = $PSBoundParameters.ContainsKey('Full') -and $Full

            # Parse custom hosts and domains from Value1 and Value2
            $customHosts = if ($Value1) { $Value1 -split ',' | ForEach-Object { $_.Trim() } } else { $null }
            $customDomains = if ($Value2) { $Value2 -split ',' | ForEach-Object { $_.Trim() } } else { $null }

            Invoke-NetworkDiagnostics -SkipSpeed:$skipSpeed -Full:$fullTest -TestHosts $customHosts -TestDomains $customDomains
        }
        Summary = "Perform comprehensive network diagnostics including connectivity, DNS, speed tests, and configuration."
        Options = @{
            0 = @(
                @{ Token = "test-hosts"; Type = "OptionalArgument"; Description = "Comma-separated list of hosts to test connectivity (default: 8.8.8.8,1.1.1.1,google.com)" }
                @{ Token = "test-domains"; Type = "OptionalArgument"; Description = "Comma-separated list of domains for DNS testing (default: google.com,microsoft.com,github.com)" }
                @{ Token = "SkipSpeed"; Type = "OptionalParameter"; Description = "Skip the download speed test" }
                @{ Token = "Full"; Type = "OptionalParameter"; Description = "Include detailed network configuration information" }
            )
        }
        Examples = @(
            "powertool network",
            "powertool net -SkipSpeed",
            "powertool nettest -Full",
            "powertool speedtest",
            "pt network 'cloudflare.com,github.com' 'example.com,stackoverflow.com'"
        )
    }
}

Export-ModuleMember -Function Test-NetworkConnectivity, Test-DNSResolution, Test-NetworkSpeed, Get-NetworkConfiguration, Invoke-NetworkDiagnostics -Variable ModuleCommands