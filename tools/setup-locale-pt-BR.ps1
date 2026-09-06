# Copia SWF e imagens de ui/vietnam para ui/pt-BR (o Git não versiona essa duplicata).
# Rodar na raiz do repo, no PC Windows, antes de ligar <LANGUAGE value="pt-BR"/>.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'Source Flash\FlashSV1\ui\vietnam'
$dst = Join-Path $root 'Source Flash\FlashSV1\ui\pt-BR'
if (-not (Test-Path (Join-Path $src 'swf'))) {
    throw "Pasta origem nao encontrada: $src\swf"
}
New-Item -ItemType Directory -Force -Path $dst | Out-Null
foreach ($name in @('swf', 'img')) {
    $from = Join-Path $src $name
    $to = Join-Path $dst $name
    if (Test-Path $to) {
        Write-Host "Ja existe: $to"
        continue
    }
    Write-Host "Copiando $name ..."
    Copy-Item -Recurse -LiteralPath $from -Destination $to
}
Write-Host "Pronto. language.txt e xml/ ja vem do Git em ui\pt-BR\."
