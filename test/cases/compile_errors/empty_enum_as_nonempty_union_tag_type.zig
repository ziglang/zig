const E = enum {};
const U = union(E) {
    one,
    two,
};

pub fn main() void {
    _ = U.one;
}

// error
// backend=stage2
// target=native
//
// :4:5: error: no field named 'one' in enum 'tmp.E'
// :2:11: note: enum declared here
