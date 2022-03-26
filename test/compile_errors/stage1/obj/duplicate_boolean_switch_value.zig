comptime {
    const x = switch (true) {
        true => false,
        false => true,
        true => false,
    };
    _ = x;
}
comptime {
    const x = switch (true) {
        false => true,
        true => false,
        false => true,
    };
    _ = x;
}

// duplicate boolean switch value
//
// tmp.zig:5:9: error: duplicate switch value
// tmp.zig:13:9: error: duplicate switch value
