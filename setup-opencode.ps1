<#
.SYNOPSIS
    Kịch bản tự động gỡ sạch, cài đặt mới OpenCode và tích hợp toàn bộ Plugin / MCP:
    - OpenCode CLI (pin major v1 để tương thích opencode-goal-plugin)
    - Superpowers (obra/superpowers)
    - ECC (affaan-m/ECC - profile developer, giữ hook runtime)
    - CodeGraph (colbymchenry/codegraph)
    - Andrej Karpathy Skills (multica-ai/andrej-karpathy-skills)
    - opencode-goal-plugin (kèm slash command /goal)
    - 9Remote notify plugin (plugin/nineRemoteNotify.js)

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

Write-Info "Cài đặt opencode-ai toàn cục qua npm (pin major v1: opencode-goal-plugin chỉ hỗ trợ opencode >=1.17.15 <2)..."
& npm install -g --allow-scripts=opencode-ai opencode-ai@1

# Ưu tiên CodeGraph CLI standalone nếu đã có, tránh cài trùng 2 bản (standalone + npm) gây lệch version.
if (Get-Command codegraph -ErrorAction SilentlyContinue) {
    Write-Success "CodeGraph CLI đã có sẵn, bỏ qua cài npm để tránh trùng bản."
} else {
    Write-Info "Chưa có CodeGraph CLI, cài qua npm..."
    & npm install -g @colbymchenry/codegraph
}
Write-Info "Đảm bảo ecc-universal đã sẵn sàng..."
& npm install -g ecc-universal

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

# Giữ hook runtime của ECC (plugins/ecc-hooks.ts): setup chuẩn có file này, --no-hooks sẽ làm fresh-install lệch với máy đang chạy.
& ecc install --profile developer --target opencode --enable-hooks
Write-Success "ECC Developer Profile (kèm hooks) đã được cài đặt vào OpenCode."

# -----------------------------------------------------------
# 5. CÀI ĐẶT SUPERPOWERS PLUGIN
# -----------------------------------------------------------
Write-Step "6. Cài đặt Superpowers (obra/superpowers)"

& opencode plugin superpowers@git+https://github.com/obra/superpowers.git -g

