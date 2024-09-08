// from #7724 - would crash the compiler with call to 'get_int_type(g, false, 65536)'

const Foo = packed struct {
    _pad: u65535 = undefined,
    bit: u1,
};
pub fn main() void {
    const foo = Foo{ .bit = 0 };
    const ptr: *align(@alignOf(Foo):65535:8192) const u1 = &foo.bit;
    _ = &ptr;
}

// error
// target=native
// backend=stage2
//
// error: size of packed struct '65536' exceeds maximum bit width of 65535
