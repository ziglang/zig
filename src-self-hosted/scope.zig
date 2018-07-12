const std = @import("std");
const Allocator = mem.Allocator;
const Decl = @import("decl.zig").Decl;
const Module = @import("module.zig").Module;
const mem = std.mem;
const ast = std.zig.ast;
const Value = @import("value.zig").Value;
const ir = @import("ir.zig");

pub const Scope = struct {
    id: Id,
    parent: ?*Scope,
    ref_count: usize,

    pub fn ref(base: *Scope) void {
        base.ref_count += 1;
    }

    pub fn deref(base: *Scope, module: *Module) void {
        base.ref_count -= 1;
        if (base.ref_count == 0) {
            if (base.parent) |parent| parent.deref(module);
            switch (base.id) {
                Id.Decls => @fieldParentPtr(Decls, "base", base).destroy(),
                Id.Block => @fieldParentPtr(Block, "base", base).destroy(module),
                Id.FnDef => @fieldParentPtr(FnDef, "base", base).destroy(module),
                Id.CompTime => @fieldParentPtr(CompTime, "base", base).destroy(module),
                Id.Defer => @fieldParentPtr(Defer, "base", base).destroy(module),
                Id.DeferExpr => @fieldParentPtr(DeferExpr, "base", base).destroy(module),
            }
        }
    }

    pub fn findFnDef(base: *Scope) ?*FnDef {
        var scope = base;
        while (true) {
            switch (scope.id) {
                Id.FnDef => return @fieldParentPtr(FnDef, "base", base),
                Id.Decls => return null,

                Id.Block,
                Id.Defer,
                Id.DeferExpr,
                Id.CompTime,
                => scope = scope.parent orelse return null,
            }
        }
    }

    pub const Id = enum {
        Decls,
        Block,
        FnDef,
        CompTime,
        Defer,
        DeferExpr,
    };

    pub const Decls = struct {
        base: Scope,
        table: Decl.Table,

        /// Creates a Decls scope with 1 reference
        pub fn create(module: *Module, parent: ?*Scope) !*Decls {
            const self = try module.a().create(Decls{
                .base = Scope{
                    .id = Id.Decls,
                    .parent = parent,
                    .ref_count = 1,
                },
                .table = undefined,
            });
            errdefer module.a().destroy(self);

            self.table = Decl.Table.init(module.a());
            errdefer self.table.deinit();

            if (parent) |p| p.ref();

            return self;
        }

        pub fn destroy(self: *Decls) void {
            self.table.deinit();
            self.table.allocator.destroy(self);
        }
    };

    pub const Block = struct {
        base: Scope,
        incoming_values: std.ArrayList(*ir.Instruction),
        incoming_blocks: std.ArrayList(*ir.BasicBlock),
        end_block: *ir.BasicBlock,
        is_comptime: *ir.Instruction,

        /// Creates a Block scope with 1 reference
        pub fn create(module: *Module, parent: ?*Scope) !*Block {
            const self = try module.a().create(Block{
                .base = Scope{
                    .id = Id.Block,
                    .parent = parent,
                    .ref_count = 1,
                },
                .incoming_values = undefined,
                .incoming_blocks = undefined,
                .end_block = undefined,
                .is_comptime = undefined,
            });
            errdefer module.a().destroy(self);

            if (parent) |p| p.ref();
            return self;
        }

        pub fn destroy(self: *Block, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const FnDef = struct {
        base: Scope,

        /// This reference is not counted so that the scope can get destroyed with the function
        fn_val: *Value.Fn,

        /// Creates a FnDef scope with 1 reference
        /// Must set the fn_val later
        pub fn create(module: *Module, parent: ?*Scope) !*FnDef {
            const self = try module.a().create(FnDef{
                .base = Scope{
                    .id = Id.FnDef,
                    .parent = parent,
                    .ref_count = 1,
                },
                .fn_val = undefined,
            });

            if (parent) |p| p.ref();

            return self;
        }

        pub fn destroy(self: *FnDef, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const CompTime = struct {
        base: Scope,

        /// Creates a CompTime scope with 1 reference
        pub fn create(module: *Module, parent: ?*Scope) !*CompTime {
            const self = try module.a().create(CompTime{
                .base = Scope{
                    .id = Id.CompTime,
                    .parent = parent,
                    .ref_count = 1,
                },
            });

            if (parent) |p| p.ref();
            return self;
        }

        pub fn destroy(self: *CompTime, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Defer = struct {
        base: Scope,
        defer_expr_scope: *DeferExpr,
        kind: Kind,

        pub const Kind = enum {
            ScopeExit,
            ErrorExit,
        };

        /// Creates a Defer scope with 1 reference
        pub fn create(
            module: *Module,
            parent: ?*Scope,
            kind: Kind,
            defer_expr_scope: *DeferExpr,
        ) !*Defer {
            const self = try module.a().create(Defer{
                .base = Scope{
                    .id = Id.Defer,
                    .parent = parent,
                    .ref_count = 1,
                },
                .defer_expr_scope = defer_expr_scope,
                .kind = kind,
            });
            errdefer module.a().destroy(self);

            defer_expr_scope.base.ref();

            if (parent) |p| p.ref();
            return self;
        }

        pub fn destroy(self: *Defer, module: *Module) void {
            self.defer_expr_scope.base.deref(module);
            module.a().destroy(self);
        }
    };

    pub const DeferExpr = struct {
        base: Scope,
        expr_node: *ast.Node,

        /// Creates a DeferExpr scope with 1 reference
        pub fn create(module: *Module, parent: ?*Scope, expr_node: *ast.Node) !*DeferExpr {
            const self = try module.a().create(DeferExpr{
                .base = Scope{
                    .id = Id.DeferExpr,
                    .parent = parent,
                    .ref_count = 1,
                },
                .expr_node = expr_node,
            });
            errdefer module.a().destroy(self);

            if (parent) |p| p.ref();
            return self;
        }

        pub fn destroy(self: *DeferExpr, module: *Module) void {
            module.a().destroy(self);
        }
    };
};
