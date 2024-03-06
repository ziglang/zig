const Small = enum(u2) {
    One,
    Two,
    Three,
    Four,
    Five,
};

export fn entry() void {
    _ = Small.One;
}

// error
// backend=stage2
// target=native
//
// :6:5: error: enumeration value '4' too large for type 'u2'
