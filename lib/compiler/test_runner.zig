//! Default test runner for unit tests.
const builtin = @import("builtin");

const std = @import("std");
const io = std.io;
const testing = std.testing;
const assert = std.debug.assert;

pub const std_options = .{
    .logFn = log,
};

var log_err_count: usize = 0;
var fba_buffer: [8192]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&fba_buffer);

const crippled = switch (builtin.zig_backend) {
    .stage2_riscv64 => true,
    else => false,
};

pub fn main() void {
    @disableInstrumentation();

    if (crippled) {
        return mainSimple() catch @panic("test failure\n");
    }

    const args = std.process.argsAlloc(fba.allocator()) catch
        @panic("unable to parse command line args");

    var listen = false;
    var opt_cache_dir: ?[]const u8 = null;

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--listen=-")) {
            listen = true;
        } else if (std.mem.startsWith(u8, arg, "--seed=")) {
            testing.random_seed = std.fmt.parseUnsigned(u32, arg["--seed=".len..], 0) catch
                @panic("unable to parse --seed command line argument");
        } else if (std.mem.startsWith(u8, arg, "--cache-dir")) {
            opt_cache_dir = arg["--cache-dir=".len..];
        } else {
            @panic("unrecognized command line argument");
        }
    }

    fba.reset();
    if (builtin.fuzz) {
        const cache_dir = opt_cache_dir orelse @panic("missing --cache-dir=[path] argument");
        fuzzer_init(FuzzerSlice.fromSlice(cache_dir));
    }

    if (listen) {
        return mainServer() catch @panic("internal test runner failure");
    } else {
        return mainTerminal();
    }
}

fn mainServer() !void {
    @disableInstrumentation();
    var server = try std.zig.Server.init(.{
        .gpa = fba.allocator(),
        .in = std.io.getStdIn(),
        .out = std.io.getStdOut(),
        .zig_version = builtin.zig_version_string,
    });
    defer server.deinit();

    if (builtin.fuzz) {
        const coverage_id = fuzzer_coverage_id();
        try server.serveU64Message(.coverage_id, coverage_id);
    }

    while (true) {
        const hdr = try server.receiveMessage();
        switch (hdr.tag) {
            .exit => {
                return std.process.exit(0);
            },
            .query_test_metadata => {
                testing.allocator_instance = .{};
                defer if (testing.allocator_instance.deinit() == .leak) {
                    @panic("internal test runner memory leak");
                };

                var string_bytes: std.ArrayListUnmanaged(u8) = .{};
                defer string_bytes.deinit(testing.allocator);
                try string_bytes.append(testing.allocator, 0); // Reserve 0 for null.

                const test_fns = builtin.test_functions;
                const names = try testing.allocator.alloc(u32, test_fns.len);
                defer testing.allocator.free(names);
                const expected_panic_msgs = try testing.allocator.alloc(u32, test_fns.len);
                defer testing.allocator.free(expected_panic_msgs);

                for (test_fns, names, expected_panic_msgs) |test_fn, *name, *expected_panic_msg| {
                    name.* = @as(u32, @intCast(string_bytes.items.len));
                    try string_bytes.ensureUnusedCapacity(testing.allocator, test_fn.name.len + 1);
                    string_bytes.appendSliceAssumeCapacity(test_fn.name);
                    string_bytes.appendAssumeCapacity(0);
                    expected_panic_msg.* = 0;
                }

                try server.serveTestMetadata(.{
                    .names = names,
                    .expected_panic_msgs = expected_panic_msgs,
                    .string_bytes = string_bytes.items,
                });
            },

            .run_test => {
                testing.allocator_instance = .{};
                log_err_count = 0;
                const index = try server.receiveBody_u32();
                const test_fn = builtin.test_functions[index];
                var fail = false;
                var skip = false;
                fuzzer = .{};
                test_fn.func() catch |err| switch (err) {
                    error.SkipZigTest => skip = true,
                    else => {
                        fail = true;
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpStackTrace(trace.*);
                        }
                    },
                };
                const leak = testing.allocator_instance.deinit() == .leak;
                try server.serveTestResults(.{
                    .index = index,
                    .flags = .{
                        .fail = fail,
                        .skip = skip,
                        .leak = leak,
                        .fuzz = fuzzer.test_data != null,
                        .log_err_count = std.math.lossyCast(
                            @TypeOf(@as(std.zig.Server.Message.TestResults.Flags, undefined).log_err_count),
                            log_err_count,
                        ),
                    },
                });
            },
            .start_fuzzing => {
                if (!builtin.fuzz) unreachable;
                const index = try server.receiveBody_u32();
                const test_fn = builtin.test_functions[index];
                fuzzer = .{ .server = &server };
                testing.allocator_instance = .{};
                defer if (testing.allocator_instance.deinit() == .leak) std.process.exit(1);
                log_err_count = 0;
                test_fn.func() catch |err| switch (err) {
                    error.SkipZigTest => continue,
                    else => {
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpStackTrace(trace.*);
                        }
                        std.debug.print("failed with error.{s}\n", .{@errorName(err)});
                        std.process.exit(1);
                    },
                };
                if (log_err_count != 0) @panic("error logs detected");
            },

            else => {
                std.debug.print("unsupported message: {x}\n", .{@intFromEnum(hdr.tag)});
                std.process.exit(1);
            },
        }
    }
}

