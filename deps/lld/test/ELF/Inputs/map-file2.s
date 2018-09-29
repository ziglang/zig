foo:
.cfi_startproc
nop
.cfi_endproc
.global bar
bar:
nop
.section .text.zed,"ax",@progbits
.global zed
zed:
