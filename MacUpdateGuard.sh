#!/bin/bash
# MacUpdateGuard v4.9 - macOS 系统更新管理工具
# 作者: bili_25396444320 (c) 2026
# 屏蔽/恢复系统更新、清除小红点、VPN(Clash)配置屏蔽
# 兼容 macOS 10.13+ (Intel / Apple Silicon)
# 用法: sudo ./MacUpdateGuard.sh  或  MacUpdateGuard.sh [disable|restore|vpn|unvpn|clearbadge|status|version|help]

# -------------------------- 全局配置 ---------------------------
readonly SCRIPT_VERSION="4.9"
readonly DEFAULT_DOMAIN_LIST=(
    "swscan.apple.com"
    "mesu.apple.com"
    "swdist.apple.com"
    "swcdn.apple.com"
    "gdmf.apple.com"
    "xp.apple.com"
)

# VPN(Clash 系代理)配置写入的 REJECT 规则：须顶置于 rules 部分，才能优先命中
readonly VPN_RULES=(
    "- DOMAIN,swdist.apple.com,REJECT"
    "- DOMAIN,swscan.apple.com,REJECT"
    "- DOMAIN,swcdn.apple.com,REJECT"
    "- DOMAIN,gdmf.apple.com,REJECT"
    "- DOMAIN,mesu.apple.com,REJECT"
    "- DOMAIN,xp.apple.com,REJECT"
)

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_NC='\033[0m' # 无颜色

# -------------------------- 初始化状态 -------------------------
INSTALLED=false
INSTALL_PATH=""

# -------------------------- 核心功能函数 -----------------------
function main() {
    check_installation
    verify_privileges
    display_header

    while true; do
        show_main_menu
        read -p "请输入选项 (1-8): " choice

        case $choice in
            1) disable_system_updates ;;
            2) restore_system_updates ;;
            3) configure_vpn_block ;;
            4) remove_vpn_block ;;
            5) clear_red_badge ;;
            6) check_system_status ;;
            7) show_version_info ;;
            8) graceful_exit ;;
            *) handle_invalid_input ;;
        esac

        echo "============================================================"
    done
}

# -------------------------- 权限管理 --------------------------
function verify_privileges() {
    if [[ $(id -u) != "0" ]]; then
        echo -e "${COLOR_RED}错误: 需要管理员权限执行此操作${COLOR_NC}" >&2
        echo "请使用: sudo \"$0\"" >&2
        exit 1
    fi
}

# -------------------------- 安装管理 --------------------------
function check_installation() {
    # 检查是否在用户目录
    if [[ "$(pwd)" =~ ^/Users/ ]]; then
        INSTALLED=true
        INSTALL_PATH="$(pwd)/$(basename "$0")"
        return
    fi

    echo "检测到脚本未安装在用户目录"
    echo "------------------------------------------------------------"
    echo "推荐将脚本安装到用户目录以获得最佳体验"
    echo "请选择操作:"
    echo "1. 自动安装到用户目录并启动 (推荐)"
    echo "2. 继续在当前目录执行"
    echo "3. 退出"
    echo ""

    read -p "请选择操作 (1-3): " install_choice

    case $install_choice in
        1) auto_install ;;
        2)
            echo "在当前目录继续执行..."
            INSTALL_PATH="$(pwd)/$(basename "$0")"
            ;;
        3) exit 0 ;;
        *) auto_install ;;
    esac
}

function auto_install() {
    local current_user=$(whoami)
    INSTALL_PATH="/Users/$current_user/MacUpdateGuard.sh"

    echo "正在自动安装..."
    echo "------------------------------------------------------------"

    sudo cp "$0" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"

    echo "安装完成! 位置: $INSTALL_PATH"
    echo "正在启动程序..."
    echo "------------------------------------------------------------"

    exec sudo "$INSTALL_PATH"
}

# -------------------------- 更新管理 --------------------------
function disable_system_updates() {
    echo "正在禁用系统自动更新..."
    echo "------------------------------------------------------------"

    # 执行禁用操作
    execute_disable_actions

    echo "------------------------------------------------------------"
    echo -e "${COLOR_GREEN}系统更新已成功禁用${COLOR_NC}"

    show_reboot_hint
}

