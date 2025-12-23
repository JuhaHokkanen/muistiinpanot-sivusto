# Määritä repositorion polku
$repoPath = "C:\DnD-muistiinpanot\muistiinpanot-sivusto"

# Siirry repositorioon
Set-Location -Path $repoPath

# Lue manuaalinen järjestys (notes/order.json), jos on olemassa
$orderFile = Join-Path "$repoPath\notes" "order.json"
$manualOrder = @()
if (Test-Path $orderFile) {
    try {
        $manualOrder = Get-Content $orderFile -Raw | ConvertFrom-Json
        if (-not ($manualOrder -is [System.Collections.IEnumerable])) { $manualOrder = @() }
    } catch {
        Write-Warning "order.json ei kelpaa JSONiksi. Ohitetaan manuaalinen järjestys."
        $manualOrder = @()
    }
}

# Luodaan indeksi taulukosta: tiedostonimi -> järjestysindeksi
$indexMap = @{}
for ($i = 0; $i -lt $manualOrder.Count; $i++) {
    $name = $manualOrder[$i]
    if (-not $indexMap.ContainsKey($name)) {
        $indexMap[$name] = $i
    }
}

# Haetaan kaikki muistiinpanot
$allNotes = Get-ChildItem -Path "$repoPath\notes" -Filter "*.md"

# Lajitellaan niin, että:
# 1) ensin order.jsonissa olevat siinä järjestyksessä
# 2) loput vanhimmasta uusimpaan
$notes = $allNotes |
    Sort-Object `
        @{ Expression = { if ($indexMap.ContainsKey($_.Name)) { $indexMap[$_.Name] } else { [int]::MaxValue } } }, `
        @{ Expression = { $_.LastWriteTime } } |
    ForEach-Object {
        @{
            title        = $_.BaseName
            file         = $_.Name
            lastModified = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            position     = if ($indexMap.ContainsKey($_.Name)) { $indexMap[$_.Name] } else { $null }
        }
    }

# Pakotetaan aina taulukoksi
$notesArray = @()
if ($notes) {
    $notesArray = @($notes)
}

# Päivitä list.json
$notesArray | ConvertTo-Json -Depth 10 | Out-File "$repoPath\notes\list.json" -Encoding utf8

# Kopioi staattiset tiedostot ja kansioiden sisältö docs-kansioon

# Määritä docs-kansion polku ja luo kansio, jos sitä ei vielä ole
$docsFolder = "$repoPath\docs"
if (-not (Test-Path -Path $docsFolder)) {
    New-Item -Path $docsFolder -ItemType Directory | Out-Null
    Write-Host "Luotiin docs-kansio: $docsFolder"
}

# Kopioi index.html, note.html ja style.css docs-kansioon
Copy-Item -Path "$repoPath\index.html" -Destination $docsFolder -Force
Copy-Item -Path "$repoPath\note.html" -Destination $docsFolder -Force
Copy-Item -Path "$repoPath\style.css" -Destination $docsFolder -Force
Write-Host "Kopioitu tiedostot: index.html, note.html ja style.css docs-kansioon."

# Kopioi notes-kansion sisältö docs/notes -kansioon
$docsNotesFolder = "$docsFolder\notes"
if (-not (Test-Path -Path $docsNotesFolder)) {
    New-Item -Path $docsNotesFolder -ItemType Directory | Out-Null
    Write-Host "Luotiin docs/notes -kansio: $docsNotesFolder"
}
Copy-Item -Path "$repoPath\notes\*" -Destination $docsNotesFolder -Recurse -Force
Write-Host "Kopioitu notes-kansion sisältö docs/notes -kansioon."

# Kopioi uudet ja päivitetyt kuvat docs/images -kansioon, mutta älä poista vanhoja
$docsImagesFolder = "$docsFolder\images"
if (-not (Test-Path -Path $docsImagesFolder)) {
    New-Item -Path $docsImagesFolder -ItemType Directory | Out-Null
    Write-Host "Luotiin docs/images -kansio: $docsImagesFolder"
}

# Kopioidaan vain olemassa olevat kuvatiedostot ilman tyhjennyksiä
Get-ChildItem -Path "$repoPath\images" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $docsImagesFolder -Force
}
Write-Host "Kopioitu kuvat images-kansiosta docs/images -kansioon."

# Lisää kaikki uudet tiedostot ja kansiot
git add .

# Tee commit ja push
$currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
git commit -m "Update complete $currentDateTime" 2>$null
git push origin main

# Odota hetki, jotta GitHub Pages ehtii päivityksen
Write-Host "Odota 60 sekuntia päivityksen valmistumiseksi..."
Start-Sleep -Seconds 60

# Avaa GitHub Pages -sivu
$webPageUrl = "https://juhahokkanen.github.io/muistiinpanot-sivusto/"
Start-Process $webPageUrl
