pub fn renderToWriter(zoir: Zoir, arena: Allocator, w: *std.io.BufferedWriter) anyerror!void {
    assert(!zoir.hasCompileErrors());

    const bytes_per_node = comptime n: {
        var n: usize = 0;
        for (@typeInfo(Zoir.Node.Repr).@"struct".fields) |f| {
            n += @sizeOf(f.type);
        }
        break :n n;
    };

    const node_bytes = zoir.nodes.len * bytes_per_node;
    const extra_bytes = zoir.extra.len * @sizeOf(u32);
    const limb_bytes = zoir.limbs.len * @sizeOf(std.math.big.Limb);
    const string_bytes = zoir.string_bytes.len;

    // zig fmt: off
    try w.print(
        \\# Nodes:              {} ({Bi})
        \\# Extra Data Items:   {} ({Bi})
        \\# BigInt Limbs:       {} ({Bi})
        \\# String Table Bytes: {Bi}
        \\# Total ZON Bytes:    {Bi}
        \\
    , .{
        zoir.nodes.len, node_bytes,
        zoir.extra.len, extra_bytes,
        zoir.limbs.len, limb_bytes,
        string_bytes,
        node_bytes + extra_bytes + limb_bytes + string_bytes,
    });
    // zig fmt: on
    var pz: PrintZon = .{
        .w = w,
        .arena = arena,
        .zoir = zoir,
        .indent = 0,
    };

    return @errorCast(pz.renderRoot());
}

const PrintZon = struct {
    w: *std.io.BufferedWriter,
    arena: Allocator,
    zoir: Zoir,
    indent: u32,

    fn renderRoot(pz: *PrintZon) anyerror!void {
        try pz.renderNode(.root);
        try pz.w.writeByte('\n');
    }

    fn renderNode(pz: *PrintZon, node: Zoir.Node.Index) anyerror!void {
        const zoir = pz.zoir;
        try pz.w.print("%{d} = ", .{@intFromEnum(node)});
        switch (node.get(zoir)) {
            .true => try pz.w.writeAll("true"),
            .false => try pz.w.writeAll("false"),
            .null => try pz.w.writeAll("null"),
            .pos_inf => try pz.w.writeAll("inf"),
            .neg_inf => try pz.w.writeAll("-inf"),
            .nan => try pz.w.writeAll("nan"),
            .int_literal => |storage| switch (storage) {
                .small => |x| try pz.w.print("int({d})", .{x}),
                .big => |x| {
                    const str = try x.toStringAlloc(pz.arena, 10, .lower);
                    try pz.w.print("int(big {s})", .{str});
                },
            },
            .float_literal => |x| try pz.w.print("float({d})", .{x}),
            .char_literal => |x| try pz.w.print("char({d})", .{x}),
            .enum_literal => |x| try pz.w.print("enum_literal({p})", .{std.zig.fmtId(x.get(zoir))}),
            .string_literal => |x| try pz.w.print("str(\"{}\")", .{std.zig.fmtEscapes(x)}),
            .empty_literal => try pz.w.writeAll("empty_literal(.{})"),
            .array_literal => |vals| {
                try pz.w.writeAll("array_literal({");
                pz.indent += 1;
                for (0..vals.len) |idx| {
                    try pz.newline();
                    try pz.renderNode(vals.at(@intCast(idx)));
                    try pz.w.writeByte(',');
                }
                pz.indent -= 1;
                try pz.newline();
                try pz.w.writeAll("})");
            },
            .struct_literal => |s| {
                try pz.w.writeAll("struct_literal({");
                pz.indent += 1;
                for (s.names, 0..s.vals.len) |name, idx| {
                    try pz.newline();
                    try pz.w.print("[{p}] ", .{std.zig.fmtId(name.get(zoir))});
                    try pz.renderNode(s.vals.at(@intCast(idx)));
                    try pz.w.writeByte(',');
                }
                pz.indent -= 1;
                try pz.newline();
                try pz.w.writeAll("})");
            },
        }
    }

    fn newline(pz: *PrintZon) !void {
        try pz.w.writeByte('\n');
        try pz.w.splatByteAll(' ', 2 * pz.indent);
    }
};

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Zoir = std.zig.Zoir;
