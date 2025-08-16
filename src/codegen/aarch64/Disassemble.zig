case: Case = .lower,
mnemonic_operands_separator: []const u8 = " ",
operands_separator: []const u8 = ", ",
enable_aliases: bool = true,

pub const Case = enum {
    lower,
    upper,
    pub fn convert(case: Case, c: u8) u8 {
        return switch (case) {
            .lower => std.ascii.toLower(c),
            .upper => std.ascii.toUpper(c),
        };
    }
};

pub fn printInstruction(dis: Disassemble, inst: aarch64.encoding.Instruction, writer: *std.Io.Writer) std.Io.Writer.Error!void {
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
                    .adr => aarch64.encoding.Instruction.size,
                    .adrp => 0,
                });
                return writer.print("{f}{s}{f}{s}.{c}0x{x}", .{
                    fmtCase(group.op, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{}).x().fmtCase(dis.case),
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
                const Rn = group.Rn.decode(.{ .sp = true }).general(sf);
                const Rd = group.Rd.decode(.{ .sp = !S }).general(sf);
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
            .add_subtract_immediate_with_tags => |add_subtract_immediate_with_tags| {
                const decoded = add_subtract_immediate_with_tags.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = add_subtract_immediate_with_tags.group;
                return writer.print("{f}{s}{f}{s}{f}{s}#0x{x}{s}#0x{x}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .sp = true }).x().fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
                    dis.operands_separator,
                    @as(u10, group.uimm6) << 4,
                    dis.operands_separator,
                    group.uimm4,
                });
            },
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
                const Rn = group.Rn.decode(.{}).general(sf);
                const Rd = group.Rd.decode(.{ .sp = decoded != .ands }).general(sf);
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
                const Rd = group.Rd.decode(.{}).general(sf);
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
                const Rd = group.Rd.decode(.{}).general(sf);
                const Rn = group.Rn.decode(.{}).general(sf);
                return if (!dis.enable_aliases) writer.print("{f}{s}{f}{s}{f}{s}#{d}{s}#{d}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    group.imm.immr,
                    dis.operands_separator,
                    group.imm.imms,
                }) else if (group.imm.imms >= group.imm.immr) writer.print("{f}{s}{f}{s}{f}{s}#{d}{s}#{d}", .{
                    fmtCase(@as(enum { sbfx, bfxil, ubfx }, switch (decoded) {
                        .unallocated => unreachable,
                        .sbfm => .sbfx,
                        .bfm => .bfxil,
                        .ubfm => .ubfx,
                    }), dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
                    dis.operands_separator,
                    group.imm.immr,
                    dis.operands_separator,
                    switch (sf) {
                        .word => @as(u6, group.imm.imms - group.imm.immr) + 1,
                        .doubleword => @as(u7, group.imm.imms - group.imm.immr) + 1,
                    },
                }) else {
                    const prefer_bfc = switch (decoded) {
                        .unallocated => unreachable,
                        .sbfm, .ubfm => false,
                        .bfm => Rn.alias == .zr,
                    };
                    try writer.print("{f}{s}{f}", .{
                        fmtCase(@as(enum { sbfiz, bfc, bfi, ubfiz }, switch (decoded) {
                            .unallocated => unreachable,
                            .sbfm => .sbfiz,
                            .bfm => if (prefer_bfc) .bfc else .bfi,
                            .ubfm => .ubfiz,
                        }), dis.case),
                        dis.mnemonic_operands_separator,
                        Rd.fmtCase(dis.case),
                    });
                    if (!prefer_bfc) try writer.print("{s}{f}", .{
                        dis.operands_separator,
                        Rn.fmtCase(dis.case),
                    });
                    try writer.print("{s}#{d}{s}#{d}", .{
                        dis.operands_separator,
                        switch (sf) {
                            .word => -%@as(u5, @intCast(group.imm.immr)),
                            .doubleword => -%@as(u6, @intCast(group.imm.immr)),
                        },
                        dis.operands_separator,
                        switch (sf) {
                            .word => @as(u6, group.imm.imms) + 1,
                            .doubleword => @as(u7, group.imm.imms) + 1,
                        },
                    });
                };
            },
            .extract => |extract| {
                const decoded = extract.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = extract.group;
                const sf = group.sf;
                return writer.print("{f}{s}{f}{s}{f}{s}{f}{s}#{d}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{}).general(sf).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{}).general(sf).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rm.decode(.{}).general(sf).fmtCase(dis.case),
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
            .pstate => |pstate| {
                const decoded = pstate.decode();
                if (decoded == .unallocated) break :unallocated;
                return writer.print("{f}", .{fmtCase(decoded, dis.case)});
            },
            .system_result => {},
            .system => {},
            .system_register_move => {},
            .unconditional_branch_register => |unconditional_branch_register| {
                const decoded = unconditional_branch_register.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = unconditional_branch_register.group;
                const Rn = group.Rn.decode(.{}).x();
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
                    group.Rt.decode(.{}).general(group.sf).fmtCase(dis.case),
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
                    group.Rt.decode(.{}).general(@enumFromInt(group.b5)).fmtCase(dis.case),
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
                    const sf: aarch64.encoding.Register.GeneralSize = @enumFromInt(group.opc >> 1);
                    return writer.print("{f}{s}{f}{s}{f}{s}[{f}]{s}#{s}0x{x}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                        group.Rt.decode(.{ .V = true }).scalar(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decode(.{ .V = true }).scalar(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                    const sf: aarch64.encoding.Register.GeneralSize = @enumFromInt(group.opc >> 1);
                    try writer.print("{f}{s}{f}{s}{f}{s}[{f}", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                        group.Rt.decode(.{ .V = true }).scalar(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decode(.{ .V = true }).scalar(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                    const sf: aarch64.encoding.Register.GeneralSize = @enumFromInt(group.opc >> 1);
                    return writer.print("{f}{s}{f}{s}{f}{s}[{f}{s}#{s}0x{x}]!", .{
                        fmtCase(decoded, dis.case),
                        dis.mnemonic_operands_separator,
                        group.Rt.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                        group.Rt.decode(.{ .V = true }).scalar(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rt2.decode(.{ .V = true }).scalar(vs).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                    const sf: aarch64.encoding.Register.GeneralSize = switch (decoded) {
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
                        group.Rt.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                    const sf: aarch64.encoding.Register.GeneralSize = switch (decoded) {
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
                        group.Rt.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                        group.Rt.decode(.{ .V = true }).scalar(group.opc1.decode(group.size)).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
                        dis.operands_separator,
                        if (group.imm9 < 0) "-" else "",
                        @abs(group.imm9),
                    });
                },
            },
            .register_register_offset => |register_register_offset| switch (register_register_offset.decode()) {
                .integer => |integer| {
                    const decoded = integer.decode();
                    const sf: aarch64.encoding.Register.GeneralSize = switch (decoded) {
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
                        group.Rt.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rm.decode(.{}).general(group.option.sf()).fmtCase(dis.case),
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
                    const sf: aarch64.encoding.Register.GeneralSize = switch (decoded) {
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
                        group.Rt.decode(.{}).general(sf).fmtCase(dis.case),
                        dis.operands_separator,
                        group.Rn.decode(.{ .sp = true }).x().fmtCase(dis.case),
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
                    if (dis.enable_aliases) fmtCase(@as(enum { udiv, sdiv, lsl, lsr, asr, ror }, switch (decoded) {
                        .unallocated => unreachable,
                        .udiv => .udiv,
                        .sdiv => .sdiv,
                        .lslv => .lsl,
                        .lsrv => .lsr,
                        .asrv => .asr,
                        .rorv => .ror,
                    }), dis.case) else fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{}).general(sf).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{}).general(sf).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rm.decode(.{}).general(sf).fmtCase(dis.case),
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
                    group.Rd.decode(.{}).general(sf).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{}).general(sf).fmtCase(dis.case),
                });
            },
            .logical_shifted_register => |logical_shifted_register| {
                const decoded = logical_shifted_register.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = logical_shifted_register.group;
                const sf = group.sf;
                const shift = group.shift;
                const Rm = group.Rm.decode(.{}).general(sf);
                const amount = group.imm6;
                const Rn = group.Rn.decode(.{}).general(sf);
                const Rd = group.Rd.decode(.{}).general(sf);
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
                const Rm = group.Rm.decode(.{}).general(sf);
                const imm6 = group.imm6;
                const Rn = group.Rn.decode(.{}).general(sf);
                const Rd = group.Rd.decode(.{}).general(sf);
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
                const Rm = group.Rm.decode(.{}).general(switch (sf) {
                    .word => .word,
                    .doubleword => group.option.sf(),
                });
                const Rn = group.Rn.decode(.{ .sp = true }).general(sf);
                const Rd = group.Rd.decode(.{ .sp = !group.S }).general(sf);
                const prefer_lsl = (Rd.alias == .sp or Rn.alias == .sp) and group.option == @as(
                    aarch64.encoding.Instruction.DataProcessingRegister.AddSubtractExtendedRegister.Option,
                    switch (sf) {
                        .word => .uxtw,
                        .doubleword => .uxtx,
                    },
                );
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
                return if (!prefer_lsl or group.imm3 != 0) {
                    try writer.print("{s}{f}", .{
                        dis.operands_separator,
                        if (prefer_lsl) fmtCase(.lsl, dis.case) else fmtCase(group.option, dis.case),
                    });
                    if (group.imm3 != 0) try writer.print(" #{d}", .{group.imm3});
                };
            },
            .add_subtract_with_carry => |add_subtract_with_carry| {
                const decoded = add_subtract_with_carry.decode();
                const group = add_subtract_with_carry.group;
                const sf = group.sf;
                const Rm = group.Rm.decode(.{}).general(sf);
                const Rn = group.Rn.decode(.{}).general(sf);
                const Rd = group.Rd.decode(.{}).general(sf);
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
                const Rm = group.Rm.decode(.{}).general(sf);
                const cond = group.cond;
                const Rn = group.Rn.decode(.{}).general(sf);
                const Rd = group.Rd.decode(.{}).general(sf);
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
                const group = data_processing_three_source.group;
                const sf = group.sf;
                const operand_sf = switch (decoded) {
                    .unallocated => break :unallocated,
                    .madd, .msub, .smulh, .umulh => sf,
                    .smaddl, .smsubl, .umaddl, .umsubl => .word,
                };
                const Ra = group.Ra.decode(.{}).general(sf);
                const elide_addend = dis.enable_aliases and Ra.alias == .zr;
                try writer.print("{f}{s}{f}{s}{f}{s}{f}", .{
                    if (elide_addend) fmtCase(@as(enum {
                        mul,
                        mneg,
                        smull,
                        smnegl,
                        smulh,
                        umull,
                        umnegl,
                        umulh,
                    }, switch (decoded) {
                        .unallocated => unreachable,
                        .madd => .mul,
                        .msub => .mneg,
                        .smaddl => .smull,
                        .smsubl => .smnegl,
                        .smulh => .smulh,
                        .umaddl => .umull,
                        .umsubl => .umnegl,
                        .umulh => .umulh,
                    }), dis.case) else fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{}).general(sf).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{}).general(operand_sf).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rm.decode(.{}).general(operand_sf).fmtCase(dis.case),
                });
                return if (!elide_addend) switch (decoded) {
                    .unallocated => unreachable,
                    .madd, .msub, .smaddl, .smsubl, .umaddl, .umsubl => writer.print("{s}{f}", .{
                        dis.operands_separator,
                        Ra.fmtCase(dis.case),
                    }),
                    .smulh, .umulh => {},
                };
            },
        },
        .data_processing_vector => |data_processing_vector| switch (data_processing_vector.decode()) {
            .unallocated => break :unallocated,
            .simd_scalar_copy => |simd_scalar_copy| {
                const decoded = simd_scalar_copy.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = simd_scalar_copy.group;
                const elem_size = @ctz(group.imm5);
                return writer.print("{f}{s}{f}{s}{f}", .{
                    if (dis.enable_aliases and decoded == .dup)
                        fmtCase(.mov, dis.case)
                    else
                        fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).scalar(@enumFromInt(elem_size)).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{ .V = true }).element(
                        @enumFromInt(elem_size),
                        @intCast(group.imm5 >> (elem_size + 1)),
                    ).fmtCase(dis.case),
                });
            },
            .simd_scalar_two_register_miscellaneous_fp16 => |simd_scalar_two_register_miscellaneous_fp16| {
                const decoded = simd_scalar_two_register_miscellaneous_fp16.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = simd_scalar_two_register_miscellaneous_fp16.group;
                try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).h().fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{ .V = true }).h().fmtCase(dis.case),
                });
                return switch (decoded) {
                    .unallocated => unreachable,
                    else => {},
                    .fcmgt,
                    .fcmeq,
                    .fcmlt,
                    .fcmge,
                    .fcmle,
                    => writer.print("{s}#0.0", .{dis.operands_separator}),
                };
            },
            .simd_scalar_two_register_miscellaneous => |simd_scalar_two_register_miscellaneous| {
                const decoded = simd_scalar_two_register_miscellaneous.decode();
                const group = simd_scalar_two_register_miscellaneous.group;
                const elem_size = switch (decoded) {
                    .unallocated => break :unallocated,
                    inline .fcvtns,
                    .fcvtms,
                    .fcvtas,
                    .scvtf,
                    .fcvtps,
                    .fcvtzs,
                    .fcvtxn,
                    .fcvtnu,
                    .fcvtmu,
                    .fcvtau,
                    .ucvtf,
                    .fcvtpu,
                    .fcvtzu,
                    => |f| f.sz.toScalarSize(),
                    else => group.size.toScalarSize(),
                };
                try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).scalar(elem_size).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{ .V = true }).scalar(switch (decoded) {
                        .unallocated => unreachable,
                        else => elem_size,
                        .sqxtn => elem_size.w(),
                    }).fmtCase(dis.case),
                });
                return switch (decoded) {
                    .unallocated => unreachable,
                    else => {},
                    .cmgt,
                    .cmeq,
                    .cmlt,
                    .cmge,
                    .cmle,
                    => writer.print("{s}#0", .{dis.operands_separator}),
                    .fcmgt,
                    .fcmeq,
                    .fcmlt,
                    .fcmge,
                    .fcmle,
                    => writer.print("{s}#0.0", .{dis.operands_separator}),
                };
            },
            .simd_scalar_pairwise => {},
            .simd_copy => |simd_copy| {
                const decoded = simd_copy.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = simd_copy.group;
                const elem_size = @ctz(group.imm5);
                return writer.print("{f}{s}{f}{s}{f}", .{
                    if (dis.enable_aliases and switch (decoded) {
                        .unallocated => unreachable,
                        .dup, .smov => false,
                        .umov => elem_size >= 2,
                        .ins => true,
                    }) fmtCase(.mov, dis.case) else fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    switch (decoded) {
                        .unallocated => unreachable,
                        .dup => |dup| group.Rd.decode(.{ .V = true }).vector(.wrap(.{
                            .size = dup.Q,
                            .elem_size = @enumFromInt(elem_size),
                        })),
                        inline .smov, .umov => |mov| group.Rd.decode(.{}).general(mov.Q),
                        .ins => group.Rd.decode(.{ .V = true }).element(
                            @enumFromInt(elem_size),
                            @intCast(group.imm5 >> (elem_size + 1)),
                        ),
                    }.fmtCase(dis.case),
                    dis.operands_separator,
                    switch (decoded) {
                        .unallocated => unreachable,
                        .dup => |dup| switch (dup.imm4) {
                            .element => group.Rn.decode(.{ .V = true }).element(
                                @enumFromInt(elem_size),
                                @intCast(group.imm5 >> (elem_size + 1)),
                            ),
                            .general => group.Rn.decode(.{}).general(switch (elem_size) {
                                0...2 => .word,
                                3 => .doubleword,
                                else => unreachable,
                            }),
                            _ => unreachable,
                        },
                        .smov, .umov => group.Rn.decode(.{ .V = true }).element(
                            @enumFromInt(elem_size),
                            @intCast(group.imm5 >> (elem_size + 1)),
                        ),
                        .ins => |ins| switch (ins.op) {
                            .element => group.Rn.decode(.{ .V = true }).element(
                                @enumFromInt(elem_size),
                                @intCast(group.imm4 >> @intCast(elem_size)),
                            ),
                            .general => group.Rn.decode(.{}).general(switch (elem_size) {
                                0...2 => .word,
                                3 => .doubleword,
                                else => unreachable,
                            }),
                        },
                    }.fmtCase(dis.case),
                });
            },
            .simd_two_register_miscellaneous_fp16 => |simd_two_register_miscellaneous_fp16| {
                const decoded = simd_two_register_miscellaneous_fp16.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = simd_two_register_miscellaneous_fp16.group;
                const arrangement: aarch64.encoding.Register.Arrangement = .wrap(.{
                    .size = group.Q,
                    .elem_size = .half,
                });
                try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).vector(arrangement).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{ .V = true }).vector(arrangement).fmtCase(dis.case),
                });
                return switch (decoded) {
                    .unallocated => unreachable,
                    else => {},
                    .fcmgt,
                    .fcmeq,
                    .fcmlt,
                    .fcmge,
                    .fcmle,
                    => writer.print("{s}#0.0", .{dis.operands_separator}),
                };
            },
            .simd_two_register_miscellaneous => |simd_two_register_miscellaneous| {
                const decoded = simd_two_register_miscellaneous.decode();
                const group = simd_two_register_miscellaneous.group;
                const elem_size = switch (decoded) {
                    .unallocated => break :unallocated,
                    inline .frintn,
                    .frintm,
                    .fcvtns,
                    .fcvtms,
                    .fcvtas,
                    .scvtf,
                    .frintp,
                    .frintz,
                    .fcvtps,
                    .fcvtzs,
                    .fcvtxn,
                    .frinta,
                    .frintx,
                    .fcvtnu,
                    .fcvtmu,
                    .fcvtau,
                    .ucvtf,
                    .frinti,
                    .fcvtpu,
                    .fcvtzu,
                    => |f| f.sz.toSize(),
                    else => group.size,
                };
                const arrangement: aarch64.encoding.Register.Arrangement = .wrap(.{
                    .size = group.Q,
                    .elem_size = elem_size,
                });
                try writer.print("{f}{s}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    switch (decoded) {
                        .unallocated => unreachable,
                        else => "",
                        .sqxtn => switch (group.Q) {
                            .double => "",
                            .quad => "2",
                        },
                    },
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).vector(arrangement).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{ .V = true }).vector(switch (decoded) {
                        .unallocated => unreachable,
                        else => arrangement,
                        .sqxtn => .wrap(.{
                            .size = .quad,
                            .elem_size = elem_size.w(),
                        }),
                    }).fmtCase(dis.case),
                });
                return switch (decoded) {
                    .unallocated => unreachable,
                    else => {},
                    .cmgt,
                    .cmeq,
                    .cmlt,
                    .cmge,
                    .cmle,
                    => writer.print("{s}#0", .{dis.operands_separator}),
                    .fcmgt,
                    .fcmeq,
                    .fcmlt,
                    .fcmge,
                    .fcmle,
                    => writer.print("{s}#0.0", .{dis.operands_separator}),
                };
            },
            .simd_across_lanes => |simd_across_lanes| {
                const decoded = simd_across_lanes.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = simd_across_lanes.group;
                const arrangement: aarch64.encoding.Register.Arrangement = .wrap(.{
                    .size = group.Q,
                    .elem_size = group.size,
                });
                return writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).scalar(group.size.toScalarSize()).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{ .V = true }).vector(arrangement).fmtCase(dis.case),
                });
            },
            .simd_three_same => |simd_three_same| {
                const decoded = simd_three_same.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = simd_three_same.group;
                const arrangement: aarch64.encoding.Register.Arrangement = .wrap(.{
                    .size = group.Q,
                    .elem_size = switch (decoded) {
                        .unallocated => break :unallocated,
                        .addp => group.size,
                        .@"and", .bic, .orr, .orn, .eor, .bsl, .bit, .bif => .byte,
                    },
                });
                const Rd = group.Rd.decode(.{ .V = true }).vector(arrangement);
                const Rn = group.Rn.decode(.{ .V = true }).vector(arrangement);
                const Rm = group.Rm.decode(.{ .V = true }).vector(arrangement);
                return if (dis.enable_aliases and decoded == .orr and Rm.alias == Rn.alias) try writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(.mov, dis.case),
                    dis.mnemonic_operands_separator,
                    Rd.fmtCase(dis.case),
                    dis.operands_separator,
                    Rn.fmtCase(dis.case),
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
            .simd_modified_immediate => |simd_modified_immediate| {
                const decoded = simd_modified_immediate.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = simd_modified_immediate.group;
                const DataProcessingVector = aarch64.encoding.Instruction.DataProcessingVector;
                try writer.print("{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).vector(.wrap(.{
                        .size = group.Q,
                        .elem_size = switch (group.o2) {
                            0b1 => .half,
                            0b0 => DataProcessingVector.Sz.toSize(@enumFromInt(group.op)),
                        },
                    })).fmtCase(dis.case),
                });
                return switch (decoded) {
                    .unallocated => unreachable,
                    .fmov => {
                        const imm = DataProcessingVector.FloatImmediate.Fmov.Imm8.fromModified(.{
                            .imm5 = group.imm5,
                            .imm3 = group.imm3,
                        }).decode();
                        try writer.print("{s}#{d}{s}", .{
                            dis.operands_separator,
                            @as(f32, imm),
                            if (imm == @trunc(imm)) ".0" else "",
                        });
                    },
                };
            },
            .convert_float_fixed => {},
            .convert_float_integer => |convert_float_integer| {
                const decoded = convert_float_integer.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = convert_float_integer.group;
                const direction: enum { float_to_integer, integer_to_float } = switch (group.opcode) {
                    0b000, 0b001, 0b100, 0b101, 0b110 => .float_to_integer,
                    0b010, 0b011, 0b111 => .integer_to_float,
                };
                return writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    @as(aarch64.encoding.Register, switch (direction) {
                        .float_to_integer => group.Rd.decode(.{}).general(group.sf),
                        .integer_to_float => switch (group.ptype) {
                            .single, .double, .half => group.Rd.decode(.{ .V = true }).scalar(group.ptype.toScalarSize()),
                            .quad => group.Rd.decode(.{ .V = true }).@"d[]"(@intCast(group.rmode)),
                        },
                    }).fmtCase(dis.case),
                    dis.operands_separator,
                    @as(aarch64.encoding.Register, switch (direction) {
                        .float_to_integer => switch (group.ptype) {
                            .single, .double, .half => group.Rn.decode(.{ .V = true }).scalar(group.ptype.toScalarSize()),
                            .quad => group.Rn.decode(.{ .V = true }).@"d[]"(@intCast(group.rmode)),
                        },
                        .integer_to_float => group.Rn.decode(.{}).general(group.sf),
                    }).fmtCase(dis.case),
                });
            },
            .float_data_processing_one_source => |float_data_processing_one_source| {
                const decoded = float_data_processing_one_source.decode();
                if (decoded == .unallocated) break :unallocated;
                const group = float_data_processing_one_source.group;
                return writer.print("{f}{s}{f}{s}{f}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).scalar(group.ptype.toScalarSize()).fmtCase(dis.case),
                    dis.operands_separator,
                    group.Rn.decode(.{ .V = true }).scalar(group.ptype.toScalarSize()).fmtCase(dis.case),
                });
            },
            .float_compare => {},
            .float_immediate => |float_immediate| {
                const decoded = float_immediate.decode();
                const group = float_immediate.group;
                const imm = switch (decoded) {
                    .unallocated => break :unallocated,
                    .fmov => |fmov| fmov.imm8.decode(),
                };
                return writer.print("{f}{s}{f}{s}#{d}{s}", .{
                    fmtCase(decoded, dis.case),
                    dis.mnemonic_operands_separator,
                    group.Rd.decode(.{ .V = true }).scalar(group.ptype.toScalarSize()).fmtCase(dis.case),
                    dis.operands_separator,
                    @as(f32, imm),
                    if (imm == @trunc(imm)) ".0" else "",
                });
            },
            .float_conditional_compare => {},
            .float_data_processing_two_source => {},
            .float_conditional_select => {},
            .float_data_processing_three_source => {},
        },
    }
    return writer.print(".{f}{s}0x{x:0>8}", .{
        fmtCase(.word, dis.case),
        dis.mnemonic_operands_separator,
        @as(aarch64.encoding.Instruction.Backing, @bitCast(inst)),
    });
}

