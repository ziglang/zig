pub const abi = @import("aarch64/abi.zig");
pub const Assemble = @import("aarch64/Assemble.zig");
pub const Disassemble = @import("aarch64/Disassemble.zig");
pub const encoding = @import("aarch64/encoding.zig");
pub const Mir = @import("aarch64/Mir.zig");
pub const Select = @import("aarch64/Select.zig");

pub fn legalizeFeatures(_: *const std.Target) ?*Air.Legalize.Features {
    return null;
}

pub fn generate(
    _: *link.File,
    pt: Zcu.PerThread,
    _: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    air: *const Air,
    liveness: *const ?Air.Liveness,
) !Mir {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const func = zcu.funcInfo(func_index);
    const func_type = zcu.intern_pool.indexToKey(func.ty).func_type;
    assert(liveness.* == null);

    const mod = zcu.navFileScope(func.owner_nav).mod.?;
    var isel: Select = .{
        .pt = pt,
        .target = &mod.resolved_target.result,
        .air = air.*,
        .nav_index = zcu.funcInfo(func_index).owner_nav,

        .def_order = .empty,
        .blocks = .empty,
        .loops = .empty,
        .active_loops = .empty,
        .loop_live = .{
            .set = .empty,
            .list = .empty,
        },
        .dom_start = 0,
        .dom_len = 0,
        .dom = .empty,

        .saved_registers = comptime .initEmpty(),
        .instructions = .empty,
        .literals = .empty,
        .nav_relocs = .empty,
        .uav_relocs = .empty,
        .global_relocs = .empty,
        .literal_relocs = .empty,

        .returns = false,
        .va_list = undefined,
        .stack_size = 0,
        .stack_align = .@"16",

        .live_registers = comptime .initFill(.free),
        .live_values = .empty,
        .values = .empty,
    };
    defer isel.deinit();

    const air_main_body = air.getMainBody();
    var param_it: Select.CallAbiIterator = .init;
    const air_args = for (air_main_body, 0..) |air_inst_index, body_index| {
        if (air.instructions.items(.tag)[@intFromEnum(air_inst_index)] != .arg) break air_main_body[0..body_index];
        const param_ty = air.instructions.items(.data)[@intFromEnum(air_inst_index)].arg.ty.toType();
        const param_vi = try param_it.param(&isel, param_ty);
        tracking_log.debug("${d} <- %{d}", .{ @intFromEnum(param_vi.?), @intFromEnum(air_inst_index) });
        try isel.live_values.putNoClobber(gpa, air_inst_index, param_vi.?);
    } else unreachable;

    const saved_gra_start = if (mod.strip) param_it.ngrn else Select.CallAbiIterator.ngrn_start;
    const saved_gra_end = if (func_type.is_var_args) Select.CallAbiIterator.ngrn_end else param_it.ngrn;
    const saved_gra_len = @intFromEnum(saved_gra_end) - @intFromEnum(saved_gra_start);

    const saved_vra_start = if (mod.strip) param_it.nsrn else Select.CallAbiIterator.nsrn_start;
    const saved_vra_end = if (func_type.is_var_args) Select.CallAbiIterator.nsrn_end else param_it.nsrn;
    const saved_vra_len = @intFromEnum(saved_vra_end) - @intFromEnum(saved_vra_start);

    const frame_record = 2;
    const named_stack_args: Select.Value.Indirect = .{
        .base = .fp,
        .offset = 8 * std.mem.alignForward(u7, frame_record + saved_gra_len, 2),
    };
    isel.va_list = .{
        .__stack = named_stack_args.withOffset(param_it.nsaa),
        .__gr_top = named_stack_args,
        .__vr_top = .{ .base = .fp, .offset = 0 },
    };

    // translate arg locations from caller-based to callee-based
    for (air_args) |air_inst_index| {
        assert(air.instructions.items(.tag)[@intFromEnum(air_inst_index)] == .arg);
        const arg_vi = isel.live_values.get(air_inst_index).?;
        const passed_vi = switch (arg_vi.parent(&isel)) {
            .unallocated, .stack_slot => arg_vi,
            .value, .constant => unreachable,
            .address => |address_vi| address_vi,
        };
        switch (passed_vi.parent(&isel)) {
            .unallocated => if (!mod.strip) {
                var part_it = arg_vi.parts(&isel);
                const first_passed_part_vi = part_it.next() orelse passed_vi;
                const hint_ra = first_passed_part_vi.hint(&isel).?;
                passed_vi.setParent(&isel, .{ .stack_slot = if (hint_ra.isVector())
                    isel.va_list.__vr_top.withOffset(@as(i8, -16) *
                        (@intFromEnum(saved_vra_end) - @intFromEnum(hint_ra)))
                else
                    isel.va_list.__gr_top.withOffset(@as(i8, -8) *
                        (@intFromEnum(saved_gra_end) - @intFromEnum(hint_ra))) });
            },
            .stack_slot => |stack_slot| {
                assert(stack_slot.base == .sp);
                passed_vi.setParent(&isel, .{
                    .stack_slot = named_stack_args.withOffset(stack_slot.offset),
                });
            },
            .address, .value, .constant => unreachable,
        }
    }

    ret: {
        var ret_it: Select.CallAbiIterator = .init;
        const ret_vi = try ret_it.ret(&isel, .fromInterned(func_type.return_type)) orelse break :ret;
        tracking_log.debug("${d} <- %main", .{@intFromEnum(ret_vi)});
        try isel.live_values.putNoClobber(gpa, Select.Block.main, ret_vi);
    }

    assert(!(try isel.blocks.getOrPut(gpa, Select.Block.main)).found_existing);
    try isel.analyze(air_main_body);
    try isel.finishAnalysis();
    isel.verify(false);

    isel.blocks.values()[0] = .{
        .live_registers = isel.live_registers,
        .target_label = @intCast(isel.instructions.items.len),
    };
    try isel.body(air_main_body);
    if (isel.live_values.fetchRemove(Select.Block.main)) |ret_vi| {
        switch (ret_vi.value.parent(&isel)) {
            .unallocated, .stack_slot => {},
            .value, .constant => unreachable,
            .address => |address_vi| try address_vi.liveIn(
                &isel,
                address_vi.hint(&isel).?,
                comptime &.initFill(.free),
            ),
        }
        ret_vi.value.deref(&isel);
    }
    isel.verify(true);

    const prologue = isel.instructions.items.len;
    const epilogue = try isel.layout(
        param_it,
        func_type.is_var_args,
        saved_gra_len,
        saved_vra_len,
        mod,
    );

    const instructions = try isel.instructions.toOwnedSlice(gpa);
    var mir: Mir = .{
        .prologue = instructions[prologue..epilogue],
        .body = instructions[0..prologue],
        .epilogue = instructions[epilogue..],
        .literals = &.{},
        .nav_relocs = &.{},
        .uav_relocs = &.{},
        .global_relocs = &.{},
        .literal_relocs = &.{},
    };
    errdefer mir.deinit(gpa);
    mir.literals = try isel.literals.toOwnedSlice(gpa);
    mir.nav_relocs = try isel.nav_relocs.toOwnedSlice(gpa);
    mir.uav_relocs = try isel.uav_relocs.toOwnedSlice(gpa);
    mir.global_relocs = try isel.global_relocs.toOwnedSlice(gpa);
    mir.literal_relocs = try isel.literal_relocs.toOwnedSlice(gpa);
    return mir;
}

test {
    _ = Assemble;
}

const Air = @import("../Air.zig");
const assert = std.debug.assert;
const InternPool = @import("../InternPool.zig");
const link = @import("../link.zig");
const std = @import("std");
const tracking_log = std.log.scoped(.tracking);
const Zcu = @import("../Zcu.zig");
