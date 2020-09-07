const std = @import("std");

fn simple(_: c_int, ...) callconv(.C) c_int {
    var ap = @vaStart();
    defer @vaEnd(&ap);
    return @vaArg(&ap, c_int);
}

fn add(count: c_int, ...) callconv(.C) c_int {
    var ap = @vaStart();
    defer @vaEnd(&ap);
    var i: usize = 0;
    var sum: c_int = 0;
    while (i < count) : (i += 1) {
        sum += @vaArg(&ap, c_int);
    }
    return sum;
}

fn printf(list_ptr: *c_void, format: [*:0]const u8, ...) callconv(.C) void {
    var ap = @vaStart();
    defer @vaEnd(&ap);
    const list = @ptrCast(
        *std.ArrayList(u8),
        @alignCast(@alignOf(*std.ArrayList(u8)), list_ptr),
    );
    for (std.mem.span(format)) |c| switch (c) {
        's' => {
            const arg = @vaArg(&ap, [*:0]const u8);
            list.writer().print("{}", .{arg}) catch return;
        },
        'd' => {
            const arg = @vaArg(&ap, c_int);
            list.writer().print("{}", .{arg}) catch return;
        },
        else => unreachable,
    };
}

test "variadic functions" {
    std.testing.expectEqual(@as(c_int, 0), simple(0, @as(c_int, 0)));
    std.testing.expectEqual(@as(c_int, 1024), simple(0, @as(c_int, 1024)));
    std.testing.expectEqual(@as(c_int, 0), add(0));
    std.testing.expectEqual(@as(c_int, 1), add(1, @as(c_int, 1)));
    std.testing.expectEqual(@as(c_int, 3), add(2, @as(c_int, 1), @as(c_int, 2)));

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    printf(&list, "dsd", @as(c_int, 1), @as([*:0]const u8, "hello"), @as(c_int, 5));
    std.testing.expectEqualStrings("1hello5", list.items);
}
