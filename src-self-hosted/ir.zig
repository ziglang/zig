const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const assert = std.debug.assert;
const text = @import("ir/text.zig");

/// These are in-memory, analyzed instructions. See `text.Inst` for the representation
/// of instructions that correspond to the ZIR text format.
/// This struct owns the `Value` and `Type` memory. When the struct is deallocated,
/// so are the `Value` and `Type`. The value of a constant must be copied into
/// a memory location for the value to survive after a const instruction.
pub const Inst = struct {
    tag: Tag,
    ty: Type,
    src_offset: usize,

    pub const Tag = enum {
        unreach,
        constant,
        assembly,
    };

    pub fn cast(base: *Inst, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub const Constant = struct {
        pub const base_tag = Tag.constant;
        base: Inst,

        val: Value,
    };

    pub const Assembly = struct {
        pub const base_tag = Tag.assembly;
        base: Inst,

        asm_source: []const u8,
        is_volatile: bool,
        output: []const u8,
        inputs: []const []const u8,
        clobbers: []const []const u8,
        args: []const []const u8,
    };
};

const TypedValue = struct {
    ty: Type,
    val: Value,
};

pub const Module = struct {
    exports: []Export,
    errors: []ErrorMsg,
    arena: std.heap.ArenaAllocator,

    pub const Export = struct {
        name: []const u8,
        typed_value: TypedValue,
    };

    pub fn deinit(self: *Module, allocator: *Allocator) void {
        allocator.free(self.exports);
        allocator.free(self.errors);
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn emit_zir(self: Module, allocator: *Allocator) !text.Module {
        return error.TodoImplementEmitToZIR;
    }
};

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub fn analyze(allocator: *Allocator, old_module: text.Module) !Module {
    var ctx = Analyze{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .old_module = &old_module,
        .errors = std.ArrayList(ErrorMsg).init(allocator),
        .inst_table = std.AutoHashMap(*text.Inst, Analyze.NewInst).init(allocator),
        .exports = std.ArrayList(Module.Export).init(allocator),
    };
    defer ctx.errors.deinit();
    defer ctx.inst_table.deinit();
    defer ctx.exports.deinit();

    ctx.analyzeRoot() catch |err| switch (err) {
        error.AnalysisFail => {
            assert(ctx.errors.items.len != 0);
        },
        else => |e| return e,
    };
    return Module{
        .exports = ctx.exports.toOwnedSlice(),
        .errors = ctx.errors.toOwnedSlice(),
        .arena = ctx.arena,
    };
}

const Analyze = struct {
    allocator: *Allocator,
    arena: std.heap.ArenaAllocator,
    old_module: *const text.Module,
    errors: std.ArrayList(ErrorMsg),
    inst_table: std.AutoHashMap(*text.Inst, NewInst),
    exports: std.ArrayList(Module.Export),

    const NewInst = struct {
        /// null means a semantic analysis error happened
        ptr: ?*Inst,
    };

    const InnerError = error{ OutOfMemory, AnalysisFail };

    fn analyzeRoot(self: *Analyze) !void {
        for (self.old_module.decls) |decl| {
            if (decl.cast(text.Inst.Export)) |export_inst| {
                try analyzeExport(self, export_inst);
            }
        }
    }

    fn resolveInst(self: *Analyze, old_inst: *text.Inst) InnerError!*Inst {
        if (self.inst_table.get(old_inst)) |kv| {
            return kv.value.ptr orelse return error.AnalysisFail;
        } else {
            const new_inst = self.analyzeDecl(old_inst) catch |err| switch (err) {
                error.AnalysisFail => {
                    try self.inst_table.putNoClobber(old_inst, .{ .ptr = null });
                    return error.AnalysisFail;
                },
                else => |e| return e,
            };
            try self.inst_table.putNoClobber(old_inst, .{ .ptr = new_inst });
            return new_inst;
        }
    }

    fn resolveInstConst(self: *Analyze, old_inst: *text.Inst) InnerError!TypedValue {
        const new_inst = try self.resolveInst(old_inst);
        const val = try self.resolveConstValue(new_inst);
        return TypedValue{
            .ty = new_inst.ty,
            .val = val,
        };
    }

    fn resolveConstValue(self: *Analyze, base: *Inst) !Value {
        const const_inst = base.cast(Inst.Constant) orelse
            return self.fail(base.src_offset, "unable to resolve comptime value", .{});
        return const_inst.val;
    }

    fn resolveConstString(self: *Analyze, old_inst: *text.Inst) ![]u8 {
        const new_inst = try self.resolveInst(old_inst);
        const wanted_type = Type.initTag(.const_slice_u8);
        const coerced_inst = try self.coerce(wanted_type, new_inst);
        const val = try self.resolveConstValue(coerced_inst);
        return val.toAllocatedBytes(&self.arena.allocator);
    }

    fn analyzeExport(self: *Analyze, export_inst: *text.Inst.Export) !void {
        const symbol_name = try self.resolveConstString(export_inst.positionals.symbol_name);
        const typed_value = try self.resolveInstConst(export_inst.positionals.value);

        switch (typed_value.ty.zigTypeTag()) {
            .Fn => {},
            else => return self.fail(
                export_inst.positionals.value.src_offset,
                "unable to export type '{}'",
                .{typed_value.ty},
            ),
        }
        try self.exports.append(.{
            .name = symbol_name,
            .typed_value = typed_value,
        });
    }

    fn analyzeDecl(self: *Analyze, old_inst: *text.Inst) !*Inst {
        switch (old_inst.tag) {
            .str => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .int => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .ptrtoint => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .fieldptr => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .deref => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .as => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .@"asm" => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .@"unreachable" => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .@"fn" => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .@"export" => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .primitive => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
            .fntype => return self.fail(old_inst.src_offset, "TODO implement analyzing {}", .{@tagName(old_inst.tag)}),
        }
    }

    fn coerce(self: *Analyze, dest_type: Type, inst: *Inst) !*Inst {
        return self.fail(inst.src_offset, "TODO implement type coercion", .{});
    }

    fn fail(self: *Analyze, src_offset: usize, comptime format: []const u8, args: var) InnerError {
        @setCold(true);
        const msg = try std.fmt.allocPrint(&self.arena.allocator, format, args);
        (try self.errors.addOne()).* = .{
            .byte_offset = src_offset,
            .msg = msg,
        };
        return error.AnalysisFail;
    }
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = if (std.builtin.link_libc) std.heap.c_allocator else &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    const src_path = args[1];
    const debug_error_trace = true;

    const source = try std.fs.cwd().readFileAllocOptions(allocator, src_path, std.math.maxInt(u32), 1, 0);

    var zir_module = try text.parse(allocator, source);
    defer zir_module.deinit(allocator);

    if (zir_module.errors.len != 0) {
        for (zir_module.errors) |err_msg| {
            const loc = findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.ParseFailure;
        std.process.exit(1);
    }

    var analyzed_module = try analyze(allocator, zir_module);
    defer analyzed_module.deinit(allocator);

    if (analyzed_module.errors.len != 0) {
        for (analyzed_module.errors) |err_msg| {
            const loc = findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.ParseFailure;
        std.process.exit(1);
    }

    var new_zir_module = try analyzed_module.emit_zir(allocator);
    defer new_zir_module.deinit(allocator);

    new_zir_module.dump();
}

fn findLineColumn(source: []const u8, byte_offset: usize) struct { line: usize, column: usize } {
    var line: usize = 0;
    var column: usize = 0;
    for (source[0..byte_offset]) |byte| {
        switch (byte) {
            '\n' => {
                line += 1;
                column = 0;
            },
            else => {
                column += 1;
            },
        }
    }
    return .{ .line = line, .column = column };
}

// Performance optimization ideas:
// * when analyzing use a field in the Inst instead of HashMap to track corresponding instructions
