.section        ".opd","aw"
.global bar
bar:
.quad   .Lbar,.TOC.@tocbase,0
.quad   .Lbar,0,0

.text
.Lbar:
        blr
