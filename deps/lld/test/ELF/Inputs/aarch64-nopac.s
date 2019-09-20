.text
.globl func2
.type func2,@function
func2:
  .globl func3
  .type func3, @function
  bl func3
  ret
