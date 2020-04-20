const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const assert = std.debug.assert;
const text = @import("ir/text.zig");

/// These are in-memory, analyzed instructions. See `text.Inst` for the representation
/// of instructions that correspond to the ZIR text format.
pub const Inst = struct {
    pub fn ty(base: *Inst) ?Type {
        switch (base.tag) {
            .constant => return base.cast(Constant).?.ty,
            .@"asm" => return base.cast(Assembly).?.ty,
            .@"fn" => return base.cast(Fn).?.ty,

            .ptrtoint => return Type.initTag(.@"usize"),
            .@"unreachable" => return Type.initTag(.@"noreturn"),
            .@"export" => return Type.initTag(.@"void"),
            .fntype, .primitive => return Type.initTag(.@"type"),

            .fieldptr,
            .deref,
            => return null,
        }
    }

    /// This struct owns the `Value` memory. When the struct is deallocated,
    /// so is the `Value`. The value of a constant must be copied into
    /// a memory location for the value to survive after a const instruction.
    pub const Constant = struct {
        base: Inst = Inst{ .tag = .constant },
        ty: Type,

        positionals: struct {
            value: Value,
        },
        kw_args: struct {},
    };
};

const Analyze = struct {
    allocator: *Allocator,
    old_tree: *const Module,
    errors: std.ArrayList(ErrorMsg),
    decls: std.ArrayList(*Inst),

    const NewInst = struct {
        ptr: *Inst,
    };
};

pub fn analyze(allocator: *Allocator, old_tree: Module) !Module {
    var ctx = Analyze{
        .allocator = allocator,
        .old_tree = &old_tree,
        .decls = std.ArrayList(*Inst).init(allocator),
        .errors = std.ArrayList(ErrorMsg).init(allocator),
        .inst_table = std.HashMap(*Inst, Analyze.InstData).init(allocator),
    };
    defer ctx.decls.deinit();
    defer ctx.errors.deinit();
    defer inst_table.deinit();

    analyzeRoot(&ctx) catch |err| switch (err) {
        error.AnalyzeFailure => {
            assert(ctx.errors.items.len != 0);
        },
        else => |e| return e,
    };
    return Module{
        .decls = ctx.decls.toOwnedSlice(),
        .errors = ctx.errors.toOwnedSlice(),
    };
}

fn analyzeRoot(ctx: *Analyze) !void {
    for (old_tree.decls) |decl| {
        if (decl.cast(Inst.Export)) |export_inst| {
            try analyzeExport(ctx, export_inst);
        }
    }
}

fn analyzeExport(ctx: *Analyze, export_inst: *Inst.Export) !void {
    const old_decl = export_inst.positionals.value;
    const new_info = ctx.inst_table.get(old_exp_target) orelse blk: {
        const new_decl = try analyzeDecl(ctx, old_decl);
        const new_info: Analyze.NewInst = .{ .ptr = new_decl };
        try ctx.inst_table.put(old_decl, new_info);
        break :blk new_info;
    };

    //const exp_type = new_info.ptr.ty();
    //switch (exp_type.zigTypeTag()) {
    //    .Fn => {
    //        if () |kv| {
    //            kv.value
    //        }
    //        return analyzeExportFn(ctx, exp_target.cast(Inst.,
    //    },
    //    else => return ctx.fail("unable to export type '{}'", .{exp_type}),
    //}
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    const src_path = args[1];
    const debug_error_trace = true;

    const source = try std.fs.cwd().readFileAllocOptions(allocator, src_path, std.math.maxInt(u32), 1, 0);

    var tree = try text.parse(allocator, source);
    defer tree.deinit();

    if (tree.errors.len != 0) {
        for (tree.errors) |err_msg| {
            const loc = findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.ParseFailure;
        std.process.exit(1);
    }

    tree.dump();

    //const new_tree = try analyze(allocator, tree);
    //defer new_tree.deinit();

    //if (new_tree.errors.len != 0) {
    //    for (new_tree.errors) |err_msg| {
    //        const loc = findLineColumn(source, err_msg.byte_offset);
    //        std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
    //    }
    //    if (debug_error_trace) return error.ParseFailure;
    //    std.process.exit(1);
    //}

    //new_tree.dump();
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
