prologue: []const Instruction,
body: []const Instruction,
epilogue: []const Instruction,
literals: []const u32,
nav_relocs: []const Reloc.Nav,
uav_relocs: []const Reloc.Uav,
global_relocs: []const Reloc.Global,
literal_relocs: []const Reloc.Literal,

pub const Reloc = struct {
    label: u32,
    addend: u64 align(@alignOf(u32)) = 0,

    pub const Nav = struct {
        nav: InternPool.Nav.Index,
        reloc: Reloc,
    };

    pub const Uav = struct {
        uav: InternPool.Key.Ptr.BaseAddr.Uav,
        reloc: Reloc,
    };

    pub const Global = struct {
        global: [*:0]const u8,
        reloc: Reloc,
    };

    pub const Literal = struct {
        label: u32,
    };
};

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    assert(mir.body.ptr + mir.body.len == mir.prologue.ptr);
    assert(mir.prologue.ptr + mir.prologue.len == mir.epilogue.ptr);
    gpa.free(mir.body.ptr[0 .. mir.body.len + mir.prologue.len + mir.epilogue.len]);
    gpa.free(mir.literals);
    gpa.free(mir.nav_relocs);
    gpa.free(mir.uav_relocs);
    gpa.free(mir.global_relocs);
    gpa.free(mir.literal_relocs);
    mir.* = undefined;
}

pub fn emit(
    mir: Mir,
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) !void {
    _ = debug_output;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;
    const func = zcu.funcInfo(func_index);
    const nav = ip.getNav(func.owner_nav);
    const mod = zcu.navFileScope(func.owner_nav).mod.?;
    const target = &mod.resolved_target.result;
    mir_log.debug("{f}:", .{nav.fqn.fmt(ip)});

    const func_align = switch (nav.status.fully_resolved.alignment) {
        .none => switch (mod.optimize_mode) {
            .Debug, .ReleaseSafe, .ReleaseFast => target_util.defaultFunctionAlignment(target),
            .ReleaseSmall => target_util.minFunctionAlignment(target),
        },
        else => |a| a.maxStrict(target_util.minFunctionAlignment(target)),
    };
    const code_len = mir.prologue.len + mir.body.len + mir.epilogue.len;
    const literals_align_gap = -%code_len & (@divExact(
        @as(u5, @intCast(func_align.minStrict(.@"16").toByteUnits().?)),
        Instruction.size,
    ) - 1);
    try code.ensureUnusedCapacity(gpa, Instruction.size *
        (code_len + literals_align_gap + mir.literals.len));
    emitInstructionsForward(code, mir.prologue);
    emitInstructionsBackward(code, mir.body);
    const body_end: u32 = @intCast(code.items.len);
    emitInstructionsBackward(code, mir.epilogue);
    code.appendNTimesAssumeCapacity(0, Instruction.size * literals_align_gap);
    code.appendSliceAssumeCapacity(@ptrCast(mir.literals));
    mir_log.debug("", .{});

    for (mir.nav_relocs) |nav_reloc| try emitReloc(
        lf,
        zcu,
        func.owner_nav,
        switch (try @import("../../codegen.zig").genNavRef(
            lf,
            pt,
            src_loc,
            nav_reloc.nav,
            &mod.resolved_target.result,
        )) {
            .sym_index => |sym_index| sym_index,
            .fail => |em| return zcu.codegenFailMsg(func.owner_nav, em),
        },
        mir.body[nav_reloc.reloc.label],
        body_end - Instruction.size * (1 + nav_reloc.reloc.label),
        nav_reloc.reloc.addend,
    );
    for (mir.uav_relocs) |uav_reloc| try emitReloc(
        lf,
        zcu,
        func.owner_nav,
        switch (try lf.lowerUav(
            pt,
            uav_reloc.uav.val,
            ZigType.fromInterned(uav_reloc.uav.orig_ty).ptrAlignment(zcu),
            src_loc,
        )) {
            .sym_index => |sym_index| sym_index,
            .fail => |em| return zcu.codegenFailMsg(func.owner_nav, em),
        },
        mir.body[uav_reloc.reloc.label],
        body_end - Instruction.size * (1 + uav_reloc.reloc.label),
        uav_reloc.reloc.addend,
    );
    for (mir.global_relocs) |global_reloc| try emitReloc(
        lf,
        zcu,
        func.owner_nav,
        if (lf.cast(.elf)) |ef|
            try ef.getGlobalSymbol(std.mem.span(global_reloc.global), null)
        else if (lf.cast(.macho)) |mf|
            try mf.getGlobalSymbol(std.mem.span(global_reloc.global), null)
        else if (lf.cast(.coff)) |cf|
            try cf.getGlobalSymbol(std.mem.span(global_reloc.global), "compiler_rt")
        else
            return zcu.codegenFail(func.owner_nav, "external symbols unimplemented for {s}", .{@tagName(lf.tag)}),
        mir.body[global_reloc.reloc.label],
        body_end - Instruction.size * (1 + global_reloc.reloc.label),
        global_reloc.reloc.addend,
    );
    const literal_reloc_offset: i19 = @intCast(mir.epilogue.len + literals_align_gap);
    for (mir.literal_relocs) |literal_reloc| {
        var instruction = mir.body[literal_reloc.label];
        instruction.load_store.register_literal.group.imm19 += literal_reloc_offset;
        instruction.write(
            code.items[body_end - Instruction.size * (1 + literal_reloc.label) ..][0..Instruction.size],
        );
    }
}