# Cài đặt dự phòng trong node_modules và đồng bộ skills còn thiếu.
# CHỈ copy skill chưa tồn tại: cả 14 skill superpowers đều trùng tên với skill đã có,
# copy -Force mù quáng sẽ ghi đè (mất custom/ECC) mỗi lần chạy lại.
Push-Location $configDir
try {
    & npm install superpowers@git+https://github.com/obra/superpowers.git --silent
    $spSkills = "$configDir\node_modules\superpowers\skills"
    $destSkills = "$configDir\skills"
    if (Test-Path $spSkills) {
        if (-not (Test-Path $destSkills)) {
            New-Item -ItemType Directory -Path $destSkills -Force | Out-Null
        }
        $skipped = @()
        $copied = @()
        Get-ChildItem $spSkills -Directory | ForEach-Object {
            $dest = Join-Path $destSkills $_.Name
            if (Test-Path $dest) { $skipped += $_.Name }
            else {
                Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
                $copied += $_.Name
            }
        }
        if ($copied.Count -gt 0) { Write-Success "Đã thêm skill mới của Superpowers: $($copied -join ', ')." }
        if ($skipped.Count -gt 0) { Write-Info "Giữ nguyên skill đã tồn tại (không ghi đè): $($skipped -join ', ')." }
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
# 6b. KHÔI PHỤC GOAL PLUGIN & 9REMOTE NOTIFY (bước wipe đã xóa)
# -----------------------------------------------------------
Write-Step "8. Khôi phục opencode-goal-plugin và 9Remote notify plugin"

Push-Location $configDir
try {
    # 1. Đảm bảo package.json có opencode-goal-plugin (pin version theo README của plugin)
    if (-not (Test-Path "$configDir\package.json")) {
        '{ "dependencies": {} }' | Set-Content "$configDir\package.json" -Encoding UTF8
    }
    $pkg = Get-Content "$configDir\package.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $pkg.dependencies) {
        $pkg | Add-Member -MemberType NoteProperty -Name "dependencies" -Value ([PSCustomObject]@{})
    }
    $pkg.dependencies | Add-Member -MemberType NoteProperty -Name "opencode-goal-plugin" -Value "0.10.0" -Force
    [System.IO.File]::WriteAllText("$configDir\package.json", ($pkg | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)
    & npm install --silent
    Write-Success "opencode-goal-plugin@0.10.0 đã sẵn sàng trong $configDir\node_modules."
} finally {
    Pop-Location
}

# 2. Khôi phục plugin 9Remote notify (thư mục plugin/ số ít, opencode tự động load)
$nineRemotePath = "$configDir\plugin\nineRemoteNotify.js"
if (-not (Test-Path $nineRemotePath)) {
    $nineRemoteDir = Split-Path $nineRemotePath -Parent
    if (-not (Test-Path $nineRemoteDir)) {
        New-Item -ItemType Directory -Path $nineRemoteDir -Force | Out-Null
    }
    $nineRemoteContent = @'
// 9Remote OpenCode status plugin (auto-generated)
const base = "http://localhost:2208/api/notify";
const post = (type) => {
  const sid = process.env.NINE_REMOTE_SESSION_ID || "";
  if (!sid) return;
  const url = base + "?type=" + type + "&sessionId=" + encodeURIComponent(sid) + "&tool=opencode";
  try { fetch(url, { signal: AbortSignal.timeout(2000) }).catch(() => {}); } catch {}
};
export const nineRemoteNotify = async () => ({
  "chat.message": async () => post("working"),
  "tool.execute.before": async () => post("working"),
  "tool.execute.after": async () => post("working"),
  event: async ({ event }) => {
    const t = event?.type;
    if (!t) return;
    if (t === "session.idle") return post("done");
    if (t === "permission.asked" || t === "question.asked" || t === "session.error") return post("blocked");
    if (t === "session.compacted" || t === "permission.replied" || t === "question.replied") return post("working");
  },
});
'@
    [System.IO.File]::WriteAllText($nineRemotePath, $nineRemoteContent, [System.Text.Encoding]::UTF8)
    Write-Success "Đã khôi phục plugin 9Remote notify."
} else {
    Write-Info "Plugin 9Remote notify đã tồn tại, giữ nguyên."
}

# -----------------------------------------------------------
# 8. CHUẨN HÓA VÀ TỐI ƯU TỆP OPENCODE.JSON (merge, không ghi đè)
# -----------------------------------------------------------
Write-Step "9. Chuẩn hóa tệp cấu hình opencode.json"

$jsonPath = "$configDir\opencode.json"
$requiredPlugins = @(
    "./plugins",
    "superpowers@git+https://github.com/obra/superpowers.git",
    "opencode-goal-plugin@0.10.0"
)
$requiredSkillPaths = @("./skills", "~/.config/opencode/skills")

if (Test-Path $jsonPath) {
    $rawJson = Get-Content $jsonPath -Raw -Encoding UTF8
    $cfg = $rawJson | ConvertFrom-Json

    # 1. Merge plugin array: giữ entry lạ, đảm bảo đủ 3 entry bắt buộc.
    # (Ghi đè 2 entry như trước đây sẽ xóa goal-plugin và làm /goal gãy.)
    $plugins = [System.Collections.Generic.List[string]]::new()
    foreach ($p in @($cfg.plugin)) {
        if ($p -and -not $plugins.Contains($p)) { $plugins.Add($p) }
    }
    foreach ($p in $requiredPlugins) {
        if (-not $plugins.Contains($p)) { $plugins.Add($p) }
    }
    $cfg.plugin = $plugins.ToArray()

    # 2. Merge skills.paths: giữ path lạ, đảm bảo đủ path bắt buộc
    if (-not $cfg.skills) {
        $cfg | Add-Member -MemberType NoteProperty -Name "skills" -Value ([PSCustomObject]@{})
    }
    $skillPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($p in @($cfg.skills.paths)) {
        if ($p -and -not $skillPaths.Contains($p)) { $skillPaths.Add($p) }
    }
    foreach ($p in $requiredSkillPaths) {
        if (-not $skillPaths.Contains($p)) { $skillPaths.Add($p) }
    }
    $cfg.skills.paths = $skillPaths.ToArray()

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

    # 5. Đảm bảo slash command /goal tồn tại (plugin load nhưng thiếu command này thì /goal vẫn gãy)
    if (-not $cfg.command) {
        $cfg | Add-Member -MemberType NoteProperty -Name "command" -Value ([PSCustomObject]@{})
    }
    $cfg.command | Add-Member -MemberType NoteProperty -Name "goal" -Value ([PSCustomObject]@{
        description = "Set a session-scoped goal and auto-continue until complete."
        template = '$ARGUMENTS'
        agent = "build"
    }) -Force

    $newJson = $cfg | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($jsonPath, $newJson, [System.Text.Encoding]::UTF8)
    Write-Success "Đã chuẩn hóa opencode.json thành công."
} else {
    # Fresh-install nhưng ECC không tự tạo opencode.json: tạo cấu hình tối thiểu thay vì skip lặng lẽ.
    Write-Warn "Chưa có opencode.json, tạo cấu hình tối thiểu..."
    $cfg = [PSCustomObject]@{
        '$schema' = "https://opencode.ai/config.json"
        plugin = $requiredPlugins
        skills = [PSCustomObject]@{ paths = $requiredSkillPaths }
        instructions = @("AGENTS.md", "karpathy-guidelines.md")
        command = [PSCustomObject]@{
            goal = [PSCustomObject]@{
                description = "Set a session-scoped goal and auto-continue until complete."
                template = '$ARGUMENTS'
                agent = "build"
            }
        }
        mcp = [PSCustomObject]@{
            codegraph = [PSCustomObject]@{
                type = "local"
                command = @("codegraph", "serve", "--mcp")
                enabled = $true
            }
        }
    }
    [System.IO.File]::WriteAllText($jsonPath, ($cfg | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)
    Write-Success "Đã tạo mới opencode.json tối thiểu."
}

# -----------------------------------------------------------
# 9. XÁC MINH HOÀN TẤT
# -----------------------------------------------------------
Write-Step "10. Kiểm tra và xác nhận trạng thái cài đặt"

Write-Host "`n[+] Danh sách MCP Servers:" -ForegroundColor Magenta
& opencode mcp list

# Xác minh goal-plugin: khai báo plugin + slash command + agent đích phải đồng thời tồn tại
$cfgCheck = Get-Content "$configDir\opencode.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($cfgCheck.plugin) -contains "opencode-goal-plugin@0.10.0") {
    Write-Success "Plugin opencode-goal-plugin đã khai báo."
} else {
    Write-Warn "Thiếu opencode-goal-plugin trong plugin[]."
}
$goalAgent = $cfgCheck.command.goal.agent
if ($cfgCheck.command.goal -and $goalAgent -and $cfgCheck.agent.PSObject.Properties[$goalAgent]) {
    Write-Success "Slash command /goal đã sẵn sàng (agent: $goalAgent)."
} elseif ($cfgCheck.command.goal) {
    Write-Warn "Có command /goal nhưng agent '$goalAgent' không tồn tại trong agent{} — /goal sẽ gãy, cần kiểm tra lại ECC install."
} else {
    Write-Warn "Thiếu command /goal trong command{}."
}
if (Test-Path "$configDir\node_modules\opencode-goal-plugin\package.json") {
    Write-Success "Package opencode-goal-plugin đã cài trong node_modules."
} else {
    Write-Warn "Chưa thấy node_modules\opencode-goal-plugin."
}
if (Test-Path "$configDir\plugin\nineRemoteNotify.js") {
    Write-Success "Plugin 9Remote notify đã sẵn sàng."
} else {
    Write-Warn "Thiếu plugin\9Remote notify (plugin\nineRemoteNotify.js)."
}

$skillCount = (Get-ChildItem "$configDir\skills" -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host "`n[+] Tổng số kỹ năng (Skills) đã cài đặt: $skillCount" -ForegroundColor Magenta
Write-Host "    - Superpowers (TDD, Brainstorming, Subagents, v.v.)" -ForegroundColor Gray
    Write-Host "    - ECC Developer (Database, Quality, Memory, v.v.)" -ForegroundColor Gray
    Write-Host "    - Karpathy Guidelines (Surgical changes, Simplicity, v.v.)" -ForegroundColor Gray

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " HOÀN TẤT CÀI ĐẶT VÀ CẤU HÌNH OPENCODE THÀNH CÔNG!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Bạn có thể khởi động OpenCode Desktop hoặc gõ 'opencode' trong terminal để bắt đầu!`n"