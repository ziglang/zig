const Letter = enum {
    A,
    B,
    C,
};
const Payload = union(Letter) {
    A: i32,
    B: f64,
};
export fn entry() usize {
    return @sizeOf(Payload);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:17: error: enum field missing: 'C'
// tmp.zig:4:5: note: declared here
