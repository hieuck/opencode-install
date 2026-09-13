# Changelog

Định dạng theo [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Ngày theo lịch sử commit của repo.

## [Unreleased]

### Added

- Cài OpenCode Desktop vào script (asset `opencode-desktop-win-{x64,arm64}.exe` từ
  GitHub releases, pin `v1.18.30`, silent `/S` per-user, tự chọn arch, bỏ qua tải
  lại nếu đã có cùng major, tự cài lại nếu lệch major). Verify check exe + version
  và cảnh báo khi Desktop lệch major với CLI (Desktop tự update có thể drift).

- Step 1 tự cài Node.js LTS / Git còn thiếu qua winget (kèm UAC nếu cần),
  nạp lại PATH và verify; không có winget thì báo link cài tay rồi dừng.
- Fallback portable khi không có winget (hoặc winget gãy): tải Node LTS portable
  từ nodejs.org + PortableGit từ git-for-windows (SFX giải nén bằng
  `Start-Process -Wait` vì `&` không chờ tiến trình GUI), không cần admin,
  cache ở `%LOCALAPPDATA%\opencode-install\tools` để lần sau khỏi tải lại.
- Verify báo dung lượng + trạng thái dùng/dormant của cache portable
  (giữ là cố ý vì ecc CLI cần node runtime; dormant thì user tự xóa tay).
- Step verify fail loudly: thiếu mảnh ghép nào (plugin, `/goal`, agent đích,
  `node_modules`) là exit 1 kèm danh sách đỏ, thay vì báo thành công giả.
- Đối chiếu `opencode debug config` cuối cài đặt để xác nhận plugin thực tế được load.
- Chạy bộ verify 8-check chính chủ của goal-plugin (`scripts/verify.mjs`) trong step verify.
- Fresh-install xóa package cache cũ của goal-plugin (tránh chạy bản stale theo
  khuyến cáo upgrading của README chính thức).
- Nhắc khởi động lại OpenCode cuối cài đặt (bắt buộc sau `-SkipUninstall`).
- Kiểm tra môi trường (Node.js, npm, git) fail-fast ngay đầu script.
- Cài CodeGraph có điều kiện: dùng bản standalone nếu có, tránh trùng bản npm.

### Changed

- Mô hình delta idempotent: installer bên thứ 3 sở hữu file của chúng, script chỉ
  merge delta (goal plugin + `/goal`); fresh và update chung một đường.
- ECC cài kèm hook runtime (`--enable-hooks`) cho khớp setup chuẩn.
- Karpathy guidelines tải trực tiếp từ upstream, không snapshot trong repo.
- Sync skills Superpowers chỉ copy skill mới, không ghi đè skill đã có.
- Pin `opencode-ai@1` (goal-plugin chỉ hỗ trợ opencode `<2`).

### Removed

- Bỏ thư mục `config/` snapshot (`opencode.json`, `package.json`, `AGENTS.md`,
  karpathy): tránh thối rữa khi upstream update agents/commands/MCP fields.
- Bỏ quản lý plugin 9Remote trong script (9Remote tự thêm/quản lý; ôm snapshot cũ
  sẽ ghi đè bản mới của nó).
- Bỏ ghi đè `plugin[]` — nguyên nhân `/goal` gãy mỗi lần chạy installer cũ.

### Fixed

- npm cũ (Node 20/22 LTS) không hiểu flag `--allow-scripts` làm gãy bước cài
  opencode-ai → tự fallback cài kiểu tương thích, gãy tiếp mới exit 1.

- `/goal` không hiện: thêm block `command.goal` vào config (plugin đã load nhưng
  thiếu slash command).
- `opencode-goal-plugin` thiếu trong `package.json` dependencies → merge dep + `npm install`.
- Markdown fences của karpathy (```` ``` ````) bị PowerShell nuốt thành `` ` `` khi ghi
  file qua here-string `@" "@` → dùng file tải trực tiếp, không qua string processing.
- Gán property lên object từ `ConvertFrom-Json` khi key chưa tồn tại sẽ throw →
  dùng `Add-Member -Force` ở các điểm merge.
