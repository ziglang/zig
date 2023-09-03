const NextError = error{NextError};
const OtherError = error{OutOfMemory};

export fn entry() void {
    const a: ?NextError!i32 = foo();
    _ = a;
}

fn foo() ?OtherError!i32 {
    return null;
}

// error
// backend=llvm
// target=native
//
// :5:34: error: expected type '?error{NextError}!i32', found '?error{OutOfMemory}!i32'
// :5:34: note: optional type child 'error{OutOfMemory}!i32' cannot cast into optional type child 'error{NextError}!i32'
// :5:34: note: 'error.OutOfMemory' not a member of destination error set
