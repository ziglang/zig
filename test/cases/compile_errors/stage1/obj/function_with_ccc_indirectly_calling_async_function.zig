export fn entry() void {
    foo();
}
fn foo() void {
    bar();
}
fn bar() void {
    suspend {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:1: error: function with calling convention 'C' cannot be async
// tmp.zig:2:8: note: async function call here
// tmp.zig:5:8: note: async function call here
// tmp.zig:8:5: note: suspends here
