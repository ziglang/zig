fn a() *noreturn {}
export fn entry() void {
    _ = a();
}

// error
// backend=stage2
// target=native
//
// :1:9: error: pointer to noreturn not allowed
