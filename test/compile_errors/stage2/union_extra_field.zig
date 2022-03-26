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

// union extra field
//
// :6:1: error: enum 'tmp.E' hs no field named 'd'
// :1:11: note: enum declared here
