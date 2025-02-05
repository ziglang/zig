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
// 6:10: error: no field or member function named 'b' in '*tmp.S'
// 6:10: note: method invocation only supports up to one level of implicit pointer dereferencing
// 6:10: note: use '.*' to dereference pointer
