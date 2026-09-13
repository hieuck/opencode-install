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
- Fallback Windows cho superpowers: warm `opencode debug config` rồi check package
  cache, chỉ dùng npm local + entry local path khi git-spec fetch thất bại
  (đúng mục Windows install issues trong README chính thức).
- Verify cảnh báo clones superpowers cũ trong skills/ cá nhân (shadow bản plugin)
  và check superpowers trong resolved config; fresh xóa package cache superpowers
  để luôn lấy main mới nhất.
- Kiểm tra môi trường (Node.js, npm, git) fail-fast ngay đầu script.
- Cài CodeGraph có điều kiện: dùng bản standalone nếu có, tránh trùng bản npm.

### Changed

- Cài superpowers theo cách chính thức tối thiểu (chỉ entry plugin[] trong config,
  opencode tự fetch + đăng ký skills) thay vì npm install + copy skills.
- Mô hình delta idempotent: installer bên thứ 3 sở hữu file của chúng, script chỉ
  merge delta (goal plugin + `/goal`); fresh và update chung một đường.
- ECC cài kèm hook runtime (`--enable-hooks`) cho khớp setup chuẩn.
- Karpathy guidelines tải trực tiếp từ upstream, không snapshot trong repo.
- Pin `opencode-ai@1` (goal-plugin chỉ hỗ trợ opencode `<2`).

### Removed

- Sync skills Superpowers vào skills/ cá nhân + npm install superpowers vô điều kiện
  (gây shadow: personal > plugin theo thứ tự ưu tiên chính thức; npm local chỉ còn
  là fallback khi git-spec fetch thất bại).
- Bỏ thư mục `config/` snapshot (`opencode.json`, `package.json`, `AGENTS.md`,
  karpathy): tránh thối rữa khi upstream update agents/commands/MCP fields.
- Bỏ quản lý plugin 9Remote trong script (9Remote tự thêm/quản lý; ôm snapshot cũ
  sẽ ghi đè bản mới của nó).
- Bỏ ghi đè `plugin[]` — nguyên nhân `/goal` gãy mỗi lần chạy installer cũ.

### Fixed

- Desktop installer rò file temp khi throw giữa chừng → bọc `try/finally` + tên file
  GUID chống collide khi chạy đồng thời.
- Crash khi `VersionInfo.FileVersion` null/rỗng (`.Split` trên null) ở check Desktop
  và verify drift → helper `Get-VersionMajor` null-safe (unknown = cài lại/cảnh báo).
- Máy 32-bit tải nhầm asset Desktop x64 → fail-fast đầu step (giống bootstrap portable).
- Prune instructions thu hẹp thành allowlist 7 refs chết đã biết (không prune mọi ref
  missing) + verify check AGENTS.md/karpathy tồn tại — tôn trọng custom của user.
- Fallback npm superpowers không check exit code (đổi entry dù cài gãy) → check
  `$LASTEXITCODE` + xác nhận package tồn tại trước khi swap entry.
- Dual-entry superpowers (git-spec + local-path cùng tồn tại qua các lần chạy) →
  merge chuẩn hóa còn 1 entry theo cache-hit.
- Resolved-config check yêu cầu `debug config` exit 0 trước khi match chuỗi
  (tránh false pass trên output lỗi).

- Merge prune instruction refs trỏ file không tồn tại (6 skills thuộc module ngoài
  profile `developer`/`framework-language` bị skip ở target opencode +
  `CONTRIBUTING.md`), có liệt kê trong output — trước đây opencode warning mỗi lần
  khởi động vì chúng.

- npm cũ (Node 20/22 LTS) không hiểu flag `--allow-scripts` làm gãy bước cài
  opencode-ai → tự fallback cài kiểu tương thích, gãy tiếp mới exit 1.

- `/goal` không hiện: thêm block `command.goal` vào config (plugin đã load nhưng
  thiếu slash command).
- `opencode-goal-plugin` thiếu trong `package.json` dependencies → merge dep + `npm install`.
- Markdown fences của karpathy (```` ``` ````) bị PowerShell nuốt thành `` ` `` khi ghi
  file qua here-string `@" "@` → dùng file tải trực tiếp, không qua string processing.
- Gán property lên object từ `ConvertFrom-Json` khi key chưa tồn tại sẽ throw →
  dùng `Add-Member -Force` ở các điểm merge.
