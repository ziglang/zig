import "syscall.zig";
import "errno.zig";

pub error SigInterrupt;
pub error Unexpected;

pub fn os_get_random_bytes(buf: []u8) -> %void {
    const amt_got = getrandom(buf.ptr, buf.len, 0);
    if (amt_got < 0) {
        return switch (-amt_got) {
            EINVAL => unreachable{},
            EFAULT => unreachable{},
            EINTR  => error.SigInterrupt,
            else   => error.Unexpected,
        }
    }
}
