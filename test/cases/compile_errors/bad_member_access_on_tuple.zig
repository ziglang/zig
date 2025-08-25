comptime {
    _ = @TypeOf(.{}).is_optional;
}

// error
// backend=stage2
// target=native
//
// :2:21: error: struct '@TypeOf(.{})' has no member named 'is_optional'
