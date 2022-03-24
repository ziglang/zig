const Letter = extern union {
    A,
};
export fn entry() void {
    var a = Letter { .A = {} };
    _ = a;
}

// extern union field missing type
//
// tmp.zig:2:5: error: union field missing type
