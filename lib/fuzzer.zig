const std = @import("std");

export threadlocal var __sancov_lowest_stack: usize = 0;

export fn __sanitizer_cov_8bit_counters_init(start: [*]u8, stop: [*]u8) void {
    std.debug.print("__sanitizer_cov_8bit_counters_init start={*}, stop={*}\n", .{ start, stop });
}

export fn __sanitizer_cov_pcs_init(pcs_beg: [*]const usize, pcs_end: [*]const usize) void {
    std.debug.print("__sanitizer_cov_pcs_init pcs_beg={*}, pcs_end={*}\n", .{ pcs_beg, pcs_end });
}
