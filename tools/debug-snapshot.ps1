$out = "E:\Arquivos\Projetos\DDTank41\logs\debug-snapshot.txt"
$lines = @()
$lines += "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
$lines += "--- ports ---"
$lines += (Get-NetTCPConnection -LocalPort 843,9500,9202,9208,9222 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort, OwningProcess | Format-Table -AutoSize | Out-String)
$lines += "--- ServerList ---"
try { $lines += (Invoke-WebRequest 'http://127.0.0.1/Request/ServerList.ashx' -UseBasicParsing -TimeoutSec 8).Content } catch { $lines += $_.Exception.Message }
$lines += "--- last-login.xml ---"
if (Test-Path "E:\Arquivos\Projetos\DDTank41\logs\last-login.xml") { $lines += Get-Content "E:\Arquivos\Projetos\DDTank41\logs\last-login.xml" -Raw } else { $lines += "(missing)" }
$lines += "--- last-select.xml ---"
if (Test-Path "E:\Arquivos\Projetos\DDTank41\logs\last-select.xml") { $lines += Get-Content "E:\Arquivos\Projetos\DDTank41\logs\last-select.xml" -Raw } else { $lines += "(missing)" }
$lines += "--- request-debug tail ---"
if (Test-Path "E:\Arquivos\Projetos\DDTank41\logs\request-debug.log") { $lines += Get-Content "E:\Arquivos\Projetos\DDTank41\logs\request-debug.log" -Tail 30 } else { $lines += "(missing)" }
$lines += "--- policy-843 tail ---"
if (Test-Path "E:\Arquivos\Projetos\DDTank41\logs\policy-843.log") { $lines += Get-Content "E:\Arquivos\Projetos\DDTank41\logs\policy-843.log" -Tail 20 } else { $lines += "(missing)" }
$flashLog = Join-Path $env:APPDATA "Macromedia\Flash Player\Logs\flashlog.txt"
$policyLog = Join-Path $env:APPDATA "Macromedia\Flash Player\Logs\policyfiles.txt"
$lines += "--- flashlog ---"
if (Test-Path $flashLog) { $lines += Get-Content $flashLog -Tail 40 } else { $lines += "(missing $flashLog)" }
$lines += "--- policyfiles ---"
if (Test-Path $policyLog) { $lines += Get-Content $policyLog -Tail 40 } else { $lines += "(missing $policyLog)" }
$lines += "--- Road Incoming last ---"
$road = "E:\Arquivos\Projetos\DDTank41\Road.Service\bin\Debug\net48\logs\GameServer.log"
if (Test-Path $road) { $lines += Select-String -Path $road -Pattern "Incoming|Disconnect|Login|Rsa|Kitoff|OverTime" | Select-Object -Last 20 | ForEach-Object { $_.Line } }
Set-Content -Path $out -Value $lines -Encoding UTF8
Write-Output $out
