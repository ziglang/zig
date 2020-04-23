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
                .constants = std.ArrayList(ir.TypedValue).init(code.allocator),
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
    /// Constants are embedded within functions (at the end, after `ret`)
    /// so that they are independently updateable.
    /// This is a list of constants that must be appended to the symbol after `ret`.
    constants: std.ArrayList(ir.TypedValue),
    errors: std.ArrayList(ErrorMsg),

    const MCValue = union(enum) {
        none,
        unreach,
        /// A pointer-sized integer that fits in a register.
        immediate: u64,
        /// Refers to the index into `constants` field of `Function`.
        local_const_ptr: usize,
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
                try self.code.append(0xcc); // x86 int3
            },
            else => return self.fail(src, "TODO implement panic for {}", .{self.module.target.cpu.arch}),
        }
        return .unreach;
    }

    fn genAsm(self: *Function, inst: *ir.Inst.Assembly) !MCValue {
        return self.fail(inst.base.src, "TODO machine code gen assembly", .{});
    }

    fn genPtrToInt(self: *Function, inst: *ir.Inst.PtrToInt) !MCValue {
        // no-op
        return self.resolveInst(inst.args.ptr);
    }

    fn resolveInst(self: *Function, inst: *ir.Inst) !MCValue {
        if (inst.cast(ir.Inst.Constant)) |const_inst| {
            switch (inst.ty.zigTypeTag()) {
                .Int => {
                    const info = inst.ty.intInfo(self.module.target);
                    const ptr_bits = self.module.target.cpu.arch.ptrBitWidth();
                    if (info.bits > ptr_bits or info.signed) {
                        return self.fail(inst.src, "TODO const int bigger than ptr and signed int", .{});
                    }
                    return MCValue{ .immediate = const_inst.val.toUnsignedInt() };
                },
                else => return self.fail(inst.src, "TODO implement const of type '{}'", .{inst.ty}),
            }
        } else {
            return self.inst_table.getValue(inst).?;
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
