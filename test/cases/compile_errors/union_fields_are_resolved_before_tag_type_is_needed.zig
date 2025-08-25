const T = union(enum) {
    a,
    pub fn f(self: T) void {
        _ = self;
    }
};
pub export fn entry() void {
    T.a.f();
}

// error
// backend=stage2
// target=native
//
// :8:8: error: no field or member function named 'f' in '@typeInfo(tmp.T).@"union".tag_type.?'
// :1:11: note: enum declared here
