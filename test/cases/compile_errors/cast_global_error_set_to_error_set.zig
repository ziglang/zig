const SmallErrorSet = error{A};
export fn entry() void {
    const x: SmallErrorSet = foo();
    _ = x;
}
fn foo() anyerror {
    return error.B;
}

// error
// backend=stage2
// target=native
//
// :3:33: error: expected type 'error{A}', found 'anyerror'
// :3:33: note: global error set cannot cast into a smaller set
