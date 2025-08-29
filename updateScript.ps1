# 步骤 1: 获取当前日期并构建提交信息
try {
    $today = Get-Date -Format "yyyy-MM-dd"
    $commitMessage = "update: $today"
    Write-Host "准备提交，提交信息为: '$commitMessage'"
} catch {
    Write-Host "错误：获取日期失败。请检查系统设置。" -ForegroundColor Red
    exit 1
}

# 步骤 2: git add
Write-Host "----------------------------------------"
Write-Host "正在执行 'git add .'..."
git add .

# 检查 'git add' 是否成功
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误：'git add .' 执行失败！" -ForegroundColor Red
    Write-Host "请检查以下可能的原因："
    Write-Host "1. 当前目录是否是一个有效的 Git 仓库？"
    Write-Host "2. 是否有文件权限问题？"
    Write-Host "运行 'git status' 查看详细状态。"
    exit 1 # 退出脚本
}
Write-Host "'git add' 成功。"

# 步骤 3: git commit
Write-Host "----------------------------------------"
Write-Host "正在执行 'git commit'..."
git commit -m "$commitMessage"

# 检查 'git commit' 是否成功
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误：'git commit' 执行失败！" -ForegroundColor Red
    Write-Host "请检查以下可能的原因："
    Write-Host "1. 是否已经配置了 user.name 和 user.email？ (使用 'git config --global user.name ...' 配置)"
    Write-Host "2. 是否没有需要提交的更改？（如果是这个问题，可以忽略此'错误'）"
    Write-Host "3. 是否存在合并冲突？"
    exit 1 # 退出脚本
}
Write-Host "'git commit' 成功。"

# 步骤 4: git push
Write-Host "----------------------------------------"
Write-Host "正在执行 'git push origin main'..."
git push origin main

# 检查 'git push' 是否成功
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误：'git push' 执行失败！" -ForegroundColor Red
    Write-Host "请检查以下可能的原因："
    Write-Host "1. 网络连接是否正常？能否访问 GitHub？"
    Write-Host "2. 远程仓库地址 (origin) 是否配置正确？"
    Write-Host "3. 是否有权限推送到远程仓库？(检查 SSH key 或 Personal Access Token 设置)"
    Write-Host "4. 远程仓库是否有新的提交？尝试先执行 'git pull' 同步远程更改。"
    exit 1 # 退出脚本
}
Write-Host "'git push' 成功。"

# 所有步骤成功
Write-Host "----------------------------------------"
Write-Host "🎉 脚本执行完毕！笔记已成功提交并推送到 GitHub！" -ForegroundColor Green