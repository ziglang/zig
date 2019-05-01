pub const errno_t = u16;
pub const exitcode_t = u32;
pub const fd_t = u32;
pub const signal_t = u8;

pub const ciovec_t = extern struct {
    buf: [*]const u8,
    buf_len: usize,
};

pub const SIGABRT: signal_t = 6;

pub extern "wasi_unstable" fn args_get(argv: [*][*]u8, argv_buf: [*]u8) errno_t;
pub extern "wasi_unstable" fn args_sizes_get(argc: *usize, argv_buf_size: *usize) errno_t;

pub extern "wasi_unstable" fn environ_get(environ: [*]?[*]u8, environ_buf: [*]u8) errno_t;
pub extern "wasi_unstable" fn environ_sizes_get(environ_count: *usize, environ_buf_size: *usize) errno_t;

pub extern "wasi_unstable" fn proc_raise(sig: signal_t) errno_t;
pub extern "wasi_unstable" fn proc_exit(rval: exitcode_t) noreturn;

pub extern "wasi_unstable" fn fd_write(fd: fd_t, iovs: *const ciovec_t, iovs_len: usize, nwritten: *usize) errno_t;

pub extern "wasi_unstable" fn random_get(buf: [*]u8, buf_len: usize) errno_t;
