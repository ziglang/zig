const Kqueue = @This();
const builtin = @import("builtin");

const std = @import("../std.zig");
const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;
const net = std.Io.net;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
const posix = std.posix;
const IpAddress = std.Io.net.IpAddress;
const errnoBug = std.Io.Threaded.errnoBug;

/// Must be a thread-safe allocator.
gpa: Allocator,

pub fn init(gpa: Allocator) Kqueue {
    return .{
        .gpa = gpa,
    };
}

pub fn deinit(k: *Kqueue) void {
    k.* = undefined;
}

pub fn io(k: *Kqueue) Io {
    return .{
        .userdata = k,
        .vtable = &.{
            .async = async,
            .concurrent = concurrent,
            .await = await,
            .cancel = cancel,
            .cancelRequested = cancelRequested,
            .select = select,

            .groupAsync = groupAsync,
            .groupWait = groupWait,
            .groupWaitUncancelable = groupWaitUncancelable,
            .groupCancel = groupCancel,

            .mutexLock = mutexLock,
            .mutexLockUncancelable = mutexLockUncancelable,
            .mutexUnlock = mutexUnlock,

            .conditionWait = conditionWait,
            .conditionWaitUncancelable = conditionWaitUncancelable,
            .conditionWake = conditionWake,

            .dirMake = dirMake,
            .dirMakePath = dirMakePath,
            .dirMakeOpenPath = dirMakeOpenPath,
            .dirStat = dirStat,
            .dirStatPath = dirStatPath,

            .fileStat = fileStat,
            .dirAccess = dirAccess,
            .dirCreateFile = dirCreateFile,
            .dirOpenFile = dirOpenFile,
            .dirOpenDir = dirOpenDir,
            .dirClose = dirClose,
            .fileClose = fileClose,
            .fileWriteStreaming = fileWriteStreaming,
            .fileWritePositional = fileWritePositional,
            .fileReadStreaming = fileReadStreaming,
            .fileReadPositional = fileReadPositional,
            .fileSeekBy = fileSeekBy,
            .fileSeekTo = fileSeekTo,
            .openSelfExe = openSelfExe,

            .now = now,
            .sleep = sleep,

            .netListenIp = netListenIp,
            .netListenUnix = netListenUnix,
            .netAccept = netAccept,
            .netBindIp = netBindIp,
            .netConnectIp = netConnectIp,
            .netConnectUnix = netConnectUnix,
            .netClose = netClose,
            .netRead = netRead,
            .netWrite = netWrite,
            .netSend = netSend,
            .netReceive = netReceive,
            .netInterfaceNameResolve = netInterfaceNameResolve,
            .netInterfaceName = netInterfaceName,
            .netLookup = netLookup,
        },
    };
}

fn async(
    userdata: ?*anyopaque,
    result: []u8,
    result_alignment: std.mem.Alignment,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) ?*Io.AnyFuture {
    return concurrent(userdata, result.len, result_alignment, context, context_alignment, start) catch {
        start(context.ptr, result.ptr);
        return null;
    };
}

fn concurrent(
    userdata: ?*anyopaque,
    result_len: usize,
    result_alignment: std.mem.Alignment,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) error{OutOfMemory}!*Io.AnyFuture {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = result_len;
    _ = result_alignment;
    _ = context;
    _ = context_alignment;
    _ = start;
    @panic("TODO");
}

fn await(
    userdata: ?*anyopaque,
    any_future: *Io.AnyFuture,
    result: []u8,
    result_alignment: std.mem.Alignment,
) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = any_future;
    _ = result;
    _ = result_alignment;
    @panic("TODO");
}

fn cancel(
    userdata: ?*anyopaque,
    any_future: *Io.AnyFuture,
    result: []u8,
    result_alignment: std.mem.Alignment,
) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = any_future;
    _ = result;
    _ = result_alignment;
    @panic("TODO");
}

fn cancelRequested(userdata: ?*anyopaque) bool {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    return false; // TODO
}

fn groupAsync(
    userdata: ?*anyopaque,
    group: *Io.Group,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (*Io.Group, context: *const anyopaque) void,
) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = group;
    _ = context;
    _ = context_alignment;
    _ = start;
    @panic("TODO");
}

fn groupWait(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) Io.Cancelable!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = group;
    _ = token;
    @panic("TODO");
}

fn groupWaitUncancelable(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = group;
    _ = token;
    @panic("TODO");
}

