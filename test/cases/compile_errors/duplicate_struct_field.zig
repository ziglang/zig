const Foo = struct {
    Bar: i32,
    Bar: usize,
};

const S = struct {
    a: u32,
    b: u32,
    a: u32,
    a: u64,
};

export fn a() void {
    const f: Foo = undefined;
    _ = f;
}

export fn b() void {
    const s: S = undefined;
    _ = s;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: duplicate struct field name
// :3:5: note: duplicate field here
// :1:13: note: struct declared here
// :7:5: error: duplicate struct field name
// :9:5: note: duplicate field here
// :10:5: note: duplicate field here
// :6:11: note: struct declared here
