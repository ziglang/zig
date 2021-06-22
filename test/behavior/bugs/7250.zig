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
    _ = nrfx_uart_rx(&g_uart0);
}
