const std = @import("std");
const elf = std.elf;

threadlocal var foo: u8 = 42;

test "Check ELF header" {
    // PIE executables are marked as ET_DYN, regular exes as ET_EXEC.
    const header = @intToPtr(*elf.Ehdr, std.process.getBaseAddress());
    try std.testing.expectEqual(elf.ET.DYN, header.e_type);
}

test "TLS is initialized" {
    // Ensure the TLS is initialized by the startup code.
    try std.testing.expectEqual(@as(u8, 42), foo);
}
