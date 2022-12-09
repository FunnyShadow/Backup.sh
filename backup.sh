#!/bin/bash

#### Auto Backup Script
#### Version 1.6.1
#### Made By BlueFunny_

### ShellCheck ###
# shellcheck disable=SC2010
# shellcheck source=/dev/null

### 脚本使用变量 ###
timestamp=$(date +%s)
version="1.6.1"

### 工具 ###
## 错误处理
Error() {
    LEcho "$1" "$2"
    exit 1
}

## Debug 输出
Debug() {
    if [ "${debug:=false}" == "true" ]; then
        LEcho "$1" "$2"
    fi
}

## 本地化信息输出
LEcho() {
    if [ "${localize:=en_us}" == "zh_cn" ]; then
        printf "%s\n" "$1"
    else
        printf "%s\n" "$2"
    fi
}

### 初始化 ###
## 读入配置信息
# shellcheck source=/dev/null
GetConfig() {
    if [ "$1" == "" ]; then
        LEcho "[x] 未提供配置文件" "[x] No config file provided"
        Error "[!] 使用方法: $0 <配置文件>" "[!] Usage: $0 <config file>"
    fi
    if [ ! -f "$1" ]; then
        LEcho "[x] 提供的配置文件不存在" "[x] Config file not found"
        Error "[!] 使用方法: $0 <配置文件>" "[!] Usage: $0 <config file>"
    fi
    if ! source "$1"; then
        Error "[x] 无法读取配置文件 [$1] " "[x] Unable to read config file [$1]"
    fi
    if [ "${configVersion:=}" != "" ]; then
        if [ ${version} != "${configVersion}" ]; then
            LEcho "[x] 配置文件版本不匹配" "[x] Config file version mismatch"
            LEcho "[!] 当前版本: ${version}" "[!] Current version: ${version}"
            Error "[!] 配置文件版本: ${configVersion}" "[!] Config file version: ${configVersion}"
        fi
    else
        Error "[x] 配置文件有误: 未找到配置文件版本" "[x] Config file error: Config file version not found"
    fi
    if [ "${enabled:=false}" != "true" ]; then
        LEcho "[-] 未启用自动备份" "[-] Auto backup is not enabled"
        exit 0
    fi
    if [ "${userName:=nobody}" != "" ]; then
        if [ "${allowRoot:=false}" != "true" ] && [ "${userName}" == "root" ]; then
            LEcho "[x] 请不要将备份文件所有者指定为 root 用户, 否则可能将导致您的备份文件无法被非 root 用户操作" "[x] Please do not specify the owner of the backup file as the root user, otherwise it may cause your backup file to be unable to be operated by non-root users"
            Error "[!] 如您执意要使用 root 用户, 请在配置文件中将 allowRoot 修改为 true" "[!] If you insist on using the root user, please change allowRoot to true in the configuration file"
        elif [ "${allowRoot:=false}" == "true" ]; then
            LEcho "[!] 强制 root 模式已开启, 已允许备份文件所有者为 root, 请注意安全" "[!] allow root mode is enabled, root is allowed to be the owner of the backup file, please pay attention to security"
        fi
    fi
    if [ "${backupList:?}" == "" ]; then
        LEcho "[-] 未指定备份文件列表, 跳过备份" "[-] No backup file list specified, skip backup" 
        exit 0
    else
        GetBackupFiles
    fi
}

## 读入配置文件中的备份列表
GetBackupFiles() {
    if ! source "${backupList}"; then
        Error "[x] 无法读取备份列表文件 [${backupList}] " "[x] Unable to read backup list file [${backupList}]"
    fi
    if [ "${backupListVersion:=}" != "" ]; then
        if [ ${version} != "${backupListVersion}" ]; then
            LEcho "[x] 备份列表文件版本不匹配" "[x] Backup list file version mismatch"
            LEcho "[!] 当前版本: ${version}" "[!] Current version: ${version}"
            Error "[!] 备份列表文件版本: ${backupListVersion}" "[!] Backup list file version: ${backupListVersion}"
        fi
    else
        Error "[x] 备份列表文件有误: 未找到备份列表文件版本" "[x] Backup list file error: Backup list file version not found"
    fi
}

## 检测是否可以跳过备份
IsSkipBackup() {
    if [ "${skipBackup:=false}" == "true" ]; then
        if [ "${debug}" == "false" ]; then
            LEcho "[x] 未启用 DEBUG 模式时启用跳过备份! 拒绝启动!" "[x] Skip backup is enabled when DEBUG mode is not enabled! Refused to start!"
            Error "[!] 请启用 DEBUG 模式, 或关闭跳过备份!" "[!] Please enable DEBUG mode, or disable skip backup!"
        fi
    fi
}

