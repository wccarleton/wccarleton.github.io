$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ReferenceDoc = Join-Path $Root "assets/cv_onepage_word_template.docx"
$Target = if ($args.Count -gt 0) { $args[0] } else { "all" }

Set-Location $Root

function Invoke-NormalizeDocx {
    param([string]$DocxPath)

    $Script = "tools/normalize-cv-docx-styles.py"

    if (Get-Command python -ErrorAction SilentlyContinue) {
        python $Script $DocxPath
    } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        python3 $Script $DocxPath
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        py $Script $DocxPath
    } else {
        Write-Error "Python is required to normalize DOCX styles after Quarto renders."
        exit 1
    }
}

function Render-OnePage {
    quarto render about.qmd `
        --to docx `
        --reference-doc $ReferenceDoc `
        --output cv-onepage.docx `
        --shift-heading-level-by -1
    Invoke-NormalizeDocx "_site/cv-onepage.docx"
}

function Render-Full {
    quarto render cv.qmd `
        --to docx `
        --reference-doc $ReferenceDoc `
        --output cv-full.docx `
        --shift-heading-level-by -1
    Invoke-NormalizeDocx "_site/cv-full.docx"
}

switch ($Target) {
    "onepage" { Render-OnePage }
    "full" { Render-Full }
    "all" {
        Render-OnePage
        Render-Full
    }
    default {
        Write-Error "Usage: tools/render-cv-docx.ps1 [onepage|full|all]"
        exit 2
    }
}
