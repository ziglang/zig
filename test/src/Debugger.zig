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
        \\breakpoint delete --force 1
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
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
        },
    );
    db.addLldbTest(
        "pointers",
        target,
        &.{
            .{
                .path = "pointers.zig",
                .source =
                \\const Pointers = struct {
                \\    var array: [7]u32 = .{
                \\        3010,
                \\        3014,
                \\        3018,
                \\        3022,
                \\        3026,
                \\        3030,
                \\        3034,
                \\    };
                \\
                \\    single: *u32 = @ptrFromInt(0x1010),
                \\    single_const: *const u32 = @ptrFromInt(0x1014),
                \\    single_volatile: *volatile u32 = @ptrFromInt(0x1018),
                \\    single_const_volatile: *const volatile u32 = @ptrFromInt(0x101c),
                \\    single_allowzero: *allowzero u32 = @ptrFromInt(0x1020),
                \\    single_const_allowzero: *const allowzero u32 = @ptrFromInt(0x1024),
                \\    single_volatile_allowzero: *volatile allowzero u32 = @ptrFromInt(0x1028),
                \\    single_const_volatile_allowzero: *const volatile allowzero u32 = @ptrFromInt(0x102c),
                \\
                \\    many: [*]u32 = @ptrFromInt(0x2010),
                \\    many_const: [*]const u32 = @ptrFromInt(0x2014),
                \\    many_volatile: [*]volatile u32 = @ptrFromInt(0x2018),
                \\    many_const_volatile: [*]const volatile u32 = @ptrFromInt(0x201c),
                \\    many_allowzero: [*]allowzero u32 = @ptrFromInt(0x2020),
                \\    many_const_allowzero: [*]const allowzero u32 = @ptrFromInt(0x2024),
                \\    many_volatile_allowzero: [*]volatile allowzero u32 = @ptrFromInt(0x2028),
                \\    many_const_volatile_allowzero: [*]const volatile allowzero u32 = @ptrFromInt(0x202c),
                \\    slice: []u32 = array[0..1],
                \\    slice_const: []const u32 = array[0..2],
                \\    slice_volatile: []volatile u32 = array[0..3],
                \\    slice_const_volatile: []const volatile u32 = array[0..4],
                \\    slice_allowzero: []allowzero u32 = array[4..4],
                \\    slice_const_allowzero: []const allowzero u32 = array[4..5],
                \\    slice_volatile_allowzero: []volatile allowzero u32 = array[4..6],
                \\    slice_const_volatile_allowzero: []const volatile allowzero u32 = array[4..7],
                \\
                \\    c: [*c]u32 = @ptrFromInt(0x4010),
                \\    c_const: [*c]const u32 = @ptrFromInt(0x4014),
                \\    c_volatile: [*c]volatile u32 = @ptrFromInt(0x4018),
                \\    c_const_volatile: [*c]const volatile u32 = @ptrFromInt(0x401c),
                \\};
                \\fn testPointers(pointers: Pointers) void {
                \\    _ = pointers;
                \\}
                \\pub fn main() void {
                \\    testPointers(.{});
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file pointers.zig --source-pattern-regexp '_ = pointers;'
        \\process launch
        \\frame variable --show-types pointers
        \\breakpoint delete --force 1
    ,
        &.{
            \\(lldb) frame variable --show-types pointers
            \\(root.pointers.Pointers) pointers = {
            \\  (*u32) single = 0x0000000000001010
            \\  (*const u32) single_const = 0x0000000000001014
            \\  (*volatile u32) single_volatile = 0x0000000000001018
            \\  (*const volatile u32) single_const_volatile = 0x000000000000101c
            \\  (*allowzero u32) single_allowzero = 0x0000000000001020
            \\  (*const allowzero u32) single_const_allowzero = 0x0000000000001024
            \\  (*volatile allowzero u32) single_volatile_allowzero = 0x0000000000001028
            \\  (*const volatile allowzero u32) single_const_volatile_allowzero = 0x000000000000102c
            \\  ([*]u32) many = 0x0000000000002010
            \\  ([*]const u32) many_const = 0x0000000000002014
            \\  ([*]volatile u32) many_volatile = 0x0000000000002018
            \\  ([*]const volatile u32) many_const_volatile = 0x000000000000201c
            \\  ([*]allowzero u32) many_allowzero = 0x0000000000002020
            \\  ([*]const allowzero u32) many_const_allowzero = 0x0000000000002024
            \\  ([*]volatile allowzero u32) many_volatile_allowzero = 0x0000000000002028
            \\  ([*]const volatile allowzero u32) many_const_volatile_allowzero = 0x000000000000202c
            \\  ([]u32) slice = len=1 {
            \\    (u32) [0] = 3010
            \\  }
            \\  ([]const u32) slice_const = len=2 {
            \\    (u32) [0] = 3010
            \\    (u32) [1] = 3014
            \\  }
            \\  ([]volatile u32) slice_volatile = len=3 {
            \\    (u32) [0] = 3010
            \\    (u32) [1] = 3014
            \\    (u32) [2] = 3018
            \\  }
            \\  ([]const volatile u32) slice_const_volatile = len=4 {
            \\    (u32) [0] = 3010
            \\    (u32) [1] = 3014
            \\    (u32) [2] = 3018
            \\    (u32) [3] = 3022
            \\  }
            \\  ([]allowzero u32) slice_allowzero = len=0 {}
            \\  ([]const allowzero u32) slice_const_allowzero = len=1 {
            \\    (u32) [0] = 3026
            \\  }
            \\  ([]volatile allowzero u32) slice_volatile_allowzero = len=2 {
            \\    (u32) [0] = 3026
            \\    (u32) [1] = 3030
            \\  }
            \\  ([]const volatile allowzero u32) slice_const_volatile_allowzero = len=3 {
            \\    (u32) [0] = 3026
            \\    (u32) [1] = 3030
            \\    (u32) [2] = 3034
            \\  }
            \\  ([*c]u32) c = 0x0000000000004010
            \\  ([*c]const u32) c_const = 0x0000000000004014
            \\  ([*c]volatile u32) c_volatile = 0x0000000000004018
            \\  ([*c]const volatile u32) c_const_volatile = 0x000000000000401c
            \\}
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
        },
    );
    db.addLldbTest(
        "enums",
        target,
        &.{
            .{
                .path = "enums.zig",
                .source =
                \\const Enums = struct {
                \\    const Zero = enum(u4) { _ };
                \\    const One = enum { first };
                \\    const Two = enum(i32) { first, second, _ };
                \\    const Three = enum { first, second, third };
                \\
                \\    zero: Zero = @enumFromInt(13),
                \\    one: One = .first,
                \\    two: Two = @enumFromInt(-1234),
                \\    three: Three = .second,
                \\};
                \\fn testEnums(enums: Enums) void {
                \\    _ = enums;
                \\}
                \\pub fn main() void {
                \\    testEnums(.{});
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file enums.zig --source-pattern-regexp '_ = enums;'
        \\process launch
        \\frame variable --show-types enums
        \\breakpoint delete --force 1
    ,
        &.{
            \\(lldb) frame variable --show-types enums
            \\(root.enums.Enums) enums = {
            \\  (root.enums.Enums.Zero) zero = @enumFromInt(13)
            \\  (root.enums.Enums.One) one = .first
            \\  (root.enums.Enums.Two) two = @enumFromInt(-1234)
            \\  (root.enums.Enums.Three) three = .second
            \\}
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
        },
    );
    db.addLldbTest(
        "errors",
        target,
        &.{
            .{
                .path = "errors.zig",
                .source =
                \\const Errors = struct {
                \\    one: error{One} = error.One,
                \\    two: error{One,Two} = error.Two,
                \\    three: error{One,Two,Three} = error.Three,
                \\    any: anyerror = error.Any,
                \\    any_void: anyerror!void = error.NotVoid,
                \\    any_u32: error{One}!u32 = 42,
                \\};
                \\fn testErrors(errors: Errors) void {
                \\    _ = errors;
                \\}
                \\pub fn main() void {
                \\    testErrors(.{});
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file errors.zig --source-pattern-regexp '_ = errors;'
        \\process launch
        \\frame variable --show-types errors
        \\breakpoint delete --force 1
    ,
        &.{
            \\(lldb) frame variable --show-types errors
            \\(root.errors.Errors) errors = {
            \\  (error{One}) one = error.One
            \\  (error{One,Two}) two = error.Two
            \\  (error{One,Two,Three}) three = error.Three
            \\  (anyerror) any = error.Any
            \\  (anyerror!void) any_void = {
            \\    (anyerror) error = error.NotVoid
            \\  }
            \\  (error{One}!u32) any_u32 = {
            \\    (u32) value = 42
            \\  }
            \\}
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
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
        \\breakpoint delete --force 1
        \\
        \\breakpoint set --file optionals.zig --source-pattern-regexp '_ = .{ &null_u32, &nonnull_u32 };'
        \\process continue
        \\frame variable --show-types null_u32 maybe_u32 nonnull_u32
        \\breakpoint delete --force 2
    ,
        &.{
            \\(lldb) frame variable null_u32 maybe_u32 nonnull_u32
            \\(?u32) null_u32 = null
            \\(?u32) maybe_u32 = null
            \\(?u32) nonnull_u32 = (nonnull_u32.? = 456)
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
            ,
            \\(lldb) frame variable --show-types null_u32 maybe_u32 nonnull_u32
            \\(?u32) null_u32 = null
            \\(?u32) maybe_u32 = {
            \\  (u32) maybe_u32.? = 123
            \\}
            \\(?u32) nonnull_u32 = {
            \\  (u32) nonnull_u32.? = 456
            \\}
            \\(lldb) breakpoint delete --force 2
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
        },
    );
    db.addLldbTest(
        "unions",
        target,
        &.{
            .{
                .path = "unions.zig",
                .source =
                \\const Unions = struct {
                \\    const Enum = enum { first, second, third };
                \\    const Untagged = extern union {
                \\        u32: u32,
                \\        i32: i32,
                \\        f32: f32,
                \\    };
                \\    const SafetyTagged = union {
                \\        void: void,
                \\        en: Enum,
                \\        eu: error{Error}!Enum,
                \\    };
                \\    const Tagged = union(enum) {
                \\        void: void,
                \\        en: Enum,
                \\        eu: error{Error}!Enum,
                \\    };
                \\
                \\    untagged: Untagged = .{ .f32 = -1.5 },
                \\    safety_tagged: SafetyTagged = .{ .en = .second },
                \\    tagged: Tagged = .{ .eu = error.Error },
                \\};
                \\fn testUnions(unions: Unions) void {
                \\    _ = unions;
                \\}
                \\pub fn main() void {
                \\    testUnions(.{});
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file unions.zig --source-pattern-regexp '_ = unions;'
        \\process launch
        \\frame variable --show-types unions
        \\breakpoint delete --force 1
    ,
        &.{
            \\(lldb) frame variable --show-types unions
            \\(root.unions.Unions) unions = {
            \\  (root.unions.Unions.Untagged) untagged = {
            \\    (u32) u32 = 3217031168
            \\    (i32) i32 = -1077936128
            \\    (f32) f32 = -1.5
            \\  }
            \\  (root.unions.Unions.SafetyTagged) safety_tagged = {
            \\    (root.unions.Unions.Enum) en = .second
            \\  }
            \\  (root.unions.Unions.Tagged) tagged = {
            \\    (error{Error}!root.unions.Unions.Enum) eu = {
            \\      (error{Error}) error = error.Error
            \\    }
            \\  }
            \\}
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
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
        \\breakpoint delete --force 1
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
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
        },
    );
    db.addLldbTest(
        "inline_call",
        target,
        &.{
            .{
                .path = "main.zig",
                .source =
                \\const module = @import("module");
                \\pub fn main() void {
                \\    fa(12);
                \\    fb(34);
                \\    module.fc(56);
                \\    module.fd(78);
                \\}
                \\fn fa(pa: u32) void {
                \\    const la = ~pa;
                \\    _ = la;
                \\}
                \\inline fn fb(pb: u32) void {
                \\    const lb = ~pb;
                \\    _ = lb;
                \\}
                \\
                ,
            },
            .{
                .import = "module",
                .path = "module.zig",
                .source =
                \\pub fn fc(pc: u32) void {
                \\    const lc = ~pc;
                \\    _ = lc;
                \\}
                \\pub inline fn fd(pd: u32) void {
                \\    const ld = ~pd;
                \\    _ = ld;
                \\}
                \\
                ,
            },
        },
        \\settings set frame-format 'frame #${frame.index}:{ ${module.file.basename}{\`${function.name-with-args}{${frame.no-debug}${function.pc-offset}}}}{ at ${line.file.basename}:${line.number}{:${line.column}}}{${function.is-optimized} [opt]}{${frame.is-artificial} [artificial]}\n'
        \\
        \\breakpoint set --file main.zig --source-pattern-regexp '_ = la;'
        \\process launch
        \\frame variable pa la
        \\thread backtrace --count 2
        \\breakpoint delete --force 1
        \\
        \\breakpoint set --file main.zig --source-pattern-regexp '_ = lb;'
        \\process continue
        \\frame variable pb lb
        \\thread backtrace --count 2
        \\breakpoint delete --force 2
        \\
        \\breakpoint set --file module.zig --source-pattern-regexp '_ = lc;'
        \\process continue
        \\frame variable pc lc
        \\thread backtrace --count 2
        \\breakpoint delete --force 3
        \\
        \\breakpoint set --file module.zig --line 7
        \\process continue
        \\frame variable pd ld
        \\thread backtrace --count 2
        \\breakpoint delete --force 4
    ,
        &.{
            \\(lldb) frame variable pa la
            \\(u32) pa = 12
            \\(u32) la = 4294967283
            \\(lldb) thread backtrace --count 2
            \\* thread #1, name = 'inline_call', stop reason = breakpoint 1.1
            \\  * frame #0: inline_call`main.fa(pa=12) at main.zig:10:5
            \\    frame #1: inline_call`main.main at main.zig:3:7
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
            ,
            \\(lldb) frame variable pb lb
            \\(u32) pb = 34
            \\(u32) lb = 4294967261
            \\(lldb) thread backtrace --count 2
            \\* thread #1, name = 'inline_call', stop reason = breakpoint 2.1
            \\  * frame #0: inline_call`main.main [inlined] fb(pb=34) at main.zig:14:5
            \\    frame #1: inline_call`main.main at main.zig:4:7
            \\(lldb) breakpoint delete --force 2
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
            ,
            \\(lldb) frame variable pc lc
            \\(u32) pc = 56
            \\(u32) lc = 4294967239
            \\(lldb) thread backtrace --count 2
            \\* thread #1, name = 'inline_call', stop reason = breakpoint 3.1
            \\  * frame #0: inline_call`module.fc(pc=56) at module.zig:3:5
            \\    frame #1: inline_call`main.main at main.zig:5:14
            \\(lldb) breakpoint delete --force 3
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
            ,
            \\(lldb) frame variable pd ld
            \\(u32) pd = 78
            \\(u32) ld = 4294967217
            \\(lldb) thread backtrace --count 2
            \\* thread #1, name = 'inline_call', stop reason = breakpoint 4.1
            \\  * frame #0: inline_call`main.main [inlined] fd(pd=78) at module.zig:7:5
            \\    frame #1: inline_call`main.main at main.zig:6:14
            \\(lldb) breakpoint delete --force 4
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
        },
    );
    db.addLldbTest(
        "link_object",
        target,
        &.{
            .{
                .path = "main.zig",
                .source =
                \\extern fn fabsf(f32) f32;
                \\pub fn main() void {
                \\    var x: f32 = -1234.5;
                \\    x = fabsf(x);
                \\    _ = &x;
                \\}
                ,
            },
        },
        \\breakpoint set --file main.zig --source-pattern-regexp 'x = fabsf\(x\);'
        \\process launch
        \\frame variable x
        \\breakpoint delete --force 1
        \\
        \\breakpoint set --file main.zig --source-pattern-regexp '_ = &x;'
        \\process continue
        \\frame variable x
        \\breakpoint delete --force 2
    ,
        &.{
            \\(lldb) frame variable x
            \\(f32) x = -1234.5
            \\(lldb) breakpoint delete --force 1
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
            ,
            \\(lldb) frame variable x
            \\(f32) x = 1234.5
            \\(lldb) breakpoint delete --force 2
            \\1 breakpoints deleted; 0 breakpoint locations disabled.
        },
    );
}

const File = struct { import: ?[]const u8 = null, path: []const u8, source: []const u8 };

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
    for (files[1..]) |file| {
        const path = files_wf.add(file.path, file.source);
        if (file.import) |import| exe.root_module.addImport(import, db.b.createModule(.{
            .root_source_file = path,
        }));
    }
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
