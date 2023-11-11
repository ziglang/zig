const Moo = enum(u8) {
    Last = 255,
    Over,
};
pub export fn entry() void {
    const y = Moo.Last;
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :3:5: error: enumeration value '256' too large for type 'u8'
