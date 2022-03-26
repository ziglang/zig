fn Undeclared() type {
    return T;
}
fn Gen() type {
    const X = Undeclared();
    return struct {
        x: X,
    };
}
export fn entry() void {
    const S = Gen();
    _ = S;
}

// variable initialization compile error then referenced
//
// tmp.zig:2:12: error: use of undeclared identifier 'T'
