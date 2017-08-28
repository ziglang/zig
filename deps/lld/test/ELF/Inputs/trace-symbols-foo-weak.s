.comm	common,4,4
.text
.weak	foo
.type	foo, @function
foo:
callq bar@PLT

.globl  func1
.type   func1, @function
func1:
call func2@PLT