function restore_system_updates() {
    echo "正在恢复系统更新功能..."
    echo "------------------------------------------------------------"

    # 执行恢复操作
    execute_restore_actions

    echo "------------------------------------------------------------"
    echo -e "${COLOR_GREEN}系统更新功能已成功恢复${COLOR_NC}"

    show_reboot_hint
}

# -------------------------- 清除小红点 --------------------------
function clear_red_badge() {
    echo "正在清除系统更新小红点/通知标记..."
    echo "------------------------------------------------------------"

    clear_badge_core

    echo "------------------------------------------------------------"

    # 回读偏好域校验：写入是否真的落盘（而不是被缓存顶掉）
    if verify_badge_cleared; then
        echo -e "${COLOR_GREEN}小红点标记已清除${COLOR_NC}"
        echo "MGU_BADGE=CLEARED"
    else
        echo -e "${COLOR_YELLOW}已执行清理，但偏好域中仍检测到残留标记${COLOR_NC}"
        echo -e "提示: 可重复执行一次；若仍无效，请重启后再试。"
        echo "MGU_BADGE=EXISTS"
    fi

    echo "提示: 若小红点稍后再次出现，说明系统又检测到了新更新，"
    echo "      可先执行「禁用系统自动更新」后再清除小红点。"
}

# 清除小红点的核心动作（供「清除小红点」与「禁用系统更新」共用）
function clear_badge_core() {
    # 1. 重置「系统设置」角标计数（必须写入当前登录用户的偏好域）
    echo "[1/5] 重置「系统设置」角标计数..."
    user_defaults_write "com.apple.systempreferences" "AttentionPrefBundleIDs" 0

    # 2. 清除「已提示过」残留标记
    #    该键残留时系统会认为角标已展示完毕，抑制后续清理动作
    echo "[2/5] 清除「已提示过」残留标记..."
    user_defaults_delete "com.apple.systempreferences" "DidShowPrefBundleIDs"

    # 3. 标记大版本升级提醒为已读，阻止「macOS 升级提醒」横幅再弹
    echo "[3/5] 标记大版本升级提醒为已读..."
    user_defaults_write_bool "com.apple.preferences.softwareupdate" "DidShowUpgradeNag" true

    # 4. 刷新偏好缓存 + 重启 Dock —— v4.9 的关键一步
    #    缺了 cfprefsd 刷新，前面的写入会被缓存顶掉，角标不消失
    echo "[4/5] 刷新偏好缓存并重启 Dock..."
    refresh_preferences_cache

    # 5. 清理系统级「推荐更新」列表（角标根因）
    echo "[5/5] 清理系统「推荐更新」列表..."
    purge_recommended_updates

    # 6. 重启通知服务并清掉旧版标记文件（兼容旧系统，新系统通常不存在）
    sudo killall usernoted 2>/dev/null
    sudo killall NotificationCenter 2>/dev/null
    sudo rm -f /var/db/SoftwareUpdate.badge 2>/dev/null
}

# 刷新偏好缓存与 Dock
function refresh_preferences_cache() {
    # cfprefsd 会缓存偏好值。不杀掉它，Dock / 系统设置仍读旧缓存，角标不消失。
    killall cfprefsd 2>/dev/null
    sleep 1
    killall Dock 2>/dev/null
}

# 清理系统级「推荐更新」列表
function purge_recommended_updates() {
    local rec_count
    rec_count=$(recommended_update_count)
    if [[ "${rec_count:-0}" == "0" ]]; then
        echo "      推荐更新列表本就为空，跳过"
        return 0
    fi
    echo "      当前有 ${rec_count} 条推荐更新，正在清理..."
    sudo defaults delete /Library/Preferences/com.apple.SoftwareUpdate.plist RecommendedUpdates >/dev/null 2>&1
    sudo killall cfprefsd >/dev/null 2>&1
    echo "      已清理（更新包文件未删除，如需一并清理请点「禁用系统自动更新」）"
}

# 统计系统级「推荐更新」条数（读不到时返回 0）
function recommended_update_count() {
    local n
    n=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist RecommendedUpdates 2>/dev/null \
        | grep -c "Product Key" 2>/dev/null)
    [[ -z "$n" ]] && n=0
    echo "$n"
}

# -------------------------- VPN 配置屏蔽 --------------------------

# 定位「当前登录用户」的 Clash 配置目录
function console_user_name() {
    stat -f %Su /dev/console 2>/dev/null
}

