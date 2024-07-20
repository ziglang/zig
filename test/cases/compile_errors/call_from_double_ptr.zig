const S = struct {
    fn b() void {}
};

export fn entry(a: **S) void {
    _ = a.b();
}

// error
// backend=stage2
// target=native
//
// 6:10: error: type '*const **tmp.S' does not support member function invocation
// 6:10: note: consider dereferencing using '.*'
