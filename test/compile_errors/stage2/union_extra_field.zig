const E = enum {
    a,
    b,
    c,
};
const U = union(E) {
    a: i32,
    b: f64,
    c: f64,
    d: f64,
};
export fn entry() usize {
    return @sizeOf(U);
}

// error
//
// :6:1: error: enum 'tmp.E' has no field named 'd'
// :1:11: note: enum declared here
