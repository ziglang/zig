# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %T/MixedCase.obj %s
# RUN: not lld-link /entry:main %T/MixedCase.obj 2>&1 | FileCheck -check-prefix=OBJECT %s

# RUN: llvm-lib /out:%T/MixedCase.lib %T/MixedCase.obj
# RUN: not lld-link /machine:x64 /entry:main %T/MixedCase.lib 2>&1 | FileCheck -check-prefix=ARCHIVE %s

# OBJECT: MixedCase.obj: undefined symbol: f
# ARCHIVE: MixedCase.lib(MixedCase.obj): undefined symbol: f

.globl main
main:
	callq	f
