# OpenCode Full Suite Installer

Script cài mới / cập nhật OpenCode về trạng thái chuẩn, chạy lại lần nào cũng ra
đúng một kết quả — không cần vá tay sau cài đặt.

## Cài những gì

| Thành phần | Nguồn | Cách cài |
|---|---|---|
| [OpenCode CLI](https://opencode.ai) (**pin major v1**) | npm `opencode-ai@1` | Cài global. Pin v1 vì `opencode-goal-plugin` chỉ hỗ trợ opencode `<2` |
| [Superpowers](https://github.com/obra/superpowers) (`obra/superpowers`) | `opencode plugin ... -g` + npm | Đăng ký plugin, skills chỉ copy mục mới (không ghi đè) |
| [ECC](https://github.com/affaan-m/ECC) Developer profile | `ecc install --profile developer --target opencode --enable-hooks` | Kèm hook runtime (`plugins/ecc-hooks.ts`) |
| [CodeGraph MCP](https://github.com/colbymchenry/codegraph) | CLI standalone (nếu có) hoặc npm, rồi `codegraph install --target opencode --location global` | Ưu tiên bản standalone để tránh trùng 2 bản |
| Karpathy guidelines | Tải trực tiếp từ upstream [`multica-ai/andrej-karpathy-skills`](https://github.com/multica-ai/andrej-karpathy-skills) | Không snapshot, luôn dùng bản mới nhất |
| [opencode-goal-plugin](https://github.com/willytop8/OpenCode-goal-plugin) + `/goal` | npm `opencode-goal-plugin@0.10.0` + merge config | Kèm slash command `/goal` (plugin load nhưng thiếu command này thì `/goal` vẫn gãy) |

## Nguyên tắc thiết kế (mô hình delta)

- **Của installer thì không đụng**: skills, commands, agents, hooks... luôn dùng bản
  mới nhất installer vừa đẻ. Repo không ôm snapshot để tránh thối rữa theo thời gian.
- **Nội dung upstream thì tải trực tiếp**: karpathy lấy từ repo gốc mỗi lần cài.
- **Phần của mình thì merge delta**: `opencode.json` / `package.json` chỉ thêm thiếu
  (goal plugin, `command.goal`, skill paths, MCP codegraph...), giữ nguyên phần của installer.
- **Idempotent**: fresh và update (`-SkipUninstall`) chạy chung một đường merge,
  chạy lại vẫn ra một kết quả.
- **Fail loudly**: thiếu mảnh ghép nào là exit 1 kèm danh sách đỏ, không báo thành công giả.

## Cách sử dụng

### 1. Nhấp đúp chuột (khuyến nghị)

Nhấp đúp `setup-opencode.bat` để fresh-install toàn bộ.

### 2. Chạy bằng PowerShell

```powershell
# Fresh-install: gỡ sạch mọi dấu vết opencode rồi cài lại từ đầu
.\setup-opencode.ps1

# Update: giữ nguyên dữ liệu, chỉ cài lại tools + merge delta config
.\setup-opencode.ps1 -SkipUninstall
```

### Yêu cầu (máy trắng cần có trước)

- Windows + PowerShell 5.1 trở lên (script không dùng cú pháp PS7-only).
- **Có mạng** (mọi bước cài đều tải từ internet).
- Node.js LTS + Git: nếu thiếu, script tự cài theo 3 tầng — winget (có thể hiện
  UAC) → portable chính chủ tải về `%LOCALAPPDATA%\opencode-install\tools`
  (không cần admin, sống sót qua wipe để lần sau khỏi tải lại) → báo link cài tay.
  Tay: https://nodejs.org/ và https://git-scm.com/download/win.
- Chạy trực tiếp file `.ps1` thì thêm `-ExecutionPolicy Bypass` (file `.bat` đã làm sẵn).

## Fresh-install làm gì, theo thứ tự

1. Dừng processes opencode, gỡ OpenCode Desktop + package npm, xóa 7 thư mục
   dữ liệu/cấu hình/cache (`~/.config/opencode`, `%APPDATA%`, `%LOCALAPPDATA%`...).
2. Cài binaries: `opencode-ai@1`, `ecc-universal`, CodeGraph (nếu chưa có).
3. Chạy installer bên thứ 3 để chúng đẻ artifacts: CodeGraph MCP wiring,
   ECC skills/commands/hooks, đăng ký Superpowers.
4. Áp delta: tải karpathy, merge `package.json` + `opencode.json`,
   `npm install`, sync skills mới, copy skill karpathy.
5. Verify: `opencode mcp list`, check plugin/`/goal`/agent đích/node_modules,
   đối chiếu `opencode debug config` thực tế. Lỗi → exit 1.

## Ghi chú

- `/goal` cần đồng thời 3 thứ: entry trong `plugin[]`, dep trong `package.json`,
  và block `command.goal` trong config — thiếu 1 là gãy. Step verify check cả 3
  rồi chạy tiếp **bộ verify 8-check chính chủ** của plugin (`scripts/verify.mjs`).
- Fresh-install xóa cả package cache cũ của goal-plugin (`~/.cache/opencode/packages`),
  vì theo README chính thức cache stale khiến bản bug cũ chạy mãi dù đã bump pin.
- Khi goal-plugin hỗ trợ opencode v2 (hoặc bỏ goal-plugin), đổi `opencode-ai@1`
  thành `opencode-ai@latest` trong script.
- Xem lịch sử thay đổi trong [CHANGELOG.md](CHANGELOG.md).
