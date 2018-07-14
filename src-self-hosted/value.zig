const std = @import("std");
const builtin = @import("builtin");
const Scope = @import("scope.zig").Scope;
const Module = @import("module.zig").Module;

/// Values are ref-counted, heap-allocated, and copy-on-write
/// If there is only 1 ref then write need not copy
pub const Value = struct {
    id: Id,
    typeof: *Type,
    ref_count: std.atomic.Int(usize),

    /// Thread-safe
    pub fn ref(base: *Value) void {
        _ = base.ref_count.incr();
    }

    /// Thread-safe
    pub fn deref(base: *Value, module: *Module) void {
        if (base.ref_count.decr() == 1) {
            base.typeof.base.deref(module);
            switch (base.id) {
                Id.Type => @fieldParentPtr(Type, "base", base).destroy(module),
                Id.Fn => @fieldParentPtr(Fn, "base", base).destroy(module),
                Id.Void => @fieldParentPtr(Void, "base", base).destroy(module),
                Id.Bool => @fieldParentPtr(Bool, "base", base).destroy(module),
                Id.NoReturn => @fieldParentPtr(NoReturn, "base", base).destroy(module),
                Id.Ptr => @fieldParentPtr(Ptr, "base", base).destroy(module),
            }
        }
    }

    pub fn getRef(base: *Value) *Value {
        base.ref();
        return base;
    }

    pub fn dump(base: *const Value) void {
        std.debug.warn("{}", @tagName(base.id));
    }

    pub const Id = enum {
        Type,
        Fn,
        Void,
        Bool,
        NoReturn,
        Ptr,
    };

    pub const Type = @import("type.zig").Type;

    pub const Fn = struct {
        base: Value,

        /// The main external name that is used in the .o file.
        /// TODO https://github.com/ziglang/zig/issues/265
        symbol_name: std.Buffer,

        /// parent should be the top level decls or container decls
        fndef_scope: *Scope.FnDef,

        /// parent is scope for last parameter
        child_scope: *Scope,

        /// parent is child_scope
        block_scope: *Scope.Block,

        /// Creates a Fn value with 1 ref
        /// Takes ownership of symbol_name
        pub fn create(module: *Module, fn_type: *Type.Fn, fndef_scope: *Scope.FnDef, symbol_name: std.Buffer) !*Fn {
            const self = try module.a().create(Fn{
                .base = Value{
                    .id = Value.Id.Fn,
                    .typeof = &fn_type.base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .fndef_scope = fndef_scope,
                .child_scope = &fndef_scope.base,
                .block_scope = undefined,
                .symbol_name = symbol_name,
            });
            fn_type.base.base.ref();
            fndef_scope.fn_val = self;
            fndef_scope.base.ref();
            return self;
        }

        pub fn destroy(self: *Fn, module: *Module) void {
            self.fndef_scope.base.deref(module);
            self.symbol_name.deinit();
            module.a().destroy(self);
        }
    };

    pub const Void = struct {
        base: Value,

        pub fn get(module: *Module) *Void {
            module.void_value.base.ref();
            return module.void_value;
        }

        pub fn destroy(self: *Void, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Bool = struct {
        base: Value,
        x: bool,

        pub fn get(module: *Module, x: bool) *Bool {
            if (x) {
                module.true_value.base.ref();
                return module.true_value;
            } else {
                module.false_value.base.ref();
                return module.false_value;
            }
        }

        pub fn destroy(self: *Bool, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const NoReturn = struct {
        base: Value,

        pub fn get(module: *Module) *NoReturn {
            module.noreturn_value.base.ref();
            return module.noreturn_value;
        }

        pub fn destroy(self: *NoReturn, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Ptr = struct {
        base: Value,

        pub const Mut = enum {
            CompTimeConst,
            CompTimeVar,
            RunTime,
        };

        pub fn destroy(self: *Ptr, module: *Module) void {
            module.a().destroy(self);
        }
    };
};