function vpn_config_dir() {
    local console_user home_dir
    console_user="$(console_user_name)"
    [[ -z "$console_user" || "$console_user" == "root" ]] && { echo ""; return; }
    home_dir="$(dscl . -read "/Users/$console_user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
    [[ -n "$home_dir" ]] && echo "$home_dir/.config/clash"
}

# 收集配置文件：顶层 *.yaml/*.yml + profiles 等一级子目录
function vpn_config_files() {
    local dir="$1" f
    for f in "$dir"/*.yaml "$dir"/*.yml "$dir"/*/*.yaml "$dir"/*/*.yml; do
        [[ -f "$f" ]] && printf '%s\n' "$f"
    done
}

# 以 root 覆写用户文件后，还原属主与权限，避免 ClashX 无法写回配置
function restore_file_owner() {
    local file="$1" mode="$2" console_user
    console_user="$(console_user_name)"
    [[ -n "$mode" ]] && chmod "$mode" "$file" 2>/dev/null
    [[ -n "$console_user" && "$console_user" != "root" ]] && chown "$console_user" "$file" 2>/dev/null
    return 0
}

function configure_vpn_block() {
    local dir
    dir="$(vpn_config_dir)"
    if [[ -z "$dir" || ! -d "$dir" ]]; then
        echo "未找到 ClashX 配置目录 (~/.config/clash)"
        echo "说明: 若使用其他代理工具，请参考项目 README 手动添加 REJECT 规则"
        echo "MGU_VPN=NOT_FOUND"
        return 1
    fi

    local yaml modified=0 skipped=0 seen=0
    while IFS= read -r yaml; do
        [[ -f "$yaml" ]] || continue
        seen=$((seen+1))
        if grep -q "swscan.apple.com" "$yaml"; then
            echo "跳过(已有屏蔽规则): $(basename "$yaml")"
            skipped=$((skipped+1))
            continue
        fi
        if ! grep -qE "^rules:[[:space:]]*$" "$yaml"; then
            echo "跳过(无 rules 部分): $(basename "$yaml")"
            skipped=$((skipped+1))
            continue
        fi

        local mode
        mode=$(stat -f %Lp "$yaml" 2>/dev/null)
        # 修改前备份一份，出错可手动还原
        cp -f "$yaml" "$yaml.mugbak"

        # 在 rules: 行后紧跟插入屏蔽块（保证顶置优先命中）
        # 注意: BSD awk(macOS 自带) 用 -v 传多行字符串会报 "newline in string"，
        #       因此规则块写入独立临时文件，由 awk 读取插入
        printf '%s\n' "${VPN_RULES[@]}" > "$yaml.mugrules"
        if awk -v rf="$yaml.mugrules" '
            /^rules:[[:space:]]*$/ {
                print
                while ((getline line < rf) > 0) print line
                close(rf)
                inserted=1
                next
            }
            { print }
            END { exit !inserted }
        ' "$yaml" > "$yaml.mugtmp"; then
            mv -f "$yaml.mugtmp" "$yaml"
            restore_file_owner "$yaml" "$mode"
            modified=$((modified+1))
            echo "已写入屏蔽规则: $(basename "$yaml")"
        else
            rm -f "$yaml.mugtmp"
            echo "写入失败(未找到 rules: 行): $(basename "$yaml")"
        fi
        rm -f "$yaml.mugrules"
    done < <(vpn_config_files "$dir")

    if [[ $seen -eq 0 ]]; then
        echo "配置目录中未找到 yaml 配置文件"
        echo "MGU_VPN=NOT_FOUND"
        return 1
    fi

    echo "MGU_VPN=MODIFIED=$modified"
    if [[ $modified -gt 0 ]]; then
        echo "完成: 请在代理工具菜单栏「配置」中重新载入配置（或重启代理工具）后生效"
    fi
    # 文件存在但一条都没写入成功（如均无 rules 段）视为失败
    [[ $modified -eq 0 && $skipped -eq 0 ]] && return 1
    return 0
}

function remove_vpn_block() {
    local dir
    dir="$(vpn_config_dir)"
    if [[ -z "$dir" || ! -d "$dir" ]]; then
        echo "未找到 ClashX 配置目录 (~/.config/clash)"
        echo "MGU_VPN=NOT_FOUND"
        return 1
    fi

    # 精确匹配本工具写入的 6 条规则行，不碰配置文件其他内容
    local del_regex='^- DOMAIN,(swdist|swscan|swcdn|gdmf|mesu|xp)\.apple\.com,REJECT[[:space:]]*$'
    local yaml modified=0
    while IFS= read -r yaml; do
        [[ -f "$yaml" ]] || continue
        if ! grep -qE "$del_regex" "$yaml"; then
            continue
        fi
        local mode
        mode=$(stat -f %Lp "$yaml" 2>/dev/null)
        if grep -vE "$del_regex" "$yaml" > "$yaml.mugtmp" && [[ -s "$yaml.mugtmp" ]]; then
            mv -f "$yaml.mugtmp" "$yaml"
            restore_file_owner "$yaml" "$mode"
            modified=$((modified+1))
            echo "已移除屏蔽规则: $(basename "$yaml")"
        else
            rm -f "$yaml.mugtmp"
            echo "还原失败(结果为空，已保留原文件): $(basename "$yaml")"
        fi
    done < <(vpn_config_files "$dir")

    echo "MGU_VPN=MODIFIED=$modified"
    if [[ $modified -gt 0 ]]; then
        echo "完成: 请在代理工具菜单栏「配置」中重新载入配置（或重启代理工具）后生效"
    fi
}

# -------------------------- 操作函数 --------------------------
function execute_disable_actions() {
    echo "关闭自动更新计划..."
    sudo softwareupdate --schedule off >/dev/null 2>&1

    # 增强设置项禁用，彻底解决电源接入后小红点问题
    echo "禁用所有自动更新选项..."
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled -bool FALSE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticDownload -bool FALSE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall -bool FALSE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall -bool FALSE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates -bool FALSE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticInstallation -bool FALSE

    echo "清理更新缓存文件..."
    sudo rm -rf /Library/Caches/com.apple.SoftwareUpdate/ 2>/dev/null
    sudo find /private/var/folders -name "com.apple.SoftwareUpdate" -exec rm -rf {} + 2>/dev/null

    create_hosts_backup
    configure_hosts_block

    refresh_system_services

    echo "停止更新服务..."
    sudo launchctl disable system/com.apple.softwareupdated >/dev/null 2>&1
    sudo launchctl stop system/com.apple.softwareupdated >/dev/null 2>&1
    sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.softwareupdated.plist >/dev/null 2>&1

    # 防止电源触发更新 - 增强解决小红点问题
    echo "禁用电源触发更新..."
    sudo pmset -a powernap 0 >/dev/null 2>&1
    sudo pmset -a womp 0 >/dev/null 2>&1
    sudo pmset -a darkwakes 0 >/dev/null 2>&1

    # 增强通知系统处理 - 彻底解决小红点问题（v4.9: 复用新的清理内核）
    echo "清除系统通知标记..."
    clear_badge_core

    echo "深度清理缓存..."
    sudo rm -rf /Library/Updates/* 2>/dev/null
    sudo rm -f /var/db/softwareupdate/* 2>/dev/null

    # 彻底清除小红点标记
    echo "清除小红点标记..."
    sudo rm -f /var/db/SoftwareUpdate.badge 2>/dev/null
    sudo rm -f /Library/Preferences/com.apple.preferences.softwareupdate.plist 2>/dev/null
    sudo rm -f /var/db/softwareupdate/preferences.plist 2>/dev/null
    sudo rm -f /private/var/db/softwareupdate/preferences.plist 2>/dev/null

    # 终止所有相关进程 - 确保设置立即生效
    echo "终止更新服务进程..."
    sudo killall softwareupdated 2>/dev/null
    sudo killall softwareupdated_notify_agent 2>/dev/null

    # 重置软件更新状态
    echo "重置软件更新状态..."
    sudo softwareupdate --reset-ignored >/dev/null 2>&1
}

function execute_restore_actions() {
    # 首先恢复Hosts配置
    restore_hosts_backup

    echo "启用自动更新计划..."
    sudo softwareupdate --schedule on >/dev/null 2>&1

    echo "恢复所有更新选项..."
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled -bool TRUE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticDownload -bool TRUE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall -bool TRUE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall -bool TRUE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates -bool TRUE
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticInstallation -bool TRUE

    echo "启动更新服务..."
    sudo launchctl enable system/com.apple.softwareupdated >/dev/null 2>&1
    sudo launchctl start system/com.apple.softwareupdated >/dev/null 2>&1
    sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.softwareupdated.plist >/dev/null 2>&1

    # 恢复电源设置
    echo "恢复电源触发设置..."
    sudo pmset -a powernap 1 >/dev/null 2>&1
    sudo pmset -a womp 1 >/dev/null 2>&1
    sudo pmset -a darkwakes 1 >/dev/null 2>&1

    echo "清理恢复缓存..."
    sudo rm -rf /Library/Caches/com.apple.SoftwareUpdate/ 2>/dev/null

    # 最后刷新系统服务
    refresh_system_services

    # 重置更新标记状态
    echo "重置更新标记状态..."
    sudo touch /var/db/SoftwareUpdate.badge
    sudo chmod 644 /var/db/SoftwareUpdate.badge
}

# -------------------------- 辅助函数 --------------------------
# 写入「当前登录用户」的偏好域
function user_defaults_write() {
    local domain="$1"
    local key="$2"
    local value="$3"
    local console_user=""
    console_user="$(stat -f %Su /dev/console 2>/dev/null)"

    if [[ "$(id -u)" == "0" && -n "$console_user" && "$console_user" != "root" ]]; then
        sudo -u "$console_user" defaults write "$domain" "$key" "$value" 2>/dev/null && return 0
    fi
    defaults write "$domain" "$key" "$value" 2>/dev/null
}

# 写入「当前登录用户」的布尔型偏好（defaults 需要 -bool 参数，故单列一个函数）
function user_defaults_write_bool() {
    local domain="$1"
    local key="$2"
    local value="$3"
    local console_user=""
    console_user="$(stat -f %Su /dev/console 2>/dev/null)"

    if [[ "$(id -u)" == "0" && -n "$console_user" && "$console_user" != "root" ]]; then
        sudo -u "$console_user" defaults write "$domain" "$key" -bool "$value" 2>/dev/null && return 0
    fi
    defaults write "$domain" "$key" -bool "$value" 2>/dev/null
}

# 删除「当前登录用户」偏好域中的指定键
function user_defaults_delete() {
    local domain="$1"
    local key="$2"
    local console_user=""
    console_user="$(stat -f %Su /dev/console 2>/dev/null)"

    if [[ "$(id -u)" == "0" && -n "$console_user" && "$console_user" != "root" ]]; then
        sudo -u "$console_user" defaults delete "$domain" "$key" >/dev/null 2>&1 && return 0
    fi
    defaults delete "$domain" "$key" >/dev/null 2>&1
}

# 读取「当前登录用户」偏好域的键值（读不到时输出空串）
function user_defaults_read() {
    local domain="$1"
    local key="$2"
    local console_user=""
    console_user="$(stat -f %Su /dev/console 2>/dev/null)"

    # 以 root 直接读会落到 /var/root 偏好域，必须切到登录用户
    if [[ "$(id -u)" == "0" && -n "$console_user" && "$console_user" != "root" ]]; then
        sudo -u "$console_user" defaults read "$domain" "$key" 2>/dev/null
        return
    fi
    defaults read "$domain" "$key" 2>/dev/null
}

# 校验小红点标记是否已清干净：角标计数为 0（或未设置）且无 DidShowPrefBundleIDs 残留
function verify_badge_cleared() {
    local attn did_show
    attn="$(user_defaults_read "com.apple.systempreferences" "AttentionPrefBundleIDs")"
    did_show="$(user_defaults_read "com.apple.systempreferences" "DidShowPrefBundleIDs")"

    [[ -z "$did_show" && ( -z "$attn" || "$attn" == "0" ) ]]
}

function create_hosts_backup() {
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="/etc/hosts.bak_$timestamp"
    sudo cp /etc/hosts "$backup_file"
    echo "已创建Hosts备份: ${backup_file##*/}"

    # 安全加固: 仅保留最近 3 份备份，避免 /etc 下无限堆积 hosts.bak_* 文件
    local old_baks=($(ls -t /etc/hosts.bak_* 2>/dev/null | tail -n +4))
    for old in "${old_baks[@]}"; do
        sudo rm -f "$old"
    done
}

