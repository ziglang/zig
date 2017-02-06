// This file is included if and only if the user's main source file does not
// include a public panic function.
// If this file wants to import other files *by name*, support for that would
// have to be added in the compiler.

var panicking = false;
pub coldcc fn panic(message: []const u8) -> unreachable {
    if (@compileVar("os") == Os.freestanding) {
        while (true) {}
    } else {
        const std = @import("std");
        const io = std.io;
        const debug = std.debug;
        const os = std.os;

        // TODO
        // if (@atomicRmw(AtomicOp.XChg, &panicking, true, AtomicOrder.SeqCst)) {
        if (panicking) {
            // Panicked during a panic.
            // TODO detect if a different thread caused the panic, because in that case
            // we would want to return here instead of calling abort, so that the thread
            // which first called panic can finish printing a stack trace.
            os.abort();
        } else {
            panicking = true;
        }

        %%io.stderr.printf("{}\n", message);
        %%debug.printStackTrace();

        os.abort();
    }
}
