const builtin = @import("builtin");
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

test "reference a global threadlocal variable" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch != .x86_64) return error.SkipZigTest; // TODO

    _ = nrfx_uart_rx(&g_uart0);
}
