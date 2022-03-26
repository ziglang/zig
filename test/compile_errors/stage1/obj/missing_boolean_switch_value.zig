comptime {
    const x = switch (true) {
        true => false,
    };
    _ = x;
}
comptime {
    const x = switch (true) {
        false => true,
    };
    _ = x;
}

// missing boolean switch value
//
// tmp.zig:2:15: error: switch must handle all possibilities
// tmp.zig:8:15: error: switch must handle all possibilities