fn groupCancel(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = group;
    _ = token;
    @panic("TODO");
}

fn select(userdata: ?*anyopaque, futures: []const *Io.AnyFuture) Io.Cancelable!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = futures;
    @panic("TODO");
}

fn mutexLock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) Io.Cancelable!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = prev_state;
    _ = mutex;
    @panic("TODO");
}
fn mutexLockUncancelable(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = prev_state;
    _ = mutex;
    @panic("TODO");
}
fn mutexUnlock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = prev_state;
    _ = mutex;
    @panic("TODO");
}

fn conditionWait(userdata: ?*anyopaque, cond: *Io.Condition, mutex: *Io.Mutex) Io.Cancelable!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = cond;
    _ = mutex;
    @panic("TODO");
}
fn conditionWaitUncancelable(userdata: ?*anyopaque, cond: *Io.Condition, mutex: *Io.Mutex) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = cond;
    _ = mutex;
    @panic("TODO");
}
fn conditionWake(userdata: ?*anyopaque, cond: *Io.Condition, wake: Io.Condition.Wake) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = cond;
    _ = wake;
    @panic("TODO");
}

fn dirMake(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, mode: Dir.Mode) Dir.MakeError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = mode;
    @panic("TODO");
}
fn dirMakePath(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, mode: Dir.Mode) Dir.MakeError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = mode;
    @panic("TODO");
}
fn dirMakeOpenPath(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, options: Dir.OpenOptions) Dir.MakeOpenPathError!Dir {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = options;
    @panic("TODO");
}
fn dirStat(userdata: ?*anyopaque, dir: Dir) Dir.StatError!Dir.Stat {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    @panic("TODO");
}
fn dirStatPath(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, options: Dir.StatPathOptions) Dir.StatPathError!File.Stat {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = options;
    @panic("TODO");
}
fn dirAccess(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, options: Dir.AccessOptions) Dir.AccessError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = options;
    @panic("TODO");
}
fn dirCreateFile(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = flags;
    @panic("TODO");
}
fn dirOpenFile(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = flags;
    @panic("TODO");
}
fn dirOpenDir(userdata: ?*anyopaque, dir: Dir, sub_path: []const u8, options: Dir.OpenOptions) Dir.OpenError!Dir {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    _ = sub_path;
    _ = options;
    @panic("TODO");
}
fn dirClose(userdata: ?*anyopaque, dir: Dir) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dir;
    @panic("TODO");
}
fn fileStat(userdata: ?*anyopaque, file: File) File.StatError!File.Stat {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    @panic("TODO");
}
fn fileClose(userdata: ?*anyopaque, file: File) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    @panic("TODO");
}
fn fileWriteStreaming(userdata: ?*anyopaque, file: File, buffer: [][]const u8) File.WriteStreamingError!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = buffer;
    @panic("TODO");
}
fn fileWritePositional(userdata: ?*anyopaque, file: File, buffer: [][]const u8, offset: u64) File.WritePositionalError!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = buffer;
    _ = offset;
    @panic("TODO");
}
fn fileReadStreaming(userdata: ?*anyopaque, file: File, data: [][]u8) File.ReadStreamingError!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = data;
    @panic("TODO");
}
fn fileReadPositional(userdata: ?*anyopaque, file: File, data: [][]u8, offset: u64) File.ReadPositionalError!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = data;
    _ = offset;
    @panic("TODO");
}
fn fileSeekBy(userdata: ?*anyopaque, file: File, relative_offset: i64) File.SeekError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = relative_offset;
    @panic("TODO");
}
fn fileSeekTo(userdata: ?*anyopaque, file: File, absolute_offset: u64) File.SeekError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    _ = absolute_offset;
    @panic("TODO");
}
fn openSelfExe(userdata: ?*anyopaque, file: File.OpenFlags) File.OpenSelfExeError!File {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = file;
    @panic("TODO");
}

fn now(userdata: ?*anyopaque, clock: Io.Clock) Io.Clock.Error!Io.Timestamp {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = clock;
    @panic("TODO");
}
fn sleep(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = timeout;
    @panic("TODO");
}

