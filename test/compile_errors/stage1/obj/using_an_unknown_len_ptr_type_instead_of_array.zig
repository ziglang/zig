const resolutions = [*][*]const u8{
    "[320 240  ]",
    null,
};
comptime {
    _ = resolutions;
}

// using an unknown len ptr type instead of array
//
// tmp.zig:1:21: error: expected array type or [_], found '[*][*]const u8'
