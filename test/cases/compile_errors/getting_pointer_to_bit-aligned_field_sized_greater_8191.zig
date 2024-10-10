const Foo = packed struct {
    _pad: u65535 = undefined,
    bit: u1,
};

pub fn main() void {
    const foo = Foo{ .bit = 0 };
    _ = @as(*align(@alignOf(Foo):65535:8192) const u1, &foo.bit);
}

// error
// target=native
// backend=stage2
//
// :1:20: error: size of packed struct '65536' exceeds maximum bit width of 65535