fn mainTerminal() void {
    @disableInstrumentation();
    const test_fn_list = builtin.test_functions;
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    var fail_count: usize = 0;
    var fuzz_count: usize = 0;
    const root_node = if (builtin.fuzz) std.Progress.Node.none else std.Progress.start(.{
        .root_name = "Test",
        .estimated_total_items = test_fn_list.len,
    });
    const have_tty = std.io.getStdErr().isTty();

    var async_frame_buffer: []align(builtin.target.stackAlignment()) u8 = undefined;
    // TODO this is on the next line (using `undefined` above) because otherwise zig incorrectly
    // ignores the alignment of the slice.
    async_frame_buffer = &[_]u8{};

    var leaks: usize = 0;
    for (test_fn_list, 0..) |test_fn, i| {
        testing.allocator_instance = .{};
        defer {
            if (testing.allocator_instance.deinit() == .leak) {
                leaks += 1;
            }
        }
        testing.log_level = .warn;

        const test_node = root_node.start(test_fn.name, 0);
        if (!have_tty) {
            std.debug.print("{d}/{d} {s}...", .{ i + 1, test_fn_list.len, test_fn.name });
        }
        fuzzer = .{};
        if (test_fn.func()) |_| {
            ok_count += 1;
            test_node.end();
            if (!have_tty) std.debug.print("OK\n", .{});
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                if (have_tty) {
                    std.debug.print("{d}/{d} {s}...SKIP\n", .{ i + 1, test_fn_list.len, test_fn.name });
                } else {
                    std.debug.print("SKIP\n", .{});
                }
                test_node.end();
            },
            else => {
                fail_count += 1;
                if (have_tty) {
                    std.debug.print("{d}/{d} {s}...FAIL ({s})\n", .{
                        i + 1, test_fn_list.len, test_fn.name, @errorName(err),
                    });
                } else {
                    std.debug.print("FAIL ({s})\n", .{@errorName(err)});
                }
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                test_node.end();
            },
        }
        fuzz_count += @intFromBool(fuzzer.test_data != null);
    }
    root_node.end();
    if (ok_count == test_fn_list.len) {
        std.debug.print("All {d} tests passed.\n", .{ok_count});
    } else {
        std.debug.print("{d} passed; {d} skipped; {d} failed.\n", .{ ok_count, skip_count, fail_count });
    }
    if (log_err_count != 0) {
        std.debug.print("{d} errors were logged.\n", .{log_err_count});
    }
    if (leaks != 0) {
        std.debug.print("{d} tests leaked memory.\n", .{leaks});
    }
    if (fuzz_count != 0) {
        std.debug.print("{d} fuzz tests found.\n", .{fuzz_count});
    }
    if (leaks != 0 or log_err_count != 0 or fail_count != 0) {
        std.process.exit(1);
    }
}

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    @disableInstrumentation();
    if (@intFromEnum(message_level) <= @intFromEnum(std.log.Level.err)) {
        log_err_count +|= 1;
    }
    if (@intFromEnum(message_level) <= @intFromEnum(testing.log_level)) {
        std.debug.print(
            "[" ++ @tagName(scope) ++ "] (" ++ @tagName(message_level) ++ "): " ++ format ++ "\n",
            args,
        );
    }
}

