fn foo(a: usize) void {
    struct {
        const a = 1;
    };
}
fn bar(a: usize) void {
    struct {
        const b = struct {
            const a = 1;
        };
    };
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :3:15: error: redeclaration of function parameter 'a'
// :1:8: note: previous declaration here
// :9:19: error: redeclaration of function parameter 'a'
// :6:8: note: previous declaration here
