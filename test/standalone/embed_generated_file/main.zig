const std = @import("std");
const blah = @embedFile("bootloader.elf");

test {
    comptime {
        std.debug.assert(std.mem.eql(u8, blah[1..][0..3], "ELF"));
    }
}
