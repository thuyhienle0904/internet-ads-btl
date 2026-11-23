# Run from any directory. Does not run R or modify analysis scripts.
param([ValidateSet('thesis','preview')][string]$Target = 'thesis')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    foreach ($tool in @('pdflatex','bibtex')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            throw "Missing $tool. Install MiKTeX and reopen PowerShell."
        }
    }
    & pdflatex -interaction=nonstopmode -halt-on-error "$Target.tex"
    if ($LASTEXITCODE -ne 0) { throw "PDFLaTeX failed: see $Target.log" }
    $aux = Get-Content "$Target.aux" -Raw
    if ($aux -match '\\bibdata\{') {
        & bibtex $Target
        if ($LASTEXITCODE -ne 0) { throw "BibTeX failed: see $Target.blg" }
    }
    1..2 | ForEach-Object {
        & pdflatex -interaction=nonstopmode -halt-on-error "$Target.tex"
        if ($LASTEXITCODE -ne 0) { throw "PDFLaTeX failed: see $Target.log" }
    }
    $log = Get-Content "$Target.log" -Raw
    if ($log -match 'There were undefined (references|citations)|Citation .+ undefined|Reference .+ undefined') {
        throw "Unresolved citations/references: see $Target.log"
    }
    Write-Host "Built: $PSScriptRoot/$Target.pdf"
} finally { Pop-Location }
