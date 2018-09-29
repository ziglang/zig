.section .text.bar1,"aG",@progbits,group,comdat

.section .text.bar2
.global bar
bar:
 .quad .text.bar1
