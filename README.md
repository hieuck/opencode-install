# OpenCode Full Suite Installer

Bộ kịch bản tự động hóa gỡ sạch, cài đặt mới OpenCode và tích hợp toàn bộ các plugin & MCP mạnh mẽ:
- **OpenCode CLI**: AI coding agent (pin major v1 để tương thích goal-plugin)
- **Superpowers (`obra/superpowers`)**: Framework phát triển phần mềm chuẩn mực (TDD, Brainstorming, Subagents, Worktrees)
- **ECC (`affaan-m/ECC`)**: Profile Developer (Database patterns, Quality workflows, Unified memory) — giữ hook runtime
- **CodeGraph (`colbymchenry/codegraph`)**: MCP code intelligence & semantic graph
- **Andrej Karpathy Guidelines (`multica-ai/andrej-karpathy-skills`)**: 4 nguyên tắc vàng định hướng hành vi của AI coding
- **opencode-goal-plugin**: Session-scoped goal workflow kèm slash command `/goal`
- **9Remote notify (`plugin/nineRemoteNotify.js`)**: Plugin local báo trạng thái session về 9Remote

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