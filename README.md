# OpenClawRog

## Windows Security Hardening Script

`secure-rog.ps1` is a PowerShell script that hardens a Windows 11 ROG Zephyrus laptop running local AI models (Ollama, LM Studio, Cortex) and Open WebUI via Docker. It is the Windows equivalent of the Mac Mini OpenClaw security checklist.

### What it does

1. **Lock local models to localhost** — Checks ports 11434, 1234, 39281 for services bound to 0.0.0.0 and sets `OLLAMA_HOST=127.0.0.1`
2. **Install Tailscale** — Installs via winget for secure remote access (SSH over Tailscale, never funnel)
3. **Enable firewall and stealth mode** — Enables Windows Firewall on all profiles, blocks inbound by default, blocks ICMP ping responses
4. **Set Open WebUI security variables** — Generates a `WEBUI_SECRET_KEY`, disables signup, disables pip install from frontmatter
5. **Update Docker Desktop** — Upgrades Docker Desktop via winget with a CVE-2025-9074 warning
6. **Install SimpleWall** — Outbound traffic monitor (LuLu equivalent for Windows)
7. **Bonus: API key check** — Warns if `~/.openclaw/openclaw.json` contains API keys that should be moved to environment variables

### How to run

1. Right-click PowerShell → **Run as Administrator**
2. `cd` into the repo folder
3. Run the script:

```powershell
.\secure-rog.ps1
```

The script requires Administrator privileges and will exit with an error if not elevated. Each step runs independently — if one fails, the rest still execute. A summary is printed at the end.
