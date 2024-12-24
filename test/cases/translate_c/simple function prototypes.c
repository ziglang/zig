void __attribute__((noreturn)) foo(void);
int bar(void);

// translate-c
// c_frontend=clang
//
// pub extern fn foo() noreturn;
// pub extern fn bar() c_int;
