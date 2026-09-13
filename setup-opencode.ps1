<#
.SYNOPSIS
    Fresh-install / cập nhật OpenCode về trạng thái chuẩn HOÀN HẢO ngay lần chạy đầu.

    Mô hình delta idempotent (giống thao tác thủ công cẩn thận, nhưng tự động):
    - Installer bên thứ 3 (ECC/CodeGraph/opencode CLI) sở hữu file của chúng
      (skills, commands, agents, hooks...) — script KHÔNG đụng tới, luôn dùng bản mới nhất.
    - Nội dung UPSTREAM (karpathy) → tải trực tiếp từ repo gốc, không snapshot.
    - File CHIA SẺ (opencode.json, package.json) → merge delta (goal plugin + /goal).
    - Plugin 9Remote do chính 9Remote tự thêm/quản lý — script không ôm vào repo
      (tránh ghi đè bản mới của nó bằng snapshot cũ).
    - Fresh hay update (-SkipUninstall) chạy chung một đường → chạy lại vẫn ra một kết quả.

    Bao gồm: OpenCode CLI (pin major v1) + OpenCode Desktop (pin theo biến $DesktopVersion
    trong script, hiện v1.18.30) + Superpowers + ECC developer (giữ hooks)
    + CodeGraph MCP + Karpathy guidelines + opencode-goal-plugin (/goal).

.PARAMETER SkipUninstall
    Chế độ update: bỏ qua gỡ/wipe, merge config thay vì ghi đè.
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
# 0. KIỂM TRA & CÀI ĐẶT MÔI TRƯỜNG YÊU CẦU
# -----------------------------------------------------------
Write-Step "1. Kiểm tra & cài đặt môi trường (Node.js, npm, git)"

# Thư mục cache tool portable (sống sót qua wipe để lần sau khỏi tải lại).
$ToolsDir = "$env:LOCALAPPDATA\opencode-install\tools"

function Reset-SessionPath {
    # winget cài xong nhưng shell hiện tại chưa thấy lệnh mới → nạp lại PATH từ registry.
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH = "$machinePath;$userPath"
}

function Add-ToolPath {
    param([string]$Dir)
    # Dùng ngay trong session hiện tại + lưu persistent (user scope, không cần admin).
    if (($env:PATH -split ";") -notcontains $Dir) { $env:PATH = "$Dir;$env:PATH" }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ((($userPath -split ";") -notcontains $Dir)) {
        [Environment]::SetEnvironmentVariable("Path", "$Dir;$userPath", "User")
    }
}

