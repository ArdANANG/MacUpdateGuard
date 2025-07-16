#!/bin/bash
# ========================================================================
# MacUpdateGuard v4.0
# 作者: bili_25396444320 (c) 2025
# 功能：macOS系统更新管理工具
# 优化版：2025年7月17日
# ========================================================================

# -------------------------- 全局配置 ---------------------------
readonly SCRIPT_VERSION="4.0"
readonly DEFAULT_DOMAIN_LIST=(
    "swscan.apple.com"
    "mesu.apple.com"
    "swdist.apple.com"
    "swcdn.apple.com"
    "gdmf.apple.com"
    "appldnld.apple.com"
    "ioshost.qtlcdn.com"
)

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
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
        read -p "请输入选项 (1-5): " choice
        
        case $choice in
            1) disable_system_updates ;;
            2) restore_system_updates ;;
            3) check_system_status ;;
            4) show_version_info ;;
            5) graceful_exit ;;
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
    echo "提示: 重启电脑使设置完全生效"
    
    system_action_menu
}

function restore_system_updates() {
    echo "正在恢复系统更新功能..."
    echo "------------------------------------------------------------"
    
    # 执行恢复操作
    execute_restore_actions
    
    echo "------------------------------------------------------------"
    echo -e "${COLOR_GREEN}系统更新功能已成功恢复${COLOR_NC}"
    echo "提示: 重启电脑使设置完全生效"
    
    # 立即刷新系统服务以确保状态更新
    refresh_system_services
    
    system_action_menu
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
    
    # 增强通知系统处理 - 彻底解决小红点问题
    echo "清除系统通知标记..."
    defaults write com.apple.systempreferences AttentionPrefBundleIDs 0
    killall Dock
    sudo killall usernoted >/dev/null 2>&1
    
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
function create_hosts_backup() {
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="/etc/hosts.bak_$timestamp"
    sudo cp /etc/hosts "$backup_file"
    echo "已创建Hosts备份: ${backup_file##*/}"
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
    {
        echo -e "\n# 更新屏蔽规则"
        for domain in "${DEFAULT_DOMAIN_LIST[@]}"; do
            echo "127.0.0.1 $domain"
        done
    } | sudo tee -a /etc/hosts >/dev/null
    sudo chmod 644 /etc/hosts
}

function remove_hosts_block() {
    # 安全地移除屏蔽规则
    if grep -q "# 更新屏蔽规则" /etc/hosts; then
        echo "正在移除Hosts屏蔽规则..."
        local lines_to_delete=$(( ${#DEFAULT_DOMAIN_LIST[@]} + 1 ))
        sudo sed -i '' "/# 更新屏蔽规则/,+${lines_to_delete}d" /etc/hosts
        sudo chmod 644 /etc/hosts
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

# -------------------------- 菜单系统 --------------------------
function system_action_menu() {
    while true; do
        echo ""
        echo "请选择操作:"
        echo "1. 立即重启电脑"
        echo "2. 关机"
        echo "3. 返回主菜单"
        echo ""
        
        read -p "请输入选项 (1-3): " action_choice
        
        case $action_choice in
            1) 
                echo "正在重启电脑..."
                sudo shutdown -r now
                ;;
            2) 
                echo "正在关机..."
                sudo shutdown -h now
                ;;
            3) 
                echo "返回主菜单..."
                return
                ;;
            *) 
                echo -e "${COLOR_RED}无效选项，请重新输入${COLOR_NC}"
                ;;
        esac
        
        echo "------------------------------------------------------------"
    done
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
    echo "3. 检查更新状态"
    echo "4. 显示版本信息"
    echo "5. 退出"
    echo ""
}

function check_system_status() {
    echo "系统更新状态检查:"
    echo "------------------------------------------------------------"
    
    # 检查更新计划状态
    local schedule_status=$(softwareupdate --schedule 2>&1)
    if [[ $schedule_status == *"off"* ]]; then
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
    local service_status=$(sudo launchctl list | grep com.apple.softwareupdated)
    if [[ -z "$service_status" ]]; then
        echo -e "软件更新服务状态: ${COLOR_RED}未运行${COLOR_NC}"
    else
        echo -e "软件更新服务状态: ${COLOR_GREEN}运行中${COLOR_NC}"
    fi
    
    echo "------------------------------------------------------------"
    echo "提示: 打开 系统设置 > 通用 > 软件更新 验证实际状态"
}

function show_version_info() {
    echo "------------------------------------------------------------"
    echo "MacUpdateGuard v${SCRIPT_VERSION}"
    echo "作者: bili_25396444320"
    echo "最后更新: 2025年7月17日"
    echo "------------------------------------------------------------"
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

# ======================== 脚本启动入口 ========================
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