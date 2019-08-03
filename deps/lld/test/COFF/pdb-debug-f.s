# REQUIRES: x86
# RUN: llvm-mc -triple=i386-pc-win32 -filetype=obj -o %t.obj %s
# RUN: lld-link -safeseh:no /subsystem:console /debug /nodefaultlib /entry:foo /out:%t.exe /pdb:%t.pdb %t.obj
# RUN: llvm-pdbutil dump -fpo %t.pdb | FileCheck %s

# CHECK:                         Old FPO Data
# CHECK-NEXT: ============================================================
# CHECK-NEXT:   RVA    | Code | Locals | Params | Prolog | Saved Regs | Use BP | Has SEH | Frame Type
# CHECK-NEXT: 00001002 |    1 |      2 |      3 |      4 |          0 |  false |   false |       FPO

.text
_foo:
ret

.global _foo

.section .debug$F,"dr"
	.long _foo@IMGREL+2
	.long 1 #  cbProc
	.long 2 # cdwLocals;
	.short 3 # cdwParams;
	.short 4 # flags
  # cbProlog : 8;
  # cbRegs : 3;
  # fHasSEH : 1;
  # fUseBP : 1;
  # reserved : 1;
  # cbFrame : 2;