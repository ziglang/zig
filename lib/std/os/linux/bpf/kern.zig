const std = @import("../../../std.zig");
const builtin = @import("builtin");

const in_bpf_program = switch (builtin.cpu.arch) {
    .bpfel, .bpfeb => true,
    else => false,
};

pub const helpers = if (in_bpf_program) @import("helpers.zig") else struct {};

pub const BpfSock = anyopaque;
pub const BpfSockAddr = anyopaque;
pub const FibLookup = anyopaque;
pub const MapDef = anyopaque;
pub const PerfEventData = anyopaque;
pub const PerfEventValue = anyopaque;
pub const PidNsInfo = anyopaque;
pub const SeqFile = anyopaque;
pub const SkBuff = anyopaque;
pub const SkMsgMd = anyopaque;
pub const SkReusePortMd = anyopaque;
pub const Sock = anyopaque;
pub const SockAddr = anyopaque;
pub const SockOps = anyopaque;
pub const SockTuple = anyopaque;
pub const SpinLock = anyopaque;
pub const SysCtl = anyopaque;
pub const Tcp6Sock = anyopaque;
pub const TcpRequestSock = anyopaque;
pub const TcpSock = anyopaque;
pub const TcpTimewaitSock = anyopaque;
pub const TunnelKey = anyopaque;
pub const Udp6Sock = anyopaque;
pub const XdpMd = anyopaque;
pub const XfrmState = anyopaque;
