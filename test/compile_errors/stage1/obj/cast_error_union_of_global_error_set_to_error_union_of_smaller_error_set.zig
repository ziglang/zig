const SmallErrorSet = error{A};
export fn entry() void {
    var x: SmallErrorSet!i32 = foo();
    _ = x;
}
fn foo() anyerror!i32 {
    return error.B;
}

// cast error union of global error set to error union of smaller error set
//
// tmp.zig:3:35: error: expected type 'SmallErrorSet!i32', found 'anyerror!i32'
// tmp.zig:3:35: note: error set 'anyerror' cannot cast into error set 'SmallErrorSet'
// tmp.zig:3:35: note: cannot cast global error set into smaller set
