const Foo = packed union(u32) {
    x: u32,
    y: u8,
};

const Bar = packed union(u6) {
    x: u9,
    y: u64,
    z: u6,
};

export fn a(_: Foo) void {}
export fn b(_: Bar) void {}

// error
// backend=stage2
// target=native
//
// :1:26: error: all fields must have a bit size of 32
// :3:8: note: field with bit size 8 here
// :6:26: error: all fields must have a bit size of 6
// :7:8: note: field with bit size 9 here
// :8:8: note: field with bit size 64 here
