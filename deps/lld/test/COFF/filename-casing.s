# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %T/MixedCase.obj %s
# RUN: not lld-link /entry:main %T/MixedCase.obj 2>&1 | FileCheck -check-prefix=OBJECT %s

# RUN: llvm-lib /out:%T/MixedCase.lib %T/MixedCase.obj
# RUN: not lld-link /machine:x64 /entry:main %T/MixedCase.lib 2>&1 | FileCheck -check-prefix=ARCHIVE %s

# OBJECT: undefined symbol: f
# OBJECT-NEXT: >>> referenced by {{.*}}MixedCase.obj:(main)
# ARCHIVE: undefined symbol: f
# ARCHIVE-NEXT: >>> referenced by {{.*}}MixedCase.lib(MixedCase.obj):(main)

.globl main
main:
	callq	f
