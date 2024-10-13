const std = @import("std");
const backend = @import("../../backend.zig");
const Interner = backend.Interner;
const Builtins = @import("../Builtins.zig");
const Builtin = Builtins.Builtin;
const Parser = @import("../Parser.zig");
const Tree = @import("../Tree.zig");
const NodeIndex = Tree.NodeIndex;
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");

fn makeNan(comptime T: type, str: []const u8) T {
    const UnsignedSameSize = std.meta.Int(.unsigned, @bitSizeOf(T));
    const parsed = std.fmt.parseUnsigned(UnsignedSameSize, str[0 .. str.len - 1], 0) catch 0;
    const bits: switch (T) {
        f32 => u23,
        f64 => u52,
        f80 => u63,
        f128 => u112,
        else => @compileError("Invalid type for makeNan"),
    } = @truncate(parsed);
    return @bitCast(@as(UnsignedSameSize, bits) | @as(UnsignedSameSize, @bitCast(std.math.nan(T))));
}

pub fn eval(tag: Builtin.Tag, p: *Parser, args: []const NodeIndex) !Value {
    const builtin = Builtin.fromTag(tag);
    if (!builtin.properties.attributes.const_evaluable) return .{};

    switch (tag) {
        Builtin.tagFromName("__builtin_inff").?,
        Builtin.tagFromName("__builtin_inf").?,
        Builtin.tagFromName("__builtin_infl").?,
        => {
            const ty: Type = switch (tag) {
                Builtin.tagFromName("__builtin_inff").? => .{ .specifier = .float },
                Builtin.tagFromName("__builtin_inf").? => .{ .specifier = .double },
                Builtin.tagFromName("__builtin_infl").? => .{ .specifier = .long_double },
                else => unreachable,
            };
            const f: Interner.Key.Float = switch (ty.bitSizeof(p.comp).?) {
                32 => .{ .f32 = std.math.inf(f32) },
                64 => .{ .f64 = std.math.inf(f64) },
                80 => .{ .f80 = std.math.inf(f80) },
                128 => .{ .f128 = std.math.inf(f128) },
                else => unreachable,
            };
            return Value.intern(p.comp, .{ .float = f });
        },
        Builtin.tagFromName("__builtin_isinf").? => blk: {
            if (args.len == 0) break :blk;
            const val = p.value_map.get(args[0]) orelse break :blk;
            return Value.fromBool(val.isInf(p.comp));
        },
        Builtin.tagFromName("__builtin_isinf_sign").? => blk: {
            if (args.len == 0) break :blk;
            const val = p.value_map.get(args[0]) orelse break :blk;
            switch (val.isInfSign(p.comp)) {
                .unknown => {},
                .finite => return Value.zero,
                .positive => return Value.one,
                .negative => return Value.int(@as(i64, -1), p.comp),
            }
        },
        Builtin.tagFromName("__builtin_isnan").? => blk: {
            if (args.len == 0) break :blk;
            const val = p.value_map.get(args[0]) orelse break :blk;
            return Value.fromBool(val.isNan(p.comp));
        },
        Builtin.tagFromName("__builtin_nan").? => blk: {
            if (args.len == 0) break :blk;
            const val = p.getDecayedStringLiteral(args[0]) orelse break :blk;
            const bytes = p.comp.interner.get(val.ref()).bytes;

            const f: Interner.Key.Float = switch ((Type{ .specifier = .double }).bitSizeof(p.comp).?) {
                32 => .{ .f32 = makeNan(f32, bytes) },
                64 => .{ .f64 = makeNan(f64, bytes) },
                80 => .{ .f80 = makeNan(f80, bytes) },
                128 => .{ .f128 = makeNan(f128, bytes) },
                else => unreachable,
            };
            return Value.intern(p.comp, .{ .float = f });
        },
        else => {},
    }
    return .{};
}
