const assert = @import("std").debug.assert;

test "@ptrCast from const to nullable" {
    const c: u8 = 4;
    var x: ?*const u8 = @ptrCast(?*const u8, &c);
    assert(x.?.* == 4);
}

test "@ptrCast from var in empty struct to nullable" {
    const container = struct.{
        var c: u8 = 4;
    };
    var x: ?*const u8 = @ptrCast(?*const u8, &container.c);
    assert(x.?.* == 4);
}
