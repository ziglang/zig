//!Things defined by POSIX

const os_bits = @import("../bits.zig");
const fd_t = os_bits.fd_t;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;
