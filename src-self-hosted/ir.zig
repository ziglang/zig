const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const assert = std.debug.assert;
const text = @import("ir/text.zig");
const BigInt = std.math.big.Int;
const Target = std.Target;

/// These are in-memory, analyzed instructions. See `text.Inst` for the representation
/// of instructions that correspond to the ZIR text format.
/// This struct owns the `Value` and `Type` memory. When the struct is deallocated,
/// so are the `Value` and `Type`. The value of a constant must be copied into
/// a memory location for the value to survive after a const instruction.
pub const Inst = struct {
    tag: Tag,
    ty: Type,
    /// Byte offset into the source.
    src: usize,

    pub const Tag = enum {
        unreach,
        constant,
        assembly,
        ptrtoint,
        bitcast,
    };

    pub fn cast(base: *Inst, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub fn Args(comptime T: type) type {
        return std.meta.fieldInfo(T, "args").field_type;
    }

    /// Returns `null` if runtime-known.
    pub fn value(base: *Inst) ?Value {
        return switch (base.tag) {
            .unreach => Value.initTag(.noreturn_value),
            .constant => base.cast(Constant).?.val,

            .assembly,
            .ptrtoint,
            .bitcast,
            => null,
        };
    }

    pub const Unreach = struct {
        pub const base_tag = Tag.unreach;
        base: Inst,
        args: void,
    };

    pub const Constant = struct {
        pub const base_tag = Tag.constant;
        base: Inst,

        val: Value,
    };

    pub const Assembly = struct {
        pub const base_tag = Tag.assembly;
        base: Inst,

        args: struct {
            asm_source: []const u8,
            is_volatile: bool,
            output: ?[]const u8,
            inputs: []const []const u8,
            clobbers: []const []const u8,
            args: []const *Inst,
        },
    };

    pub const PtrToInt = struct {
        pub const base_tag = Tag.ptrtoint;

        base: Inst,
        args: struct {
            ptr: *Inst,
        },
    };

    pub const BitCast = struct {
        pub const base_tag = Tag.bitcast;

        base: Inst,
        args: struct {
            operand: *Inst,
        },
    };
};

pub const TypedValue = struct {
    ty: Type,
    val: Value,
};

pub const Module = struct {
    exports: []Export,
    errors: []ErrorMsg,
    arena: std.heap.ArenaAllocator,
    fns: []Fn,
    target: Target,

    pub const Export = struct {
        name: []const u8,
        typed_value: TypedValue,
        src: usize,
    };

    pub const Fn = struct {
        analysis_status: enum { in_progress, failure, success },
        body: []*Inst,
        fn_type: Type,
    };

    pub fn deinit(self: *Module, allocator: *Allocator) void {
        allocator.free(self.exports);
        allocator.free(self.errors);
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub fn analyze(allocator: *Allocator, old_module: text.Module, target: Target) !Module {
    var ctx = Analyze{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .old_module = &old_module,
        .errors = std.ArrayList(ErrorMsg).init(allocator),
        .decl_table = std.AutoHashMap(*text.Inst, Analyze.NewDecl).init(allocator),
        .exports = std.ArrayList(Module.Export).init(allocator),
        .fns = std.ArrayList(Module.Fn).init(allocator),
        .target = target,
    };
    defer ctx.errors.deinit();
    defer ctx.decl_table.deinit();
    defer ctx.exports.deinit();
    defer ctx.fns.deinit();
    errdefer ctx.arena.deinit();

    ctx.analyzeRoot() catch |err| switch (err) {
        error.AnalysisFail => {
            assert(ctx.errors.items.len != 0);
        },
        else => |e| return e,
    };
    return Module{
        .exports = ctx.exports.toOwnedSlice(),
        .errors = ctx.errors.toOwnedSlice(),
        .fns = ctx.fns.toOwnedSlice(),
        .arena = ctx.arena,
        .target = target,
    };
}

const Analyze = struct {
    allocator: *Allocator,
    arena: std.heap.ArenaAllocator,
    old_module: *const text.Module,
    errors: std.ArrayList(ErrorMsg),
    decl_table: std.AutoHashMap(*text.Inst, NewDecl),
    exports: std.ArrayList(Module.Export),
    fns: std.ArrayList(Module.Fn),
    target: Target,

    const NewDecl = struct {
        /// null means a semantic analysis error happened
        ptr: ?*Inst,
    };

    const NewInst = struct {
        /// null means a semantic analysis error happened
        ptr: ?*Inst,
    };

    const Fn = struct {
        body: std.ArrayList(*Inst),
        inst_table: std.AutoHashMap(*text.Inst, NewInst),
        /// Index into Module fns array
        fn_index: usize,
    };

    const InnerError = error{ OutOfMemory, AnalysisFail };

    fn analyzeRoot(self: *Analyze) !void {
        for (self.old_module.decls) |decl| {
            if (decl.cast(text.Inst.Export)) |export_inst| {
                try analyzeExport(self, null, export_inst);
            }
        }
    }

    fn resolveInst(self: *Analyze, opt_func: ?*Fn, old_inst: *text.Inst) InnerError!*Inst {
        if (opt_func) |func| {
            if (func.inst_table.get(old_inst)) |kv| {
                return kv.value.ptr orelse return error.AnalysisFail;
            }
        }

        if (self.decl_table.get(old_inst)) |kv| {
            return kv.value.ptr orelse return error.AnalysisFail;
        } else {
            const new_inst = self.analyzeInst(null, old_inst) catch |err| switch (err) {
                error.AnalysisFail => {
                    try self.decl_table.putNoClobber(old_inst, .{ .ptr = null });
                    return error.AnalysisFail;
                },
                else => |e| return e,
            };
            try self.decl_table.putNoClobber(old_inst, .{ .ptr = new_inst });
            return new_inst;
        }
    }

    fn requireFunctionBody(self: *Analyze, func: ?*Fn, src: usize) !*Fn {
        return func orelse return self.fail(src, "instruction illegal outside function body", .{});
    }

    fn resolveInstConst(self: *Analyze, func: ?*Fn, old_inst: *text.Inst) InnerError!TypedValue {
        const new_inst = try self.resolveInst(func, old_inst);
        const val = try self.resolveConstValue(new_inst);
        return TypedValue{
            .ty = new_inst.ty,
            .val = val,
        };
    }

    fn resolveConstValue(self: *Analyze, base: *Inst) !Value {
        return base.value() orelse return self.fail(base.src, "unable to resolve comptime value", .{});
    }

    fn resolveConstString(self: *Analyze, func: ?*Fn, old_inst: *text.Inst) ![]u8 {
        const new_inst = try self.resolveInst(func, old_inst);
        const wanted_type = Type.initTag(.const_slice_u8);
        const coerced_inst = try self.coerce(func, wanted_type, new_inst);
        const val = try self.resolveConstValue(coerced_inst);
        return val.toAllocatedBytes(&self.arena.allocator);
    }

    fn resolveType(self: *Analyze, func: ?*Fn, old_inst: *text.Inst) !Type {
        const new_inst = try self.resolveInst(func, old_inst);
        const wanted_type = Type.initTag(.@"type");
        const coerced_inst = try self.coerce(func, wanted_type, new_inst);
        const val = try self.resolveConstValue(coerced_inst);
        return val.toType();
    }

    fn analyzeExport(self: *Analyze, func: ?*Fn, export_inst: *text.Inst.Export) !void {
        const symbol_name = try self.resolveConstString(func, export_inst.positionals.symbol_name);
        const typed_value = try self.resolveInstConst(func, export_inst.positionals.value);

        switch (typed_value.ty.zigTypeTag()) {
            .Fn => {},
            else => return self.fail(
                export_inst.positionals.value.src,
                "unable to export type '{}'",
                .{typed_value.ty},
            ),
        }
        try self.exports.append(.{
            .name = symbol_name,
            .typed_value = typed_value,
            .src = export_inst.base.src,
        });
    }

    /// TODO should not need the cast on the last parameter at the callsites
    fn addNewInstArgs(
        self: *Analyze,
        func: *Fn,
        src: usize,
        ty: Type,
        comptime T: type,
        args: Inst.Args(T),
    ) !*Inst {
        const inst = try self.addNewInst(func, src, ty, T);
        inst.args = args;
        return &inst.base;
    }

    fn addNewInst(self: *Analyze, func: *Fn, src: usize, ty: Type, comptime T: type) !*T {
        const inst = try self.arena.allocator.create(T);
        inst.* = .{
            .base = .{
                .tag = T.base_tag,
                .ty = ty,
                .src = src,
            },
            .args = undefined,
        };
        try func.body.append(&inst.base);
        return inst;
    }

    fn constInst(self: *Analyze, src: usize, typed_value: TypedValue) !*Inst {
        const const_inst = try self.arena.allocator.create(Inst.Constant);
        const_inst.* = .{
            .base = .{
                .tag = Inst.Constant.base_tag,
                .ty = typed_value.ty,
                .src = src,
            },
            .val = typed_value.val,
        };
        return &const_inst.base;
    }

    fn constStr(self: *Analyze, src: usize, str: []const u8) !*Inst {
        const array_payload = try self.arena.allocator.create(Type.Payload.Array_u8_Sentinel0);
        array_payload.* = .{ .len = str.len };

        const ty_payload = try self.arena.allocator.create(Type.Payload.SingleConstPointer);
        ty_payload.* = .{ .pointee_type = Type.initPayload(&array_payload.base) };

        const bytes_payload = try self.arena.allocator.create(Value.Payload.Bytes);
        bytes_payload.* = .{ .data = str };

        return self.constInst(src, .{
            .ty = Type.initPayload(&ty_payload.base),
            .val = Value.initPayload(&bytes_payload.base),
        });
    }

    fn constType(self: *Analyze, src: usize, ty: Type) !*Inst {
        return self.constInst(src, .{
            .ty = Type.initTag(.type),
            .val = try ty.toValue(&self.arena.allocator),
        });
    }

    fn constVoid(self: *Analyze, src: usize) !*Inst {
        return self.constInst(src, .{
            .ty = Type.initTag(.void),
            .val = Value.initTag(.void_value),
        });
    }

    fn constIntUnsigned(self: *Analyze, src: usize, ty: Type, int: u64) !*Inst {
        const int_payload = try self.arena.allocator.create(Value.Payload.Int_u64);
        int_payload.* = .{ .int = int };

        return self.constInst(src, .{
            .ty = ty,
            .val = Value.initPayload(&int_payload.base),
        });
    }

    fn constIntSigned(self: *Analyze, src: usize, ty: Type, int: i64) !*Inst {
        const int_payload = try self.arena.allocator.create(Value.Payload.Int_i64);
        int_payload.* = .{ .int = int };

        return self.constInst(src, .{
            .ty = ty,
            .val = Value.initPayload(&int_payload.base),
        });
    }

    fn constIntBig(self: *Analyze, src: usize, ty: Type, big_int: BigInt) !*Inst {
        if (big_int.isPositive()) {
            if (big_int.to(u64)) |x| {
                return self.constIntUnsigned(src, ty, x);
            } else |err| switch (err) {
                error.NegativeIntoUnsigned => unreachable,
                error.TargetTooSmall => {}, // handled below
            }
        } else {
            if (big_int.to(i64)) |x| {
                return self.constIntSigned(src, ty, x);
            } else |err| switch (err) {
                error.NegativeIntoUnsigned => unreachable,
                error.TargetTooSmall => {}, // handled below
            }
        }

        const big_int_payload = try self.arena.allocator.create(Value.Payload.IntBig);
        big_int_payload.* = .{ .big_int = big_int };

        return self.constInst(src, .{
            .ty = ty,
            .val = Value.initPayload(&big_int_payload.base),
        });
    }

    fn analyzeInst(self: *Analyze, func: ?*Fn, old_inst: *text.Inst) InnerError!*Inst {
        switch (old_inst.tag) {
            .str => {
                // We can use this reference because Inst.Const's Value is arena-allocated.
                // The value would get copied to a MemoryCell before the `text.Inst.Str` lifetime ends.
                const bytes = old_inst.cast(text.Inst.Str).?.positionals.bytes;
                return self.constStr(old_inst.src, bytes);
            },
            .int => {
                const big_int = old_inst.cast(text.Inst.Int).?.positionals.int;
                return self.constIntBig(old_inst.src, Type.initTag(.comptime_int), big_int);
            },
            .ptrtoint => return self.analyzeInstPtrToInt(func, old_inst.cast(text.Inst.PtrToInt).?),
            .fieldptr => return self.analyzeInstFieldPtr(func, old_inst.cast(text.Inst.FieldPtr).?),
            .deref => return self.analyzeInstDeref(func, old_inst.cast(text.Inst.Deref).?),
            .as => return self.analyzeInstAs(func, old_inst.cast(text.Inst.As).?),
            .@"asm" => return self.analyzeInstAsm(func, old_inst.cast(text.Inst.Asm).?),
            .@"unreachable" => return self.analyzeInstUnreachable(func, old_inst.cast(text.Inst.Unreachable).?),
            .@"fn" => return self.analyzeInstFn(func, old_inst.cast(text.Inst.Fn).?),
            .@"export" => {
                try self.analyzeExport(func, old_inst.cast(text.Inst.Export).?);
                return self.constVoid(old_inst.src);
            },
            .primitive => return self.analyzeInstPrimitive(func, old_inst.cast(text.Inst.Primitive).?),
            .fntype => return self.analyzeInstFnType(func, old_inst.cast(text.Inst.FnType).?),
            .intcast => return self.analyzeInstIntCast(func, old_inst.cast(text.Inst.IntCast).?),
            .bitcast => return self.analyzeInstBitCast(func, old_inst.cast(text.Inst.BitCast).?),
            .elemptr => return self.analyzeInstElemPtr(func, old_inst.cast(text.Inst.ElemPtr).?),
            .add => return self.analyzeInstAdd(func, old_inst.cast(text.Inst.Add).?),
        }
    }

    fn analyzeInstFn(self: *Analyze, opt_func: ?*Fn, fn_inst: *text.Inst.Fn) InnerError!*Inst {
        const fn_type = try self.resolveType(opt_func, fn_inst.positionals.fn_type);

        var new_func: Fn = .{
            .body = std.ArrayList(*Inst).init(self.allocator),
            .inst_table = std.AutoHashMap(*text.Inst, NewInst).init(self.allocator),
            .fn_index = self.fns.items.len,
        };
        defer new_func.body.deinit();
        defer new_func.inst_table.deinit();
        // Don't hang on to a reference to this when analyzing body instructions, since the memory
        // could become invalid.
        (try self.fns.addOne()).* = .{
            .analysis_status = .in_progress,
            .fn_type = fn_type,
            .body = undefined,
        };

        for (fn_inst.positionals.body.instructions) |src_inst| {
            const new_inst = self.analyzeInst(&new_func, src_inst) catch |err| {
                self.fns.items[new_func.fn_index].analysis_status = .failure;
                try new_func.inst_table.putNoClobber(src_inst, .{ .ptr = null });
                return err;
            };
            try new_func.inst_table.putNoClobber(src_inst, .{ .ptr = new_inst });
        }

        const f = &self.fns.items[new_func.fn_index];
        f.analysis_status = .success;
        f.body = new_func.body.toOwnedSlice();

        const fn_payload = try self.arena.allocator.create(Value.Payload.Function);
        fn_payload.* = .{ .index = new_func.fn_index };

        return self.constInst(fn_inst.base.src, .{
            .ty = fn_type,
            .val = Value.initPayload(&fn_payload.base),
        });
    }

    fn analyzeInstFnType(self: *Analyze, func: ?*Fn, fntype: *text.Inst.FnType) InnerError!*Inst {
        const return_type = try self.resolveType(func, fntype.positionals.return_type);

        if (return_type.zigTypeTag() == .NoReturn and
            fntype.positionals.param_types.len == 0 and
            fntype.kw_args.cc == .Naked)
        {
            return self.constType(fntype.base.src, Type.initTag(.fn_naked_noreturn_no_args));
        }

        return self.fail(fntype.base.src, "TODO implement fntype instruction more", .{});
    }

    fn analyzeInstPrimitive(self: *Analyze, func: ?*Fn, primitive: *text.Inst.Primitive) InnerError!*Inst {
        return self.constType(primitive.base.src, primitive.positionals.tag.toType());
    }

    fn analyzeInstAs(self: *Analyze, func: ?*Fn, as: *text.Inst.As) InnerError!*Inst {
        const dest_type = try self.resolveType(func, as.positionals.dest_type);
        const new_inst = try self.resolveInst(func, as.positionals.value);
        return self.coerce(func, dest_type, new_inst);
    }

    fn analyzeInstPtrToInt(self: *Analyze, func: ?*Fn, ptrtoint: *text.Inst.PtrToInt) InnerError!*Inst {
        const ptr = try self.resolveInst(func, ptrtoint.positionals.ptr);
        if (ptr.ty.zigTypeTag() != .Pointer) {
            return self.fail(ptrtoint.positionals.ptr.src, "expected pointer, found '{}'", .{ptr.ty});
        }
        // TODO handle known-pointer-address
        const f = try self.requireFunctionBody(func, ptrtoint.base.src);
        const ty = Type.initTag(.usize);
        return self.addNewInstArgs(f, ptrtoint.base.src, ty, Inst.PtrToInt, Inst.Args(Inst.PtrToInt){ .ptr = ptr });
    }

    fn analyzeInstFieldPtr(self: *Analyze, func: ?*Fn, fieldptr: *text.Inst.FieldPtr) InnerError!*Inst {
        const object_ptr = try self.resolveInst(func, fieldptr.positionals.object_ptr);
        const field_name = try self.resolveConstString(func, fieldptr.positionals.field_name);

        const elem_ty = switch (object_ptr.ty.zigTypeTag()) {
            .Pointer => object_ptr.ty.elemType(),
            else => return self.fail(fieldptr.positionals.object_ptr.src, "expected pointer, found '{}'", .{object_ptr.ty}),
        };
        switch (elem_ty.zigTypeTag()) {
            .Array => {
                if (mem.eql(u8, field_name, "len")) {
                    const len_payload = try self.arena.allocator.create(Value.Payload.Int_u64);
                    len_payload.* = .{ .int = elem_ty.arrayLen() };

                    const ref_payload = try self.arena.allocator.create(Value.Payload.RefVal);
                    ref_payload.* = .{ .val = Value.initPayload(&len_payload.base) };

                    return self.constInst(fieldptr.base.src, .{
                        .ty = Type.initTag(.single_const_pointer_to_comptime_int),
                        .val = Value.initPayload(&ref_payload.base),
                    });
                } else {
                    return self.fail(
                        fieldptr.positionals.field_name.src,
                        "no member named '{}' in '{}'",
                        .{ field_name, elem_ty },
                    );
                }
            },
            else => return self.fail(fieldptr.base.src, "type '{}' does not support field access", .{elem_ty}),
        }
    }

    fn analyzeInstIntCast(self: *Analyze, func: ?*Fn, intcast: *text.Inst.IntCast) InnerError!*Inst {
        const dest_type = try self.resolveType(func, intcast.positionals.dest_type);
        const new_inst = try self.resolveInst(func, intcast.positionals.value);

        const dest_is_comptime_int = switch (dest_type.zigTypeTag()) {
            .ComptimeInt => true,
            .Int => false,
            else => return self.fail(
                intcast.positionals.dest_type.src,
                "expected integer type, found '{}'",
                .{
                    dest_type,
                },
            ),
        };

        switch (new_inst.ty.zigTypeTag()) {
            .ComptimeInt, .Int => {},
            else => return self.fail(
                intcast.positionals.value.src,
                "expected integer type, found '{}'",
                .{new_inst.ty},
            ),
        }

        if (dest_is_comptime_int or new_inst.value() != null) {
            return self.coerce(func, dest_type, new_inst);
        }

        return self.fail(intcast.base.src, "TODO implement analyze widen or shorten int", .{});
    }

    fn analyzeInstBitCast(self: *Analyze, func: ?*Fn, inst: *text.Inst.BitCast) InnerError!*Inst {
        const dest_type = try self.resolveType(func, inst.positionals.dest_type);
        const operand = try self.resolveInst(func, inst.positionals.operand);
        return self.bitcast(func, dest_type, operand);
    }

    fn analyzeInstElemPtr(self: *Analyze, func: ?*Fn, inst: *text.Inst.ElemPtr) InnerError!*Inst {
        const array_ptr = try self.resolveInst(func, inst.positionals.array_ptr);
        const uncasted_index = try self.resolveInst(func, inst.positionals.index);
        const elem_index = try self.coerce(func, Type.initTag(.usize), uncasted_index);

        if (array_ptr.ty.isSinglePointer() and array_ptr.ty.elemType().zigTypeTag() == .Array) {
            if (array_ptr.value()) |array_ptr_val| {
                if (elem_index.value()) |index_val| {
                    // Both array pointer and index are compile-time known.
                    const index_u64 = index_val.toUnsignedInt();
                    // @intCast here because it would have been impossible to construct a value that
                    // required a larger index.
                    const elem_val = try array_ptr_val.elemValueAt(&self.arena.allocator, @intCast(usize, index_u64));

                    const ref_payload = try self.arena.allocator.create(Value.Payload.RefVal);
                    ref_payload.* = .{ .val = elem_val };

                    const type_payload = try self.arena.allocator.create(Type.Payload.SingleConstPointer);
                    type_payload.* = .{ .pointee_type = array_ptr.ty.elemType().elemType() };

                    return self.constInst(inst.base.src, .{
                        .ty = Type.initPayload(&type_payload.base),
                        .val = Value.initPayload(&ref_payload.base),
                    });
                }
            }
        }

        return self.fail(inst.base.src, "TODO implement more analyze elemptr", .{});
    }

    fn analyzeInstAdd(self: *Analyze, func: ?*Fn, inst: *text.Inst.Add) InnerError!*Inst {
        const lhs = try self.resolveInst(func, inst.positionals.lhs);
        const rhs = try self.resolveInst(func, inst.positionals.rhs);

        if (lhs.ty.zigTypeTag() == .Int and rhs.ty.zigTypeTag() == .Int) {
            if (lhs.value()) |lhs_val| {
                if (rhs.value()) |rhs_val| {
                    const lhs_bigint = try lhs_val.toBigInt(&self.arena.allocator);
                    const rhs_bigint = try rhs_val.toBigInt(&self.arena.allocator);
                    var result_bigint = try BigInt.init(&self.arena.allocator);
                    try BigInt.add(&result_bigint, lhs_bigint, rhs_bigint);

                    if (!lhs.ty.eql(rhs.ty)) {
                        return self.fail(inst.base.src, "TODO implement peer type resolution", .{});
                    }

                    const val_payload = try self.arena.allocator.create(Value.Payload.IntBig);
                    val_payload.* = .{ .big_int = result_bigint };

                    return self.constInst(inst.base.src, .{
                        .ty = lhs.ty,
                        .val = Value.initPayload(&val_payload.base),
                    });
                }
            }
        }

        return self.fail(inst.base.src, "TODO implement more analyze add", .{});
    }

    fn analyzeInstDeref(self: *Analyze, func: ?*Fn, deref: *text.Inst.Deref) InnerError!*Inst {
        const ptr = try self.resolveInst(func, deref.positionals.ptr);
        const elem_ty = switch (ptr.ty.zigTypeTag()) {
            .Pointer => ptr.ty.elemType(),
            else => return self.fail(deref.positionals.ptr.src, "expected pointer, found '{}'", .{ptr.ty}),
        };
        if (ptr.value()) |val| {
            return self.constInst(deref.base.src, .{
                .ty = elem_ty,
                .val = val.pointerDeref(),
            });
        }

        return self.fail(deref.base.src, "TODO implement runtime deref", .{});
    }

    fn analyzeInstAsm(self: *Analyze, func: ?*Fn, assembly: *text.Inst.Asm) InnerError!*Inst {
        const return_type = try self.resolveType(func, assembly.positionals.return_type);
        const asm_source = try self.resolveConstString(func, assembly.positionals.asm_source);
        const output = if (assembly.kw_args.output) |o| try self.resolveConstString(func, o) else null;

        const inputs = try self.arena.allocator.alloc([]const u8, assembly.kw_args.inputs.len);
        const clobbers = try self.arena.allocator.alloc([]const u8, assembly.kw_args.clobbers.len);
        const args = try self.arena.allocator.alloc(*Inst, assembly.kw_args.args.len);

        for (inputs) |*elem, i| {
            elem.* = try self.resolveConstString(func, assembly.kw_args.inputs[i]);
        }
        for (clobbers) |*elem, i| {
            elem.* = try self.resolveConstString(func, assembly.kw_args.clobbers[i]);
        }
        for (args) |*elem, i| {
            const arg = try self.resolveInst(func, assembly.kw_args.args[i]);
            elem.* = try self.coerce(func, Type.initTag(.usize), arg);
        }

        const f = try self.requireFunctionBody(func, assembly.base.src);
        return self.addNewInstArgs(f, assembly.base.src, return_type, Inst.Assembly, Inst.Args(Inst.Assembly){
            .asm_source = asm_source,
            .is_volatile = assembly.kw_args.@"volatile",
            .output = output,
            .inputs = inputs,
            .clobbers = clobbers,
            .args = args,
        });
    }

    fn analyzeInstUnreachable(self: *Analyze, func: ?*Fn, unreach: *text.Inst.Unreachable) InnerError!*Inst {
        const f = try self.requireFunctionBody(func, unreach.base.src);
        return self.addNewInstArgs(f, unreach.base.src, Type.initTag(.noreturn), Inst.Unreach, {});
    }

    fn coerce(self: *Analyze, func: ?*Fn, dest_type: Type, inst: *Inst) !*Inst {
        // If the types are the same, we can return the operand.
        if (dest_type.eql(inst.ty))
            return inst;

        const in_memory_result = coerceInMemoryAllowed(dest_type, inst.ty);
        if (in_memory_result == .ok) {
            return self.bitcast(func, dest_type, inst);
        }

        // *[N]T to []T
        if (inst.ty.isSinglePointer() and dest_type.isSlice() and
            (!inst.ty.pointerIsConst() or dest_type.pointerIsConst()))
        {
            const array_type = inst.ty.elemType();
            const dst_elem_type = dest_type.elemType();
            if (array_type.zigTypeTag() == .Array and
                coerceInMemoryAllowed(dst_elem_type, array_type.elemType()) == .ok)
            {
                return self.coerceArrayPtrToSlice(dest_type, inst);
            }
        }

        // comptime_int to fixed-width integer
        if (inst.ty.zigTypeTag() == .ComptimeInt and dest_type.zigTypeTag() == .Int) {
            // The representation is already correct; we only need to make sure it fits in the destination type.
            const val = inst.value().?; // comptime_int always has comptime known value
            if (!val.intFitsInType(dest_type, self.target)) {
                return self.fail(inst.src, "type {} cannot represent integer value {}", .{ inst.ty, val });
            }
            return self.constInst(inst.src, .{ .ty = dest_type, .val = val });
        }

        // integer widening
        if (inst.ty.zigTypeTag() == .Int and dest_type.zigTypeTag() == .Int) {
            const src_info = inst.ty.intInfo(self.target);
            const dst_info = dest_type.intInfo(self.target);
            if (src_info.signed == dst_info.signed and dst_info.bits >= src_info.bits) {
                if (inst.value()) |val| {
                    return self.constInst(inst.src, .{ .ty = dest_type, .val = val });
                } else {
                    return self.fail(inst.src, "TODO implement runtime integer widening", .{});
                }
            } else {
                return self.fail(inst.src, "TODO implement more int widening {} to {}", .{ inst.ty, dest_type });
            }
        }

        return self.fail(inst.src, "TODO implement type coercion from {} to {}", .{ inst.ty, dest_type });
    }

    fn bitcast(self: *Analyze, func: ?*Fn, dest_type: Type, inst: *Inst) !*Inst {
        if (inst.value()) |val| {
            // Keep the comptime Value representation; take the new type.
            return self.constInst(inst.src, .{ .ty = dest_type, .val = val });
        }
        // TODO validate the type size and other compile errors
        const f = try self.requireFunctionBody(func, inst.src);
        return self.addNewInstArgs(f, inst.src, dest_type, Inst.BitCast, Inst.Args(Inst.BitCast){ .operand = inst });
    }

    fn coerceArrayPtrToSlice(self: *Analyze, dest_type: Type, inst: *Inst) !*Inst {
        if (inst.value()) |val| {
            // The comptime Value representation is compatible with both types.
            return self.constInst(inst.src, .{ .ty = dest_type, .val = val });
        }
        return self.fail(inst.src, "TODO implement coerceArrayPtrToSlice runtime instruction", .{});
    }

    fn fail(self: *Analyze, src: usize, comptime format: []const u8, args: var) InnerError {
        @setCold(true);
        const msg = try std.fmt.allocPrint(&self.arena.allocator, format, args);
        (try self.errors.addOne()).* = .{
            .byte_offset = src,
            .msg = msg,
        };
        return error.AnalysisFail;
    }

    const InMemoryCoercionResult = enum {
        ok,
        no_match,
    };

    fn coerceInMemoryAllowed(dest_type: Type, src_type: Type) InMemoryCoercionResult {
        if (dest_type.eql(src_type))
            return .ok;

        // TODO: implement more of this function

        return .no_match;
    }
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = if (std.builtin.link_libc) std.heap.c_allocator else &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    const src_path = args[1];
    const debug_error_trace = true;

    const source = try std.fs.cwd().readFileAllocOptions(allocator, src_path, std.math.maxInt(u32), 1, 0);

    var zir_module = try text.parse(allocator, source);
    defer zir_module.deinit(allocator);

    if (zir_module.errors.len != 0) {
        for (zir_module.errors) |err_msg| {
            const loc = findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.ParseFailure;
        std.process.exit(1);
    }

    const native_info = try std.zig.system.NativeTargetInfo.detect(allocator, .{});

    var analyzed_module = try analyze(allocator, zir_module, native_info.target);
    defer analyzed_module.deinit(allocator);

    if (analyzed_module.errors.len != 0) {
        for (analyzed_module.errors) |err_msg| {
            const loc = findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.ParseFailure;
        std.process.exit(1);
    }

    const output_zir = true;
    if (output_zir) {
        var new_zir_module = try text.emit_zir(allocator, analyzed_module);
        defer new_zir_module.deinit(allocator);

        var bos = std.io.bufferedOutStream(std.io.getStdOut().outStream());
        try new_zir_module.writeToStream(allocator, bos.outStream());
        try bos.flush();
    }

    const link = @import("link.zig");
    var result = try link.updateExecutableFilePath(allocator, analyzed_module, std.fs.cwd(), "a.out");
    defer result.deinit(allocator);
    if (result.errors.len != 0) {
        for (result.errors) |err_msg| {
            const loc = findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.ParseFailure;
        std.process.exit(1);
    }
}

fn findLineColumn(source: []const u8, byte_offset: usize) struct { line: usize, column: usize } {
    var line: usize = 0;
    var column: usize = 0;
    for (source[0..byte_offset]) |byte| {
        switch (byte) {
            '\n' => {
                line += 1;
                column = 0;
            },
            else => {
                column += 1;
            },
        }
    }
    return .{ .line = line, .column = column };
}

// Performance optimization ideas:
// * when analyzing use a field in the Inst instead of HashMap to track corresponding instructions
