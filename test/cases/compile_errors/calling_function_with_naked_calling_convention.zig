export fn entry() void {
    foo();
}
fn foo() callconv(.Naked) void {}

// error
// backend=llvm
// target=native
//
// :2:5: error: unable to call function with naked calling convention
// :4:1: note: function declared here
