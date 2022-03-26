const Small = enum(u2) {
    One,
    Two,
    Three,
    Four,
};

export fn entry() void {
    var y = @as(f32, 3);
    var x = @intToEnum(Small, y);
    _ = x;
}

// explicitly casting non tag type to enum
//
// tmp.zig:10:31: error: expected integer type, found 'f32'
