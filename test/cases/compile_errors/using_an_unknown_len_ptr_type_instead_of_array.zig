const resolutions = [*][*]const u8{
    "[320 240  ]",
    null,
};
comptime {
    _ = resolutions;
}

// error
// backend=stage2
// target=native
//
// :1:21: error: type '[*][*]const u8' does not support array initialization syntax
