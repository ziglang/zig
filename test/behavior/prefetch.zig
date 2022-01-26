test "@prefetch()" {
    var a: u32 = 42;

    @prefetch(&a, .{});

    @prefetch(&a, .{ .rw = .read, .locality = 3, .cache = .data });
    @prefetch(&a, .{ .rw = .read, .locality = 2, .cache = .data });
    @prefetch(&a, .{ .rw = .read, .locality = 1, .cache = .data });
    @prefetch(&a, .{ .rw = .read, .locality = 0, .cache = .data });

    @prefetch(&a, .{ .rw = .write, .locality = 3, .cache = .data });
    @prefetch(&a, .{ .rw = .write, .locality = 2, .cache = .data });
    @prefetch(&a, .{ .rw = .write, .locality = 1, .cache = .data });
    @prefetch(&a, .{ .rw = .write, .locality = 0, .cache = .data });

    @prefetch(&a, .{ .rw = .read, .locality = 3, .cache = .instruction });
    @prefetch(&a, .{ .rw = .read, .locality = 2, .cache = .instruction });
    @prefetch(&a, .{ .rw = .read, .locality = 1, .cache = .instruction });
    @prefetch(&a, .{ .rw = .read, .locality = 0, .cache = .instruction });

    @prefetch(&a, .{ .rw = .write, .locality = 3, .cache = .instruction });
    @prefetch(&a, .{ .rw = .write, .locality = 2, .cache = .instruction });
    @prefetch(&a, .{ .rw = .write, .locality = 1, .cache = .instruction });
    @prefetch(&a, .{ .rw = .write, .locality = 0, .cache = .instruction });
}
