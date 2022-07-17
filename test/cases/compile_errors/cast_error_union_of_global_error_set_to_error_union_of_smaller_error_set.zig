const SmallErrorSet = error{A};
export fn entry() void {
    var x: SmallErrorSet!i32 = foo();
    _ = x;
}
fn foo() anyerror!i32 {
    return error.B;
}

// error
// backend=stage2
// target=native
//
// :3:35: error: expected type 'error{A}!i32', found 'anyerror!i32'
// :3:35: note: global error set cannot cast into a smaller set
