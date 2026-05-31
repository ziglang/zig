comptime {
    _ = comptime 0;
}
comptime {
    comptime _, _ = .{ 0, 0 };
}

// error
//
// :2:9: error: redundant comptime keyword in already comptime scope
// :5:5: error: redundant comptime keyword in already comptime scope
