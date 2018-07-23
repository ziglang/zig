const std = @import("std");
const builtin = @import("builtin");
const Scope = @import("scope.zig").Scope;
const Compilation = @import("compilation.zig").Compilation;
const Value = @import("value.zig").Value;
const llvm = @import("llvm.zig");
const event = std.event;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Type = struct {
    base: Value,
    id: Id,
    name: []const u8,
    abi_alignment: AbiAlignment,

    pub const AbiAlignment = event.Future(error{OutOfMemory}!u32);

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

    pub fn getLlvmType(
        base: *Type,
        allocator: *Allocator,
        llvm_context: llvm.ContextRef,
    ) (error{OutOfMemory}!llvm.TypeRef) {
        switch (base.id) {
            Id.Struct => return @fieldParentPtr(Struct, "base", base).getLlvmType(allocator, llvm_context),
            Id.Fn => return @fieldParentPtr(Fn, "base", base).getLlvmType(allocator, llvm_context),
            Id.Type => unreachable,
            Id.Void => unreachable,
            Id.Bool => return @fieldParentPtr(Bool, "base", base).getLlvmType(allocator, llvm_context),
            Id.NoReturn => unreachable,
            Id.Int => return @fieldParentPtr(Int, "base", base).getLlvmType(allocator, llvm_context),
            Id.Float => return @fieldParentPtr(Float, "base", base).getLlvmType(allocator, llvm_context),
            Id.Pointer => return @fieldParentPtr(Pointer, "base", base).getLlvmType(allocator, llvm_context),
            Id.Array => return @fieldParentPtr(Array, "base", base).getLlvmType(allocator, llvm_context),
            Id.ComptimeFloat => unreachable,
            Id.ComptimeInt => unreachable,
            Id.Undefined => unreachable,
            Id.Null => unreachable,
            Id.Optional => return @fieldParentPtr(Optional, "base", base).getLlvmType(allocator, llvm_context),
            Id.ErrorUnion => return @fieldParentPtr(ErrorUnion, "base", base).getLlvmType(allocator, llvm_context),
            Id.ErrorSet => return @fieldParentPtr(ErrorSet, "base", base).getLlvmType(allocator, llvm_context),
            Id.Enum => return @fieldParentPtr(Enum, "base", base).getLlvmType(allocator, llvm_context),
            Id.Union => return @fieldParentPtr(Union, "base", base).getLlvmType(allocator, llvm_context),
            Id.Namespace => unreachable,
            Id.Block => unreachable,
            Id.BoundFn => return @fieldParentPtr(BoundFn, "base", base).getLlvmType(allocator, llvm_context),
            Id.ArgTuple => unreachable,
            Id.Opaque => return @fieldParentPtr(Opaque, "base", base).getLlvmType(allocator, llvm_context),
            Id.Promise => return @fieldParentPtr(Promise, "base", base).getLlvmType(allocator, llvm_context),
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
                .typ = &MetaType.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
            .id = id,
            .name = name,
            .abi_alignment = AbiAlignment.init(comp.loop),
        };
    }

    /// If you happen to have an llvm context handy, use getAbiAlignmentInContext instead.
    /// Otherwise, this one will grab one from the pool and then release it.
    pub async fn getAbiAlignment(base: *Type, comp: *Compilation) !u32 {
        if (await (async base.abi_alignment.start() catch unreachable)) |ptr| return ptr.*;

        {
            const held = try comp.event_loop_local.getAnyLlvmContext();
            defer held.release(comp.event_loop_local);

            const llvm_context = held.node.data;

            base.abi_alignment.data = await (async base.resolveAbiAlignment(comp, llvm_context) catch unreachable);
        }
        base.abi_alignment.resolve();
        return base.abi_alignment.data;
    }

    /// If you have an llvm conext handy, you can use it here.
    pub async fn getAbiAlignmentInContext(base: *Type, comp: *Compilation, llvm_context: llvm.ContextRef) !u32 {
        if (await (async base.abi_alignment.start() catch unreachable)) |ptr| return ptr.*;

        base.abi_alignment.data = await (async base.resolveAbiAlignment(comp, llvm_context) catch unreachable);
        base.abi_alignment.resolve();
        return base.abi_alignment.data;
    }

    /// Lower level function that does the work. See getAbiAlignment.
    async fn resolveAbiAlignment(base: *Type, comp: *Compilation, llvm_context: llvm.ContextRef) !u32 {
        const llvm_type = try base.getLlvmType(comp.gpa(), llvm_context);
        return @intCast(u32, llvm.ABIAlignmentOfType(comp.target_data_ref, llvm_type));
    }

    pub const Struct = struct {
        base: Type,
        decls: *Scope.Decls,

        pub fn destroy(self: *Struct, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Struct, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
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
            typ: *Type,
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
                param.typ.base.ref();
            }
            return result;
        }

        pub fn destroy(self: *Fn, comp: *Compilation) void {
            self.return_type.base.deref(comp);
            for (self.params) |param| {
                param.typ.base.deref(comp);
            }
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Fn, allocator: *Allocator, llvm_context: llvm.ContextRef) !llvm.TypeRef {
            const llvm_return_type = switch (self.return_type.id) {
                Type.Id.Void => llvm.VoidTypeInContext(llvm_context) orelse return error.OutOfMemory,
                else => try self.return_type.getLlvmType(allocator, llvm_context),
            };
            const llvm_param_types = try allocator.alloc(llvm.TypeRef, self.params.len);
            defer allocator.free(llvm_param_types);
            for (llvm_param_types) |*llvm_param_type, i| {
                llvm_param_type.* = try self.params[i].typ.getLlvmType(allocator, llvm_context);
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

        pub fn getLlvmType(self: *Bool, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
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

        pub fn get_u8(comp: *Compilation) *Int {
            comp.u8_type.base.base.ref();
            return comp.u8_type;
        }

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

        pub fn getLlvmType(self: *Int, allocator: *Allocator, llvm_context: llvm.ContextRef) !llvm.TypeRef {
            return llvm.IntTypeInContext(llvm_context, self.key.bit_count) orelse return error.OutOfMemory;
        }
    };

    pub const Float = struct {
        base: Type,

        pub fn destroy(self: *Float, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Float, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
            @panic("TODO");
        }
    };
    pub const Pointer = struct {
        base: Type,
        key: Key,
        garbage_node: std.atomic.Stack(*Pointer).Node,

        pub const Key = struct {
            child_type: *Type,
            mut: Mut,
            vol: Vol,
            size: Size,
            alignment: Align,

            pub fn hash(self: *const Key) u32 {
                const align_hash = switch (self.alignment) {
                    Align.Abi => 0xf201c090,
                    Align.Override => |x| x,
                };
                return hash_usize(@ptrToInt(self.child_type)) *%
                    hash_enum(self.mut) *%
                    hash_enum(self.vol) *%
                    hash_enum(self.size) *%
                    align_hash;
            }

            pub fn eql(self: *const Key, other: *const Key) bool {
                if (self.child_type != other.child_type or
                    self.mut != other.mut or
                    self.vol != other.vol or
                    self.size != other.size or
                    @TagType(Align)(self.alignment) != @TagType(Align)(other.alignment))
                {
                    return false;
                }
                switch (self.alignment) {
                    Align.Abi => return true,
                    Align.Override => |x| return x == other.alignment.Override,
                }
            }
        };

        pub const Mut = enum {
            Mut,
            Const,
        };

        pub const Vol = enum {
            Non,
            Volatile,
        };

        pub const Align = union(enum) {
            Abi,
            Override: u32,
        };

        pub const Size = builtin.TypeInfo.Pointer.Size;

        pub fn destroy(self: *Pointer, comp: *Compilation) void {
            self.garbage_node = std.atomic.Stack(*Pointer).Node{
                .data = self,
                .next = undefined,
            };
            comp.registerGarbage(Pointer, &self.garbage_node);
        }

        pub async fn gcDestroy(self: *Pointer, comp: *Compilation) void {
            {
                const held = await (async comp.ptr_type_table.acquire() catch unreachable);
                defer held.release();

                _ = held.value.remove(&self.key).?;
            }
            self.key.child_type.base.deref(comp);
            comp.gpa().destroy(self);
        }

        pub async fn getAlignAsInt(self: *Pointer, comp: *Compilation) u32 {
            switch (self.key.alignment) {
                Align.Abi => return await (async self.key.child_type.getAbiAlignment(comp) catch unreachable),
                Align.Override => |alignment| return alignment,
            }
        }

        pub async fn get(
            comp: *Compilation,
            key: Key,
        ) !*Pointer {
            var normal_key = key;
            switch (key.alignment) {
                Align.Abi => {},
                Align.Override => |alignment| {
                    const abi_align = try await (async key.child_type.getAbiAlignment(comp) catch unreachable);
                    if (abi_align == alignment) {
                        normal_key.alignment = Align.Abi;
                    }
                },
            }
            {
                const held = await (async comp.ptr_type_table.acquire() catch unreachable);
                defer held.release();

                if (held.value.get(&normal_key)) |entry| {
                    entry.value.base.base.ref();
                    return entry.value;
                }
            }

            const self = try comp.gpa().create(Pointer{
                .base = undefined,
                .key = normal_key,
                .garbage_node = undefined,
            });
            errdefer comp.gpa().destroy(self);

            const size_str = switch (self.key.size) {
                Size.One => "*",
                Size.Many => "[*]",
                Size.Slice => "[]",
            };
            const mut_str = switch (self.key.mut) {
                Mut.Const => "const ",
                Mut.Mut => "",
            };
            const vol_str = switch (self.key.vol) {
                Vol.Volatile => "volatile ",
                Vol.Non => "",
            };
            const name = switch (self.key.alignment) {
                Align.Abi => try std.fmt.allocPrint(
                    comp.gpa(),
                    "{}{}{}{}",
                    size_str,
                    mut_str,
                    vol_str,
                    self.key.child_type.name,
                ),
                Align.Override => |alignment| try std.fmt.allocPrint(
                    comp.gpa(),
                    "{}align<{}> {}{}{}",
                    size_str,
                    alignment,
                    mut_str,
                    vol_str,
                    self.key.child_type.name,
                ),
            };
            errdefer comp.gpa().free(name);

            self.base.init(comp, Id.Pointer, name);

            {
                const held = await (async comp.ptr_type_table.acquire() catch unreachable);
                defer held.release();

                _ = try held.value.put(&self.key, self);
            }
            return self;
        }

        pub fn getLlvmType(self: *Pointer, allocator: *Allocator, llvm_context: llvm.ContextRef) !llvm.TypeRef {
            const elem_llvm_type = try self.key.child_type.getLlvmType(allocator, llvm_context);
            return llvm.PointerType(elem_llvm_type, 0) orelse return error.OutOfMemory;
        }
    };

    pub const Array = struct {
        base: Type,
        key: Key,
        garbage_node: std.atomic.Stack(*Array).Node,

        pub const Key = struct {
            elem_type: *Type,
            len: usize,

            pub fn hash(self: *const Key) u32 {
                return hash_usize(@ptrToInt(self.elem_type)) *% hash_usize(self.len);
            }

            pub fn eql(self: *const Key, other: *const Key) bool {
                return self.elem_type == other.elem_type and self.len == other.len;
            }
        };

        pub fn destroy(self: *Array, comp: *Compilation) void {
            self.key.elem_type.base.deref(comp);
            comp.gpa().destroy(self);
        }

        pub async fn get(comp: *Compilation, key: Key) !*Array {
            key.elem_type.base.ref();
            errdefer key.elem_type.base.deref(comp);

            {
                const held = await (async comp.array_type_table.acquire() catch unreachable);
                defer held.release();

                if (held.value.get(&key)) |entry| {
                    entry.value.base.base.ref();
                    return entry.value;
                }
            }

            const self = try comp.gpa().create(Array{
                .base = undefined,
                .key = key,
                .garbage_node = undefined,
            });
            errdefer comp.gpa().destroy(self);

            const name = try std.fmt.allocPrint(comp.gpa(), "[{}]{}", key.len, key.elem_type.name);
            errdefer comp.gpa().free(name);

            self.base.init(comp, Id.Array, name);

            {
                const held = await (async comp.array_type_table.acquire() catch unreachable);
                defer held.release();

                _ = try held.value.put(&self.key, self);
            }
            return self;
        }

        pub fn getLlvmType(self: *Array, allocator: *Allocator, llvm_context: llvm.ContextRef) !llvm.TypeRef {
            const elem_llvm_type = try self.key.elem_type.getLlvmType(allocator, llvm_context);
            return llvm.ArrayType(elem_llvm_type, @intCast(c_uint, self.key.len)) orelse return error.OutOfMemory;
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

        pub fn getLlvmType(self: *Optional, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ErrorUnion = struct {
        base: Type,

        pub fn destroy(self: *ErrorUnion, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *ErrorUnion, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const ErrorSet = struct {
        base: Type,

        pub fn destroy(self: *ErrorSet, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *ErrorSet, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Enum = struct {
        base: Type,

        pub fn destroy(self: *Enum, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Enum, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Union = struct {
        base: Type,

        pub fn destroy(self: *Union, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Union, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
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

        pub fn getLlvmType(self: *BoundFn, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
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

        pub fn getLlvmType(self: *Opaque, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
            @panic("TODO");
        }
    };

    pub const Promise = struct {
        base: Type,

        pub fn destroy(self: *Promise, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Promise, allocator: *Allocator, llvm_context: llvm.ContextRef) llvm.TypeRef {
            @panic("TODO");
        }
    };
};

fn hash_usize(x: usize) u32 {
    return switch (@sizeOf(usize)) {
        4 => x,
        8 => @truncate(u32, x *% 0xad44ee2d8e3fc13d),
        else => @compileError("implement this hash function"),
    };
}

fn hash_enum(x: var) u32 {
    const rands = []u32{
        0x85ebf64f,
        0x3fcb3211,
        0x240a4e8e,
        0x40bb0e3c,
        0x78be45af,
        0x1ca98e37,
        0xec56053a,
        0x906adc48,
        0xd4fe9763,
        0x54c80dac,
    };
    comptime assert(@memberCount(@typeOf(x)) < rands.len);
    return rands[@enumToInt(x)];
}
