const macho = @import("../macho.zig");

extern "c" fn __error() *c_int;
pub extern "c" fn _NSGetExecutablePath(buf: [*]u8, bufsize: *u32) c_int;
pub extern "c" fn _dyld_get_image_header(image_index: u32) ?*mach_header;

pub extern "c" fn __getdirentries64(fd: c_int, buf_ptr: [*]u8, buf_len: usize, basep: *i64) usize;

pub extern "c" fn mach_absolute_time() u64;
pub extern "c" fn mach_timebase_info(tinfo: ?*mach_timebase_info_data) void;

pub extern "c" fn kqueue() c_int;
pub extern "c" fn kevent(
    kq: c_int,
    changelist: [*]const Kevent,
    nchanges: c_int,
    eventlist: [*]Kevent,
    nevents: c_int,
    timeout: ?*const timespec,
) c_int;

pub extern "c" fn kevent64(
    kq: c_int,
    changelist: [*]const kevent64_s,
    nchanges: c_int,
    eventlist: [*]kevent64_s,
    nevents: c_int,
    flags: c_uint,
    timeout: ?*const timespec,
) c_int;

pub extern "c" fn sysctl(name: [*]c_int, namelen: c_uint, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
pub extern "c" fn sysctlbyname(name: [*]const u8, oldp: ?*c_void, oldlenp: ?*usize, newp: ?*c_void, newlen: usize) c_int;
pub extern "c" fn sysctlnametomib(name: [*]const u8, mibp: ?*c_int, sizep: ?*usize) c_int;

pub extern "c" fn bind(socket: c_int, address: ?*const sockaddr, address_len: socklen_t) c_int;
pub extern "c" fn socket(domain: c_int, type: c_int, protocol: c_int) c_int;

/// The value of the link editor defined symbol _MH_EXECUTE_SYM is the address
/// of the mach header in a Mach-O executable file type.  It does not appear in
/// any file type other than a MH_EXECUTE file type.  The type of the symbol is
/// absolute as the header is not part of any section.
pub extern "c" var _mh_execute_header: if (@sizeOf(usize) == 8) mach_header_64 else mach_header;

pub const mach_header_64 = macho.mach_header_64;
pub const mach_header = macho.mach_header;

pub use @import("../os/darwin/errno.zig");

pub const _errno = __error;

pub const in_port_t = u16;
pub const sa_family_t = u8;
pub const socklen_t = u32;
pub const sockaddr = extern union.{
    in: sockaddr_in,
    in6: sockaddr_in6,
};
pub const sockaddr_in = extern struct.{
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    addr: u32,
    zero: [8]u8,
};
pub const sockaddr_in6 = extern struct.{
    len: u8,
    family: sa_family_t,
    port: in_port_t,
    flowinfo: u32,
    addr: [16]u8,
    scope_id: u32,
};

pub const timeval = extern struct.{
    tv_sec: isize,
    tv_usec: isize,
};

pub const timezone = extern struct.{
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const mach_timebase_info_data = extern struct.{
    numer: u32,
    denom: u32,
};

/// Renamed to Stat to not conflict with the stat function.
pub const Stat = extern struct.{
    dev: i32,
    mode: u16,
    nlink: u16,
    ino: u64,
    uid: u32,
    gid: u32,
    rdev: i32,
    atime: usize,
    atimensec: usize,
    mtime: usize,
    mtimensec: usize,
    ctime: usize,
    ctimensec: usize,
    birthtime: usize,
    birthtimensec: usize,
    size: i64,
    blocks: i64,
    blksize: i32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare: [2]i64,
};

pub const timespec = extern struct.{
    tv_sec: isize,
    tv_nsec: isize,
};

pub const sigset_t = u32;

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with function name.
pub const Sigaction = extern struct.{
    handler: extern fn (c_int) void,
    sa_mask: sigset_t,
    sa_flags: c_int,
};

pub const dirent = extern struct.{
    d_ino: usize,
    d_seekoff: usize,
    d_reclen: u16,
    d_namlen: u16,
    d_type: u8,
    d_name: u8, // field address is address of first byte of name
};

pub const pthread_attr_t = extern struct.{
    __sig: c_long,
    __opaque: [56]u8,
};

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct.{
    ident: usize,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: isize,
    udata: usize,
};

// sys/types.h on macos uses #pragma pack(4) so these checks are
// to make sure the struct is laid out the same. These values were
// produced from C code using the offsetof macro.
const std = @import("../index.zig");
const assert = std.debug.assert;

comptime {
    assert(@byteOffsetOf(Kevent, "ident") == 0);
    assert(@byteOffsetOf(Kevent, "filter") == 8);
    assert(@byteOffsetOf(Kevent, "flags") == 10);
    assert(@byteOffsetOf(Kevent, "fflags") == 12);
    assert(@byteOffsetOf(Kevent, "data") == 16);
    assert(@byteOffsetOf(Kevent, "udata") == 24);
}

pub const kevent64_s = extern struct.{
    ident: u64,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: i64,
    udata: u64,
    ext: [2]u64,
};

// sys/types.h on macos uses #pragma pack() so these checks are
// to make sure the struct is laid out the same. These values were
// produced from C code using the offsetof macro.
comptime {
    assert(@byteOffsetOf(kevent64_s, "ident") == 0);
    assert(@byteOffsetOf(kevent64_s, "filter") == 8);
    assert(@byteOffsetOf(kevent64_s, "flags") == 10);
    assert(@byteOffsetOf(kevent64_s, "fflags") == 12);
    assert(@byteOffsetOf(kevent64_s, "data") == 16);
    assert(@byteOffsetOf(kevent64_s, "udata") == 24);
    assert(@byteOffsetOf(kevent64_s, "ext") == 32);
}
