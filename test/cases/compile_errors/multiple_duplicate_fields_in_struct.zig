const S = struct {
    a: u64,
    b: u64,
    a: u64,
    a: u64,
};

export fn entry() void {
    _ = S;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: duplicate struct field: 'a'
// :4:5: note: other field here
// :5:5: note: other field here
// :1:11: note: struct declared here
