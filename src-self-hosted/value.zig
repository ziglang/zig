const std = @import("std");
const Scope = @import("scope.zig").Scope;
const Compilation = @import("compilation.zig").Compilation;
const ObjectFile = @import("codegen.zig").ObjectFile;
const llvm = @import("llvm.zig");
const Buffer = std.Buffer;
const assert = std.debug.assert;

/// Values are ref-counted, heap-allocated, and copy-on-write
/// If there is only 1 ref then write need not copy
pub const Value = struct {
    id: Id,
    typ: *Type,
    ref_count: std.atomic.Int(usize),

    /// Thread-safe
    pub fn ref(base: *Value) void {
        _ = base.ref_count.incr();
    }

    /// Thread-safe
    pub fn deref(base: *Value, comp: *Compilation) void {
        if (base.ref_count.decr() == 1) {
            base.typ.base.deref(comp);
            switch (base.id) {
                .Type => @fieldParentPtr(Type, "base", base).destroy(comp),
                .Fn => @fieldParentPtr(Fn, "base", base).destroy(comp),
                .FnProto => @fieldParentPtr(FnProto, "base", base).destroy(comp),
                .Void => @fieldParentPtr(Void, "base", base).destroy(comp),
                .Bool => @fieldParentPtr(Bool, "base", base).destroy(comp),
                .NoReturn => @fieldParentPtr(NoReturn, "base", base).destroy(comp),
                .Ptr => @fieldParentPtr(Ptr, "base", base).destroy(comp),
                .Int => @fieldParentPtr(Int, "base", base).destroy(comp),
                .Array => @fieldParentPtr(Array, "base", base).destroy(comp),
            }
        }
    }

    pub fn setType(base: *Value, new_type: *Type, comp: *Compilation) void {
        base.typ.base.deref(comp);
        new_type.base.ref();
        base.typ = new_type;
    }

    pub fn getRef(base: *Value) *Value {
        base.ref();
        return base;
    }

    pub fn cast(base: *Value, comptime T: type) ?*T {
        if (base.id != @field(Id, @typeName(T))) return null;
        return @fieldParentPtr(T, "base", base);
    }

    pub fn dump(base: *const Value) void {
        std.debug.warn("{}", .{@tagName(base.id)});
    }

    pub fn getLlvmConst(base: *Value, ofile: *ObjectFile) (error{OutOfMemory}!?*llvm.Value) {
        switch (base.id) {
            .Type => unreachable,
            .Fn => return @fieldParentPtr(Fn, "base", base).getLlvmConst(ofile),
            .FnProto => return @fieldParentPtr(FnProto, "base", base).getLlvmConst(ofile),
            .Void => return null,
            .Bool => return @fieldParentPtr(Bool, "base", base).getLlvmConst(ofile),
            .NoReturn => unreachable,
            .Ptr => return @fieldParentPtr(Ptr, "base", base).getLlvmConst(ofile),
            .Int => return @fieldParentPtr(Int, "base", base).getLlvmConst(ofile),
            .Array => return @fieldParentPtr(Array, "base", base).getLlvmConst(ofile),
        }
    }

    pub fn derefAndCopy(self: *Value, comp: *Compilation) (error{OutOfMemory}!*Value) {
        if (self.ref_count.get() == 1) {
            // ( ͡° ͜ʖ ͡°)
            return self;
        }

        assert(self.ref_count.decr() != 1);
        return self.copy(comp);
    }

    pub fn copy(base: *Value, comp: *Compilation) (error{OutOfMemory}!*Value) {
        switch (base.id) {
            .Type => unreachable,
            .Fn => unreachable,
            .FnProto => unreachable,
            .Void => unreachable,
            .Bool => unreachable,
            .NoReturn => unreachable,
            .Ptr => unreachable,
            .Array => unreachable,
            .Int => return &(try @fieldParentPtr(Int, "base", base).copy(comp)).base,
        }
    }

    pub const Parent = union(enum) {
        None,
        BaseStruct: BaseStruct,
        BaseArray: BaseArray,
        BaseUnion: *Value,
        BaseScalar: *Value,

        pub const BaseStruct = struct {
            val: *Value,
            field_index: usize,
        };

        pub const BaseArray = struct {
            val: *Value,
            elem_index: usize,
        };
    };

    pub const Id = enum {
        Type,
        Fn,
        Void,
        Bool,
        NoReturn,
        Array,
        Ptr,
        Int,
        FnProto,
    };

    pub const Type = @import("type.zig").Type;

    pub const FnProto = struct {
        base: Value,

        /// The main external name that is used in the .o file.
        /// TODO https://github.com/ziglang/zig/issues/265
        symbol_name: Buffer,

        pub fn create(comp: *Compilation, fn_type: *Type.Fn, symbol_name: Buffer) !*FnProto {
            const self = try comp.gpa().create(FnProto);
            self.* = FnProto{
                .base = Value{
                    .id = .FnProto,
                    .typ = &fn_type.base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .symbol_name = symbol_name,
            };
            fn_type.base.base.ref();
            return self;
        }

        pub fn destroy(self: *FnProto, comp: *Compilation) void {
            self.symbol_name.deinit();
            comp.gpa().destroy(self);
        }

        pub fn getLlvmConst(self: *FnProto, ofile: *ObjectFile) !?*llvm.Value {
            const llvm_fn_type = try self.base.typ.getLlvmType(ofile.arena, ofile.context);
            const llvm_fn = llvm.AddFunction(
                ofile.module,
                self.symbol_name.toSliceConst(),
                llvm_fn_type,
            ) orelse return error.OutOfMemory;

            // TODO port more logic from codegen.cpp:fn_llvm_value

            return llvm_fn;
        }
    };

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
        block_scope: ?*Scope.Block,

        /// Path to the object file that contains this function
        containing_object: Buffer,

        link_set_node: *std.TailQueue(?*Value.Fn).Node,

        /// Creates a Fn value with 1 ref
        /// Takes ownership of symbol_name
        pub fn create(comp: *Compilation, fn_type: *Type.Fn, fndef_scope: *Scope.FnDef, symbol_name: Buffer) !*Fn {
            const link_set_node = try comp.gpa().create(Compilation.FnLinkSet.Node);
            link_set_node.* = Compilation.FnLinkSet.Node{
                .data = null,
                .next = undefined,
                .prev = undefined,
            };
            errdefer comp.gpa().destroy(link_set_node);

            const self = try comp.gpa().create(Fn);
            self.* = Fn{
                .base = Value{
                    .id = .Fn,
                    .typ = &fn_type.base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .fndef_scope = fndef_scope,
                .child_scope = &fndef_scope.base,
                .block_scope = null,
                .symbol_name = symbol_name,
                .containing_object = Buffer.initNull(comp.gpa()),
                .link_set_node = link_set_node,
            };
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

        /// We know that the function definition will end up in an .o file somewhere.
        /// Here, all we have to do is generate a global prototype.
        /// TODO cache the prototype per ObjectFile
        pub fn getLlvmConst(self: *Fn, ofile: *ObjectFile) !?*llvm.Value {
            const llvm_fn_type = try self.base.typ.getLlvmType(ofile.arena, ofile.context);
            const llvm_fn = llvm.AddFunction(
                ofile.module,
                self.symbol_name.toSliceConst(),
                llvm_fn_type,
            ) orelse return error.OutOfMemory;

            // TODO port more logic from codegen.cpp:fn_llvm_value

            return llvm_fn;
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

        pub fn getLlvmConst(self: *Bool, ofile: *ObjectFile) !?*llvm.Value {
            const llvm_type = llvm.Int1TypeInContext(ofile.context) orelse return error.OutOfMemory;
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
        special: Special,
        mut: Mut,

        pub const Mut = enum {
            CompTimeConst,
            CompTimeVar,
            RunTime,
        };

        pub const Special = union(enum) {
            Scalar: *Value,
            BaseArray: BaseArray,
            BaseStruct: BaseStruct,
            HardCodedAddr: u64,
            Discard,
        };

        pub const BaseArray = struct {
            val: *Value,
            elem_index: usize,
        };

        pub const BaseStruct = struct {
            val: *Value,
            field_index: usize,
        };

        pub fn createArrayElemPtr(
            comp: *Compilation,
            array_val: *Array,
            mut: Type.Pointer.Mut,
            size: Type.Pointer.Size,
            elem_index: usize,
        ) !*Ptr {
            array_val.base.ref();
            errdefer array_val.base.deref(comp);

            const elem_type = array_val.base.typ.cast(Type.Array).?.key.elem_type;
            const ptr_type = try Type.Pointer.get(comp, Type.Pointer.Key{
                .child_type = elem_type,
                .mut = mut,
                .vol = Type.Pointer.Vol.Non,
                .size = size,
                .alignment = .Abi,
            });
            var ptr_type_consumed = false;
            errdefer if (!ptr_type_consumed) ptr_type.base.base.deref(comp);

            const self = try comp.gpa().create(Value.Ptr);
            self.* = Value.Ptr{
                .base = Value{
                    .id = .Ptr,
                    .typ = &ptr_type.base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .special = Special{
                    .BaseArray = BaseArray{
                        .val = &array_val.base,
                        .elem_index = 0,
                    },
                },
                .mut = Mut.CompTimeConst,
            };
            ptr_type_consumed = true;
            errdefer comp.gpa().destroy(self);

            return self;
        }

        pub fn destroy(self: *Ptr, comp: *Compilation) void {
            comp.gpa().destroy(self);
        }

        pub fn getLlvmConst(self: *Ptr, ofile: *ObjectFile) !?*llvm.Value {
            const llvm_type = self.base.typ.getLlvmType(ofile.arena, ofile.context);
            // TODO carefully port the logic from codegen.cpp:gen_const_val_ptr
            switch (self.special) {
                .Scalar => |scalar| @panic("TODO"),
                .BaseArray => |base_array| {
                    // TODO put this in one .o file only, and after that, generate extern references to it
                    const array_llvm_value = (try base_array.val.getLlvmConst(ofile)).?;
                    const ptr_bit_count = ofile.comp.target_ptr_bits;
                    const usize_llvm_type = llvm.IntTypeInContext(ofile.context, ptr_bit_count) orelse return error.OutOfMemory;
                    var indices = [_]*llvm.Value{
                        llvm.ConstNull(usize_llvm_type) orelse return error.OutOfMemory,
                        llvm.ConstInt(usize_llvm_type, base_array.elem_index, 0) orelse return error.OutOfMemory,
                    };
                    return llvm.ConstInBoundsGEP(
                        array_llvm_value,
                        @ptrCast([*]*llvm.Value, &indices),
                        @intCast(c_uint, indices.len),
                    ) orelse return error.OutOfMemory;
                },
                .BaseStruct => |base_struct| @panic("TODO"),
                .HardCodedAddr => |addr| @panic("TODO"),
                .Discard => unreachable,
            }
        }
    };

    pub const Array = struct {
        base: Value,
        special: Special,

        pub const Special = union(enum) {
            Undefined,
            OwnedBuffer: []u8,
            Explicit: Data,
        };

        pub const Data = struct {
            parent: Parent,
            elements: []*Value,
        };

        /// Takes ownership of buffer
        pub fn createOwnedBuffer(comp: *Compilation, buffer: []u8) !*Array {
            const u8_type = Type.Int.get_u8(comp);
            defer u8_type.base.base.deref(comp);

            const array_type = try Type.Array.get(comp, Type.Array.Key{
                .elem_type = &u8_type.base,
                .len = buffer.len,
            });
            errdefer array_type.base.base.deref(comp);

            const self = try comp.gpa().create(Value.Array);
            self.* = Value.Array{
                .base = Value{
                    .id = .Array,
                    .typ = &array_type.base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .special = Special{ .OwnedBuffer = buffer },
            };
            errdefer comp.gpa().destroy(self);

            return self;
        }

        pub fn destroy(self: *Array, comp: *Compilation) void {
            switch (self.special) {
                .Undefined => {},
                .OwnedBuffer => |buf| {
                    comp.gpa().free(buf);
                },
                .Explicit => {},
            }
            comp.gpa().destroy(self);
        }

        pub fn getLlvmConst(self: *Array, ofile: *ObjectFile) !?*llvm.Value {
            switch (self.special) {
                .Undefined => {
                    const llvm_type = try self.base.typ.getLlvmType(ofile.arena, ofile.context);
                    return llvm.GetUndef(llvm_type);
                },
                .OwnedBuffer => |buf| {
                    const dont_null_terminate = 1;
                    const llvm_str_init = llvm.ConstStringInContext(
                        ofile.context,
                        buf.ptr,
                        @intCast(c_uint, buf.len),
                        dont_null_terminate,
                    ) orelse return error.OutOfMemory;
                    const str_init_type = llvm.TypeOf(llvm_str_init);
                    const global = llvm.AddGlobal(ofile.module, str_init_type, "") orelse return error.OutOfMemory;
                    llvm.SetInitializer(global, llvm_str_init);
                    llvm.SetLinkage(global, llvm.PrivateLinkage);
                    llvm.SetGlobalConstant(global, 1);
                    llvm.SetUnnamedAddr(global, 1);
                    llvm.SetAlignment(global, llvm.ABIAlignmentOfType(ofile.comp.target_data_ref, str_init_type));
                    return global;
                },
                .Explicit => @panic("TODO"),
            }

            //{
            //    uint64_t len = type_entry->data.array.len;
            //    if (const_val->data.x_array.special == ConstArraySpecialUndef) {
            //        return LLVMGetUndef(type_entry->type_ref);
            //    }

            //    LLVMValueRef *values = allocate<LLVMValueRef>(len);
            //    LLVMTypeRef element_type_ref = type_entry->data.array.child_type->type_ref;
            //    bool make_unnamed_struct = false;
            //    for (uint64_t i = 0; i < len; i += 1) {
            //        ConstExprValue *elem_value = &const_val->data.x_array.s_none.elements[i];
            //        LLVMValueRef val = gen_const_val(g, elem_value, "");
            //        values[i] = val;
            //        make_unnamed_struct = make_unnamed_struct || is_llvm_value_unnamed_type(elem_value->type, val);
            //    }
            //    if (make_unnamed_struct) {
            //        return LLVMConstStruct(values, len, true);
            //    } else {
            //        return LLVMConstArray(element_type_ref, values, (unsigned)len);
            //    }
            //}
        }
    };

    pub const Int = struct {
        base: Value,
        big_int: std.math.big.Int,

        pub fn createFromString(comp: *Compilation, typ: *Type, base: u8, value: []const u8) !*Int {
            const self = try comp.gpa().create(Value.Int);
            self.* = Value.Int{
                .base = Value{
                    .id = .Int,
                    .typ = typ,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .big_int = undefined,
            };
            typ.base.ref();
            errdefer comp.gpa().destroy(self);

            self.big_int = try std.math.big.Int.init(comp.gpa());
            errdefer self.big_int.deinit();

            try self.big_int.setString(base, value);

            return self;
        }

        pub fn getLlvmConst(self: *Int, ofile: *ObjectFile) !?*llvm.Value {
            switch (self.base.typ.id) {
                .Int => {
                    const type_ref = try self.base.typ.getLlvmType(ofile.arena, ofile.context);
                    if (self.big_int.len() == 0) {
                        return llvm.ConstNull(type_ref);
                    }
                    const unsigned_val = if (self.big_int.len() == 1) blk: {
                        break :blk llvm.ConstInt(type_ref, self.big_int.limbs[0], @boolToInt(false));
                    } else if (@sizeOf(std.math.big.Limb) == @sizeOf(u64)) blk: {
                        break :blk llvm.ConstIntOfArbitraryPrecision(
                            type_ref,
                            @intCast(c_uint, self.big_int.len()),
                            @ptrCast([*]u64, self.big_int.limbs.ptr),
                        );
                    } else {
                        @compileError("std.math.Big.Int.Limb size does not match LLVM");
                    };
                    return if (self.big_int.isPositive()) unsigned_val else llvm.ConstNeg(unsigned_val);
                },
                .ComptimeInt => unreachable,
                else => unreachable,
            }
        }

        pub fn copy(old: *Int, comp: *Compilation) !*Int {
            old.base.typ.base.ref();
            errdefer old.base.typ.base.deref(comp);

            const new = try comp.gpa().create(Value.Int);
            new.* = Value.Int{
                .base = Value{
                    .id = .Int,
                    .typ = old.base.typ,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .big_int = undefined,
            };
            errdefer comp.gpa().destroy(new);

            new.big_int = try old.big_int.clone();
            errdefer new.big_int.deinit();

            return new;
        }

        pub fn destroy(self: *Int, comp: *Compilation) void {
            self.big_int.deinit();
            comp.gpa().destroy(self);
        }
    };
};