function restore_hosts_backup() {
    if ls /etc/hosts.bak_* >/dev/null 2>&1; then
        local latest_bak=$(ls -t /etc/hosts.bak_* | head -1)
        sudo cp -f "$latest_bak" /etc/hosts
        sudo chmod 644 /etc/hosts
        echo "已恢复Hosts备份: ${latest_bak##*/}"

        # 确保移除所有屏蔽规则
        remove_hosts_block
    else
        echo "注意: 未找到Hosts备份文件，尝试直接移除屏蔽规则..."
        remove_hosts_block
    fi
}

function configure_hosts_block() {
    # 安全加固: 先移除旧屏蔽块再追加，避免多次执行「禁用」导致规则重复堆积
    remove_hosts_block
    {
        echo ""
        echo "# 更新屏蔽规则"
        for domain in "${DEFAULT_DOMAIN_LIST[@]}"; do
            echo "127.0.0.1 $domain"
        done
    } | sudo tee -a /etc/hosts >/dev/null
    sudo chmod 644 /etc/hosts
}

function remove_hosts_block() {
    # 安全加固: 按「标记行 + 已知域名行」精确过滤，替代脆弱的固定行数 sed 删除
    # （旧行为: sed '/# 更新屏蔽规则/,+Nd' 假定标记后恰好 N 行，若 hosts 被其他
    #   工具/用户修改过，可能误删无关配置或漏删屏蔽规则）
    if grep -q "^# 更新屏蔽规则" /etc/hosts; then
        echo "正在移除Hosts屏蔽规则..."
        local tmp_hosts
        tmp_hosts="$(mktemp)"
        local domain_regex
        domain_regex=$(IFS='|'; echo "${DEFAULT_DOMAIN_LIST[*]}")
        sudo awk -v re="^127\.0\.0\.1[[:space:]]+($domain_regex)[[:space:]]*$" '
            /^# 更新屏蔽规则[[:space:]]*$/ { skip=1; next }
            skip && $0 ~ re { next }
            { skip=0; print }
        ' /etc/hosts | sudo tee "$tmp_hosts" >/dev/null
        # 仅当过滤结果非空才替换，避免异常情况下清空 /etc/hosts
        if [[ -s "$tmp_hosts" ]]; then
            sudo cat "$tmp_hosts" > /etc/hosts  # cp 会继承临时文件属主/权限，这里原地覆写
            sudo chmod 644 /etc/hosts
        fi
        rm -f "$tmp_hosts"
    fi
}

