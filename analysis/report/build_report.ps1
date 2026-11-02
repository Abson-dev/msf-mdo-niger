# Build the Word results report from the model outputs (Windows, needs Microsoft Word for the final layout).
#   1. conda run -n mdo-models Rscript analysis/run_models.R      (if the models have not been run)
#   2. powershell -File analysis/report/build_report.ps1          (from the project root)
# Uses the conda environments mdo-models (R) and doc-tools (pandoc).
$ErrorActionPreference = "Stop"
$conda = "$env:LOCALAPPDATA\miniforge3\Scripts\conda.exe"
$root = (Get-Location).Path
$out = Join-Path $root "analysis\report\MDO_Niger_model_results.docx"
$pdf = Join-Path $root "analysis\report\MDO_Niger_model_results.pdf"

& $conda run -n mdo-models --no-capture-output Rscript analysis/report/build_report.R
Push-Location analysis\report
& $conda run -n doc-tools pandoc results_report.md -o $out --toc --toc-depth=2 --number-sections --resource-path=.
Pop-Location
& (Join-Path $root "analysis\report\word_finish.ps1") -Docx $out -Pdf $pdf `
    -Footer "Niger MDO surveillance: model results" -FirstHeading "Summary"
"Report: $out"
