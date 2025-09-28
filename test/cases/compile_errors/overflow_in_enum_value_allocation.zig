const Moo = enum(u8) {
    Last = 255,
    Over,
};
pub export fn entry() void {
    const y = Moo.Last;
    _ = y;
}

// error
//
// :3:5: error: enumeration value '256' too large for type 'u8'
