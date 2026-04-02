#Requires -RunAsAdministrator

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Run as Administrator." -ForegroundColor Red
    exit 1
}

$results = @{}

Write-Host "STEP 1: Lock local models to localhost" -ForegroundColor Cyan
try {
    $ports = @{ 11434 = "Ollama"; 1234 = "LM Studio"; 39281 = "Cortex" }
    foreach ($port in $ports.Keys) {
        $listening = netstat -an | Select-String ":$port\s"
        if ($listening) {
            if ($listening -match "0\.0\.0\.0:$port") {
                Write-Host "WARNING: $($ports[$port]) exposed on 0.0.0.0" -ForegroundColor Red
            } else {
                Write-Host "OK: $($ports[$port]) on 127.0.0.1" -ForegroundColor Green
            }
        } else {
            Write-Host "INFO: Nothing on port $port" -ForegroundColor Gray
        }
    }
    setx OLLAMA_HOST "127.0.0.1" | Out-Null
    Write-Host "Set OLLAMA_HOST=127.0.0.1" -ForegroundColor Green
    $results["Step 1"] = "PASSED"
} catch {
    $results["Step 1"] = "FAILED"
    Write-Host "FAILED: $_" -ForegroundColor Red
}

Write-Host "STEP 2: Install Tailscale" -ForegroundColor Cyan
try {
    winget install Tailscale.Tailscale --accept-source-agreements --accept-package-agreements
    Write-Host "Run: tailscale up --ssh" -ForegroundColor Yellow
    $results["Step 2"] = "PASSED"
} catch {
    $results["Step 2"] = "FAILED"
    Write-Host "FAILED: $_" -ForegroundColor Red
}

Write-Host "STEP 3: Firewall and stealth mode" -ForegroundColor Cyan
try {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
    Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
    Remove-NetFirewallRule -Name "Block ICMPv4-In" -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Block ICMPv4-In" -Name "Block ICMPv4-In" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Block | Out-Null
    Write-Host "Firewall hardened and stealth mode enabled" -ForegroundColor Green
    $results["Step 3"] = "PASSED"
} catch {
    $results["Step 3"] = "FAILED"
    Write-Host "FAILED: $_" -ForegroundColor Red
}

Write-Host "STEP 4: Open WebUI security variables" -ForegroundColor Cyan
try {
    $secretKey = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })
    setx WEBUI_SECRET_KEY "$secretKey" | Out-Null
    setx ENABLE_SIGNUP "False" | Out-Null
    setx ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS "False" | Out-Null
    Write-Host "Security variables set." -ForegroundColor Green
    Write-Host "Run: docker compose down && docker compose up -d" -ForegroundColor Yellow
    $results["Step 4"] = "PASSED"
} catch {
    $results["Step 4"] = "FAILED"
    Write-Host "FAILED: $_" -ForegroundColor Red
}

Write-Host "STEP 5: Update Docker Desktop" -ForegroundColor Cyan
try {
    winget upgrade Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    Write-Host "Docker updated" -ForegroundColor Green
    $results["Step 5"] = "PASSED"
} catch {
    $results["Step 5"] = "FAILED"
    Write-Host "FAILED: $_" -ForegroundColor Red
}

Write-Host "STEP 6: Install SimpleWall" -ForegroundColor Cyan
try {
    winget install Henry++.simplewall --accept-source-agreements --accept-package-agreements
    Write-Host "SimpleWall installed" -ForegroundColor Green
    $results["Step 6"] = "PASSED"
} catch {
    $results["Step 6"] = "FAILED"
    Write-Host "FAILED: $_" -ForegroundColor Red
}

Write-Host "BONUS: Check openclaw.json for API keys" -ForegroundColor Cyan
try {
    $configPath = Join-Path $HOME ".openclaw\openclaw.json"
    if (Test-Path $configPath) {
        Write-Host "WARNING: Found $configPath - move api_key values to setx" -ForegroundColor Red
    } else {
        Write-Host "OK: No openclaw.json found" -ForegroundColor Green
    }
    $results["Bonus"] = "PASSED"
} catch {
    $results["Bonus"] = "FAILED"
    Write-Host "FAILED: $_" -ForegroundColor Red
}

Write-Host "== SUMMARY ==" -ForegroundColor Cyan
foreach ($step in $results.GetEnumerator() | Sort-Object Name) {
    $color = if ($step.Value -eq "PASSED") { "Green" } else { "Red" }
    Write-Host "  [$($step.Value)] $($step.Name)" -ForegroundColor $color
}
Write-Host "Done. Your ROG Zephyrus is hardened." -ForegroundColor Cyan