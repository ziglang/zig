const std = @import("std");
const builtin = @import("builtin");
const Allocator = mem.Allocator;
const Decl = @import("decl.zig").Decl;
const Compilation = @import("compilation.zig").Compilation;
const mem = std.mem;
const ast = std.zig.ast;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const ir = @import("ir.zig");
const Span = @import("errmsg.zig").Span;
const assert = std.debug.assert;
const event = std.event;
const llvm = @import("llvm.zig");

pub const Scope = struct.{
    id: Id,
    parent: ?*Scope,
    ref_count: std.atomic.Int(usize),

    /// Thread-safe
    pub fn ref(base: *Scope) void {
        _ = base.ref_count.incr();
    }

    /// Thread-safe
    pub fn deref(base: *Scope, comp: *Compilation) void {
        if (base.ref_count.decr() == 1) {
            if (base.parent) |parent| parent.deref(comp);
            switch (base.id) {
                Id.Root => @fieldParentPtr(Root, "base", base).destroy(comp),
                Id.Decls => @fieldParentPtr(Decls, "base", base).destroy(comp),
                Id.Block => @fieldParentPtr(Block, "base", base).destroy(comp),
                Id.FnDef => @fieldParentPtr(FnDef, "base", base).destroy(comp),
                Id.CompTime => @fieldParentPtr(CompTime, "base", base).destroy(comp),
                Id.Defer => @fieldParentPtr(Defer, "base", base).destroy(comp),
                Id.DeferExpr => @fieldParentPtr(DeferExpr, "base", base).destroy(comp),
                Id.Var => @fieldParentPtr(Var, "base", base).destroy(comp),
                Id.AstTree => @fieldParentPtr(AstTree, "base", base).destroy(comp),
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
                Id.FnDef => return @fieldParentPtr(FnDef, "base", scope),
                Id.Root, Id.Decls => return null,

                Id.Block,
                Id.Defer,
                Id.DeferExpr,
                Id.CompTime,
                Id.Var,
                => scope = scope.parent.?,

                Id.AstTree => unreachable,
            }
        }
    }

    pub fn findDeferExpr(base: *Scope) ?*DeferExpr {
        var scope = base;
        while (true) {
            switch (scope.id) {
                Id.DeferExpr => return @fieldParentPtr(DeferExpr, "base", scope),

                Id.FnDef,
                Id.Decls,
                => return null,

                Id.Block,
                Id.Defer,
                Id.CompTime,
                Id.Root,
                Id.Var,
                => scope = scope.parent orelse return null,

                Id.AstTree => unreachable,
            }
        }
    }

    fn init(base: *Scope, id: Id, parent: *Scope) void {
        base.* = Scope.{
            .id = id,
            .parent = parent,
            .ref_count = std.atomic.Int(usize).init(1),
        };
        parent.ref();
    }

    pub const Id = enum.{
        Root,
        AstTree,
        Decls,
        Block,
        FnDef,
        CompTime,
        Defer,
        DeferExpr,
        Var,
    };

    pub const Root = struct.{
        base: Scope,
        realpath: []const u8,
        decls: *Decls,

        /// Creates a Root scope with 1 reference
        /// Takes ownership of realpath
        pub fn create(comp: *Compilation, realpath: []u8) !*Root {
            const self = try comp.gpa().createOne(Root);
            self.* = Root.{
                .base = Scope.{
                    .id = Id.Root,
                    .parent = null,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .realpath = realpath,
                .decls = undefined,
            };
            errdefer comp.gpa().destroy(self);
            self.decls = try Decls.create(comp, &self.base);
            return self;
        }

        pub fn destroy(self: *Root, comp: *Compilation) void {
            // TODO comp.fs_watch.removeFile(self.realpath);
            self.decls.base.deref(comp);
            comp.gpa().free(self.realpath);
            comp.gpa().destroy(self);
        }
    };

    pub const AstTree = struct.{
        base: Scope,
        tree: *ast.Tree,

        /// Creates a scope with 1 reference
        /// Takes ownership of tree, will deinit and destroy when done.
        pub fn create(comp: *Compilation, tree: *ast.Tree, root_scope: *Root) !*AstTree {
            const self = try comp.gpa().createOne(AstTree);
            self.* = AstTree.{
                .base = undefined,
                .tree = tree,
            };
            self.base.init(Id.AstTree, &root_scope.base);

            return self;
        }

        pub fn destroy(self: *AstTree, comp: *Compilation) void {
            comp.gpa().free(self.tree.source);
            self.tree.deinit();
            comp.gpa().destroy(self.tree);
            comp.gpa().destroy(self);
        }

        pub fn root(self: *AstTree) *Root {
            return self.base.findRoot();
        }
    };

    pub const Decls = struct.{
        base: Scope,

        /// This table remains Write Locked when the names are incomplete or possibly outdated.
        /// So if a reader manages to grab a lock, it can be sure that the set of names is complete
        /// and correct.
        table: event.RwLocked(Decl.Table),

        /// Creates a Decls scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope) !*Decls {
            const self = try comp.gpa().createOne(Decls);
            self.* = Decls.{
                .base = undefined,
                .table = event.RwLocked(Decl.Table).init(comp.loop, Decl.Table.init(comp.gpa())),
            };
            self.base.init(Id.Decls, parent);
            return self;
        }

        pub fn destroy(self: *Decls, comp: *Compilation) void {
            self.table.deinit();
            comp.gpa().destroy(self);
        }
    };

    pub const Block = struct.{
        base: Scope,
        incoming_values: std.ArrayList(*ir.Inst),
        incoming_blocks: std.ArrayList(*ir.BasicBlock),
        end_block: *ir.BasicBlock,
        is_comptime: *ir.Inst,

        safety: Safety,

        const Safety = union(enum).{
            Auto,
            Manual: Manual,

            const Manual = struct.{
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
            const self = try comp.gpa().createOne(Block);
            self.* = Block.{
                .base = undefined,
                .incoming_values = undefined,
                .incoming_blocks = undefined,
                .end_block = undefined,
                .is_comptime = undefined,
                .safety = Safety.Auto,
            };
            self.base.init(Id.Block, parent);
            return self;
        }

        pub fn destroy(self: *Block, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const FnDef = struct.{
        base: Scope,

        /// This reference is not counted so that the scope can get destroyed with the function
        fn_val: ?*Value.Fn,

        /// Creates a FnDef scope with 1 reference
        /// Must set the fn_val later
        pub fn create(comp: *Compilation, parent: *Scope) !*FnDef {
            const self = try comp.gpa().createOne(FnDef);
            self.* = FnDef.{
                .base = undefined,
                .fn_val = null,
            };
            self.base.init(Id.FnDef, parent);
            return self;
        }

        pub fn destroy(self: *FnDef, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const CompTime = struct.{
        base: Scope,

        /// Creates a CompTime scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope) !*CompTime {
            const self = try comp.gpa().createOne(CompTime);
            self.* = CompTime.{ .base = undefined };
            self.base.init(Id.CompTime, parent);
            return self;
        }

        pub fn destroy(self: *CompTime, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Defer = struct.{
        base: Scope,
        defer_expr_scope: *DeferExpr,
        kind: Kind,

        pub const Kind = enum.{
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
            const self = try comp.gpa().createOne(Defer);
            self.* = Defer.{
                .base = undefined,
                .defer_expr_scope = defer_expr_scope,
                .kind = kind,
            };
            self.base.init(Id.Defer, parent);
            defer_expr_scope.base.ref();
            return self;
        }

        pub fn destroy(self: *Defer, comp: *Compilation) void {
            self.defer_expr_scope.base.deref(comp);
            comp.gpa().destroy(self);
        }
    };

    pub const DeferExpr = struct.{
        base: Scope,
        expr_node: *ast.Node,
        reported_err: bool,

        /// Creates a DeferExpr scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope, expr_node: *ast.Node) !*DeferExpr {
            const self = try comp.gpa().createOne(DeferExpr);
            self.* = DeferExpr.{
                .base = undefined,
                .expr_node = expr_node,
                .reported_err = false,
            };
            self.base.init(Id.DeferExpr, parent);
            return self;
        }

        pub fn destroy(self: *DeferExpr, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Var = struct.{
        base: Scope,
        name: []const u8,
        src_node: *ast.Node,
        data: Data,

        pub const Data = union(enum).{
            Param: Param,
            Const: *Value,
        };

        pub const Param = struct.{
            index: usize,
            typ: *Type,
            llvm_value: llvm.ValueRef,
        };

        pub fn createParam(
            comp: *Compilation,
            parent: *Scope,
            name: []const u8,
            src_node: *ast.Node,
            param_index: usize,
            param_type: *Type,
        ) !*Var {
            const self = try create(comp, parent, name, src_node);
            self.data = Data.{
                .Param = Param.{
                    .index = param_index,
                    .typ = param_type,
                    .llvm_value = undefined,
                },
            };
            return self;
        }

        pub fn createConst(
            comp: *Compilation,
            parent: *Scope,
            name: []const u8,
            src_node: *ast.Node,
            value: *Value,
        ) !*Var {
            const self = try create(comp, parent, name, src_node);
            self.data = Data.{ .Const = value };
            value.ref();
            return self;
        }

        fn create(comp: *Compilation, parent: *Scope, name: []const u8, src_node: *ast.Node) !*Var {
            const self = try comp.gpa().createOne(Var);
            self.* = Var.{
                .base = undefined,
                .name = name,
                .src_node = src_node,
                .data = undefined,
            };
            self.base.init(Id.Var, parent);
            return self;
        }

        pub fn destroy(self: *Var, comp: *Compilation) void {
            switch (self.data) {
                Data.Param => {},
                Data.Const => |value| value.deref(comp),
            }
            comp.gpa().destroy(self);
        }
    };
};
