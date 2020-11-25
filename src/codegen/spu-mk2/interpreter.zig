const std = @import("std");
const log = std.log.scoped(.SPU_2_Interpreter);
const spu = @import("../spu-mk2.zig");
const FlagRegister = spu.FlagRegister;
const Instruction = spu.Instruction;
const ExecutionCondition = spu.ExecutionCondition;

pub fn Interpreter(comptime Bus: type) type {
    return struct {
        ip: u16 = 0,
        sp: u16 = undefined,
        bp: u16 = undefined,
        fr: FlagRegister = @bitCast(FlagRegister, @as(u16, 0)),
        /// This is set to true when we hit an undefined0 instruction, allowing it to
        /// be used as a trap for testing purposes
        undefined0: bool = false,
        /// This is set to true when we hit an undefined1 instruction, allowing it to
        /// be used as a trap for testing purposes. undefined1 is used as a breakpoint.
        undefined1: bool = false,
        bus: Bus,

        pub fn ExecuteBlock(self: *@This(), comptime size: ?u32) !void {
            var count: usize = 0;
            while (size == null or count < size.?) {
                count += 1;
                var instruction = @bitCast(Instruction, self.bus.read16(self.ip));

                log.debug("Executing {}\n", .{instruction});

                self.ip +%= 2;

                const execute = switch (instruction.condition) {
                    .always => true,
                    .not_zero => !self.fr.zero,
                    .when_zero => self.fr.zero,
                    .overflow => self.fr.carry,
                    ExecutionCondition.greater_or_equal_zero => !self.fr.negative,
                    else => return error.Unimplemented,
                };

                if (execute) {
                    const val0 = switch (instruction.input0) {
                        .zero => @as(u16, 0),
                        .immediate => i: {
                            const val = self.bus.read16(@intCast(u16, self.ip));
                            self.ip +%= 2;
                            break :i val;
                        },
                        else => |e| e: {
                            // peek or pop; show value at current SP, and if pop, increment sp
                            const val = self.bus.read16(self.sp);
                            if (e == .pop) {
                                self.sp +%= 2;
                            }
                            break :e val;
                        },
                    };
                    const val1 = switch (instruction.input1) {
                        .zero => @as(u16, 0),
                        .immediate => i: {
                            const val = self.bus.read16(@intCast(u16, self.ip));
                            self.ip +%= 2;
                            break :i val;
                        },
                        else => |e| e: {
                            // peek or pop; show value at current SP, and if pop, increment sp
                            const val = self.bus.read16(self.sp);
                            if (e == .pop) {
                                self.sp +%= 2;
                            }
                            break :e val;
                        },
                    };

                    const output: u16 = switch (instruction.command) {
                        .get => self.bus.read16(self.bp +% (2 *% val0)),
                        .set => a: {
                            self.bus.write16(self.bp +% 2 *% val0, val1);
                            break :a val1;
                        },
                        .load8 => self.bus.read8(val0),
                        .load16 => self.bus.read16(val0),
                        .store8 => a: {
                            const val = @truncate(u8, val1);
                            self.bus.write8(val0, val);
                            break :a val;
                        },
                        .store16 => a: {
                            self.bus.write16(val0, val1);
                            break :a val1;
                        },
                        .copy => val0,
                        .add => a: {
                            var val: u16 = undefined;
                            self.fr.carry = @addWithOverflow(u16, val0, val1, &val);
                            break :a val;
                        },
                        .sub => a: {
                            var val: u16 = undefined;
                            self.fr.carry = @subWithOverflow(u16, val0, val1, &val);
                            break :a val;
                        },
                        .spset => a: {
                            self.sp = val0;
                            break :a val0;
                        },
                        .bpset => a: {
                            self.bp = val0;
                            break :a val0;
                        },
                        .frset => a: {
                            const val = (@bitCast(u16, self.fr) & val1) | (val0 & ~val1);
                            self.fr = @bitCast(FlagRegister, val);
                            break :a val;
                        },
                        .bswap => (val0 >> 8) | (val0 << 8),
                        .bpget => self.bp,
                        .spget => self.sp,
                        .ipget => self.ip +% (2 *% val0),
                        .lsl => val0 << 1,
                        .lsr => val0 >> 1,
                        .@"and" => val0 & val1,
                        .@"or" => val0 | val1,
                        .xor => val0 ^ val1,
                        .not => ~val0,
                        .undefined0 => {
                            self.undefined0 = true;
                            // Break out of the loop, and let the caller decide what to do
                            return;
                        },
                        .undefined1 => {
                            self.undefined1 = true;
                            // Break out of the loop, and let the caller decide what to do
                            return;
                        },
                        .signext => if ((val0 & 0x80) != 0)
                            (val0 & 0xFF) | 0xFF00
                        else
                            (val0 & 0xFF),
                        else => return error.Unimplemented,
                    };

                    switch (instruction.output) {
                        .discard => {},
                        .push => {
                            self.sp -%= 2;
                            self.bus.write16(self.sp, output);
                        },
                        .jump => {
                            self.ip = output;
                        },
                        else => return error.Unimplemented,
                    }
                    if (instruction.modify_flags) {
                        self.fr.negative = (output & 0x8000) != 0;
                        self.fr.zero = (output == 0x0000);
                    }
                } else {
                    if (instruction.input0 == .immediate) self.ip +%= 2;
                    if (instruction.input1 == .immediate) self.ip +%= 2;
                    break;
                }
            }
        }
    };
}
