const std = @import("std");
const Allocator = std.mem.Allocator;

const Foo = struct { data: *u32 };

fn getData() !u32 {
    return 666;
}

fn genFoos(allocator: Allocator, num: usize) ![]Foo {
    const foos = try allocator.alloc(Foo, num);
    errdefer allocator.free(foos);

    for (foos, 0..) |*foo, i| {
        foo.data = try allocator.create(u32);
        // This errdefer does not last between iterations
        errdefer allocator.destroy(foo.data);

        // The data for the first 3 foos will be leaked
        if (i >= 3) return error.TooManyFoos;

        foo.data.* = try getData();
    }

    return foos;
}

test "genFoos" {
    try std.testing.expectError(error.TooManyFoos, genFoos(std.testing.allocator, 5));
}

// test_error=3 errors were logged
