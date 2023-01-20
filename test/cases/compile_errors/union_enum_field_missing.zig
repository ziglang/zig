const E = enum {
    a,
    b,
    c,
};

const U = union(E) {
    a: i32,
    b: f64,
};

export fn entry() usize {
    return @sizeOf(U);
}

// error
// target=native
//
// :7:11: error: enum field(s) missing in union
// :4:5: note: field 'c' missing, declared here
// :1:11: note: enum declared here
