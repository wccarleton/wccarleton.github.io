$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$FullCv = Join-Path $Root "cv.qmd"
$OnePage = Join-Path $Root "about.qmd"

# Future one-page CV condensation rules:
# - Treat cv.qmd as the canonical source of truth.
# - Keep the one-page CV focused on outputs, awards, and service; omit teaching unless a funder asks for it.
# - Collapse expertise to an inline keyword list rather than a full bullet section.
# - Shorten education to completion dates, degree names, and universities only.
# - In selected publications, strip author lists to the first author and W.C. Carleton, keeping Carleton bolded.
# - Prefer 5-6 recent/high-signal publications so the page stays close to one printed page.
# - Include current editorial board roles, including Discover Cities.

Write-Error "This prototype generator is intentionally disabled. Port the rules above into the production Python/Quarto pipeline before regenerating about.qmd."
exit 1

$Lines = Get-Content -Encoding UTF8 $FullCv

function Get-Section {
    param(
        [string[]]$InputLines,
        [string]$Heading,
        [int]$StopLevel = 2
    )

    $start = -1
    for ($i = 0; $i -lt $InputLines.Count; $i++) {
        if ($InputLines[$i].Trim() -eq $Heading) {
            $start = $i + 1
            break
        }
    }
    if ($start -lt 0) { return @() }

    $stopPrefix = ("#" * $StopLevel) + " "
    $out = New-Object System.Collections.Generic.List[string]
    for ($i = $start; $i -lt $InputLines.Count; $i++) {
        if ($InputLines[$i].StartsWith($stopPrefix)) { break }
        $out.Add($InputLines[$i])
    }
    return $out.ToArray()
}

function Get-Bullets {
    param([string[]]$InputLines)
    return @($InputLines | Where-Object { $_.StartsWith("- ") })
}

function First-BulletContaining {
    param(
        [string[]]$InputLines,
        [string]$Needle
    )
    return @(Get-Bullets $InputLines | Where-Object { $_ -like "*$Needle*" } | Select-Object -First 1)
}

$contact = New-Object System.Collections.Generic.List[string]
$inFrontMatter = $false
foreach ($line in $Lines) {
    if ($line.Trim() -eq "---") {
        $inFrontMatter = -not $inFrontMatter
        continue
    }
    if ($inFrontMatter) { continue }
    if ($line.StartsWith("## Profile") -or $line.StartsWith("## Highlights")) { break }
    $contact.Add($line)
}

$highlights = Get-Section $Lines "## Highlights" 2
$publicationRecord = First-BulletContaining (Get-Section $highlights "### Publication Record" 3) "peer-reviewed"
if (-not $publicationRecord) {
    $publicationRecord = "- Publication record maintained in the full CV."
}

$teaching = Get-Bullets (Get-Section $highlights "### Teaching" 3) | Select-Object -First 3
$funding = Get-Bullets (Get-Section $highlights "### Funding" 3) | Select-Object -First 1
$analytical = Get-Bullets (Get-Section $highlights "### Analytical Expertise" 3)
$programming = Get-Bullets (Get-Section $highlights "### Programming Languages" 3)
$education = Get-Bullets (Get-Section $Lines "## Education" 2) | Select-Object -First 2
$profile = @(Get-Section $Lines "## Profile" 2 | Where-Object { $_.Trim().Length -gt 0 })
if ($profile.Count -eq 0) {
    $profile = @("Archaeologist and data scientist developing quantitative, spatial, and computational approaches for long-term human-environment records.")
}

$publications = Get-Section $Lines "## Publications and Academic Contributions" 2
$articles = Get-Section $publications "### Peer-Reviewed Journal Articles" 3
$recentPubs = Get-Bullets $articles | Select-Object -First 5

$out = New-Object System.Collections.Generic.List[string]
$out.Add("---")
$out.Add('title: "Condensed CV"')
$out.Add("---")
$out.Add("")
$out.Add("<!-- This file is generated from cv.qmd by tools/build-cv.ps1. Edit cv.qmd, then run ``powershell -ExecutionPolicy Bypass -File tools/build-cv.ps1``. -->")
$out.Add("")
$contact | ForEach-Object { $out.Add($_) }
$out.Add("")
$out.Add("Full CV: [HTML](cv.qmd)  ")
$out.Add("Research: [ORCID](https://orcid.org/0000-0001-7463-8638) and [Google Scholar](https://scholar.google.ca/citations?user=0ZG-6CsAAAAJ&hl=en)")
$out.Add("")
$out.Add("## Profile")
$out.Add("")
$profile | ForEach-Object { $out.Add($_) }
$out.Add("")
$out.Add("## Highlights")
$out.Add("")
$out.Add($publicationRecord)
$teaching | ForEach-Object { $out.Add($_) }
$funding | ForEach-Object { $out.Add($_) }
$out.Add("")
$out.Add("## Expertise")
$out.Add("")
$analytical | ForEach-Object { $out.Add($_) }
$programming | ForEach-Object { $out.Add($_) }
$out.Add("")
$out.Add("## Education")
$out.Add("")
$education | ForEach-Object { $out.Add($_) }
$out.Add("")
$out.Add("## Selected Recent Publications")
$out.Add("")
$recentPubs | ForEach-Object { $out.Add($_) }
$out.Add("")
$out.Add("## Academic Service")
$out.Add("")
$out.Add("- 2023-present: Ombudsperson, Max Planck Institute of Geoanthropology")
$out.Add("- Editorial experience: Data in Brief; Journal of Archaeological Science: Reports")

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($OnePage, $out, $utf8NoBom)
