export fn entry() void {
    _ = async foo();
}
fn foo() void {
    suspend {
        suspend {}
    }
}

// error
// backend=stage2
// target=native
//
// :6:9: error: cannot suspend inside suspend block
// :5:5: note: other suspend block here
