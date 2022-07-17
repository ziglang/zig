const std = @import("std.zig");
const builtin = @import("builtin");

const math = std.math;
const print = std.debug.print;

pub const FailingAllocator = @import("testing/failing_allocator.zig").FailingAllocator;

/// This should only be used in temporary test programs.
pub const allocator = allocator_instance.allocator();
pub var allocator_instance = std.heap.GeneralPurposeAllocator(.{}){};

pub const failing_allocator = failing_allocator_instance.allocator();
pub var failing_allocator_instance = FailingAllocator.init(base_allocator_instance.allocator(), 0);

pub var base_allocator_instance = std.heap.FixedBufferAllocator.init("");

/// TODO https://github.com/ziglang/zig/issues/5738
pub var log_level = std.log.Level.warn;

/// This is available to any test that wants to execute Zig in a child process.
/// It will be the same executable that is running `zig test`.
pub var zig_exe_path: []const u8 = undefined;

/// This function is intended to be used only in tests. It prints diagnostics to stderr
/// and then returns a test failure error when actual_error_union is not expected_error.
pub fn expectError(expected_error: anyerror, actual_error_union: anytype) !void {
    if (actual_error_union) |actual_payload| {
        std.debug.print("expected error.{s}, found {any}\n", .{ @errorName(expected_error), actual_payload });
        return error.TestUnexpectedError;
    } else |actual_error| {
        if (expected_error != actual_error) {
            std.debug.print("expected error.{s}, found error.{s}\n", .{
                @errorName(expected_error),
                @errorName(actual_error),
            });
            return error.TestExpectedError;
        }
    }
}

