const std = @import("std.zig");

pub const LeakCountAllocator = @import("testing/leak_count_allocator.zig").LeakCountAllocator;
pub const FailingAllocator = @import("testing/failing_allocator.zig").FailingAllocator;

/// This should only be used in temporary test programs.
pub const allocator = &allocator_instance.allocator;
pub var allocator_instance = LeakCountAllocator.init(&base_allocator_instance.allocator);

pub const failing_allocator = &FailingAllocator.init(&base_allocator_instance.allocator, 0).allocator;

pub var base_allocator_instance = std.heap.ThreadSafeFixedBufferAllocator.init(allocator_mem[0..]);
var allocator_mem: [1024 * 1024]u8 = undefined;

/// This function is intended to be used only in tests. It prints diagnostics to stderr
/// and then aborts when actual_error_union is not expected_error.
pub fn expectError(expected_error: anyerror, actual_error_union: var) void {
    if (actual_error_union) |actual_payload| {
        std.debug.panic("expected error.{}, found {}", .{ @errorName(expected_error), actual_payload });
    } else |actual_error| {
        if (expected_error != actual_error) {
            std.debug.panic("expected error.{}, found error.{}", .{
                @errorName(expected_error),
                @errorName(actual_error),
            });
        }
    }
}

/// This function is intended to be used only in tests. When the two values are not
/// equal, prints diagnostics to stderr to show exactly how they are not equal,
/// then aborts.
/// The types must match exactly.
pub fn expectEqual(expected: var, actual: @TypeOf(expected)) void {
    switch (@typeInfo(@TypeOf(actual))) {
        .NoReturn,
        .BoundFn,
        .Opaque,
        .Frame,
        .AnyFrame,
        => @compileError("value of type " ++ @typeName(@TypeOf(actual)) ++ " encountered"),

        .Undefined,
        .Null,
        .Void,
        => return,

        .Type,
        .Bool,
        .Int,
        .Float,
        .ComptimeFloat,
        .ComptimeInt,
        .EnumLiteral,
        .Enum,
        .Fn,
        .ErrorSet,
        => {
            if (actual != expected) {
                std.debug.panic("expected {}, found {}", .{ expected, actual });
            }
        },

        .Pointer => |pointer| {
            switch (pointer.size) {
                .One, .Many, .C => {
                    if (actual != expected) {
                        std.debug.panic("expected {*}, found {*}", .{ expected, actual });
                    }
                },
                .Slice => {
                    if (actual.ptr != expected.ptr) {
                        std.debug.panic("expected slice ptr {}, found {}", .{ expected.ptr, actual.ptr });
                    }
                    if (actual.len != expected.len) {
                        std.debug.panic("expected slice len {}, found {}", .{ expected.len, actual.len });
                    }
                },
            }
        },

        .Array => |array| expectEqualSlices(array.child, &expected, &actual),

        .Vector => |vectorType| {
            var i: usize = 0;
            while (i < vectorType.len) : (i += 1) {
                if (!std.meta.eql(expected[i], actual[i])) {
                    std.debug.panic("index {} incorrect. expected {}, found {}", .{ i, expected[i], actual[i] });
                }
            }
        },

        .Struct => |structType| {
            inline for (structType.fields) |field| {
                expectEqual(@field(expected, field.name), @field(actual, field.name));
            }
        },

        .Union => |union_info| {
            if (union_info.tag_type == null) {
                @compileError("Unable to compare untagged union values");
            }

            const TagType = @TagType(@TypeOf(expected));

            const expectedTag = @as(TagType, expected);
            const actualTag = @as(TagType, actual);

            expectEqual(expectedTag, actualTag);

            // we only reach this loop if the tags are equal
            inline for (std.meta.fields(@TypeOf(actual))) |fld| {
                if (std.mem.eql(u8, fld.name, @tagName(actualTag))) {
                    expectEqual(@field(expected, fld.name), @field(actual, fld.name));
                    return;
                }
            }

            // we iterate over *all* union fields
            // => we should never get here as the loop above is
            //    including all possible values.
            unreachable;
        },

        .Optional => {
            if (expected) |expected_payload| {
                if (actual) |actual_payload| {
                    expectEqual(expected_payload, actual_payload);
                } else {
                    std.debug.panic("expected {}, found null", .{expected_payload});
                }
            } else {
                if (actual) |actual_payload| {
                    std.debug.panic("expected null, found {}", .{actual_payload});
                }
            }
        },

        .ErrorUnion => {
            if (expected) |expected_payload| {
                if (actual) |actual_payload| {
                    expectEqual(expected_payload, actual_payload);
                } else |actual_err| {
                    std.debug.panic("expected {}, found {}", .{ expected_payload, actual_err });
                }
            } else |expected_err| {
                if (actual) |actual_payload| {
                    std.debug.panic("expected {}, found {}", .{ expected_err, actual_payload });
                } else |actual_err| {
                    expectEqual(expected_err, actual_err);
                }
            }
        },
    }
}

test "expectEqual.union(enum)" {
    const T = union(enum) {
        a: i32,
        b: f32,
    };

    const a10 = T{ .a = 10 };
    const a20 = T{ .a = 20 };

    expectEqual(a10, a10);
}

/// This function is intended to be used only in tests. When the two slices are not
/// equal, prints diagnostics to stderr to show exactly how they are not equal,
/// then aborts.
pub fn expectEqualSlices(comptime T: type, expected: []const T, actual: []const T) void {
    // TODO better printing of the difference
    // If the arrays are small enough we could print the whole thing
    // If the child type is u8 and no weird bytes, we could print it as strings
    // Even for the length difference, it would be useful to see the values of the slices probably.
    if (expected.len != actual.len) {
        std.debug.panic("slice lengths differ. expected {}, found {}", .{ expected.len, actual.len });
    }
    var i: usize = 0;
    while (i < expected.len) : (i += 1) {
        if (!std.meta.eql(expected[i], actual[i])) {
            std.debug.panic("index {} incorrect. expected {}, found {}", .{ i, expected[i], actual[i] });
        }
    }
}

/// This function is intended to be used only in tests. When `ok` is false, the test fails.
/// A message is printed to stderr and then abort is called.
pub fn expect(ok: bool) void {
    if (!ok) @panic("test failure");
}

test "expectEqual nested array" {
    const a = [2][2]f32{
        [_]f32{ 1.0, 0.0 },
        [_]f32{ 0.0, 1.0 },
    };

    const b = [2][2]f32{
        [_]f32{ 1.0, 0.0 },
        [_]f32{ 0.0, 1.0 },
    };

    expectEqual(a, b);
}

test "expectEqual vector" {
    var a = @splat(4, @as(u32, 4));
    var b = @splat(4, @as(u32, 4));

    expectEqual(a, b);
}
