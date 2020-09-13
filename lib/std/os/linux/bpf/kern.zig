// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../../std.zig");

const in_bpf_program = switch (std.builtin.arch) {
    .bpfel, .bpfeb => true,
    else => false,
};

pub const helpers = if (in_bpf_program) @import("helpers.zig") else struct {};

// TODO: fill these in
pub const BpfSock = packed struct {};
pub const BpfSockAddr = packed struct {};
pub const FibLookup = packed struct {};
pub const MapDef = packed struct {};
pub const PerfEventData = packed struct {};
pub const PerfEventValue = packed struct {};
pub const PidNsInfo = packed struct {};
pub const SeqFile = packed struct {};
pub const SkBuff = packed struct {};
pub const SkMsgMd = packed struct {};
pub const SkReusePortMd = packed struct {};
pub const Sock = packed struct {};
pub const SockAddr = packed struct {};
pub const SockOps = packed struct {};
pub const SockTuple = packed struct {};
pub const SpinLock = packed struct {};
pub const SysCtl = packed struct {};
pub const Tcp6Sock = packed struct {};
pub const TcpRequestSock = packed struct {};
pub const TcpSock = packed struct {};
pub const TcpTimewaitSock = packed struct {};
pub const TunnelKey = packed struct {};
pub const Udp6Sock = packed struct {};
pub const XdpMd = packed struct {};
pub const XfrmState = packed struct {};
