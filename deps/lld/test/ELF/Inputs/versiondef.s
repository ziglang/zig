.text
.globl func_impl
func_impl:
  ret
.globl func_impl2
func_impl2:
  ret
.symver func_impl, func@@VER2
.symver func_impl2, func@VER
