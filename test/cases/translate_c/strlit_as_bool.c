void foo() { if(0 && "error message") {} }

// translate-c
// c_frontend=clang
//
// pub export fn foo() void {
//     if (false and (@intFromPtr("error message") != 0)) {}
// }
