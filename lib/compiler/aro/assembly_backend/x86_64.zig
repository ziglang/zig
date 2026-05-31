const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const aro = @import("aro");
const Assembly = aro.Assembly;
const Compilation = aro.Compilation;
const Node = Tree.Node;
const Source = aro.Source;
const Tree = aro.Tree;
const QualType = aro.QualType;
const Value = aro.Value;

const AsmCodeGen = @This();
const Error = aro.Compilation.Error;

tree: *const Tree,
comp: *Compilation,
text: *std.Io.Writer,
data: *std.Io.Writer,

const StorageUnit = enum(u8) {
    byte = 8,
    short = 16,
    long = 32,
    quad = 64,

    fn trunc(self: StorageUnit, val: u64) u64 {
        return switch (self) {
            .byte => @as(u8, @truncate(val)),
            .short => @as(u16, @truncate(val)),
            .long => @as(u32, @truncate(val)),
            .quad => val,
        };
    }
};

fn serializeInt(value: u64, storage_unit: StorageUnit, w: *std.Io.Writer) !void {
    try w.print("  .{s}  0x{x}\n", .{ @tagName(storage_unit), storage_unit.trunc(value) });
}

fn serializeFloat(comptime T: type, value: T, w: *std.Io.Writer) !void {
    switch (T) {
        f128 => {
            const bytes = std.mem.asBytes(&value);
            const first = std.mem.bytesToValue(u64, bytes[0..8]);
            try serializeInt(first, .quad, w);
            const second = std.mem.bytesToValue(u64, bytes[8..16]);
            return serializeInt(second, .quad, w);
        },
        f80 => {
            const bytes = std.mem.asBytes(&value);
            const first = std.mem.bytesToValue(u64, bytes[0..8]);
            try serializeInt(first, .quad, w);
            const second = std.mem.bytesToValue(u16, bytes[8..10]);
            try serializeInt(second, .short, w);
            return w.writeAll("  .zero 6\n");
        },
        else => {
            const size = @bitSizeOf(T);
            const storage_unit = std.meta.intToEnum(StorageUnit, size) catch unreachable;
            const IntTy = @Int(.unsigned, size);
            const int_val: IntTy = @bitCast(value);
            return serializeInt(int_val, storage_unit, w);
        },
    }
}

pub fn todo(c: *AsmCodeGen, msg: []const u8, tok: Tree.TokenIndex) Error {
    const loc: Source.Location = c.tree.tokens.items(.loc)[tok];

    var sf = std.heap.stackFallback(1024, c.comp.gpa);
    const allocator = sf.get();
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    try buf.print(allocator, "TODO: {s}", .{msg});
    try c.comp.diagnostics.add(.{
        .text = buf.items,
        .kind = .@"error",
        .location = loc.expand(c.comp),
    });
    return error.FatalError;
}

fn emitAggregate(c: *AsmCodeGen, qt: QualType, node: Node.Index) !void {
    _ = qt;
    return c.todo("Codegen aggregates", node.tok(c.tree));
}

fn emitSingleValue(c: *AsmCodeGen, qt: QualType, node: Node.Index) !void {
    const value = c.tree.value_map.get(node) orelse return;
    const bit_size = qt.bitSizeof(c.comp);
    const scalar_kind = qt.scalarKind(c.comp);
    if (!scalar_kind.isReal()) {
        return c.todo("Codegen _Complex values", node.tok(c.tree));
    } else if (scalar_kind.isInt()) {
        const storage_unit = std.meta.intToEnum(StorageUnit, bit_size) catch return c.todo("Codegen _BitInt values", node.tok(c.tree));
        try c.data.print("  .{s} ", .{@tagName(storage_unit)});
        _ = try value.print(qt, c.comp, c.data);
        try c.data.writeByte('\n');
    } else if (scalar_kind.isFloat()) {
        switch (bit_size) {
            16 => return serializeFloat(f16, value.toFloat(f16, c.comp), c.data),
            32 => return serializeFloat(f32, value.toFloat(f32, c.comp), c.data),
            64 => return serializeFloat(f64, value.toFloat(f64, c.comp), c.data),
            80 => return serializeFloat(f80, value.toFloat(f80, c.comp), c.data),
            128 => return serializeFloat(f128, value.toFloat(f128, c.comp), c.data),
            else => unreachable,
        }
    } else if (scalar_kind.isPointer()) {
        return c.todo("Codegen pointer", node.tok(c.tree));
    } else if (qt.is(c.comp, .array)) {
        // Todo:
        //  Handle truncated initializers e.g. char x[3] = "hello";
        //  Zero out remaining bytes if initializer is shorter than storage capacity
        //  Handle non-char strings
        const bytes = value.toBytes(c.comp);
        const directive = if (bytes.len > bit_size / 8) "ascii" else "string";
        try c.data.print("  .{s} ", .{directive});
        try Value.printString(bytes, qt, c.comp, c.data);

        try c.data.writeByte('\n');
    } else unreachable;
}

