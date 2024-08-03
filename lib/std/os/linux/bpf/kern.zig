const std = @import("../../../std.zig");
const builtin = @import("builtin");

const in_bpf_program = switch (builtin.cpu.arch) {
    .bpfel, .bpfeb => true,
    else => false,
};

pub const helpers = if (in_bpf_program) @import("helpers.zig") else struct {};

pub const BPF = struct {
    const BinPrm = opaque {};
    const BTFPtr = opaque {};
    const BpfDynPtr = opaque {};
    const BpfRedirNeigh = opaque {};
    const BpfSock = opaque {};
    const BpfSockAddr = opaque {};
    const BpfSockOps = opaque {};
    const BpfTimer = opaque {};
    const FibLookup = opaque {};
    const File = opaque {};
    const Inode = opaque {};
    const IpHdr = opaque {};
    const Ipv6Hdr = opaque {};
    const MapDef = opaque {};
    const MpTcpSock = opaque {};
    const Path = opaque {};
    const PerfEventData = opaque {};
    const PerfEventValue = opaque {};
    const PidNsInfo = opaque {};
    const SeqFile = opaque {};
    const SkBuff = opaque {};
    const SkMsgMd = opaque {};
    const SkReusePortMd = opaque {};
    const Sock = opaque {};
    const Socket = opaque {};
    const SockAddr = opaque {};
    const SockOps = opaque {};
    const SockTuple = opaque {};
    const SpinLock = opaque {};
    const SysCtl = opaque {};
    const Task = opaque {};
    const Tcp6Sock = opaque {};
    const TcpRequestSock = opaque {};
    const TcpSock = opaque {};
    const TcpTimewaitSock = opaque {};
    const TunnelKey = opaque {};
    const Udp6Sock = opaque {};
    const UnixSock = opaque {};
    const XdpMd = opaque {};
    const XfrmState = opaque {};
};

comptime {
    if (in_bpf_program) {
        // Include additional BPF-specific code here if needed
    }
}
