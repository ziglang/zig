const std = @import("std");
const builtin = std.builtin;
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
            .Struct => @fieldParentPtr(Struct, "base", base).destroy(comp),
            .Fn => @fieldParentPtr(Fn, "base", base).destroy(comp),
            .Type => @fieldParentPtr(MetaType, "base", base).destroy(comp),
            .Void => @fieldParentPtr(Void, "base", base).destroy(comp),
            .Bool => @fieldParentPtr(Bool, "base", base).destroy(comp),
            .NoReturn => @fieldParentPtr(NoReturn, "base", base).destroy(comp),
            .Int => @fieldParentPtr(Int, "base", base).destroy(comp),
            .Float => @fieldParentPtr(Float, "base", base).destroy(comp),
            .Pointer => @fieldParentPtr(Pointer, "base", base).destroy(comp),
            .Array => @fieldParentPtr(Array, "base", base).destroy(comp),
            .ComptimeFloat => @fieldParentPtr(ComptimeFloat, "base", base).destroy(comp),
            .ComptimeInt => @fieldParentPtr(ComptimeInt, "base", base).destroy(comp),
            .EnumLiteral => @fieldParentPtr(EnumLiteral, "base", base).destroy(comp),
            .Undefined => @fieldParentPtr(Undefined, "base", base).destroy(comp),
            .Null => @fieldParentPtr(Null, "base", base).destroy(comp),
            .Optional => @fieldParentPtr(Optional, "base", base).destroy(comp),
            .ErrorUnion => @fieldParentPtr(ErrorUnion, "base", base).destroy(comp),
            .ErrorSet => @fieldParentPtr(ErrorSet, "base", base).destroy(comp),
            .Enum => @fieldParentPtr(Enum, "base", base).destroy(comp),
            .Union => @fieldParentPtr(Union, "base", base).destroy(comp),
            .BoundFn => @fieldParentPtr(BoundFn, "base", base).destroy(comp),
            .Opaque => @fieldParentPtr(Opaque, "base", base).destroy(comp),
            .Frame => @fieldParentPtr(Frame, "base", base).destroy(comp),
            .AnyFrame => @fieldParentPtr(AnyFrame, "base", base).destroy(comp),
            .Vector => @fieldParentPtr(Vector, "base", base).destroy(comp),
        }
    }

    pub fn getLlvmType(
        base: *Type,
        allocator: *Allocator,
        llvm_context: *llvm.Context,
    ) error{OutOfMemory}!*llvm.Type {
        switch (base.id) {
            .Struct => return @fieldParentPtr(Struct, "base", base).getLlvmType(allocator, llvm_context),
            .Fn => return @fieldParentPtr(Fn, "base", base).getLlvmType(allocator, llvm_context),
            .Type => unreachable,
            .Void => unreachable,
            .Bool => return @fieldParentPtr(Bool, "base", base).getLlvmType(allocator, llvm_context),
            .NoReturn => unreachable,
            .Int => return @fieldParentPtr(Int, "base", base).getLlvmType(allocator, llvm_context),
            .Float => return @fieldParentPtr(Float, "base", base).getLlvmType(allocator, llvm_context),
            .Pointer => return @fieldParentPtr(Pointer, "base", base).getLlvmType(allocator, llvm_context),
            .Array => return @fieldParentPtr(Array, "base", base).getLlvmType(allocator, llvm_context),
            .ComptimeFloat => unreachable,
            .ComptimeInt => unreachable,
            .EnumLiteral => unreachable,
            .Undefined => unreachable,
            .Null => unreachable,
            .Optional => return @fieldParentPtr(Optional, "base", base).getLlvmType(allocator, llvm_context),
            .ErrorUnion => return @fieldParentPtr(ErrorUnion, "base", base).getLlvmType(allocator, llvm_context),
            .ErrorSet => return @fieldParentPtr(ErrorSet, "base", base).getLlvmType(allocator, llvm_context),
            .Enum => return @fieldParentPtr(Enum, "base", base).getLlvmType(allocator, llvm_context),
            .Union => return @fieldParentPtr(Union, "base", base).getLlvmType(allocator, llvm_context),
            .BoundFn => return @fieldParentPtr(BoundFn, "base", base).getLlvmType(allocator, llvm_context),
            .Opaque => return @fieldParentPtr(Opaque, "base", base).getLlvmType(allocator, llvm_context),
            .Frame => return @fieldParentPtr(Frame, "base", base).getLlvmType(allocator, llvm_context),
            .AnyFrame => return @fieldParentPtr(AnyFrame, "base", base).getLlvmType(allocator, llvm_context),
            .Vector => return @fieldParentPtr(Vector, "base", base).getLlvmType(allocator, llvm_context),
        }
    }

    pub fn handleIsPtr(base: *Type) bool {
        switch (base.id) {
            .Type,
            .ComptimeFloat,
            .ComptimeInt,
            .EnumLiteral,
            .Undefined,
            .Null,
            .BoundFn,
            .Opaque,
            => unreachable,

            .NoReturn,
            .Void,
            .Bool,
            .Int,
            .Float,
            .Pointer,
            .ErrorSet,
            .Enum,
            .Fn,
            .Frame,
            .AnyFrame,
            .Vector,
            => return false,

            .Struct => @panic("TODO"),
            .Array => @panic("TODO"),
            .Optional => @panic("TODO"),
            .ErrorUnion => @panic("TODO"),
            .Union => @panic("TODO"),
        }
    }

    pub fn hasBits(base: *Type) bool {
        switch (base.id) {
            .Type,
            .ComptimeFloat,
            .ComptimeInt,
            .EnumLiteral,
            .Undefined,
            .Null,
            .BoundFn,
            .Opaque,
            => unreachable,

            .Void,
            .NoReturn,
            => return false,

            .Bool,
            .Int,
            .Float,
            .Fn,
            .Frame,
            .AnyFrame,
            .Vector,
            => return true,

            .Pointer => {
                const ptr_type = @fieldParentPtr(Pointer, "base", base);
                return ptr_type.key.child_type.hasBits();
            },

            .ErrorSet => @panic("TODO"),
            .Enum => @panic("TODO"),
            .Struct => @panic("TODO"),
            .Array => @panic("TODO"),
            .Optional => @panic("TODO"),
            .ErrorUnion => @panic("TODO"),
            .Union => @panic("TODO"),
        }
    }

    pub fn cast(base: *Type, comptime T: type) ?*T {
        if (base.id != @field(Id, @typeName(T))) return null;
        return @fieldParentPtr(T, "base", base);
    }

    pub fn dump(base: *const Type) void {
        std.debug.warn("{}", .{@tagName(base.id)});
    }

    fn init(base: *Type, comp: *Compilation, id: Id, name: []const u8) void {
        base.* = Type{
            .base = Value{
                .id = .Type,
                .typ = &MetaType.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
            .id = id,
            .name = name,
            .abi_alignment = AbiAlignment.init(),
        };
    }

    /// If you happen to have an llvm context handy, use getAbiAlignmentInContext instead.
    /// Otherwise, this one will grab one from the pool and then release it.
    pub fn getAbiAlignment(base: *Type, comp: *Compilation) !u32 {
        if (base.abi_alignment.start()) |ptr| return ptr.*;

        {
            const held = try comp.zig_compiler.getAnyLlvmContext();
            defer held.release(comp.zig_compiler);

            const llvm_context = held.node.data;

            base.abi_alignment.data = base.resolveAbiAlignment(comp, llvm_context);
        }
        base.abi_alignment.resolve();
        return base.abi_alignment.data;
    }

    /// If you have an llvm conext handy, you can use it here.
    pub fn getAbiAlignmentInContext(base: *Type, comp: *Compilation, llvm_context: *llvm.Context) !u32 {
        if (base.abi_alignment.start()) |ptr| return ptr.*;

        base.abi_alignment.data = base.resolveAbiAlignment(comp, llvm_context);
        base.abi_alignment.resolve();
        return base.abi_alignment.data;
    }

    /// Lower level function that does the work. See getAbiAlignment.
    fn resolveAbiAlignment(base: *Type, comp: *Compilation, llvm_context: *llvm.Context) !u32 {
        const llvm_type = try base.getLlvmType(comp.gpa(), llvm_context);
        return @intCast(u32, llvm.ABIAlignmentOfType(comp.target_data_ref, llvm_type));
    }

    pub const Struct = struct {
        base: Type,
        decls: *Scope.Decls,

        pub fn destroy(self: *Struct, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Struct, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const Fn = struct {
        base: Type,
        key: Key,
        non_key: NonKey,
        garbage_node: std.atomic.Stack(*Fn).Node,

        pub const Kind = enum {
            Normal,
            Generic,
        };

        pub const NonKey = union {
            Normal: Normal,
            Generic: void,

            pub const Normal = struct {
                variable_list: std.ArrayList(*Scope.Var),
            };
        };

        pub const Key = struct {
            data: Data,
            alignment: ?u32,

            pub const Data = union(Kind) {
                Generic: Generic,
                Normal: Normal,
            };

            pub const Normal = struct {
                params: []Param,
                return_type: *Type,
                is_var_args: bool,
                cc: CallingConvention,
            };

            pub const Generic = struct {
                param_count: usize,
                cc: CallingConvention,
            };

            pub fn hash(self: *const Key) u32 {
                var result: u32 = 0;
                result +%= hashAny(self.alignment, 0);
                switch (self.data) {
                    .Generic => |generic| {
                        result +%= hashAny(generic.param_count, 1);
                        result +%= hashAny(generic.cc, 3);
                    },
                    .Normal => |normal| {
                        result +%= hashAny(normal.return_type, 4);
                        result +%= hashAny(normal.is_var_args, 5);
                        result +%= hashAny(normal.cc, 6);
                        for (normal.params) |param| {
                            result +%= hashAny(param.is_noalias, 7);
                            result +%= hashAny(param.typ, 8);
                        }
                    },
                }
                return result;
            }

            pub fn eql(self: *const Key, other: *const Key) bool {
                if ((self.alignment == null) != (other.alignment == null)) return false;
                if (self.alignment) |self_align| {
                    if (self_align != other.alignment.?) return false;
                }
                if (@as(@TagType(Data), self.data) != @as(@TagType(Data), other.data)) return false;
                switch (self.data) {
                    .Generic => |*self_generic| {
                        const other_generic = &other.data.Generic;
                        if (self_generic.param_count != other_generic.param_count) return false;
                        if (self_generic.cc != other_generic.cc) return false;
                    },
                    .Normal => |*self_normal| {
                        const other_normal = &other.data.Normal;
                        if (self_normal.cc != other_normal.cc) return false;
                        if (self_normal.is_var_args != other_normal.is_var_args) return false;
                        if (self_normal.return_type != other_normal.return_type) return false;
                        for (self_normal.params) |*self_param, i| {
                            const other_param = &other_normal.params[i];
                            if (self_param.is_noalias != other_param.is_noalias) return false;
                            if (self_param.typ != other_param.typ) return false;
                        }
                    },
                }
                return true;
            }

            pub fn deref(key: Key, comp: *Compilation) void {
                switch (key.data) {
                    .Generic => {},
                    .Normal => |normal| {
                        normal.return_type.base.deref(comp);
                        for (normal.params) |param| {
                            param.typ.base.deref(comp);
                        }
                    },
                }
            }

            pub fn ref(key: Key) void {
                switch (key.data) {
                    .Generic => {},
                    .Normal => |normal| {
                        normal.return_type.base.ref();
                        for (normal.params) |param| {
                            param.typ.base.ref();
                        }
                    },
                }
            }
        };

        const CallingConvention = builtin.CallingConvention;

        pub const Param = struct {
            is_noalias: bool,
            typ: *Type,
        };

        fn ccFnTypeStr(cc: CallingConvention) []const u8 {
            return switch (cc) {
                .Unspecified => "",
                .C => "extern ",
                .Cold => "coldcc ",
                .Naked => "nakedcc ",
                .Stdcall => "stdcallcc ",
                .Async => "async ",
                else => unreachable,
            };
        }

        pub fn paramCount(self: *Fn) usize {
            return switch (self.key.data) {
                .Generic => |generic| generic.param_count,
                .Normal => |normal| normal.params.len,
            };
        }

        /// takes ownership of key.Normal.params on success
        pub fn get(comp: *Compilation, key: Key) !*Fn {
            {
                const held = comp.fn_type_table.acquire();
                defer held.release();

                if (held.value.get(&key)) |entry| {
                    entry.value.base.base.ref();
                    return entry.value;
                }
            }

            key.ref();
            errdefer key.deref(comp);

            const self = try comp.gpa().create(Fn);
            self.* = Fn{
                .base = undefined,
                .key = key,
                .non_key = undefined,
                .garbage_node = undefined,
            };
            errdefer comp.gpa().destroy(self);

            var name_buf = try std.Buffer.initSize(comp.gpa(), 0);
            defer name_buf.deinit();

            const name_stream = &std.io.BufferOutStream.init(&name_buf).stream;

            switch (key.data) {
                .Generic => |generic| {
                    self.non_key = NonKey{ .Generic = {} };
                    const cc_str = ccFnTypeStr(generic.cc);
                    try name_stream.print("{}fn(", .{cc_str});
                    var param_i: usize = 0;
                    while (param_i < generic.param_count) : (param_i += 1) {
                        const arg = if (param_i == 0) "var" else ", var";
                        try name_stream.write(arg);
                    }
                    try name_stream.write(")");
                    if (key.alignment) |alignment| {
                        try name_stream.print(" align({})", .{alignment});
                    }
                    try name_stream.write(" var");
                },
                .Normal => |normal| {
                    self.non_key = NonKey{
                        .Normal = NonKey.Normal{ .variable_list = std.ArrayList(*Scope.Var).init(comp.gpa()) },
                    };
                    const cc_str = ccFnTypeStr(normal.cc);
                    try name_stream.print("{}fn(", .{cc_str});
                    for (normal.params) |param, i| {
                        if (i != 0) try name_stream.write(", ");
                        if (param.is_noalias) try name_stream.write("noalias ");
                        try name_stream.write(param.typ.name);
                    }
                    if (normal.is_var_args) {
                        if (normal.params.len != 0) try name_stream.write(", ");
                        try name_stream.write("...");
                    }
                    try name_stream.write(")");
                    if (key.alignment) |alignment| {
                        try name_stream.print(" align({})", .{alignment});
                    }
                    try name_stream.print(" {}", .{normal.return_type.name});
                },
            }

            self.base.init(comp, .Fn, name_buf.toOwnedSlice());

            {
                const held = comp.fn_type_table.acquire();
                defer held.release();

                _ = try held.value.put(&self.key, self);
            }
            return self;
        }

        pub fn destroy(self: *Fn, comp: *Compilation) void {
            self.key.deref(comp);
            switch (self.key.data) {
                .Generic => {},
                .Normal => {
                    self.non_key.Normal.variable_list.deinit();
                },
            }
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Fn, allocator: *Allocator, llvm_context: *llvm.Context) !*llvm.Type {
            const normal = &self.key.data.Normal;
            const llvm_return_type = switch (normal.return_type.id) {
                .Void => llvm.VoidTypeInContext(llvm_context) orelse return error.OutOfMemory,
                else => try normal.return_type.getLlvmType(allocator, llvm_context),
            };
            const llvm_param_types = try allocator.alloc(*llvm.Type, normal.params.len);
            defer allocator.free(llvm_param_types);
            for (llvm_param_types) |*llvm_param_type, i| {
                llvm_param_type.* = try normal.params[i].typ.getLlvmType(allocator, llvm_context);
            }

            return llvm.FunctionType(
                llvm_return_type,
                llvm_param_types.ptr,
                @intCast(c_uint, llvm_param_types.len),
                @boolToInt(normal.is_var_args),
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

        pub fn getLlvmType(self: *Bool, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
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
                var result: u32 = 0;
                result +%= hashAny(self.is_signed, 0);
                result +%= hashAny(self.bit_count, 1);
                return result;
            }

            pub fn eql(self: *const Key, other: *const Key) bool {
                return self.bit_count == other.bit_count and self.is_signed == other.is_signed;
            }
        };

        pub fn get_u8(comp: *Compilation) *Int {
            comp.u8_type.base.base.ref();
            return comp.u8_type;
        }

        pub fn get(comp: *Compilation, key: Key) !*Int {
            {
                const held = comp.int_type_table.acquire();
                defer held.release();

                if (held.value.get(&key)) |entry| {
                    entry.value.base.base.ref();
                    return entry.value;
                }
            }

            const self = try comp.gpa().create(Int);
            self.* = Int{
                .base = undefined,
                .key = key,
                .garbage_node = undefined,
            };
            errdefer comp.gpa().destroy(self);

            const u_or_i = "ui"[@boolToInt(key.is_signed)];
            const name = try std.fmt.allocPrint(comp.gpa(), "{c}{}", .{ u_or_i, key.bit_count });
            errdefer comp.gpa().free(name);

            self.base.init(comp, .Int, name);

            {
                const held = comp.int_type_table.acquire();
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

        pub fn gcDestroy(self: *Int, comp: *Compilation) void {
            {
                const held = comp.int_type_table.acquire();
                defer held.release();

                _ = held.value.remove(&self.key).?;
            }
            // we allocated the name
            comp.gpa().free(self.base.name);
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Int, allocator: *Allocator, llvm_context: *llvm.Context) !*llvm.Type {
            return llvm.IntTypeInContext(llvm_context, self.key.bit_count) orelse return error.OutOfMemory;
        }
    };

    pub const Float = struct {
        base: Type,

        pub fn destroy(self: *Float, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Float, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
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
                var result: u32 = 0;
                result +%= switch (self.alignment) {
                    .Abi => 0xf201c090,
                    .Override => |x| hashAny(x, 0),
                };
                result +%= hashAny(self.child_type, 1);
                result +%= hashAny(self.mut, 2);
                result +%= hashAny(self.vol, 3);
                result +%= hashAny(self.size, 4);
                return result;
            }

            pub fn eql(self: *const Key, other: *const Key) bool {
                if (self.child_type != other.child_type or
                    self.mut != other.mut or
                    self.vol != other.vol or
                    self.size != other.size or
                    @as(@TagType(Align), self.alignment) != @as(@TagType(Align), other.alignment))
                {
                    return false;
                }
                switch (self.alignment) {
                    .Abi => return true,
                    .Override => |x| return x == other.alignment.Override,
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

        pub fn gcDestroy(self: *Pointer, comp: *Compilation) void {
            {
                const held = comp.ptr_type_table.acquire();
                defer held.release();

                _ = held.value.remove(&self.key).?;
            }
            self.key.child_type.base.deref(comp);
            comp.gpa().destroy(self);
        }

        pub fn getAlignAsInt(self: *Pointer, comp: *Compilation) u32 {
            switch (self.key.alignment) {
                .Abi => return self.key.child_type.getAbiAlignment(comp),
                .Override => |alignment| return alignment,
            }
        }

        pub fn get(
            comp: *Compilation,
            key: Key,
        ) !*Pointer {
            var normal_key = key;
            switch (key.alignment) {
                .Abi => {},
                .Override => |alignment| {
                    // TODO https://github.com/ziglang/zig/issues/3190
                    var align_spill = alignment;
                    const abi_align = try key.child_type.getAbiAlignment(comp);
                    if (abi_align == align_spill) {
                        normal_key.alignment = .Abi;
                    }
                },
            }
            {
                const held = comp.ptr_type_table.acquire();
                defer held.release();

                if (held.value.get(&normal_key)) |entry| {
                    entry.value.base.base.ref();
                    return entry.value;
                }
            }

            const self = try comp.gpa().create(Pointer);
            self.* = Pointer{
                .base = undefined,
                .key = normal_key,
                .garbage_node = undefined,
            };
            errdefer comp.gpa().destroy(self);

            const size_str = switch (self.key.size) {
                .One => "*",
                .Many => "[*]",
                .Slice => "[]",
                .C => "[*c]",
            };
            const mut_str = switch (self.key.mut) {
                .Const => "const ",
                .Mut => "",
            };
            const vol_str = switch (self.key.vol) {
                .Volatile => "volatile ",
                .Non => "",
            };
            const name = switch (self.key.alignment) {
                .Abi => try std.fmt.allocPrint(comp.gpa(), "{}{}{}{}", .{
                    size_str,
                    mut_str,
                    vol_str,
                    self.key.child_type.name,
                }),
                .Override => |alignment| try std.fmt.allocPrint(comp.gpa(), "{}align<{}> {}{}{}", .{
                    size_str,
                    alignment,
                    mut_str,
                    vol_str,
                    self.key.child_type.name,
                }),
            };
            errdefer comp.gpa().free(name);

            self.base.init(comp, .Pointer, name);

            {
                const held = comp.ptr_type_table.acquire();
                defer held.release();

                _ = try held.value.put(&self.key, self);
            }
            return self;
        }

        pub fn getLlvmType(self: *Pointer, allocator: *Allocator, llvm_context: *llvm.Context) !*llvm.Type {
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
                var result: u32 = 0;
                result +%= hashAny(self.elem_type, 0);
                result +%= hashAny(self.len, 1);
                return result;
            }

            pub fn eql(self: *const Key, other: *const Key) bool {
                return self.elem_type == other.elem_type and self.len == other.len;
            }
        };

        pub fn destroy(self: *Array, comp: *Compilation) void {
            self.key.elem_type.base.deref(comp);
            comp.gpa().destroy(self);
        }

        pub fn get(comp: *Compilation, key: Key) !*Array {
            key.elem_type.base.ref();
            errdefer key.elem_type.base.deref(comp);

            {
                const held = comp.array_type_table.acquire();
                defer held.release();

                if (held.value.get(&key)) |entry| {
                    entry.value.base.base.ref();
                    return entry.value;
                }
            }

            const self = try comp.gpa().create(Array);
            self.* = Array{
                .base = undefined,
                .key = key,
                .garbage_node = undefined,
            };
            errdefer comp.gpa().destroy(self);

            const name = try std.fmt.allocPrint(comp.gpa(), "[{}]{}", .{ key.len, key.elem_type.name });
            errdefer comp.gpa().free(name);

            self.base.init(comp, .Array, name);

            {
                const held = comp.array_type_table.acquire();
                defer held.release();

                _ = try held.value.put(&self.key, self);
            }
            return self;
        }

        pub fn getLlvmType(self: *Array, allocator: *Allocator, llvm_context: *llvm.Context) !*llvm.Type {
            const elem_llvm_type = try self.key.elem_type.getLlvmType(allocator, llvm_context);
            return llvm.ArrayType(elem_llvm_type, @intCast(c_uint, self.key.len)) orelse return error.OutOfMemory;
        }
    };

    pub const Vector = struct {
        base: Type,

        pub fn destroy(self: *Vector, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Vector, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
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

    pub const EnumLiteral = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(comp: *Compilation) *EnumLiteral {
            comp.comptime_int_type.base.base.ref();
            return comp.comptime_int_type;
        }

        pub fn destroy(self: *EnumLiteral, comp: *Compilation) void {
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

        pub fn getLlvmType(self: *Optional, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const ErrorUnion = struct {
        base: Type,

        pub fn destroy(self: *ErrorUnion, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *ErrorUnion, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const ErrorSet = struct {
        base: Type,

        pub fn destroy(self: *ErrorSet, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *ErrorSet, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const Enum = struct {
        base: Type,

        pub fn destroy(self: *Enum, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Enum, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const Union = struct {
        base: Type,

        pub fn destroy(self: *Union, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Union, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const BoundFn = struct {
        base: Type,

        pub fn destroy(self: *BoundFn, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *BoundFn, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const Opaque = struct {
        base: Type,

        pub fn destroy(self: *Opaque, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Opaque, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const Frame = struct {
        base: Type,

        pub fn destroy(self: *Frame, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *Frame, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };

    pub const AnyFrame = struct {
        base: Type,

        pub fn destroy(self: *AnyFrame, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmType(self: *AnyFrame, allocator: *Allocator, llvm_context: *llvm.Context) *llvm.Type {
            @panic("TODO");
        }
    };
};

fn hashAny(x: var, comptime seed: u64) u32 {
    switch (@typeInfo(@TypeOf(x))) {
        .Int => |info| {
            comptime var rng = comptime std.rand.DefaultPrng.init(seed);
            const unsigned_x = @bitCast(std.meta.IntType(false, info.bits), x);
            if (info.bits <= 32) {
                return @as(u32, unsigned_x) *% comptime rng.random.scalar(u32);
            } else {
                return @truncate(u32, unsigned_x *% comptime rng.random.scalar(@TypeOf(unsigned_x)));
            }
        },
        .Pointer => |info| {
            switch (info.size) {
                .One => return hashAny(@ptrToInt(x), seed),
                .Many => @compileError("implement hash function"),
                .Slice => @compileError("implement hash function"),
                .C => unreachable,
            }
        },
        .Enum => return hashAny(@enumToInt(x), seed),
        .Bool => {
            comptime var rng = comptime std.rand.DefaultPrng.init(seed);
            const vals = comptime [2]u32{ rng.random.scalar(u32), rng.random.scalar(u32) };
            return vals[@boolToInt(x)];
        },
        .Optional => {
            if (x) |non_opt| {
                return hashAny(non_opt, seed);
            } else {
                return hashAny(@as(u32, 1), seed);
            }
        },
        else => @compileError("implement hash function for " ++ @typeName(@TypeOf(x))),
    }
}