## 环境校验
Verify() {
    LEcho "[-] 验证基础环境中....." "[-] Verifying basic environment....."
    Debug "[D] 当前位置: $(pwd)" "[D] Current location: $(pwd)"
    Debug "[D] 当前执行脚本用户: $(whoami)" "[D] Current executing script user: $(whoami)"
    # 检测用户
    if [ "$(whoami)" != "root" ]; then
        LEcho "[!] 当前执行脚本用户非特权用户, 可能无法操作部分文件" "[!] The current executing script user is not a privileged user, and may not be able to operate some files"
        if [ "$(whoami)" != "www" ]; then
            Error "[x] 错误, 当前执行脚本用户无权限操作关键文件, 无法继续执行备份任务" "[x] Error, the current executing script user has no permission to operate critical files, and cannot continue to execute backup tasks"
        fi
    fi
    # 检测备份存储文件夹及工作区状态
    if [ -d "${backupDir:=/usr/local/share/autobackup/}" ]; then
        Debug "[D] 已检测到备份存储文件夹,跳过补全" "[D] Backup storage folder detected, skipping completion"
    else
        LEcho "[x] 未检测到备份存储目录文件夹,可能是第一次备份/初始化,正在自动创建中" "[x] Backup storage folder not detected, may be the first backup / initialization, creating automatically"
        mkdir -p "${backupDir}" && Debug "[D] 已创建备份存储文件夹" "[D] Backup storage folder created"
        chown -R "${userName}" "${backupDir}"
    fi
    if [ -d "${workDir:=/usr/local/share/autobackup/work}" ]; then
        LEcho "[!] 检测到已存在上一次运行所留下的残留文件,正在清理中" "[!] Detected residual files left over from the last run, cleaning up"
        Cleaner "full"
    else
        LEcho "[D] 未检测到工作文件夹,跳过清理" "[D] Work folder not detected, skipping cleanup"
    fi
    LEcho "[-] 创建新的工作文件夹中....."
    mkdir -p "${workDir}" && Debug "[D] 已创建工作文件夹" "[D] Work folder created"
    chown -R "${userName}" "${workDir}"
    # 检测当前位置
    if [ "$(pwd)" != "${backupDir}" ]; then
        LEcho "[!] 当前位置错误,正在自动移动中" "[!] Current location is wrong, moving automatically"
        cd "${backupDir}" && Debug "[D] 已经移动至: $(pwd)" "[D] Moved to: $(pwd)"
    fi
    # 检测剩余槽位数量
    Debug "[D] 当前位置: $(pwd)" "[D] Current location: $(pwd)"
    Debug "[D] 当前槽位数量: ${solt:=5}" "[D] Current slot number: ${solt:=5}"
    Debug "[D] 当前备份文件数量: $(ls -l | grep -c "^-")" "[D] Current backup file number: $(ls -l | grep -c "^-")"
    if [ "$(ls -l | grep -c "^-")" -eq "${solt}" ]; then
        Cleaner "backup"
    else
        if [ "$(ls -l | grep -c "^-")" -gt "${solt}" ]; then
            Cleaner "backup"
        else
            solts=$(("${solt}" - "$(ls -l | grep -c "^-")"))
            LEcho "[-] 剩余槽位数量: ${solts}" "[-] Remaining slot number: ${solts}"
        fi
    fi
    LEcho "[√] 基础环境验证完毕,进行下一步操作" "[√] Basic environment verification completed, proceed to the next step"
    cd "${workDir}" || Error "[x] 错误, 无法进入工作文件夹, 请检查权限" "[x] Error, unable to enter the work folder, please check the permission"
}

### 主程序 ###
## 输出版权与配置信息
Copyright() {
    clear
    LEcho "[A] 通用全自动本地备份脚本 Made By BlueFunny_" "[A] General automatic local backup script Made By BlueFunny_"
    LEcho "[A] 当前版本:v${version}" "[A] Current version:v${version}"
    LEcho "[A] 建议搭配Rclone/Rsync,体验更佳!" "[A] It is recommended to use Rclone/Rsync for better experience!"
    LEcho "=====================================" "====================================="
    Debug "[D] 配置信息如下" "[D] Configuration information as follows"
    Debug "[D] Debug模式: 已启用" "[D] Debug mode: enabled"
    Debug "[D] 语言: ${localize}" "[D] Language: ${localize}"
    Debug "[D] 备份文件所有者: ${userName}" "[D] Backup file owner: ${userName}"
    Debug "[D] 强制 root 模式: ${allowRoot}" "[D] Allow root mode: ${allowRoot}"
    Debug "[D] 跳过备份: ${skipBackup}" "[D] Skip backup: ${skipBackup}"
    Debug "[D] 备份槽位数量: ${solt}" "[D] Backup slot number: ${solt}"
    Debug "[D] 备份存储文件夹目录: ${backupDir}" "[D] Backup storage folder directory: ${backupDir}"
    Debug "[D] 工作区文件夹目录: ${workDir}" "[D] Work area folder directory: ${workDir}"
}

## 主函数
Main() {
    if [ "${skipBackup}" == "false" ]; then
        LEcho "[-] 复制文件中....." "[-] Copying files....."
        Backup
        LEcho "[-] 打包中....." "[-] Packing....."
        Packer
        LEcho "[√] 成功备份" "[√] Backup successfully"
        LEcho "[-] 备份文件路径:$(pwd)/${fileName:=${timestamp}.tar.gz}" "[-] Backup file path:$(pwd)/${fileName:=${timestamp}.tar.gz}"
    else
        Debug "[D] 备份已跳过" "[D] Backup skipped"
    fi
    LEcho "[-] 清理残留运行文件中" "[-] Cleaning up residual running files"
    Cleaner "full"
    LEcho "[√] 所有任务执行完毕,等待服务器进行自动同步任务" "[√] All tasks completed, waiting for the server to perform automatic synchronization tasks"
    exit 0
}