fn emitValue(c: *AsmCodeGen, qt: QualType, node: Node.Index) !void {
    switch (node.get(c.tree)) {
        .array_init_expr,
        .struct_init_expr,
        .union_init_expr,
        => return c.todo("Codegen multiple inits", node.tok(c.tree)),
        else => return c.emitSingleValue(qt, node),
    }
}

pub fn genAsm(tree: *const Tree) Error!Assembly {
    var data: std.Io.Writer.Allocating = .init(tree.comp.gpa);
    defer data.deinit();

    var text: std.Io.Writer.Allocating = .init(tree.comp.gpa);
    defer text.deinit();

    var codegen: AsmCodeGen = .{
        .tree = tree,
        .comp = tree.comp,
        .text = &text.writer,
        .data = &data.writer,
    };

    codegen.genDecls() catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        error.OutOfMemory => return error.OutOfMemory,
        error.FatalError => return error.FatalError,
    };

    const text_slice = try text.toOwnedSlice();
    errdefer tree.comp.gpa.free(text_slice);
    const data_slice = try data.toOwnedSlice();
    return .{
        .text = text_slice,
        .data = data_slice,
    };
}

fn genDecls(c: *AsmCodeGen) !void {
    if (c.tree.comp.code_gen_options.debug != .strip) {
        const sources = c.tree.comp.sources.values();
        for (sources) |source| {
            try c.data.print("  .file {d} \"{s}\"\n", .{ @intFromEnum(source.id.index) + 1, source.path });
        }
    }

    for (c.tree.root_decls.items) |decl| {
        switch (decl.get(c.tree)) {
            .static_assert,
            .typedef,
            .struct_decl,
            .union_decl,
            .enum_decl,
            => {},

            .function => |function| {
                if (function.body == null) continue;
                try c.genFn(function);
            },

            .variable => |variable| try c.genVar(variable),

            else => unreachable,
        }
    }
    try c.text.writeAll("  .section  .note.GNU-stack,\"\",@progbits\n");
}

fn genFn(c: *AsmCodeGen, function: Node.Function) !void {
    return c.todo("Codegen functions", function.name_tok);
}

fn genVar(c: *AsmCodeGen, variable: Node.Variable) !void {
    const comp = c.comp;
    const qt = variable.qt;

    const is_tentative = variable.initializer == null;
    const size = qt.sizeofOrNull(comp) orelse blk: {
        // tentative array definition assumed to have one element
        std.debug.assert(is_tentative and qt.is(c.comp, .array));
        break :blk qt.childType(c.comp).sizeof(comp);
    };

    const name = c.tree.tokSlice(variable.name_tok);
    const nat_align = qt.alignof(comp);
    const alignment = if (qt.is(c.comp, .array) and size >= 16) @max(16, nat_align) else nat_align;

    if (variable.storage_class == .static) {
        try c.data.print("  .local \"{s}\"\n", .{name});
    } else {
        try c.data.print("  .globl \"{s}\"\n", .{name});
    }

    if (is_tentative and comp.code_gen_options.common) {
        try c.data.print("  .comm \"{s}\", {d}, {d}\n", .{ name, size, alignment });
        return;
    }
    if (variable.initializer) |init| {
        if (variable.thread_local and comp.code_gen_options.data_sections) {
            try c.data.print("  .section .tdata.\"{s}\",\"awT\",@progbits\n", .{name});
        } else if (variable.thread_local) {
            try c.data.writeAll("  .section .tdata,\"awT\",@progbits\n");
        } else if (comp.code_gen_options.data_sections) {
            try c.data.print("  .section .data.\"{s}\",\"aw\",@progbits\n", .{name});
        } else {
            try c.data.writeAll("  .data\n");
        }

        try c.data.print("  .type \"{s}\", @object\n", .{name});
        try c.data.print("  .size \"{s}\", {d}\n", .{ name, size });
        try c.data.print("  .align {d}\n", .{alignment});
        try c.data.print("\"{s}\":\n", .{name});
        try c.emitValue(qt, init);
        return;
    }
    if (variable.thread_local and comp.code_gen_options.data_sections) {
        try c.data.print("  .section .tbss.\"{s}\",\"awT\",@nobits\n", .{name});
    } else if (variable.thread_local) {
        try c.data.writeAll("  .section .tbss,\"awT\",@nobits\n");
    } else if (comp.code_gen_options.data_sections) {
        try c.data.print("  .section .bss.\"{s}\",\"aw\",@nobits\n", .{name});
    } else {
        try c.data.writeAll("  .bss\n");
    }
    try c.data.print("  .align {d}\n", .{alignment});
    try c.data.print("\"{s}\":\n", .{name});
    try c.data.print("  .zero {d}\n", .{size});
}
