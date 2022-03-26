const Small = enum (u2) {
    One,
    Two,
    Three,
    Four,
    Five,
};

export fn entry() void {
    var x = Small.One;
    _ = x;
}

// specify enum tag type that is too small
//
// tmp.zig:6:5: error: enumeration value 4 too large for type 'u2'
