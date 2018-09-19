.global _start
_start:
.global _Z1fi
_Z1fi:
.cfi_startproc
nop
.cfi_endproc

.section .aaa, "a";
.quad 1;

.section .bbb, "a";
.quad 2;

.section .ccc, "a";
.quad 3;

.section .ddd, "a";
.quad 4
