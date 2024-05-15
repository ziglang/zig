const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "thread local variable" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm) switch (builtin.cpu.arch) {
        .x86_64, .x86 => {},
        else => return error.SkipZigTest,
    }; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_x86_64 and builtin.os.tag == .macos) {
        // Fails due to register hazards.
        return error.SkipZigTest;
    }

    const S = struct {
        threadlocal var t: i32 = 1234;
    };
    S.t += 1;
    try expect(S.t == 1235);
}

test "pointer to thread local array" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm) switch (builtin.cpu.arch) {
        .x86_64, .x86 => {},
        else => return error.SkipZigTest,
    }; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const s = "Hello world";
    @memcpy(buffer[0..s.len], s);
    try std.testing.expectEqualSlices(u8, buffer[0..], s);
}

threadlocal var buffer: [11]u8 = undefined;

test "reference a global threadlocal variable" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm) switch (builtin.cpu.arch) {
        .x86_64, .x86 => {},
        else => return error.SkipZigTest,
    }; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    _ = nrfx_uart_rx(&g_uart0);
}

const nrfx_uart_t = extern struct {
    p_reg: [*c]u32,
    drv_inst_idx: u8,
};

pub fn nrfx_uart_rx(p_instance: [*c]const nrfx_uart_t) void {
    _ = p_instance;
}

threadlocal var g_uart0 = nrfx_uart_t{
    .p_reg = 0,
    .drv_inst_idx = 0,
};
