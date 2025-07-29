comptime {
    _ = enum(i0) { a, _ };
}

comptime {
    _ = enum(u0) { a, _ };
}

comptime {
    _ = enum(u0) { a, b, _ };
}

// error
//
// :2:9: error: non-exhaustive enum specifies every value
// :6:9: error: non-exhaustive enum specifies every value
// :10:23: error: enumeration value '1' too large for type 'u0'
