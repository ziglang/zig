const std = @import("std");
const Compilation = @import("Compilation.zig");
const Tree = @import("Tree.zig");
const NodeIndex = Tree.NodeIndex;
const Object = @import("Object.zig");
const x86_64 = @import("codegen/x86_64.zig");

const Codegen = @This();

comp: *Compilation,
tree: Tree,
obj: *Object,
node_tag: []const Tree.Tag,
node_data: []const Tree.Node.Data,

pub const Error = Compilation.Error || error{CodegenFailed};

/// Generate tree to an object file.
/// Caller is responsible for flushing and freeing the returned object.
pub fn generateTree(comp: *Compilation, tree: Tree) Compilation.Error!*Object {
    var c = Codegen{
        .comp = comp,
        .tree = tree,
        .obj = try Object.create(comp),
        .node_tag = tree.nodes.items(.tag),
        .node_data = tree.nodes.items(.data),
    };
    errdefer c.obj.deinit();

    const node_tags = tree.nodes.items(.tag);
    for (tree.root_decls) |decl| {
        switch (node_tags[@intFromEnum(decl)]) {
            // these produce no code
            .static_assert,
            .typedef,
            .struct_decl_two,
            .union_decl_two,
            .enum_decl_two,
            .struct_decl,
            .union_decl,
            .enum_decl,
            .struct_forward_decl,
            .union_forward_decl,
            .enum_forward_decl,
            => {},

            // define symbol
            .fn_proto,
            .static_fn_proto,
            .inline_fn_proto,
            .inline_static_fn_proto,
            .extern_var,
            .threadlocal_extern_var,
            => {
                const name = c.tree.tokSlice(c.node_data[@intFromEnum(decl)].decl.name);
                _ = try c.obj.declareSymbol(.undefined, name, .Strong, .external, 0, 0);
            },

            // function definition
            .fn_def,
            .static_fn_def,
            .inline_fn_def,
            .inline_static_fn_def,
            => c.genFn(decl) catch |err| switch (err) {
                error.FatalError => return error.FatalError,
                error.OutOfMemory => return error.OutOfMemory,
                error.CodegenFailed => continue,
            },

            .@"var",
            .static_var,
            .threadlocal_var,
            .threadlocal_static_var,
            .implicit_static_var,
            => c.genVar(decl) catch |err| switch (err) {
                error.FatalError => return error.FatalError,
                error.OutOfMemory => return error.OutOfMemory,
                error.CodegenFailed => continue,
            },

            // TODO
            .file_scope_asm => {},

            else => unreachable,
        }
    }

    return c.obj;
}

fn genFn(c: *Codegen, decl: NodeIndex) Error!void {
    const section: Object.Section = .func;
    const data = try c.obj.getSection(section);
    const start_len = data.items.len;
    switch (c.comp.target.cpu.arch) {
        .x86_64 => try x86_64.genFn(c, decl, data),
        else => unreachable,
    }
    const name = c.tree.tokSlice(c.node_data[@intFromEnum(decl)].decl.name);
    _ = try c.obj.declareSymbol(section, name, .Strong, .func, start_len, data.items.len - start_len);
}

fn genVar(c: *Codegen, decl: NodeIndex) Error!void {
    switch (c.comp.target.cpu.arch) {
        .x86_64 => try x86_64.genVar(c, decl),
        else => unreachable,
    }
}