function Install-PortablePrereq {
    # Fallback khi không có winget / winget gãy: tải bản portable CHÍNH CHỦ,
    # không cần admin. Lỗi ở đâu dừng loud ở đó, không bao giờ cài dở dang.
    param([ValidateSet("node", "git")][string]$Kind)
    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-Error "Bootstrap portable chỉ hỗ trợ Windows 64-bit."
        exit 1
    }
    if (-not (Test-Path $ToolsDir)) {
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("opencode-dl-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        if ($Kind -eq "node") {
            Write-Info "Hỏi nodejs.org bản LTS mới nhất..."
            $index = Invoke-WebRequest -Uri "https://nodejs.org/dist/index.json" -UseBasicParsing | ConvertFrom-Json
            $lts = @($index | Where-Object { $_.lts })[0]
            if (-not $lts) {
                Write-Error "Không đọc được danh sách LTS từ nodejs.org."
                exit 1
            }
            $ver = $lts.version  # dạng "v24.x.x"
            $zipPath = Join-Path $tmp "node.zip"
            Write-Info "Tải Node $ver portable (~30MB)..."
            Invoke-WebRequest -Uri "https://nodejs.org/dist/$ver/node-$ver-win-x64.zip" -OutFile $zipPath -UseBasicParsing
            Get-ChildItem (Join-Path $ToolsDir "node-v*") -Directory -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Info "Giải nén Node portable..."
            Expand-Archive -Path $zipPath -DestinationPath $ToolsDir -Force
            Add-ToolPath (Join-Path $ToolsDir "node-$ver-win-x64")
        } else {
            Write-Info "Hỏi GitHub API release mới nhất của git-for-windows..."
            $rel = Invoke-WebRequest -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" -UseBasicParsing -Headers @{ "User-Agent" = "opencode-install" } | ConvertFrom-Json
            $asset = @($rel.assets | Where-Object { $_.name -like "PortableGit-*-64-bit.7z.exe" })[0]
            if (-not $asset) {
                Write-Error "Không tìm thấy asset PortableGit trong release mới nhất."
                exit 1
            }
            $sfxPath = Join-Path $tmp "portablegit.exe"
            Write-Info "Tải $($asset.name) (~60MB)..."
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $sfxPath -UseBasicParsing
            $dest = Join-Path $ToolsDir "PortableGit"
            if (Test-Path $dest) {
                Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Write-Info "Giải nén Git portable (silent)..."
            # SFX của PortableGit là GUI-subsystem: toán tử & không chờ nó xong
            # (trả về ngay, thuốc giải nén chưa chạy) → bắt buộc Start-Process -Wait.
            $sfxProc = Start-Process -FilePath $sfxPath -ArgumentList "-y", "-o$dest" -Wait -PassThru
            if ($sfxProc.ExitCode -ne 0) {
                Write-Error "Giải nén PortableGit thất bại (exit $($sfxProc.ExitCode))."
                exit 1
            }
            Add-ToolPath (Join-Path $dest "cmd")
        }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-Tool {
    param(
        [string]$Command,
        [string]$DisplayName,
        [string]$WingetId,
        [string]$ManualUrl,
        [ValidateSet("node", "git")][string]$PortableKind
    )
    if (Get-Command $Command -ErrorAction SilentlyContinue) { return }
    # Tầng 1: winget (nhanh, có thể hỏi UAC).
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Cài $DisplayName qua winget (có thể hiện UAC xin quyền admin)..."
        & winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
        Reset-SessionPath
    } else {
        Write-Warn "Không có winget, bỏ qua tầng winget."
    }
    # Tầng 2: bootstrap portable chính chủ trong repo (không cần admin).
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Warn "winget thất bại/không có → fallback portable..."
        Install-PortablePrereq -Kind $PortableKind
        Reset-SessionPath
    }
    # Tầng 3: chịu thua → báo link tay, dừng loud.
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Error "Không cài được $DisplayName. Đóng mở lại terminal rồi chạy lại script, hoặc cài tay tại: $ManualUrl"
        exit 1
    }
    Write-Success "$DisplayName đã sẵn sàng."
}

Ensure-Tool -Command "node" -DisplayName "Node.js LTS (kèm npm)" -WingetId "OpenJS.NodeJS.LTS" -ManualUrl "https://nodejs.org/" -PortableKind "node"
Ensure-Tool -Command "git" -DisplayName "Git" -WingetId "Git.Git" -ManualUrl "https://git-scm.com/download/win" -PortableKind "git"

$nodeVer = & node --version
$npmVer = & npm --version
$gitVer = & git --version
Write-Success "Node.js: $nodeVer | npm: $npmVer | Git: $gitVer"

# -----------------------------------------------------------
# 1. GỠ BỎ SẠCH SẼ OPENCODE CŨ (fresh install only)
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

    # Xóa cache gói goal-plugin cũ: theo README chính thức, cache stale khiến bản bug cũ
    # vẫn chạy mãi dù đã bump pin. Chỉ xóa goal-plugin*, không đụng cache khác.
    Write-Info "Xóa package cache cũ của opencode-goal-plugin (tránh chạy bản stale)..."
    Get-ChildItem "$env:USERPROFILE\.cache\opencode\packages" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "opencode-goal-plugin*" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "Đã gỡ bỏ sạch sẽ toàn bộ OpenCode cũ."
} else {
    Write-Step "2. Chế độ update (-SkipUninstall): giữ nguyên dữ liệu, merge config"
}

# -----------------------------------------------------------
# 2. CÀI ĐẶT MỚI OPENCODE CLI & CÁC CÔNG CỤ CƠ SỞ
# -----------------------------------------------------------
Write-Step "3. Cài đặt mới OpenCode CLI và các công cụ bổ trợ"

