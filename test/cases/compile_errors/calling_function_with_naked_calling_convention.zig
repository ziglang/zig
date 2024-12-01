export fn entry() void {
    foo();
}
fn foo() callconv(.naked) void {}

// error
// backend=llvm
// target=native
//
// :2:5: error: unable to call function with calling convention 'naked'
// :4:1: note: function declared here
