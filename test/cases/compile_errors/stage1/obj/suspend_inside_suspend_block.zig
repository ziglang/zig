export fn entry() void {
    _ = async foo();
}
fn foo() void {
    suspend {
        suspend {
        }
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:9: error: cannot suspend inside suspend block
// tmp.zig:5:5: note: other suspend block here
