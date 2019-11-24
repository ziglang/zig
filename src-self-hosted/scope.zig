const std = @import("std");
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

pub const Scope = struct {
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
                .Root => @fieldParentPtr(Root, "base", base).destroy(comp),
                .Decls => @fieldParentPtr(Decls, "base", base).destroy(comp),
                .Block => @fieldParentPtr(Block, "base", base).destroy(comp),
                .FnDef => @fieldParentPtr(FnDef, "base", base).destroy(comp),
                .CompTime => @fieldParentPtr(CompTime, "base", base).destroy(comp),
                .Defer => @fieldParentPtr(Defer, "base", base).destroy(comp),
                .DeferExpr => @fieldParentPtr(DeferExpr, "base", base).destroy(comp),
                .Var => @fieldParentPtr(Var, "base", base).destroy(comp),
                .AstTree => @fieldParentPtr(AstTree, "base", base).destroy(comp),
            }
        }
    }

    pub fn findRoot(base: *Scope) *Root {
        var scope = base;
        while (scope.parent) |parent| {
            scope = parent;
        }
        assert(scope.id == .Root);
        return @fieldParentPtr(Root, "base", scope);
    }

    pub fn findFnDef(base: *Scope) ?*FnDef {
        var scope = base;
        while (true) {
            switch (scope.id) {
                .FnDef => return @fieldParentPtr(FnDef, "base", scope),
                .Root, .Decls => return null,

                .Block,
                .Defer,
                .DeferExpr,
                .CompTime,
                .Var,
                => scope = scope.parent.?,

                .AstTree => unreachable,
            }
        }
    }

    pub fn findDeferExpr(base: *Scope) ?*DeferExpr {
        var scope = base;
        while (true) {
            switch (scope.id) {
                .DeferExpr => return @fieldParentPtr(DeferExpr, "base", scope),

                .FnDef,
                .Decls,
                => return null,

                .Block,
                .Defer,
                .CompTime,
                .Root,
                .Var,
                => scope = scope.parent orelse return null,

                .AstTree => unreachable,
            }
        }
    }

    fn init(base: *Scope, id: Id, parent: *Scope) void {
        base.* = Scope{
            .id = id,
            .parent = parent,
            .ref_count = std.atomic.Int(usize).init(1),
        };
        parent.ref();
    }

    pub const Id = enum {
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

    pub const Root = struct {
        base: Scope,
        realpath: []const u8,
        decls: *Decls,

        /// Creates a Root scope with 1 reference
        /// Takes ownership of realpath
        pub fn create(comp: *Compilation, realpath: []u8) !*Root {
            const self = try comp.gpa().create(Root);
            self.* = Root{
                .base = Scope{
                    .id = .Root,
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

    pub const AstTree = struct {
        base: Scope,
        tree: *ast.Tree,

        /// Creates a scope with 1 reference
        /// Takes ownership of tree, will deinit and destroy when done.
        pub fn create(comp: *Compilation, tree: *ast.Tree, root_scope: *Root) !*AstTree {
            const self = try comp.gpa().create(AstTree);
            self.* = AstTree{
                .base = undefined,
                .tree = tree,
            };
            self.base.init(.AstTree, &root_scope.base);

            return self;
        }

        pub fn destroy(self: *AstTree, comp: *Compilation) void {
            comp.gpa().free(self.tree.source);
            self.tree.deinit();
            comp.gpa().destroy(self);
        }

        pub fn root(self: *AstTree) *Root {
            return self.base.findRoot();
        }
    };

    pub const Decls = struct {
        base: Scope,

        /// This table remains Write Locked when the names are incomplete or possibly outdated.
        /// So if a reader manages to grab a lock, it can be sure that the set of names is complete
        /// and correct.
        table: event.RwLocked(Decl.Table),

        /// Creates a Decls scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope) !*Decls {
            const self = try comp.gpa().create(Decls);
            self.* = Decls{
                .base = undefined,
                .table = event.RwLocked(Decl.Table).init(Decl.Table.init(comp.gpa())),
            };
            self.base.init(.Decls, parent);
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
                    .Auto => switch (comp.build_mode) {
                        .Debug,
                        .ReleaseSafe,
                        => true,
                        .ReleaseFast,
                        .ReleaseSmall,
                        => false,
                    },
                    .Manual => |man| man.enabled,
                };
            }
        };

        /// Creates a Block scope with 1 reference
        pub fn create(comp: *Compilation, parent: *Scope) !*Block {
            const self = try comp.gpa().create(Block);
            self.* = Block{
                .base = undefined,
                .incoming_values = undefined,
                .incoming_blocks = undefined,
                .end_block = undefined,
                .is_comptime = undefined,
                .safety = Safety.Auto,
            };
            self.base.init(.Block, parent);
            return self;
        }

        pub fn destroy(self: *Block, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const FnDef = struct {
        base: Scope,

        /// This reference is not counted so that the scope can get destroyed with the function
        fn_val: ?*Value.Fn,

        /// Creates a FnDef scope with 1 reference
        /// Must set the fn_val later
        pub fn create(comp: *Compilation, parent: *Scope) !*FnDef {
            const self = try comp.gpa().create(FnDef);
            self.* = FnDef{
                .base = undefined,
                .fn_val = null,
            };
            self.base.init(.FnDef, parent);
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
            const self = try comp.gpa().create(CompTime);
            self.* = CompTime{ .base = undefined };
            self.base.init(.CompTime, parent);
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
            const self = try comp.gpa().create(Defer);
            self.* = Defer{
                .base = undefined,
                .defer_expr_scope = defer_expr_scope,
                .kind = kind,
            };
            self.base.init(.Defer, parent);
            defer_expr_scope.base.ref();
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
            const self = try comp.gpa().create(DeferExpr);
            self.* = DeferExpr{
                .base = undefined,
                .expr_node = expr_node,
                .reported_err = false,
            };
            self.base.init(.DeferExpr, parent);
            return self;
        }

        pub fn destroy(self: *DeferExpr, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Var = struct {
        base: Scope,
        name: []const u8,
        src_node: *ast.Node,
        data: Data,

        pub const Data = union(enum) {
            Param: Param,
            Const: *Value,
        };

        pub const Param = struct {
            index: usize,
            typ: *Type,
            llvm_value: *llvm.Value,
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
            self.data = Data{
                .Param = Param{
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
            self.data = Data{ .Const = value };
            value.ref();
            return self;
        }

        fn create(comp: *Compilation, parent: *Scope, name: []const u8, src_node: *ast.Node) !*Var {
            const self = try comp.gpa().create(Var);
            self.* = Var{
                .base = undefined,
                .name = name,
                .src_node = src_node,
                .data = undefined,
            };
            self.base.init(.Var, parent);
            return self;
        }

        pub fn destroy(self: *Var, comp: *Compilation) void {
            switch (self.data) {
                .Param => {},
                .Const => |value| value.deref(comp),
            }
            comp.gpa().destroy(self);
        }
    };
};