Write-Info "Cài đặt opencode-ai toàn cục qua npm (pin major v1: opencode-goal-plugin chỉ hỗ trợ opencode >=1.17.15 <2)..."
# npm >= 11.6 yêu cầu allow-list cho install scripts; npm cũ (Node 20/22 LTS) không hiểu
# flag này → thử có flag trước, gãy thì cài kiểu cũ (vẫn chạy scripts + cảnh báo).
& npm install -g --allow-scripts=opencode-ai opencode-ai@1
if ($LASTEXITCODE -ne 0) {
    Write-Warn "npm không hỗ trợ --allow-scripts, cài lại kiểu tương thích..."
    & npm install -g opencode-ai@1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cài opencode-ai thất bại. Kiểm tra mạng và npm."
        exit 1
    }
}

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
# 3. CÀI ĐẶT CODEGRAPH MCP (đẻ artifacts: AGENTS.md, MCP wiring)
# -----------------------------------------------------------
Write-Step "4. Cài đặt và cấu hình CodeGraph MCP (colbymchenry/codegraph)"

& codegraph install --target opencode --location global --yes
Write-Success "CodeGraph MCP đã được cấu hình cho OpenCode."

# -----------------------------------------------------------
# 4. CÀI ĐẶT ECC (đẻ artifacts: skills/, commands/, plugins/ecc-hooks.ts)
# -----------------------------------------------------------
Write-Step "5. Cài đặt ECC - Everything Claude Code (affaan-m/ECC)"

# Giữ hook runtime của ECC (plugins/ecc-hooks.ts): setup chuẩn có file này.
& ecc install --profile developer --target opencode --enable-hooks
Write-Success "ECC Developer Profile (kèm hooks) đã được cài đặt vào OpenCode."

# -----------------------------------------------------------
# 5. ĐĂNG KÝ SUPERPOWERS VỚI OPENCODE
# -----------------------------------------------------------
Write-Step "6. Đăng ký Superpowers (obra/superpowers) với OpenCode"

# Chạy TRƯỚC khi ghi config chuẩn: CLI có thể tự tạo/sửa opencode.json,
# bản canonical ở bước 7 sẽ ghi đè nên kết quả cuối luôn deterministic.
& opencode plugin superpowers@git+https://github.com/obra/superpowers.git -g
Write-Success "Superpowers đã được đăng ký (node_modules + skills sync ở bước 7)."

# -----------------------------------------------------------
# 6. CÀI OPENCODE DESKTOP (bản win per-user từ GitHub releases, không cần admin)
# -----------------------------------------------------------
Write-Step "7. Cài đặt OpenCode Desktop"

# Pin Desktop theo CLI major v1 — bump tay theo https://github.com/anomalyco/opencode/releases
$DesktopVersion = "v1.18.30"
$desktopExe = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"
$desktopArch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
$needDesktop = $true
if ((Test-Path $desktopExe) -and $SkipUninstall) {
    $installedDeskVer = (Get-Item $desktopExe).VersionInfo.FileVersion
    if ($installedDeskVer.Split('.')[0] -eq $DesktopVersion.TrimStart('v').Split('.')[0]) {
        Write-Info "OpenCode Desktop $installedDeskVer đã có sẵn, bỏ qua tải lại."
        $needDesktop = $false
    } else {
        Write-Warn "Desktop $installedDeskVer lệch major với pin $DesktopVersion → cài lại cho đồng bộ CLI."
    }
}
if ($needDesktop) {
    $desktopUrl = "https://github.com/anomalyco/opencode/releases/download/$DesktopVersion/opencode-desktop-win-$desktopArch.exe"
    $desktopInstaller = Join-Path ([IO.Path]::GetTempPath()) "opencode-desktop-setup.exe"
    Write-Info "Tải OpenCode Desktop $DesktopVersion ($desktopArch, ~120MB)..."
    Invoke-WebRequest -Uri $desktopUrl -OutFile $desktopInstaller -UseBasicParsing
    Write-Info "Cài silent (per-user, không cần admin)..."
    $deskProc = Start-Process -FilePath $desktopInstaller -ArgumentList "/S" -Wait -PassThru
    Remove-Item $desktopInstaller -Force -ErrorAction SilentlyContinue
    if ($deskProc.ExitCode -ne 0) {
        Write-Error "Cài OpenCode Desktop thất bại (exit $($deskProc.ExitCode))."
        exit 1
    }
    if (-not (Test-Path $desktopExe)) {
        Write-Error "Cài xong nhưng không thấy OpenCode.exe tại $desktopExe."
        exit 1
    }
    Write-Success "OpenCode Desktop đã sẵn sàng: phiên bản $((Get-Item $desktopExe).VersionInfo.FileVersion)"
}

