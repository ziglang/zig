const std = @import("std");
const CrossTarget = std.zig.CrossTarget;
const TestContext = @import("../../src/test.zig").TestContext;

const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};
const macos_x64 = CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .macos,
};
const all_targets: []const CrossTarget = &[_]CrossTarget{
    linux_x64,
    macos_x64,
};

pub fn addCases(ctx: *TestContext) !void {
    try addLinuxTestCases(ctx);
    try addMacOsTestCases(ctx);

    // Common tests
    for (all_targets) |target| {
        {
            var case = ctx.exe("adding numbers at runtime and comptime", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    add(3, 4);
                \\}
                \\
                \\fn add(a: u32, b: u32) void {
                \\    if (a + b != 7) unreachable;
                \\}
            ,
                "",
            );
            // comptime function call
            case.addCompareOutput(
                \\pub fn main() void {
                \\    if (x - 7 != 0) unreachable;
                \\}
                \\
                \\fn add(a: u32, b: u32) u32 {
                \\    return a + b;
                \\}
                \\
                \\const x = add(3, 4);
            ,
                "",
            );
            // Inline function call
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: usize = 3;
                \\    const y = add(1, 2, x);
                \\    if (y - 6 != 0) unreachable;
                \\}
                \\
                \\fn add(a: usize, b: usize, c: usize) callconv(.Inline) usize {
                \\    return a + b + c;
                \\}
            ,
                "",
            );
        }

        {
            var case = ctx.exe("subtracting numbers at runtime", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    sub(7, 4);
                \\}
                \\
                \\fn sub(a: u32, b: u32) void {
                \\    if (a - b != 3) unreachable;
                \\}
            ,
                "",
            );
        }

        {
            var case = ctx.exe("unused vars", target);
            case.addError(
                \\pub fn main() void {
                \\    const x = 1;
                \\}
            , &.{":2:11: error: unused local constant"});
        }

        {
            var case = ctx.exe("multiplying numbers at runtime and comptime", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    mul(3, 4);
                \\}
                \\
                \\fn mul(a: u32, b: u32) void {
                \\    if (a * b != 12) unreachable;
                \\}
            ,
                "",
            );
            // comptime function call
            case.addCompareOutput(
                \\pub fn main() void {
                \\    if (x - 12 != 0) unreachable;
                \\}
                \\
                \\fn mul(a: u32, b: u32) u32 {
                \\    return a * b;
                \\}
                \\
                \\const x = mul(3, 4);
            ,
                "",
            );
            // Inline function call
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: usize = 5;
                \\    const y = mul(2, 3, x);
                \\    if (y - 30 != 0) unreachable;
                \\}
                \\
                \\fn mul(a: usize, b: usize, c: usize) callconv(.Inline) usize {
                \\    return a * b * c;
                \\}
            ,
                "",
            );
        }

        {
            var case = ctx.exe("assert function", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    add(3, 4);
                \\}
                \\
                \\fn add(a: u32, b: u32) void {
                \\    assert(a + b == 7);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Tests copying a register. For the `c = a + b`, it has to
            // preserve both a and b, because they are both used later.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    add(3, 4);
                \\}
                \\
                \\fn add(a: u32, b: u32) void {
                \\    const c = a + b; // 7
                \\    const d = a + c; // 10
                \\    const e = d + b; // 14
                \\    assert(e == 14);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // More stress on the liveness detection.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    add(3, 4);
                \\}
                \\
                \\fn add(a: u32, b: u32) void {
                \\    const c = a + b; // 7
                \\    const d = a + c; // 10
                \\    const e = d + b; // 14
                \\    const f = d + e; // 24
                \\    const g = e + f; // 38
                \\    const h = f + g; // 62
                \\    const i = g + h; // 100
                \\    assert(i == 100);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Requires a second move. The register allocator should figure out to re-use rax.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    add(3, 4);
                \\}
                \\
                \\fn add(a: u32, b: u32) void {
                \\    const c = a + b; // 7
                \\    const d = a + c; // 10
                \\    const e = d + b; // 14
                \\    const f = d + e; // 24
                \\    const g = e + f; // 38
                \\    const h = f + g; // 62
                \\    const i = g + h; // 100
                \\    const j = i + d; // 110
                \\    assert(j == 110);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Now we test integer return values.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(add(3, 4) == 7);
                \\    assert(add(20, 10) == 30);
                \\}
                \\
                \\fn add(a: u32, b: u32) u32 {
                \\    return a + b;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Local mutable variables.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(add(3, 4) == 7);
                \\    assert(add(20, 10) == 30);
                \\}
                \\
                \\fn add(a: u32, b: u32) u32 {
                \\    var x: u32 = undefined;
                \\    x = 0;
                \\    x += a;
                \\    x += b;
                \\    return x;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Optionals
            case.addCompareOutput(
                \\pub fn main() void {
                \\    const a: u32 = 2;
                \\    const b: ?u32 = a;
                \\    const c = b.?;
                \\    if (c != 2) unreachable;
                \\}
            ,
                "",
            );

            switch (target.getOsTag()) {
                .linux => {
                    // While loops
                    case.addCompareOutput(
                        \\pub fn main() void {
                        \\    var i: u32 = 0;
                        \\    while (i < 4) : (i += 1) print();
                        \\    assert(i == 4);
                        \\}
                        \\
                        \\fn print() void {
                        \\    asm volatile ("syscall"
                        \\        :
                        \\        : [number] "{rax}" (1),
                        \\          [arg1] "{rdi}" (1),
                        \\          [arg2] "{rsi}" (@ptrToInt("hello\n")),
                        \\          [arg3] "{rdx}" (6)
                        \\        : "rcx", "r11", "memory"
                        \\    );
                        \\    return;
                        \\}
                        \\
                        \\pub fn assert(ok: bool) void {
                        \\    if (!ok) unreachable; // assertion failure
                        \\}
                    ,
                        "hello\nhello\nhello\nhello\n",
                    );

                    // inline while requires the condition to be comptime known.
                    case.addError(
                        \\pub fn main() void {
                        \\    var i: u32 = 0;
                        \\    inline while (i < 4) : (i += 1) print();
                        \\    assert(i == 4);
                        \\}
                        \\
                        \\fn print() void {
                        \\    asm volatile ("syscall"
                        \\        :
                        \\        : [number] "{rax}" (1),
                        \\          [arg1] "{rdi}" (1),
                        \\          [arg2] "{rsi}" (@ptrToInt("hello\n")),
                        \\          [arg3] "{rdx}" (6)
                        \\        : "rcx", "r11", "memory"
                        \\    );
                        \\    return;
                        \\}
                        \\
                        \\pub fn assert(ok: bool) void {
                        \\    if (!ok) unreachable; // assertion failure
                        \\}
                    , &[_][]const u8{":3:21: error: unable to resolve comptime value"});
                },
                .macos => {
                    // While loops
                    case.addCompareOutput(
                        \\extern "c" fn write(usize, usize, usize) usize;
                        \\
                        \\pub fn main() void {
                        \\    var i: u32 = 0;
                        \\    while (i < 4) : (i += 1) print();
                        \\    assert(i == 4);
                        \\}
                        \\
                        \\fn print() void {
                        \\    _ = write(1, @ptrToInt("hello\n"), 6);
                        \\}
                        \\
                        \\pub fn assert(ok: bool) void {
                        \\    if (!ok) unreachable; // assertion failure
                        \\}
                    ,
                        "hello\nhello\nhello\nhello\n",
                    );

                    // inline while requires the condition to be comptime known.
                    case.addError(
                        \\extern "c" fn write(usize, usize, usize) usize;
                        \\
                        \\pub fn main() void {
                        \\    var i: u32 = 0;
                        \\    inline while (i < 4) : (i += 1) print();
                        \\    assert(i == 4);
                        \\}
                        \\
                        \\fn print() void {
                        \\    _ = write(1, @ptrToInt("hello\n"), 6);
                        \\}
                        \\
                        \\pub fn assert(ok: bool) void {
                        \\    if (!ok) unreachable; // assertion failure
                        \\}
                    , &[_][]const u8{":5:21: error: unable to resolve comptime value"});
                },
                else => unreachable,
            }

            // Labeled blocks (no conditional branch)
            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(add(3, 4) == 20);
                \\}
                \\
                \\fn add(a: u32, b: u32) u32 {
                \\    const x: u32 = blk: {
                \\        const c = a + b; // 7
                \\        const d = a + c; // 10
                \\        const e = d + b; // 14
                \\        break :blk e;
                \\    };
                \\    const y = x + a; // 17
                \\    const z = y + a; // 20
                \\    return z;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // This catches a possible bug in the logic for re-using dying operands.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(add(3, 4) == 116);
                \\}
                \\
                \\fn add(a: u32, b: u32) u32 {
                \\    const x: u32 = blk: {
                \\        const c = a + b; // 7
                \\        const d = a + c; // 10
                \\        const e = d + b; // 14
                \\        const f = d + e; // 24
                \\        const g = e + f; // 38
                \\        const h = f + g; // 62
                \\        const i = g + h; // 100
                \\        const j = i + d; // 110
                \\        break :blk j;
                \\    };
                \\    const y = x + a; // 113
                \\    const z = y + a; // 116
                \\    return z;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Spilling registers to the stack.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(add(3, 4) == 1221);
                \\    assert(mul(3, 4) == 21609);
                \\}
                \\
                \\fn add(a: u32, b: u32) u32 {
                \\    const x: u32 = blk: {
                \\        const c = a + b; // 7
                \\        const d = a + c; // 10
                \\        const e = d + b; // 14
                \\        const f = d + e; // 24
                \\        const g = e + f; // 38
                \\        const h = f + g; // 62
                \\        const i = g + h; // 100
                \\        const j = i + d; // 110
                \\        const k = i + j; // 210
                \\        const l = j + k; // 320
                \\        const m = l + c; // 327
                \\        const n = m + d; // 337
                \\        const o = n + e; // 351
                \\        const p = o + f; // 375
                \\        const q = p + g; // 413
                \\        const r = q + h; // 475
                \\        const s = r + i; // 575
                \\        const t = s + j; // 685
                \\        const u = t + k; // 895
                \\        const v = u + l; // 1215
                \\        break :blk v;
                \\    };
                \\    const y = x + a; // 1218
                \\    const z = y + a; // 1221
                \\    return z;
                \\}
                \\
                \\fn mul(a: u32, b: u32) u32 {
                \\    const x: u32 = blk: {
                \\        const c = a * a * a * a; // 81
                \\        const d = a * a * a * b; // 108
                \\        const e = a * a * b * a; // 108
                \\        const f = a * a * b * b; // 144
                \\        const g = a * b * a * a; // 108
                \\        const h = a * b * a * b; // 144
                \\        const i = a * b * b * a; // 144
                \\        const j = a * b * b * b; // 192
                \\        const k = b * a * a * a; // 108
                \\        const l = b * a * a * b; // 144
                \\        const m = b * a * b * a; // 144
                \\        const n = b * a * b * b; // 192
                \\        const o = b * b * a * a; // 144
                \\        const p = b * b * a * b; // 192
                \\        const q = b * b * b * a; // 192
                \\        const r = b * b * b * b; // 256
                \\        const s = c + d + e + f + g + h + i + j + k + l + m + n + o + p + q + r; // 2401
                \\        break :blk s;
                \\    };
                \\    const y = x * a; // 7203
                \\    const z = y * a; // 21609
                \\    return z;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Reusing the registers of dead operands playing nicely with conditional branching.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(add(3, 4) == 791);
                \\    assert(add(4, 3) == 79);
                \\}
                \\
                \\fn add(a: u32, b: u32) u32 {
                \\    const x: u32 = if (a < b) blk: {
                \\        const c = a + b; // 7
                \\        const d = a + c; // 10
                \\        const e = d + b; // 14
                \\        const f = d + e; // 24
                \\        const g = e + f; // 38
                \\        const h = f + g; // 62
                \\        const i = g + h; // 100
                \\        const j = i + d; // 110
                \\        const k = i + j; // 210
                \\        const l = k + c; // 217
                \\        const m = l + d; // 227
                \\        const n = m + e; // 241
                \\        const o = n + f; // 265
                \\        const p = o + g; // 303
                \\        const q = p + h; // 365
                \\        const r = q + i; // 465
                \\        const s = r + j; // 575
                \\        const t = s + k; // 785
                \\        break :blk t;
                \\    } else blk: {
                \\        const t = b + b + a; // 10
                \\        const c = a + t; // 14
                \\        const d = c + t; // 24
                \\        const e = d + t; // 34
                \\        const f = e + t; // 44
                \\        const g = f + t; // 54
                \\        const h = c + g; // 68
                \\        break :blk h + b; // 71
                \\    };
                \\    const y = x + a; // 788, 75
                \\    const z = y + a; // 791, 79
                \\    return z;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Character literals and multiline strings.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    const ignore =
                \\        \\ cool thx
                \\        \\
                \\    ;
                \\    _ = ignore;
                \\    add('ぁ', '\x03');
                \\}
                \\
                \\fn add(a: u32, b: u32) void {
                \\    assert(a + b == 12356);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Global const.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    add(aa, bb);
                \\}
                \\
                \\const aa = 'ぁ';
                \\const bb = '\x03';
                \\
                \\fn add(a: u32, b: u32) void {
                \\    assert(a + b == 12356);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Array access.
            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert("hello"[0] == 'h');
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // Array access to a global array.
            case.addCompareOutput(
                \\const hello = "hello".*;
                \\pub fn main() void {
                \\    assert(hello[1] == 'e');
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            // 64bit set stack
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var i: u64 = 0xFFEEDDCCBBAA9988;
                \\    assert(i == 0xFFEEDDCCBBAA9988);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            switch (target.getOsTag()) {
                .linux => {
                    // Basic for loop
                    case.addCompareOutput(
                        \\pub fn main() void {
                        \\    for ("hello") |_| print();
                        \\}
                        \\
                        \\fn print() void {
                        \\    asm volatile ("syscall"
                        \\        :
                        \\        : [number] "{rax}" (1),
                        \\          [arg1] "{rdi}" (1),
                        \\          [arg2] "{rsi}" (@ptrToInt("hello\n")),
                        \\          [arg3] "{rdx}" (6)
                        \\        : "rcx", "r11", "memory"
                        \\    );
                        \\    return;
                        \\}
                    ,
                        "hello\nhello\nhello\nhello\nhello\n",
                    );
                },
                .macos => {
                    // Basic for loop
                    case.addCompareOutput(
                        \\extern "c" fn write(usize, usize, usize) usize;
                        \\
                        \\pub fn main() void {
                        \\    for ("hello") |_| print();
                        \\}
                        \\
                        \\fn print() void {
                        \\    _ = write(1, @ptrToInt("hello\n"), 6);
                        \\}
                    ,
                        "hello\nhello\nhello\nhello\nhello\n",
                    );
                },
                else => unreachable,
            }
        }

        {
            var case = ctx.exe("@TypeOf", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: usize = 0;
                \\    _ = x;
                \\    const z = @TypeOf(x, @as(u128, 5));
                \\    assert(z == u128);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );
            case.addCompareOutput(
                \\pub fn main() void {
                \\    const z = @TypeOf(true);
                \\    assert(z == bool);
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );
            case.addError(
                \\pub fn main() void {
                \\    _ = @TypeOf(true, 1);
                \\}
            , &[_][]const u8{
                ":2:9: error: incompatible types: 'bool' and 'comptime_int'",
                ":2:17: note: type 'bool' here",
                ":2:23: note: type 'comptime_int' here",
            });
        }

        {
            var case = ctx.exe("basic import", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    @import("print.zig").print();
                \\}
            ,
                "Hello, World!\n",
            );
            switch (target.getOsTag()) {
                .linux => try case.files.append(.{
                    .src = 
                    \\pub fn print() void {
                    \\    asm volatile ("syscall"
                    \\        :
                    \\        : [number] "{rax}" (@as(usize, 1)),
                    \\          [arg1] "{rdi}" (@as(usize, 1)),
                    \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
                    \\          [arg3] "{rdx}" (@as(usize, 14))
                    \\        : "rcx", "r11", "memory"
                    \\    );
                    \\    return;
                    \\}
                    ,
                    .path = "print.zig",
                }),
                .macos => try case.files.append(.{
                    .src = 
                    \\extern "c" fn write(usize, usize, usize) usize;
                    \\
                    \\pub fn print() void {
                    \\    _ = write(1, @ptrToInt("Hello, World!\n"), 14);
                    \\}
                    ,
                    .path = "print.zig",
                }),
                else => unreachable,
            }
        }

        {
            var case = ctx.exe("redundant comptime", target);
            case.addError(
                \\pub fn main() void {
                \\    var a: comptime u32 = 0;
                \\}
            ,
                &.{":2:12: error: redundant comptime keyword in already comptime scope"},
            );
            case.addError(
                \\pub fn main() void {
                \\    comptime {
                \\        var a: u32 = comptime 0;
                \\    }
                \\}
            ,
                &.{":3:22: error: redundant comptime keyword in already comptime scope"},
            );
        }
        {
            var case = ctx.exe("try in comptime in struct in test", target);
            case.addError(
                \\test "@unionInit on union w/ tag but no fields" {
                \\    const S = struct {
                \\        comptime {
                \\            try expect(false);
                \\        }
                \\    };
                \\    _ = S;
                \\}
            ,
                &.{":4:13: error: 'try' outside function scope"},
            );
        }
        {
            var case = ctx.exe("import private", target);
            case.addError(
                \\pub fn main() void {
                \\    @import("print.zig").print();
                \\}
            ,
                &.{
                    ":2:25: error: 'print' is not marked 'pub'",
                    "print.zig:2:1: note: declared here",
                },
            );
            switch (target.getOsTag()) {
                .linux => try case.files.append(.{
                    .src = 
                    \\// dummy comment to make print be on line 2
                    \\fn print() void {
                    \\    asm volatile ("syscall"
                    \\        :
                    \\        : [number] "{rax}" (@as(usize, 1)),
                    \\          [arg1] "{rdi}" (@as(usize, 1)),
                    \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
                    \\          [arg3] "{rdx}" (@as(usize, 14))
                    \\        : "rcx", "r11", "memory"
                    \\    );
                    \\    return;
                    \\}
                    ,
                    .path = "print.zig",
                }),
                .macos => try case.files.append(.{
                    .src = 
                    \\extern "c" fn write(usize, usize, usize) usize;
                    \\fn print() void {
                    \\    _ = write(1, @ptrToInt("Hello, World!\n"), 14);
                    \\}
                    ,
                    .path = "print.zig",
                }),
                else => unreachable,
            }
        }

        ctx.compileError("function redeclaration", target,
            \\// dummy comment
            \\fn entry() void {}
            \\fn entry() void {}
            \\
            \\fn foo() void {
            \\    var foo = 1234;
            \\}
        , &[_][]const u8{
            ":3:1: error: redeclaration of 'entry'",
            ":2:1: note: other declaration here",
            ":6:9: error: local shadows declaration of 'foo'",
            ":5:1: note: declared here",
        });

        ctx.compileError("returns in try", target,
            \\pub fn main() !void {
            \\	try a();
            \\	try b();
            \\}
            \\
            \\pub fn a() !void {
            \\	defer try b();
            \\}
            \\pub fn b() !void {
            \\	defer return a();
            \\}
        , &[_][]const u8{
            ":7:8: error: 'try' not allowed inside defer expression",
            ":10:8: error: cannot return from defer expression",
        });

        ctx.compileError("ambiguous references", target,
            \\const T = struct {
            \\    const T = struct {
            \\        fn f() void {
            \\            _ = T;
            \\        }
            \\    };
            \\};
        , &.{
            ":4:17: error: ambiguous reference",
            ":2:5: note: declared here",
            ":1:1: note: also declared here",
        });

        ctx.compileError("inner func accessing outer var", target,
            \\pub fn f() void {
            \\    var bar: bool = true;
            \\    const S = struct {
            \\        fn baz() bool {
            \\            return bar;
            \\        }
            \\    };
            \\    _ = S;
            \\}
        , &.{
            ":5:20: error: mutable 'bar' not accessible from here",
            ":2:9: note: declared mutable here",
            ":3:15: note: crosses namespace boundary here",
        });

        ctx.compileError("global variable redeclaration", target,
            \\// dummy comment
            \\var foo = false;
            \\var foo = true;
        , &[_][]const u8{
            ":3:1: error: redeclaration of 'foo'",
            ":2:1: note: other declaration here",
        });

        ctx.compileError("compileError", target,
            \\export fn foo() void {
            \\  @compileError("this is an error");
            \\}
        , &[_][]const u8{":2:3: error: this is an error"});

        {
            var case = ctx.exe("intToPtr", target);
            case.addError(
                \\pub fn main() void {
                \\    _ = @intToPtr(*u8, 0);
                \\}
            , &[_][]const u8{
                ":2:24: error: pointer type '*u8' does not allow address zero",
            });
            case.addError(
                \\pub fn main() void {
                \\    _ = @intToPtr(*u32, 2);
                \\}
            , &[_][]const u8{
                ":2:25: error: pointer type '*u32' requires aligned address",
            });
        }

        {
            var case = ctx.obj("variable shadowing", target);
            case.addError(
                \\pub fn main() void {
                \\    var i: u32 = 10;
                \\    var i: u32 = 10;
                \\}
            , &[_][]const u8{
                ":3:9: error: redeclaration of local variable 'i'",
                ":2:9: note: previous declaration here",
            });
            case.addError(
                \\var testing: i64 = 10;
                \\pub fn main() void {
                \\    var testing: i64 = 20;
                \\}
            , &[_][]const u8{
                ":3:9: error: local shadows declaration of 'testing'",
                ":1:1: note: declared here",
            });
            case.addError(
                \\fn a() type {
                \\    return struct {
                \\        pub fn b() void {
                \\            const c = 6;
                \\            const c = 69;
                \\        }
                \\    };
                \\}
            , &[_][]const u8{
                ":5:19: error: redeclaration of local constant 'c'",
                ":4:19: note: previous declaration here",
            });
            case.addError(
                \\pub fn main() void {
                \\    var i = 0;
                \\    for ("n") |_, i| {
                \\    }
                \\}
            , &[_][]const u8{
                ":3:19: error: redeclaration of local variable 'i'",
                ":2:9: note: previous declaration here",
            });
            case.addError(
                \\pub fn main() void {
                \\    var i = 0;
                \\    for ("n") |i| {
                \\    }
                \\}
            , &[_][]const u8{
                ":3:16: error: redeclaration of local variable 'i'",
                ":2:9: note: previous declaration here",
            });
            case.addError(
                \\pub fn main() void {
                \\    var i = 0;
                \\    while ("n") |i| {
                \\    }
                \\}
            , &[_][]const u8{
                ":3:18: error: redeclaration of local variable 'i'",
                ":2:9: note: previous declaration here",
            });
            case.addError(
                \\pub fn main() void {
                \\    var i = 0;
                \\    while ("n") |bruh| {
                \\        _ = bruh;
                \\    } else |i| {
                \\
                \\    }
                \\}
            , &[_][]const u8{
                ":5:13: error: redeclaration of local variable 'i'",
                ":2:9: note: previous declaration here",
            });
            case.addError(
                \\pub fn main() void {
                \\    var i = 0;
                \\    if (true) |i| {}
                \\}
            , &[_][]const u8{
                ":3:16: error: redeclaration of local variable 'i'",
                ":2:9: note: previous declaration here",
            });
            case.addError(
                \\pub fn main() void {
                \\    var i = 0;
                \\    if (true) |i| {} else |e| {}
                \\}
            , &[_][]const u8{
                ":3:16: error: redeclaration of local variable 'i'",
                ":2:9: note: previous declaration here",
            });
            case.addError(
                \\pub fn main() void {
                \\    var i = 0;
                \\    if (true) |_| {} else |i| {}
                \\}
            , &[_][]const u8{
                ":3:28: error: redeclaration of local variable 'i'",
                ":2:9: note: previous declaration here",
            });
        }

        {
            // TODO make the test harness support checking the compile log output too
            var case = ctx.obj("@compileLog", target);
            // The other compile error prevents emission of a "found compile log" statement.
            case.addError(
                \\export fn _start() noreturn {
                \\    const b = true;
                \\    var f: u32 = 1;
                \\    @compileLog(b, 20, f, x);
                \\    @compileLog(1000);
                \\    var bruh: usize = true;
                \\    _ = bruh;
                \\    unreachable;
                \\}
                \\export fn other() void {
                \\    @compileLog(1234);
                \\}
                \\fn x() void {}
            , &[_][]const u8{
                ":6:23: error: expected usize, found bool",
            });

            // Now only compile log statements remain. One per Decl.
            case.addError(
                \\export fn _start() noreturn {
                \\    const b = true;
                \\    var f: u32 = 1;
                \\    @compileLog(b, 20, f, x);
                \\    @compileLog(1000);
                \\    unreachable;
                \\}
                \\export fn other() void {
                \\    @compileLog(1234);
                \\}
                \\fn x() void {}
            , &[_][]const u8{
                ":9:5: error: found compile log statement",
                ":4:5: note: also here",
            });
        }

        {
            var case = ctx.obj("extern variable has no type", target);
            case.addError(
                \\comptime {
                \\    const x = foo + foo;
                \\    _ = x;
                \\}
                \\extern var foo: i32;
            , &[_][]const u8{":2:15: error: unable to resolve comptime value"});
            case.addError(
                \\export fn entry() void {
                \\    _ = foo;
                \\}
                \\extern var foo;
            , &[_][]const u8{":4:8: error: unable to infer variable type"});
        }

        {
            var case = ctx.exe("break/continue", target);

            // Break out of loop
            case.addCompareOutput(
                \\pub fn main() void {
                \\    while (true) {
                \\        break;
                \\    }
                \\}
            ,
                "",
            );
            case.addCompareOutput(
                \\pub fn main() void {
                \\    foo: while (true) {
                \\        break :foo;
                \\    }
                \\}
            ,
                "",
            );

            // Continue in loop
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var i: u64 = 0;
                \\    while (true) : (i+=1) {
                \\        if (i == 4) return;
                \\        continue;
                \\    }
                \\}
            ,
                "",
            );
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var i: u64 = 0;
                \\    foo: while (true) : (i+=1) {
                \\        if (i == 4) return;
                \\        continue :foo;
                \\    }
                \\}
            ,
                "",
            );
        }

        {
            var case = ctx.exe("unused labels", target);
            case.addError(
                \\comptime {
                \\    foo: {}
                \\}
            , &[_][]const u8{":2:5: error: unused block label"});
            case.addError(
                \\comptime {
                \\    foo: while (true) {}
                \\}
            , &[_][]const u8{":2:5: error: unused while loop label"});
            case.addError(
                \\comptime {
                \\    foo: for ("foo") |_| {}
                \\}
            , &[_][]const u8{":2:5: error: unused for loop label"});
            case.addError(
                \\comptime {
                \\    blk: {blk: {}}
                \\}
            , &[_][]const u8{
                ":2:11: error: redefinition of label 'blk'",
                ":2:5: note: previous definition here",
            });
        }

        {
            var case = ctx.exe("bad inferred variable type", target);
            case.addError(
                \\pub fn main() void {
                \\    var x = null;
                \\    _ = x;
                \\}
            , &[_][]const u8{
                ":2:9: error: variable of type '@TypeOf(null)' must be const or comptime",
            });
        }

        {
            var case = ctx.exe("compile error in inline fn call fixed", target);
            case.addError(
                \\pub fn main() void {
                \\    var x: usize = 3;
                \\    const y = add(10, 2, x);
                \\    if (y - 6 != 0) unreachable;
                \\}
                \\
                \\fn add(a: usize, b: usize, c: usize) callconv(.Inline) usize {
                \\    if (a == 10) @compileError("bad");
                \\    return a + b + c;
                \\}
            , &[_][]const u8{
                ":8:18: error: bad",
                ":3:18: note: called from here",
            });

            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: usize = 3;
                \\    const y = add(1, 2, x);
                \\    if (y - 6 != 0) unreachable;
                \\}
                \\
                \\fn add(a: usize, b: usize, c: usize) callconv(.Inline) usize {
                \\    if (a == 10) @compileError("bad");
                \\    return a + b + c;
                \\}
            ,
                "",
            );
        }
        {
            var case = ctx.exe("recursive inline function", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    const y = fibonacci(7);
                \\    if (y - 21 != 0) unreachable;
                \\}
                \\
                \\fn fibonacci(n: usize) callconv(.Inline) usize {
                \\    if (n <= 2) return n;
                \\    return fibonacci(n - 2) + fibonacci(n - 1);
                \\}
            ,
                "",
            );
            // This additionally tests that the compile error reports the correct source location.
            // Without storing source locations relative to the owner decl, the compile error
            // here would be off by 2 bytes (from the "7" -> "999").
            case.addError(
                \\pub fn main() void {
                \\    const y = fibonacci(999);
                \\    if (y - 21 != 0) unreachable;
                \\}
                \\
                \\fn fibonacci(n: usize) callconv(.Inline) usize {
                \\    if (n <= 2) return n;
                \\    return fibonacci(n - 2) + fibonacci(n - 1);
                \\}
            , &[_][]const u8{":8:21: error: evaluation exceeded 1000 backwards branches"});
        }
        {
            var case = ctx.exe("orelse at comptime", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    const i: ?u64 = 0;
                \\    const result = i orelse 5;
                \\    assert(result == 0);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            ,
                "",
            );
            case.addCompareOutput(
                \\pub fn main() void {
                \\    const i: ?u64 = null;
                \\    const result = i orelse 5;
                \\    assert(result == 5);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            ,
                "",
            );
        }

        {
            var case = ctx.exe("passing u0 to function", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    doNothing(0);
                \\}
                \\fn doNothing(arg: u0) void {
                \\    _ = arg;
                \\}
            ,
                "",
            );
        }

        {
            var case = ctx.exe("catch at comptime", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    const i: anyerror!u64 = 0;
                \\    const caught = i catch 5;
                \\    assert(caught == 0);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            ,
                "",
            );

            case.addCompareOutput(
                \\pub fn main() void {
                \\    const i: anyerror!u64 = error.B;
                \\    const caught = i catch 5;
                \\    assert(caught == 5);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            ,
                "",
            );

            case.addCompareOutput(
                \\pub fn main() void {
                \\    const a: anyerror!comptime_int = 42;
                \\    const b: *const comptime_int = &(a catch unreachable);
                \\    assert(b.* == 42);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable; // assertion failure
                \\}
            , "");

            case.addCompareOutput(
                \\pub fn main() void {
                \\    const a: anyerror!u32 = error.B;
                \\    _ = &(a catch |err| assert(err == error.B));
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            , "");

            case.addCompareOutput(
                \\pub fn main() void {
                \\    const a: anyerror!u32 = error.Bar;
                \\    a catch |err| assert(err == error.Bar);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            , "");
        }

        {
            var case = ctx.exe("runtime bitwise and", target);

            case.addCompareOutput(
                \\pub fn main() void {
                \\    var i: u32 = 10;
                \\    var j: u32 = 11;
                \\    assert(i & 1 == 0);
                \\    assert(j & 1 == 1);
                \\    var m1: u32 = 0b1111;
                \\    var m2: u32 = 0b0000;
                \\    assert(m1 & 0b1010 == 0b1010);
                \\    assert(m2 & 0b1010 == 0b0000);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            ,
                "",
            );
        }

        {
            var case = ctx.exe("runtime bitwise or", target);

            case.addCompareOutput(
                \\pub fn main() void {
                \\    var i: u32 = 10;
                \\    var j: u32 = 11;
                \\    assert(i | 1 == 11);
                \\    assert(j | 1 == 11);
                \\    var m1: u32 = 0b1111;
                \\    var m2: u32 = 0b0000;
                \\    assert(m1 | 0b1010 == 0b1111);
                \\    assert(m2 | 0b1010 == 0b1010);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            ,
                "",
            );
        }

        {
            var case = ctx.exe("merge error sets", target);

            case.addCompareOutput(
                \\pub fn main() void {
                \\    const E = error{ A, B, D } || error { A, B, C };
                \\    E.A catch {};
                \\    E.B catch {};
                \\    E.C catch {};
                \\    E.D catch {};
                \\    const E2 = error { X, Y } || @TypeOf(error.Z);
                \\    E2.X catch {};
                \\    E2.Y catch {};
                \\    E2.Z catch {};
                \\    assert(anyerror || error { Z } == anyerror);
                \\}
                \\fn assert(b: bool) void {
                \\    if (!b) unreachable;
                \\}
            ,
                "",
            );
            case.addError(
                \\pub fn main() void {
                \\    const z = true || false;
                \\    _ = z;
                \\}
            , &.{
                ":2:15: error: expected error set type, found 'bool'",
                ":2:20: note: '||' merges error sets; 'or' performs boolean OR",
            });
        }

        {
            var case = ctx.exe("comptime var", target);

            case.addError(
                \\pub fn main() void {
                \\    var a: u32 = 0;
                \\    comptime var b: u32 = 0;
                \\    if (a == 0) b = 3;
                \\}
            , &.{
                ":4:21: error: store to comptime variable depends on runtime condition",
                ":4:11: note: runtime condition here",
            });

            case.addError(
                \\pub fn main() void {
                \\    var a: u32 = 0;
                \\    comptime var b: u32 = 0;
                \\    switch (a) {
                \\        0 => {},
                \\        else => b = 3,
                \\    }
                \\}
            , &.{
                ":6:21: error: store to comptime variable depends on runtime condition",
                ":4:13: note: runtime condition here",
            });

            switch (target.getOsTag()) {
                .linux => case.addCompareOutput(
                    \\pub fn main() void {
                    \\    comptime var len: u32 = 5;
                    \\    print(len);
                    \\    len += 9;
                    \\    print(len);
                    \\}
                    \\
                    \\fn print(len: usize) void {
                    \\    asm volatile ("syscall"
                    \\        :
                    \\        : [number] "{rax}" (1),
                    \\          [arg1] "{rdi}" (1),
                    \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
                    \\          [arg3] "{rdx}" (len)
                    \\        : "rcx", "r11", "memory"
                    \\    );
                    \\    return;
                    \\}
                , "HelloHello, World!\n"),
                .macos => case.addCompareOutput(
                    \\extern "c" fn write(usize, usize, usize) usize;
                    \\
                    \\pub fn main() void {
                    \\    comptime var len: u32 = 5;
                    \\    print(len);
                    \\    len += 9;
                    \\    print(len);
                    \\}
                    \\
                    \\fn print(len: usize) void {
                    \\    _ = write(1, @ptrToInt("Hello, World!\n"), len);
                    \\}
                , "HelloHello, World!\n"),

                else => unreachable,
            }

            case.addError(
                \\comptime {
                \\    var x: i32 = 1;
                \\    x += 1;
                \\    if (x != 1) unreachable;
                \\}
                \\pub fn main() void {}
            , &.{":4:17: error: unable to resolve comptime value"});

            case.addError(
                \\pub fn main() void {
                \\    comptime var i: u64 = 0;
                \\    while (i < 5) : (i += 1) {}
                \\}
            , &.{
                ":3:24: error: cannot store to comptime variable in non-inline loop",
                ":3:5: note: non-inline loop here",
            });

            case.addCompareOutput(
                \\pub fn main() void {
                \\    var a: u32 = 0;
                \\    if (a == 0) {
                \\        comptime var b: u32 = 0;
                \\        b = 1;
                \\    }
                \\}
                \\comptime {
                \\    var x: i32 = 1;
                \\    x += 1;
                \\    if (x != 2) unreachable;
                \\}
            , "");

            switch (target.getOsTag()) {
                .linux => case.addCompareOutput(
                    \\pub fn main() void {
                    \\    comptime var i: u64 = 2;
                    \\    inline while (i < 6) : (i+=1) {
                    \\        print(i);
                    \\    }
                    \\}
                    \\fn print(len: usize) void {
                    \\    asm volatile ("syscall"
                    \\        :
                    \\        : [number] "{rax}" (1),
                    \\          [arg1] "{rdi}" (1),
                    \\          [arg2] "{rsi}" (@ptrToInt("Hello")),
                    \\          [arg3] "{rdx}" (len)
                    \\        : "rcx", "r11", "memory"
                    \\    );
                    \\    return;
                    \\}
                , "HeHelHellHello"),
                .macos => case.addCompareOutput(
                    \\extern "c" fn write(usize, usize, usize) usize;
                    \\
                    \\pub fn main() void {
                    \\    comptime var i: u64 = 2;
                    \\    inline while (i < 6) : (i+=1) {
                    \\        print(i);
                    \\    }
                    \\}
                    \\fn print(len: usize) void {
                    \\    _ = write(1, @ptrToInt("Hello"), len);
                    \\}
                , "HeHelHellHello"),
                else => unreachable,
            }
        }

        {
            var case = ctx.exe("double ampersand", target);

            case.addError(
                \\pub const a = if (true && false) 1 else 2;
            , &[_][]const u8{":1:24: error: ambiguous use of '&&'; use 'and' for logical AND, or change whitespace to ' & &' for bitwise AND"});

            case.addError(
                \\pub fn main() void {
                \\    const a = true;
                \\    const b = false;
                \\    _ = a & &b;
                \\}
            , &[_][]const u8{
                ":4:11: error: incompatible types: 'bool' and '*const bool'",
                ":4:9: note: type 'bool' here",
                ":4:13: note: type '*const bool' here",
            });

            case.addCompareOutput(
                \\pub fn main() void {
                \\    const b: u8 = 1;
                \\    _ = &&b;
                \\}
            , "");
        }

        {
            var case = ctx.exe("setting an address space on a local variable", target);
            case.addError(
                \\export fn entry() i32 {
                \\    var foo: i32 addrspace(".general") = 1234;
                \\    return foo;
                \\}
            , &[_][]const u8{
                ":2:28: error: cannot set address space of local variable 'foo'",
            });
        }

        {
            var case = ctx.exe("saving vars of different ABI size to stack", target);

            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(callMe(2) == 24);
                \\}
                \\
                \\fn callMe(a: u8) u8 {
                \\    var b: u8 = a + 10;
                \\    const c = 2 * b;
                \\    return c;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(callMe(2) == 24);
                \\}
                \\
                \\fn callMe(a: u16) u16 {
                \\    var b: u16 = a + 10;
                \\    const c = 2 * b;
                \\    return c;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );

            case.addCompareOutput(
                \\pub fn main() void {
                \\    assert(callMe(2) == 24);
                \\}
                \\
                \\fn callMe(a: u32) u32 {
                \\    var b: u32 = a + 10;
                \\    const c = 2 * b;
                \\    return c;
                \\}
                \\
                \\pub fn assert(ok: bool) void {
                \\    if (!ok) unreachable; // assertion failure
                \\}
            ,
                "",
            );
        }
        {
            var case = ctx.exe("issue 7187: miscompilation with bool return type", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: usize = 1;
                \\    var y: bool = getFalse();
                \\    _ = y;
                \\
                \\    assert(x == 1);
                \\}
                \\
                \\fn getFalse() bool {
                \\    return false;
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
        }

        {
            var case = ctx.exe("load-store via pointer deref", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: u32 = undefined;
                \\    set(&x);
                \\    assert(x == 123);
                \\}
                \\
                \\fn set(x: *u32) void {
                \\    x.* = 123;
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: u16 = undefined;
                \\    set(&x);
                \\    assert(x == 123);
                \\}
                \\
                \\fn set(x: *u16) void {
                \\    x.* = 123;
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: u8 = undefined;
                \\    set(&x);
                \\    assert(x == 123);
                \\}
                \\
                \\fn set(x: *u8) void {
                \\    x.* = 123;
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
        }

        {
            var case = ctx.exe("optional payload", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: u32 = undefined;
                \\    const maybe_x = byPtr(&x);
                \\    assert(maybe_x != null);
                \\    maybe_x.?.* = 123;
                \\    assert(x == 123);
                \\}
                \\
                \\fn byPtr(x: *u32) ?*u32 {
                \\    return x;
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: u32 = undefined;
                \\    const maybe_x = byPtr(&x);
                \\    assert(maybe_x == null);
                \\}
                \\
                \\fn byPtr(x: *u32) ?*u32 {
                \\    _ = x;
                \\    return null;
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: u8 = undefined;
                \\    const maybe_x = byPtr(&x);
                \\    assert(maybe_x != null);
                \\    maybe_x.?.* = 255;
                \\    assert(x == 255);
                \\}
                \\
                \\fn byPtr(x: *u8) ?*u8 {
                \\    return x;
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
            case.addCompareOutput(
                \\pub fn main() void {
                \\    var x: i8 = undefined;
                \\    const maybe_x = byPtr(&x);
                \\    assert(maybe_x != null);
                \\    maybe_x.?.* = -1;
                \\    assert(x == -1);
                \\}
                \\
                \\fn byPtr(x: *i8) ?*i8 {
                \\    return x;
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
        }

        {
            var case = ctx.exe("unwrap error union - simple errors", target);
            case.addCompareOutput(
                \\pub fn main() void {
                \\    maybeErr() catch unreachable;
                \\}
                \\
                \\fn maybeErr() !void {
                \\    return;
                \\}
            , "");
            case.addCompareOutput(
                \\pub fn main() void {
                \\    maybeErr() catch return;
                \\    unreachable;
                \\}
                \\
                \\fn maybeErr() !void {
                \\    return error.NoWay;
                \\}
            , "");
        }

        {
            var case = ctx.exe("access slice element by index - slice_elem_val", target);
            case.addCompareOutput(
                \\var array = [_]usize{ 0, 42, 123, 34 };
                \\var slice: []const usize = &array;
                \\
                \\pub fn main() void {
                \\    assert(slice[0] == 0);
                \\    assert(slice[1] == 42);
                \\    assert(slice[2] == 123);
                \\    assert(slice[3] == 34);
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
        }

        {
            var case = ctx.exe("lower unnamed constants - structs", target);
            case.addCompareOutput(
                \\const Foo = struct {
                \\    a: u8,
                \\    b: u32,
                \\
                \\    fn first(self: *Foo) u8 {
                \\        return self.a;
                \\    }
                \\
                \\    fn second(self: *Foo) u32 {
                \\        return self.b;
                \\    }
                \\};
                \\
                \\pub fn main() void {
                \\    var foo = Foo{ .a = 1, .b = 5 };
                \\    assert(foo.first() == 1);
                \\    assert(foo.second() == 5);
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");

            case.addCompareOutput(
                \\const Foo = struct {
                \\    a: u8,
                \\    b: u32,
                \\
                \\    fn first(self: *Foo) u8 {
                \\        return self.a;
                \\    }
                \\
                \\    fn second(self: *Foo) u32 {
                \\        return self.b;
                \\    }
                \\};
                \\
                \\pub fn main() void {
                \\    var foo = Foo{ .a = 1, .b = 5 };
                \\    assert(foo.first() == 1);
                \\    assert(foo.second() == 5);
                \\
                \\    foo.a = 10;
                \\    foo.b = 255;
                \\
                \\    assert(foo.first() == 10);
                \\    assert(foo.second() == 255);
                \\
                \\    var foo2 = Foo{ .a = 15, .b = 255 };
                \\    assert(foo2.first() == 15);
                \\    assert(foo2.second() == 255);
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");

            case.addCompareOutput(
                \\const Foo = struct {
                \\    a: u8,
                \\    b: u32,
                \\
                \\    fn first(self: *Foo) u8 {
                \\        return self.a;
                \\    }
                \\
                \\    fn second(self: *Foo) u32 {
                \\        return self.b;
                \\    }
                \\};
                \\
                \\pub fn main() void {
                \\    var foo2 = Foo{ .a = 15, .b = 255 };
                \\    assert(foo2.first() == 15);
                \\    assert(foo2.second() == 255);
                \\}
                \\
                \\fn assert(ok: bool) void {
                \\    if (!ok) unreachable;
                \\}
            , "");
        }
    }
}

fn addLinuxTestCases(ctx: *TestContext) !void {
    // Linux tests
    {
        var case = ctx.exe("hello world with updates", linux_x64);

        case.addError("", &[_][]const u8{
            ":109:9: error: struct 'tmp.tmp' has no member named 'main'",
        });

        // Incorrect return type
        case.addError(
            \\pub export fn _start() noreturn {
            \\}
        , &[_][]const u8{":2:1: error: expected noreturn, found void"});

        // Regular old hello world
        case.addCompareOutput(
            \\pub export fn _start() noreturn {
            \\    print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{rdx}" (14)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "Hello, World!\n",
        );

        // Convert to pub fn main
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{rdx}" (14)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
        ,
            "Hello, World!\n",
        );

        // Now change the message only
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
            \\          [arg3] "{rdx}" (104)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
        ,
            "What is up? This is a longer message that will force the data to be relocated in virtual address space.\n",
        );
        // Now we print it twice.
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print();
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
            \\          [arg3] "{rdx}" (104)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
        ,
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\
        );
    }

    {
        var case = ctx.exe("adding numbers at comptime", linux_x64);
        case.addCompareOutput(
            \\pub export fn _start() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{rdx}" (10 + 4)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (@as(usize, 230) + @as(usize, 1)),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "Hello, World!\n",
        );
    }

    {
        var case = ctx.exe("only 1 function and it gets updated", linux_x64);
        case.addCompareOutput(
            \\pub export fn _start() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (60), // exit
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        case.addCompareOutput(
            \\pub export fn _start() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231), // exit_group
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }
    {
        var case = ctx.exe("inline assembly", linux_x64);

        case.addError(
            \\pub fn main() void {
            \\    const number = 1234;
            \\    const x = asm volatile ("syscall"
            \\        : [o] "{rax}" (-> number)
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (60)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    _ = x;
            \\}
        , &[_][]const u8{":4:27: error: expected type, found comptime_int"});
        case.addError(
            \\const S = struct {
            \\    comptime {
            \\        asm volatile (
            \\            \\zig_moment:
            \\            \\syscall
            \\        );
            \\    }
            \\};
            \\pub fn main() void {
            \\    _ = S;
            \\}
        , &.{":3:13: error: volatile is meaningless on global assembly"});
        case.addError(
            \\pub fn main() void {
            \\    var bruh: u32 = 1;
            \\    asm (""
            \\        :
            \\        : [bruh] "{rax}" (4)
            \\        : "memory"
            \\    );
            \\}
        , &.{":3:5: error: assembly expression with no output must be marked volatile"});
        case.addError(
            \\pub fn main() void {}
            \\comptime {
            \\    asm (""
            \\        :
            \\        : [bruh] "{rax}" (4)
            \\        : "memory"
            \\    );
            \\}
        , &.{":3:5: error: global assembly cannot have inputs, outputs, or clobbers"});
    }

    {
        var case = ctx.exe("issue 10138: callee preserved regs working", linux_x64);
        case.addCompareOutput(
            \\pub fn main() void {
            \\    const fd = open();
            \\    _ = write(fd, "a", 1);
            \\    _ = close(fd);
            \\}
            \\
            \\fn open() usize {
            \\    return 42;
            \\}
            \\
            \\fn write(fd: usize, a: [*]const u8, len: usize) usize {
            \\    return syscall4(.WRITE, fd, @ptrToInt(a), len);
            \\}
            \\
            \\fn syscall4(n: enum { WRITE }, a: usize, b: usize, c: usize) usize {
            \\    _ = n;
            \\    _ = a;
            \\    _ = b;
            \\    _ = c;
            \\    return 23;
            \\}
            \\
            \\fn close(fd: usize) usize {
            \\    if (fd != 42)
            \\        unreachable;
            \\    return 0;
            \\}
        , "");
    }
}

fn addMacOsTestCases(ctx: *TestContext) !void {
    // macOS tests
    {
        var case = ctx.exe("darwin hello world with updates", macos_x64);
        case.addError("", &[_][]const u8{
            ":109:9: error: struct 'tmp.tmp' has no member named 'main'",
        });

        // Incorrect return type
        case.addError(
            \\pub export fn main() noreturn {
            \\}
        , &[_][]const u8{
            ":2:1: error: expected noreturn, found void",
        });

        // Regular old hello world
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\extern "c" fn exit(usize) noreturn;
            \\
            \\pub export fn main() noreturn {
            \\    print();
            \\
            \\    exit(0);
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("Hello, World!\n");
            \\    const len = 14;
            \\    _ = write(1, msg, len);
            \\}
        ,
            "Hello, World!\n",
        );

        // Now using start.zig without an explicit extern exit fn
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\
            \\pub fn main() void {
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("Hello, World!\n");
            \\    const len = 14;
            \\    _ = write(1, msg, len);
            \\}
        ,
            "Hello, World!\n",
        );

        // Print it 4 times and force growth and realloc.
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\
            \\pub fn main() void {
            \\    print();
            \\    print();
            \\    print();
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("Hello, World!\n");
            \\    const len = 14;
            \\    _ = write(1, msg, len);
            \\}
        ,
            \\Hello, World!
            \\Hello, World!
            \\Hello, World!
            \\Hello, World!
            \\
        );

        // Print it once, and change the message.
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\
            \\pub fn main() void {
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n");
            \\    const len = 104;
            \\    _ = write(1, msg, len);
            \\}
        ,
            "What is up? This is a longer message that will force the data to be relocated in virtual address space.\n",
        );

        // Now we print it twice.
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\
            \\pub fn main() void {
            \\    print();
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n");
            \\    const len = 104;
            \\    _ = write(1, msg, len);
            \\}
        ,
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\
        );
    }
}
