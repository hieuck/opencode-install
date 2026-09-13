# OpenCode Full Suite Installer

Fresh-install deterministic: wipe sạch → cài binaries → chạy installer bên thứ 3
(ECC/CodeGraph đẻ skills, hooks, commands) → áp delta của mình (merge, idempotent).
Chạy lại lần nào cũng ra đúng một trạng thái — hoàn hảo ngay lần đầu, không cần vá tay.

- **OpenCode CLI**: AI coding agent (pin major v1 để tương thích goal-plugin)
- **Superpowers (`obra/superpowers`)**: Framework phát triển phần mềm chuẩn mực (TDD, Brainstorming, Subagents, Worktrees)
- **ECC (`affaan-m/ECC`)**: Profile Developer (Database patterns, Quality workflows, Unified memory) — giữ hook runtime
- **CodeGraph (`colbymchenry/codegraph`)**: MCP code intelligence & semantic graph
- **Andrej Karpathy Guidelines**: tải trực tiếp từ upstream (`multica-ai/andrej-karpathy-skills`, theo README chính thức của họ) — không snapshot, luôn dùng bản mới nhất
- **opencode-goal-plugin**: Session-scoped goal workflow kèm slash command `/goal`
- Plugin 9Remote do chính 9Remote tự thêm/quản lý — script không can thiệp

## Source of truth (mô hình delta)

Repo này không ôm snapshot config. Quy tắc ownership:

- Installer bên thứ 3 (ECC/CodeGraph/opencode CLI) sở hữu file của chúng
  (skills, commands, agents, hooks...) — script không đụng tới, luôn dùng bản mới nhất.
- Nội dung upstream (karpathy) → tải trực tiếp từ repo gốc, không snapshot.
- File chia sẻ (`opencode.json`, `package.json`) → script **merge delta**
  (goal plugin + slash command `/goal`), giữ nguyên agents/commands mới nhất của installer.
- Plugin 9Remote do chính 9Remote tự thêm/quản lý.

## Cách sử dụng

### 1. Nhấp đúp chuột (Khuyến nghị)
Nhấp đúp chuột vào file `setup-opencode.bat` để chạy cài đặt tự động.

### 2. Chạy bằng PowerShell
```powershell
# Gỡ sạch và cài đặt mới toàn bộ:
.\setup-opencode.ps1

# Chỉ cập nhật/cấu hình lại mà không gỡ OpenCode:
.\setup-opencode.ps1 -SkipUninstall
```