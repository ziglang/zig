# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %t.main.obj %s

# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %t.lib.obj \
# RUN:     %S/Inputs/mangled-symbol.s
# RUN: lld-link /lib /out:%t.lib %t.lib.obj
# RUN: lld-link /lib /llvmlibthin /out:%t_thin.lib %t.lib.obj

# RUN: lld-link /entry:main %t.main.obj %t.lib /out:%t.exe 2>&1 | \
# RUN:     FileCheck --allow-empty %s
# RUN: lld-link /entry:main %t.main.obj %t_thin.lib /out:%t.exe 2>&1 | \
# RUN:     FileCheck --allow-empty %s
# RUN: lld-link /entry:main %t.main.obj /wholearchive:%t_thin.lib /out:%t.exe 2>&1 | \
# RUN:     FileCheck --allow-empty %s

# RUN: rm %t.lib.obj
# RUN: lld-link /entry:main %t.main.obj %t.lib /out:%t.exe 2>&1 | \
# RUN:     FileCheck --allow-empty %s

# CHECK-NOT: error: could not get the buffer for the member defining

	.text

	.def main
		.scl 2
		.type 32
	.endef
	.global main
main:
	call "?f@@YAHXZ"
	retq $0
