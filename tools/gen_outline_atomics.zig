const std = @import("std");
const Allocator = std.mem.Allocator;

const AtomicOp = enum {
    cas,
    swp,
    ldadd,
    ldclr,
    ldeor,
    ldset,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 2) {
        usageAndExit(std.io.getStdErr(), args[0], 1);
    }

    var file = try std.fs.cwd().createFile(args[1], .{ .truncate = true });

    try file.writeAll(
        \\const std = @import("std");
        \\const builtin = @import("builtin");
        \\const arch = builtin.cpu.arch;
        \\const is_test = builtin.is_test;
        \\const target = std.Target;
        \\const os_tag = builtin.os.tag;
        \\const is_darwin = target.Os.Tag.isDarwin(os_tag);
        \\const has_lse = target.aarch64.featureSetHas(builtin.target.cpu.features, .lse);
        \\const linkage = if (is_test)
        \\    std.builtin.GlobalLinkage.Internal
        \\else
        \\    std.builtin.GlobalLinkage.Strong;
        \\
        \\
    );

    for ([_]N{ .one, .two, .four, .eight, .sixteen }) |n| {
        for ([_]Ordering{ .relax, .acq, .rel, .acq_rel }) |order| {
            for ([_]AtomicOp{ .cas, .swp, .ldadd, .ldclr, .ldeor, .ldset }) |pat| {
                if (pat == .cas or n != .sixteen) {
                    for ([_]bool{ true, false }) |darwin| {
                        for ([_]bool{ true, false }) |lse| {
                            const darwin_name = if (darwin) "Darwin" else "Nondarwin";
                            const lse_name = if (lse) "Lse" else "Nolse";
                            var buf: [100:0]u8 = undefined;
                            const name = try std.fmt.bufPrintZ(&buf, "{s}{s}{s}{s}{s}", .{ @tagName(pat), n.toBytes(), order.capName(), darwin_name, lse_name });
                            const body = switch (pat) {
                                .cas => try generateCas(&allocator, n, order, lse),
                                .swp => try generateSwp(&allocator, n, order, lse),
                                .ldadd => try generateLd(&allocator, n, order, .ldadd, lse),
                                .ldclr => try generateLd(&allocator, n, order, .ldclr, lse),
                                .ldeor => try generateLd(&allocator, n, order, .ldeor, lse),
                                .ldset => try generateLd(&allocator, n, order, .ldset, lse),
                            };
                            defer allocator.destroy(body.ptr);
                            try writeFunction(&file, name, pat, n, body);
                        }
                    }
                    try writeExport(&file, @tagName(pat), n.toBytes(), order);
                }
            }
        }
    }

    try file.writeAll(
        \\//TODO: Add linksection once implemented and remove init at writeFunction
        \\fn __init_aarch64_have_lse_atomics() callconv(.C) void {
        \\    const AT_HWCAP = 16;
        \\    const HWCAP_ATOMICS = 1 << 8;
        \\    const hwcap = std.os.linux.getauxval(AT_HWCAP);
        \\    __aarch64_have_lse_atomics = @boolToInt((hwcap & HWCAP_ATOMICS) != 0);
        \\}
        \\
        \\var __aarch64_have_lse_atomics: u8 = @boolToInt(has_lse);
        \\
        \\comptime {
        \\    if (arch.isAARCH64()) {
        \\        @export(__aarch64_cas1_relax, .{ .name = "__aarch64_cas1_relax", .linkage = linkage });
        \\        @export(__aarch64_cas1_acq, .{ .name = "__aarch64_cas1_acq", .linkage = linkage });
        \\        @export(__aarch64_cas1_rel, .{ .name = "__aarch64_cas1_rel", .linkage = linkage });
        \\        @export(__aarch64_cas1_acq_rel, .{ .name = "__aarch64_cas1_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_cas2_relax, .{ .name = "__aarch64_cas2_relax", .linkage = linkage });
        \\        @export(__aarch64_cas2_acq, .{ .name = "__aarch64_cas2_acq", .linkage = linkage });
        \\        @export(__aarch64_cas2_rel, .{ .name = "__aarch64_cas2_rel", .linkage = linkage });
        \\        @export(__aarch64_cas2_acq_rel, .{ .name = "__aarch64_cas2_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_cas4_relax, .{ .name = "__aarch64_cas4_relax", .linkage = linkage });
        \\        @export(__aarch64_cas4_acq, .{ .name = "__aarch64_cas4_acq", .linkage = linkage });
        \\        @export(__aarch64_cas4_rel, .{ .name = "__aarch64_cas4_rel", .linkage = linkage });
        \\        @export(__aarch64_cas4_acq_rel, .{ .name = "__aarch64_cas4_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_cas8_relax, .{ .name = "__aarch64_cas8_relax", .linkage = linkage });
        \\        @export(__aarch64_cas8_acq, .{ .name = "__aarch64_cas8_acq", .linkage = linkage });
        \\        @export(__aarch64_cas8_rel, .{ .name = "__aarch64_cas8_rel", .linkage = linkage });
        \\        @export(__aarch64_cas8_acq_rel, .{ .name = "__aarch64_cas8_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_cas16_relax, .{ .name = "__aarch64_cas16_relax", .linkage = linkage });
        \\        @export(__aarch64_cas16_acq, .{ .name = "__aarch64_cas16_acq", .linkage = linkage });
        \\        @export(__aarch64_cas16_rel, .{ .name = "__aarch64_cas16_rel", .linkage = linkage });
        \\        @export(__aarch64_cas16_acq_rel, .{ .name = "__aarch64_cas16_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_swp1_relax, .{ .name = "__aarch64_swp1_relax", .linkage = linkage });
        \\        @export(__aarch64_swp1_acq, .{ .name = "__aarch64_swp1_acq", .linkage = linkage });
        \\        @export(__aarch64_swp1_rel, .{ .name = "__aarch64_swp1_rel", .linkage = linkage });
        \\        @export(__aarch64_swp1_acq_rel, .{ .name = "__aarch64_swp1_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_swp2_relax, .{ .name = "__aarch64_swp2_relax", .linkage = linkage });
        \\        @export(__aarch64_swp2_acq, .{ .name = "__aarch64_swp2_acq", .linkage = linkage });
        \\        @export(__aarch64_swp2_rel, .{ .name = "__aarch64_swp2_rel", .linkage = linkage });
        \\        @export(__aarch64_swp2_acq_rel, .{ .name = "__aarch64_swp2_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_swp4_relax, .{ .name = "__aarch64_swp4_relax", .linkage = linkage });
        \\        @export(__aarch64_swp4_acq, .{ .name = "__aarch64_swp4_acq", .linkage = linkage });
        \\        @export(__aarch64_swp4_rel, .{ .name = "__aarch64_swp4_rel", .linkage = linkage });
        \\        @export(__aarch64_swp4_acq_rel, .{ .name = "__aarch64_swp4_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_swp8_relax, .{ .name = "__aarch64_swp8_relax", .linkage = linkage });
        \\        @export(__aarch64_swp8_acq, .{ .name = "__aarch64_swp8_acq", .linkage = linkage });
        \\        @export(__aarch64_swp8_rel, .{ .name = "__aarch64_swp8_rel", .linkage = linkage });
        \\        @export(__aarch64_swp8_acq_rel, .{ .name = "__aarch64_swp8_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldadd1_relax, .{ .name = "__aarch64_ldadd1_relax", .linkage = linkage });
        \\        @export(__aarch64_ldadd1_acq, .{ .name = "__aarch64_ldadd1_acq", .linkage = linkage });
        \\        @export(__aarch64_ldadd1_rel, .{ .name = "__aarch64_ldadd1_rel", .linkage = linkage });
        \\        @export(__aarch64_ldadd1_acq_rel, .{ .name = "__aarch64_ldadd1_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldadd2_relax, .{ .name = "__aarch64_ldadd2_relax", .linkage = linkage });
        \\        @export(__aarch64_ldadd2_acq, .{ .name = "__aarch64_ldadd2_acq", .linkage = linkage });
        \\        @export(__aarch64_ldadd2_rel, .{ .name = "__aarch64_ldadd2_rel", .linkage = linkage });
        \\        @export(__aarch64_ldadd2_acq_rel, .{ .name = "__aarch64_ldadd2_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldadd4_relax, .{ .name = "__aarch64_ldadd4_relax", .linkage = linkage });
        \\        @export(__aarch64_ldadd4_acq, .{ .name = "__aarch64_ldadd4_acq", .linkage = linkage });
        \\        @export(__aarch64_ldadd4_rel, .{ .name = "__aarch64_ldadd4_rel", .linkage = linkage });
        \\        @export(__aarch64_ldadd4_acq_rel, .{ .name = "__aarch64_ldadd4_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldadd8_relax, .{ .name = "__aarch64_ldadd8_relax", .linkage = linkage });
        \\        @export(__aarch64_ldadd8_acq, .{ .name = "__aarch64_ldadd8_acq", .linkage = linkage });
        \\        @export(__aarch64_ldadd8_rel, .{ .name = "__aarch64_ldadd8_rel", .linkage = linkage });
        \\        @export(__aarch64_ldadd8_acq_rel, .{ .name = "__aarch64_ldadd8_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldclr1_relax, .{ .name = "__aarch64_ldclr1_relax", .linkage = linkage });
        \\        @export(__aarch64_ldclr1_acq, .{ .name = "__aarch64_ldclr1_acq", .linkage = linkage });
        \\        @export(__aarch64_ldclr1_rel, .{ .name = "__aarch64_ldclr1_rel", .linkage = linkage });
        \\        @export(__aarch64_ldclr1_acq_rel, .{ .name = "__aarch64_ldclr1_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldclr2_relax, .{ .name = "__aarch64_ldclr2_relax", .linkage = linkage });
        \\        @export(__aarch64_ldclr2_acq, .{ .name = "__aarch64_ldclr2_acq", .linkage = linkage });
        \\        @export(__aarch64_ldclr2_rel, .{ .name = "__aarch64_ldclr2_rel", .linkage = linkage });
        \\        @export(__aarch64_ldclr2_acq_rel, .{ .name = "__aarch64_ldclr2_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldclr4_relax, .{ .name = "__aarch64_ldclr4_relax", .linkage = linkage });
        \\        @export(__aarch64_ldclr4_acq, .{ .name = "__aarch64_ldclr4_acq", .linkage = linkage });
        \\        @export(__aarch64_ldclr4_rel, .{ .name = "__aarch64_ldclr4_rel", .linkage = linkage });
        \\        @export(__aarch64_ldclr4_acq_rel, .{ .name = "__aarch64_ldclr4_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldclr8_relax, .{ .name = "__aarch64_ldclr8_relax", .linkage = linkage });
        \\        @export(__aarch64_ldclr8_acq, .{ .name = "__aarch64_ldclr8_acq", .linkage = linkage });
        \\        @export(__aarch64_ldclr8_rel, .{ .name = "__aarch64_ldclr8_rel", .linkage = linkage });
        \\        @export(__aarch64_ldclr8_acq_rel, .{ .name = "__aarch64_ldclr8_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldeor1_relax, .{ .name = "__aarch64_ldeor1_relax", .linkage = linkage });
        \\        @export(__aarch64_ldeor1_acq, .{ .name = "__aarch64_ldeor1_acq", .linkage = linkage });
        \\        @export(__aarch64_ldeor1_rel, .{ .name = "__aarch64_ldeor1_rel", .linkage = linkage });
        \\        @export(__aarch64_ldeor1_acq_rel, .{ .name = "__aarch64_ldeor1_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldeor2_relax, .{ .name = "__aarch64_ldeor2_relax", .linkage = linkage });
        \\        @export(__aarch64_ldeor2_acq, .{ .name = "__aarch64_ldeor2_acq", .linkage = linkage });
        \\        @export(__aarch64_ldeor2_rel, .{ .name = "__aarch64_ldeor2_rel", .linkage = linkage });
        \\        @export(__aarch64_ldeor2_acq_rel, .{ .name = "__aarch64_ldeor2_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldeor4_relax, .{ .name = "__aarch64_ldeor4_relax", .linkage = linkage });
        \\        @export(__aarch64_ldeor4_acq, .{ .name = "__aarch64_ldeor4_acq", .linkage = linkage });
        \\        @export(__aarch64_ldeor4_rel, .{ .name = "__aarch64_ldeor4_rel", .linkage = linkage });
        \\        @export(__aarch64_ldeor4_acq_rel, .{ .name = "__aarch64_ldeor4_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldeor8_relax, .{ .name = "__aarch64_ldeor8_relax", .linkage = linkage });
        \\        @export(__aarch64_ldeor8_acq, .{ .name = "__aarch64_ldeor8_acq", .linkage = linkage });
        \\        @export(__aarch64_ldeor8_rel, .{ .name = "__aarch64_ldeor8_rel", .linkage = linkage });
        \\        @export(__aarch64_ldeor8_acq_rel, .{ .name = "__aarch64_ldeor8_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldset1_relax, .{ .name = "__aarch64_ldset1_relax", .linkage = linkage });
        \\        @export(__aarch64_ldset1_acq, .{ .name = "__aarch64_ldset1_acq", .linkage = linkage });
        \\        @export(__aarch64_ldset1_rel, .{ .name = "__aarch64_ldset1_rel", .linkage = linkage });
        \\        @export(__aarch64_ldset1_acq_rel, .{ .name = "__aarch64_ldset1_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldset2_relax, .{ .name = "__aarch64_ldset2_relax", .linkage = linkage });
        \\        @export(__aarch64_ldset2_acq, .{ .name = "__aarch64_ldset2_acq", .linkage = linkage });
        \\        @export(__aarch64_ldset2_rel, .{ .name = "__aarch64_ldset2_rel", .linkage = linkage });
        \\        @export(__aarch64_ldset2_acq_rel, .{ .name = "__aarch64_ldset2_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldset4_relax, .{ .name = "__aarch64_ldset4_relax", .linkage = linkage });
        \\        @export(__aarch64_ldset4_acq, .{ .name = "__aarch64_ldset4_acq", .linkage = linkage });
        \\        @export(__aarch64_ldset4_rel, .{ .name = "__aarch64_ldset4_rel", .linkage = linkage });
        \\        @export(__aarch64_ldset4_acq_rel, .{ .name = "__aarch64_ldset4_acq_rel", .linkage = linkage });
        \\        @export(__aarch64_ldset8_relax, .{ .name = "__aarch64_ldset8_relax", .linkage = linkage });
        \\        @export(__aarch64_ldset8_acq, .{ .name = "__aarch64_ldset8_acq", .linkage = linkage });
        \\        @export(__aarch64_ldset8_rel, .{ .name = "__aarch64_ldset8_rel", .linkage = linkage });
        \\        @export(__aarch64_ldset8_acq_rel, .{ .name = "__aarch64_ldset8_acq_rel", .linkage = linkage });
        \\    }
        \\}
        \\
    );
}

fn usageAndExit(file: std.fs.File, arg0: []const u8, code: u8) noreturn {
    file.writer().print(
        \\Usage: {s} /path/to/lib/compiler_rt/lse_atomics.zig
        \\
        \\Generates outline atomics for compiler-rt.
        \\
    , .{arg0}) catch std.process.exit(1);
    std.process.exit(code);
}

fn writeFunction(file: *std.fs.File, name: [:0]const u8, op: AtomicOp, n: N, body: [:0]const u8) !void {
    var fn_buf: [100:0]u8 = undefined;
    const fn_sig = if (op != .cas)
        try std.fmt.bufPrintZ(&fn_buf, "fn {[name]s}(val: u{[n]s}, ptr: *u{[n]s}) callconv(.C) u{[n]s} {{", .{ .name = name, .n = n.toBits() })
    else
        try std.fmt.bufPrintZ(&fn_buf, "fn {[name]s}(expected: u{[n]s}, desired: u{[n]s}, ptr: *u{[n]s}) callconv(.C) u{[n]s} {{", .{ .name = name, .n = n.toBits() });
    try file.writeAll(fn_sig);
    try file.writeAll(
        \\
        \\    @setRuntimeSafety(false);
        \\    __init_aarch64_have_lse_atomics();
        \\
        \\    return asm volatile (
        \\
    );
    var iter = std.mem.split(u8, body, "\n");
    while (iter.next()) |line| {
        try file.writeAll("        \\\\");
        try file.writeAll(line);
        try file.writeAll("\n");
    }
    var constraint_buf: [500:0]u8 = undefined;
    const constraints = if (op != .cas)
        try std.fmt.bufPrintZ(&constraint_buf,
            \\        : [ret] "={{{[reg]s}0}}" (-> u{[ty]s}),
            \\        : [val] "{{{[reg]s}0}}" (val),
            \\          [ptr] "{{x1}}" (ptr),
            \\          [__aarch64_have_lse_atomics] "{{w16}}" (__aarch64_have_lse_atomics),
            \\        : "w15", "w16", "w17", "memory"
            \\
        , .{ .reg = n.register(), .ty = n.toBits() })
    else
        try std.fmt.bufPrintZ(&constraint_buf,
            \\        : [ret] "={{{[reg]s}0}}" (-> u{[ty]s}),
            \\        : [expected] "{{{[reg]s}0}}" (expected),
            \\          [desired] "{{{[reg]s}1}}" (desired),
            \\          [ptr] "{{x2}}" (ptr),
            \\          [__aarch64_have_lse_atomics] "{{w16}}" (__aarch64_have_lse_atomics),
            \\        : "w15", "w16", "w17", "memory"
            \\
        , .{ .reg = n.register(), .ty = n.toBits() });

    try file.writeAll(constraints);
    try file.writeAll(
        \\    );
        \\
    );
    try file.writeAll("}\n");
}

fn writeExport(file: *std.fs.File, pat: [:0]const u8, n: [:0]const u8, order: Ordering) !void {
    var darwin_lse_buf: [100:0]u8 = undefined;
    var darwin_nolse_buf: [100:0]u8 = undefined;
    var nodarwin_lse_buf: [100:0]u8 = undefined;
    var nodarwin_nolse_buf: [100:0]u8 = undefined;
    var name_buf: [100:0]u8 = undefined;
    const darwin_lse = try std.fmt.bufPrintZ(&darwin_lse_buf, "{s}{s}{s}DarwinLse", .{ pat, n, order.capName() });
    const darwin_nolse = try std.fmt.bufPrintZ(&darwin_nolse_buf, "{s}{s}{s}DarwinNolse", .{ pat, n, order.capName() });
    const nodarwin_lse = try std.fmt.bufPrintZ(&nodarwin_lse_buf, "{s}{s}{s}NondarwinLse", .{ pat, n, order.capName() });
    const nodarwin_nolse = try std.fmt.bufPrintZ(&nodarwin_nolse_buf, "{s}{s}{s}NondarwinNolse", .{ pat, n, order.capName() });
    const name = try std.fmt.bufPrintZ(&name_buf, "__aarch64_{s}{s}_{s}", .{ pat, n, @tagName(order) });
    try file.writeAll("const ");
    try file.writeAll(name);
    try file.writeAll(
        \\ = if (is_darwin)
        \\    if (has_lse)
        \\        
    );
    try file.writeAll(darwin_lse);
    try file.writeAll(
        \\
        \\    else
        \\        
    );
    try file.writeAll(darwin_nolse);
    try file.writeAll(
        \\
        \\else if (has_lse)
        \\    
    );
    try file.writeAll(nodarwin_lse);
    try file.writeAll(
        \\
        \\else
        \\    
    );
    try file.writeAll(nodarwin_nolse);
    try file.writeAll(
        \\;
        \\
    );
}

const N = enum(u8) {
    one = 1,
    two = 2,
    four = 4,
    eight = 8,
    sixteen = 16,

    const Defines = struct {
        s: [:0]const u8,
        uxt: [:0]const u8,
        b: [:0]const u8,
    };
    fn defines(self: @This()) Defines {
        const s = switch (self) {
            .one => "b",
            .two => "h",
            else => "",
        };
        const uxt = switch (self) {
            .one => "uxtb",
            .two => "uxth",
            .four, .eight, .sixteen => "mov",
        };
        const b = switch (self) {
            .one => "0x00000000",
            .two => "0x40000000",
            .four => "0x80000000",
            .eight => "0xc0000000",
            else => "0x00000000",
        };
        return Defines{
            .s = s,
            .uxt = uxt,
            .b = b,
        };
    }

    fn register(self: @This()) [:0]const u8 {
        return if (@enumToInt(self) < 8) "w" else "x";
    }

    fn toBytes(self: @This()) [:0]const u8 {
        return switch (self) {
            .one => "1",
            .two => "2",
            .four => "4",
            .eight => "8",
            .sixteen => "16",
        };
    }

    fn toBits(self: @This()) [:0]const u8 {
        return switch (self) {
            .one => "8",
            .two => "16",
            .four => "32",
            .eight => "64",
            .sixteen => "128",
        };
    }
};

const Ordering = enum {
    relax,
    acq,
    rel,
    acq_rel,

    const Defines = struct {
        suff: [:0]const u8,
        a: [:0]const u8,
        l: [:0]const u8,
        m: [:0]const u8,
        n: [:0]const u8,
    };
    fn defines(self: @This()) Defines {
        const suff = switch (self) {
            .relax => "_relax",
            .acq => "_acq",
            .rel => "_rel",
            .acq_rel => "_acq_rel",
        };
        const a = switch (self) {
            .relax => "",
            .acq => "a",
            .rel => "",
            .acq_rel => "a",
        };
        const l = switch (self) {
            .relax => "",
            .acq => "",
            .rel => "l",
            .acq_rel => "l",
        };
        const m = switch (self) {
            .relax => "0x000000",
            .acq => "0x400000",
            .rel => "0x008000",
            .acq_rel => "0x408000",
        };
        const n = switch (self) {
            .relax => "0x000000",
            .acq => "0x800000",
            .rel => "0x400000",
            .acq_rel => "0xc00000",
        };
        return .{ .suff = suff, .a = a, .l = l, .m = m, .n = n };
    }

    fn capName(self: @This()) [:0]const u8 {
        return switch (self) {
            .relax => "Relax",
            .acq => "Acq",
            .rel => "Rel",
            .acq_rel => "AcqRel",
        };
    }
};

const LdName = enum { ldadd, ldclr, ldeor, ldset };

fn generateCas(alloc: *Allocator, n: N, order: Ordering, lse: bool) ![:0]const u8 {
    const s_def = n.defines();
    const o_def = order.defines();
    var cas_buf = try alloc.create([200:0]u8);
    var ldxr_buf = try alloc.create([200:0]u8);
    var stxr_buf = try alloc.create([200:0]u8);
    defer alloc.destroy(cas_buf);
    defer alloc.destroy(ldxr_buf);
    defer alloc.destroy(stxr_buf);
    var instr_buf = try alloc.create([1000:0]u8);
    errdefer alloc.destroy(instr_buf);

    const reg = n.register();

    if (@enumToInt(n) < 16) {
        const cas = if (lse) blk: {
            break :blk try std.fmt.bufPrintZ(cas_buf,
                \\cas{[a]s}{[l]s}{[s]s} {[reg]s}0, {[reg]s}1, [x2]
                \\
            , .{ .a = o_def.a, .l = o_def.l, .s = s_def.s, .reg = reg });
        } else try std.fmt.bufPrintZ(cas_buf, ".inst 0x08a07c41 + {s} + {s}\n", .{ s_def.b, o_def.m });
        const ldxr = try std.fmt.bufPrintZ(ldxr_buf, "ld{s}xr{s}", .{ o_def.a, s_def.s });
        const stxr = try std.fmt.bufPrintZ(stxr_buf, "st{s}xr{s}", .{ o_def.l, s_def.s });

        return try std.fmt.bufPrintZ(instr_buf,
            \\        cbz     w16, 8f
            \\        {[cas]s}
            \\        cbz     wzr, 1f
            \\8:
            \\        {[uxt]s}    {[reg]s}16, {[reg]s}0
            \\0:
            \\        {[ldxr]s}   {[reg]s}0, [x2]
            \\        cmp    {[reg]s}0, {[reg]s}16
            \\        bne    1f
            \\        {[stxr]s}   w17, {[reg]s}1, [x2]
            \\        cbnz   w17, 0b
            \\1:
        , .{
            .cas = cas,
            .uxt = s_def.uxt,
            .ldxr = ldxr,
            .stxr = stxr,
            .reg = reg,
        });
    } else {
        const casp = if (lse)
            try std.fmt.bufPrintZ(cas_buf, "casp{s}{s}  x0, x1, x2, x3, [x4]\n", .{ o_def.a, o_def.l })
        else
            try std.fmt.bufPrintZ(cas_buf, ".inst 0x48207c82 + {s}\n", .{o_def.m});

        const ldxp = try std.fmt.bufPrintZ(ldxr_buf, "ld{s}xp", .{o_def.a});
        const stxp = try std.fmt.bufPrintZ(stxr_buf, "st{s}xp", .{o_def.l});

        return try std.fmt.bufPrintZ(instr_buf,
            \\        cbz     w16, 8f
            \\        {[casp]s}
            \\        cbz     wzr, 1f
            \\8:
            \\        mov    x16, x0
            \\        mov    x17, x1
            \\0:
            \\        {[ldxp]s}   x0, x1, [x4]
            \\        cmp    x0, x16
            \\        ccmp   x1, x17, #0, eq
            \\        bne    1f
            \\        {[stxp]s}   w15, x2, x3, [x4]
            \\        cbnz   w15, 0b
            \\1:
        , .{
            .casp = casp,
            .ldxp = ldxp,
            .stxp = stxp,
        });
    }
}

fn generateSwp(alloc: *Allocator, n: N, order: Ordering, lse: bool) ![:0]const u8 {
    const s_def = n.defines();
    const o_def = order.defines();

    var swp_buf = try alloc.create([200:0]u8);
    var ldxr_buf = try alloc.create([200:0]u8);
    var stxr_buf = try alloc.create([200:0]u8);
    defer alloc.destroy(swp_buf);
    defer alloc.destroy(ldxr_buf);
    defer alloc.destroy(stxr_buf);

    const reg = n.register();

    const swp = if (lse) blk: {
        break :blk try std.fmt.bufPrintZ(swp_buf,
            \\swp{[a]s}{[l]s}{[s]s}  {[reg]s}0, {[reg]s}0, [x1]
        , .{ .a = o_def.a, .l = o_def.l, .s = s_def.s, .reg = reg });
    } else std.fmt.bufPrintZ(swp_buf, ".inst 0x38208020 + {s} + {s}", .{ .b = s_def.b, .n = o_def.n });

    const ldxr = try std.fmt.bufPrintZ(ldxr_buf, "ld{s}xr{s}", .{ o_def.a, s_def.s });
    const stxr = try std.fmt.bufPrintZ(stxr_buf, "st{s}xr{s}", .{ o_def.l, s_def.s });

    var instr_buf = try alloc.create([1000:0]u8);
    errdefer alloc.destroy(instr_buf);
    return try std.fmt.bufPrintZ(instr_buf,
        \\        cbz     w16, 8f
        \\        {[swp]s}
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    {[reg]s}16, {[reg]s}0
        \\0:
        \\        {[ldxr]s}   {[reg]s}0, [x1]
        \\        {[stxr]s}   w17, {[reg]s}16, [x1]
        \\        cbnz   w17, 0b
        \\1:
    , .{
        .swp = swp,
        .ldxr = ldxr,
        .stxr = stxr,
        .reg = reg,
    });
}

fn generateLd(alloc: *Allocator, n: N, order: Ordering, ld: LdName, lse: bool) ![:0]const u8 {
    const s_def = n.defines();
    const o_def = order.defines();
    const ldname = @tagName(ld);
    const op = switch (ld) {
        .ldadd => "add",
        .ldclr => "bic",
        .ldeor => "eor",
        .ldset => "orr",
    };
    const op_n = switch (ld) {
        .ldadd => "0x0000",
        .ldclr => "0x1000",
        .ldeor => "0x2000",
        .ldset => "0x3000",
    };

    var swp_buf = try alloc.create([200:0]u8);
    var ldop_buf = try alloc.create([200:0]u8);
    var ldxr_buf = try alloc.create([200:0]u8);
    var stxr_buf = try alloc.create([200:0]u8);
    defer alloc.destroy(swp_buf);
    defer alloc.destroy(ldop_buf);
    defer alloc.destroy(ldxr_buf);
    defer alloc.destroy(stxr_buf);

    const reg = n.register();

    const ldop = if (lse)
        std.fmt.bufPrintZ(ldop_buf,
            \\{[ldnm]s}{[a]s}{[l]s}{[s]s} {[reg]s}0, {[reg]s}0, [x1]
        , .{ .ldnm = ldname, .a = o_def.a, .l = o_def.l, .s = s_def.s, .reg = reg })
    else
        std.fmt.bufPrintZ(ldop_buf,
            \\.inst 0x38200020 + {[op_n]s} + {[b]s} + {[n]s}
        , .{ .op_n = op_n, .b = s_def.b, .n = o_def.n });

    const ldxr = try std.fmt.bufPrintZ(ldxr_buf, "ld{s}xr{s}", .{ o_def.a, s_def.s });
    const stxr = try std.fmt.bufPrintZ(stxr_buf, "st{s}xr{s}", .{ o_def.l, s_def.s });

    var instr_buf = try alloc.create([1000:0]u8);
    errdefer alloc.destroy(instr_buf);
    return try std.fmt.bufPrintZ(instr_buf,
        \\        cbz     w16, 8f
        \\        {[ldop]s}
        \\        cbz     wzr, 1f
        \\8:
        \\        mov    {[reg]s}16, {[reg]s}0
        \\0:
        \\        {[ldxr]s}   {[reg]s}0, [x1]
        \\        {[op]s}     {[reg]s}17, {[reg]s}0, {[reg]s}16
        \\        {[stxr]s}   w15, {[reg]s}17, [x1]
        \\        cbnz   w15, 0b
        \\1:
    , .{
        .ldop = ldop,
        .ldxr = ldxr,
        .stxr = stxr,
        .op = op,
        .reg = reg,
    });
}