function refresh_system_services() {
    echo "刷新系统服务..."
    sudo dscacheutil -flushcache >/dev/null 2>&1
    sudo killall -HUP mDNSResponder >/dev/null 2>&1

    # 静默处理服务操作
    sudo launchctl stop system/com.apple.softwareupdated >/dev/null 2>&1
    sleep 1
    sudo launchctl start system/com.apple.softwareupdated >/dev/null 2>&1

    # 确保通知服务刷新
    sudo killall -9 NotificationCenter 2>/dev/null
}

# -------------------------- 重启提示 --------------------------
function show_reboot_hint() {
    echo ""
    echo -e "${COLOR_YELLOW}============================================================${COLOR_NC}"
    echo -e "${COLOR_YELLOW}重要提示: 为使设置完全生效，请自行手动重启或关机:${COLOR_NC}"
    echo "  - 点击屏幕左上角  >  重新启动... / 关机..."
    echo "  - 或稍后自行选择合适的时间重启电脑"
    echo -e "${COLOR_YELLOW}============================================================${COLOR_NC}"
}

# -------------------------- 信息显示 --------------------------
function display_header() {
    echo ""
    echo "============================================================"
    echo "MacUpdateGuard v${SCRIPT_VERSION} | 作者: bili_25396444320"
    [[ -n "$INSTALL_PATH" ]] && echo "位置: $INSTALL_PATH"
    echo "============================================================"
}