/// This function is intended to be used only in tests. When the two values are not
/// equal, prints diagnostics to stderr to show exactly how they are not equal,
/// then returns a test failure error.
/// `actual` is casted to the type of `expected`.
pub fn expectEqual(expected: anytype, actual: @TypeOf(expected)) !void {
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

        .Type => {
            if (actual != expected) {
                std.debug.print("expected type {s}, found type {s}\n", .{ @typeName(expected), @typeName(actual) });
                return error.TestExpectedEqual;
            }
        },

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
                std.debug.print("expected {}, found {}\n", .{ expected, actual });
                return error.TestExpectedEqual;
            }
        },

        .Pointer => |pointer| {
            switch (pointer.size) {
                .One, .Many, .C => {
                    if (actual != expected) {
                        std.debug.print("expected {*}, found {*}\n", .{ expected, actual });
                        return error.TestExpectedEqual;
                    }
                },
                .Slice => {
                    if (actual.ptr != expected.ptr) {
                        std.debug.print("expected slice ptr {*}, found {*}\n", .{ expected.ptr, actual.ptr });
                        return error.TestExpectedEqual;
                    }
                    if (actual.len != expected.len) {
                        std.debug.print("expected slice len {}, found {}\n", .{ expected.len, actual.len });
                        return error.TestExpectedEqual;
                    }
                },
            }
        },

        .Array => |array| try expectEqualSlices(array.child, &expected, &actual),

        .Vector => |info| {
            var i: usize = 0;
            while (i < info.len) : (i += 1) {
                if (!std.meta.eql(expected[i], actual[i])) {
                    std.debug.print("index {} incorrect. expected {}, found {}\n", .{
                        i, expected[i], actual[i],
                    });
                    return error.TestExpectedEqual;
                }
            }
        },

        .Struct => |structType| {
            inline for (structType.fields) |field| {
                try expectEqual(@field(expected, field.name), @field(actual, field.name));
            }
        },

        .Union => |union_info| {
            if (union_info.tag_type == null) {
                @compileError("Unable to compare untagged union values");
            }

            const Tag = std.meta.Tag(@TypeOf(expected));

            const expectedTag = @as(Tag, expected);
            const actualTag = @as(Tag, actual);

            try expectEqual(expectedTag, actualTag);

            // we only reach this loop if the tags are equal
            inline for (std.meta.fields(@TypeOf(actual))) |fld| {
                if (std.mem.eql(u8, fld.name, @tagName(actualTag))) {
                    try expectEqual(@field(expected, fld.name), @field(actual, fld.name));
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
                    try expectEqual(expected_payload, actual_payload);
                } else {
                    std.debug.print("expected {any}, found null\n", .{expected_payload});
                    return error.TestExpectedEqual;
                }
            } else {
                if (actual) |actual_payload| {
                    std.debug.print("expected null, found {any}\n", .{actual_payload});
                    return error.TestExpectedEqual;
                }
            }
        },

        .ErrorUnion => {
            if (expected) |expected_payload| {
                if (actual) |actual_payload| {
                    try expectEqual(expected_payload, actual_payload);
                } else |actual_err| {
                    std.debug.print("expected {any}, found {}\n", .{ expected_payload, actual_err });
                    return error.TestExpectedEqual;
                }
            } else |expected_err| {
                if (actual) |actual_payload| {
                    std.debug.print("expected {}, found {any}\n", .{ expected_err, actual_payload });
                    return error.TestExpectedEqual;
                } else |actual_err| {
                    try expectEqual(expected_err, actual_err);
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

    try expectEqual(a10, a10);
}

/// This function is intended to be used only in tests. When the formatted result of the template
/// and its arguments does not equal the expected text, it prints diagnostics to stderr to show how
/// they are not equal, then returns an error.
pub fn expectFmt(expected: []const u8, comptime template: []const u8, args: anytype) !void {
    const result = try std.fmt.allocPrint(allocator, template, args);
    defer allocator.free(result);
    if (std.mem.eql(u8, result, expected)) return;

    print("\n====== expected this output: =========\n", .{});
    print("{s}", .{expected});
    print("\n======== instead found this: =========\n", .{});
    print("{s}", .{result});
    print("\n======================================\n", .{});
    return error.TestExpectedFmt;
}

/// This function is intended to be used only in tests. When the actual value is
/// not approximately equal to the expected value, prints diagnostics to stderr
/// to show exactly how they are not equal, then returns a test failure error.
/// See `math.approxEqAbs` for more informations on the tolerance parameter.
/// The types must be floating point
pub fn expectApproxEqAbs(expected: anytype, actual: @TypeOf(expected), tolerance: @TypeOf(expected)) !void {
    const T = @TypeOf(expected);

    switch (@typeInfo(T)) {
        .Float => if (!math.approxEqAbs(T, expected, actual, tolerance)) {
            std.debug.print("actual {}, not within absolute tolerance {} of expected {}\n", .{ actual, tolerance, expected });
            return error.TestExpectedApproxEqAbs;
        },

        .ComptimeFloat => @compileError("Cannot approximately compare two comptime_float values"),

        else => @compileError("Unable to compare non floating point values"),
    }
}

test "expectApproxEqAbs" {
    inline for ([_]type{ f16, f32, f64, f128 }) |T| {
        const pos_x: T = 12.0;
        const pos_y: T = 12.06;
        const neg_x: T = -12.0;
        const neg_y: T = -12.06;

        try expectApproxEqAbs(pos_x, pos_y, 0.1);
        try expectApproxEqAbs(neg_x, neg_y, 0.1);
    }
}

/// This function is intended to be used only in tests. When the actual value is
/// not approximately equal to the expected value, prints diagnostics to stderr
/// to show exactly how they are not equal, then returns a test failure error.
/// See `math.approxEqRel` for more informations on the tolerance parameter.
/// The types must be floating point
pub fn expectApproxEqRel(expected: anytype, actual: @TypeOf(expected), tolerance: @TypeOf(expected)) !void {
    const T = @TypeOf(expected);

    switch (@typeInfo(T)) {
        .Float => if (!math.approxEqRel(T, expected, actual, tolerance)) {
            std.debug.print("actual {}, not within relative tolerance {} of expected {}\n", .{ actual, tolerance, expected });
            return error.TestExpectedApproxEqRel;
        },

        .ComptimeFloat => @compileError("Cannot approximately compare two comptime_float values"),

        else => @compileError("Unable to compare non floating point values"),
    }
}

test "expectApproxEqRel" {
    inline for ([_]type{ f16, f32, f64, f128 }) |T| {
        const eps_value = comptime math.epsilon(T);
        const sqrt_eps_value = comptime @sqrt(eps_value);

        const pos_x: T = 12.0;
        const pos_y: T = pos_x + 2 * eps_value;
        const neg_x: T = -12.0;
        const neg_y: T = neg_x - 2 * eps_value;

        try expectApproxEqRel(pos_x, pos_y, sqrt_eps_value);
        try expectApproxEqRel(neg_x, neg_y, sqrt_eps_value);
    }
}

/// This function is intended to be used only in tests. When the two slices are not
/// equal, prints diagnostics to stderr to show exactly how they are not equal,
/// then returns a test failure error.
/// If your inputs are UTF-8 encoded strings, consider calling `expectEqualStrings` instead.
pub fn expectEqualSlices(comptime T: type, expected: []const T, actual: []const T) !void {
    // TODO better printing of the difference
    // If the arrays are small enough we could print the whole thing
    // If the child type is u8 and no weird bytes, we could print it as strings
    // Even for the length difference, it would be useful to see the values of the slices probably.
    if (expected.len != actual.len) {
        std.debug.print("slice lengths differ. expected {d}, found {d}\n", .{ expected.len, actual.len });
        return error.TestExpectedEqual;
    }
    var i: usize = 0;
    while (i < expected.len) : (i += 1) {
        if (!std.meta.eql(expected[i], actual[i])) {
            std.debug.print("index {} incorrect. expected {any}, found {any}\n", .{ i, expected[i], actual[i] });
            return error.TestExpectedEqual;
        }
    }
}

/// This function is intended to be used only in tests. Checks that two slices or two arrays are equal,
/// including that their sentinel (if any) are the same. Will error if given another type.
pub fn expectEqualSentinel(comptime T: type, comptime sentinel: T, expected: [:sentinel]const T, actual: [:sentinel]const T) !void {
    try expectEqualSlices(T, expected, actual);

    const expected_value_sentinel = blk: {
        switch (@typeInfo(@TypeOf(expected))) {
            .Pointer => {
                break :blk expected[expected.len];
            },
            .Array => |array_info| {
                const indexable_outside_of_bounds = @as([]const array_info.child, &expected);
                break :blk indexable_outside_of_bounds[indexable_outside_of_bounds.len];
            },
            else => {},
        }
    };

    const actual_value_sentinel = blk: {
        switch (@typeInfo(@TypeOf(actual))) {
            .Pointer => {
                break :blk actual[actual.len];
            },
            .Array => |array_info| {
                const indexable_outside_of_bounds = @as([]const array_info.child, &actual);
                break :blk indexable_outside_of_bounds[indexable_outside_of_bounds.len];
            },
            else => {},
        }
    };

    if (!std.meta.eql(sentinel, expected_value_sentinel)) {
        std.debug.print("expectEqualSentinel: 'expected' sentinel in memory is different from its type sentinel. type sentinel {}, in memory sentinel {}\n", .{ sentinel, expected_value_sentinel });
        return error.TestExpectedEqual;
    }

    if (!std.meta.eql(sentinel, actual_value_sentinel)) {
        std.debug.print("expectEqualSentinel: 'actual' sentinel in memory is different from its type sentinel. type sentinel {}, in memory sentinel {}\n", .{ sentinel, actual_value_sentinel });
        return error.TestExpectedEqual;
    }
}

/// This function is intended to be used only in tests.
/// When `ok` is false, returns a test failure error.
pub fn expect(ok: bool) !void {
    if (!ok) return error.TestUnexpectedResult;
}

pub const TmpDir = struct {
    dir: std.fs.Dir,
    parent_dir: std.fs.Dir,
    sub_path: [sub_path_len]u8,

    const random_bytes_count = 12;
    const sub_path_len = std.fs.base64_encoder.calcSize(random_bytes_count);

    pub fn cleanup(self: *TmpDir) void {
        self.dir.close();
        self.parent_dir.deleteTree(&self.sub_path) catch {};
        self.parent_dir.close();
        self.* = undefined;
    }
};

pub const TmpIterableDir = struct {
    iterable_dir: std.fs.IterableDir,
    parent_dir: std.fs.Dir,
    sub_path: [sub_path_len]u8,

    const random_bytes_count = 12;
    const sub_path_len = std.fs.base64_encoder.calcSize(random_bytes_count);

    pub fn cleanup(self: *TmpIterableDir) void {
        self.iterable_dir.close();
        self.parent_dir.deleteTree(&self.sub_path) catch {};
        self.parent_dir.close();
        self.* = undefined;
    }
};

fn getCwdOrWasiPreopen() std.fs.Dir {
    if (builtin.os.tag == .wasi and !builtin.link_libc) {
        var preopens = std.fs.wasi.PreopenList.init(allocator);
        defer preopens.deinit();
        preopens.populate(null) catch
            @panic("unable to make tmp dir for testing: unable to populate preopens");
        const preopen = preopens.find(std.fs.wasi.PreopenType{ .Dir = "." }) orelse
            @panic("unable to make tmp dir for testing: didn't find '.' in the preopens");

        return std.fs.Dir{ .fd = preopen.fd };
    } else {
        return std.fs.cwd();
    }
}

pub fn tmpDir(opts: std.fs.Dir.OpenDirOptions) TmpDir {
    var random_bytes: [TmpDir.random_bytes_count]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    var sub_path: [TmpDir.sub_path_len]u8 = undefined;
    _ = std.fs.base64_encoder.encode(&sub_path, &random_bytes);

    var cwd = getCwdOrWasiPreopen();
    var cache_dir = cwd.makeOpenPath("zig-cache", .{}) catch
        @panic("unable to make tmp dir for testing: unable to make and open zig-cache dir");
    defer cache_dir.close();
    var parent_dir = cache_dir.makeOpenPath("tmp", .{}) catch
        @panic("unable to make tmp dir for testing: unable to make and open zig-cache/tmp dir");
    var dir = parent_dir.makeOpenPath(&sub_path, opts) catch
        @panic("unable to make tmp dir for testing: unable to make and open the tmp dir");

    return .{
        .dir = dir,
        .parent_dir = parent_dir,
        .sub_path = sub_path,
    };
}

pub fn tmpIterableDir(opts: std.fs.Dir.OpenDirOptions) TmpIterableDir {
    var random_bytes: [TmpIterableDir.random_bytes_count]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    var sub_path: [TmpIterableDir.sub_path_len]u8 = undefined;
    _ = std.fs.base64_encoder.encode(&sub_path, &random_bytes);

    var cwd = getCwdOrWasiPreopen();
    var cache_dir = cwd.makeOpenPath("zig-cache", .{}) catch
        @panic("unable to make tmp dir for testing: unable to make and open zig-cache dir");
    defer cache_dir.close();
    var parent_dir = cache_dir.makeOpenPath("tmp", .{}) catch
        @panic("unable to make tmp dir for testing: unable to make and open zig-cache/tmp dir");
    var dir = parent_dir.makeOpenPathIterable(&sub_path, opts) catch
        @panic("unable to make tmp dir for testing: unable to make and open the tmp dir");

    return .{
        .iterable_dir = dir,
        .parent_dir = parent_dir,
        .sub_path = sub_path,
    };
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

    try expectEqual(a, b);
}

test "expectEqual vector" {
    var a = @splat(4, @as(u32, 4));
    var b = @splat(4, @as(u32, 4));

    try expectEqual(a, b);
}

pub fn expectEqualStrings(expected: []const u8, actual: []const u8) !void {
    if (std.mem.indexOfDiff(u8, actual, expected)) |diff_index| {
        print("\n====== expected this output: =========\n", .{});
        printWithVisibleNewlines(expected);
        print("\n======== instead found this: =========\n", .{});
        printWithVisibleNewlines(actual);
        print("\n======================================\n", .{});

        var diff_line_number: usize = 1;
        for (expected[0..diff_index]) |value| {
            if (value == '\n') diff_line_number += 1;
        }
        print("First difference occurs on line {d}:\n", .{diff_line_number});

        print("expected:\n", .{});
        printIndicatorLine(expected, diff_index);

        print("found:\n", .{});
        printIndicatorLine(actual, diff_index);

        return error.TestExpectedEqual;
    }
}

pub fn expectStringStartsWith(actual: []const u8, expected_starts_with: []const u8) !void {
    if (std.mem.startsWith(u8, actual, expected_starts_with))
        return;

    const shortened_actual = if (actual.len >= expected_starts_with.len)
        actual[0..expected_starts_with.len]
    else
        actual;

    print("\n====== expected to start with: =========\n", .{});
    printWithVisibleNewlines(expected_starts_with);
    print("\n====== instead ended with: ===========\n", .{});
    printWithVisibleNewlines(shortened_actual);
    print("\n========= full output: ==============\n", .{});
    printWithVisibleNewlines(actual);
    print("\n======================================\n", .{});

    return error.TestExpectedStartsWith;
}

pub fn expectStringEndsWith(actual: []const u8, expected_ends_with: []const u8) !void {
    if (std.mem.endsWith(u8, actual, expected_ends_with))
        return;

    const shortened_actual = if (actual.len >= expected_ends_with.len)
        actual[(actual.len - expected_ends_with.len)..]
    else
        actual;

    print("\n====== expected to end with: =========\n", .{});
    printWithVisibleNewlines(expected_ends_with);
    print("\n====== instead ended with: ===========\n", .{});
    printWithVisibleNewlines(shortened_actual);
    print("\n========= full output: ==============\n", .{});
    printWithVisibleNewlines(actual);
    print("\n======================================\n", .{});

    return error.TestExpectedEndsWith;
}

fn printIndicatorLine(source: []const u8, indicator_index: usize) void {
    const line_begin_index = if (std.mem.lastIndexOfScalar(u8, source[0..indicator_index], '\n')) |line_begin|
        line_begin + 1
    else
        0;
    const line_end_index = if (std.mem.indexOfScalar(u8, source[indicator_index..], '\n')) |line_end|
        (indicator_index + line_end)
    else
        source.len;

    printLine(source[line_begin_index..line_end_index]);
    {
        var i: usize = line_begin_index;
        while (i < indicator_index) : (i += 1)
            print(" ", .{});
    }
    print("^\n", .{});
}

fn printWithVisibleNewlines(source: []const u8) void {
    var i: usize = 0;
    while (std.mem.indexOfScalar(u8, source[i..], '\n')) |nl| : (i += nl + 1) {
        printLine(source[i .. i + nl]);
    }
    print("{s}␃\n", .{source[i..]}); // End of Text symbol (ETX)
}

fn printLine(line: []const u8) void {
    if (line.len != 0) switch (line[line.len - 1]) {
        ' ', '\t' => return print("{s}⏎\n", .{line}), // Carriage return symbol,
        else => {},
    };
    print("{s}\n", .{line});
}

test {
    try expectEqualStrings("foo", "foo");
}

/// Exhaustively check that allocation failures within `test_fn` are handled without
/// introducing memory leaks. If used with the `testing.allocator` as the `backing_allocator`,
/// it will also be able to detect double frees, etc (when runtime safety is enabled).
///
/// The provided `test_fn` must have a `std.mem.Allocator` as its first argument,
/// and must have a return type of `!void`. Any extra arguments of `test_fn` can
/// be provided via the `extra_args` tuple.
///
/// Any relevant state shared between runs of `test_fn` *must* be reset within `test_fn`.
///
/// The strategy employed is to:
/// - Run the test function once to get the total number of allocations.
/// - Then, iterate and run the function X more times, incrementing
///   the failing index each iteration (where X is the total number of
///   allocations determined previously)
///
/// Expects that `test_fn` has a deterministic number of memory allocations:
/// - If an allocation was made to fail during a run of `test_fn`, but `test_fn`
///   didn't return `error.OutOfMemory`, then `error.SwallowedOutOfMemoryError`
///   is returned from `checkAllAllocationFailures`. You may want to ignore this
///   depending on whether or not the code you're testing includes some strategies
///   for recovering from `error.OutOfMemory`.
/// - If a run of `test_fn` with an expected allocation failure executes without
///   an allocation failure being induced, then `error.NondeterministicMemoryUsage`
///   is returned. This error means that there are allocation points that won't be
///   tested by the strategy this function employs (that is, there are sometimes more
///   points of allocation than the initial run of `test_fn` detects).
///
/// ---
///
/// Here's an example using a simple test case that will cause a leak when the
/// allocation of `bar` fails (but will pass normally):
///
/// ```zig
/// test {
///     const length: usize = 10;
///     const allocator = std.testing.allocator;
///     var foo = try allocator.alloc(u8, length);
///     var bar = try allocator.alloc(u8, length);
///
///     allocator.free(foo);
///     allocator.free(bar);
/// }
/// ```
///
/// The test case can be converted to something that this function can use by
/// doing:
///
/// ```zig
/// fn testImpl(allocator: std.mem.Allocator, length: usize) !void {
///     var foo = try allocator.alloc(u8, length);
///     var bar = try allocator.alloc(u8, length);
///
///     allocator.free(foo);
///     allocator.free(bar);
/// }
///
/// test {
///     const length: usize = 10;
///     const allocator = std.testing.allocator;
///     try std.testing.checkAllAllocationFailures(allocator, testImpl, .{length});
/// }
/// ```
///
/// Running this test will show that `foo` is leaked when the allocation of
/// `bar` fails. The simplest fix, in this case, would be to use defer like so:
///
/// ```zig
/// fn testImpl(allocator: std.mem.Allocator, length: usize) !void {
///     var foo = try allocator.alloc(u8, length);
///     defer allocator.free(foo);
///     var bar = try allocator.alloc(u8, length);
///     defer allocator.free(bar);
/// }
/// ```
pub fn checkAllAllocationFailures(backing_allocator: std.mem.Allocator, comptime test_fn: anytype, extra_args: anytype) !void {
    switch (@typeInfo(@typeInfo(@TypeOf(test_fn)).Fn.return_type.?)) {
        .ErrorUnion => |info| {
            if (info.payload != void) {
                @compileError("Return type must be !void");
            }
        },
        else => @compileError("Return type must be !void"),
    }
    if (@typeInfo(@TypeOf(extra_args)) != .Struct) {
        @compileError("Expected tuple or struct argument, found " ++ @typeName(@TypeOf(extra_args)));
    }

    const ArgsTuple = std.meta.ArgsTuple(@TypeOf(test_fn));
    const fn_args_fields = @typeInfo(ArgsTuple).Struct.fields;
    if (fn_args_fields.len == 0 or fn_args_fields[0].field_type != std.mem.Allocator) {
        @compileError("The provided function must have an " ++ @typeName(std.mem.Allocator) ++ " as its first argument");
    }
    const expected_args_tuple_len = fn_args_fields.len - 1;
    if (extra_args.len != expected_args_tuple_len) {
        @compileError("The provided function expects " ++ (comptime std.fmt.comptimePrint("{d}", .{expected_args_tuple_len})) ++ " extra arguments, but the provided tuple contains " ++ (comptime std.fmt.comptimePrint("{d}", .{extra_args.len})));
    }

    // Setup the tuple that will actually be used with @call (we'll need to insert
    // the failing allocator in field @"0" before each @call)
    var args: ArgsTuple = undefined;
    inline for (@typeInfo(@TypeOf(extra_args)).Struct.fields) |field, i| {
        const arg_i_str = comptime str: {
            var str_buf: [100]u8 = undefined;
            const args_i = i + 1;
            const str_len = std.fmt.formatIntBuf(&str_buf, args_i, 10, .lower, .{});
            break :str str_buf[0..str_len];
        };
        @field(args, arg_i_str) = @field(extra_args, field.name);
    }

    // Try it once with unlimited memory, make sure it works
    const needed_alloc_count = x: {
        var failing_allocator_inst = std.testing.FailingAllocator.init(backing_allocator, std.math.maxInt(usize));
        args.@"0" = failing_allocator_inst.allocator();

        try @call(.{}, test_fn, args);
        break :x failing_allocator_inst.index;
    };

    var fail_index: usize = 0;
    while (fail_index < needed_alloc_count) : (fail_index += 1) {
        var failing_allocator_inst = std.testing.FailingAllocator.init(backing_allocator, fail_index);
        args.@"0" = failing_allocator_inst.allocator();

        if (@call(.{}, test_fn, args)) |_| {
            if (failing_allocator_inst.has_induced_failure) {
                return error.SwallowedOutOfMemoryError;
            } else {
                return error.NondeterministicMemoryUsage;
            }
        } else |err| switch (err) {
            error.OutOfMemory => {
                if (failing_allocator_inst.allocated_bytes != failing_allocator_inst.freed_bytes) {
                    print(
                        "\nfail_index: {d}/{d}\nallocated bytes: {d}\nfreed bytes: {d}\nallocations: {d}\ndeallocations: {d}\nallocation that was made to fail: {s}",
                        .{
                            fail_index,
                            needed_alloc_count,
                            failing_allocator_inst.allocated_bytes,
                            failing_allocator_inst.freed_bytes,
                            failing_allocator_inst.allocations,
                            failing_allocator_inst.deallocations,
                            failing_allocator_inst.getStackTrace(),
                        },
                    );
                    return error.MemoryLeakDetected;
                }
            },
            else => return err,
        }
    }
}

/// Given a type, reference all the declarations inside, so that the semantic analyzer sees them.
pub fn refAllDecls(comptime T: type) void {
    if (!builtin.is_test) return;
    inline for (comptime std.meta.declarations(T)) |decl| {
        if (decl.is_pub) _ = @field(T, decl.name);
    }
}

/// Given a type, and Recursively reference all the declarations inside, so that the semantic analyzer sees them.
/// For deep types, you may use `@setEvalBranchQuota`
pub fn refAllDeclsRecursive(comptime T: type) void {
    inline for (comptime std.meta.declarations(T)) |decl| {
        if (decl.is_pub) {
            if (@TypeOf(@field(T, decl.name)) == type) {
                switch (@typeInfo(@field(T, decl.name))) {
                    .Struct, .Enum, .Union, .Opaque => refAllDeclsRecursive(@field(T, decl.name)),
                    else => {},
                }
            }
            _ = @field(T, decl.name);
        }
    }
}
