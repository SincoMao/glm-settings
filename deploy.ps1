#Requires -Version 5.1
<#
deploy.ps1 — Claude Code 配置一键部署（由同目录 d-*.bat 调用，也可直接运行）

行为：
  1. 从 -KeyEnvName 指定的环境变量读取 API Key（先查当前进程，再查用户级注册表，
     因此 setx 设置完无需重开终端即可生效）；
  2. 将本目录 settings.json 中的 ANTHROPIC_AUTH_TOKEN 回填为真实密钥，经 JSON
     校验后写出（UTF-8 无 BOM），覆盖前自动备份现有配置；
  3. 按 -AgentAction 同步 vision 子代理：
       deploy = 部署本目录 agents\vision.md 到 <claude>\agents\vision.md
       remove = 备份并删除 <claude>\agents\vision.md（flash 架构无视觉子代理，残留即错误路由）
       none   = 跳过
  4. 打印端点 / 模型 / 密钥掩码摘要。部署目标：%CLAUDE_CONFIG_DIR%（若已设置），否则 %USERPROFILE%\.claude
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$KeyEnvName,
    [Parameter(Mandatory = $true)][string]$ProfileLabel,
    [Parameter(Mandatory = $true)][ValidateSet('deploy', 'remove', 'none')][string]$AgentAction
)

$ErrorActionPreference = 'Stop'

# ---- 1. 取 API Key：进程环境变量 → 用户级（注册表 HKCU\Environment） ----
$apiKey = [Environment]::GetEnvironmentVariable($KeyEnvName, 'Process')
if (-not $apiKey) { $apiKey = [Environment]::GetEnvironmentVariable($KeyEnvName, 'User') }
$apiKey = ("$apiKey").Trim()
if (-not $apiKey) {
    Write-Host "[错误] 未找到环境变量 $KeyEnvName（当前进程与用户级注册表均未设置）。" -ForegroundColor Red
    Write-Host "       请先设置为用户环境变量后重试，例如：" -ForegroundColor Yellow
    Write-Host "         setx $KeyEnvName `"sk-你的密钥`"" -ForegroundColor Yellow
    Write-Host "       （setx 直接写入用户级注册表，本脚本从注册表读取，设置完无需重开终端。）" -ForegroundColor Yellow
    exit 1
}
if ($apiKey -match '\s') {
    Write-Host "[错误] $KeyEnvName 的值含有空白字符，请检查是否复制了多余的引号或空格。" -ForegroundColor Red
    exit 1
}

# ---- 2. 定位源文件与部署目标 ----
$srcSettings = Join-Path $PSScriptRoot 'settings.json'
$claudeDir   = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$targetSettings = Join-Path $claudeDir 'settings.json'
$agentsDir  = Join-Path $claudeDir 'agents'
$targetVision  = Join-Path $agentsDir 'vision.md'
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')

if (-not (Test-Path $srcSettings)) {
    Write-Host "[错误] 找不到源配置：$srcSettings" -ForegroundColor Red
    exit 1
}

# ---- 3. 读取源配置并回填密钥（正则替换整值，不依赖占位符文本） ----
$text = [IO.File]::ReadAllText($srcSettings)
$pattern = '("ANTHROPIC_AUTH_TOKEN"\s*:\s*")[^"]*(")'
if (-not [regex]::IsMatch($text, $pattern)) {
    Write-Host "[错误] $srcSettings 中未找到 ANTHROPIC_AUTH_TOKEN 字段，无法回填密钥。" -ForegroundColor Red
    exit 1
}
$text = [regex]::Replace($text, $pattern, { param($m) $m.Groups[1].Value + $apiKey + $m.Groups[2].Value })

# ---- 4. 写出前校验：JSON 可解析、占位符已清除 ----
try { $json = $text | ConvertFrom-Json }
catch {
    Write-Host "[错误] 回填后的 settings.json 不是合法 JSON：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
if ("$($json.env.ANTHROPIC_AUTH_TOKEN)" -match 'REPLACE_WITH') {
    Write-Host "[错误] 密钥回填未生效（仍为占位符），已中止写出。" -ForegroundColor Red
    exit 1
}

# ---- 5. 备份现有配置后写出（UTF-8 无 BOM） ----
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }
if (Test-Path $targetSettings) {
    $bak = "$targetSettings.bak-$stamp"
    Copy-Item $targetSettings $bak -Force
    Write-Host "已备份原配置 -> $bak"
}
[IO.File]::WriteAllText($targetSettings, $text, [Text.UTF8Encoding]::new($false))
Write-Host "已部署 settings.json -> $targetSettings"

# ---- 6. vision 子代理同步 ----
switch ($AgentAction) {
    'deploy' {
        $srcVision = Join-Path $PSScriptRoot 'agents\vision.md'
        if (Test-Path $srcVision) {
            if (-not (Test-Path $agentsDir)) { New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null }
            Copy-Item $srcVision $targetVision -Force
            Write-Host "已部署 vision 子代理 -> $targetVision"
        }
        else {
            Write-Host "[警告] 未找到 $srcVision，已跳过 vision 子代理部署。" -ForegroundColor Yellow
        }
    }
    'remove' {
        if (Test-Path $targetVision) {
            Copy-Item $targetVision "$targetVision.bak-$stamp" -Force
            Remove-Item $targetVision -Force
            Write-Host "已按 flash 架构移除 vision 子代理（残留即错误路由，原文件已备份）-> $targetVision"
        }
        else {
            Write-Host "vision 子代理不存在，无需清理。"
        }
    }
    default { }
}

# ---- 7. 摘要 ----
$masked = if ($apiKey.Length -gt 12) { $apiKey.Substring(0, 6) + '...' + $apiKey.Substring($apiKey.Length - 4) } else { '******' }
Write-Host ""
Write-Host "===== 部署完成：$ProfileLabel =====" -ForegroundColor Green
Write-Host ("  API 端点    : {0}" -f $json.env.ANTHROPIC_BASE_URL)
Write-Host ("  Opus/Sonnet : {0}" -f $json.env.ANTHROPIC_DEFAULT_OPUS_MODEL)
Write-Host ("  Haiku       : {0}" -f $json.env.ANTHROPIC_DEFAULT_HAIKU_MODEL)
Write-Host ("  密钥        : {0}（来自 {1}）" -f $masked, $KeyEnvName)
Write-Host ""
Write-Host "已运行的会话不会热加载 settings.json，请新开 Claude Code 会话生效。" -ForegroundColor Cyan
exit 0
