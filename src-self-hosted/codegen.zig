const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const ir = @import("ir.zig");
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const Symbol = struct {
    errors: []ErrorMsg,

    pub fn deinit(self: *Symbol, allocator: *mem.Allocator) void {
        for (self.errors) |err| {
            allocator.free(err.msg);
        }
        allocator.free(self.errors);
        self.* = undefined;
    }
};

pub fn generateSymbol(typed_value: ir.TypedValue, module: ir.Module, code: *std.ArrayList(u8)) !Symbol {
    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {
            const index = typed_value.val.cast(Value.Payload.Function).?.index;
            const module_fn = module.fns[index];

            var function = Function{
                .module = &module,
                .mod_fn = &module_fn,
                .code = code,
                .inst_table = std.AutoHashMap(*ir.Inst, Function.MCValue).init(code.allocator),
                .errors = std.ArrayList(ErrorMsg).init(code.allocator),
            };
            defer function.inst_table.deinit();
            defer function.errors.deinit();

            for (module_fn.body) |inst| {
                const new_inst = function.genFuncInst(inst) catch |err| switch (err) {
                    error.CodegenFail => {
                        assert(function.errors.items.len != 0);
                        break;
                    },
                    else => |e| return e,
                };
                try function.inst_table.putNoClobber(inst, new_inst);
            }

            return Symbol{ .errors = function.errors.toOwnedSlice() };
        },
        else => @panic("TODO implement generateSymbol for non-function types"),
    }
}

const Function = struct {
    module: *const ir.Module,
    mod_fn: *const ir.Module.Fn,
    code: *std.ArrayList(u8),
    inst_table: std.AutoHashMap(*ir.Inst, MCValue),
    errors: std.ArrayList(ErrorMsg),

    const MCValue = union(enum) {
        none,
        unreach,
        /// A pointer-sized integer that fits in a register.
        immediate: u64,
        /// The constant was emitted into the code, at this offset.
        embedded_in_code: usize,
    };

    fn genFuncInst(self: *Function, inst: *ir.Inst) !MCValue {
        switch (inst.tag) {
            .unreach => return self.genPanic(inst.src),
            .constant => unreachable, // excluded from function bodies
            .assembly => return self.genAsm(inst.cast(ir.Inst.Assembly).?),
            .ptrtoint => return self.genPtrToInt(inst.cast(ir.Inst.PtrToInt).?),
        }
    }

    fn genPanic(self: *Function, src: usize) !MCValue {
        // TODO change this to call the panic function
        switch (self.module.target.cpu.arch) {
            .i386, .x86_64 => {
                try self.code.append(0xcc); // int3
            },
            else => return self.fail(src, "TODO implement panic for {}", .{self.module.target.cpu.arch}),
        }
        return .unreach;
    }

    fn genRet(self: *Function, src: usize) !void {
        // TODO change this to call the panic function
        switch (self.module.target.cpu.arch) {
            .i386, .x86_64 => {
                try self.code.append(0xc3); // ret
            },
            else => return self.fail(src, "TODO implement ret for {}", .{self.module.target.cpu.arch}),
        }
    }

    fn genRelativeFwdJump(self: *Function, src: usize, amount: u32) !void {
        switch (self.module.target.cpu.arch) {
            .i386, .x86_64 => {
                if (amount <= std.math.maxInt(u8)) {
                    try self.code.resize(self.code.items.len + 2);
                    self.code.items[self.code.items.len - 2] = 0xeb;
                    self.code.items[self.code.items.len - 1] = @intCast(u8, amount);
                } else if (amount <= std.math.maxInt(u16)) {
                    try self.code.resize(self.code.items.len + 3);
                    self.code.items[self.code.items.len - 3] = 0xe9; // jmp rel16
                    const imm_ptr = self.code.items[self.code.items.len - 2 ..][0..2];
                    mem.writeIntLittle(u16, imm_ptr, @intCast(u16, amount));
                } else {
                    try self.code.resize(self.code.items.len + 5);
                    self.code.items[self.code.items.len - 5] = 0xea; // jmp rel32
                    const imm_ptr = self.code.items[self.code.items.len - 4 ..][0..4];
                    mem.writeIntLittle(u32, imm_ptr, amount);
                }
            },
            else => return self.fail(src, "TODO implement relative forward jump for {}", .{self.module.target.cpu.arch}),
        }
    }

    fn genAsm(self: *Function, inst: *ir.Inst.Assembly) !MCValue {
        return self.fail(inst.base.src, "TODO machine code gen assembly", .{});
    }

    fn genPtrToInt(self: *Function, inst: *ir.Inst.PtrToInt) !MCValue {
        // no-op
        return self.resolveInst(inst.args.ptr);
    }

    fn resolveInst(self: *Function, inst: *ir.Inst) !MCValue {
        if (self.inst_table.getValue(inst)) |mcv| {
            return mcv;
        }
        if (inst.cast(ir.Inst.Constant)) |const_inst| {
            const mcvalue = try self.genTypedValue(inst.src, .{ .ty = inst.ty, .val = const_inst.val });
            try self.inst_table.putNoClobber(inst, mcvalue);
            return mcvalue;
        } else {
            return self.inst_table.getValue(inst).?;
        }
    }

    fn genTypedValue(self: *Function, src: usize, typed_value: ir.TypedValue) !MCValue {
        switch (typed_value.ty.zigTypeTag()) {
            .Pointer => {
                const ptr_elem_type = typed_value.ty.elemType();
                switch (ptr_elem_type.zigTypeTag()) {
                    .Array => {
                        // TODO more checks to make sure this can be emitted as a string literal
                        const bytes = try typed_value.val.toAllocatedBytes(self.code.allocator);
                        defer self.code.allocator.free(bytes);
                        const smaller_len = std.math.cast(u32, bytes.len) catch
                            return self.fail(src, "TODO handle a larger string constant", .{});

                        // Emit the string literal directly into the code; jump over it.
                        const offset = self.code.items.len;
                        try self.genRelativeFwdJump(src, smaller_len);
                        try self.code.appendSlice(bytes);
                        return MCValue{ .embedded_in_code = offset };
                    },
                    else => |t| return self.fail(src, "TODO implement emitTypedValue for pointer to '{}'", .{@tagName(t)}),
                }
            },
            .Int => {
                const info = typed_value.ty.intInfo(self.module.target);
                const ptr_bits = self.module.target.cpu.arch.ptrBitWidth();
                if (info.bits > ptr_bits or info.signed) {
                    return self.fail(src, "TODO const int bigger than ptr and signed int", .{});
                }
                return MCValue{ .immediate = typed_value.val.toUnsignedInt() };
            },
            else => return self.fail(src, "TODO implement const of type '{}'", .{typed_value.ty}),
        }
    }

    fn fail(self: *Function, src: usize, comptime format: []const u8, args: var) error{ CodegenFail, OutOfMemory } {
        @setCold(true);
        const msg = try std.fmt.allocPrint(self.errors.allocator, format, args);
        {
            errdefer self.errors.allocator.free(msg);
            (try self.errors.addOne()).* = .{
                .byte_offset = src,
                .msg = msg,
            };
        }
        return error.CodegenFail;
    }
};
