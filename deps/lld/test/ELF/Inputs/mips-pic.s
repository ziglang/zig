  .option pic2

  .section .text.1,"ax",@progbits
  .align 4
  .globl foo1a
  .type foo1a, @function
foo1a:
  nop
  .globl foo1b
  .type foo1b, @function
foo1b:
  nop

  .section .text.2,"ax",@progbits
  .align 4
  .globl foo2
  .type foo2, @function
foo2:
  nop
