param([string]$Docx, [string]$Pdf, [string]$Footer = "Niger MDO surveillance: econometric methodology",
      [string]$FirstHeading = "Purpose and summary")
# Finish a pandoc-made .docx in Word: table styling, page numbers, page break after the contents,
# updated table of contents; save and export a PDF.
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$navy = 0x553C0B   # BGR for #0B3C55
try {
    $doc = $word.Documents.Open($Docx, $false, $false)

    # margins 2.2 cm
    $cm = 28.3465
    foreach ($s in $doc.Sections) {
        $s.PageSetup.TopMargin = 2.2 * $cm; $s.PageSetup.BottomMargin = 2.2 * $cm
        $s.PageSetup.LeftMargin = 2.2 * $cm; $s.PageSetup.RightMargin = 2.2 * $cm
    }

    # tables: full width, header row shaded and repeated, light row rules, compact text
    foreach ($t in $doc.Tables) {
        $t.AllowAutoFit = $true
        $t.Range.Font.Size = 9.5
        $t.AutoFitBehavior(1)          # wdAutoFitContent: columns sized to their content
        $t.AutoFitBehavior(2)          # wdAutoFitWindow: then stretched to the page width
        $t.Range.ParagraphFormat.SpaceBefore = 2
        $t.Range.ParagraphFormat.SpaceAfter = 2
        $t.Borders.Enable = $false
        foreach ($r in $t.Rows) {
            $b = $r.Borders.Item(-3)   # wdBorderBottom
            $b.LineStyle = 1; $b.LineWidth = 4; $b.Color = 0xD9D9D9
        }
        $h = $t.Rows.Item(1)
        $h.HeadingFormat = -1
        $h.Range.Font.Bold = $true
        $h.Range.Font.Color = 0xFFFFFF
        $h.Shading.BackgroundPatternColor = $navy
        $t.Rows.AllowBreakAcrossPages = 0
        # keep short tables, and every table's caption, on the same page as the table
        if ($t.Rows.Count -le 20) {
            for ($k = 1; $k -lt $t.Rows.Count; $k++) { $t.Rows.Item($k).Range.ParagraphFormat.KeepWithNext = -1 }
        }
        $cap = $t.Range.Previous(4, 1)          # wdParagraph: the paragraph just before the table
        if ($cap) { $cap.ParagraphFormat.KeepWithNext = -1 }
        $t.TopPadding = 2; $t.BottomPadding = 2; $t.LeftPadding = 5; $t.RightPadding = 5
    }

    # footer: "Page X of Y", centred, small grey
    $sec = $doc.Sections.Item(1)
    $f = $sec.Footers.Item(1).Range
    $f.Text = ""
    $f.Font.Size = 9; $f.Font.Color = 0x7F7F7F
    $f.ParagraphFormat.Alignment = 1
    $f.InsertAfter("$Footer  |  Page ")
    $f.Collapse(0); $f.Fields.Add($f, 33) | Out-Null          # wdFieldPage
    $f = $sec.Footers.Item(1).Range; $f.Collapse(0); $f.InsertAfter(" of ")
    $f = $sec.Footers.Item(1).Range; $f.Collapse(0); $f.Fields.Add($f, 26) | Out-Null   # wdFieldNumPages

    # page break before the first numbered heading (after the contents)
    foreach ($p in $doc.Paragraphs) {
        if ($p.OutlineLevel -eq 1 -and $p.Range.Text -match [regex]::Escape($FirstHeading)) {
            $r = $p.Range; $r.Collapse(1)        # collapse to the start, so the heading is kept
            $r.InsertBreak(7) | Out-Null         # wdPageBreak
            break
        }
    }

    foreach ($toc in $doc.TablesOfContents) { $toc.Update() }
    $doc.Fields.Update() | Out-Null
    $doc.Save()
    "Saved $Docx"
    # the PDF is a convenience copy; it fails if the file is open elsewhere (viewer, OneDrive lock)
    try { $doc.ExportAsFixedFormat($Pdf, 17); "PDF: $Pdf" } catch { "PDF not written (file open elsewhere?): $Pdf" }
    try { $doc.Close(0) } catch { }   # Word sometimes drops the automation connection after the export
} finally {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}