function show_main_menu() {
    echo ""
    echo "请选择操作:"
    echo "1. 禁用系统自动更新"
    echo "2. 恢复系统自动更新"
    echo "3. VPN配置屏蔽 (ClashX)"
    echo "4. 还原VPN屏蔽"
    echo "5. 清除小红点"
    echo "6. 检查更新状态"
    echo "7. 显示版本信息"
    echo "8. 退出"
    echo ""
}

function check_system_status() {
    echo "系统更新状态检查:"
    echo "------------------------------------------------------------"

    # 检查更新计划状态
    # 说明: 中文系统下 `softwareupdate --schedule` 的输出会被本地化
    #       （如「自动检查已关闭」），不含英文 "off"，导致误判。
    #       优先读取 AutomaticCheckEnabled 偏好域（0=已禁用 1=已启用），
    #       读不到时再回退到命令输出匹配（兼容中英文）。
    local schedule_off=false
    local auto_check=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled 2>/dev/null)
    if [[ "$auto_check" == "0" ]]; then
        schedule_off=true
    elif [[ -z "$auto_check" ]]; then
        local schedule_status=$(softwareupdate --schedule 2>&1)
        if [[ $schedule_status == *"off"* || $schedule_status == *"已关闭"* || $schedule_status == *"已禁用"* ]]; then
            schedule_off=true
        fi
    fi

    if $schedule_off; then
        echo -e "自动更新状态: ${COLOR_RED}已禁用${COLOR_NC}"
    else
        echo -e "自动更新状态: ${COLOR_GREEN}已启用${COLOR_NC}"
    fi

    # 检查服务器屏蔽状态
    echo -n "服务器屏蔽状态: "
    local all_active=true
    for domain in "${DEFAULT_DOMAIN_LIST[@]}"; do
        if ! grep -q "^127\.0\.0\.1[[:space:]]*$domain" /etc/hosts; then
            all_active=false
            break
        fi
    done

    if $all_active; then
        echo -e "${COLOR_RED}已生效${COLOR_NC}"
    else
        echo -e "${COLOR_GREEN}未生效${COLOR_NC}"
    fi

    # 检查软件更新服务状态
    local service_status=$(sudo launchctl list 2>/dev/null | grep com.apple.softwareupdated)
    if [[ -z "$service_status" ]]; then
        echo -e "软件更新服务状态: ${COLOR_RED}未运行${COLOR_NC}"
    else
        echo -e "软件更新服务状态: ${COLOR_GREEN}运行中${COLOR_NC}"
    fi

    # 检查小红点标记状态
    # v4.9: 旧版判断的是 /var/db/SoftwareUpdate.badge 这个标记文件——该文件在
    #       现代 macOS 上根本不存在，导致永远上报「已清除」。现改为回读真实偏好域。
    if verify_badge_cleared; then
        echo -e "小红点标记状态: ${COLOR_RED}已清除${COLOR_NC}"
        echo "MGU_BADGE=CLEARED"
    else
        echo -e "小红点标记状态: ${COLOR_GREEN}仍有残留${COLOR_NC}"
        echo "MGU_BADGE=EXISTS"
    fi

    # 系统仍推荐的更新条数 —— 角标复现的源头，非 0 说明清完还会再亮
    local rec_count
    rec_count=$(recommended_update_count)
    if [[ "$rec_count" == "0" ]]; then
        echo -e "系统推荐更新条数: ${COLOR_RED}0${COLOR_NC}"
    else
        echo -e "系统推荐更新条数: ${COLOR_GREEN}${rec_count}${COLOR_NC}（角标可能再次出现）"
    fi
    echo "MGU_REC=${rec_count}"

    echo "------------------------------------------------------------"
    echo "提示: 打开 系统设置 > 通用 > 软件更新 验证实际状态"

    # 机器可读结果标记（供 MacUpdateGuard.app 图形界面精确解析）
    if $all_active; then
        echo "MGU_BLOCKED=YES"
    else
        echo "MGU_BLOCKED=NO"
    fi
    if $schedule_off; then
        echo "MGU_SCHEDULE=OFF"
    else
        echo "MGU_SCHEDULE=ON"
    fi
}