fn fmtCase(tag: anytype, case: Case) struct {
    tag: []const u8,
    case: Case,
    pub fn format(data: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        for (data.tag) |c| try writer.writeByte(data.case.convert(c));
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
            .general => |size| switch (data.reg.alias) {
                else => unreachable,
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
                    data.case.convert(size.prefix()),
                    @intFromEnum(alias.encode(.{})),
                }),
                .zr => try writer.print("{c}{f}", .{
                    data.case.convert(size.prefix()),
                    fmtCase(data.reg.alias, data.case),
                }),
                .sp => try writer.print("{s}{f}", .{
                    switch (size) {
                        .word => &.{data.case.convert('w')},
                        .doubleword => "",
                    },
                    fmtCase(data.reg.alias, data.case),
                }),
            },
            .scalar => |size| try writer.print("{c}{d}", .{
                data.case.convert(size.prefix()),
                @intFromEnum(data.reg.alias.encode(.{ .V = true })),
            }),
            .vector => |arrangement| try writer.print("{f}.{f}", .{
                fmtCase(data.reg.alias, data.case),
                fmtCase(arrangement, data.case),
            }),
            .element => |element| try writer.print("{f}.{c}[{d}]", .{
                fmtCase(data.reg.alias, data.case),
                data.case.convert(element.size.prefix()),
                element.index,
            }),
            .scalable => try writer.print("{c}{d}", .{
                data.case.convert('z'),
                @intFromEnum(data.reg.alias.encode(.{ .V = true })),
            }),
        }
    }
};

const aarch64 = @import("../aarch64.zig");
const Disassemble = @This();
const std = @import("std");