fn netListenIp(
    userdata: ?*anyopaque,
    address: net.IpAddress,
    options: net.IpAddress.ListenOptions,
) net.IpAddress.ListenError!net.Server {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = address;
    _ = options;
    @panic("TODO");
}
fn netAccept(userdata: ?*anyopaque, server: net.Socket.Handle) net.Server.AcceptError!net.Stream {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = server;
    @panic("TODO");
}
fn netBindIp(
    userdata: ?*anyopaque,
    address: *const net.IpAddress,
    options: net.IpAddress.BindOptions,
) net.IpAddress.BindError!net.Socket {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    const family = Io.Threaded.posixAddressFamily(address);
    const socket_fd = try openSocketPosix(k, family, options);
    errdefer posix.close(socket_fd);
    var storage: Io.Threaded.PosixAddress = undefined;
    var addr_len = Io.Threaded.addressToPosix(address, &storage);
    try posixBind(k, socket_fd, &storage.any, addr_len);
    try posixGetSockName(k, socket_fd, &storage.any, &addr_len);
    return .{
        .handle = socket_fd,
        .address = Io.Threaded.addressFromPosix(&storage),
    };
}
fn netConnectIp(userdata: ?*anyopaque, address: *const net.IpAddress, options: net.IpAddress.ConnectOptions) net.IpAddress.ConnectError!net.Stream {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = address;
    _ = options;
    @panic("TODO");
}
fn netListenUnix(
    userdata: ?*anyopaque,
    unix_address: *const net.UnixAddress,
    options: net.UnixAddress.ListenOptions,
) net.UnixAddress.ListenError!net.Socket.Handle {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = unix_address;
    _ = options;
    @panic("TODO");
}
fn netConnectUnix(
    userdata: ?*anyopaque,
    unix_address: *const net.UnixAddress,
) net.UnixAddress.ConnectError!net.Socket.Handle {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = unix_address;
    @panic("TODO");
}

fn netSend(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    outgoing_messages: []net.OutgoingMessage,
    flags: net.SendFlags,
) struct { ?net.Socket.SendError, usize } {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));

    const posix_flags: u32 =
        @as(u32, if (@hasDecl(posix.MSG, "CONFIRM") and flags.confirm) posix.MSG.CONFIRM else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "DONTROUTE") and flags.dont_route) posix.MSG.DONTROUTE else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "EOR") and flags.eor) posix.MSG.EOR else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "OOB") and flags.oob) posix.MSG.OOB else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "FASTOPEN") and flags.fastopen) posix.MSG.FASTOPEN else 0) |
        posix.MSG.NOSIGNAL;

    _ = k;
    _ = posix_flags;
    _ = handle;
    _ = outgoing_messages;
    @panic("TODO");
}

fn netReceive(
    userdata: ?*anyopaque,
    handle: net.Socket.Handle,
    message_buffer: []net.IncomingMessage,
    data_buffer: []u8,
    flags: net.ReceiveFlags,
    timeout: Io.Timeout,
) struct { ?net.Socket.ReceiveTimeoutError, usize } {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = handle;
    _ = message_buffer;
    _ = data_buffer;
    _ = flags;
    _ = timeout;
    @panic("TODO");
}
fn netRead(userdata: ?*anyopaque, src: net.Socket.Handle, data: [][]u8) net.Stream.Reader.Error!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = src;
    _ = data;
    @panic("TODO");
}
fn netWrite(userdata: ?*anyopaque, dest: net.Socket.Handle, header: []const u8, data: []const []const u8, splat: usize) net.Stream.Writer.Error!usize {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = dest;
    _ = header;
    _ = data;
    _ = splat;
    @panic("TODO");
}
fn netClose(userdata: ?*anyopaque, handle: net.Socket.Handle) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = handle;
    @panic("TODO");
}
fn netInterfaceNameResolve(
    userdata: ?*anyopaque,
    name: *const net.Interface.Name,
) net.Interface.Name.ResolveError!net.Interface {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = name;
    @panic("TODO");
}
fn netInterfaceName(userdata: ?*anyopaque, interface: net.Interface) net.Interface.NameError!net.Interface.Name {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = interface;
    @panic("TODO");
}
fn netLookup(
    userdata: ?*anyopaque,
    host_name: net.HostName,
    result: *Io.Queue(net.HostName.LookupResult),
    options: net.HostName.LookupOptions,
) void {
    const k: *Kqueue = @ptrCast(@alignCast(userdata));
    _ = k;
    _ = host_name;
    _ = result;
    _ = options;
    @panic("TODO");
}

