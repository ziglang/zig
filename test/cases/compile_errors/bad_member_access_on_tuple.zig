comptime {
    _ = @TypeOf(.{}).is_optional;
}

// error
//
// :2:21: error: struct '@TypeOf(.{})' has no member named 'is_optional'
