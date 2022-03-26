const Letter = struct {
    A,
};
export fn entry() void {
    var a = Letter { .A = {} };
    _ = a;
}

// struct field missing type
//
// tmp.zig:2:5: error: struct field missing type
