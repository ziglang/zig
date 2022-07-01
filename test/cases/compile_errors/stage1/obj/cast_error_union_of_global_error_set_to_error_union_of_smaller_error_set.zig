const SmallErrorSet = error{A};
export fn entry() void {
    var x: SmallErrorSet!i32 = foo();
    _ = x;
}
fn foo() anyerror!i32 {
    return error.B;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:35: error: expected type 'SmallErrorSet!i32', found 'anyerror!i32'
// tmp.zig:3:35: note: error set 'anyerror' cannot cast into error set 'SmallErrorSet'
// tmp.zig:3:35: note: cannot cast global error set into smaller set
