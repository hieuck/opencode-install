<#
.SYNOPSIS
    Kịch bản tự động gỡ sạch, cài đặt mới OpenCode và tích hợp toàn bộ Plugin / MCP:
    - OpenCode CLI
    - Superpowers (obra/superpowers)
    - ECC (affaan-m/ECC - profile developer)
    - CodeGraph (colbymchenry/codegraph)
    - Andrej Karpathy Skills (multica-ai/andrej-karpathy-skills)

.PARAMETER SkipUninstall
    Bỏ qua bước gỡ cài đặt, chỉ cập nhật và thiết lập lại plugin/cấu hình.
#>
[CmdletBinding()]
param (
    [switch]$SkipUninstall = $false
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Step {
    param([string]$Msg)
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [>>] $Msg" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Msg)
    Write-Host "  [OK] $Msg" -ForegroundColor Green
}

function Write-Info {
    param([string]$Msg)
    Write-Host "  [..] $Msg" -ForegroundColor Gray
}

function Write-Warn {
    param([string]$Msg)
    Write-Host "  [!] $Msg" -ForegroundColor Yellow
}

# -----------------------------------------------------------
# 0. KIỂM TRA MÔI TRƯỜNG YÊU CẦU
# -----------------------------------------------------------
Write-Step "1. Kiểm tra môi trường hệ thống (Node.js, npm, git)"

try {
    $nodeVer = & node --version
    $npmVer = & npm --version
    Write-Success "Node.js: $nodeVer | npm: $npmVer"
} catch {
    Write-Error "Không tìm thấy Node.js/npm. Vui lòng cài đặt Node.js trước khi chạy script."
    exit 1
}

try {
    $gitVer = & git --version
    Write-Success "Git: $gitVer"
} catch {
    Write-Error "Không tìm thấy Git. Vui lòng cài đặt Git trước khi chạy script."
    exit 1
}

# -----------------------------------------------------------
# 1. GỠ BỎ SẠCH SẼ OPENCODE CŨ
# -----------------------------------------------------------
if (-not $SkipUninstall) {
    Write-Step "2. Dọn dẹp & Gỡ bỏ hoàn toàn OpenCode hiện tại"

    Write-Info "Dừng tất cả các tiến trình OpenCode đang chạy..."
    Get-Process | Where-Object { $_.Path -like "*opencode*" -or $_.Name -like "*opencode*" } | Stop-Process -Force -ErrorAction SilentlyContinue

    Write-Info "Chạy trình gỡ cài đặt chính thức OpenCode Desktop (nếu có)..."
    $uninstallerDesktop1 = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\Uninstall OpenCode.exe"
    $uninstallerDesktop2 = "$env:LOCALAPPDATA\OpenCode\uninstall.exe"

    if (Test-Path $uninstallerDesktop1) {
        Write-Info "Gỡ OpenCode Desktop 1..."
        Start-Process -FilePath $uninstallerDesktop1 -ArgumentList "/currentuser /S" -Wait -ErrorAction SilentlyContinue
    }
    if (Test-Path $uninstallerDesktop2) {
        Write-Info "Gỡ OpenCode Desktop 2..."
        Start-Process -FilePath $uninstallerDesktop2 -ArgumentList "/S" -Wait -ErrorAction SilentlyContinue
    }

    Write-Info "Gỡ bỏ gói opencode-ai toàn cục từ npm..."
    & npm uninstall -g opencode-ai 2>$null

    Write-Info "Xóa sạch các thư mục dữ liệu, cấu hình và bộ nhớ đệm cũ..."
    $cleanPaths = @(
        "$env:USERPROFILE\.config\opencode",
        "$env:APPDATA\ai.opencode.desktop",
        "$env:APPDATA\OpenCode",
        "$env:LOCALAPPDATA\@opencode-aidesktop-updater",
        "$env:LOCALAPPDATA\ai.opencode.desktop",
        "$env:LOCALAPPDATA\OpenCode",
        "$env:LOCALAPPDATA\Programs\@opencode-aidesktop"
    )

    foreach ($p in $cleanPaths) {
        if (Test-Path $p) {
            Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
            Write-Info "Đã xóa: $p"
        }
    }
    Write-Success "Đã gỡ bỏ sạch sẽ toàn bộ OpenCode cũ."
} else {
    Write-Step "2. Bỏ qua bước gỡ cài đặt (-SkipUninstall)"
}

# -----------------------------------------------------------
# 2. CÀI ĐẶT MỚI OPENCODE CLI & CÁC CÔNG CỤ CƠ SỞ
# -----------------------------------------------------------
Write-Step "3. Cài đặt mới OpenCode CLI và các công cụ bổ trợ"

Write-Info "Cài đặt opencode-ai toàn cục qua npm..."
& npm install -g --allow-scripts=opencode-ai opencode-ai

Write-Info "Đảm bảo @colbymchenry/codegraph và ecc-universal đã sẵn sàng..."
& npm install -g @colbymchenry/codegraph ecc-universal

$configDir = "$env:USERPROFILE\.config\opencode"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$opencodeVer = & opencode --version
Write-Success "OpenCode CLI đã sẵn sàng: phiên bản $opencodeVer"

# -----------------------------------------------------------
# 3. CÀI ĐẶT CODEGRAPH MCP
# -----------------------------------------------------------
Write-Step "4. Cài đặt và cấu hình CodeGraph MCP (colbymchenry/codegraph)"

& codegraph install --target opencode --location global --yes
Write-Success "CodeGraph MCP đã được cấu hình cho OpenCode."

# -----------------------------------------------------------
# 4. CÀI ĐẶT ECC (EVERYTHING CLAUDE CODE - DEVELOPER PROFILE)
# -----------------------------------------------------------
Write-Step "5. Cài đặt ECC - Everything Claude Code (affaan-m/ECC)"

& ecc install --profile developer --target opencode --no-hooks
Write-Success "ECC Developer Profile đã được cài đặt vào OpenCode."

# -----------------------------------------------------------
# 5. CÀI ĐẶT SUPERPOWERS PLUGIN
# -----------------------------------------------------------
Write-Step "6. Cài đặt Superpowers (obra/superpowers)"

& opencode plugin superpowers@git+https://github.com/obra/superpowers.git -g

# Cài đặt dự phòng trong node_modules và đồng bộ skills
Push-Location $configDir
try {
    & npm install superpowers@git+https://github.com/obra/superpowers.git --silent
    if (Test-Path "$configDir\node_modules\superpowers\skills") {
        Copy-Item -Path "$configDir\node_modules\superpowers\skills\*" -Destination "$configDir\skills\" -Recurse -Force
        Write-Success "Đã đồng bộ bộ kỹ năng của Superpowers vào $configDir\skills."
    }
} finally {
    Pop-Location
}

# -----------------------------------------------------------
# 6. TÍCH HỢP ANDREJ KARPATHY SKILLS & GUIDELINES
# -----------------------------------------------------------
Write-Step "7. Tích hợp Andrej Karpathy Coding Guidelines (multica-ai/andrej-karpathy-skills)"

$karpathyContent = @"
---
name: karpathy-guidelines
description: Behavioral guidelines derived from Andrej Karpathy's observations. Use to enforce disciplined, surgical, test-driven coding and avoid over-engineering or silent assumptions.
---

# Andrej Karpathy Coding Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
"@

# Lưu thành tệp hướng dẫn toàn cục và skill
$karpathyFile = "$configDir\karpathy-guidelines.md"
[System.IO.File]::WriteAllText($karpathyFile, $karpathyContent, [System.Text.Encoding]::UTF8)

$karpathySkillDir = "$configDir\skills\karpathy-guidelines"
if (-not (Test-Path $karpathySkillDir)) {
    New-Item -ItemType Directory -Path $karpathySkillDir -Force | Out-Null
}
[System.IO.File]::WriteAllText("$karpathySkillDir\SKILL.md", $karpathyContent, [System.Text.Encoding]::UTF8)
Write-Success "Đã tạo kỹ năng và chỉ dẫn Andrej Karpathy trong $configDir."

# -----------------------------------------------------------
# 7. CHUẨN HÓA VÀ TỐI ƯU TỆP OPENCODE.JSON
# -----------------------------------------------------------
Write-Step "8. Chuẩn hóa tệp cấu hình opencode.json"

$jsonPath = "$configDir\opencode.json"
if (Test-Path $jsonPath) {
    $rawJson = Get-Content $jsonPath -Raw -Encoding UTF8
    $cfg = $rawJson | ConvertFrom-Json

    # 1. Tối ưu plugin array (tránh trùng lặp)
    $plugins = [System.Collections.Generic.List[string]]::new()
    $plugins.Add("./plugins")
    $plugins.Add("superpowers@git+https://github.com/obra/superpowers.git")
    $cfg.plugin = $plugins.ToArray()

    # 2. Đảm bảo skills.paths trỏ đúng
    if (-not $cfg.skills) {
        $cfg | Add-Member -MemberType NoteProperty -Name "skills" -Value ([PSCustomObject]@{})
    }
    $cfg.skills.paths = @("./skills", "~/.config/opencode/skills")

    # 3. Đảm bảo instructions có cả AGENTS.md và karpathy-guidelines.md
    $instList = [System.Collections.Generic.List[string]]::new()
    if ($cfg.instructions) {
        foreach ($item in $cfg.instructions) {
            if (-not $instList.Contains($item)) { $instList.Add($item) }
        }
    }
    if (-not $instList.Contains("AGENTS.md")) { $instList.Insert(0, "AGENTS.md") }
    if (-not $instList.Contains("karpathy-guidelines.md")) { $instList.Insert(1, "karpathy-guidelines.md") }
    $cfg.instructions = $instList.ToArray()

    # 4. Đảm bảo codegraph MCP được đăng ký
    if (-not $cfg.mcp) {
        $cfg | Add-Member -MemberType NoteProperty -Name "mcp" -Value ([PSCustomObject]@{})
    }
    $cfg.mcp | Add-Member -MemberType NoteProperty -Name "codegraph" -Value ([PSCustomObject]@{
        type = "local"
        command = @("codegraph", "serve", "--mcp")
        enabled = $true
    }) -Force

    $newJson = $cfg | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($jsonPath, $newJson, [System.Text.Encoding]::UTF8)
    Write-Success "Đã chuẩn hóa opencode.json thành công."
}

# -----------------------------------------------------------
# 8. XÁC MINH HOÀN TẤT
# -----------------------------------------------------------
Write-Step "9. Kiểm tra và xác nhận trạng thái cài đặt"

Write-Host "`n[+] Danh sách MCP Servers:" -ForegroundColor Magenta
& opencode mcp list

$skillCount = (Get-ChildItem "$configDir\skills" -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host "`n[+] Tổng số kỹ năng (Skills) đã cài đặt: $skillCount" -ForegroundColor Magenta
Write-Host "    - Superpowers (TDD, Brainstorming, Subagents, v.v.)" -ForegroundColor Gray
    Write-Host "    - ECC Developer (Database, Quality, Memory, v.v.)" -ForegroundColor Gray
    Write-Host "    - Karpathy Guidelines (Surgical changes, Simplicity, v.v.)" -ForegroundColor Gray

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " HOÀN TẤT CÀI ĐẶT VÀ CẤU HÌNH OPENCODE THÀNH CÔNG!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Bạn có thể khởi động OpenCode Desktop hoặc gõ 'opencode' trong terminal để bắt đầu!`n"