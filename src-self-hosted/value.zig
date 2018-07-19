const std = @import("std");
const builtin = @import("builtin");
const Scope = @import("scope.zig").Scope;
const Compilation = @import("compilation.zig").Compilation;
const ObjectFile = @import("codegen.zig").ObjectFile;
const llvm = @import("llvm.zig");
const Buffer = std.Buffer;

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
    pub fn deref(base: *Value, comp: *Compilation) void {
        if (base.ref_count.decr() == 1) {
            base.typeof.base.deref(comp);
            switch (base.id) {
                Id.Type => @fieldParentPtr(Type, "base", base).destroy(comp),
                Id.Fn => @fieldParentPtr(Fn, "base", base).destroy(comp),
                Id.Void => @fieldParentPtr(Void, "base", base).destroy(comp),
                Id.Bool => @fieldParentPtr(Bool, "base", base).destroy(comp),
                Id.NoReturn => @fieldParentPtr(NoReturn, "base", base).destroy(comp),
                Id.Ptr => @fieldParentPtr(Ptr, "base", base).destroy(comp),
                Id.Int => @fieldParentPtr(Int, "base", base).destroy(comp),
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

    pub fn getLlvmConst(base: *Value, ofile: *ObjectFile) (error{OutOfMemory}!?llvm.ValueRef) {
        switch (base.id) {
            Id.Type => unreachable,
            Id.Fn => @panic("TODO"),
            Id.Void => return null,
            Id.Bool => return @fieldParentPtr(Bool, "base", base).getLlvmConst(ofile),
            Id.NoReturn => unreachable,
            Id.Ptr => @panic("TODO"),
            Id.Int => return @fieldParentPtr(Int, "base", base).getLlvmConst(ofile),
        }
    }

    pub const Id = enum {
        Type,
        Fn,
        Void,
        Bool,
        NoReturn,
        Ptr,
        Int,
    };

    pub const Type = @import("type.zig").Type;

    pub const Fn = struct {
        base: Value,

        /// The main external name that is used in the .o file.
        /// TODO https://github.com/ziglang/zig/issues/265
        symbol_name: Buffer,

        /// parent should be the top level decls or container decls
        fndef_scope: *Scope.FnDef,

        /// parent is scope for last parameter
        child_scope: *Scope,

        /// parent is child_scope
        block_scope: *Scope.Block,

        /// Path to the object file that contains this function
        containing_object: Buffer,

        link_set_node: *std.LinkedList(?*Value.Fn).Node,

        /// Creates a Fn value with 1 ref
        /// Takes ownership of symbol_name
        pub fn create(comp: *Compilation, fn_type: *Type.Fn, fndef_scope: *Scope.FnDef, symbol_name: Buffer) !*Fn {
            const link_set_node = try comp.gpa().create(Compilation.FnLinkSet.Node{
                .data = null,
                .next = undefined,
                .prev = undefined,
            });
            errdefer comp.gpa().destroy(link_set_node);

            const self = try comp.gpa().create(Fn{
                .base = Value{
                    .id = Value.Id.Fn,
                    .typeof = &fn_type.base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .fndef_scope = fndef_scope,
                .child_scope = &fndef_scope.base,
                .block_scope = undefined,
                .symbol_name = symbol_name,
                .containing_object = Buffer.initNull(comp.gpa()),
                .link_set_node = link_set_node,
            });
            fn_type.base.base.ref();
            fndef_scope.fn_val = self;
            fndef_scope.base.ref();
            return self;
        }

        pub fn destroy(self: *Fn, comp: *Compilation) void {
            // remove with a tombstone so that we do not have to grab a lock
            if (self.link_set_node.data != null) {
                // it's now the job of the link step to find this tombstone and
                // deallocate it.
                self.link_set_node.data = null;
            } else {
                comp.gpa().destroy(self.link_set_node);
            }

            self.containing_object.deinit();
            self.fndef_scope.base.deref(comp);
            self.symbol_name.deinit();
            comp.gpa().destroy(self);
        }
    };

    pub const Void = struct {
        base: Value,

        pub fn get(comp: *Compilation) *Void {
            comp.void_value.base.ref();
            return comp.void_value;
        }

        pub fn destroy(self: *Void, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Bool = struct {
        base: Value,
        x: bool,

        pub fn get(comp: *Compilation, x: bool) *Bool {
            if (x) {
                comp.true_value.base.ref();
                return comp.true_value;
            } else {
                comp.false_value.base.ref();
                return comp.false_value;
            }
        }

        pub fn destroy(self: *Bool, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmConst(self: *Bool, ofile: *ObjectFile) ?llvm.ValueRef {
            const llvm_type = llvm.Int1TypeInContext(ofile.context);
            if (self.x) {
                return llvm.ConstAllOnes(llvm_type);
            } else {
                return llvm.ConstNull(llvm_type);
            }
        }
    };

    pub const NoReturn = struct {
        base: Value,

        pub fn get(comp: *Compilation) *NoReturn {
            comp.noreturn_value.base.ref();
            return comp.noreturn_value;
        }

        pub fn destroy(self: *NoReturn, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Ptr = struct {
        base: Value,

        pub const Mut = enum {
            CompTimeConst,
            CompTimeVar,
            RunTime,
        };

        pub fn destroy(self: *Ptr, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Int = struct {
        base: Value,
        big_int: std.math.big.Int,

        pub fn createFromString(comp: *Compilation, typeof: *Type, base: u8, value: []const u8) !*Int {
            const self = try comp.gpa().create(Value.Int{
                .base = Value{
                    .id = Value.Id.Int,
                    .typeof = typeof,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .big_int = undefined,
            });
            typeof.base.ref();
            errdefer comp.gpa().destroy(self);

            self.big_int = try std.math.big.Int.init(comp.gpa());
            errdefer self.big_int.deinit();

            try self.big_int.setString(base, value);

            return self;
        }

        pub fn getLlvmConst(self: *Int, ofile: *ObjectFile) !?llvm.ValueRef {
            switch (self.base.typeof.id) {
                Type.Id.Int => {
                    const type_ref = try self.base.typeof.getLlvmType(ofile);
                    if (self.big_int.len == 0) {
                        return llvm.ConstNull(type_ref);
                    }
                    const unsigned_val = if (self.big_int.len == 1) blk: {
                        break :blk llvm.ConstInt(type_ref, self.big_int.limbs[0], @boolToInt(false));
                    } else if (@sizeOf(std.math.big.Limb) == @sizeOf(u64)) blk: {
                        break :blk llvm.ConstIntOfArbitraryPrecision(
                            type_ref,
                            @intCast(c_uint, self.big_int.len),
                            @ptrCast([*]u64, self.big_int.limbs.ptr),
                        );
                    } else {
                        @compileError("std.math.Big.Int.Limb size does not match LLVM");
                    };
                    return if (self.big_int.positive) unsigned_val else llvm.ConstNeg(unsigned_val);
                },
                Type.Id.ComptimeInt => unreachable,
                else => unreachable,
            }
        }

        pub fn destroy(self: *Int, comp: *Compilation) void {
            self.big_int.deinit();
            comp.gpa().destroy(self);
        }
    };
};
