pub fn main(argc: c_int, argv: [*:null]?[*:0]u8) c_int {
    return @intFromBool(argv[@intCast(argc)] != null);
}

// run