function show_version_info() {
    echo "------------------------------------------------------------"
    echo "MacUpdateGuard v${SCRIPT_VERSION}"
    echo "作者: bili_25396444320"
    echo "最后更新: 2026年10月2日"
    echo "------------------------------------------------------------"
}

# -------------------------- 结果校验 --------------------------
# 禁用后的实际效果校验: hosts 屏蔽规则齐全 + 自动更新开关确已关闭
function verify_disable_effect() {
    local ok=true
    for domain in "${DEFAULT_DOMAIN_LIST[@]}"; do
        if ! grep -q "^127\.0\.0\.1[[:space:]]*$domain" /etc/hosts; then
            echo "校验失败: $domain 未写入 /etc/hosts" >&2
            ok=false
        fi
    done
    local auto_check
    auto_check=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticCheckEnabled 2>/dev/null)
    if [[ "$auto_check" != "0" ]]; then
        echo "校验失败: AutomaticCheckEnabled 未关闭 (当前值: ${auto_check:-未设置})" >&2
        ok=false
    fi
    $ok
}

# -------------------------- 退出处理 --------------------------
function graceful_exit() {
    echo ""
    echo "感谢使用系统更新管理工具!"
    [[ -n "$INSTALL_PATH" ]] && echo "提示: 下次运行: sudo \"$INSTALL_PATH\""
    exit 0
}

