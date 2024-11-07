pub export fn main(argc: c_int, argv: [*:null]?[*:0]c_char, envp: [*:null]?[*:0]c_char) c_int {
    _ = envp;
    return @intFromBool(argv[@intCast(argc)] != null);
}

// run
