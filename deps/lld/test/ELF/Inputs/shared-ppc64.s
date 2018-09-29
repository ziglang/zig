    .text
    .abiversion 2
    .globl  foo
    .p2align        4
    .type   foo,@function

foo:
.Lfunc_begin0:
  li 3, 55
  blr
  .long   0
  .quad   0
.Lfunc_end0:
  .size foo, .Lfunc_end0-.Lfunc_begin0
