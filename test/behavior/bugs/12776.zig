const std = @import("std");
const builtin = @import("builtin");

const RAM = struct {
    data: [0xFFFF + 1]u8,
    fn new() !RAM {
        return RAM{ .data = [_]u8{0} ** 0x10000 };
    }
    fn get(self: *RAM, addr: u16) u8 {
        return self.data[addr];
    }
};

const CPU = packed struct {
    interrupts: bool,
    ram: *RAM,
    fn new(ram: *RAM) !CPU {
        return CPU{
            .ram = ram,
            .interrupts = false,
        };
    }
    fn tick(self: *CPU) !void {
        var queued_interrupts = self.ram.get(0xFFFF) & self.ram.get(0xFF0F);
        if (self.interrupts and queued_interrupts != 0) {
            self.interrupts = false;
        }
    }
};

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) {
        // Careful enabling this test, fails randomly.
        return error.SkipZigTest;
    }

    var ram = try RAM.new();
    var cpu = try CPU.new(&ram);
    try cpu.tick();
    try std.testing.expect(cpu.interrupts == false);
}
