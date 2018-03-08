.global foo
.weak __wrap_foo
.protected __wrap_foo
.global __real_foo
foo = 0x11000
__wrap_foo = 0x11010
__real_foo = 0x11020
