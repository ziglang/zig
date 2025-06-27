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
// :3:5: error: no field named 'one' in enum 'tmp.E'
// :1:11: note: enum declared here
