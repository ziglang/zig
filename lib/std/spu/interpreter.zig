const std = @import("std");
usingnamespace @import("defines.zig");

const Bus = struct {
    ROM: []u8,
    RAM0: []u8,
    RAM1: []u8,
    serialIn: fn () u8,
    serialOut: fn (value: u8) void,

    pub fn init(allocator: *std.mem.Allocator, serialIn: fn () u8, serialOut: fn (value: u8) void) !Bus {
        const ROM = try allocator.alloc(u8, 0x4000);
        errdefer allocator.free(ROM);
        const RAM0 = try allocator.alloc(u8, 0x1000);
        errdefer allocator.free(ROM);
        const RAM1 = try allocator.alloc(u8, 0x8000);

        return Bus{
            .ROM = ROM,
            .RAM0 = RAM0,
            .RAM1 = RAM1,
            .serialIn = serialIn,
            .serialOut = serialOut,
        };
    }

    pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
        allocator.free(self.ROM);
        allocator.free(self.RAM0);
        allocator.free(self.RAM1);
        self.* = undefined;
    }

    pub fn read(self: @This(), comptime T: type, addr: u16) !T {
        if (addr < 0x4000) {
            return @ptrCast(*align(1) T, &self.ROM[addr]).*;
        } else if (addr >= 0x6000 and addr < 0x7000) {
            return @ptrCast(*align(1) T, &self.RAM0[addr - 0x6000]).*;
        } else if (addr >= 0x8000 and addr < 0x10000) {
            return @ptrCast(*align(1) T, &self.RAM1[addr - 0x8000]).*;
        } else if (addr >= 0x4000 and addr < 0x5000 and @typeInfo(T) == .Int) {
            return @intCast(T, self.serialIn());
        }
        return error.BusError;
    }

    pub fn write(self: *@This(), comptime T: type, addr: u16, val: T) !void {
        if (addr < 0x4000) {
            return error.BusError;
        }
        if (addr >= 0x6000 and addr < 0x7000) {
            // RAM0
            @ptrCast(*align(2) T, @alignCast(2, &self.RAM0[addr - 0x6000])).* = val;
        } else if (addr >= 0x8000 and addr < 0x10000) {
            @ptrCast(*align(2) T, @alignCast(2, &self.RAM1[addr - 0x8000])).* = val;
        } else if (addr >= 0x4000 and addr < 0x5000) {
            // Serial
            self.serialOut(val);
        } else {
            return error.BusError;
        }
    }
};

allocator: *std.mem.Allocator,
ip: u16 = 0,
sp: u16 = 0,
bp: u16 = 0,
fr: FlagRegister = @bitCast(FlagRegister, @as(u16, 0)),
bus: *Bus,
/// This is set to true when we hit an undefined0 instruction, allowing it to
/// be used as a trap for testing purposes
undefined0: bool = false,

pub fn init(allocator: *std.mem.Allocator, serialIn: fn () u8, serialOut: fn (value: u8) void) !@This() {
    return @This(){
        .bus = try Bus.init(allocator, serialIn, serialOut),
        .allocator = args.allocator,
    };
}

pub fn deinit(self: *@This()) void {
    self.bus.deinit(self.allocator);
    self.* = undefined;
}

pub fn ExecuteBlock(self: *@This(), comptime size: ?u32) !void {
    var count: usize = 0;
    while (size == null or count < size.?) {
        count += 1;
        var instruction: Instruction = try self.bus.read(Instruction, self.ip);
        while (@bitCast(u16, instruction) == 0) {
            // Skip no-ops
            self.ip += 2;
            instruction = try self.bus.read(Instruction, self.ip);
        }

        self.ip += 2;

        const execute = switch (instruction.condition) {
            .always => true,
            .not_zero => !self.fr.zero,
            .when_zero => self.fr.zero,
            .overflow => self.fr.carry,
            ExecutionCondition.greater_or_equal_zero => !self.fr.negative,
            else => return error.unimplemented,
        };

        if (execute) {
            const val0 = switch (instruction.input0) {
                .zero => @as(u16, 0),
                .immediate => i: {
                    const val = try self.bus.read(u16, @intCast(u16, self.ip));
                    self.ip +%= 2;
                    break :i val;
                },
                else => |e| e: {
                    // peek or pop; show value at current SP, and if pop, increment sp
                    const val = try self.bus.read(u16, self.sp);
                    if (e == .pop) {
                        self.sp +%= 2;
                    }
                    break :e val;
                },
            };
            const val1 = switch (instruction.input1) {
                .zero => @as(u16, 0),
                .immediate => i: {
                    const val = try self.bus.read(u16, @intCast(u16, self.ip));
                    self.ip += 2;
                    break :i val;
                },
                else => |e| e: {
                    // peek or pop; show value at current SP, and if pop, increment sp
                    const val = try self.bus.read(u16, self.sp);
                    if (e == .pop) {
                        self.sp +%= 2;
                    }
                    break :e val;
                },
            };

            const output: u16 = switch (instruction.command) {
                .get => try self.bus.read(u16, self.bp +% (2 *% val0)),
                .set => a: {
                    try self.bus.write(u16, self.bp +% 2 *% val0, val1);
                    break :a val1;
                },
                .load8 => try self.bus.read(u8, val0),
                .load16 => try self.bus.read(u16, val0),
                .store8 => a: {
                    const val = @truncate(u8, val1);
                    try self.bus.write(u8, val0, @intCast(u8, val));
                    break :a val;
                },
                .store16 => a: {
                    try self.bus.write(u16, val0, val1);
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
                .undefined1 => return error.BadInstruction,
                .signext => if ((val0 & 0x80) != 0)
                    (val0 & 0xFF) | 0xFF00
                else
                    (val0 & 0xFF),
                else => return error.unimplemented,
            };

            switch (instruction.output) {
                .discard => {},
                .push => {
                    self.sp -%= 2;
                    try self.bus.write(u16, self.sp, output);
                },
                .jump => {
                    self.ip = output;
                    if (!(instruction.command == .copy and instruction.input0 == .immediate)) {
                        // Not absolute. Break, for compatibility with JIT.
                        break;
                    }
                },
                else => return error.unimplemented,
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
