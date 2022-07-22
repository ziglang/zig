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
// backend=stage2
// target=native
//
// :6:17: error: enum field(s) missing in union
// :4:5: note: field 'C' missing, declared here
// :1:16: note: enum declared here
