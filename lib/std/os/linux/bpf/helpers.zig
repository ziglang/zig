// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const kern = @import("kern.zig");

// in BPF, all the helper calls
// TODO: when https://github.com/ziglang/zig/issues/1717 is here, make a nice
// function that uses the Helper enum
//
// Note, these function signatures were created from documentation found in
// '/usr/include/linux/bpf.h'
pub const map_lookup_elem = @intToPtr(fn (map: *const kern.MapDef, key: ?*const c_void) ?*c_void, 1);
pub const map_update_elem = @intToPtr(fn (map: *const kern.MapDef, key: ?*const c_void, value: ?*const c_void, flags: u64) c_long, 2);
pub const map_delete_elem = @intToPtr(fn (map: *const kern.MapDef, key: ?*const c_void) c_long, 3);
pub const probe_read = @intToPtr(fn (dst: ?*c_void, size: u32, unsafe_ptr: ?*const c_void) c_long, 4);
pub const ktime_get_ns = @intToPtr(fn () u64, 5);
pub const trace_printk = @intToPtr(fn (fmt: [*:0]const u8, fmt_size: u32, arg1: u64, arg2: u64, arg3: u64) c_long, 6);
pub const get_prandom_u32 = @intToPtr(fn () u32, 7);
pub const get_smp_processor_id = @intToPtr(fn () u32, 8);
pub const skb_store_bytes = @intToPtr(fn (skb: *kern.SkBuff, offset: u32, from: ?*const c_void, len: u32, flags: u64) c_long, 9);
pub const l3_csum_replace = @intToPtr(fn (skb: *kern.SkBuff, offset: u32, from: u64, to: u64, size: u64) c_long, 10);
pub const l4_csum_replace = @intToPtr(fn (skb: *kern.SkBuff, offset: u32, from: u64, to: u64, flags: u64) c_long, 11);
pub const tail_call = @intToPtr(fn (ctx: ?*c_void, prog_array_map: *const kern.MapDef, index: u32) c_long, 12);
pub const clone_redirect = @intToPtr(fn (skb: *kern.SkBuff, ifindex: u32, flags: u64) c_long, 13);
pub const get_current_pid_tgid = @intToPtr(fn () u64, 14);
pub const get_current_uid_gid = @intToPtr(fn () u64, 15);
pub const get_current_comm = @intToPtr(fn (buf: ?*c_void, size_of_buf: u32) c_long, 16);
pub const get_cgroup_classid = @intToPtr(fn (skb: *kern.SkBuff) u32, 17);
// Note vlan_proto is big endian
pub const skb_vlan_push = @intToPtr(fn (skb: *kern.SkBuff, vlan_proto: u16, vlan_tci: u16) c_long, 18);
pub const skb_vlan_pop = @intToPtr(fn (skb: *kern.SkBuff) c_long, 19);
pub const skb_get_tunnel_key = @intToPtr(fn (skb: *kern.SkBuff, key: *kern.TunnelKey, size: u32, flags: u64) c_long, 20);
pub const skb_set_tunnel_key = @intToPtr(fn (skb: *kern.SkBuff, key: *kern.TunnelKey, size: u32, flags: u64) c_long, 21);
pub const perf_event_read = @intToPtr(fn (map: *const kern.MapDef, flags: u64) u64, 22);
pub const redirect = @intToPtr(fn (ifindex: u32, flags: u64) c_long, 23);
pub const get_route_realm = @intToPtr(fn (skb: *kern.SkBuff) u32, 24);
pub const perf_event_output = @intToPtr(fn (ctx: ?*c_void, map: *const kern.MapDef, flags: u64, data: ?*c_void, size: u64) c_long, 25);
pub const skb_load_bytes = @intToPtr(fn (skb: ?*c_void, offset: u32, to: ?*c_void, len: u32) c_long, 26);
pub const get_stackid = @intToPtr(fn (ctx: ?*c_void, map: *const kern.MapDef, flags: u64) c_long, 27);
// from and to point to __be32
pub const csum_diff = @intToPtr(fn (from: *u32, from_size: u32, to: *u32, to_size: u32, seed: u32) i64, 28);
pub const skb_get_tunnel_opt = @intToPtr(fn (skb: *kern.SkBuff, opt: ?*c_void, size: u32) c_long, 29);
pub const skb_set_tunnel_opt = @intToPtr(fn (skb: *kern.SkBuff, opt: ?*c_void, size: u32) c_long, 30);
// proto is __be16
pub const skb_change_proto = @intToPtr(fn (skb: *kern.SkBuff, proto: u16, flags: u64) c_long, 31);
pub const skb_change_type = @intToPtr(fn (skb: *kern.SkBuff, skb_type: u32) c_long, 32);
pub const skb_under_cgroup = @intToPtr(fn (skb: *kern.SkBuff, map: ?*const c_void, index: u32) c_long, 33);
pub const get_hash_recalc = @intToPtr(fn (skb: *kern.SkBuff) u32, 34);
pub const get_current_task = @intToPtr(fn () u64, 35);
pub const probe_write_user = @intToPtr(fn (dst: ?*c_void, src: ?*const c_void, len: u32) c_long, 36);
pub const current_task_under_cgroup = @intToPtr(fn (map: *const kern.MapDef, index: u32) c_long, 37);
pub const skb_change_tail = @intToPtr(fn (skb: *kern.SkBuff, len: u32, flags: u64) c_long, 38);
pub const skb_pull_data = @intToPtr(fn (skb: *kern.SkBuff, len: u32) c_long, 39);
pub const csum_update = @intToPtr(fn (skb: *kern.SkBuff, csum: u32) i64, 40);
pub const set_hash_invalid = @intToPtr(fn (skb: *kern.SkBuff) void, 41);
pub const get_numa_node_id = @intToPtr(fn () c_long, 42);
pub const skb_change_head = @intToPtr(fn (skb: *kern.SkBuff, len: u32, flags: u64) c_long, 43);
pub const xdp_adjust_head = @intToPtr(fn (xdp_md: *kern.XdpMd, delta: c_int) c_long, 44);
pub const probe_read_str = @intToPtr(fn (dst: ?*c_void, size: u32, unsafe_ptr: ?*const c_void) c_long, 45);
pub const get_socket_cookie = @intToPtr(fn (ctx: ?*c_void) u64, 46);
pub const get_socket_uid = @intToPtr(fn (skb: *kern.SkBuff) u32, 47);
pub const set_hash = @intToPtr(fn (skb: *kern.SkBuff, hash: u32) c_long, 48);
pub const setsockopt = @intToPtr(fn (bpf_socket: *kern.SockOps, level: c_int, optname: c_int, optval: ?*c_void, optlen: c_int) c_long, 49);
pub const skb_adjust_room = @intToPtr(fn (skb: *kern.SkBuff, len_diff: i32, mode: u32, flags: u64) c_long, 50);
pub const redirect_map = @intToPtr(fn (map: *const kern.MapDef, key: u32, flags: u64) c_long, 51);
pub const sk_redirect_map = @intToPtr(fn (skb: *kern.SkBuff, map: *const kern.MapDef, key: u32, flags: u64) c_long, 52);
pub const sock_map_update = @intToPtr(fn (skops: *kern.SockOps, map: *const kern.MapDef, key: ?*c_void, flags: u64) c_long, 53);
pub const xdp_adjust_meta = @intToPtr(fn (xdp_md: *kern.XdpMd, delta: c_int) c_long, 54);
pub const perf_event_read_value = @intToPtr(fn (map: *const kern.MapDef, flags: u64, buf: *kern.PerfEventValue, buf_size: u32) c_long, 55);
pub const perf_prog_read_value = @intToPtr(fn (ctx: *kern.PerfEventData, buf: *kern.PerfEventValue, buf_size: u32) c_long, 56);
pub const getsockopt = @intToPtr(fn (bpf_socket: ?*c_void, level: c_int, optname: c_int, optval: ?*c_void, optlen: c_int) c_long, 57);
pub const override_return = @intToPtr(fn (regs: *PtRegs, rc: u64) c_long, 58);
pub const sock_ops_cb_flags_set = @intToPtr(fn (bpf_sock: *kern.SockOps, argval: c_int) c_long, 59);
pub const msg_redirect_map = @intToPtr(fn (msg: *kern.SkMsgMd, map: *const kern.MapDef, key: u32, flags: u64) c_long, 60);
pub const msg_apply_bytes = @intToPtr(fn (msg: *kern.SkMsgMd, bytes: u32) c_long, 61);
pub const msg_cork_bytes = @intToPtr(fn (msg: *kern.SkMsgMd, bytes: u32) c_long, 62);
pub const msg_pull_data = @intToPtr(fn (msg: *kern.SkMsgMd, start: u32, end: u32, flags: u64) c_long, 63);
pub const bind = @intToPtr(fn (ctx: *kern.BpfSockAddr, addr: *kern.SockAddr, addr_len: c_int) c_long, 64);
pub const xdp_adjust_tail = @intToPtr(fn (xdp_md: *kern.XdpMd, delta: c_int) c_long, 65);
pub const skb_get_xfrm_state = @intToPtr(fn (skb: *kern.SkBuff, index: u32, xfrm_state: *kern.XfrmState, size: u32, flags: u64) c_long, 66);
pub const get_stack = @intToPtr(fn (ctx: ?*c_void, buf: ?*c_void, size: u32, flags: u64) c_long, 67);
pub const skb_load_bytes_relative = @intToPtr(fn (skb: ?*const c_void, offset: u32, to: ?*c_void, len: u32, start_header: u32) c_long, 68);
pub const fib_lookup = @intToPtr(fn (ctx: ?*c_void, params: *kern.FibLookup, plen: c_int, flags: u32) c_long, 69);
pub const sock_hash_update = @intToPtr(fn (skops: *kern.SockOps, map: *const kern.MapDef, key: ?*c_void, flags: u64) c_long, 70);
pub const msg_redirect_hash = @intToPtr(fn (msg: *kern.SkMsgMd, map: *const kern.MapDef, key: ?*c_void, flags: u64) c_long, 71);
pub const sk_redirect_hash = @intToPtr(fn (skb: *kern.SkBuff, map: *const kern.MapDef, key: ?*c_void, flags: u64) c_long, 72);
pub const lwt_push_encap = @intToPtr(fn (skb: *kern.SkBuff, typ: u32, hdr: ?*c_void, len: u32) c_long, 73);
pub const lwt_seg6_store_bytes = @intToPtr(fn (skb: *kern.SkBuff, offset: u32, from: ?*const c_void, len: u32) c_long, 74);
pub const lwt_seg6_adjust_srh = @intToPtr(fn (skb: *kern.SkBuff, offset: u32, delta: i32) c_long, 75);
pub const lwt_seg6_action = @intToPtr(fn (skb: *kern.SkBuff, action: u32, param: ?*c_void, param_len: u32) c_long, 76);
pub const rc_repeat = @intToPtr(fn (ctx: ?*c_void) c_long, 77);
pub const rc_keydown = @intToPtr(fn (ctx: ?*c_void, protocol: u32, scancode: u64, toggle: u32) c_long, 78);
pub const skb_cgroup_id = @intToPtr(fn (skb: *kern.SkBuff) u64, 79);
pub const get_current_cgroup_id = @intToPtr(fn () u64, 80);
pub const get_local_storage = @intToPtr(fn (map: ?*c_void, flags: u64) ?*c_void, 81);
pub const sk_select_reuseport = @intToPtr(fn (reuse: *kern.SkReusePortMd, map: *const kern.MapDef, key: ?*c_void, flags: u64) c_long, 82);
pub const skb_ancestor_cgroup_id = @intToPtr(fn (skb: *kern.SkBuff, ancestor_level: c_int) u64, 83);
pub const sk_lookup_tcp = @intToPtr(fn (ctx: ?*c_void, tuple: *kern.SockTuple, tuple_size: u32, netns: u64, flags: u64) ?*kern.Sock, 84);
pub const sk_lookup_udp = @intToPtr(fn (ctx: ?*c_void, tuple: *kern.SockTuple, tuple_size: u32, netns: u64, flags: u64) ?*kern.Sock, 85);
pub const sk_release = @intToPtr(fn (sock: *kern.Sock) c_long, 86);
pub const map_push_elem = @intToPtr(fn (map: *const kern.MapDef, value: ?*const c_void, flags: u64) c_long, 87);
pub const map_pop_elem = @intToPtr(fn (map: *const kern.MapDef, value: ?*c_void) c_long, 88);
pub const map_peek_elem = @intToPtr(fn (map: *const kern.MapDef, value: ?*c_void) c_long, 89);
pub const msg_push_data = @intToPtr(fn (msg: *kern.SkMsgMd, start: u32, len: u32, flags: u64) c_long, 90);
pub const msg_pop_data = @intToPtr(fn (msg: *kern.SkMsgMd, start: u32, len: u32, flags: u64) c_long, 91);
pub const rc_pointer_rel = @intToPtr(fn (ctx: ?*c_void, rel_x: i32, rel_y: i32) c_long, 92);
pub const spin_lock = @intToPtr(fn (lock: *kern.SpinLock) c_long, 93);
pub const spin_unlock = @intToPtr(fn (lock: *kern.SpinLock) c_long, 94);
pub const sk_fullsock = @intToPtr(fn (sk: *kern.Sock) ?*SkFullSock, 95);
pub const tcp_sock = @intToPtr(fn (sk: *kern.Sock) ?*kern.TcpSock, 96);
pub const skb_ecn_set_ce = @intToPtr(fn (skb: *kern.SkBuff) c_long, 97);
pub const get_listener_sock = @intToPtr(fn (sk: *kern.Sock) ?*kern.Sock, 98);
pub const skc_lookup_tcp = @intToPtr(fn (ctx: ?*c_void, tuple: *kern.SockTuple, tuple_size: u32, netns: u64, flags: u64) ?*kern.Sock, 99);
pub const tcp_check_syncookie = @intToPtr(fn (sk: *kern.Sock, iph: ?*c_void, iph_len: u32, th: *TcpHdr, th_len: u32) c_long, 100);
pub const sysctl_get_name = @intToPtr(fn (ctx: *kern.SysCtl, buf: ?*u8, buf_len: c_ulong, flags: u64) c_long, 101);
pub const sysctl_get_current_value = @intToPtr(fn (ctx: *kern.SysCtl, buf: ?*u8, buf_len: c_ulong) c_long, 102);
pub const sysctl_get_new_value = @intToPtr(fn (ctx: *kern.SysCtl, buf: ?*u8, buf_len: c_ulong) c_long, 103);
pub const sysctl_set_new_value = @intToPtr(fn (ctx: *kern.SysCtl, buf: ?*const u8, buf_len: c_ulong) c_long, 104);
pub const strtol = @intToPtr(fn (buf: *const u8, buf_len: c_ulong, flags: u64, res: *c_long) c_long, 105);
pub const strtoul = @intToPtr(fn (buf: *const u8, buf_len: c_ulong, flags: u64, res: *c_ulong) c_long, 106);
pub const sk_storage_get = @intToPtr(fn (map: *const kern.MapDef, sk: *kern.Sock, value: ?*c_void, flags: u64) ?*c_void, 107);
pub const sk_storage_delete = @intToPtr(fn (map: *const kern.MapDef, sk: *kern.Sock) c_long, 108);
pub const send_signal = @intToPtr(fn (sig: u32) c_long, 109);
pub const tcp_gen_syncookie = @intToPtr(fn (sk: *kern.Sock, iph: ?*c_void, iph_len: u32, th: *TcpHdr, th_len: u32) i64, 110);
pub const skb_output = @intToPtr(fn (ctx: ?*c_void, map: *const kern.MapDef, flags: u64, data: ?*c_void, size: u64) c_long, 111);
pub const probe_read_user = @intToPtr(fn (dst: ?*c_void, size: u32, unsafe_ptr: ?*const c_void) c_long, 112);
pub const probe_read_kernel = @intToPtr(fn (dst: ?*c_void, size: u32, unsafe_ptr: ?*const c_void) c_long, 113);
pub const probe_read_user_str = @intToPtr(fn (dst: ?*c_void, size: u32, unsafe_ptr: ?*const c_void) c_long, 114);
pub const probe_read_kernel_str = @intToPtr(fn (dst: ?*c_void, size: u32, unsafe_ptr: ?*const c_void) c_long, 115);
pub const tcp_send_ack = @intToPtr(fn (tp: ?*c_void, rcv_nxt: u32) c_long, 116);
pub const send_signal_thread = @intToPtr(fn (sig: u32) c_long, 117);
pub const jiffies64 = @intToPtr(fn () u64, 118);
pub const read_branch_records = @intToPtr(fn (ctx: *kern.PerfEventData, buf: ?*c_void, size: u32, flags: u64) c_long, 119);
pub const get_ns_current_pid_tgid = @intToPtr(fn (dev: u64, ino: u64, nsdata: *kern.PidNsInfo, size: u32) c_long, 120);
pub const xdp_output = @intToPtr(fn (ctx: ?*c_void, map: *const kern.MapDef, flags: u64, data: ?*c_void, size: u64) c_long, 121);
pub const get_netns_cookie = @intToPtr(fn (ctx: ?*c_void) u64, 122);
pub const get_current_ancestor_cgroup_id = @intToPtr(fn (ancestor_level: c_int) u64, 123);
pub const sk_assign = @intToPtr(fn (skb: *kern.SkBuff, sk: *kern.Sock, flags: u64) c_long, 124);
pub const ktime_get_boot_ns = @intToPtr(fn () u64, 125);
pub const seq_printf = @intToPtr(fn (m: *kern.SeqFile, fmt: ?*const u8, fmt_size: u32, data: ?*const c_void, data_len: u32) c_long, 126);
pub const seq_write = @intToPtr(fn (m: *kern.SeqFile, data: ?*const u8, len: u32) c_long, 127);
pub const sk_cgroup_id = @intToPtr(fn (sk: *kern.BpfSock) u64, 128);
pub const sk_ancestor_cgroup_id = @intToPtr(fn (sk: *kern.BpfSock, ancestor_level: c_long) u64, 129);
pub const ringbuf_output = @intToPtr(fn (ringbuf: ?*c_void, data: ?*c_void, size: u64, flags: u64) ?*c_void, 130);
pub const ringbuf_reserve = @intToPtr(fn (ringbuf: ?*c_void, size: u64, flags: u64) ?*c_void, 131);
pub const ringbuf_submit = @intToPtr(fn (data: ?*c_void, flags: u64) void, 132);
pub const ringbuf_discard = @intToPtr(fn (data: ?*c_void, flags: u64) void, 133);
pub const ringbuf_query = @intToPtr(fn (ringbuf: ?*c_void, flags: u64) u64, 134);
pub const csum_level = @intToPtr(fn (skb: *kern.SkBuff, level: u64) c_long, 134);
pub const skc_to_tcp6_sock = @intToPtr(fn (sk: ?*c_void) ?*kern.Tcp6Sock, 135);
pub const skc_to_tcp_sock = @intToPtr(fn (sk: ?*c_void) ?*kern.TcpSock, 136);
pub const skc_to_tcp_timewait_sock = @intToPtr(fn (sk: ?*c_void) ?*kern.TcpTimewaitSock, 137);
pub const skc_to_tcp_request_sock = @intToPtr(fn (sk: ?*c_void) ?*kern.TcpRequestSock, 138);
pub const skc_to_udp6_sock = @intToPtr(fn (sk: ?*c_void) ?*kern.Udp6Sock, 139);
pub const get_task_stack = @intToPtr(fn (task: ?*c_void, buf: ?*c_void, size: u32, flags: u64) c_long, 140);
