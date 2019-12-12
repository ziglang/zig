//!Things defined by POSIX

const os_bits = @import("../bits.zig");
const fd_t = os_bits.fd_t;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub fn getStdOutHandle() fd_t {
    return STDOUT_FILENO;
}

pub fn getStdErrHandle() fd_t {
    return STDERR_FILENO;
}

pub fn getStdInHandle() fd_t {
    return STDIN_FILENO;
}
