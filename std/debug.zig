const io = @import("io.zig");

pub fn assert(b: bool) {
    if (!b) unreachable{}
}

pub fn print_stack_trace() {
    var maybe_fp: ?&const u8 = @frame_address();
    while (true) {
        const fp = maybe_fp ?? break;
        const return_address = *(&const usize)(usize(fp) + @sizeof(usize));
        %%io.stderr.print_u64(return_address);
        %%io.stderr.printf("\n");
        maybe_fp = *(&const ?&const u8)(fp);
    }
}
