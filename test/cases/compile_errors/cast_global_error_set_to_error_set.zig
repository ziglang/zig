const SmallErrorSet = error{A};
export fn entry() void {
    var x: SmallErrorSet = foo();
    _ = x;
}
fn foo() anyerror {
    return error.B;
}

// error
// backend=stage2
// target=native
//
// :3:31: error: expected type 'error{A}', found 'anyerror'
// :3:31: note: global error set cannot cast into a smaller set