## 文件复制
Backup() {
    if cp -r "${backupFiles[@]:?}" ./; then
        LEcho "[√] 已经成功复制所有文件" "[√] All files have been successfully copied"
    else
        Error "[x] 复制文件失败,请检查权限" "[x] Failed to copy files, please check the permission"
    fi
    return
}

## 打包
Packer() {
    #if [ "${genDigest:=false}" == "true" ]; then
    #    LEcho "[-] 生成文件摘要中..." "[-] Generating file digest..."
    #    if ! sha256sum "${backupFiles[*]:?}/*" >"${workDir}/all.sha256"; then
    #        Error "[x] 生成文件摘要失败,请检查权限" "[x] Failed to generate file digest, please check the permission"
    #    fi
    #    LEcho "[√] 文件摘要生成成功" "[√] File digest generated successfully"
    #fi
    cd ${backupDir} || Error "[x] 错误, 无法进入工作文件夹, 请检查权限" "[x] Error, unable to enter the work folder, please check the permission"
    Debug "[D] 当前位置: $(pwd)" "[D] Current location: $(pwd)"
    if [ -d "$(pwd)/${fileName}" ]; then
        LEcho "[!] 检测到已存在相同文件名,正在强制删除中..." "[!] A file with the same name already exists, deleting it forcibly..."
        rm -rf ./"${fileName}" && Debug "[D] 已成功删除同文件名文件" "[D] The same file name file has been successfully deleted"
    fi
    if ! tar -czvf "${fileName}" "./work"; then
        Error "[x] 打包失败" "[x] Packing failed"
    else
        LEcho "[√] 打包成功" "[√] Packing succeeded"
    fi
    chmod 777 "${fileName}"
    chown "${userName}" "${fileName}"
    chgrp "${userName}" "${fileName}"
    return
}

## 清理
Cleaner() {
    if [ "$1" == "full" ]; then
        cd "${backupDir}" || Error "[x] 错误, 无法进入备份文件夹, 请检查权限" "[x] Error, unable to enter the backup folder, please check the permission"
        rm -rf "${workDir}" && Debug "[D] 已删除工作文件夹" "[D] Work folder deleted"
        LEcho "[√] 清理完毕" "[√] Cleaned up"
    elif [ "$1" == "backup" ]; then
        LEcho "[!] 检测到已经达到最大备份数量,正在自动清理中....." "[!] The maximum number of backups has been reached, cleaning up automatically....."
        cd ..
        Debug "[D] 当前位置: $(pwd)" "[D] Current location: $(pwd)"
        rm -rf "${backupDir}" && Debug "[D] 已成功删除备份存储文件夹" "[D] Backup storage folder deleted successfully"
        mkdir -p "${backupDir}" && Debug "[D] 已成功创建备份存储文件夹" "[D] Backup storage folder created successfully"
        chown -R "${userName}" "${backupDir}"
        mkdir -p "${workDir}" && Debug "[D] 已创建工作文件夹" "[D] Work folder created"
        chown -R "${userName}" "${workDir}"
        LEcho "[√] 清理完毕"
        cd "${workDir}" || Error "[x] 错误, 无法进入工作文件夹, 请检查权限" "[x] Error, unable to enter the work folder, please check the permission"
        Debug "[D] 当前位置: $(pwd)" "[D] Current location: $(pwd)"
    else
        Error "[x] 未知错误, 请联系脚本作者" "[x] Unknown error, please contact the script author"
    fi
    return
}

### 外部函数 ###
## 运行备份前脚本
PreBackup() {
    if [ "${preBackup:=""}" != "" ]; then
        if [ -f "${preBackup}" ]; then
            LEcho "[-] 正在运行备份前脚本" "[-] Running pre-backup script"
            if ! bash "${preBackup}"; then
                LEcho "[!] 备份前脚本运行报错" "[!] Pre-backup script error"
            fi
        else
            LEcho "[!] 备份前脚本不存在, 跳过运行" "[!] Pre-backup script does not exist, skip running"
        fi
    fi
}

## 运行备份后脚本
PostBackup() {
    if [ "${postBackup:=""}" != "" ]; then
        if [ -f "${postBackup}" ]; then
            LEcho "[-] 正在运行备份后脚本" "[-] Running post-backup script"
            if ! bash "${postBackup}"; then
                LEcho "[!] 备份后脚本运行报错" "[!] Post-backup script error"
            fi
        else
            LEcho "[!] 备份后脚本不存在, 跳过运行" "[!] Post-backup script does not exist, skip running"
        fi
    fi
}

### 启动 ###
##开始运行
Copyright
GetConfig "$1"
PreBackup
IsSkipBackup
Verify
Main
PostBackup
exit 0
