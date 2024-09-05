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
                \\    single_allowzero_const: *allowzero const u32 = @ptrFromInt(0x1024),
                \\    single_allowzero_volatile: *allowzero volatile u32 = @ptrFromInt(0x1028),
                \\    single_allowzero_const_volatile: *allowzero const volatile u32 = @ptrFromInt(0x102c),
                \\
                \\    many: [*]u32 = @ptrFromInt(0x2010),
                \\    many_const: [*]const u32 = @ptrFromInt(0x2014),
                \\    many_volatile: [*]volatile u32 = @ptrFromInt(0x2018),
                \\    many_const_volatile: [*]const volatile u32 = @ptrFromInt(0x201c),
                \\    many_allowzero: [*]allowzero u32 = @ptrFromInt(0x2020),
                \\    many_allowzero_const: [*]allowzero const u32 = @ptrFromInt(0x2024),
                \\    many_allowzero_volatile: [*]allowzero volatile u32 = @ptrFromInt(0x2028),
                \\    many_allowzero_const_volatile: [*]allowzero const volatile u32 = @ptrFromInt(0x202c),
                \\    slice: []u32 = array[0..1],
                \\    slice_const: []const u32 = array[0..2],
                \\    slice_volatile: []volatile u32 = array[0..3],
                \\    slice_const_volatile: []const volatile u32 = array[0..4],
                \\    slice_allowzero: []allowzero u32 = array[4..4],
                \\    slice_allowzero_const: []allowzero const u32 = array[4..5],
                \\    slice_allowzero_volatile: []allowzero volatile u32 = array[4..6],
                \\    slice_allowzero_const_volatile: []allowzero const volatile u32 = array[4..7],
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
            \\  (*allowzero const u32) single_allowzero_const = 0x0000000000001024
            \\  (*allowzero volatile u32) single_allowzero_volatile = 0x0000000000001028
            \\  (*allowzero const volatile u32) single_allowzero_const_volatile = 0x000000000000102c
            \\  ([*]u32) many = 0x0000000000002010
            \\  ([*]const u32) many_const = 0x0000000000002014
            \\  ([*]volatile u32) many_volatile = 0x0000000000002018
            \\  ([*]const volatile u32) many_const_volatile = 0x000000000000201c
            \\  ([*]allowzero u32) many_allowzero = 0x0000000000002020
            \\  ([*]allowzero const u32) many_allowzero_const = 0x0000000000002024
            \\  ([*]allowzero volatile u32) many_allowzero_volatile = 0x0000000000002028
            \\  ([*]allowzero const volatile u32) many_allowzero_const_volatile = 0x000000000000202c
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
            \\  ([]allowzero const u32) slice_allowzero_const = len=1 {
            \\    (u32) [0] = 3026
            \\  }
            \\  ([]allowzero volatile u32) slice_allowzero_volatile = len=2 {
            \\    (u32) [0] = 3026
            \\    (u32) [1] = 3030
            \\  }
            \\  ([]allowzero const volatile u32) slice_allowzero_const_volatile = len=3 {
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
        "strings",
        target,
        &.{
            .{
                .path = "strings.zig",
                .source =
                \\const Strings = struct {
                \\    c_ptr: [*c]const u8 = "c_ptr\x07\x08\t",
                \\    many_ptr: [*:0]const u8 = "many_ptr\n\x0b\x0c",
                \\    ptr_array: *const [12:0]u8 = "ptr_array\x00\r\x1b",
                \\    slice: [:0]const u8 = "slice\"\'\\\x00",
                \\};
                \\fn testStrings(strings: Strings) void {
                \\    _ = strings;
                \\}
                \\pub fn main() void {
                \\    testStrings(.{});
                \\}
                \\
                ,
            },
        },
        \\breakpoint set --file strings.zig --source-pattern-regexp '_ = strings;'
        \\process launch
        \\frame variable --show-types strings.slice
        \\frame variable --show-types --format character strings.slice
        \\frame variable --show-types --format c-string strings
        \\breakpoint delete --force 1
    ,
        &.{
            \\(lldb) frame variable --show-types strings.slice
            \\([:0]const u8) strings.slice = len=9 {
            \\  (u8) [0] = 115
            \\  (u8) [1] = 108
            \\  (u8) [2] = 105
            \\  (u8) [3] = 99
            \\  (u8) [4] = 101
            \\  (u8) [5] = 34
            \\  (u8) [6] = 39
            \\  (u8) [7] = 92
            \\  (u8) [8] = 0
            \\}
            \\(lldb) frame variable --show-types --format character strings.slice
            \\([:0]const u8) strings.slice = len=9 {
            \\  (u8) [0] = 's'
            \\  (u8) [1] = 'l'
            \\  (u8) [2] = 'i'
            \\  (u8) [3] = 'c'
            \\  (u8) [4] = 'e'
            \\  (u8) [5] = '\"'
            \\  (u8) [6] = '\''
            \\  (u8) [7] = '\\'
            \\  (u8) [8] = '\x00'
            \\}
            \\(lldb) frame variable --show-types --format c-string strings
            \\(root.strings.Strings) strings = {
            \\  ([*c]const u8) c_ptr = "c_ptr\x07\x08\t"
            \\  ([*:0]const u8) many_ptr = "many_ptr\n\x0b\x0c"
            \\  (*const [12:0]u8) ptr_array = "ptr_array\x00\r\x1b"
            \\  ([:0]const u8) slice = "slice\"\'\\\x00" len=9 {
            \\    (u8) [0] = "s"
            \\    (u8) [1] = "l"
            \\    (u8) [2] = "i"
            \\    (u8) [3] = "c"
            \\    (u8) [4] = "e"
            \\    (u8) [5] = "\""
            \\    (u8) [6] = "\'"
            \\    (u8) [7] = "\\"
            \\    (u8) [8] = "\x00"
            \\  }
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
        \\expression --show-types -- Enums
        \\frame variable --show-types enums
        \\breakpoint delete --force 1
    ,
        &.{
            \\(lldb) expression --show-types -- Enums
            \\(type) Enums = struct {
            \\  (type) Zero = enum {}
            \\  (type) One = enum {
            \\    (root.enums.Enums.One) first = .first
            \\  }
            \\  (type) Two = enum {
            \\    (root.enums.Enums.Two) first = .first
            \\    (root.enums.Enums.Two) second = .second
            \\  }
            \\  (type) Three = enum {
            \\    (root.enums.Enums.Three) first = .first
            \\    (root.enums.Enums.Three) second = .second
            \\    (root.enums.Enums.Three) third = .third
            \\  }
            \\}
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
                \\    const Zero = error{};
                \\    const One = Zero || error{One};
                \\    const Two = One || error{Two};
                \\    const Three = Two || error{Three};
                \\
                \\    one: One = error.One,
                \\    two: Two = error.Two,
                \\    three: Three = error.Three,
                \\    any: anyerror = error.Any,
                \\    any_void: anyerror!void = error.NotVoid,
                \\    any_u32: One!u32 = 42,
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
        \\expression --show-types -- Errors
        \\frame variable --show-types errors
        \\breakpoint delete --force 1
    ,
        &.{
            \\(lldb) expression --show-types -- Errors
            \\(type) Errors = struct {
            \\  (type) Zero = error {}
            \\  (type) One = error {
            \\    (error{One}) One = error.One
            \\  }
            \\  (type) Two = error {
            \\    (error{One,Two}) One = error.One
            \\    (error{One,Two}) Two = error.Two
            \\  }
            \\  (type) Three = error {
            \\    (error{One,Two,Three}) One = error.One
            \\    (error{One,Two,Three}) Two = error.Two
            \\    (error{One,Two,Three}) Three = error.Three
            \\  }
            \\}
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
        \\expression --show-types -- Unions
        \\frame variable --show-types unions
        \\breakpoint delete --force 1
    ,
        &.{
            \\(lldb) expression --show-types -- Unions
            \\(type) Unions = struct {
            \\  (type) Untagged = union {}
            \\  (type) SafetyTagged = union(enum) {
            \\    (@typeInfo(unions.Unions.SafetyTagged).@"union".tag_type.?) void = .void
            \\    (@typeInfo(unions.Unions.SafetyTagged).@"union".tag_type.?) en = .en
            \\    (@typeInfo(unions.Unions.SafetyTagged).@"union".tag_type.?) eu = .eu
            \\  }
            \\  (type) Enum = enum {
            \\    (root.unions.Unions.Enum) first = .first
            \\    (root.unions.Unions.Enum) second = .second
            \\    (root.unions.Unions.Enum) third = .third
            \\  }
            \\  (type) Tagged = union(enum) {
            \\    (@typeInfo(unions.Unions.Tagged).@"union".tag_type.?) void = .void
            \\    (@typeInfo(unions.Unions.Tagged).@"union".tag_type.?) en = .en
            \\    (@typeInfo(unions.Unions.Tagged).@"union".tag_type.?) eu = .eu
            \\  }
            \\}
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
                .path = "root0.zig",
                .source =
                \\const root0 = @This();
                \\pub const root1 = @import("root1.zig");
                \\const mod0 = @import("module");
                \\const mod1 = mod0.mod1;
                \\pub fn r0pf(r0pa: u32) void {
                \\    root0.r0cf(r0pa ^ 1);
                \\    root0.r0cfi(r0pa ^ 2);
                \\    root1.r1cf(r0pa ^ 3);
                \\    root1.r1cfi(r0pa ^ 4);
                \\    mod0.m0cf(r0pa ^ 5);
                \\    mod0.m0cfi(r0pa ^ 6);
                \\    mod1.m1cf(r0pa ^ 7);
                \\    mod1.m1cfi(r0pa ^ 8);
                \\}
                \\pub inline fn r0pfi(r0pai: u32) void {
                \\    root0.r0cf(r0pai ^ 1);
                \\    root0.r0cfi(r0pai ^ 2);
                \\    root1.r1cf(r0pai ^ 3);
                \\    root1.r1cfi(r0pai ^ 4);
                \\    mod0.m0cf(r0pai ^ 5);
                \\    mod0.m0cfi(r0pai ^ 6);
                \\    mod1.m1cf(r0pai ^ 7);
                \\    mod1.m1cfi(r0pai ^ 8);
                \\}
                \\pub fn r0cf(r0ca: u32) void {
                \\    _ = r0ca;
                \\}
                \\pub inline fn r0cfi(r0cai: u32) void {
                \\    _ = r0cai;
                \\}
                \\pub fn main() void {
                \\    root0.r0pf(12);
                \\    root0.r0pfi(23);
                \\    root1.r1pf(34);
                \\    root1.r1pfi(45);
                \\    mod0.m0pf(56);
                \\    mod0.m0pfi(67);
                \\    mod1.m1pf(78);
                \\    mod1.m1pfi(89);
                \\}
                \\
                ,
            },
            .{
                .path = "root1.zig",
                .source =
                \\const root0 = @import("root0.zig");
                \\const root1 = @This();
                \\const mod0 = @import("module");
                \\const mod1 = mod0.mod1;
                \\pub fn r1pf(r1pa: u32) void {
                \\    root0.r0cf(r1pa ^ 1);
                \\    root0.r0cfi(r1pa ^ 2);
                \\    root1.r1cf(r1pa ^ 3);
                \\    root1.r1cfi(r1pa ^ 4);
                \\    mod0.m0cf(r1pa ^ 5);
                \\    mod0.m0cfi(r1pa ^ 6);
                \\    mod1.m1cf(r1pa ^ 7);
                \\    mod1.m1cfi(r1pa ^ 8);
                \\}
                \\pub inline fn r1pfi(r1pai: u32) void {
                \\    root0.r0cf(r1pai ^ 1);
                \\    root0.r0cfi(r1pai ^ 2);
                \\    root1.r1cf(r1pai ^ 3);
                \\    root1.r1cfi(r1pai ^ 4);
                \\    mod0.m0cf(r1pai ^ 5);
                \\    mod0.m0cfi(r1pai ^ 6);
                \\    mod1.m1cf(r1pai ^ 7);
                \\    mod1.m1cfi(r1pai ^ 8);
                \\}
                \\pub fn r1cf(r1ca: u32) void {
                \\    _ = r1ca;
                \\}
                \\pub inline fn r1cfi(r1cai: u32) void {
                \\    _ = r1cai;
                \\}
                \\
                ,
            },
            .{
                .import = "module",
                .path = "mod0.zig",
                .source =
                \\const root0 = @import("root");
                \\const root1 = root0.root1;
                \\const mod0 = @This();
                \\pub const mod1 = @import("mod1.zig");
                \\pub fn m0pf(m0pa: u32) void {
                \\    root0.r0cf(m0pa ^ 1);
                \\    root0.r0cfi(m0pa ^ 2);
                \\    root1.r1cf(m0pa ^ 3);
                \\    root1.r1cfi(m0pa ^ 4);
                \\    mod0.m0cf(m0pa ^ 5);
                \\    mod0.m0cfi(m0pa ^ 6);
                \\    mod1.m1cf(m0pa ^ 7);
                \\    mod1.m1cfi(m0pa ^ 8);
                \\}
                \\pub inline fn m0pfi(m0pai: u32) void {
                \\    root0.r0cf(m0pai ^ 1);
                \\    root0.r0cfi(m0pai ^ 2);
                \\    root1.r1cf(m0pai ^ 3);
                \\    root1.r1cfi(m0pai ^ 4);
                \\    mod0.m0cf(m0pai ^ 5);
                \\    mod0.m0cfi(m0pai ^ 6);
                \\    mod1.m1cf(m0pai ^ 7);
                \\    mod1.m1cfi(m0pai ^ 8);
                \\}
                \\pub fn m0cf(m0ca: u32) void {
                \\    _ = m0ca;
                \\}
                \\pub inline fn m0cfi(m0cai: u32) void {
                \\    _ = m0cai;
                \\}
                \\
                ,
            },
            .{
                .path = "mod1.zig",
                .source =
                \\const root0 = @import("root");
                \\const root1 = root0.root1;
                \\const mod0 = @import("mod0.zig");
                \\const mod1 = @This();
                \\pub fn m1pf(m1pa: u32) void {
                \\    root0.r0cf(m1pa ^ 1);
                \\    root0.r0cfi(m1pa ^ 2);
                \\    root1.r1cf(m1pa ^ 3);
                \\    root1.r1cfi(m1pa ^ 4);
                \\    mod0.m0cf(m1pa ^ 5);
                \\    mod0.m0cfi(m1pa ^ 6);
                \\    mod1.m1cf(m1pa ^ 7);
                \\    mod1.m1cfi(m1pa ^ 8);
                \\}
                \\pub inline fn m1pfi(m1pai: u32) void {
                \\    root0.r0cf(m1pai ^ 1);
                \\    root0.r0cfi(m1pai ^ 2);
                \\    root1.r1cf(m1pai ^ 3);
                \\    root1.r1cfi(m1pai ^ 4);
                \\    mod0.m0cf(m1pai ^ 5);
                \\    mod0.m0cfi(m1pai ^ 6);
                \\    mod1.m1cf(m1pai ^ 7);
                \\    mod1.m1cfi(m1pai ^ 8);
                \\}
                \\pub fn m1cf(m1ca: u32) void {
                \\    _ = m1ca;
                \\}
                \\pub inline fn m1cfi(m1cai: u32) void {
                \\    _ = m1cai;
                \\}
                \\
                ,
            },
        },
        \\settings set frame-format 'frame #${frame.index}:{ ${module.file.basename}{\`${function.name-with-args}{${frame.no-debug}${function.pc-offset}}}}{ at ${line.file.basename}:${line.number}{:${line.column}}}{${function.is-optimized} [opt]}{${frame.is-artificial} [artificial]}\n'
        \\
        \\breakpoint set --file root0.zig --line 26
        \\breakpoint set --file root0.zig --line 29
        \\breakpoint set --file root1.zig --line 26
        \\breakpoint set --file root1.zig --line 29
        \\breakpoint set --file mod0.zig --line 26
        \\breakpoint set --file mod0.zig --line 29
        \\breakpoint set --file mod1.zig --line 26
        \\breakpoint set --file mod1.zig --line 29
        \\
        \\process launch
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
        \\process continue
        \\thread backtrace --count 3
    ,
        &.{
            \\  * frame #0: inline_call`root0.r0cf(r0ca=13) at root0.zig:26:5
            \\    frame #1: inline_call`root0.r0pf(r0pa=12) at root0.zig:6:15
            \\    frame #2: inline_call`root0.main at root0.zig:32:15
            ,
            \\  * frame #0: inline_call`root0.r0pf [inlined] r0cfi(r0cai=14) at root0.zig:29:5
            \\    frame #1: inline_call`root0.r0pf(r0pa=12) at root0.zig:7:16
            \\    frame #2: inline_call`root0.main at root0.zig:32:15
            ,
            \\  * frame #0: inline_call`root1.r1cf(r1ca=15) at root1.zig:26:5
            \\    frame #1: inline_call`root0.r0pf(r0pa=12) at root0.zig:8:15
            \\    frame #2: inline_call`root0.main at root0.zig:32:15
            ,
            \\  * frame #0: inline_call`root0.r0pf [inlined] r1cfi(r1cai=8) at root1.zig:29:5
            \\    frame #1: inline_call`root0.r0pf(r0pa=12) at root0.zig:9:16
            \\    frame #2: inline_call`root0.main at root0.zig:32:15
            ,
            \\  * frame #0: inline_call`mod0.m0cf(m0ca=9) at mod0.zig:26:5
            \\    frame #1: inline_call`root0.r0pf(r0pa=12) at root0.zig:10:14
            \\    frame #2: inline_call`root0.main at root0.zig:32:15
            ,
            \\  * frame #0: inline_call`root0.r0pf [inlined] m0cfi(m0cai=10) at mod0.zig:29:5
            \\    frame #1: inline_call`root0.r0pf(r0pa=12) at root0.zig:11:15
            \\    frame #2: inline_call`root0.main at root0.zig:32:15
            ,
            \\  * frame #0: inline_call`mod1.m1cf(m1ca=11) at mod1.zig:26:5
            \\    frame #1: inline_call`root0.r0pf(r0pa=12) at root0.zig:12:14
            \\    frame #2: inline_call`root0.main at root0.zig:32:15
            ,
            \\  * frame #0: inline_call`root0.r0pf [inlined] m1cfi(m1cai=4) at mod1.zig:29:5
            \\    frame #1: inline_call`root0.r0pf(r0pa=12) at root0.zig:13:15
            \\    frame #2: inline_call`root0.main at root0.zig:32:15
            ,
            \\  * frame #0: inline_call`root0.r0cf(r0ca=22) at root0.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] r0pfi(r0pai=23) at root0.zig:16:15
            \\    frame #2: inline_call`root0.main at root0.zig:33:16
            ,
            \\  * frame #0: inline_call`root0.main [inlined] r0cfi(r0cai=21) at root0.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] r0pfi(r0pai=23) at root0.zig:17:16
            \\    frame #2: inline_call`root0.main at root0.zig:33:16
            ,
            \\  * frame #0: inline_call`root1.r1cf(r1ca=20) at root1.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] r0pfi(r0pai=23) at root0.zig:18:15
            \\    frame #2: inline_call`root0.main at root0.zig:33:16
            ,
            \\  * frame #0: inline_call`root0.main [inlined] r1cfi(r1cai=19) at root1.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] r0pfi(r0pai=23) at root0.zig:19:16
            \\    frame #2: inline_call`root0.main at root0.zig:33:16
            ,
            \\  * frame #0: inline_call`mod0.m0cf(m0ca=18) at mod0.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] r0pfi(r0pai=23) at root0.zig:20:14
            \\    frame #2: inline_call`root0.main at root0.zig:33:16
            ,
            \\  * frame #0: inline_call`root0.main [inlined] m0cfi(m0cai=17) at mod0.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] r0pfi(r0pai=23) at root0.zig:21:15
            \\    frame #2: inline_call`root0.main at root0.zig:33:16
            ,
            \\  * frame #0: inline_call`mod1.m1cf(m1ca=16) at mod1.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] r0pfi(r0pai=23) at root0.zig:22:14
            \\    frame #2: inline_call`root0.main at root0.zig:33:16
            ,
            \\  * frame #0: inline_call`root0.main [inlined] m1cfi(m1cai=31) at mod1.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] r0pfi(r0pai=23) at root0.zig:23:15
            \\    frame #2: inline_call`root0.main at root0.zig:33:16
            ,
            \\  * frame #0: inline_call`root0.r0cf(r0ca=35) at root0.zig:26:5
            \\    frame #1: inline_call`root1.r1pf(r1pa=34) at root1.zig:6:15
            \\    frame #2: inline_call`root0.main at root0.zig:34:15
            ,
            \\  * frame #0: inline_call`root1.r1pf [inlined] r0cfi(r0cai=32) at root0.zig:29:5
            \\    frame #1: inline_call`root1.r1pf(r1pa=34) at root1.zig:7:16
            \\    frame #2: inline_call`root0.main at root0.zig:34:15
            ,
            \\  * frame #0: inline_call`root1.r1cf(r1ca=33) at root1.zig:26:5
            \\    frame #1: inline_call`root1.r1pf(r1pa=34) at root1.zig:8:15
            \\    frame #2: inline_call`root0.main at root0.zig:34:15
            ,
            \\  * frame #0: inline_call`root1.r1pf [inlined] r1cfi(r1cai=38) at root1.zig:29:5
            \\    frame #1: inline_call`root1.r1pf(r1pa=34) at root1.zig:9:16
            \\    frame #2: inline_call`root0.main at root0.zig:34:15
            ,
            \\  * frame #0: inline_call`mod0.m0cf(m0ca=39) at mod0.zig:26:5
            \\    frame #1: inline_call`root1.r1pf(r1pa=34) at root1.zig:10:14
            \\    frame #2: inline_call`root0.main at root0.zig:34:15
            ,
            \\  * frame #0: inline_call`root1.r1pf [inlined] m0cfi(m0cai=36) at mod0.zig:29:5
            \\    frame #1: inline_call`root1.r1pf(r1pa=34) at root1.zig:11:15
            \\    frame #2: inline_call`root0.main at root0.zig:34:15
            ,
            \\  * frame #0: inline_call`mod1.m1cf(m1ca=37) at mod1.zig:26:5
            \\    frame #1: inline_call`root1.r1pf(r1pa=34) at root1.zig:12:14
            \\    frame #2: inline_call`root0.main at root0.zig:34:15
            ,
            \\  * frame #0: inline_call`root1.r1pf [inlined] m1cfi(m1cai=42) at mod1.zig:29:5
            \\    frame #1: inline_call`root1.r1pf(r1pa=34) at root1.zig:13:15
            \\    frame #2: inline_call`root0.main at root0.zig:34:15
            ,
            \\  * frame #0: inline_call`root0.r0cf(r0ca=44) at root0.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] r1pfi(r1pai=45) at root1.zig:16:15
            \\    frame #2: inline_call`root0.main at root0.zig:35:16
            ,
            \\  * frame #0: inline_call`root0.main [inlined] r0cfi(r0cai=47) at root0.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] r1pfi(r1pai=45) at root1.zig:17:16
            \\    frame #2: inline_call`root0.main at root0.zig:35:16
            ,
            \\  * frame #0: inline_call`root1.r1cf(r1ca=46) at root1.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] r1pfi(r1pai=45) at root1.zig:18:15
            \\    frame #2: inline_call`root0.main at root0.zig:35:16
            ,
            \\  * frame #0: inline_call`root0.main [inlined] r1cfi(r1cai=41) at root1.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] r1pfi(r1pai=45) at root1.zig:19:16
            \\    frame #2: inline_call`root0.main at root0.zig:35:16
            ,
            \\  * frame #0: inline_call`mod0.m0cf(m0ca=40) at mod0.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] r1pfi(r1pai=45) at root1.zig:20:14
            \\    frame #2: inline_call`root0.main at root0.zig:35:16
            ,
            \\  * frame #0: inline_call`root0.main [inlined] m0cfi(m0cai=43) at mod0.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] r1pfi(r1pai=45) at root1.zig:21:15
            \\    frame #2: inline_call`root0.main at root0.zig:35:16
            ,
            \\  * frame #0: inline_call`mod1.m1cf(m1ca=42) at mod1.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] r1pfi(r1pai=45) at root1.zig:22:14
            \\    frame #2: inline_call`root0.main at root0.zig:35:16
            ,
            \\  * frame #0: inline_call`root0.main [inlined] m1cfi(m1cai=37) at mod1.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] r1pfi(r1pai=45) at root1.zig:23:15
            \\    frame #2: inline_call`root0.main at root0.zig:35:16
            ,
            \\  * frame #0: inline_call`root0.r0cf(r0ca=57) at root0.zig:26:5
            \\    frame #1: inline_call`mod0.m0pf(m0pa=56) at mod0.zig:6:15
            \\    frame #2: inline_call`root0.main at root0.zig:36:14
            ,
            \\  * frame #0: inline_call`mod0.m0pf [inlined] r0cfi(r0cai=58) at root0.zig:29:5
            \\    frame #1: inline_call`mod0.m0pf(m0pa=56) at mod0.zig:7:16
            \\    frame #2: inline_call`root0.main at root0.zig:36:14
            ,
            \\  * frame #0: inline_call`root1.r1cf(r1ca=59) at root1.zig:26:5
            \\    frame #1: inline_call`mod0.m0pf(m0pa=56) at mod0.zig:8:15
            \\    frame #2: inline_call`root0.main at root0.zig:36:14
            ,
            \\  * frame #0: inline_call`mod0.m0pf [inlined] r1cfi(r1cai=60) at root1.zig:29:5
            \\    frame #1: inline_call`mod0.m0pf(m0pa=56) at mod0.zig:9:16
            \\    frame #2: inline_call`root0.main at root0.zig:36:14
            ,
            \\  * frame #0: inline_call`mod0.m0cf(m0ca=61) at mod0.zig:26:5
            \\    frame #1: inline_call`mod0.m0pf(m0pa=56) at mod0.zig:10:14
            \\    frame #2: inline_call`root0.main at root0.zig:36:14
            ,
            \\  * frame #0: inline_call`mod0.m0pf [inlined] m0cfi(m0cai=62) at mod0.zig:29:5
            \\    frame #1: inline_call`mod0.m0pf(m0pa=56) at mod0.zig:11:15
            \\    frame #2: inline_call`root0.main at root0.zig:36:14
            ,
            \\  * frame #0: inline_call`mod1.m1cf(m1ca=63) at mod1.zig:26:5
            \\    frame #1: inline_call`mod0.m0pf(m0pa=56) at mod0.zig:12:14
            \\    frame #2: inline_call`root0.main at root0.zig:36:14
            ,
            \\  * frame #0: inline_call`mod0.m0pf [inlined] m1cfi(m1cai=48) at mod1.zig:29:5
            \\    frame #1: inline_call`mod0.m0pf(m0pa=56) at mod0.zig:13:15
            \\    frame #2: inline_call`root0.main at root0.zig:36:14
            ,
            \\  * frame #0: inline_call`root0.r0cf(r0ca=66) at root0.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] m0pfi(m0pai=67) at mod0.zig:16:15
            \\    frame #2: inline_call`root0.main at root0.zig:37:15
            ,
            \\  * frame #0: inline_call`root0.main [inlined] r0cfi(r0cai=65) at root0.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] m0pfi(m0pai=67) at mod0.zig:17:16
            \\    frame #2: inline_call`root0.main at root0.zig:37:15
            ,
            \\  * frame #0: inline_call`root1.r1cf(r1ca=64) at root1.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] m0pfi(m0pai=67) at mod0.zig:18:15
            \\    frame #2: inline_call`root0.main at root0.zig:37:15
            ,
            \\  * frame #0: inline_call`root0.main [inlined] r1cfi(r1cai=71) at root1.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] m0pfi(m0pai=67) at mod0.zig:19:16
            \\    frame #2: inline_call`root0.main at root0.zig:37:15
            ,
            \\  * frame #0: inline_call`mod0.m0cf(m0ca=70) at mod0.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] m0pfi(m0pai=67) at mod0.zig:20:14
            \\    frame #2: inline_call`root0.main at root0.zig:37:15
            ,
            \\  * frame #0: inline_call`root0.main [inlined] m0cfi(m0cai=69) at mod0.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] m0pfi(m0pai=67) at mod0.zig:21:15
            \\    frame #2: inline_call`root0.main at root0.zig:37:15
            ,
            \\  * frame #0: inline_call`mod1.m1cf(m1ca=68) at mod1.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] m0pfi(m0pai=67) at mod0.zig:22:14
            \\    frame #2: inline_call`root0.main at root0.zig:37:15
            ,
            \\  * frame #0: inline_call`root0.main [inlined] m1cfi(m1cai=75) at mod1.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] m0pfi(m0pai=67) at mod0.zig:23:15
            \\    frame #2: inline_call`root0.main at root0.zig:37:15
            ,
            \\  * frame #0: inline_call`root0.r0cf(r0ca=79) at root0.zig:26:5
            \\    frame #1: inline_call`mod1.m1pf(m1pa=78) at mod1.zig:6:15
            \\    frame #2: inline_call`root0.main at root0.zig:38:14
            ,
            \\  * frame #0: inline_call`mod1.m1pf [inlined] r0cfi(r0cai=76) at root0.zig:29:5
            \\    frame #1: inline_call`mod1.m1pf(m1pa=78) at mod1.zig:7:16
            \\    frame #2: inline_call`root0.main at root0.zig:38:14
            ,
            \\  * frame #0: inline_call`root1.r1cf(r1ca=77) at root1.zig:26:5
            \\    frame #1: inline_call`mod1.m1pf(m1pa=78) at mod1.zig:8:15
            \\    frame #2: inline_call`root0.main at root0.zig:38:14
            ,
            \\  * frame #0: inline_call`mod1.m1pf [inlined] r1cfi(r1cai=74) at root1.zig:29:5
            \\    frame #1: inline_call`mod1.m1pf(m1pa=78) at mod1.zig:9:16
            \\    frame #2: inline_call`root0.main at root0.zig:38:14
            ,
            \\  * frame #0: inline_call`mod0.m0cf(m0ca=75) at mod0.zig:26:5
            \\    frame #1: inline_call`mod1.m1pf(m1pa=78) at mod1.zig:10:14
            \\    frame #2: inline_call`root0.main at root0.zig:38:14
            ,
            \\  * frame #0: inline_call`mod1.m1pf [inlined] m0cfi(m0cai=72) at mod0.zig:29:5
            \\    frame #1: inline_call`mod1.m1pf(m1pa=78) at mod1.zig:11:15
            \\    frame #2: inline_call`root0.main at root0.zig:38:14
            ,
            \\  * frame #0: inline_call`mod1.m1cf(m1ca=73) at mod1.zig:26:5
            \\    frame #1: inline_call`mod1.m1pf(m1pa=78) at mod1.zig:12:14
            \\    frame #2: inline_call`root0.main at root0.zig:38:14
            ,
            \\  * frame #0: inline_call`mod1.m1pf [inlined] m1cfi(m1cai=70) at mod1.zig:29:5
            \\    frame #1: inline_call`mod1.m1pf(m1pa=78) at mod1.zig:13:15
            \\    frame #2: inline_call`root0.main at root0.zig:38:14
            ,
            \\  * frame #0: inline_call`root0.r0cf(r0ca=88) at root0.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] m1pfi(m1pai=89) at mod1.zig:16:15
            \\    frame #2: inline_call`root0.main at root0.zig:39:15
            ,
            \\  * frame #0: inline_call`root0.main [inlined] r0cfi(r0cai=91) at root0.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] m1pfi(m1pai=89) at mod1.zig:17:16
            \\    frame #2: inline_call`root0.main at root0.zig:39:15
            ,
            \\  * frame #0: inline_call`root1.r1cf(r1ca=90) at root1.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] m1pfi(m1pai=89) at mod1.zig:18:15
            \\    frame #2: inline_call`root0.main at root0.zig:39:15
            ,
            \\  * frame #0: inline_call`root0.main [inlined] r1cfi(r1cai=93) at root1.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] m1pfi(m1pai=89) at mod1.zig:19:16
            \\    frame #2: inline_call`root0.main at root0.zig:39:15
            ,
            \\  * frame #0: inline_call`mod0.m0cf(m0ca=92) at mod0.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] m1pfi(m1pai=89) at mod1.zig:20:14
            \\    frame #2: inline_call`root0.main at root0.zig:39:15
            ,
            \\  * frame #0: inline_call`root0.main [inlined] m0cfi(m0cai=95) at mod0.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] m1pfi(m1pai=89) at mod1.zig:21:15
            \\    frame #2: inline_call`root0.main at root0.zig:39:15
            ,
            \\  * frame #0: inline_call`mod1.m1cf(m1ca=94) at mod1.zig:26:5
            \\    frame #1: inline_call`root0.main [inlined] m1pfi(m1pai=89) at mod1.zig:22:14
            \\    frame #2: inline_call`root0.main at root0.zig:39:15
            ,
            \\  * frame #0: inline_call`root0.main [inlined] m1cfi(m1cai=81) at mod1.zig:29:5
            \\    frame #1: inline_call`root0.main [inlined] m1pfi(m1pai=89) at mod1.zig:23:15
            \\    frame #2: inline_call`root0.main at root0.zig:39:15
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
