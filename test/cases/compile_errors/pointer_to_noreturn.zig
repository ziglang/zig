fn a() *noreturn {}
export fn entry() void {
    _ = a();
}

// error
//
// :1:9: error: pointer to noreturn not allowed
