const expect = @import("std").testing.expect;

test "sentinel-terminated 0-length slices" {
    var u32s: [4]u32 = [_]u32{0, 1, 2, 3};

    var index: u8 = 2;
    var slice = u32s[index..index:2];
    var array_ptr = u32s[2..2:2];
    const comptime_known_array_value = u32s[2..2:2].*;
    var runtime_array_value = u32s[2..2:2].*;

    expect(slice[0] == 2);
    expect(array_ptr[0] == 2);
    expect(comptime_known_array_value[0] == 2);
    expect(runtime_array_value[0] == 2); //fails
}