fn openSocketPosix(
    k: *Kqueue,
    family: posix.sa_family_t,
    options: IpAddress.BindOptions,
) error{
    AddressFamilyUnsupported,
    ProtocolUnsupportedBySystem,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    SystemResources,
    ProtocolUnsupportedByAddressFamily,
    SocketModeUnsupported,
    OptionUnsupported,
    Unexpected,
    Canceled,
}!posix.socket_t {
    const mode = Io.Threaded.posixSocketMode(options.mode);
    const protocol = Io.Threaded.posixProtocol(options.protocol);
    const socket_fd = while (true) {
        try k.checkCancel();
        const flags: u32 = mode | if (Io.Threaded.socket_flags_unsupported) 0 else posix.SOCK.CLOEXEC;
        const socket_rc = posix.system.socket(family, flags, protocol);
        switch (posix.errno(socket_rc)) {
            .SUCCESS => {
                const fd: posix.fd_t = @intCast(socket_rc);
                errdefer posix.close(fd);
                if (Io.Threaded.socket_flags_unsupported) {
                    while (true) {
                        try k.checkCancel();
                        switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, @as(usize, posix.FD_CLOEXEC)))) {
                            .SUCCESS => break,
                            .INTR => continue,
                            .CANCELED => return error.Canceled,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                    }

                    var fl_flags: usize = while (true) {
                        try k.checkCancel();
                        const rc = posix.system.fcntl(fd, posix.F.GETFL, @as(usize, 0));
                        switch (posix.errno(rc)) {
                            .SUCCESS => break @intCast(rc),
                            .INTR => continue,
                            .CANCELED => return error.Canceled,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                    };
                    fl_flags &= ~@as(usize, 1 << @bitOffsetOf(posix.O, "NONBLOCK"));
                    while (true) {
                        try k.checkCancel();
                        switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFL, fl_flags))) {
                            .SUCCESS => break,
                            .INTR => continue,
                            .CANCELED => return error.Canceled,
                            else => |err| return posix.unexpectedErrno(err),
                        }
                    }
                }
                break fd;
            },
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .INVAL => return error.ProtocolUnsupportedBySystem,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .PROTONOSUPPORT => return error.ProtocolUnsupportedByAddressFamily,
            .PROTOTYPE => return error.SocketModeUnsupported,
            else => |err| return posix.unexpectedErrno(err),
        }
    };
    errdefer posix.close(socket_fd);

    if (options.ip6_only) {
        if (posix.IPV6 == void) return error.OptionUnsupported;
        try setSocketOption(k, socket_fd, posix.IPPROTO.IPV6, posix.IPV6.V6ONLY, 0);
    }

    return socket_fd;
}

fn posixBind(
    k: *Kqueue,
    socket_fd: posix.socket_t,
    addr: *const posix.sockaddr,
    addr_len: posix.socklen_t,
) !void {
    while (true) {
        try k.checkCancel();
        switch (posix.errno(posix.system.bind(socket_fd, addr, addr_len))) {
            .SUCCESS => break,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .ADDRINUSE => return error.AddressInUse,
            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .INVAL => |err| return errnoBug(err), // invalid parameters
            .NOTSOCK => |err| return errnoBug(err), // invalid `sockfd`
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .ADDRNOTAVAIL => return error.AddressUnavailable,
            .FAULT => |err| return errnoBug(err), // invalid `addr` pointer
            .NOMEM => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn posixGetSockName(k: *Kqueue, socket_fd: posix.fd_t, addr: *posix.sockaddr, addr_len: *posix.socklen_t) !void {
    while (true) {
        try k.checkCancel();
        switch (posix.errno(posix.system.getsockname(socket_fd, addr, addr_len))) {
            .SUCCESS => break,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .FAULT => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err), // invalid parameters
            .NOTSOCK => |err| return errnoBug(err), // always a race condition
            .NOBUFS => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn setSocketOption(k: *Kqueue, fd: posix.fd_t, level: i32, opt_name: u32, option: u32) !void {
    const o: []const u8 = @ptrCast(&option);
    while (true) {
        try k.checkCancel();
        switch (posix.errno(posix.system.setsockopt(fd, level, opt_name, o.ptr, @intCast(o.len)))) {
            .SUCCESS => return,
            .INTR => continue,
            .CANCELED => return error.Canceled,

            .BADF => |err| return errnoBug(err), // File descriptor used after closed.
            .NOTSOCK => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn checkCancel(k: *Kqueue) error{Canceled}!void {
    if (cancelRequested(k)) return error.Canceled;
}
