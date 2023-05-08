const std = @import("../std.zig");

fn writeUnknownReg(writer: anytype, reg_number: u8) !void {
    try writer.print("reg{}", .{ reg_number });
}

pub fn writeRegisterName(writer: anytype, arch: ?std.Target.Cpu.Arch, reg_number: u8) !void {
    if (arch) |a| {
        switch (a) {
            .x86_64 => {
                switch (reg_number) {
                    0 => try writer.writeAll("RAX"),
                    1 => try writer.writeAll("RDX"),
                    2 => try writer.writeAll("RCX"),
                    3 => try writer.writeAll("RBX"),
                    4 => try writer.writeAll("RSI"),
                    5 => try writer.writeAll("RDI"),
                    6 => try writer.writeAll("RBP"),
                    7 => try writer.writeAll("RSP"),
                    8...15 => try writer.print("R{}", .{ reg_number }),
                    16 => try writer.writeAll("RIP"),
                    17...32 => try writer.print("XMM{}", .{ reg_number - 17 }),
                    33...40 => try writer.print("ST{}", .{ reg_number - 33 }),
                    41...48 => try writer.print("MM{}", .{ reg_number - 41 }),
                    49 => try writer.writeAll("RFLAGS"),
                    50 => try writer.writeAll("ES"),
                    51 => try writer.writeAll("CS"),
                    52 => try writer.writeAll("SS"),
                    53 => try writer.writeAll("DS"),
                    54 => try writer.writeAll("FS"),
                    55 => try writer.writeAll("GS"),
                    // 56-57 Reserved
                    58 => try writer.writeAll("FS.BASE"),
                    59 => try writer.writeAll("GS.BASE"),
                    // 60-61 Reserved
                    62 => try writer.writeAll("TR"),
                    63 => try writer.writeAll("LDTR"),
                    64 => try writer.writeAll("MXCSR"),
                    65 => try writer.writeAll("FCW"),
                    66 => try writer.writeAll("FSW"),
                    67...82 => try writer.print("XMM{}", .{ reg_number - 51 }),
                    // 83-117 Reserved
                    118...125 => try writer.print("K{}", .{ reg_number - 118 }),
                    // 126-129 Reserved
                    else => try writeUnknownReg(writer, reg_number),
                }
            },

            // TODO: Add x86, aarch64

            else => try writeUnknownReg(writer, reg_number),
        }
    } else try writeUnknownReg(writer, reg_number);
}
