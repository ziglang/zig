# REQUIRES: mips
# Having an R_MIPS_64 relocation in eh_frame would previously crash LLD
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-freebsd %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck %s -check-prefix OBJ
# RUN: ld.lld --eh-frame-hdr -shared -z notext -o %t.so %t.o
# RUN: llvm-readobj -r %t.so | FileCheck %s -check-prefix PIC-RELOCS

# Linking this as a PIE executable would also previously crash
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-freebsd %S/Inputs/archive2.s -o %t-foo.o
# -pie needs -z notext because of the R_MIPS_64 relocation
# RUN: ld.lld --eh-frame-hdr -Bdynamic -pie -z notext -o %t-pie-dynamic.exe %t.o %t-foo.o
# RUN: llvm-readobj -r %t-pie-dynamic.exe | FileCheck %s -check-prefix PIC-RELOCS


# OBJ:       Section ({{.*}}) .rela.text {
# OBJ-NEXT:    0x0 R_MIPS_GPREL16/R_MIPS_SUB/R_MIPS_HI16 foo 0x0
# OBJ-NEXT:  }
# OBJ-NEXT:  Section ({{.*}}) .rela.eh_frame {
# OBJ-NEXT:    0x1C R_MIPS_64/R_MIPS_NONE/R_MIPS_NONE .text 0x0
# OBJ-NEXT:  }

# PIC-RELOCS: Relocations [
# PIC-RELOCS-NEXT:  Section (7) .rel.dyn {
# PIC-RELOCS-NEXT:    {{0x.+}} R_MIPS_REL32/R_MIPS_64/R_MIPS_NONE - 0x0
# PIC-RELOCS-NEXT:  }
# PIC-RELOCS-NEXT:]


.globl foo

bar:
.cfi_startproc
lui	$11, %hi(%neg(%gp_rel(foo)))
.cfi_endproc

.globl __start
__start:
b bar
