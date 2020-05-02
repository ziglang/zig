const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;

pub const text = @import("ir/text.zig");

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
        assembly,
        bitcast,
        breakpoint,
        cmp,
        condbr,
        constant,
        isnonnull,
        isnull,
        ptrtoint,
        ret,
        unreach,
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
        if (base.ty.onePossibleValue())
            return Value.initTag(.the_one_possible_value);

        const inst = base.cast(Constant) orelse return null;
        return inst.val;
    }

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

    pub const BitCast = struct {
        pub const base_tag = Tag.bitcast;

        base: Inst,
        args: struct {
            operand: *Inst,
        },
    };

    pub const Breakpoint = struct {
        pub const base_tag = Tag.breakpoint;
        base: Inst,
        args: void,
    };

    pub const Cmp = struct {
        pub const base_tag = Tag.cmp;

        base: Inst,
        args: struct {
            lhs: *Inst,
            op: std.math.CompareOperator,
            rhs: *Inst,
        },
    };

    pub const CondBr = struct {
        pub const base_tag = Tag.condbr;

        base: Inst,
        args: struct {
            condition: *Inst,
            true_body: Module.Body,
            false_body: Module.Body,
        },
    };

    pub const Constant = struct {
        pub const base_tag = Tag.constant;
        base: Inst,

        val: Value,
    };

    pub const IsNonNull = struct {
        pub const base_tag = Tag.isnonnull;

        base: Inst,
        args: struct {
            operand: *Inst,
        },
    };

    pub const IsNull = struct {
        pub const base_tag = Tag.isnull;

        base: Inst,
        args: struct {
            operand: *Inst,
        },
    };

    pub const PtrToInt = struct {
        pub const base_tag = Tag.ptrtoint;

        base: Inst,
        args: struct {
            ptr: *Inst,
        },
    };

    pub const Ret = struct {
        pub const base_tag = Tag.ret;
        base: Inst,
        args: void,
    };

    pub const Unreach = struct {
        pub const base_tag = Tag.unreach;
        base: Inst,
        args: void,
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
    link_mode: std.builtin.LinkMode,
    output_mode: std.builtin.OutputMode,
    object_format: std.Target.ObjectFormat,
    optimize_mode: std.builtin.Mode,

    pub const Export = struct {
        name: []const u8,
        typed_value: TypedValue,
        src: usize,
    };

    pub const Fn = struct {
        analysis_status: enum { in_progress, failure, success },
        body: Body,
        fn_type: Type,
    };

    pub const Body = struct {
        instructions: []*Inst,
    };

    pub fn deinit(self: *Module, allocator: *Allocator) void {
        allocator.free(self.exports);
        allocator.free(self.errors);
        for (self.fns) |f| {
            allocator.free(f.body.instructions);
        }
        allocator.free(self.fns);
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const AnalyzeOptions = struct {
    target: Target,
    output_mode: std.builtin.OutputMode,
    link_mode: std.builtin.LinkMode,
    object_format: ?std.Target.ObjectFormat = null,
    optimize_mode: std.builtin.Mode,
};

pub fn analyze(allocator: *Allocator, old_module: text.Module, options: AnalyzeOptions) !Module {
    var ctx = Analyze{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .old_module = &old_module,
        .errors = std.ArrayList(ErrorMsg).init(allocator),
        .decl_table = std.AutoHashMap(*text.Inst, Analyze.NewDecl).init(allocator),
        .exports = std.ArrayList(Module.Export).init(allocator),
        .fns = std.ArrayList(Module.Fn).init(allocator),
        .target = options.target,
        .optimize_mode = options.optimize_mode,
        .link_mode = options.link_mode,
        .output_mode = options.output_mode,
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
        .target = ctx.target,
        .link_mode = ctx.link_mode,
        .output_mode = ctx.output_mode,
        .object_format = options.object_format orelse ctx.target.getObjectFormat(),
        .optimize_mode = ctx.optimize_mode,
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
    link_mode: std.builtin.LinkMode,
    optimize_mode: std.builtin.Mode,
    output_mode: std.builtin.OutputMode,

    const NewDecl = struct {
        /// null means a semantic analysis error happened
        ptr: ?*Inst,
    };

    const NewInst = struct {
        /// null means a semantic analysis error happened
        ptr: ?*Inst,
    };

    const Fn = struct {
        /// Index into Module fns array
        fn_index: usize,
        inner_block: Block,
        inst_table: std.AutoHashMap(*text.Inst, NewInst),
    };

    const Block = struct {
        func: *Fn,
        instructions: std.ArrayList(*Inst),
    };

    const InnerError = error{ OutOfMemory, AnalysisFail };

    fn analyzeRoot(self: *Analyze) !void {
        for (self.old_module.decls) |decl| {
            if (decl.cast(text.Inst.Export)) |export_inst| {
                try analyzeExport(self, null, export_inst);
            }
        }
    }

    fn resolveInst(self: *Analyze, opt_block: ?*Block, old_inst: *text.Inst) InnerError!*Inst {
        if (opt_block) |block| {
            if (block.func.inst_table.get(old_inst)) |kv| {
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

    fn requireRuntimeBlock(self: *Analyze, block: ?*Block, src: usize) !*Block {
        return block orelse return self.fail(src, "instruction illegal outside function body", .{});
    }

    fn resolveInstConst(self: *Analyze, block: ?*Block, old_inst: *text.Inst) InnerError!TypedValue {
        const new_inst = try self.resolveInst(block, old_inst);
        const val = try self.resolveConstValue(new_inst);
        return TypedValue{
            .ty = new_inst.ty,
            .val = val,
        };
    }

    fn resolveConstValue(self: *Analyze, base: *Inst) !Value {
        return (try self.resolveDefinedValue(base)) orelse
            return self.fail(base.src, "unable to resolve comptime value", .{});
    }

    fn resolveDefinedValue(self: *Analyze, base: *Inst) !?Value {
        if (base.value()) |val| {
            if (val.isUndef()) {
                return self.fail(base.src, "use of undefined value here causes undefined behavior", .{});
            }
            return val;
        }
        return null;
    }

    fn resolveConstString(self: *Analyze, block: ?*Block, old_inst: *text.Inst) ![]u8 {
        const new_inst = try self.resolveInst(block, old_inst);
        const wanted_type = Type.initTag(.const_slice_u8);
        const coerced_inst = try self.coerce(block, wanted_type, new_inst);
        const val = try self.resolveConstValue(coerced_inst);
        return val.toAllocatedBytes(&self.arena.allocator);
    }

    fn resolveType(self: *Analyze, block: ?*Block, old_inst: *text.Inst) !Type {
        const new_inst = try self.resolveInst(block, old_inst);
        const wanted_type = Type.initTag(.@"type");
        const coerced_inst = try self.coerce(block, wanted_type, new_inst);
        const val = try self.resolveConstValue(coerced_inst);
        return val.toType();
    }

    fn analyzeExport(self: *Analyze, block: ?*Block, export_inst: *text.Inst.Export) !void {
        const symbol_name = try self.resolveConstString(block, export_inst.positionals.symbol_name);
        const typed_value = try self.resolveInstConst(block, export_inst.positionals.value);

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
        block: *Block,
        src: usize,
        ty: Type,
        comptime T: type,
        args: Inst.Args(T),
    ) !*Inst {
        const inst = try self.addNewInst(block, src, ty, T);
        inst.args = args;
        return &inst.base;
    }

    fn addNewInst(self: *Analyze, block: *Block, src: usize, ty: Type, comptime T: type) !*T {
        const inst = try self.arena.allocator.create(T);
        inst.* = .{
            .base = .{
                .tag = T.base_tag,
                .ty = ty,
                .src = src,
            },
            .args = undefined,
        };
        try block.instructions.append(&inst.base);
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
            .val = Value.initTag(.the_one_possible_value),
        });
    }

    fn constUndef(self: *Analyze, src: usize, ty: Type) !*Inst {
        return self.constInst(src, .{
            .ty = ty,
            .val = Value.initTag(.undef),
        });
    }

    fn constBool(self: *Analyze, src: usize, v: bool) !*Inst {
        return self.constInst(src, .{
            .ty = Type.initTag(.bool),
            .val = ([2]Value{ Value.initTag(.bool_false), Value.initTag(.bool_true) })[@boolToInt(v)],
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

    fn constIntBig(self: *Analyze, src: usize, ty: Type, big_int: BigIntConst) !*Inst {
        const val_payload = if (big_int.positive) blk: {
            if (big_int.to(u64)) |x| {
                return self.constIntUnsigned(src, ty, x);
            } else |err| switch (err) {
                error.NegativeIntoUnsigned => unreachable,
                error.TargetTooSmall => {}, // handled below
            }
            const big_int_payload = try self.arena.allocator.create(Value.Payload.IntBigPositive);
            big_int_payload.* = .{ .limbs = big_int.limbs };
            break :blk &big_int_payload.base;
        } else blk: {
            if (big_int.to(i64)) |x| {
                return self.constIntSigned(src, ty, x);
            } else |err| switch (err) {
                error.NegativeIntoUnsigned => unreachable,
                error.TargetTooSmall => {}, // handled below
            }
            const big_int_payload = try self.arena.allocator.create(Value.Payload.IntBigNegative);
            big_int_payload.* = .{ .limbs = big_int.limbs };
            break :blk &big_int_payload.base;
        };

        return self.constInst(src, .{
            .ty = ty,
            .val = Value.initPayload(val_payload),
        });
    }

    fn analyzeInst(self: *Analyze, block: ?*Block, old_inst: *text.Inst) InnerError!*Inst {
        switch (old_inst.tag) {
            .breakpoint => return self.analyzeInstBreakpoint(block, old_inst.cast(text.Inst.Breakpoint).?),
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
            .ptrtoint => return self.analyzeInstPtrToInt(block, old_inst.cast(text.Inst.PtrToInt).?),
            .fieldptr => return self.analyzeInstFieldPtr(block, old_inst.cast(text.Inst.FieldPtr).?),
            .deref => return self.analyzeInstDeref(block, old_inst.cast(text.Inst.Deref).?),
            .as => return self.analyzeInstAs(block, old_inst.cast(text.Inst.As).?),
            .@"asm" => return self.analyzeInstAsm(block, old_inst.cast(text.Inst.Asm).?),
            .@"unreachable" => return self.analyzeInstUnreachable(block, old_inst.cast(text.Inst.Unreachable).?),
            .@"return" => return self.analyzeInstRet(block, old_inst.cast(text.Inst.Return).?),
            .@"fn" => return self.analyzeInstFn(block, old_inst.cast(text.Inst.Fn).?),
            .@"export" => {
                try self.analyzeExport(block, old_inst.cast(text.Inst.Export).?);
                return self.constVoid(old_inst.src);
            },
            .primitive => return self.analyzeInstPrimitive(old_inst.cast(text.Inst.Primitive).?),
            .fntype => return self.analyzeInstFnType(block, old_inst.cast(text.Inst.FnType).?),
            .intcast => return self.analyzeInstIntCast(block, old_inst.cast(text.Inst.IntCast).?),
            .bitcast => return self.analyzeInstBitCast(block, old_inst.cast(text.Inst.BitCast).?),
            .elemptr => return self.analyzeInstElemPtr(block, old_inst.cast(text.Inst.ElemPtr).?),
            .add => return self.analyzeInstAdd(block, old_inst.cast(text.Inst.Add).?),
            .cmp => return self.analyzeInstCmp(block, old_inst.cast(text.Inst.Cmp).?),
            .condbr => return self.analyzeInstCondBr(block, old_inst.cast(text.Inst.CondBr).?),
            .isnull => return self.analyzeInstIsNull(block, old_inst.cast(text.Inst.IsNull).?),
            .isnonnull => return self.analyzeInstIsNonNull(block, old_inst.cast(text.Inst.IsNonNull).?),
        }
    }

    fn analyzeInstBreakpoint(self: *Analyze, block: ?*Block, inst: *text.Inst.Breakpoint) InnerError!*Inst {
        const b = try self.requireRuntimeBlock(block, inst.base.src);
        return self.addNewInstArgs(b, inst.base.src, Type.initTag(.void), Inst.Breakpoint, Inst.Args(Inst.Breakpoint){});
    }

    fn analyzeInstFn(self: *Analyze, block: ?*Block, fn_inst: *text.Inst.Fn) InnerError!*Inst {
        const fn_type = try self.resolveType(block, fn_inst.positionals.fn_type);

        var new_func: Fn = .{
            .fn_index = self.fns.items.len,
            .inner_block = .{
                .func = undefined,
                .instructions = std.ArrayList(*Inst).init(self.allocator),
            },
            .inst_table = std.AutoHashMap(*text.Inst, NewInst).init(self.allocator),
        };
        new_func.inner_block.func = &new_func;
        defer new_func.inner_block.instructions.deinit();
        defer new_func.inst_table.deinit();
        // Don't hang on to a reference to this when analyzing body instructions, since the memory
        // could become invalid.
        (try self.fns.addOne()).* = .{
            .analysis_status = .in_progress,
            .fn_type = fn_type,
            .body = undefined,
        };

        try self.analyzeBody(&new_func.inner_block, fn_inst.positionals.body);

        const f = &self.fns.items[new_func.fn_index];
        f.analysis_status = .success;
        f.body = .{ .instructions = new_func.inner_block.instructions.toOwnedSlice() };

        const fn_payload = try self.arena.allocator.create(Value.Payload.Function);
        fn_payload.* = .{ .index = new_func.fn_index };

        return self.constInst(fn_inst.base.src, .{
            .ty = fn_type,
            .val = Value.initPayload(&fn_payload.base),
        });
    }

    fn analyzeInstFnType(self: *Analyze, block: ?*Block, fntype: *text.Inst.FnType) InnerError!*Inst {
        const return_type = try self.resolveType(block, fntype.positionals.return_type);

        if (return_type.zigTypeTag() == .NoReturn and
            fntype.positionals.param_types.len == 0 and
            fntype.kw_args.cc == .Naked)
        {
            return self.constType(fntype.base.src, Type.initTag(.fn_naked_noreturn_no_args));
        }

        if (return_type.zigTypeTag() == .Void and
            fntype.positionals.param_types.len == 0 and
            fntype.kw_args.cc == .C)
        {
            return self.constType(fntype.base.src, Type.initTag(.fn_ccc_void_no_args));
        }

        return self.fail(fntype.base.src, "TODO implement fntype instruction more", .{});
    }

    fn analyzeInstPrimitive(self: *Analyze, primitive: *text.Inst.Primitive) InnerError!*Inst {
        return self.constType(primitive.base.src, primitive.positionals.tag.toType());
    }

    fn analyzeInstAs(self: *Analyze, block: ?*Block, as: *text.Inst.As) InnerError!*Inst {
        const dest_type = try self.resolveType(block, as.positionals.dest_type);
        const new_inst = try self.resolveInst(block, as.positionals.value);
        return self.coerce(block, dest_type, new_inst);
    }

    fn analyzeInstPtrToInt(self: *Analyze, block: ?*Block, ptrtoint: *text.Inst.PtrToInt) InnerError!*Inst {
        const ptr = try self.resolveInst(block, ptrtoint.positionals.ptr);
        if (ptr.ty.zigTypeTag() != .Pointer) {
            return self.fail(ptrtoint.positionals.ptr.src, "expected pointer, found '{}'", .{ptr.ty});
        }
        // TODO handle known-pointer-address
        const b = try self.requireRuntimeBlock(block, ptrtoint.base.src);
        const ty = Type.initTag(.usize);
        return self.addNewInstArgs(b, ptrtoint.base.src, ty, Inst.PtrToInt, Inst.Args(Inst.PtrToInt){ .ptr = ptr });
    }

    fn analyzeInstFieldPtr(self: *Analyze, block: ?*Block, fieldptr: *text.Inst.FieldPtr) InnerError!*Inst {
        const object_ptr = try self.resolveInst(block, fieldptr.positionals.object_ptr);
        const field_name = try self.resolveConstString(block, fieldptr.positionals.field_name);

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

    fn analyzeInstIntCast(self: *Analyze, block: ?*Block, intcast: *text.Inst.IntCast) InnerError!*Inst {
        const dest_type = try self.resolveType(block, intcast.positionals.dest_type);
        const new_inst = try self.resolveInst(block, intcast.positionals.value);

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
            return self.coerce(block, dest_type, new_inst);
        }

        return self.fail(intcast.base.src, "TODO implement analyze widen or shorten int", .{});
    }

    fn analyzeInstBitCast(self: *Analyze, block: ?*Block, inst: *text.Inst.BitCast) InnerError!*Inst {
        const dest_type = try self.resolveType(block, inst.positionals.dest_type);
        const operand = try self.resolveInst(block, inst.positionals.operand);
        return self.bitcast(block, dest_type, operand);
    }

    fn analyzeInstElemPtr(self: *Analyze, block: ?*Block, inst: *text.Inst.ElemPtr) InnerError!*Inst {
        const array_ptr = try self.resolveInst(block, inst.positionals.array_ptr);
        const uncasted_index = try self.resolveInst(block, inst.positionals.index);
        const elem_index = try self.coerce(block, Type.initTag(.usize), uncasted_index);

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

    fn analyzeInstAdd(self: *Analyze, block: ?*Block, inst: *text.Inst.Add) InnerError!*Inst {
        const lhs = try self.resolveInst(block, inst.positionals.lhs);
        const rhs = try self.resolveInst(block, inst.positionals.rhs);

        if (lhs.ty.zigTypeTag() == .Int and rhs.ty.zigTypeTag() == .Int) {
            if (lhs.value()) |lhs_val| {
                if (rhs.value()) |rhs_val| {
                    // TODO is this a performance issue? maybe we should try the operation without
                    // resorting to BigInt first.
                    var lhs_space: Value.BigIntSpace = undefined;
                    var rhs_space: Value.BigIntSpace = undefined;
                    const lhs_bigint = lhs_val.toBigInt(&lhs_space);
                    const rhs_bigint = rhs_val.toBigInt(&rhs_space);
                    const limbs = try self.arena.allocator.alloc(
                        std.math.big.Limb,
                        std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
                    );
                    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
                    result_bigint.add(lhs_bigint, rhs_bigint);
                    const result_limbs = result_bigint.limbs[0..result_bigint.len];

                    if (!lhs.ty.eql(rhs.ty)) {
                        return self.fail(inst.base.src, "TODO implement peer type resolution", .{});
                    }

                    const val_payload = if (result_bigint.positive) blk: {
                        const val_payload = try self.arena.allocator.create(Value.Payload.IntBigPositive);
                        val_payload.* = .{ .limbs = result_limbs };
                        break :blk &val_payload.base;
                    } else blk: {
                        const val_payload = try self.arena.allocator.create(Value.Payload.IntBigNegative);
                        val_payload.* = .{ .limbs = result_limbs };
                        break :blk &val_payload.base;
                    };

                    return self.constInst(inst.base.src, .{
                        .ty = lhs.ty,
                        .val = Value.initPayload(val_payload),
                    });
                }
            }
        }

        return self.fail(inst.base.src, "TODO implement more analyze add", .{});
    }

    fn analyzeInstDeref(self: *Analyze, block: ?*Block, deref: *text.Inst.Deref) InnerError!*Inst {
        const ptr = try self.resolveInst(block, deref.positionals.ptr);
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

    fn analyzeInstAsm(self: *Analyze, block: ?*Block, assembly: *text.Inst.Asm) InnerError!*Inst {
        const return_type = try self.resolveType(block, assembly.positionals.return_type);
        const asm_source = try self.resolveConstString(block, assembly.positionals.asm_source);
        const output = if (assembly.kw_args.output) |o| try self.resolveConstString(block, o) else null;

        const inputs = try self.arena.allocator.alloc([]const u8, assembly.kw_args.inputs.len);
        const clobbers = try self.arena.allocator.alloc([]const u8, assembly.kw_args.clobbers.len);
        const args = try self.arena.allocator.alloc(*Inst, assembly.kw_args.args.len);

        for (inputs) |*elem, i| {
            elem.* = try self.resolveConstString(block, assembly.kw_args.inputs[i]);
        }
        for (clobbers) |*elem, i| {
            elem.* = try self.resolveConstString(block, assembly.kw_args.clobbers[i]);
        }
        for (args) |*elem, i| {
            const arg = try self.resolveInst(block, assembly.kw_args.args[i]);
            elem.* = try self.coerce(block, Type.initTag(.usize), arg);
        }

        const b = try self.requireRuntimeBlock(block, assembly.base.src);
        return self.addNewInstArgs(b, assembly.base.src, return_type, Inst.Assembly, Inst.Args(Inst.Assembly){
            .asm_source = asm_source,
            .is_volatile = assembly.kw_args.@"volatile",
            .output = output,
            .inputs = inputs,
            .clobbers = clobbers,
            .args = args,
        });
    }

    fn analyzeInstCmp(self: *Analyze, block: ?*Block, inst: *text.Inst.Cmp) InnerError!*Inst {
        const lhs = try self.resolveInst(block, inst.positionals.lhs);
        const rhs = try self.resolveInst(block, inst.positionals.rhs);
        const op = inst.positionals.op;

        const is_equality_cmp = switch (op) {
            .eq, .neq => true,
            else => false,
        };
        const lhs_ty_tag = lhs.ty.zigTypeTag();
        const rhs_ty_tag = rhs.ty.zigTypeTag();
        if (is_equality_cmp and lhs_ty_tag == .Null and rhs_ty_tag == .Null) {
            // null == null, null != null
            return self.constBool(inst.base.src, op == .eq);
        } else if (is_equality_cmp and
            ((lhs_ty_tag == .Null and rhs_ty_tag == .Optional) or
            rhs_ty_tag == .Null and lhs_ty_tag == .Optional))
        {
            // comparing null with optionals
            const opt_operand = if (lhs_ty_tag == .Optional) lhs else rhs;
            if (opt_operand.value()) |opt_val| {
                const is_null = opt_val.isNull();
                return self.constBool(inst.base.src, if (op == .eq) is_null else !is_null);
            }
            const b = try self.requireRuntimeBlock(block, inst.base.src);
            switch (op) {
                .eq => return self.addNewInstArgs(
                    b,
                    inst.base.src,
                    Type.initTag(.bool),
                    Inst.IsNull,
                    Inst.Args(Inst.IsNull){ .operand = opt_operand },
                ),
                .neq => return self.addNewInstArgs(
                    b,
                    inst.base.src,
                    Type.initTag(.bool),
                    Inst.IsNonNull,
                    Inst.Args(Inst.IsNonNull){ .operand = opt_operand },
                ),
                else => unreachable,
            }
        } else if (is_equality_cmp and
            ((lhs_ty_tag == .Null and rhs.ty.isCPtr()) or (rhs_ty_tag == .Null and lhs.ty.isCPtr())))
        {
            return self.fail(inst.base.src, "TODO implement C pointer cmp", .{});
        } else if (lhs_ty_tag == .Null or rhs_ty_tag == .Null) {
            const non_null_type = if (lhs_ty_tag == .Null) rhs.ty else lhs.ty;
            return self.fail(inst.base.src, "comparison of '{}' with null", .{non_null_type});
        } else if (is_equality_cmp and
            ((lhs_ty_tag == .EnumLiteral and rhs_ty_tag == .Union) or
            (rhs_ty_tag == .EnumLiteral and lhs_ty_tag == .Union)))
        {
            return self.fail(inst.base.src, "TODO implement equality comparison between a union's tag value and an enum literal", .{});
        } else if (lhs_ty_tag == .ErrorSet and rhs_ty_tag == .ErrorSet) {
            if (!is_equality_cmp) {
                return self.fail(inst.base.src, "{} operator not allowed for errors", .{@tagName(op)});
            }
            return self.fail(inst.base.src, "TODO implement equality comparison between errors", .{});
        } else if (lhs.ty.isNumeric() and rhs.ty.isNumeric()) {
            // This operation allows any combination of integer and float types, regardless of the
            // signed-ness, comptime-ness, and bit-width. So peer type resolution is incorrect for
            // numeric types.
            return self.cmpNumeric(block, inst.base.src, lhs, rhs, op);
        }
        return self.fail(inst.base.src, "TODO implement more cmp analysis", .{});
    }

    fn analyzeInstIsNull(self: *Analyze, block: ?*Block, inst: *text.Inst.IsNull) InnerError!*Inst {
        const operand = try self.resolveInst(block, inst.positionals.operand);
        return self.analyzeIsNull(block, inst.base.src, operand, true);
    }

    fn analyzeInstIsNonNull(self: *Analyze, block: ?*Block, inst: *text.Inst.IsNonNull) InnerError!*Inst {
        const operand = try self.resolveInst(block, inst.positionals.operand);
        return self.analyzeIsNull(block, inst.base.src, operand, false);
    }

    fn analyzeInstCondBr(self: *Analyze, block: ?*Block, inst: *text.Inst.CondBr) InnerError!*Inst {
        const uncasted_cond = try self.resolveInst(block, inst.positionals.condition);
        const cond = try self.coerce(block, Type.initTag(.bool), uncasted_cond);

        if (try self.resolveDefinedValue(cond)) |cond_val| {
            const body = if (cond_val.toBool()) &inst.positionals.true_body else &inst.positionals.false_body;
            try self.analyzeBody(block, body.*);
            return self.constVoid(inst.base.src);
        }

        const parent_block = try self.requireRuntimeBlock(block, inst.base.src);

        var true_block: Block = .{
            .func = parent_block.func,
            .instructions = std.ArrayList(*Inst).init(self.allocator),
        };
        defer true_block.instructions.deinit();
        try self.analyzeBody(&true_block, inst.positionals.true_body);

        var false_block: Block = .{
            .func = parent_block.func,
            .instructions = std.ArrayList(*Inst).init(self.allocator),
        };
        defer false_block.instructions.deinit();
        try self.analyzeBody(&false_block, inst.positionals.false_body);

        // Copy the instruction pointers to the arena memory
        const true_instructions = try self.arena.allocator.alloc(*Inst, true_block.instructions.items.len);
        const false_instructions = try self.arena.allocator.alloc(*Inst, false_block.instructions.items.len);

        mem.copy(*Inst, true_instructions, true_block.instructions.items);
        mem.copy(*Inst, false_instructions, false_block.instructions.items);

        return self.addNewInstArgs(parent_block, inst.base.src, Type.initTag(.void), Inst.CondBr, Inst.Args(Inst.CondBr){
            .condition = cond,
            .true_body = .{ .instructions = true_instructions },
            .false_body = .{ .instructions = false_instructions },
        });
    }

    fn wantSafety(self: *Analyze, block: ?*Block) bool {
        return switch (self.optimize_mode) {
            .Debug => true,
            .ReleaseSafe => true,
            .ReleaseFast => false,
            .ReleaseSmall => false,
        };
    }

    fn analyzeInstUnreachable(self: *Analyze, block: ?*Block, unreach: *text.Inst.Unreachable) InnerError!*Inst {
        const b = try self.requireRuntimeBlock(block, unreach.base.src);
        if (self.wantSafety(block)) {
            // TODO Once we have a panic function to call, call it here instead of this.
            _ = try self.addNewInstArgs(b, unreach.base.src, Type.initTag(.void), Inst.Breakpoint, {});
        }
        return self.addNewInstArgs(b, unreach.base.src, Type.initTag(.noreturn), Inst.Unreach, {});
    }

    fn analyzeInstRet(self: *Analyze, block: ?*Block, inst: *text.Inst.Return) InnerError!*Inst {
        const b = try self.requireRuntimeBlock(block, inst.base.src);
        return self.addNewInstArgs(b, inst.base.src, Type.initTag(.noreturn), Inst.Ret, {});
    }

    fn analyzeBody(self: *Analyze, block: ?*Block, body: text.Module.Body) !void {
        for (body.instructions) |src_inst| {
            const new_inst = self.analyzeInst(block, src_inst) catch |err| {
                if (block) |b| {
                    self.fns.items[b.func.fn_index].analysis_status = .failure;
                    try b.func.inst_table.putNoClobber(src_inst, .{ .ptr = null });
                }
                return err;
            };
            if (block) |b| try b.func.inst_table.putNoClobber(src_inst, .{ .ptr = new_inst });
        }
    }

    fn analyzeIsNull(
        self: *Analyze,
        block: ?*Block,
        src: usize,
        operand: *Inst,
        invert_logic: bool,
    ) InnerError!*Inst {
        return self.fail(src, "TODO implement analysis of isnull and isnotnull", .{});
    }

    /// Asserts that lhs and rhs types are both numeric.
    fn cmpNumeric(
        self: *Analyze,
        block: ?*Block,
        src: usize,
        lhs: *Inst,
        rhs: *Inst,
        op: std.math.CompareOperator,
    ) !*Inst {
        assert(lhs.ty.isNumeric());
        assert(rhs.ty.isNumeric());

        const lhs_ty_tag = lhs.ty.zigTypeTag();
        const rhs_ty_tag = rhs.ty.zigTypeTag();

        if (lhs_ty_tag == .Vector and rhs_ty_tag == .Vector) {
            if (lhs.ty.arrayLen() != rhs.ty.arrayLen()) {
                return self.fail(src, "vector length mismatch: {} and {}", .{
                    lhs.ty.arrayLen(),
                    rhs.ty.arrayLen(),
                });
            }
            return self.fail(src, "TODO implement support for vectors in cmpNumeric", .{});
        } else if (lhs_ty_tag == .Vector or rhs_ty_tag == .Vector) {
            return self.fail(src, "mixed scalar and vector operands to comparison operator: '{}' and '{}'", .{
                lhs.ty,
                rhs.ty,
            });
        }

        if (lhs.value()) |lhs_val| {
            if (rhs.value()) |rhs_val| {
                return self.constBool(src, Value.compare(lhs_val, op, rhs_val));
            }
        }

        // TODO handle comparisons against lazy zero values
        // Some values can be compared against zero without being runtime known or without forcing
        // a full resolution of their value, for example `@sizeOf(@Frame(function))` is known to
        // always be nonzero, and we benefit from not forcing the full evaluation and stack frame layout
        // of this function if we don't need to.

        // It must be a runtime comparison.
        const b = try self.requireRuntimeBlock(block, src);
        // For floats, emit a float comparison instruction.
        const lhs_is_float = switch (lhs_ty_tag) {
            .Float, .ComptimeFloat => true,
            else => false,
        };
        const rhs_is_float = switch (rhs_ty_tag) {
            .Float, .ComptimeFloat => true,
            else => false,
        };
        if (lhs_is_float and rhs_is_float) {
            // Implicit cast the smaller one to the larger one.
            const dest_type = x: {
                if (lhs_ty_tag == .ComptimeFloat) {
                    break :x rhs.ty;
                } else if (rhs_ty_tag == .ComptimeFloat) {
                    break :x lhs.ty;
                }
                if (lhs.ty.floatBits(self.target) >= rhs.ty.floatBits(self.target)) {
                    break :x lhs.ty;
                } else {
                    break :x rhs.ty;
                }
            };
            const casted_lhs = try self.coerce(block, dest_type, lhs);
            const casted_rhs = try self.coerce(block, dest_type, rhs);
            return self.addNewInstArgs(b, src, dest_type, Inst.Cmp, Inst.Args(Inst.Cmp){
                .lhs = casted_lhs,
                .rhs = casted_rhs,
                .op = op,
            });
        }
        // For mixed unsigned integer sizes, implicit cast both operands to the larger integer.
        // For mixed signed and unsigned integers, implicit cast both operands to a signed
        // integer with + 1 bit.
        // For mixed floats and integers, extract the integer part from the float, cast that to
        // a signed integer with mantissa bits + 1, and if there was any non-integral part of the float,
        // add/subtract 1.
        const lhs_is_signed = if (lhs.value()) |lhs_val|
            lhs_val.compareWithZero(.lt)
        else
            (lhs.ty.isFloat() or lhs.ty.isSignedInt());
        const rhs_is_signed = if (rhs.value()) |rhs_val|
            rhs_val.compareWithZero(.lt)
        else
            (rhs.ty.isFloat() or rhs.ty.isSignedInt());
        const dest_int_is_signed = lhs_is_signed or rhs_is_signed;

        var dest_float_type: ?Type = null;

        var lhs_bits: usize = undefined;
        if (lhs.value()) |lhs_val| {
            if (lhs_val.isUndef())
                return self.constUndef(src, Type.initTag(.bool));
            const is_unsigned = if (lhs_is_float) x: {
                var bigint_space: Value.BigIntSpace = undefined;
                var bigint = try lhs_val.toBigInt(&bigint_space).toManaged(self.allocator);
                defer bigint.deinit();
                const zcmp = lhs_val.orderAgainstZero();
                if (lhs_val.floatHasFraction()) {
                    switch (op) {
                        .eq => return self.constBool(src, false),
                        .neq => return self.constBool(src, true),
                        else => {},
                    }
                    if (zcmp == .lt) {
                        try bigint.addScalar(bigint.toConst(), -1);
                    } else {
                        try bigint.addScalar(bigint.toConst(), 1);
                    }
                }
                lhs_bits = bigint.toConst().bitCountTwosComp();
                break :x (zcmp != .lt);
            } else x: {
                lhs_bits = lhs_val.intBitCountTwosComp();
                break :x (lhs_val.orderAgainstZero() != .lt);
            };
            lhs_bits += @boolToInt(is_unsigned and dest_int_is_signed);
        } else if (lhs_is_float) {
            dest_float_type = lhs.ty;
        } else {
            const int_info = lhs.ty.intInfo(self.target);
            lhs_bits = int_info.bits + @boolToInt(!int_info.signed and dest_int_is_signed);
        }

        var rhs_bits: usize = undefined;
        if (rhs.value()) |rhs_val| {
            if (rhs_val.isUndef())
                return self.constUndef(src, Type.initTag(.bool));
            const is_unsigned = if (rhs_is_float) x: {
                var bigint_space: Value.BigIntSpace = undefined;
                var bigint = try rhs_val.toBigInt(&bigint_space).toManaged(self.allocator);
                defer bigint.deinit();
                const zcmp = rhs_val.orderAgainstZero();
                if (rhs_val.floatHasFraction()) {
                    switch (op) {
                        .eq => return self.constBool(src, false),
                        .neq => return self.constBool(src, true),
                        else => {},
                    }
                    if (zcmp == .lt) {
                        try bigint.addScalar(bigint.toConst(), -1);
                    } else {
                        try bigint.addScalar(bigint.toConst(), 1);
                    }
                }
                rhs_bits = bigint.toConst().bitCountTwosComp();
                break :x (zcmp != .lt);
            } else x: {
                rhs_bits = rhs_val.intBitCountTwosComp();
                break :x (rhs_val.orderAgainstZero() != .lt);
            };
            rhs_bits += @boolToInt(is_unsigned and dest_int_is_signed);
        } else if (rhs_is_float) {
            dest_float_type = rhs.ty;
        } else {
            const int_info = rhs.ty.intInfo(self.target);
            rhs_bits = int_info.bits + @boolToInt(!int_info.signed and dest_int_is_signed);
        }

        const dest_type = if (dest_float_type) |ft| ft else blk: {
            const max_bits = std.math.max(lhs_bits, rhs_bits);
            const casted_bits = std.math.cast(u16, max_bits) catch |err| switch (err) {
                error.Overflow => return self.fail(src, "{} exceeds maximum integer bit count", .{max_bits}),
            };
            break :blk try self.makeIntType(dest_int_is_signed, casted_bits);
        };
        const casted_lhs = try self.coerce(block, dest_type, lhs);
        const casted_rhs = try self.coerce(block, dest_type, lhs);

        return self.addNewInstArgs(b, src, dest_type, Inst.Cmp, Inst.Args(Inst.Cmp){
            .lhs = casted_lhs,
            .rhs = casted_rhs,
            .op = op,
        });
    }

    fn makeIntType(self: *Analyze, signed: bool, bits: u16) !Type {
        if (signed) {
            const int_payload = try self.arena.allocator.create(Type.Payload.IntSigned);
            int_payload.* = .{ .bits = bits };
            return Type.initPayload(&int_payload.base);
        } else {
            const int_payload = try self.arena.allocator.create(Type.Payload.IntUnsigned);
            int_payload.* = .{ .bits = bits };
            return Type.initPayload(&int_payload.base);
        }
    }

    fn coerce(self: *Analyze, block: ?*Block, dest_type: Type, inst: *Inst) !*Inst {
        // If the types are the same, we can return the operand.
        if (dest_type.eql(inst.ty))
            return inst;

        const in_memory_result = coerceInMemoryAllowed(dest_type, inst.ty);
        if (in_memory_result == .ok) {
            return self.bitcast(block, dest_type, inst);
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

    fn bitcast(self: *Analyze, block: ?*Block, dest_type: Type, inst: *Inst) !*Inst {
        if (inst.value()) |val| {
            // Keep the comptime Value representation; take the new type.
            return self.constInst(inst.src, .{ .ty = dest_type, .val = val });
        }
        // TODO validate the type size and other compile errors
        const b = try self.requireRuntimeBlock(block, inst.src);
        return self.addNewInstArgs(b, inst.src, dest_type, Inst.BitCast, Inst.Args(Inst.BitCast){ .operand = inst });
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
    defer std.process.argsFree(allocator, args);

    const src_path = args[1];
    const debug_error_trace = true;

    const source = try std.fs.cwd().readFileAllocOptions(allocator, src_path, std.math.maxInt(u32), 1, 0);
    defer allocator.free(source);

    var zir_module = try text.parse(allocator, source);
    defer zir_module.deinit(allocator);

    if (zir_module.errors.len != 0) {
        for (zir_module.errors) |err_msg| {
            const loc = std.zig.findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.ParseFailure;
        std.process.exit(1);
    }

    const native_info = try std.zig.system.NativeTargetInfo.detect(allocator, .{});

    var analyzed_module = try analyze(allocator, zir_module, .{
        .target = native_info.target,
        .output_mode = .Obj,
        .link_mode = .Static,
        .optimize_mode = .Debug,
    });
    defer analyzed_module.deinit(allocator);

    if (analyzed_module.errors.len != 0) {
        for (analyzed_module.errors) |err_msg| {
            const loc = std.zig.findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.AnalysisFail;
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
    var result = try link.updateFilePath(allocator, analyzed_module, std.fs.cwd(), "zir.o");
    defer result.deinit(allocator);
    if (result.errors.len != 0) {
        for (result.errors) |err_msg| {
            const loc = std.zig.findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.LinkFailure;
        std.process.exit(1);
    }
}

// Performance optimization ideas:
// * when analyzing use a field in the Inst instead of HashMap to track corresponding instructions
