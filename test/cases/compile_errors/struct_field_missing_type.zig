const Letter = struct {
    A,
};
export fn entry() void {
    var a = Letter { .A = {} };
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: struct field missing type
