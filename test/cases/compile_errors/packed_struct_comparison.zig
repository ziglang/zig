const x: Foo = .{};
const y: Foo = .{};

export fn a() void {
    _ = x > y;
}

export fn b() void {
    _ = x < y;
}

export fn c() void {
    _ = x >= y;
}
export fn d() void {
    _ = x <= y;
}

const Foo = packed struct {
    a: u4 = 10,
    b: u4 = 5,
};

// error
// backend=stage2
// target=native
//
// :5:11: error: operator > not allowed for type 'tmp.Foo'
// :19:20: note: struct declared here
// :9:11: error: operator < not allowed for type 'tmp.Foo'
// :19:20: note: struct declared here
// :13:11: error: operator >= not allowed for type 'tmp.Foo'
// :19:20: note: struct declared here
// :16:11: error: operator <= not allowed for type 'tmp.Foo'
// :19:20: note: struct declared here
