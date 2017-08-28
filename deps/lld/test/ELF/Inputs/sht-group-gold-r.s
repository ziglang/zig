# sht-group-gold-r.elf is produced by
#
#   llvm-mc -filetype=obj -triple=x86_64-pc-linux sht-group-gold-r.s -o sht-group-gold-r.o
#   ld.gold -o sht-group-gold-r.elf -r sht-group-gold-r.o

.global foo, bar

.section .text.foo,"aG",@progbits,group_foo,comdat
foo:
  nop

.section .text.bar,"aG",@progbits,group_bar,comdat
bar:
  nop
