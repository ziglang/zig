const resolutions = [*][*]const u8{
    "[320 240  ]",
    null,
};
comptime {
    _ = resolutions;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:21: error: expected array type or [_], found '[*][*]const u8'