# -----------------------------------------------------------
# 7. ÁP DELTA CẤU HÌNH CHUẨN (idempotent — chạy lại vẫn ra một kết quả)
#    Quy tắc ownership:
#    - Nội dung UPSTREAM (karpathy) → tải trực tiếp từ repo gốc, không snapshot.
#    - File CHIA SẺ (installer cũng ghi: opencode.json, package.json) → merge delta goal.
#    - File CỦA INSTALLER/ỨNG DỤNG KHÁC (skills/, commands/, agents, hooks,
#      plugin 9Remote...) → không đụng tới, luôn dùng bản mới nhất
#      (tránh snapshot thối rữa hoặc ghi đè bản mới của tool khác).
# -----------------------------------------------------------
Write-Step "8. Áp delta cấu hình chuẩn vào $configDir"

$requiredPlugins = @(
    "./plugins",
    "superpowers@git+https://github.com/obra/superpowers.git",
    "opencode-goal-plugin@0.10.0"
)
$requiredSkillPaths = @("./skills", "~/.config/opencode/skills")

# ---- 7a. Karpathy: tải trực tiếp từ upstream theo README chính thức của họ,
# không ôm snapshot trong repo → luôn dùng bản mới nhất, đúng markdown fences.
$karpathyUrl = "https://raw.githubusercontent.com/multica-ai/andrej-karpathy-skills/main/skills/karpathy-guidelines/SKILL.md"
Invoke-WebRequest -Uri $karpathyUrl -OutFile "$configDir\karpathy-guidelines.md" -UseBasicParsing
Write-Success "Đã tải karpathy-guidelines từ upstream."

