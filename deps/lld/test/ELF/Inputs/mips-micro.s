  .text
  .set micromips
  .global foo
  .type foo,@function
foo:
  nop

  .set nomicromips
  .global bar
  .type bar,@function
bar:
  nop
