# Sync preview/ PWA files into docs/ (GitHub Pages publishing folder)
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root "preview"
$dst  = Join-Path $root "docs"

New-Item -ItemType Directory -Force -Path $dst | Out-Null
if (Test-Path $dst) { Get-ChildItem $dst -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }

$files = @("index.html", "sw.js", "manifest.webmanifest", "icon-180.png", "icon-512.png")
foreach ($f in $files) {
  Copy-Item -Path (Join-Path $src $f) -Destination $dst -Force
}
Get-ChildItem $dst | ForEach-Object { "$($_.Name)  $($_.Length) bytes" }
Write-Output "Synced to docs/. Commit and push to update GitHub Pages."
