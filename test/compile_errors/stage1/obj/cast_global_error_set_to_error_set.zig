const SmallErrorSet = error{A};
export fn entry() void {
    var x: SmallErrorSet = foo();
    _ = x;
}
fn foo() anyerror {
    return error.B;
}

// cast global error set to error set
//
// tmp.zig:3:31: error: expected type 'SmallErrorSet', found 'anyerror'
// tmp.zig:3:31: note: cannot cast global error set into smaller set