# ---- 7b. package.json (chia sẻ với installer) → merge dep goal, giữ deps của ECC ----
if (-not (Test-Path "$configDir\package.json")) {
    '{ "dependencies": {} }' | Set-Content "$configDir\package.json" -Encoding UTF8
}
$pkg = Get-Content "$configDir\package.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $pkg.dependencies) {
    $pkg | Add-Member -MemberType NoteProperty -Name "dependencies" -Value ([PSCustomObject]@{})
}
$pkg.dependencies | Add-Member -MemberType NoteProperty -Name "opencode-goal-plugin" -Value "0.10.0" -Force
[System.IO.File]::WriteAllText("$configDir\package.json", ($pkg | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)
Write-Success "Đã merge package.json (giữ deps của installer, thêm goal-plugin)."

# ---- 7c. opencode.json (chia sẻ với installer) → merge delta, giữ agents/commands mới nhất ----
if (-not (Test-Path "$configDir\opencode.json")) {
    Write-Warn "Chưa có opencode.json, tạo khung rỗng rồi merge delta..."
    '{ }' | Set-Content "$configDir\opencode.json" -Encoding UTF8
}
$cfg = Get-Content "$configDir\opencode.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# 1. Merge plugin array: giữ entry lạ, đảm bảo đủ 3 entry bắt buộc.
$plugins = [System.Collections.Generic.List[string]]::new()
foreach ($p in @($cfg.plugin)) {
    if ($p -and -not $plugins.Contains($p)) { $plugins.Add($p) }
}
foreach ($p in $requiredPlugins) {
    if (-not $plugins.Contains($p)) { $plugins.Add($p) }
}
# Add-Member -Force (thay vì gán trực tiếp): object từ ConvertFrom-Json không cho
# gán property chưa tồn tại — gán trực tiếp sẽ throw khi file gốc thiếu key này.
$cfg | Add-Member -MemberType NoteProperty -Name "plugin" -Value $plugins.ToArray() -Force

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
    $cfg.skills | Add-Member -MemberType NoteProperty -Name "paths" -Value $skillPaths.ToArray() -Force

# 3. Đảm bảo instructions có cả AGENTS.md và karpathy-guidelines.md
$instList = [System.Collections.Generic.List[string]]::new()
if ($cfg.instructions) {
    foreach ($item in $cfg.instructions) {
        if (-not $instList.Contains($item)) { $instList.Add($item) }
    }
}
    if (-not $instList.Contains("AGENTS.md")) { $instList.Insert(0, "AGENTS.md") }
    if (-not $instList.Contains("karpathy-guidelines.md")) { $instList.Insert(1, "karpathy-guidelines.md") }
    $cfg | Add-Member -MemberType NoteProperty -Name "instructions" -Value $instList.ToArray() -Force

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

[System.IO.File]::WriteAllText("$configDir\opencode.json", ($cfg | ConvertTo-Json -Depth 20), [System.Text.Encoding]::UTF8)
Write-Success "Đã merge opencode.json (giữ agents/commands của installer, thêm delta goal)."

# Cài dependencies khai báo trong package.json (gồm opencode-goal-plugin + superpowers).
Push-Location $configDir
try {
    & npm install --silent
    Write-Success "Dependencies của config đã cài xong."
} finally {
    Pop-Location
}

# Đồng bộ skills Superpowers còn thiếu (CHỈ copy skill chưa tồn tại để không ghi đè ECC/custom).
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

# Skill karpathy-guidelines từ file chuẩn (nội dung đã fix đúng markdown fences).
$karpathySkillDir = "$configDir\skills\karpathy-guidelines"
if (-not (Test-Path $karpathySkillDir)) {
    New-Item -ItemType Directory -Path $karpathySkillDir -Force | Out-Null
}
Copy-Item "$configDir\karpathy-guidelines.md" "$karpathySkillDir\SKILL.md" -Force
Write-Success "Skill karpathy-guidelines đã đồng bộ."

# -----------------------------------------------------------
# 8. XÁC MINH HOÀN TẤT (fail loudly nếu thiếu mảnh ghép nào)
# -----------------------------------------------------------
Write-Step "9. Kiểm tra và xác nhận trạng thái cài đặt"

Write-Host "`n[+] Danh sách MCP Servers:" -ForegroundColor Magenta
& opencode mcp list

$failures = @()

# Xác minh goal-plugin: khai báo plugin + slash command + agent đích phải đồng thời tồn tại
$cfgCheck = Get-Content "$configDir\opencode.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($cfgCheck.plugin) -contains "opencode-goal-plugin@0.10.0") {
    Write-Success "Plugin opencode-goal-plugin đã khai báo."
} else {
    Write-Warn "Thiếu opencode-goal-plugin trong plugin[]."
    $failures += "plugin[] thiếu opencode-goal-plugin"
}
$goalAgent = $cfgCheck.command.goal.agent
if ($cfgCheck.command.goal -and $goalAgent -and $cfgCheck.agent.PSObject.Properties[$goalAgent]) {
    Write-Success "Slash command /goal đã sẵn sàng (agent: $goalAgent)."
} elseif ($cfgCheck.command.goal) {
    Write-Warn "Có command /goal nhưng agent '$goalAgent' không tồn tại trong agent{}."
    $failures += "command /goal trỏ agent '$goalAgent' không tồn tại"
} else {
    Write-Warn "Thiếu command /goal trong command{}."
    $failures += "thiếu command /goal"
}
if (Test-Path "$configDir\node_modules\opencode-goal-plugin\package.json") {
    Write-Success "Package opencode-goal-plugin đã cài trong node_modules."
} else {
    Write-Warn "Chưa thấy node_modules\opencode-goal-plugin."
    $failures += "node_modules thiếu opencode-goal-plugin"
}

