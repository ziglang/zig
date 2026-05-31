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

// error
//
// :2:15: error: switch must handle all possibilities
// :8:15: error: switch must handle all possibilities
