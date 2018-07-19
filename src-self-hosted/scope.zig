const std = @import("std");
const builtin = @import("builtin");
const Allocator = mem.Allocator;
const Decl = @import("decl.zig").Decl;
const Compilation = @import("compilation.zig").Compilation;
const mem = std.mem;
const ast = std.zig.ast;
const Value = @import("value.zig").Value;
const ir = @import("ir.zig");
const Span = @import("errmsg.zig").Span;
const assert = std.debug.assert;

pub const Scope = struct {
    id: Id,
    parent: ?*Scope,
    ref_count: usize,

    pub fn ref(base: *Scope) void {
        base.ref_count += 1;
    }

    pub fn deref(base: *Scope, comp: *Compilation) void {
        base.ref_count -= 1;
        if (base.ref_count == 0) {
            if (base.parent) |parent| parent.deref(comp);
            switch (base.id) {
                Id.Root => @fieldParentPtr(Root, "base", base).destroy(comp),
                Id.Decls => @fieldParentPtr(Decls, "base", base).destroy(comp),
                Id.Block => @fieldParentPtr(Block, "base", base).destroy(comp),
                Id.FnDef => @fieldParentPtr(FnDef, "base", base).destroy(comp),
                Id.CompTime => @fieldParentPtr(CompTime, "base", base).destroy(comp),
                Id.Defer => @fieldParentPtr(Defer, "base", base).destroy(comp),
                Id.DeferExpr => @fieldParentPtr(DeferExpr, "base", base).destroy(comp),
            }
        }
    }

    pub fn findRoot(base: *Scope) *Root {
        var scope = base;
        while (scope.parent) |parent| {
            scope = parent;
        }
        assert(scope.id == Id.Root);
        return @fieldParentPtr(Root, "base", scope);
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
                Id.Root,
                => scope = scope.parent orelse return null,
            }
        }
    }

    pub fn findDeferExpr(base: *Scope) ?*DeferExpr {
        var scope = base;
        while (true) {
            switch (scope.id) {
                Id.DeferExpr => return @fieldParentPtr(DeferExpr, "base", base),

                Id.FnDef,
                Id.Decls,
                => return null,

                Id.Block,
                Id.Defer,
                Id.CompTime,
                Id.Root,
                => scope = scope.parent orelse return null,
            }
        }
    }

    pub const Id = enum {
        Root,
        Decls,
        Block,
        FnDef,
        CompTime,
        Defer,
        DeferExpr,
    };

    pub const Root = struct {
        base: Scope,
        tree: ast.Tree,
        realpath: []const u8,

        /// Creates a Root scope with 1 reference
        /// Takes ownership of realpath
        /// Caller must set tree
        pub fn create(comp: *Compilation, tree: ast.Tree, realpath: []u8) !*Root {
            const self = try comp.gpa().create(Root{
                .base = Scope{
                    .id = Id.Root,
                    .parent = null,
                    .ref_count = 1,
                },
                .tree = tree,
                .realpath = realpath,
            });
            errdefer comp.gpa().destroy(self);

            return self;
        }

        pub fn destroy(self: *Root, comp: *Compilation) void {
            comp.gpa().free(self.tree.source);
            self.tree.deinit();
            comp.gpa().free(self.realpath);
            comp.gpa().destroy(self);
        }
    };

    pub const Decls = struct {
        base: Scope,
        table: Decl.Table,

        /// Creates a Decls scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope) !*Decls {
            const self = try comp.gpa().create(Decls{
                .base = Scope{
                    .id = Id.Decls,
                    .parent = parent,
                    .ref_count = 1,
                },
                .table = undefined,
            });
            errdefer comp.gpa().destroy(self);

            self.table = Decl.Table.init(comp.gpa());
            errdefer self.table.deinit();

            parent.ref();

            return self;
        }

        pub fn destroy(self: *Decls, comp: *Compilation) void {
            self.table.deinit();
            comp.gpa().destroy(self);
        }
    };

    pub const Block = struct {
        base: Scope,
        incoming_values: std.ArrayList(*ir.Inst),
        incoming_blocks: std.ArrayList(*ir.BasicBlock),
        end_block: *ir.BasicBlock,
        is_comptime: *ir.Inst,

        safety: Safety,

        const Safety = union(enum) {
            Auto,
            Manual: Manual,

            const Manual = struct {
                /// the source span that disabled the safety value
                span: Span,

                /// whether safety is enabled
                enabled: bool,
            };

            fn get(self: Safety, comp: *Compilation) bool {
                return switch (self) {
                    Safety.Auto => switch (comp.build_mode) {
                        builtin.Mode.Debug,
                        builtin.Mode.ReleaseSafe,
                        => true,
                        builtin.Mode.ReleaseFast,
                        builtin.Mode.ReleaseSmall,
                        => false,
                    },
                    @TagType(Safety).Manual => |man| man.enabled,
                };
            }
        };

        /// Creates a Block scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope) !*Block {
            const self = try comp.gpa().create(Block{
                .base = Scope{
                    .id = Id.Block,
                    .parent = parent,
                    .ref_count = 1,
                },
                .incoming_values = undefined,
                .incoming_blocks = undefined,
                .end_block = undefined,
                .is_comptime = undefined,
                .safety = Safety.Auto,
            });
            errdefer comp.gpa().destroy(self);

            parent.ref();
            return self;
        }

        pub fn destroy(self: *Block, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const FnDef = struct {
        base: Scope,

        /// This reference is not counted so that the scope can get destroyed with the function
        fn_val: *Value.Fn,

        /// Creates a FnDef scope with 1 reference
        /// Must set the fn_val later
        pub fn create(comp: *Compilation, parent: *Scope) !*FnDef {
            const self = try comp.gpa().create(FnDef{
                .base = Scope{
                    .id = Id.FnDef,
                    .parent = parent,
                    .ref_count = 1,
                },
                .fn_val = undefined,
            });

            parent.ref();

            return self;
        }

        pub fn destroy(self: *FnDef, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const CompTime = struct {
        base: Scope,

        /// Creates a CompTime scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope) !*CompTime {
            const self = try comp.gpa().create(CompTime{
                .base = Scope{
                    .id = Id.CompTime,
                    .parent = parent,
                    .ref_count = 1,
                },
            });

            parent.ref();
            return self;
        }

        pub fn destroy(self: *CompTime, comp: *Compilation) void {
            comp.gpa().destroy(self);
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
            comp: *Compilation,
            parent: *Scope,
            kind: Kind,
            defer_expr_scope: *DeferExpr,
        ) !*Defer {
            const self = try comp.gpa().create(Defer{
                .base = Scope{
                    .id = Id.Defer,
                    .parent = parent,
                    .ref_count = 1,
                },
                .defer_expr_scope = defer_expr_scope,
                .kind = kind,
            });
            errdefer comp.gpa().destroy(self);

            defer_expr_scope.base.ref();

            parent.ref();
            return self;
        }

        pub fn destroy(self: *Defer, comp: *Compilation) void {
            self.defer_expr_scope.base.deref(comp);
            comp.gpa().destroy(self);
        }
    };

    pub const DeferExpr = struct {
        base: Scope,
        expr_node: *ast.Node,
        reported_err: bool,

        /// Creates a DeferExpr scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope, expr_node: *ast.Node) !*DeferExpr {
            const self = try comp.gpa().create(DeferExpr{
                .base = Scope{
                    .id = Id.DeferExpr,
                    .parent = parent,
                    .ref_count = 1,
                },
                .expr_node = expr_node,
                .reported_err = false,
            });
            errdefer comp.gpa().destroy(self);

            parent.ref();
            return self;
        }

        pub fn destroy(self: *DeferExpr, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };
};
