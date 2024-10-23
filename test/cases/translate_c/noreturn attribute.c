void foo(void) __attribute__((noreturn));

// translate-c
// c_frontend=aro,clang
//
// pub extern fn foo() noreturn;
