const std = @import("../std.zig");
usingnamespace std.c;

extern "c" fn __error() *c_int;
pub const _errno = __error;

pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) usize;
pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;
pub extern "c" fn getrandom(buf_ptr: [*]u8, buf_len: usize, flags: c_uint) isize;

pub const dl_iterate_phdr_callback = extern fn (info: *dl_phdr_info, size: usize, data: ?*c_void) c_int;
pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*c_void) c_int;

pub const pthread_mutex_t = extern struct {
    inner: ?*c_void = null,
};
pub const pthread_cond_t = extern struct {
    inner: ?*c_void = null,
};

pub const pthread_attr_t = extern struct {
    __size: [56]u8,
    __align: c_long,
};

/// address family for hostname not supported
pub const EAI_ADDRFAMILY = 1;

/// name could not be resolved at this time
pub const EAI_AGAIN = 2;

/// flags parameter had an invalid value
pub const EAI_BADFLAGS = 3;

/// non-recoverable failure in name resolution
pub const EAI_FAIL = 4;

/// address family not recognized
pub const EAI_FAMILY = 5;

/// memory allocation failure
pub const EAI_MEMORY = 6;

/// no address associated with hostname
pub const EAI_NODATA = 7;

/// name does not resolve
pub const EAI_NONAME = 8;

/// service not recognized for socket type
pub const EAI_SERVICE = 9;

/// intended socket type was not recognized
pub const EAI_SOCKTYPE = 10;

/// system error returned in errno
pub const EAI_SYSTEM = 11;

/// invalid value for hints
pub const EAI_BADHINTS = 12;

/// resolved protocol is unknown
pub const EAI_PROTOCOL = 13;

/// argument buffer overflow
pub const EAI_OVERFLOW = 14;

pub const EAI_MAX = 15;

/// get address to use bind()
pub const AI_PASSIVE = 0x00000001;

/// fill ai_canonname
pub const AI_CANONNAME = 0x00000002;

/// prevent host name resolution
pub const AI_NUMERICHOST = 0x00000004;

/// prevent service name resolution
pub const AI_NUMERICSERV = 0x00000008;

/// valid flags for addrinfo (not a standard def, apps should not use it)
pub const AI_MASK = (AI_PASSIVE | AI_CANONNAME | AI_NUMERICHOST | AI_NUMERICSERV | AI_ADDRCONFIG | AI_ALL | AI_V4MAPPED);

/// IPv6 and IPv4-mapped (with AI_V4MAPPED)
pub const AI_ALL = 0x00000100;

/// accept IPv4-mapped if kernel supports
pub const AI_V4MAPPED_CFG = 0x00000200;

/// only if any address is assigned
pub const AI_ADDRCONFIG = 0x00000400;

/// accept IPv4-mapped IPv6 address
pub const AI_V4MAPPED = 0x00000800;

/// special recommended flags for getipnodebyname
pub const AI_DEFAULT = (AI_V4MAPPED_CFG | AI_ADDRCONFIG);
