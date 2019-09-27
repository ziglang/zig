# REQUIRES: x86

# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t.obj %s
# RUN: not lld-link /out:%t.exe /entry:main -notarealopt=ion /WX %t.obj 2>&1 | \
# RUN:   FileCheck -check-prefix=ERROR %s
# RUN: not lld-link /out:%t.exe /entry:main -notarealopt=ion /WX:NO /WX %t.obj 2>&1 | \
# RUN:   FileCheck -check-prefix=ERROR %s
# RUN: lld-link /out:%t.exe /entry:main -notarealopt=ion /WX /WX:NO %t.obj 2>&1 | \
# RUN:   FileCheck -check-prefix=WARNING %s

# ERROR: error: ignoring unknown argument '-notarealopt=ion'
# WARNING: warning: ignoring unknown argument '-notarealopt=ion'

.text
.global main
main:
	ret
