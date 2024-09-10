comptime {
    _ = enum(i0) { a, _ };
}
comptime {
    _ = enum(u0) { a, b, _ };
}

// error
//
// :2:9: error: non-exhaustive enum specifies every value
// :5:9: error: non-exhaustive enum specifies every value