/// Simpler main(), exercising fewer language features, so that
/// work-in-progress backends can handle it.
pub fn mainSimple() anyerror!void {
    @disableInstrumentation();
    // is the backend capable of printing to stderr?
    const enable_print = switch (builtin.zig_backend) {
        else => false,
    };
    // is the backend capable of using std.fmt.format to print a summary at the end?
    const print_summary = switch (builtin.zig_backend) {
        else => false,
    };

    var passed: u64 = 0;
    var skipped: u64 = 0;
    var failed: u64 = 0;

    // we don't want to bring in File and Writer if the backend doesn't support it
    const stderr = if (comptime enable_print) std.io.getStdErr() else {};

    for (builtin.test_functions) |test_fn| {
        if (test_fn.func()) |_| {
            if (enable_print) {
                stderr.writeAll(test_fn.name) catch {};
                stderr.writeAll("... ") catch {};
                stderr.writeAll("PASS\n") catch {};
            }
        } else |err| if (enable_print) {
            if (enable_print) {
                stderr.writeAll(test_fn.name) catch {};
                stderr.writeAll("... ") catch {};
            }
            if (err != error.SkipZigTest) {
                if (enable_print) stderr.writeAll("FAIL\n") catch {};
                failed += 1;
                if (!enable_print) return err;
                continue;
            }
            if (enable_print) stderr.writeAll("SKIP\n") catch {};
            skipped += 1;
            continue;
        }
        passed += 1;
    }
    if (enable_print and print_summary) {
        stderr.writer().print("{} passed, {} skipped, {} failed\n", .{ passed, skipped, failed }) catch {};
    }
    if (failed != 0) std.process.exit(1);
}

const FuzzerSlice = extern struct {
    ptr: [*]const u8,
    len: usize,

    /// Inline to avoid fuzzer instrumentation.
    inline fn toSlice(s: FuzzerSlice) []const u8 {
        return s.ptr[0..s.len];
    }

    /// Inline to avoid fuzzer instrumentation.
    inline fn fromSlice(s: []const u8) FuzzerSlice {
        return .{ .ptr = s.ptr, .len = s.len };
    }
};

// Initialized prior to executing each test function.
var fuzzer: Fuzzer = undefined;

// NOTE: These must only be referenced when `builtin.fuzz` since libfuzzer is only linked
// when that is true.
extern fn fuzzer_next() FuzzerSlice;
extern fn fuzzer_init(cache_dir: FuzzerSlice) void;
extern fn fuzzer_coverage_id() u64;

const Fuzzer = struct {
    server: ?*std.zig.Server = null,
    test_data: ?TestData = null,

    const TestData = struct {
        notification_state: enum { before_first, after_first, rest } = .before_first,
        entry_addr: usize = 0,
        corpus: if (!builtin.fuzz) []const []const u8 else void,
        corpus_index: if (!builtin.fuzz) usize else void,
        allocator_instance: std.heap.GeneralPurposeAllocator(.{}) = .{},
    };
};

pub fn fuzzerInit(options: testing.FuzzerOptions) void {
    if (!builtin.fuzz) {
        fuzzer.test_data = .{
            .corpus = if (options.corpus.len == 0) &.{""} else options.corpus,
            .corpus_index = 0,
        };
        return;
    }
    fuzzer.test_data = .{
        .corpus = {},
        .corpus_index = {},
    };
}

pub fn fuzzerNext() ?testing.Fuzzer.Run {
    @disableInstrumentation();
    if (crippled) return "";
    // Test date must be initialized during `fuzzerInit`.
    const test_data = &fuzzer.test_data.?;
    // Evaluate the previous loop. This must do nothing before the first loop.
    if (test_data.allocator_instance.deinit() == .leak) std.process.exit(1);
    if (log_err_count != 0) @panic("error logs detected");
    // Reset the allocator.
    test_data.allocator_instance = .{};
    // Iterate over the corpus for dry-run tests.
    if (!builtin.fuzz) {
        if (test_data.corpus_index >= test_data.corpus.len)
            return null;
        const result = test_data.corpus[test_data.corpus_index];
        test_data.corpus_index += 1;
        return .{
            .allocator = test_data.allocator_instance.allocator(),
            .input = result,
        };
    }
    // Notify the Zig server on the second call to `fuzzerNext` using the return address
    // from the first call. Subsequent calls have no effect.
    switch (test_data.notification_state) {
        .before_first => {
            test_data.entry_addr = @returnAddress();
            test_data.notification_state = .after_first;
        },
        .after_first => {
            if (fuzzer.server) |server|
                server.serveU64Message(.fuzz_start_addr, @returnAddress()) catch @panic("internal test runner failure");
            test_data.notification_state = .rest;
        },
        .rest => {},
    }
    return .{
        .allocator = test_data.allocator_instance.allocator(),
        .input = fuzzer_next().toSlice(),
    };
}
