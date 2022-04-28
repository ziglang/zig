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
// backend=stage1
// target=native
//
// tmp.zig:5:34: error: expected type '?NextError!i32', found '?OtherError!i32'
// tmp.zig:5:34: note: optional type child 'OtherError!i32' cannot cast into optional type child 'NextError!i32'
// tmp.zig:5:34: note: error set 'OtherError' cannot cast into error set 'NextError'
// tmp.zig:2:26: note: 'error.OutOfMemory' not a member of destination error set
