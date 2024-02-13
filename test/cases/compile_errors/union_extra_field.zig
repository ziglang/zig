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
// target=native
//
// :10:5: error: no field named 'd' in enum 'tmp.E'
// :1:11: note: enum declared here
