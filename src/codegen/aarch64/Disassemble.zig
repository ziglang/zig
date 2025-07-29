case: Case = .lower,
mnemonic_operands_separator: []const u8 = " ",
operands_separator: []const u8 = ", ",
enable_aliases: bool = true,

pub const Case = enum { lower, upper };

pub fn printInstruction(dis: Disassemble, inst: Instruction, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    unallocated: switch (inst.decode()) {
        .unallocated => break :unallocated,
        .reserved => |reserved| switch (reserved.decode()) {
            .unallocated => break :unallocated,
            .udf => |udf| return writer.print("{f}{s}#0x{x}", .{
                fmtCase(.udf, dis.case),
                dis.mnemonic_operands_separator,
                udf.imm16,
            }),
        },
        .sme => {},
        .sve => {},
        .data_processing_immediate => |data_processing_immediate| switch (data_processing_immediate.decode()) {
            .unallocated => break :unallocated,
            .pc_relative_addressing => |pc_relative_addressing| {
                const group = pc_relative_addressing.group;
                const imm = (@as(i33, group.immhi) << 2 | @as(i33, group.immlo) << 0) + @as(i33, switch (group.op) {
                    .adr => Instruction.size,
                    .adrp => 0,
                });
                return writer.print("{f}{s}{f}{s}.{c}0x{x}", .{
                    fmtCase(group.op, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decodeInteger(.doubleword, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    @as(u8, if (imm < 0) '-' else '+'),
                    switch (group.op) {
                        .adr => @abs(imm),
                        .adrp => @abs(imm) << 12,
                    },
                });
            },
            .add_subtract_immediate => |add_subtract_immediate| {
                const group = add_subtract_immediate.group;
                const op = group.op;
                const S = group.S;
                const sf = group.sf;
                const sh = group.sh;
                const imm12 = group.imm12;
                const Rn = group.Rn.decodeInteger(sf, .{ .sp = true });
                const Rd = group.Rd.decodeInteger(sf, .{ .sp = !S });
                const elide_shift = sh == .@"0";
                if (dis.enable_aliases and op == .add and S == false and elide_shift and imm12 == 0 and
                    (Rn.alias == .sp or Rd.alias == .sp)) try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(.mov, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                }) else try writer.print("{f}{s}{s}{f}{s}{f}{s}#0x{x}", .{
                    fmtCase(op, dis.case),
                    if (S) "s" else "",
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    imm12,
                });
                return if (!elide_shift) writer.print("{s}{f} #{s}", .{
                    dis.operands_separator,
                    fmtCase(.lsl, dis.case),
                    @tagName(sh),
                });
            },
            .add_subtract_immediate_with_tags => {},
            .logical_immediate => |logical_immediate| {
                const decoded = logical_immediate.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = logical_immediate.group;
                const sf = group.sf;
                const decoded_imm = group.imm.decodeImmediate(sf);
                const imm = switch (sf) {
                    .word => @as(i32, @bitCast(@as(u32, @intCast(decoded_imm)))),
                    .doubleword => @as(i64, @bitCast(decoded_imm)),
                };
                const Rn = group.Rn.decodeInteger(sf, .{});
                const Rd = group.Rd.decodeInteger(sf, .{ .sp = decoded != .ands });
                return if (dis.enable_aliases and decoded == .orr and Rn.alias == .zr and !group.imm.moveWidePreferred(sf)) writer.print("{f}{s}{f}{s}#{s}0x{x}", .{
                    fmtCase(.mov, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    if (imm < 0) "-" else "",
                    @abs(imm),
                }) else if (dis.enable_aliases and decoded == .ands and Rd.alias == .zr) writer.print("{f}{s}{f}{s}#{s}0x{x}", .{
                    fmtCase(.tst, dis.case),
                    dis.mnemonic_operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    if (imm < 0) "-" else "",
                    @abs(imm),
                }) else writer.print("{f}{s}{f}{s}{f}{s}#0x{x}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    decoded_imm,
                });
            },
            .move_wide_immediate => |move_wide_immediate| {
                const decoded = move_wide_immediate.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = move_wide_immediate.group;
                const sf = group.sf;
                const hw = group.hw;
                const imm16 = group.imm16;
                const Rd = group.Rd.decodeInteger(sf, .{});
                const elide_shift = hw == .@"0";
                if (dis.enable_aliases and switch (decoded) {
                    .unallocated => unreachable,
                    .movz => elide_shift or group.imm16 != 0,
                    .movn => (elide_shift or group.imm16 != 0) and switch (sf) {
                        .word => group.imm16 != std.math.maxInt(u16),
                        .doubleword => true,
                    },
                    .movk => false,
                }) {
                    const decoded_imm = switch (sf) {
                        .word => @as(i32, @bitCast(@as(u32, group.imm16) << @intCast(hw.int()))),
                        .doubleword => @as(i64, @bitCast(@as(u64, group.imm16) << hw.int())),
                    };
                    const imm = switch (decoded) {
                        .unallocated => unreachable,
                        .movz => decoded_imm,
                        .movn => ~decoded_imm,
                        .movk => unreachable,
                    };
                    return writer.print("{f}{s}{f}{s}#{s}0x{x}", .{
                        fmtCase(.mov, dis.case),
                        dis.mnemonic_operands_separator,
                        Rd.fmtCase(dis.case),
                        dis.operands_separator,
                        if (imm < 0) "-" else "",
                        @abs(imm),
                    });
                }
                try writer.print("{f}{s}{f}{s}#0x{x}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    imm16,
                });
                return if (!elide_shift) writer.print("{s}{f} #{s}", .{
                    dis.operands_separator,
                    fmtCase(.lsl, dis.case),
                    @tagName(hw),
                });
            },
            .bitfield => |bitfield| {
                const decoded = bitfield.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = bitfield.group;
                const sf = group.sf;
                return writer.print("{f}{s}{f}{s}{f}{s}#{d}{s}#{d}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.imm.immr,
                    dis.operands_separator,
                    group.imm.imms,
                });
            },
            .extract => |extract| {
                const decoded = extract.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = extract.group;
                const sf = group.sf;
                return writer.print("{f}{s}{f}{s}{f}{s}{f}{s}#{d}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rm.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.imms,
                });
            },
        },
        .branch_exception_generating_system => |branch_exception_generating_system| switch (branch_exception_generating_system.decode()) {
            .unallocated => break :unallocated,
            .conditional_branch_immediate => |conditional_branch_immediate| {
                const decoded = conditional_branch_immediate.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = conditional_branch_immediate.group;
                const imm = @as(i21, group.imm19);
                return writer.print("{f}.{f}{s}.{c}0x{x}", .{
                    fmtCase(decoded, dis.case),
                    fmtCase(group.cond, dis.case),
                    dis.mnemonic_operands_separator,
                    @as(u8, if (imm < 0) '-' else '+'),
                    @abs(imm) << 2,
                });
            },
            .exception_generating => |exception_generating| {
                const decoded = exception_generating.decode();
                switch (decoded) {
                    .unallocated => break :unallocated,
                    .svc, .hvc, .smc, .brk, .hlt, .tcancel => {},
                    .dcps1, .dcps2, .dcps3 => switch (exception_generating.group.imm16) {
                        0 => return writer.print("{f}", .{fmtCase(decoded, dis.case)}),
                        else => {},
                    },
                }
                return switch (exception_generating.group.imm16) {
                    0 => writer.print("{f}{s}#0", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                    }),
                    else => writer.print("{f}{s}#0x{x}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        exception_generating.group.imm16,
                    }),
                };
            },
            .system_register_argument => {},
            .hints => |hints| switch (hints.decode()) {
                .hint => |hint| return writer.print("{f}{s}#0x{x}", .{
                    fmtCase(.hint, dis.case),
                    dis.mnemonic_operands_separator,
                    @as(u7, hint.CRm) << 3 | @as(u7, hint.op2) << 0,
                }),
                else => |decoded| return writer.print("{f}", .{fmtCase(decoded, dis.case)}),
            },
            .barriers => {},
            .pstate => {},
            .system_result => {},
            .system => {},
            .system_register_move => {},
            .unconditional_branch_register => |unconditional_branch_register| {
                const decoded = unconditional_branch_register.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = unconditional_branch_register.group;
                const Rn = group.Rn.decodeInteger(.doubleword, .{});
                try writer.print("{f}", .{fmtCase(decoded, dis.case)});
                return if (decoded != .ret or Rn.alias != .r30) try writer.print("{s}{f}", .{
                    dis.mnemonic_operands_separator,
                    Rn.fmtCase(dis.case),
                });
            },
            .unconditional_branch_immediate => |unconditional_branch_immediate| {
                const group = unconditional_branch_immediate.group;
                const imm = @as(i28, group.imm26);
                return writer.print("{f}{s}.{c}0x{x}", .{
                    fmtCase(group.op, dis.case),
                    dis.mnemonic_operands_separator,
                    @as(u8, if (imm < 0) '-' else '+'),
                    @abs(imm) << 2,
                });
            },
            .compare_branch_immediate => |compare_branch_immediate| {
                const group = compare_branch_immediate.group;
                const imm = @as(i21, group.imm19);
                return writer.print("{f}{s}{f}{s}.{c}0x{x}", .{
                    fmtCase(group.op, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rt.decodeInteger(group.sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    @as(u8, if (imm < 0) '-' else '+'),
                    @abs(imm) << 2,
                });
            },
            .test_branch_immediate => |test_branch_immediate| {
                const group = test_branch_immediate.group;
                const imm = @as(i16, group.imm14);
                return writer.print("{f}{s}{f}{s}#0x{d}{s}.{c}0x{x}", .{
                    fmtCase(group.op, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rt.decodeInteger(@enumFromInt(group.b5), .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    @as(u6, group.b5) << 5 |
                        @as(u6, group.b40) << 0,
                    dis.operands_separator,
                    @as(u8, if (imm < 0) '-' else '+'),
                    @abs(imm) << 2,
                });
            },
        },
        .load_store => |load_store| switch (load_store.decode()) {
            .unallocated => break :unallocated,
            .register_literal => {},
            .memory => {},
            .no_allocate_pair_offset => {},
            .register_pair_post_indexed => |register_pair_post_indexed| switch (register_pair_post_indexed.decode()) {
                .integer => |integer| {
                    const decoded = integer.decode();
                    if (decoded == .unallocated) break :unallocated;
                    const group = integer.group;
                    const sf: aarch64.encoding.Register.IntegerSize = @enumFromInt(group.opc >> 1);
                    return writer.print("{f}{s}{f}{s}{f}{s}[{f}]{s}#{s}0x{x}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                        dis.operands_separator,
                        if (group.imm7 < 0) "-" else "",
                        @as(u10, @abs(group.imm7)) << (@as(u2, 2) + @intFromEnum(sf)),
                    });
                },
                .vector => |vector| {
                    const decoded = vector.decode();
                    if (decoded == .unallocated) break :unallocated;
                    const group = vector.group;
                    const vs = group.opc.decode();
                    return writer.print("{f}{s}{f}{s}{f}{s}[{f}]{s}#{s}0x{x}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeVector(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decodeVector(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                        dis.operands_separator,
                        if (group.imm7 < 0) "-" else "",
                        @as(u11, @abs(group.imm7)) << (@as(u3, 2) + @intFromEnum(vs)),
                    });
                },
            },
            .register_pair_offset => |register_pair_offset| switch (register_pair_offset.decode()) {
                .integer => |integer| {
                    const decoded = integer.decode();
                    if (decoded == .unallocated) break :unallocated;
                    const group = integer.group;
                    const sf: aarch64.encoding.Register.IntegerSize = @enumFromInt(group.opc >> 1);
                    try writer.print("{f}{s}{f}{s}{f}{s}[{f}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                    });
                    if (group.imm7 != 0) try writer.print("{s}#{s}0x{x}", .{
                        dis.operands_separator,
                        if (group.imm7 < 0) "-" else "",
                        @as(u10, @abs(group.imm7)) << (@as(u2, 2) + @intFromEnum(sf)),
                    });
                    return writer.writeByte(']');
                },
                .vector => |vector| {
                    const decoded = vector.decode();
                    if (decoded == .unallocated) break :unallocated;
                    const group = vector.group;
                    const vs = group.opc.decode();
                    try writer.print("{f}{s}{f}{s}{f}{s}[{f}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeVector(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decodeVector(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                    });
                    if (group.imm7 != 0) try writer.print("{s}#{s}0x{x}", .{
                        dis.operands_separator,
                        if (group.imm7 < 0) "-" else "",
                        @as(u11, @abs(group.imm7)) << (@as(u3, 2) + @intFromEnum(vs)),
                    });
                    return writer.writeByte(']');
                },
            },
            .register_pair_pre_indexed => |register_pair_pre_indexed| switch (register_pair_pre_indexed.decode()) {
                .integer => |integer| {
                    const decoded = integer.decode();
                    if (decoded == .unallocated) break :unallocated;
                    const group = integer.group;
                    const sf: aarch64.encoding.Register.IntegerSize = @enumFromInt(group.opc >> 1);
                    return writer.print("{f}{s}{f}{s}{f}{s}[{f}{s}#{s}0x{x}]!", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                        dis.operands_separator,
                        if (group.imm7 < 0) "-" else "",
                        @as(u10, @abs(group.imm7)) << (@as(u2, 2) + @intFromEnum(sf)),
                    });
                },
                .vector => |vector| {
                    const decoded = vector.decode();
                    if (decoded == .unallocated) break :unallocated;
                    const group = vector.group;
                    const vs = group.opc.decode();
                    return writer.print("{f}{s}{f}{s}{f}{s}[{f}{s}#{s}0x{x}]!", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeVector(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decodeVector(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                        dis.operands_separator,
                        if (group.imm7 < 0) "-" else "",
                        @as(u11, @abs(group.imm7)) << (@as(u3, 2) + @intFromEnum(vs)),
                    });
                },
            },
            .register_unscaled_immediate => {},
            .register_immediate_post_indexed => |register_immediate_post_indexed| switch (register_immediate_post_indexed.decode()) {
                .integer => |integer| {
                    const decoded = integer.decode();
                    const sf: aarch64.encoding.Register.IntegerSize = switch (decoded) {
                        .unallocated => break :unallocated,
                        .strb, .ldrb, .strh, .ldrh => .word,
                        inline .ldrsb, .ldrsh => |encoded| switch (encoded.opc0) {
                            0b0 => .doubleword,
                            0b1 => .word,
                        },
                        .ldrsw => .doubleword,
                        inline .str, .ldr => |encoded| encoded.sf,
                    };
                    const group = integer.group;
                    return writer.print("{f}{s}{f}{s}[{f}]{s}#{s}0x{x}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                        dis.operands_separator,
                        if (group.imm9 < 0) "-" else "",
                        @abs(group.imm9),
                    });
                },
                .vector => {},
            },
            .register_unprivileged => {},
            .register_immediate_pre_indexed => |register_immediate_pre_indexed| switch (register_immediate_pre_indexed.decode()) {
                .integer => |integer| {
                    const decoded = integer.decode();
                    const sf: aarch64.encoding.Register.IntegerSize = switch (decoded) {
                        .unallocated => break :unallocated,
                        inline .ldrsb, .ldrsh => |encoded| switch (encoded.opc0) {
                            0b0 => .doubleword,
                            0b1 => .word,
                        },
                        .strb, .ldrb, .strh, .ldrh => .word,
                        .ldrsw => .doubleword,
                        inline .str, .ldr => |encoded| encoded.sf,
                    };
                    const group = integer.group;
                    return writer.print("{f}{s}{f}{s}[{f}{s}#{s}0x{x}]!", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                        dis.operands_separator,
                        if (group.imm9 < 0) "-" else "",
                        @abs(group.imm9),
                    });
                },
                .vector => |vector| {
                    const decoded = vector.decode();
                    if (decoded == .unallocated) break :unallocated;
                    const group = vector.group;
                    return writer.print("{f}{s}{f}{s}[{f}{s}#{s}0x{x}]!", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeVector(group.opc1.decode(group.size)).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                        dis.operands_separator,
                        if (group.imm9 < 0) "-" else "",
                        @abs(group.imm9),
                    });
                },
            },
            .register_register_offset => |register_register_offset| switch (register_register_offset.decode()) {
                .integer => |integer| {
                    const decoded = integer.decode();
                    const sf: aarch64.encoding.Register.IntegerSize = switch (decoded) {
                        .unallocated, .prfm => break :unallocated,
                        .strb, .ldrb, .strh, .ldrh => .word,
                        inline .ldrsb, .ldrsh => |encoded| switch (encoded.opc0) {
                            0b0 => .doubleword,
                            0b1 => .word,
                        },
                        .ldrsw => .doubleword,
                        inline .str, .ldr => |encoded| encoded.sf,
                    };
                    const group = integer.group;
                    try writer.print("{f}{s}{f}{s}[{f}{s}{f}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rm.decodeInteger(group.option.sf(), .{}).fmtCase(dis.case),
                    });
                    if (group.option != .lsl or group.S) {
                        try writer.print("{s}{f}", .{
                            dis.operands_separator,
                            fmtCase(group.option, dis.case),
                        });
                        if (group.S) try writer.print(" #{d}", .{
                            @intFromEnum(group.size),
                        });
                    }
                    return writer.writeByte(']');
                },
                .vector => {},
            },
            .register_unsigned_immediate => |register_unsigned_immediate| switch (register_unsigned_immediate.decode()) {
                .integer => |integer| {
                    const decoded = integer.decode();
                    const sf: aarch64.encoding.Register.IntegerSize = switch (decoded) {
                        .unallocated, .prfm => break :unallocated,
                        .strb, .ldrb, .strh, .ldrh => .word,
                        inline .ldrsb, .ldrsh => |encoded| switch (encoded.opc0) {
                            0b0 => .doubleword,
                            0b1 => .word,
                        },
                        .ldrsw => .doubleword,
                        inline .str, .ldr => |encoded| encoded.sf,
                    };
                    const group = integer.group;
                    try writer.print("{f}{s}{f}{s}[{f}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decodeInteger(sf, .{}).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decodeInteger(.doubleword, .{ .sp = true }).fmtCase(dis.case),
                    });
                    if (group.imm12 > 0) try writer.print("{s}#0x{x}", .{
                        dis.operands_separator,
                        @as(u15, group.imm12) << @intFromEnum(group.size),
                    });
                    return writer.writeByte(']');
                },
                .vector => {},
            },
        },
        .data_processing_register => |data_processing_register| switch (data_processing_register.decode()) {
            .unallocated => break :unallocated,
            .data_processing_two_source => |data_processing_two_source| {
                const decoded = data_processing_two_source.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = data_processing_two_source.group;
                const sf = group.sf;
                return writer.print("{f}{s}{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rm.decodeInteger(sf, .{}).fmtCase(dis.case),
                });
            },
            .data_processing_one_source => |data_processing_one_source| {
                const decoded = data_processing_one_source.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = data_processing_one_source.group;
                const sf = group.sf;
                return writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decodeInteger(sf, .{}).fmtCase(dis.case),
                });
            },
            .logical_shifted_register => |logical_shifted_register| {
                const decoded = logical_shifted_register.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = logical_shifted_register.group;
                const sf = group.sf;
                const shift = group.shift;
                const Rm = group.Rm.decodeInteger(sf, .{});
                const amount = group.imm6;
                const Rn = group.Rn.decodeInteger(sf, .{});
                const Rd = group.Rd.decodeInteger(sf, .{});
                const elide_shift = shift == .lsl and amount == 0;
                if (dis.enable_aliases and switch (decoded) {
                    else => false,
                    .orr => elide_shift,
                    .orn => true,
                } and Rn.alias == .zr) try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(@as(enum { mov, mvn }, switch (decoded) {
                        else => unreachable,
                        .orr => .mov,
                        .orn => .mvn,
                    }), dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                }) else if (dis.enable_aliases and decoded == .ands and Rd.alias == .zr) try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(.tst, dis.case),
                    dis.mnemonic_operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                }) else try writer.print("{f}{s}{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                });
                return if (!elide_shift) writer.print("{s}{f} #{d}", .{
                    dis.operands_separator,
                    fmtCase(shift, dis.case),
                    amount,
                });
            },
            .add_subtract_shifted_register => |add_subtract_shifted_register| {
                const decoded = add_subtract_shifted_register.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = add_subtract_shifted_register.group;
                const sf = group.sf;
                const shift = group.shift;
                const Rm = group.Rm.decodeInteger(sf, .{});
                const imm6 = group.imm6;
                const Rn = group.Rn.decodeInteger(sf, .{});
                const Rd = group.Rd.decodeInteger(sf, .{});
                if (dis.enable_aliases and group.S and Rd.alias == .zr) try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(@as(enum { cmn, cmp }, switch (group.op) {
                        .add => .cmn,
                        .sub => .cmp,
                    }), dis.case),
                    dis.mnemonic_operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                }) else if (dis.enable_aliases and group.op == .sub and Rn.alias == .zr) try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(@as(enum { neg, negs }, switch (group.S) {
                        false => .neg,
                        true => .negs,
                    }), dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                }) else try writer.print("{f}{s}{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                });
                return if (shift != .lsl or imm6 != 0) return writer.print("{s}{f} #{d}", .{
                    dis.operands_separator,
                    fmtCase(shift, dis.case),
                    imm6,
                });
            },
            .add_subtract_extended_register => |add_subtract_extended_register| {
                const decoded = add_subtract_extended_register.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = add_subtract_extended_register.group;
                const sf = group.sf;
                const Rm = group.Rm.decodeInteger(group.option.sf(), .{});
                const Rn = group.Rn.decodeInteger(sf, .{ .sp = true });
                const Rd = group.Rd.decodeInteger(sf, .{ .sp = true });
                if (dis.enable_aliases and group.S and Rd.alias == .zr) try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(@as(enum { cmn, cmp }, switch (group.op) {
                        .add => .cmn,
                        .sub => .cmp,
                    }), dis.case),
                    dis.mnemonic_operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                }) else try writer.print("{f}{s}{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                });
                return if (group.option != @as(Instruction.DataProcessingRegister.AddSubtractExtendedRegister.Option, switch (sf) {
                    .word => .uxtw,
                    .doubleword => .uxtx,
                }) or group.imm3 != 0) writer.print("{s}{f} #{d}", .{
                    dis.operands_separator,
                    fmtCase(group.option, dis.case),
                    group.imm3,
                });
            },
            .add_subtract_with_carry => |add_subtract_with_carry| {
                const decoded = add_subtract_with_carry.decode();
                const group = add_subtract_with_carry.group;
                const sf = group.sf;
                const Rm = group.Rm.decodeInteger(sf, .{});
                const Rn = group.Rn.decodeInteger(sf, .{});
                const Rd = group.Rd.decodeInteger(sf, .{});
                return if (dis.enable_aliases and group.op == .sbc and Rn.alias == .zr) try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(@as(enum { ngc, ngcs }, switch (group.S) {
                        false => .ngc,
                        true => .ngcs,
                    }), dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                }) else try writer.print("{f}{s}{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                });
            },
            .rotate_right_into_flags => {},
            .evaluate_into_flags => {},
            .conditional_compare_register => {},
            .conditional_compare_immediate => {},
            .conditional_select => |conditional_select| {
                const decoded = conditional_select.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = conditional_select.group;
                const sf = group.sf;
                const Rm = group.Rm.decodeInteger(sf, .{});
                const cond = group.cond;
                const Rn = group.Rn.decodeInteger(sf, .{});
                const Rd = group.Rd.decodeInteger(sf, .{});
                return if (dis.enable_aliases and group.op != group.op2 and Rm.alias == .zr and cond != .al and cond != .nv and Rn.alias == Rm.alias) writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(@as(enum { cset, csetm }, switch (decoded) {
                        else => unreachable,
                        .csinc => .cset,
                        .csinv => .csetm,
                    }), dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    fmtCase(cond.invert(), dis.case),
                }) else if (dis.enable_aliases and decoded != .csel and cond != .al and cond != .nv and Rn.alias == Rm.alias) writer.print("{f}{s}{f}{s}{f}{s}{f}", .{
                    fmtCase(@as(enum { cinc, cinv, cneg }, switch (decoded) {
                        else => unreachable,
                        .csinc => .cinc,
                        .csinv => .cinv,
                        .csneg => .cneg,
                    }), dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    fmtCase(cond.invert(), dis.case),
                }) else writer.print("{f}{s}{f}{s}{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    Rm.fmtCase(dis.case),
                    dis.operands_separator,
                    fmtCase(cond, dis.case),
                });
            },
            .data_processing_three_source => |data_processing_three_source| {
                const decoded = data_processing_three_source.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = data_processing_three_source.group;
                const sf = group.sf;
                try writer.print("{f}{s}{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decodeInteger(sf, .{}).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rm.decodeInteger(sf, .{}).fmtCase(dis.case),
                });
                return switch (decoded) {
                    .unallocated => unreachable,
                    .madd, .msub, .smaddl, .smsubl, .umaddl, .umsubl => writer.print("{s}{f}", .{
                        dis.operands_separator,
                        group.Ra.decodeInteger(sf, .{}).fmtCase(dis.case),
                    }),
                    .smulh, .umulh => {},
                };
            },
        },
        .data_processing_vector => {},
    }
    return writer.print(".{f}{s}0x{x:0>8}", .{
        fmtCase(.word, dis.case),
        dis.mnemonic_operands_separator,
        @as(Instruction.Backing, @bitCast(inst)),
    });
}

