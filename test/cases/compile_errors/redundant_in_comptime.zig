comptime {
    _ = @inComptime();
}

// error
//
// :2:9: error: redundant '@inComptime' in comptime scope
