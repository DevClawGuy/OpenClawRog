# ROG Zephyrus Windows Security Hardening -- OpenClaw Edition
#
# Usage: Right-click PowerShell -> Run as Administrator -> cd into repo folder -> .\secure-rog.ps1

#Requires -RunAsAdministrator

# --- Admin check ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell -> Run as Administrator, then re-run this script." -ForegroundColor Yellow
    exit 1
}

$results = @{}

# ============================================================================
# STEP 1 -- Lock local models to localhost
# ============================================================================
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 1: Lock local models to localhost" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $ports = @{
        11434 = "Ollama"
        1234  = "LM Studio"
        39281 = "Cortex"
    }

    foreach ($port in $ports.Keys) {
        $listening = netstat -an | Select-String ":$port\s"
        if ($listening) {
            foreach ($line in $listening) {
                if ($line -match "0\.0\.0\.0:$port") {
                    Write-Host "WARNING: $($ports[$port]) on port $port is listening on 0.0.0.0 (exposed to network!)" -ForegroundColor Red
                } elseif ($line -match "127\.0\.0\.1:$port") {
                    Write-Host "OK: $($ports[$port]) on port $port is bound to 127.0.0.1" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "INFO: Nothing listening on port $port ($($ports[$port]))" -ForegroundColor Gray
        }
    }

    setx OLLAMA_HOST "127.0.0.1" | Out-Null
    Write-Host "Set OLLAMA_HOST=127.0.0.1 permanently via setx" -ForegroundColor Green

    $results["Step 1 - Lock local models to localhost"] = "PASSED"
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    $results["Step 1 - Lock local models to localhost"] = "FAILED"
}

# ============================================================================
# STEP 2 -- Install Tailscale
# ============================================================================
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 2: Install Tailscale" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    winget install Tailscale.Tailscale --accept-source-agreements --accept-package-agreements
    Write-Host "`nAfter install, run:" -ForegroundColor Yellow
    Write-Host "  tailscale up --ssh" -ForegroundColor White
    Write-Host "`nWARNING: Use 'tailscale serve' only. NEVER use 'tailscale funnel' -- it exposes services to the public internet." -ForegroundColor Red

    $results["Step 2 - Install Tailscale"] = "PASSED"
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    $results["Step 2 - Install Tailscale"] = "FAILED"
}

# ============================================================================
# STEP 3 -- Enable firewall and stealth mode
# ============================================================================
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 3: Enable firewall and stealth mode" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
    Write-Host "Enabled Windows Firewall on all profiles (Domain, Public, Private)" -ForegroundColor Green

    Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
    Write-Host "Set DefaultInboundAction to Block on all profiles" -ForegroundColor Green

    # Remove existing rule if present to avoid duplicates
    Remove-NetFirewallRule -Name "Block ICMPv4-In" -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Block ICMPv4-In" -Name "Block ICMPv4-In" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Block | Out-Null
    Write-Host "Added firewall rule to block ICMPv4 ping responses (stealth mode)" -ForegroundColor Green

    $results["Step 3 - Enable firewall and stealth mode"] = "PASSED"
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    $results["Step 3 - Enable firewall and stealth mode"] = "FAILED"
}

# ============================================================================
# STEP 4 -- Set Open WebUI security variables
# ============================================================================
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 4: Set Open WebUI security variables" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $secretKey = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })
    setx WEBUI_SECRET_KEY "$secretKey" | Out-Null
    Write-Host "Generated and set WEBUI_SECRET_KEY (32-byte hex)" -ForegroundColor Green

    setx ENABLE_SIGNUP "False" | Out-Null
    Write-Host "Set ENABLE_SIGNUP=False" -ForegroundColor Green

    setx ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS "False" | Out-Null
    Write-Host "Set ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS=False" -ForegroundColor Green

    Write-Host "`nRestart Docker to apply:" -ForegroundColor Yellow
    Write-Host "  docker compose down && docker compose up -d" -ForegroundColor White

    $results["Step 4 - Set Open WebUI security variables"] = "PASSED"
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    $results["Step 4 - Set Open WebUI security variables"] = "FAILED"
}

# ============================================================================
# STEP 5 -- Update Docker Desktop
# ============================================================================
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 5: Update Docker Desktop" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    winget upgrade Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    Write-Host "WARNING: CVE-2025-9074 -- container escape vulnerability. Ensure Docker Desktop is fully up to date." -ForegroundColor Red

    $results["Step 5 - Update Docker Desktop"] = "PASSED"
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    $results["Step 5 - Update Docker Desktop"] = "FAILED"
}

# ============================================================================
# STEP 6 -- Install SimpleWall (outbound monitor, LuLu equivalent)
# ============================================================================
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 6: Install SimpleWall" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    winget install Henry++.simplewall --accept-source-agreements --accept-package-agreements
    Write-Host "WARNING: Windows Firewall only blocks inbound. SimpleWall watches outbound." -ForegroundColor Yellow
    Write-Host "Do NOT stack with GlassWire -- pick one outbound monitor." -ForegroundColor Red

    $results["Step 6 - Install SimpleWall"] = "PASSED"
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    $results["Step 6 - Install SimpleWall"] = "FAILED"
}

# ============================================================================
# BONUS -- Check for API keys in config files
# ============================================================================
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "BONUS: Check for API keys in config files" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $configPath = Join-Path $HOME ".openclaw\openclaw.json"
    if (Test-Path $configPath) {
        Write-Host "WARNING: Found $configPath" -ForegroundColor Red
        Write-Host "If this file contains api_key values, move them to environment variables:" -ForegroundColor Yellow
        Write-Host '  setx OPENCLAW_API_KEY "your_key_here"' -ForegroundColor White
        Write-Host "Then remove the api_key entries from the JSON file." -ForegroundColor Yellow
    } else {
        Write-Host "OK: No openclaw.json config file found at $configPath" -ForegroundColor Green
    }

    $results["Bonus - Check for API keys"] = "PASSED"
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    $results["Bonus - Check for API keys"] = "FAILED"
}

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

foreach ($step in $results.GetEnumerator() | Sort-Object Name) {
    if ($step.Value -eq "PASSED") {
        Write-Host "  [PASS] $($step.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $($step.Name)" -ForegroundColor Red
    }
}

$failed = ($results.Values | Where-Object { $_ -eq "FAILED" }).Count
if ($failed -eq 0) {
    Write-Host "`nAll steps completed successfully." -ForegroundColor Green
} else {
    Write-Host "`n$failed step(s) failed. Review the output above." -ForegroundColor Yellow
}

Write-Host "`nDone. Your ROG Zephyrus is hardened." -ForegroundColor Cyan