fn fmtCase(tag: anytype, case: Case) struct {
    tag: []const u8,
    case: Case,
    pub fn format(data: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        for (data.tag) |c| try writer.writeByte(switch (data.case) {
            .lower => std.ascii.toLower(c),
            .upper => std.ascii.toUpper(c),
        });
    }
} {
    return .{ .tag = @tagName(tag), .case = case };
}

pub const RegisterFormatter = struct {
    reg: aarch64.encoding.Register,
    case: Case,
    pub fn format(data: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (data.reg.format) {
            .alias => try writer.print("{f}", .{fmtCase(data.reg.alias, data.case)}),
            .integer => |size| switch (data.reg.alias) {
                .r0,
                .r1,
                .r2,
                .r3,
                .r4,
                .r5,
                .r6,
                .r7,
                .r8,
                .r9,
                .r10,
                .r11,
                .r12,
                .r13,
                .r14,
                .r15,
                .r16,
                .r17,
                .r18,
                .r19,
                .r20,
                .r21,
                .r22,
                .r23,
                .r24,
                .r25,
                .r26,
                .r27,
                .r28,
                .r29,
                .r30,
                => |alias| try writer.print("{c}{d}", .{
                    size.prefix(),
                    @intFromEnum(alias.encode(.{})),
                }),
                .zr => try writer.print("{c}{f}", .{
                    size.prefix(),
                    fmtCase(data.reg.alias, data.case),
                }),
                else => try writer.print("{s}{f}", .{
                    switch (size) {
                        .word => "w",
                        .doubleword => "",
                    },
                    fmtCase(data.reg.alias, data.case),
                }),
            },
            .scalar => |size| try writer.print("{c}{d}", .{
                size.prefix(),
                @intFromEnum(data.reg.alias.encode(.{ .V = true })),
            }),
            .vector => |arrangement| try writer.print("{f}.{f}", .{
                fmtCase(data.reg.alias, data.case),
                fmtCase(arrangement, data.case),
            }),
            .element => |element| try writer.print("{f}.{c}[{d}]", .{
                fmtCase(data.reg.alias, data.case),
                element.size.prefix(),
                element.index,
            }),
        }
    }
};

const aarch64 = @import("../aarch64.zig");
const Disassemble = @This();
const Instruction = aarch64.encoding.Instruction;
const std = @import("std");
