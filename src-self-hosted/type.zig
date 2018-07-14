const std = @import("std");
const builtin = @import("builtin");
const Scope = @import("scope.zig").Scope;
const Module = @import("module.zig").Module;
const Value = @import("value.zig").Value;
const llvm = @import("llvm.zig");
const CompilationUnit = @import("codegen.zig").CompilationUnit;

pub const Type = struct {
    base: Value,
    id: Id,

    pub const Id = builtin.TypeId;

    pub fn destroy(base: *Type, module: *Module) void {
        switch (base.id) {
            Id.Struct => @fieldParentPtr(Struct, "base", base).destroy(module),
            Id.Fn => @fieldParentPtr(Fn, "base", base).destroy(module),
            Id.Type => @fieldParentPtr(MetaType, "base", base).destroy(module),
            Id.Void => @fieldParentPtr(Void, "base", base).destroy(module),
            Id.Bool => @fieldParentPtr(Bool, "base", base).destroy(module),
            Id.NoReturn => @fieldParentPtr(NoReturn, "base", base).destroy(module),
            Id.Int => @fieldParentPtr(Int, "base", base).destroy(module),
            Id.Float => @fieldParentPtr(Float, "base", base).destroy(module),
            Id.Pointer => @fieldParentPtr(Pointer, "base", base).destroy(module),
            Id.Array => @fieldParentPtr(Array, "base", base).destroy(module),
            Id.ComptimeFloat => @fieldParentPtr(ComptimeFloat, "base", base).destroy(module),
            Id.ComptimeInt => @fieldParentPtr(ComptimeInt, "base", base).destroy(module),
            Id.Undefined => @fieldParentPtr(Undefined, "base", base).destroy(module),
            Id.Null => @fieldParentPtr(Null, "base", base).destroy(module),
            Id.Optional => @fieldParentPtr(Optional, "base", base).destroy(module),
            Id.ErrorUnion => @fieldParentPtr(ErrorUnion, "base", base).destroy(module),
            Id.ErrorSet => @fieldParentPtr(ErrorSet, "base", base).destroy(module),
            Id.Enum => @fieldParentPtr(Enum, "base", base).destroy(module),
            Id.Union => @fieldParentPtr(Union, "base", base).destroy(module),
            Id.Namespace => @fieldParentPtr(Namespace, "base", base).destroy(module),
            Id.Block => @fieldParentPtr(Block, "base", base).destroy(module),
            Id.BoundFn => @fieldParentPtr(BoundFn, "base", base).destroy(module),
            Id.ArgTuple => @fieldParentPtr(ArgTuple, "base", base).destroy(module),
            Id.Opaque => @fieldParentPtr(Opaque, "base", base).destroy(module),
            Id.Promise => @fieldParentPtr(Promise, "base", base).destroy(module),
        }
    }

    pub fn getLlvmType(base: *Type, cunit: *CompilationUnit) (error{OutOfMemory}!llvm.TypeRef) {
        switch (base.id) {
            Id.Struct => return @fieldParentPtr(Struct, "base", base).getLlvmType(cunit),
            Id.Fn => return @fieldParentPtr(Fn, "base", base).getLlvmType(cunit),
            Id.Type => unreachable,
            Id.Void => unreachable,
            Id.Bool => return @fieldParentPtr(Bool, "base", base).getLlvmType(cunit),
            Id.NoReturn => unreachable,
            Id.Int => return @fieldParentPtr(Int, "base", base).getLlvmType(cunit),
            Id.Float => return @fieldParentPtr(Float, "base", base).getLlvmType(cunit),
            Id.Pointer => return @fieldParentPtr(Pointer, "base", base).getLlvmType(cunit),
            Id.Array => return @fieldParentPtr(Array, "base", base).getLlvmType(cunit),
            Id.ComptimeFloat => unreachable,
            Id.ComptimeInt => unreachable,
            Id.Undefined => unreachable,
            Id.Null => unreachable,
            Id.Optional => return @fieldParentPtr(Optional, "base", base).getLlvmType(cunit),
            Id.ErrorUnion => return @fieldParentPtr(ErrorUnion, "base", base).getLlvmType(cunit),
            Id.ErrorSet => return @fieldParentPtr(ErrorSet, "base", base).getLlvmType(cunit),
            Id.Enum => return @fieldParentPtr(Enum, "base", base).getLlvmType(cunit),
            Id.Union => return @fieldParentPtr(Union, "base", base).getLlvmType(cunit),
            Id.Namespace => unreachable,
            Id.Block => unreachable,
            Id.BoundFn => return @fieldParentPtr(BoundFn, "base", base).getLlvmType(cunit),
            Id.ArgTuple => unreachable,
            Id.Opaque => return @fieldParentPtr(Opaque, "base", base).getLlvmType(cunit),
            Id.Promise => return @fieldParentPtr(Promise, "base", base).getLlvmType(cunit),
        }
    }

    pub fn dump(base: *const Type) void {
        std.debug.warn("{}", @tagName(base.id));
    }

    pub fn getAbiAlignment(base: *Type, module: *Module) u32 {
        @panic("TODO getAbiAlignment");
    }

    pub const Struct = struct {
        base: Type,
        decls: *Scope.Decls,

        pub fn destroy(self: *Struct, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Struct, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Fn = struct {
        base: Type,
        return_type: *Type,
        params: []Param,
        is_var_args: bool,

        pub const Param = struct {
            is_noalias: bool,
            typeof: *Type,
        };

        pub fn create(module: *Module, return_type: *Type, params: []Param, is_var_args: bool) !*Fn {
            const result = try module.a().create(Fn{
                .base = Type{
                    .base = Value{
                        .id = Value.Id.Type,
                        .typeof = &MetaType.get(module).base,
                        .ref_count = std.atomic.Int(usize).init(1),
                    },
                    .id = builtin.TypeId.Fn,
                },
                .return_type = return_type,
                .params = params,
                .is_var_args = is_var_args,
            });
            errdefer module.a().destroy(result);

            result.return_type.base.ref();
            for (result.params) |param| {
                param.typeof.base.ref();
            }
            return result;
        }

        pub fn destroy(self: *Fn, module: *Module) void {
            self.return_type.base.deref(module);
            for (self.params) |param| {
                param.typeof.base.deref(module);
            }
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Fn, cunit: *CompilationUnit) !llvm.TypeRef {
            const llvm_return_type = switch (self.return_type.id) {
                Type.Id.Void => llvm.VoidTypeInContext(cunit.context) orelse return error.OutOfMemory,
                else => try self.return_type.getLlvmType(cunit),
            };
            const llvm_param_types = try cunit.a().alloc(llvm.TypeRef, self.params.len);
            defer cunit.a().free(llvm_param_types);
            for (llvm_param_types) |*llvm_param_type, i| {
                llvm_param_type.* = try self.params[i].typeof.getLlvmType(cunit);
            }

            return llvm.FunctionType(
                llvm_return_type,
                llvm_param_types.ptr,
                @intCast(c_uint, llvm_param_types.len),
                @boolToInt(self.is_var_args),
            ) orelse error.OutOfMemory;
        }
    };

    pub const MetaType = struct {
        base: Type,
        value: *Type,

        /// Adds 1 reference to the resulting type
        pub fn get(module: *Module) *MetaType {
            module.meta_type.base.base.ref();
            return module.meta_type;
        }

        pub fn destroy(self: *MetaType, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Void = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(module: *Module) *Void {
            module.void_type.base.base.ref();
            return module.void_type;
        }

        pub fn destroy(self: *Void, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Bool = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(module: *Module) *Bool {
            module.bool_type.base.base.ref();
            return module.bool_type;
        }

        pub fn destroy(self: *Bool, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Bool, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const NoReturn = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(module: *Module) *NoReturn {
            module.noreturn_type.base.base.ref();
            return module.noreturn_type;
        }

        pub fn destroy(self: *NoReturn, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Int = struct {
        base: Type,

        pub fn destroy(self: *Int, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Int, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Float = struct {
        base: Type,

        pub fn destroy(self: *Float, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Float, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };
    pub const Pointer = struct {
        base: Type,
        mut: Mut,
        vol: Vol,
        size: Size,
        alignment: u32,

        pub const Mut = enum {
            Mut,
            Const,
        };
        pub const Vol = enum {
            Non,
            Volatile,
        };
        pub const Size = builtin.TypeInfo.Pointer.Size;

        pub fn destroy(self: *Pointer, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn get(
            module: *Module,
            elem_type: *Type,
            mut: Mut,
            vol: Vol,
            size: Size,
            alignment: u32,
        ) *Pointer {
            @panic("TODO get pointer");
        }

        pub fn getLlvmType(self: *Pointer, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Array = struct {
        base: Type,

        pub fn destroy(self: *Array, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Array, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ComptimeFloat = struct {
        base: Type,

        pub fn destroy(self: *ComptimeFloat, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const ComptimeInt = struct {
        base: Type,

        pub fn destroy(self: *ComptimeInt, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Undefined = struct {
        base: Type,

        pub fn destroy(self: *Undefined, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Null = struct {
        base: Type,

        pub fn destroy(self: *Null, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Optional = struct {
        base: Type,

        pub fn destroy(self: *Optional, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Optional, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ErrorUnion = struct {
        base: Type,

        pub fn destroy(self: *ErrorUnion, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *ErrorUnion, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ErrorSet = struct {
        base: Type,

        pub fn destroy(self: *ErrorSet, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *ErrorSet, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Enum = struct {
        base: Type,

        pub fn destroy(self: *Enum, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Enum, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Union = struct {
        base: Type,

        pub fn destroy(self: *Union, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Union, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Namespace = struct {
        base: Type,

        pub fn destroy(self: *Namespace, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Block = struct {
        base: Type,

        pub fn destroy(self: *Block, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const BoundFn = struct {
        base: Type,

        pub fn destroy(self: *BoundFn, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *BoundFn, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ArgTuple = struct {
        base: Type,

        pub fn destroy(self: *ArgTuple, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Opaque = struct {
        base: Type,

        pub fn destroy(self: *Opaque, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Opaque, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Promise = struct {
        base: Type,

        pub fn destroy(self: *Promise, module: *Module) void {
            module.a().destroy(self);
        }

        pub fn getLlvmType(self: *Promise, cunit: *CompilationUnit) llvm.TypeRef {
            @panic("TODO");
        }
    };
};
