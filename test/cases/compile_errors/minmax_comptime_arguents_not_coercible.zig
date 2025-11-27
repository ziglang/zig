// zig fmt: off
comptime { _ = @min(@as(f32, 1.0), u32_max); }
comptime { _ = @max(@as(f32, 1.0), u32_max); }
comptime { _ = @min(@as(f32, 1.0), 1234, u32_max, 0.1); }
comptime { _ = @max(@as(f32, 1.0), 1234, u32_max, 0.1); }
comptime {
    var f: f32 = 1.0;
    _ = &f;
    _ = @min(f, u32_max);
}
comptime {
    var f: f32 = 1.0;
    _ = &f;
    _ = @max(f, u32_max);
}

const u32_max: u32 = 4294967295;

// error
//
// :2:36: error: type 'f32' cannot represent integer value '4294967295'
// :3:36: error: type 'f32' cannot represent integer value '4294967295'
// :4:42: error: type 'f32' cannot represent integer value '4294967295'
// :5:42: error: type 'f32' cannot represent integer value '4294967295'
// :9:17: error: type 'f32' cannot represent integer value '4294967295'
// :14:17: error: type 'f32' cannot represent integer value '4294967295'
