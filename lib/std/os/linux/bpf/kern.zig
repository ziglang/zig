const std = @import("../../../std.zig");

const in_bpf_program = switch (std.builtin.cpu.arch) {
    .bpfel, .bpfeb => true,
    else => false,
};

pub const helpers = if (in_bpf_program) @import("helpers.zig") else struct {};

pub const BpfSock = opaque {};
pub const BpfSockAddr = opaque {};
pub const FibLookup = opaque {};
pub const MapDef = opaque {};
pub const PerfEventData = opaque {};
pub const PerfEventValue = opaque {};
pub const PidNsInfo = opaque {};
pub const SeqFile = opaque {};
pub const SkBuff = opaque {};
pub const SkMsgMd = opaque {};
pub const SkReusePortMd = opaque {};
pub const Sock = opaque {};
pub const SockAddr = opaque {};
pub const SockOps = opaque {};
pub const SockTuple = opaque {};
pub const SpinLock = opaque {};
pub const SysCtl = opaque {};
pub const Tcp6Sock = opaque {};
pub const TcpRequestSock = opaque {};
pub const TcpSock = opaque {};
pub const TcpTimewaitSock = opaque {};
pub const TunnelKey = opaque {};
pub const Udp6Sock = opaque {};
pub const XdpMd = opaque {};
pub const XfrmState = opaque {};
