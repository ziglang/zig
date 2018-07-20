const std = @import("std");
const builtin = @import("builtin");
const Scope = @import("scope.zig").Scope;
const Compilation = @import("compilation.zig").Compilation;
const Value = @import("value.zig").Value;
const llvm = @import("llvm.zig");
const ObjectFile = @import("codegen.zig").ObjectFile;

pub const Type = struct {
    base: Value,
    id: Id,
    name: []const u8,

    pub const Id = builtin.TypeId;

    pub fn destroy(base: *Type, comp: *Compilation) void {
        switch (base.id) {
            Id.Struct => @fieldParentPtr(Struct, "base", base).destroy(comp),
            Id.Fn => @fieldParentPtr(Fn, "base", base).destroy(comp),
            Id.Type => @fieldParentPtr(MetaType, "base", base).destroy(comp),
            Id.Void => @fieldParentPtr(Void, "base", base).destroy(comp),
            Id.Bool => @fieldParentPtr(Bool, "base", base).destroy(comp),
            Id.NoReturn => @fieldParentPtr(NoReturn, "base", base).destroy(comp),
            Id.Int => @fieldParentPtr(Int, "base", base).destroy(comp),
            Id.Float => @fieldParentPtr(Float, "base", base).destroy(comp),
            Id.Pointer => @fieldParentPtr(Pointer, "base", base).destroy(comp),
            Id.Array => @fieldParentPtr(Array, "base", base).destroy(comp),
            Id.ComptimeFloat => @fieldParentPtr(ComptimeFloat, "base", base).destroy(comp),
            Id.ComptimeInt => @fieldParentPtr(ComptimeInt, "base", base).destroy(comp),
            Id.Undefined => @fieldParentPtr(Undefined, "base", base).destroy(comp),
            Id.Null => @fieldParentPtr(Null, "base", base).destroy(comp),
            Id.Optional => @fieldParentPtr(Optional, "base", base).destroy(comp),
            Id.ErrorUnion => @fieldParentPtr(ErrorUnion, "base", base).destroy(comp),
            Id.ErrorSet => @fieldParentPtr(ErrorSet, "base", base).destroy(comp),
            Id.Enum => @fieldParentPtr(Enum, "base", base).destroy(comp),
            Id.Union => @fieldParentPtr(Union, "base", base).destroy(comp),
            Id.Namespace => @fieldParentPtr(Namespace, "base", base).destroy(comp),
            Id.Block => @fieldParentPtr(Block, "base", base).destroy(comp),
            Id.BoundFn => @fieldParentPtr(BoundFn, "base", base).destroy(comp),
            Id.ArgTuple => @fieldParentPtr(ArgTuple, "base", base).destroy(comp),
            Id.Opaque => @fieldParentPtr(Opaque, "base", base).destroy(comp),
            Id.Promise => @fieldParentPtr(Promise, "base", base).destroy(comp),
        }
    }

    pub fn getLlvmType(base: *Type, ofile: *ObjectFile) (error{OutOfMemory}!llvm.TypeRef) {
        switch (base.id) {
            Id.Struct => return @fieldParentPtr(Struct, "base", base).getLlvmType(ofile),
            Id.Fn => return @fieldParentPtr(Fn, "base", base).getLlvmType(ofile),
            Id.Type => unreachable,
            Id.Void => unreachable,
            Id.Bool => return @fieldParentPtr(Bool, "base", base).getLlvmType(ofile),
            Id.NoReturn => unreachable,
            Id.Int => return @fieldParentPtr(Int, "base", base).getLlvmType(ofile),
            Id.Float => return @fieldParentPtr(Float, "base", base).getLlvmType(ofile),
            Id.Pointer => return @fieldParentPtr(Pointer, "base", base).getLlvmType(ofile),
            Id.Array => return @fieldParentPtr(Array, "base", base).getLlvmType(ofile),
            Id.ComptimeFloat => unreachable,
            Id.ComptimeInt => unreachable,
            Id.Undefined => unreachable,
            Id.Null => unreachable,
            Id.Optional => return @fieldParentPtr(Optional, "base", base).getLlvmType(ofile),
            Id.ErrorUnion => return @fieldParentPtr(ErrorUnion, "base", base).getLlvmType(ofile),
            Id.ErrorSet => return @fieldParentPtr(ErrorSet, "base", base).getLlvmType(ofile),
            Id.Enum => return @fieldParentPtr(Enum, "base", base).getLlvmType(ofile),
            Id.Union => return @fieldParentPtr(Union, "base", base).getLlvmType(ofile),
            Id.Namespace => unreachable,
            Id.Block => unreachable,
            Id.BoundFn => return @fieldParentPtr(BoundFn, "base", base).getLlvmType(ofile),
            Id.ArgTuple => unreachable,
            Id.Opaque => return @fieldParentPtr(Opaque, "base", base).getLlvmType(ofile),
            Id.Promise => return @fieldParentPtr(Promise, "base", base).getLlvmType(ofile),
        }
    }

    pub fn handleIsPtr(base: *Type) bool {
        switch (base.id) {
            Id.Type,
            Id.ComptimeFloat,
            Id.ComptimeInt,
            Id.Undefined,
            Id.Null,
            Id.Namespace,
            Id.Block,
            Id.BoundFn,
            Id.ArgTuple,
            Id.Opaque,
            => unreachable,

            Id.NoReturn,
            Id.Void,
            Id.Bool,
            Id.Int,
            Id.Float,
            Id.Pointer,
            Id.ErrorSet,
            Id.Enum,
            Id.Fn,
            Id.Promise,
            => return false,

            Id.Struct => @panic("TODO"),
            Id.Array => @panic("TODO"),
            Id.Optional => @panic("TODO"),
            Id.ErrorUnion => @panic("TODO"),
            Id.Union => @panic("TODO"),
        }
    }

    pub fn hasBits(base: *Type) bool {
        switch (base.id) {
            Id.Type,
            Id.ComptimeFloat,
            Id.ComptimeInt,
            Id.Undefined,
            Id.Null,
            Id.Namespace,
            Id.Block,
            Id.BoundFn,
            Id.ArgTuple,
            Id.Opaque,
            => unreachable,

            Id.Void,
            Id.NoReturn,
            => return false,

            Id.Bool,
            Id.Int,
            Id.Float,
            Id.Fn,
            Id.Promise,
            => return true,

            Id.ErrorSet => @panic("TODO"),
            Id.Enum => @panic("TODO"),
            Id.Pointer => @panic("TODO"),
            Id.Struct => @panic("TODO"),
            Id.Array => @panic("TODO"),
            Id.Optional => @panic("TODO"),
            Id.ErrorUnion => @panic("TODO"),
            Id.Union => @panic("TODO"),
        }
    }

    pub fn cast(base: *Type, comptime T: type) ?*T {
        if (base.id != @field(Id, @typeName(T))) return null;
        return @fieldParentPtr(T, "base", base);
    }

    pub fn dump(base: *const Type) void {
        std.debug.warn("{}", @tagName(base.id));
    }

    fn init(base: *Type, comp: *Compilation, id: Id, name: []const u8) void {
        base.* = Type{
            .base = Value{
                .id = Value.Id.Type,
                .typeof = &MetaType.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
            .id = id,
            .name = name,
        };
    }

    pub fn getAbiAlignment(base: *Type, comp: *Compilation) u32 {
        @panic("TODO getAbiAlignment");
    }

    pub const Struct = struct {
        base: Type,
        decls: *Scope.Decls,

        pub fn destroy(self: *Struct, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Struct, ofile: *ObjectFile) llvm.TypeRef {
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

        pub fn create(comp: *Compilation, return_type: *Type, params: []Param, is_var_args: bool) !*Fn {
            const result = try comp.gpa().create(Fn{
                .base = undefined,
                .return_type = return_type,
                .params = params,
                .is_var_args = is_var_args,
            });
            errdefer comp.gpa().destroy(result);

            result.base.init(comp, Id.Fn, "TODO fn type name");

            result.return_type.base.ref();
            for (result.params) |param| {
                param.typeof.base.ref();
            }
            return result;
        }

        pub fn destroy(self: *Fn, comp: *Compilation) void {
            self.return_type.base.deref(comp);
            for (self.params) |param| {
                param.typeof.base.deref(comp);
            }
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Fn, ofile: *ObjectFile) !llvm.TypeRef {
            const llvm_return_type = switch (self.return_type.id) {
                Type.Id.Void => llvm.VoidTypeInContext(ofile.context) orelse return error.OutOfMemory,
                else => try self.return_type.getLlvmType(ofile),
            };
            const llvm_param_types = try ofile.gpa().alloc(llvm.TypeRef, self.params.len);
            defer ofile.gpa().free(llvm_param_types);
            for (llvm_param_types) |*llvm_param_type, i| {
                llvm_param_type.* = try self.params[i].typeof.getLlvmType(ofile);
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
        pub fn get(comp: *Compilation) *MetaType {
            comp.meta_type.base.base.ref();
            return comp.meta_type;
        }

        pub fn destroy(self: *MetaType, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Void = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(comp: *Compilation) *Void {
            comp.void_type.base.base.ref();
            return comp.void_type;
        }

        pub fn destroy(self: *Void, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Bool = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(comp: *Compilation) *Bool {
            comp.bool_type.base.base.ref();
            return comp.bool_type;
        }

        pub fn destroy(self: *Bool, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Bool, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const NoReturn = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(comp: *Compilation) *NoReturn {
            comp.noreturn_type.base.base.ref();
            return comp.noreturn_type;
        }

        pub fn destroy(self: *NoReturn, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Int = struct {
        base: Type,
        key: Key,
        garbage_node: std.atomic.Stack(*Int).Node,

        pub const Key = struct {
            bit_count: u32,
            is_signed: bool,

            pub fn hash(self: *const Key) u32 {
                const rands = [2]u32{ 0xa4ba6498, 0x75fc5af7 };
                return rands[@boolToInt(self.is_signed)] *% self.bit_count;
            }

            pub fn eql(self: *const Key, other: *const Key) bool {
                return self.bit_count == other.bit_count and self.is_signed == other.is_signed;
            }
        };

        pub async fn get(comp: *Compilation, key: Key) !*Int {
            {
                const held = await (async comp.int_type_table.acquire() catch unreachable);
                defer held.release();

                if (held.value.get(&key)) |entry| {
                    entry.value.base.base.ref();
                    return entry.value;
                }
            }

            const self = try comp.gpa().create(Int{
                .base = undefined,
                .key = key,
                .garbage_node = undefined,
            });
            errdefer comp.gpa().destroy(self);

            const u_or_i = "ui"[@boolToInt(key.is_signed)];
            const name = try std.fmt.allocPrint(comp.gpa(), "{c}{}", u_or_i, key.bit_count);
            errdefer comp.gpa().free(name);

            self.base.init(comp, Id.Int, name);

            {
                const held = await (async comp.int_type_table.acquire() catch unreachable);
                defer held.release();

                _ = try held.value.put(&self.key, self);
            }
            return self;
        }

        pub fn destroy(self: *Int, comp: *Compilation) void {
            self.garbage_node = std.atomic.Stack(*Int).Node{
                .data = self,
                .next = undefined,
            };
            comp.registerGarbage(Int, &self.garbage_node);
        }

        pub async fn gcDestroy(self: *Int, comp: *Compilation) void {
            {
                const held = await (async comp.int_type_table.acquire() catch unreachable);
                defer held.release();

                _ = held.value.remove(&self.key).?;
            }
            // we allocated the name
            comp.gpa().free(self.base.name);
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Int, ofile: *ObjectFile) !llvm.TypeRef {
            return llvm.IntTypeInContext(ofile.context, self.key.bit_count) orelse return error.OutOfMemory;
        }
    };

    pub const Float = struct {
        base: Type,

        pub fn destroy(self: *Float, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Float, ofile: *ObjectFile) llvm.TypeRef {
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

        pub fn destroy(self: *Pointer, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn get(
            comp: *Compilation,
            elem_type: *Type,
            mut: Mut,
            vol: Vol,
            size: Size,
            alignment: u32,
        ) *Pointer {
            @panic("TODO get pointer");
        }

        pub fn getLlvmType(self: *Pointer, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Array = struct {
        base: Type,

        pub fn destroy(self: *Array, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Array, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ComptimeFloat = struct {
        base: Type,

        pub fn destroy(self: *ComptimeFloat, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const ComptimeInt = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(comp: *Compilation) *ComptimeInt {
            comp.comptime_int_type.base.base.ref();
            return comp.comptime_int_type;
        }

        pub fn destroy(self: *ComptimeInt, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Undefined = struct {
        base: Type,

        pub fn destroy(self: *Undefined, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Null = struct {
        base: Type,

        pub fn destroy(self: *Null, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Optional = struct {
        base: Type,

        pub fn destroy(self: *Optional, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Optional, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ErrorUnion = struct {
        base: Type,

        pub fn destroy(self: *ErrorUnion, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *ErrorUnion, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ErrorSet = struct {
        base: Type,

        pub fn destroy(self: *ErrorSet, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *ErrorSet, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Enum = struct {
        base: Type,

        pub fn destroy(self: *Enum, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Enum, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Union = struct {
        base: Type,

        pub fn destroy(self: *Union, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Union, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Namespace = struct {
        base: Type,

        pub fn destroy(self: *Namespace, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Block = struct {
        base: Type,

        pub fn destroy(self: *Block, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const BoundFn = struct {
        base: Type,

        pub fn destroy(self: *BoundFn, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *BoundFn, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ArgTuple = struct {
        base: Type,

        pub fn destroy(self: *ArgTuple, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }
    };

    pub const Opaque = struct {
        base: Type,

        pub fn destroy(self: *Opaque, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Opaque, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Promise = struct {
        base: Type,

        pub fn destroy(self: *Promise, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Promise, ofile: *ObjectFile) llvm.TypeRef {
            @panic("TODO");
        }
    };
};