function handle_invalid_input() {
    echo -e "${COLOR_RED}无效选项，请重新输入${COLOR_NC}"
}

# ======================== 子命令模式 ========================
# 用法: MacUpdateGuard.sh [disable|restore|vpn|unvpn|clearbadge|status|version|help]
# 供 MacUpdateGuard.app 图形界面或命令行直接调用，跳过交互菜单
function show_help() {
    echo "MacUpdateGuard v${SCRIPT_VERSION}"
    echo "用法: $0 [子命令]"
    echo ""
    echo "子命令:"
    echo "  disable     禁用系统自动更新"
    echo "  restore     恢复系统自动更新"
    echo "  vpn         VPN配置屏蔽 (向 ClashX 配置写入 REJECT 规则)"
    echo "  unvpn       还原VPN屏蔽"
    echo "  clearbadge  清除系统更新小红点"
    echo "  status      检查当前更新状态"
    echo "  version     显示版本信息"
    echo "  help        显示本帮助"
    echo ""
    echo "不带参数运行将进入交互式菜单（需 sudo）。"
}

function run_subcommand() {
    # 安全加固: 写操作必须以 root 执行，否则系统命令会静默失败
    case "$1" in
        disable|restore|clearbadge|vpn|unvpn)
            if [[ $(id -u) != "0" ]]; then
                echo "错误: 子命令 '$1' 需要 root 权限" >&2
                echo "MGU_ERROR=NEED_ROOT" >&2
                echo "请使用: sudo \"$0\" $1" >&2
                exit 2
            fi
            ;;
    esac
    case "$1" in
        disable)
            execute_disable_actions
            # 安全加固: 执行后实际校验效果，防止「命令静默失败仍报成功」
            verify_disable_effect || {
                echo "错误: 禁用操作未完全生效，请检查上方输出" >&2
                echo "MGU_ERROR=VERIFY_FAILED" >&2
                exit 3
            }
            echo "系统更新已成功禁用"
            echo "提示: 请自行手动重启或关机以使设置完全生效"
            ;;
        restore)
            execute_restore_actions
            # 恢复操作同样校验: 屏蔽规则应已移除
            if grep -q "^# 更新屏蔽规则" /etc/hosts; then
                echo "错误: hosts 屏蔽规则未能移除" >&2
                echo "MGU_ERROR=VERIFY_FAILED" >&2
                exit 3
            fi
            echo "系统更新功能已成功恢复"
            echo "提示: 请自行手动重启或关机以使设置完全生效"
            ;;
        vpn)
            configure_vpn_block || exit 1
            ;;
        unvpn)
            remove_vpn_block || exit 1
            ;;
        clearbadge)
            clear_red_badge
            ;;
        status)
            check_system_status
            ;;
        version)
            echo "MacUpdateGuard v${SCRIPT_VERSION}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "未知子命令: $1" >&2
            echo "用法: $0 [disable|restore|vpn|unvpn|clearbadge|status|version|help]" >&2
            exit 1
            ;;
    esac
    exit 0
}

# ======================== 脚本启动入口 ========================
# 带参数时进入子命令模式 (GUI/命令行直调)；无参数时进入交互菜单
if [[ $# -gt 0 ]]; then
    run_subcommand "$1"
fi

if [ -x "$0" ]; then
    main "$@"
else
    echo "检测到权限问题，正在修复..."
    echo "------------------------------------------------------------"

    sudo chmod +x "$0"
    if [ -x "$0" ]; then
        echo "权限修复成功! 重新启动脚本..."
        echo "------------------------------------------------------------"
        exec sudo "$0"
    else
        echo -e "${COLOR_RED}权限修复失败，请手动执行:${COLOR_NC}"
        echo "sudo chmod +x \"$0\""
        echo "sudo \"$0\""
        exit 1
    fi
fi