fn emitInstructionsForward(code: *std.ArrayListUnmanaged(u8), instructions: []const Instruction) void {
    for (instructions) |instruction| emitInstruction(code, instruction);
}
fn emitInstructionsBackward(code: *std.ArrayListUnmanaged(u8), instructions: []const Instruction) void {
    var instruction_index = instructions.len;
    while (instruction_index > 0) {
        instruction_index -= 1;
        emitInstruction(code, instructions[instruction_index]);
    }
}
fn emitInstruction(code: *std.ArrayListUnmanaged(u8), instruction: Instruction) void {
    mir_log.debug("    {f}", .{instruction});
    instruction.write(code.addManyAsArrayAssumeCapacity(Instruction.size));
}

fn emitReloc(
    lf: *link.File,
    zcu: *Zcu,
    owner_nav: InternPool.Nav.Index,
    sym_index: u32,
    instruction: Instruction,
    offset: u32,
    addend: u64,
) !void {
    const gpa = zcu.gpa;
    switch (instruction.decode()) {
        else => unreachable,
        .branch_exception_generating_system => |decoded| if (lf.cast(.elf)) |ef| {
            const zo = ef.zigObjectPtr().?;
            const atom = zo.symbol(try zo.getOrCreateMetadataForNav(zcu, owner_nav)).atom(ef).?;
            const r_type: std.elf.R_AARCH64 = switch (decoded.decode().unconditional_branch_immediate.group.op) {
                .b => .JUMP26,
                .bl => .CALL26,
            };
            try atom.addReloc(gpa, .{
                .r_offset = offset,
                .r_info = @as(u64, sym_index) << 32 | @intFromEnum(r_type),
                .r_addend = @bitCast(addend),
            }, zo);
        } else if (lf.cast(.macho)) |mf| {
            const zo = mf.getZigObject().?;
            const atom = zo.symbols.items[try zo.getOrCreateMetadataForNav(mf, owner_nav)].getAtom(mf).?;
            try atom.addReloc(mf, .{
                .tag = .@"extern",
                .offset = offset,
                .target = sym_index,
                .addend = @bitCast(addend),
                .type = .branch,
                .meta = .{
                    .pcrel = true,
                    .has_subtractor = false,
                    .length = 2,
                    .symbolnum = @intCast(sym_index),
                },
            });
        },
        .data_processing_immediate => |decoded| if (lf.cast(.elf)) |ef| {
            const zo = ef.zigObjectPtr().?;
            const atom = zo.symbol(try zo.getOrCreateMetadataForNav(zcu, owner_nav)).atom(ef).?;
            const r_type: std.elf.R_AARCH64 = switch (decoded.decode()) {
                else => unreachable,
                .pc_relative_addressing => |pc_relative_addressing| switch (pc_relative_addressing.group.op) {
                    .adr => .ADR_PREL_LO21,
                    .adrp => .ADR_PREL_PG_HI21,
                },
                .add_subtract_immediate => |add_subtract_immediate| switch (add_subtract_immediate.group.op) {
                    .add => .ADD_ABS_LO12_NC,
                    .sub => unreachable,
                },
            };
            try atom.addReloc(gpa, .{
                .r_offset = offset,
                .r_info = @as(u64, sym_index) << 32 | @intFromEnum(r_type),
                .r_addend = @bitCast(addend),
            }, zo);
        } else if (lf.cast(.macho)) |mf| {
            const zo = mf.getZigObject().?;
            const atom = zo.symbols.items[try zo.getOrCreateMetadataForNav(mf, owner_nav)].getAtom(mf).?;
            switch (decoded.decode()) {
                else => unreachable,
                .pc_relative_addressing => |pc_relative_addressing| switch (pc_relative_addressing.group.op) {
                    .adr => unreachable,
                    .adrp => try atom.addReloc(mf, .{
                        .tag = .@"extern",
                        .offset = offset,
                        .target = sym_index,
                        .addend = @bitCast(addend),
                        .type = .page,
                        .meta = .{
                            .pcrel = true,
                            .has_subtractor = false,
                            .length = 2,
                            .symbolnum = @intCast(sym_index),
                        },
                    }),
                },
                .add_subtract_immediate => |add_subtract_immediate| switch (add_subtract_immediate.group.op) {
                    .add => try atom.addReloc(mf, .{
                        .tag = .@"extern",
                        .offset = offset,
                        .target = sym_index,
                        .addend = @bitCast(addend),
                        .type = .pageoff,
                        .meta = .{
                            .pcrel = false,
                            .has_subtractor = false,
                            .length = 2,
                            .symbolnum = @intCast(sym_index),
                        },
                    }),
                    .sub => unreachable,
                },
            }
        },
    }
}

const Air = @import("../../Air.zig");
const assert = std.debug.assert;
const mir_log = std.log.scoped(.mir);
const Instruction = @import("encoding.zig").Instruction;
const InternPool = @import("../../InternPool.zig");
const link = @import("../../link.zig");
const Mir = @This();
const std = @import("std");
const target_util = @import("../../target.zig");
const Zcu = @import("../../Zcu.zig");
const ZigType = @import("../../Type.zig");
