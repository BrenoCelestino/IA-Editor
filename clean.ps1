param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

$targets = @(
    (Join-Path $ProjectRoot ".cache\trabalho")
)

# Também remove arquivos temporários soltos na raiz ou em .cache\*.tmp / *.log
$extraFiles = Get-ChildItem -Path $ProjectRoot -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Extension -in @(".tmp", ".log")
}

$removedCount = 0
$freedBytes = 0

foreach ($dir in $targets) {
    if (Test-Path $dir) {
        $size = (Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if (-not $size) { $size = 0 }
        $freedBytes += $size
        $removedCount++
        if ($DryRun) {
            Write-Host "[DryRun] Removeria pasta residual: $dir ($([math]::Round($size / 1MB, 2)) MB)"
        } else {
            Remove-Item -Path $dir -Recurse -Force
            Write-Host "[OK] Pasta residual removida: $dir ($([math]::Round($size / 1MB, 2)) MB)"
        }
    }
}

foreach ($f in $extraFiles) {
    $freedBytes += $f.Length
    $removedCount++
    if ($DryRun) {
        Write-Host "[DryRun] Removeria arquivo temporário: $($f.FullName)"
    } else {
        Remove-Item -Path $f.FullName -Force
        Write-Host "[OK] Arquivo temporário removido: $($f.FullName)"
    }
}

if ($removedCount -eq 0) {
    Write-Host "Nenhum arquivo residual encontrado. O projeto já está limpo!"
} else {
    $mb = [math]::Round($freedBytes / 1MB, 2)
    if ($DryRun) {
        Write-Host "Total que seria liberado: $mb MB (preservando .venv, node_modules, modelos em .cache, Video Bruto e Video Pronto)."
    } else {
        Write-Host "Limpeza concluída! Espaço liberado: $mb MB (preservados .venv, node_modules, modelos em .cache, Video Bruto e Video Pronto)."
    }
}
