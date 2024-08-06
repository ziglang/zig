b: *std.Build,
options: Options,
root_step: *std.Build.Step,

pub const Options = struct {
    test_filters: []const []const u8,
    gdb: ?[]const u8,
    lldb: ?[]const u8,
    optimize_modes: []const std.builtin.OptimizeMode,
    skip_single_threaded: bool,
    skip_non_native: bool,
    skip_libc: bool,
};

pub const Target = struct {
    resolved: std.Build.ResolvedTarget,
    optimize_mode: std.builtin.OptimizeMode = .Debug,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    pic: ?bool = null,
    test_name_suffix: []const u8,
};

pub fn addTestsForTarget(db: *Debugger, target: Target) void {
    db.addLldbTest(
        "basic",
        target,
        &.{
            .{
                .path = "basic.zig",
                .source =
                \\const Basic = struct {
                \\    void: void = {},
                \\    bool_false: bool = false,
                \\    bool_true: bool = true,
                \\    u0_0: u0 = 0,
                \\    u1_0: u1 = 0,
                \\    u1_1: u1 = 1,
                \\    u2_0: u2 = 0,
                \\    u2_3: u2 = 3,
                \\    u3_0: u3 = 0,
                \\    u3_7: u3 = 7,
                \\    u4_0: u4 = 0,
                \\    u4_15: u4 = 15,
                \\    u5_0: u5 = 0,
                \\    u5_31: u5 = 31,
                \\    u6_0: u6 = 0,
                \\    u6_63: u6 = 63,
                \\    u7_0: u7 = 0,
                \\    u7_127: u7 = 127,
                \\    u8_0: u8 = 0,
                \\    u8_255: u8 = 255,
                \\    u16_0: u16 = 0,
                \\    u16_65535: u16 = 65535,
                \\    u24_0: u24 = 0,
                \\    u24_16777215: u24 = 16777215,
                \\    u32_0: u32 = 0,
                \\    u32_4294967295: u32 = 4294967295,
                \\    i0_0: i0 = 0,
                \\    @"i1_-1": i1 = -1,
                \\    i1_0: i1 = 0,
                \\    @"i2_-2": i2 = -2,
                \\    i2_0: i2 = 0,
                \\    i2_1: i2 = 1,
                \\    @"i3_-4": i3 = -4,
                \\    i3_0: i3 = 0,
                \\    i3_3: i3 = 3,
                \\    @"i4_-8": i4 = -8,
                \\    i4_0: i4 = 0,
                \\    i4_7: i4 = 7,
                \\    @"i5_-16": i5 = -16,
                \\    i5_0: i5 = 0,
                \\    i5_15: i5 = 15,
                \\    @"i6_-32": i6 = -32,
                \\    i6_0: i6 = 0,
                \\    i6_31: i6 = 31,
                \\    @"i7_-64": i7 = -64,
                \\    i7_0: i7 = 0,
                \\    i7_63: i7 = 63,
                \\    @"i8_-128": i8 = -128,
                \\    i8_0: i8 = 0,
                \\    i8_127: i8 = 127,
                \\    @"i16_-32768": i16 = -32768,
                \\    i16_0: i16 = 0,
                \\    i16_32767: i16 = 32767,
                \\    @"i24_-8388608": i24 = -8388608,
                \\    i24_0: i24 = 0,
                \\    i24_8388607: i24 = 8388607,
                \\    @"i32_-2147483648": i32 = -2147483648,
                \\    i32_0: i32 = 0,
                \\    i32_2147483647: i32 = 2147483647,
                \\    @"f16_42.625": f16 = 42.625,
                \\    @"f32_-2730.65625": f32 = -2730.65625,
                \\    @"f64_357913941.33203125": f64 = 357913941.33203125,
                \\    @"f80_-91625968981.3330078125": f80 = -91625968981.3330078125,
                \\    @"f128_384307168202282325.333332061767578125": f128 = 384307168202282325.333332061767578125,
                \\};
                \\fn testBasic(basic: Basic) void {
                \\    _ = basic;
                \\}
                \\pub fn main() void {
                \\    testBasic(.{});
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file basic.zig --source-pattern-regexp '_ = basic;'
        \\process launch
        \\frame variable --show-types basic
        \\breakpoint delete --force
    ,
        &.{
            \\(lldb) frame variable --show-types basic
            \\(root.basic.Basic) basic = {
            \\  (void) void = {}
            \\  (bool) bool_false = false
            \\  (bool) bool_true = true
            \\  (u0) u0_0 = 0
            \\  (u1) u1_0 = 0
            \\  (u1) u1_1 = 1
            \\  (u2) u2_0 = 0
            \\  (u2) u2_3 = 3
            \\  (u3) u3_0 = 0
            \\  (u3) u3_7 = 7
            \\  (u4) u4_0 = 0
            \\  (u4) u4_15 = 15
            \\  (u5) u5_0 = 0
            \\  (u5) u5_31 = 31
            \\  (u6) u6_0 = 0
            \\  (u6) u6_63 = 63
            \\  (u7) u7_0 = 0
            \\  (u7) u7_127 = 127
            \\  (u8) u8_0 = 0
            \\  (u8) u8_255 = 255
            \\  (u16) u16_0 = 0
            \\  (u16) u16_65535 = 65535
            \\  (u24) u24_0 = 0
            \\  (u24) u24_16777215 = 16777215
            \\  (u32) u32_0 = 0
            \\  (u32) u32_4294967295 = 4294967295
            \\  (i0) i0_0 = 0
            \\  (i1) i1_-1 = -1
            \\  (i1) i1_0 = 0
            \\  (i2) i2_-2 = -2
            \\  (i2) i2_0 = 0
            \\  (i2) i2_1 = 1
            \\  (i3) i3_-4 = -4
            \\  (i3) i3_0 = 0
            \\  (i3) i3_3 = 3
            \\  (i4) i4_-8 = -8
            \\  (i4) i4_0 = 0
            \\  (i4) i4_7 = 7
            \\  (i5) i5_-16 = -16
            \\  (i5) i5_0 = 0
            \\  (i5) i5_15 = 15
            \\  (i6) i6_-32 = -32
            \\  (i6) i6_0 = 0
            \\  (i6) i6_31 = 31
            \\  (i7) i7_-64 = -64
            \\  (i7) i7_0 = 0
            \\  (i7) i7_63 = 63
            \\  (i8) i8_-128 = -128
            \\  (i8) i8_0 = 0
            \\  (i8) i8_127 = 127
            \\  (i16) i16_-32768 = -32768
            \\  (i16) i16_0 = 0
            \\  (i16) i16_32767 = 32767
            \\  (i24) i24_-8388608 = -8388608
            \\  (i24) i24_0 = 0
            \\  (i24) i24_8388607 = 8388607
            \\  (i32) i32_-2147483648 = -2147483648
            \\  (i32) i32_0 = 0
            \\  (i32) i32_2147483647 = 2147483647
            \\  (f16) f16_42.625 = 42.625
            \\  (f32) f32_-2730.65625 = -2730.65625
            \\  (f64) f64_357913941.33203125 = 357913941.33203125
            \\  (f80) f80_-91625968981.3330078125 = -91625968981.3330078125
            \\  (f128) f128_384307168202282325.333332061767578125 = 384307168202282325.333332061767578125
            \\}
        },
    );
    db.addLldbTest(
        "storage",
        target,
        &.{
            .{
                .path = "storage.zig",
                .source =
                \\const global_const: u64 = 0x19e50dc8d6002077;
                \\var global_var: u64 = 0xcc423cec08622e32;
                \\threadlocal var global_threadlocal1: u64 = 0xb4d643528c042121;
                \\threadlocal var global_threadlocal2: u64 = 0x43faea1cf5ad7a22;
                \\fn testStorage(
                \\    param1: u64,
                \\    param2: u64,
                \\    param3: u64,
                \\    param4: u64,
                \\    param5: u64,
                \\    param6: u64,
                \\    param7: u64,
                \\    param8: u64,
                \\) callconv(.C) void {
                \\    const local_comptime_val: u64 = global_const *% global_const;
                \\    const local_comptime_ptr: struct { u64 } = .{ local_comptime_val *% local_comptime_val };
                \\    const local_const: u64 = global_var ^ global_threadlocal1 ^ global_threadlocal2 ^
                \\        param1 ^ param2 ^ param3 ^ param4 ^ param5 ^ param6 ^ param7 ^ param8;
                \\    var local_var: u64 = local_comptime_ptr[0] ^ local_const;
                \\    local_var = local_var;
                \\}
                \\pub fn main() void {
                \\    testStorage(
                \\        0x6a607e08125c7e00,
                \\        0x98944cb2a45a8b51,
                \\        0xa320cf10601ee6fb,
                \\        0x691ed3535bad3274,
                \\        0x63690e6867a5799f,
                \\        0x8e163f0ec76067f2,
                \\        0xf9a252c455fb4c06,
                \\        0xc88533722601e481,
                \\    );
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file storage.zig --source-pattern-regexp 'local_var = local_var;'
        \\process launch
        \\target variable --show-types --format hex global_const global_var global_threadlocal1 global_threadlocal2
        \\frame variable --show-types --format hex param1 param2 param3 param4 param5 param6 param7 param8 local_comptime_val local_comptime_ptr.0 local_const local_var
        \\breakpoint delete --force
    ,
        &.{
            \\(lldb) target variable --show-types --format hex global_const global_var global_threadlocal1 global_threadlocal2
            \\(u64) global_const = 0x19e50dc8d6002077
            \\(u64) global_var = 0xcc423cec08622e32
            \\(u64) global_threadlocal1 = 0xb4d643528c042121
            \\(u64) global_threadlocal2 = 0x43faea1cf5ad7a22
            \\(lldb) frame variable --show-types --format hex param1 param2 param3 param4 param5 param6 param7 param8 local_comptime_val local_comptime_ptr.0 local_const local_var
            \\(u64) param1 = 0x6a607e08125c7e00
            \\(u64) param2 = 0x98944cb2a45a8b51
            \\(u64) param3 = 0xa320cf10601ee6fb
            \\(u64) param4 = 0x691ed3535bad3274
            \\(u64) param5 = 0x63690e6867a5799f
            \\(u64) param6 = 0x8e163f0ec76067f2
            \\(u64) param7 = 0xf9a252c455fb4c06
            \\(u64) param8 = 0xc88533722601e481
            \\(u64) local_comptime_val = 0x69490636f81df751
            \\(u64) local_comptime_ptr.0 = 0x82e834dae74767a1
            \\(u64) local_const = 0xdffceb8b2f41e205
            \\(u64) local_var = 0x5d14df51c80685a4
        },
    );
    db.addLldbTest(
        "slices",
        target,
        &.{
            .{
                .path = "slices.zig",
                .source =
                \\pub fn main() void {
                \\    {
                \\        var array: [4]u32 = .{ 1, 2, 4, 8 };
                \\        const slice: []u32 = &array;
                \\        _ = slice;
                \\    }
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file slices.zig --source-pattern-regexp '_ = slice;'
        \\process launch
        \\frame variable --show-types array slice
        \\breakpoint delete --force
    ,
        &.{
            \\(lldb) frame variable --show-types array slice
            \\([4]u32) array = {
            \\  (u32) [0] = 1
            \\  (u32) [1] = 2
            \\  (u32) [2] = 4
            \\  (u32) [3] = 8
            \\}
            \\([]u32) slice = {
            \\  (u32) [0] = 1
            \\  (u32) [1] = 2
            \\  (u32) [2] = 4
            \\  (u32) [3] = 8
            \\}
        },
    );
    db.addLldbTest(
        "optionals",
        target,
        &.{
            .{
                .path = "optionals.zig",
                .source =
                \\pub fn main() void {
                \\    {
                \\        var null_u32: ?u32 = null;
                \\        var maybe_u32: ?u32 = null;
                \\        var nonnull_u32: ?u32 = 456;
                \\        maybe_u32 = 123;
                \\        _ = .{ &null_u32, &nonnull_u32 };
                \\    }
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file optionals.zig --source-pattern-regexp 'maybe_u32 = 123;'
        \\process launch
        \\frame variable null_u32 maybe_u32 nonnull_u32
        \\breakpoint delete --force
        \\
        \\breakpoint set --file optionals.zig --source-pattern-regexp '_ = .{ &null_u32, &nonnull_u32 };'
        \\process continue
        \\frame variable --show-types null_u32 maybe_u32 nonnull_u32
        \\breakpoint delete --force
    ,
        &.{
            \\(lldb) frame variable null_u32 maybe_u32 nonnull_u32
            \\(?u32) null_u32 = null
            \\(?u32) maybe_u32 = null
            \\(?u32) nonnull_u32 = (nonnull_u32.? = 456)
            ,
            \\(lldb) frame variable --show-types null_u32 maybe_u32 nonnull_u32
            \\(?u32) null_u32 = null
            \\(?u32) maybe_u32 = {
            \\  (u32) maybe_u32.? = 123
            \\}
            \\(?u32) nonnull_u32 = {
            \\  (u32) nonnull_u32.? = 456
            \\}
        },
    );
}

const File = struct { path: []const u8, source: []const u8 };

fn addGdbTest(
    db: *Debugger,
    name: []const u8,
    target: Target,
    files: []const File,
    commands: []const u8,
    expected_output: []const []const u8,
) void {
    db.addTest(
        name,
        target,
        files,
        &.{
            db.options.gdb orelse return,
            "--batch",
            "--command",
        },
        commands,
        &.{
            "--args",
        },
        expected_output,
    );
}

fn addLldbTest(
    db: *Debugger,
    name: []const u8,
    target: Target,
    files: []const File,
    commands: []const u8,
    expected_output: []const []const u8,
) void {
    db.addTest(
        name,
        target,
        files,
        &.{
            db.options.lldb orelse return,
            "--batch",
            "--source",
        },
        commands,
        &.{
            "--",
        },
        expected_output,
    );
}

/// After a failure while running a script, the debugger starts accepting commands from stdin, and
/// because it is empty, the debugger exits normally with status 0. Choose a non-zero status to
/// return from the debugger script instead to detect it running to completion and indicate success.
const success = 99;

fn addTest(
    db: *Debugger,
    name: []const u8,
    target: Target,
    files: []const File,
    db_argv1: []const []const u8,
    commands: []const u8,
    db_argv2: []const []const u8,
    expected_output: []const []const u8,
) void {
    for (db.options.test_filters) |test_filter| {
        if (std.mem.indexOf(u8, name, test_filter)) |_| return;
    }
    const files_wf = db.b.addWriteFiles();
    const exe = db.b.addExecutable(.{
        .name = name,
        .target = target.resolved,
        .root_source_file = files_wf.add(files[0].path, files[0].source),
        .optimize = target.optimize_mode,
        .link_libc = target.link_libc,
        .single_threaded = target.single_threaded,
        .pic = target.pic,
        .strip = false,
        .use_llvm = false,
        .use_lld = false,
    });
    for (files[1..]) |file| _ = files_wf.add(file.path, file.source);
    const commands_wf = db.b.addWriteFiles();
    const run = std.Build.Step.Run.create(db.b, db.b.fmt("run {s} {s}", .{ name, target.test_name_suffix }));
    run.addArgs(db_argv1);
    run.addFileArg(commands_wf.add(db.b.fmt("{s}.cmd", .{name}), db.b.fmt("{s}\n\nquit {d}\n", .{ commands, success })));
    run.addArgs(db_argv2);
    run.addArtifactArg(exe);
    for (expected_output) |expected| run.addCheck(.{ .expect_stdout_match = db.b.fmt("{s}\n", .{expected}) });
    run.addCheck(.{ .expect_term = .{ .Exited = success } });
    run.setStdIn(.{ .bytes = "" });
    db.root_step.dependOn(&run.step);
}

const Debugger = @This();
const std = @import("std");