# Verify chính chủ của plugin author (8 checks: hooks, /goal status/set, cache không cũ,
# không gọi model). Đây là kiểm chứng mạnh nhất, hơn mọi check file tồn tại ở trên.
if (Test-Path "$configDir\node_modules\opencode-goal-plugin\scripts\verify.mjs") {
    Write-Info "Chạy bộ verify chính chủ của opencode-goal-plugin..."
    $goalVerifyOut = & node "$configDir\node_modules\opencode-goal-plugin\scripts\verify.mjs" 2>&1 | Out-String
    Write-Info $goalVerifyOut.Trim()
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Verify chính chủ opencode-goal-plugin: PASS."
    } else {
        Write-Warn "Verify chính chủ opencode-goal-plugin: FAIL (exit $LASTEXITCODE)."
        $failures += "verify chính chủ opencode-goal-plugin FAIL"
    }
} else {
    Write-Warn "Thiếu script verify của opencode-goal-plugin."
    $failures += "thiếu script verify của opencode-goal-plugin"
}

# Đối chiếu cuối: resolved config thực tế opencode load phải chứa đủ các plugin.
try {
    $resolved = & opencode debug config 2>&1 | Out-String
    if ($resolved -match "opencode-goal-plugin" -and $resolved -match "ecc-hooks") {
        Write-Success "Resolved config chứa đủ goal-plugin và ECC hooks."
    } else {
        Write-Warn "Resolved config thiếu mảnh ghép — khởi động lại opencode rồi chạy 'opencode debug config' để đối chiếu."
        $failures += "resolved config thiếu plugin"
    }
} catch {
    Write-Warn "Không chạy được 'opencode debug config' để đối chiếu: $_"
}

$desktopExeCheck = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"
if (Test-Path $desktopExeCheck) {
    $deskFileVer = (Get-Item $desktopExeCheck).VersionInfo.FileVersion
    Write-Success "OpenCode Desktop đã cài: phiên bản $deskFileVer"
    if ($deskFileVer.Split('.')[0] -ne $DesktopVersion.TrimStart('v').Split('.')[0]) {
        Write-Warn "Desktop ($deskFileVer) lệch major với pin ($DesktopVersion) — /goal có thể gãy trên Desktop."
    }
} else {
    Write-Warn "Thiếu OpenCode Desktop."
    $failures += "thiếu OpenCode Desktop"
}

# Minh bạch cache portable: phải giữ vì ecc CLI cần node runtime (xóa là ecc chết
# trên máy không có system node). Chỉ báo dormant để user tự dọn, không tự xóa.
if (Test-Path $ToolsDir) {
    $toolsMB = [math]::Round(((Get-ChildItem $ToolsDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB), 1)
    $toolsInUse = @("node", "git") | Where-Object {
        (Get-Command $_ -ErrorAction SilentlyContinue).Source -like "$ToolsDir*"
    }
    if (@($toolsInUse).Count -eq 0) {
        Write-Info "Cache portable ($toolsMB MB) đang dormant (đã có system node/git) — xóa tay nếu muốn: Remove-Item '$ToolsDir' -Recurse -Force"
    } else {
        Write-Info "Cache portable ($toolsMB MB) đang dùng ($($toolsInUse -join ', ')) — giữ lại để chạy."
    }
}

$skillCount = (Get-ChildItem "$configDir\skills" -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host "`n[+] Tổng số kỹ năng (Skills) đã cài đặt: $skillCount" -ForegroundColor Magenta
Write-Host "    - Superpowers (TDD, Brainstorming, Subagents, v.v.)" -ForegroundColor Gray
Write-Host "    - ECC Developer (Database, Quality, Memory, v.v.)" -ForegroundColor Gray
Write-Host "    - Karpathy Guidelines (Surgical changes, Simplicity, v.v.)" -ForegroundColor Gray

if ($SkipUninstall) {
    Write-Host "`n[!] Khởi động lại OpenCode để nhận config mới (theo README chính thức của goal-plugin)." -ForegroundColor Yellow
}

if ($failures.Count -gt 0) {
    Write-Host "`n========================================================" -ForegroundColor Red
    Write-Host " CÀI ĐẶT CHƯA HOÀN HẢO — còn $($failures.Count) vấn đề:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    Write-Host "========================================================" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " HOÀN TẤT CÀI ĐẶT VÀ CẤU HÌNH OPENCODE THÀNH CÔNG!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Bạn có thể khởi động OpenCode Desktop hoặc gõ 'opencode' trong terminal để bắt đầu!`n"
