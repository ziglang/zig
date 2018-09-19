    .text
    .abiversion 2
    .globl  foo_not_shared
    .p2align        4
    .type   foo_not_shared,@function

foo_not_shared:
.Lfunc_begin0:
  li 3, 55
  blr
  .long   0
  .quad   0
.Lfunc_end0:
  .size foo_not_shared, .Lfunc_end0-.Lfunc_begin0
