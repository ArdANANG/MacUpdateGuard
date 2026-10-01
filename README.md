# MacUpdateGuard 🛡️

**macOS 系统更新屏蔽工具** —— 一键屏蔽 / 恢复系统更新、清除「小红点」角标，图形界面开箱即用。

🎉 **v4.9 全新图形版本**：打开 App 点一下即可，无需终端命令。同时保留完整命令行模式。

## 功能

| 功能          | 说明                        |
| ----------- | ------------------------- |
| 🚫 屏蔽系统更新   | 屏蔽 Apple 更新服务器，阻止自动检测与下载  |
| ✅ 恢复系统更新    | 一键还原全部设置                  |
| 🔴 清除小红点    | 清除「系统设置」更新角标（支持 macOS 15） |
| 🌐 VPN 配置屏蔽 | 挂代理时也能屏蔽（ClashX 等自动写入规则）  |
| 📊 查看状态     | 检测屏蔽是否生效                  |

## 下载安装

前往 [Releases](https://github.com/ArdANANG/MacUpdateGuard/releases) 下载 `MacUpdateGuard.dmg`：

1. 打开 DMG，将 App 拖入「应用程序」
2. 首次打开提示「无法验证开发者」时：右键 App → 打开（或到 系统设置 → 隐私与安全性 → 仍要打开）
3. 点右下角「授权」输入管理员密码即可使用

**系统要求**：macOS 10.13 及以上，Intel / Apple Silicon 通用。

## VPN 用户看这里

挂代理（ClashX / ClashX Pro 等）时，解决方法：

1. 先执行「屏蔽系统更新」，再点 **「VPN配置屏蔽」**（自动处理 `~/.config/clash` 下所有配置，含 `profiles/` 子目录）
2. 在代理工具菜单栏「配置」中**重新载入配置**（或重启代理工具）
3. 重启一次 macOS，小红点彻底消失

> 原配置自动备份为 `*.yaml.mugbak`，点「还原VPN屏蔽」即可回滚。

### 其他代理工具（手动添加）

使用 Surge / Quantumult X / Loon 等工具时，把下面 6 条规则添加到**规则列表最顶部**（顺序决定优先级，必须在所有分流规则之前），保存后重新载入配置。

**Surge**（配置文件 `[Rule]` 部分最顶部）：

```
DOMAIN,swscan.apple.com,REJECT
DOMAIN,swdist.apple.com,REJECT
DOMAIN,swcdn.apple.com,REJECT
DOMAIN,gdmf.apple.com,REJECT
DOMAIN,mesu.apple.com,REJECT
DOMAIN,xp.apple.com,REJECT
```

**Quantumult X**（配置文件 `[filter_local]` 部分最顶部）：

```
domain, swscan.apple.com, reject
domain, swdist.apple.com, reject
domain, swcdn.apple.com, reject
domain, gdmf.apple.com, reject
domain, mesu.apple.com, reject
domain, xp.apple.com, reject
```

## 命令行使用

不想装 App？一条命令直接用脚本：

```bash
cd ~ && curl -fsSL -o MacUpdateGuard.sh https://raw.githubusercontent.com/ArdANANG/MacUpdateGuard/main/MacUpdateGuard.sh && chmod +x MacUpdateGuard.sh && sudo ./MacUpdateGuard.sh
```

运行后出现交互菜单，按数字选择即可。也可直接使用子命令：

```bash
sudo ./MacUpdateGuard.sh disable     # 屏蔽系统更新
sudo ./MacUpdateGuard.sh restore     # 恢复系统更新
sudo ./MacUpdateGuard.sh clearbadge  # 清除小红点
sudo ./MacUpdateGuard.sh vpn         # VPN 配置屏蔽
sudo ./MacUpdateGuard.sh unvpn       # 还原 VPN 屏蔽
sudo ./MacUpdateGuard.sh status      # 查看状态
```

已装 App 的，脚本也可以直接调用：`sudo /Applications/MacUpdateGuard.app/Contents/Resources/MacUpdateGuard.sh`

## 老版本用户更新

**脚本用户**：重新跑一遍下载命令即可，会自动覆盖旧版：

```bash
cd ~ && curl -fsSL -o MacUpdateGuard.sh https://raw.githubusercontent.com/ArdANANG/MacUpdateGuard/main/MacUpdateGuard.sh && chmod +x MacUpdateGuard.sh && sudo ./MacUpdateGuard.sh
```

**App 用户**：下载新 DMG → 打开 → 把新 App 拖入「应用程序」→ 提示「已存在同名文件」时点**替换**即可，无需先卸载。

## 不会用终端？照这个来

1. 打开「终端」（Launchpad → 其他 → 终端）
2. 复制下面**这一整行**，粘贴进去，按回车：

```bash
cd ~ && curl -fsSL -o MacUpdateGuard.sh https://raw.githubusercontent.com/ArdANANG/MacUpdateGuard/main/MacUpdateGuard.sh && chmod +x MacUpdateGuard.sh && sudo ./MacUpdateGuard.sh
```

1. 提示输入密码时，输入你的开机密码（屏幕不会显示，输完直接回车），出现菜单后按数字选择即可
