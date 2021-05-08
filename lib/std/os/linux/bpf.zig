// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace std.os.linux;
const std = @import("../../std.zig");
const errno = getErrno;
const unexpectedErrno = std.os.unexpectedErrno;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const expect = std.testing.expect;

pub const btf = @import("bpf/btf.zig");
pub const kern = @import("bpf/kern.zig");

// instruction classes
pub const LD = 0x00;
pub const LDX = 0x01;
pub const ST = 0x02;
pub const STX = 0x03;
pub const ALU = 0x04;
pub const JMP = 0x05;
pub const RET = 0x06;
pub const MISC = 0x07;

/// 32-bit
pub const W = 0x00;
/// 16-bit
pub const H = 0x08;
/// 8-bit
pub const B = 0x10;
/// 64-bit
pub const DW = 0x18;

pub const IMM = 0x00;
pub const ABS = 0x20;
pub const IND = 0x40;
pub const MEM = 0x60;
pub const LEN = 0x80;
pub const MSH = 0xa0;

// alu fields
pub const ADD = 0x00;
pub const SUB = 0x10;
pub const MUL = 0x20;
pub const DIV = 0x30;
pub const OR = 0x40;
pub const AND = 0x50;
pub const LSH = 0x60;
pub const RSH = 0x70;
pub const NEG = 0x80;
pub const MOD = 0x90;
pub const XOR = 0xa0;

// jmp fields
pub const JA = 0x00;
pub const JEQ = 0x10;
pub const JGT = 0x20;
pub const JGE = 0x30;
pub const JSET = 0x40;

//#define BPF_SRC(code)   ((code) & 0x08)
pub const K = 0x00;
pub const X = 0x08;

pub const MAXINSNS = 4096;

// instruction classes
/// jmp mode in word width
pub const JMP32 = 0x06;

/// alu mode in double word width
pub const ALU64 = 0x07;

// ld/ldx fields
/// exclusive add
pub const XADD = 0xc0;

// alu/jmp fields
/// mov reg to reg
pub const MOV = 0xb0;

/// sign extending arithmetic shift right */
pub const ARSH = 0xc0;

// change endianness of a register
/// flags for endianness conversion:
pub const END = 0xd0;

/// convert to little-endian */
pub const TO_LE = 0x00;

/// convert to big-endian
pub const TO_BE = 0x08;
pub const FROM_LE = TO_LE;
pub const FROM_BE = TO_BE;

// jmp encodings
/// jump != *
pub const JNE = 0x50;

/// LT is unsigned, '<'
pub const JLT = 0xa0;

/// LE is unsigned, '<=' *
pub const JLE = 0xb0;

/// SGT is signed '>', GT in x86
pub const JSGT = 0x60;

/// SGE is signed '>=', GE in x86
pub const JSGE = 0x70;

/// SLT is signed, '<'
pub const JSLT = 0xc0;

/// SLE is signed, '<='
pub const JSLE = 0xd0;

/// function call
pub const CALL = 0x80;

/// function return
pub const EXIT = 0x90;

/// Flag for prog_attach command. If a sub-cgroup installs some bpf program, the
/// program in this cgroup yields to sub-cgroup program.
pub const F_ALLOW_OVERRIDE = 0x1;

/// Flag for prog_attach command. If a sub-cgroup installs some bpf program,
/// that cgroup program gets run in addition to the program in this cgroup.
pub const F_ALLOW_MULTI = 0x2;

/// Flag for prog_attach command.
pub const F_REPLACE = 0x4;

/// If BPF_F_STRICT_ALIGNMENT is used in BPF_PROG_LOAD command, the verifier
/// will perform strict alignment checking as if the kernel has been built with
/// CONFIG_EFFICIENT_UNALIGNED_ACCESS not set, and NET_IP_ALIGN defined to 2.
pub const F_STRICT_ALIGNMENT = 0x1;

/// If BPF_F_ANY_ALIGNMENT is used in BPF_PROF_LOAD command, the verifier will
/// allow any alignment whatsoever.  On platforms with strict alignment
/// requirements for loads ands stores (such as sparc and mips) the verifier
/// validates that all loads and stores provably follow this requirement.  This
/// flag turns that checking and enforcement off.
///
/// It is mostly used for testing when we want to validate the context and
/// memory access aspects of the verifier, but because of an unaligned access
/// the alignment check would trigger before the one we are interested in.
pub const F_ANY_ALIGNMENT = 0x2;

/// BPF_F_TEST_RND_HI32 is used in BPF_PROG_LOAD command for testing purpose.
/// Verifier does sub-register def/use analysis and identifies instructions
/// whose def only matters for low 32-bit, high 32-bit is never referenced later
/// through implicit zero extension. Therefore verifier notifies JIT back-ends
/// that it is safe to ignore clearing high 32-bit for these instructions. This
/// saves some back-ends a lot of code-gen. However such optimization is not
/// necessary on some arches, for example x86_64, arm64 etc, whose JIT back-ends
/// hence hasn't used verifier's analysis result. But, we really want to have a
/// way to be able to verify the correctness of the described optimization on
/// x86_64 on which testsuites are frequently exercised.
///
/// So, this flag is introduced. Once it is set, verifier will randomize high
/// 32-bit for those instructions who has been identified as safe to ignore
/// them.  Then, if verifier is not doing correct analysis, such randomization
/// will regress tests to expose bugs.
pub const F_TEST_RND_HI32 = 0x4;

/// When BPF ldimm64's insn[0].src_reg != 0 then this can have two extensions:
/// insn[0].src_reg:  BPF_PSEUDO_MAP_FD   BPF_PSEUDO_MAP_VALUE
/// insn[0].imm:      map fd              map fd
/// insn[1].imm:      0                   offset into value
/// insn[0].off:      0                   0
/// insn[1].off:      0                   0
/// ldimm64 rewrite:  address of map      address of map[0]+offset
/// verifier type:    CONST_PTR_TO_MAP    PTR_TO_MAP_VALUE
pub const PSEUDO_MAP_FD = 1;
pub const PSEUDO_MAP_VALUE = 2;

/// when bpf_call->src_reg == BPF_PSEUDO_CALL, bpf_call->imm == pc-relative
/// offset to another bpf function
pub const PSEUDO_CALL = 1;

/// flag for BPF_MAP_UPDATE_ELEM command. create new element or update existing
pub const ANY = 0;

/// flag for BPF_MAP_UPDATE_ELEM command. create new element if it didn't exist
pub const NOEXIST = 1;

/// flag for BPF_MAP_UPDATE_ELEM command. update existing element
pub const EXIST = 2;

/// flag for BPF_MAP_UPDATE_ELEM command. spin_lock-ed map_lookup/map_update
pub const F_LOCK = 4;

/// flag for BPF_MAP_CREATE command */
pub const BPF_F_NO_PREALLOC = 0x1;

/// flag for BPF_MAP_CREATE command. Instead of having one common LRU list in
/// the BPF_MAP_TYPE_LRU_[PERCPU_]HASH map, use a percpu LRU list which can
/// scale and perform better.  Note, the LRU nodes (including free nodes) cannot
/// be moved across different LRU lists.
pub const BPF_F_NO_COMMON_LRU = 0x2;

/// flag for BPF_MAP_CREATE command. Specify numa node during map creation
pub const BPF_F_NUMA_NODE = 0x4;

/// flag for BPF_MAP_CREATE command. Flags for BPF object read access from
/// syscall side
pub const BPF_F_RDONLY = 0x8;

/// flag for BPF_MAP_CREATE command. Flags for BPF object write access from
/// syscall side
pub const BPF_F_WRONLY = 0x10;

/// flag for BPF_MAP_CREATE command. Flag for stack_map, store build_id+offset
/// instead of pointer
pub const BPF_F_STACK_BUILD_ID = 0x20;

/// flag for BPF_MAP_CREATE command. Zero-initialize hash function seed. This
/// should only be used for testing.
pub const BPF_F_ZERO_SEED = 0x40;

/// flag for BPF_MAP_CREATE command Flags for accessing BPF object from program
/// side.
pub const BPF_F_RDONLY_PROG = 0x80;

/// flag for BPF_MAP_CREATE command. Flags for accessing BPF object from program
/// side.
pub const BPF_F_WRONLY_PROG = 0x100;

/// flag for BPF_MAP_CREATE command. Clone map from listener for newly accepted
/// socket
pub const BPF_F_CLONE = 0x200;

/// flag for BPF_MAP_CREATE command. Enable memory-mapping BPF map
pub const BPF_F_MMAPABLE = 0x400;

/// These values correspond to "syscalls" within the BPF program's environment,
/// each one is documented in std.os.linux.BPF.kern
pub const Helper = enum(i32) {
    unspec,
    map_lookup_elem,
    map_update_elem,
    map_delete_elem,
    probe_read,
    ktime_get_ns,
    trace_printk,
    get_prandom_u32,
    get_smp_processor_id,
    skb_store_bytes,
    l3_csum_replace,
    l4_csum_replace,
    tail_call,
    clone_redirect,
    get_current_pid_tgid,
    get_current_uid_gid,
    get_current_comm,
    get_cgroup_classid,
    skb_vlan_push,
    skb_vlan_pop,
    skb_get_tunnel_key,
    skb_set_tunnel_key,
    perf_event_read,
    redirect,
    get_route_realm,
    perf_event_output,
    skb_load_bytes,
    get_stackid,
    csum_diff,
    skb_get_tunnel_opt,
    skb_set_tunnel_opt,
    skb_change_proto,
    skb_change_type,
    skb_under_cgroup,
    get_hash_recalc,
    get_current_task,
    probe_write_user,
    current_task_under_cgroup,
    skb_change_tail,
    skb_pull_data,
    csum_update,
    set_hash_invalid,
    get_numa_node_id,
    skb_change_head,
    xdp_adjust_head,
    probe_read_str,
    get_socket_cookie,
    get_socket_uid,
    set_hash,
    setsockopt,
    skb_adjust_room,
    redirect_map,
    sk_redirect_map,
    sock_map_update,
    xdp_adjust_meta,
    perf_event_read_value,
    perf_prog_read_value,
    getsockopt,
    override_return,
    sock_ops_cb_flags_set,
    msg_redirect_map,
    msg_apply_bytes,
    msg_cork_bytes,
    msg_pull_data,
    bind,
    xdp_adjust_tail,
    skb_get_xfrm_state,
    get_stack,
    skb_load_bytes_relative,
    fib_lookup,
    sock_hash_update,
    msg_redirect_hash,
    sk_redirect_hash,
    lwt_push_encap,
    lwt_seg6_store_bytes,
    lwt_seg6_adjust_srh,
    lwt_seg6_action,
    rc_repeat,
    rc_keydown,
    skb_cgroup_id,
    get_current_cgroup_id,
    get_local_storage,
    sk_select_reuseport,
    skb_ancestor_cgroup_id,
    sk_lookup_tcp,
    sk_lookup_udp,
    sk_release,
    map_push_elem,
    map_pop_elem,
    map_peek_elem,
    msg_push_data,
    msg_pop_data,
    rc_pointer_rel,
    spin_lock,
    spin_unlock,
    sk_fullsock,
    tcp_sock,
    skb_ecn_set_ce,
    get_listener_sock,
    skc_lookup_tcp,
    tcp_check_syncookie,
    sysctl_get_name,
    sysctl_get_current_value,
    sysctl_get_new_value,
    sysctl_set_new_value,
    strtol,
    strtoul,
    sk_storage_get,
    sk_storage_delete,
    send_signal,
    tcp_gen_syncookie,
    skb_output,
    probe_read_user,
    probe_read_kernel,
    probe_read_user_str,
    probe_read_kernel_str,
    tcp_send_ack,
    send_signal_thread,
    jiffies64,
    read_branch_records,
    get_ns_current_pid_tgid,
    xdp_output,
    get_netns_cookie,
    get_current_ancestor_cgroup_id,
    sk_assign,
    ktime_get_boot_ns,
    seq_printf,
    seq_write,
    sk_cgroup_id,
    sk_ancestor_cgroup_id,
    ringbuf_output,
    ringbuf_reserve,
    ringbuf_submit,
    ringbuf_discard,
    ringbuf_query,
    csum_level,
    skc_to_tcp6_sock,
    skc_to_tcp_sock,
    skc_to_tcp_timewait_sock,
    skc_to_tcp_request_sock,
    skc_to_udp6_sock,
    get_task_stack,
    _,
};

// TODO: determine that this is the expected bit layout for both little and big
// endian systems
/// a single BPF instruction
pub const Insn = packed struct {
    code: u8,
    dst: u4,
    src: u4,
    off: i16,
    imm: i32,

    /// r0 - r9 are general purpose 64-bit registers, r10 points to the stack
    /// frame
    pub const Reg = packed enum(u4) { r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 };
    const Source = packed enum(u1) { reg, imm };

    const Mode = packed enum(u8) {
        imm = IMM,
        abs = ABS,
        ind = IND,
        mem = MEM,
        len = LEN,
        msh = MSH,
    };

    const AluOp = packed enum(u8) {
        add = ADD,
        sub = SUB,
        mul = MUL,
        div = DIV,
        alu_or = OR,
        alu_and = AND,
        lsh = LSH,
        rsh = RSH,
        neg = NEG,
        mod = MOD,
        xor = XOR,
        mov = MOV,
        arsh = ARSH,
    };

    pub const Size = packed enum(u8) {
        byte = B,
        half_word = H,
        word = W,
        double_word = DW,
    };

    const JmpOp = packed enum(u8) {
        ja = JA,
        jeq = JEQ,
        jgt = JGT,
        jge = JGE,
        jset = JSET,
        jlt = JLT,
        jle = JLE,
        jne = JNE,
        jsgt = JSGT,
        jsge = JSGE,
        jslt = JSLT,
        jsle = JSLE,
    };

    const ImmOrReg = union(Source) {
        imm: i32,
        reg: Reg,
    };

    fn imm_reg(code: u8, dst: Reg, src: anytype, off: i16) Insn {
        const imm_or_reg = if (@typeInfo(@TypeOf(src)) == .EnumLiteral)
            ImmOrReg{ .reg = @as(Reg, src) }
        else
            ImmOrReg{ .imm = src };

        const src_type = switch (imm_or_reg) {
            .imm => K,
            .reg => X,
        };

        return Insn{
            .code = code | src_type,
            .dst = @enumToInt(dst),
            .src = switch (imm_or_reg) {
                .imm => 0,
                .reg => |r| @enumToInt(r),
            },
            .off = off,
            .imm = switch (imm_or_reg) {
                .imm => |i| i,
                .reg => 0,
            },
        };
    }

    fn alu(comptime width: comptime_int, op: AluOp, dst: Reg, src: anytype) Insn {
        const width_bitfield = switch (width) {
            32 => ALU,
            64 => ALU64,
            else => @compileError("width must be 32 or 64"),
        };

        return imm_reg(width_bitfield | @enumToInt(op), dst, src, 0);
    }

    pub fn mov(dst: Reg, src: anytype) Insn {
        return alu(64, .mov, dst, src);
    }

    pub fn add(dst: Reg, src: anytype) Insn {
        return alu(64, .add, dst, src);
    }

    pub fn sub(dst: Reg, src: anytype) Insn {
        return alu(64, .sub, dst, src);
    }

    pub fn mul(dst: Reg, src: anytype) Insn {
        return alu(64, .mul, dst, src);
    }

    pub fn div(dst: Reg, src: anytype) Insn {
        return alu(64, .div, dst, src);
    }

    pub fn alu_or(dst: Reg, src: anytype) Insn {
        return alu(64, .alu_or, dst, src);
    }

    pub fn alu_and(dst: Reg, src: anytype) Insn {
        return alu(64, .alu_and, dst, src);
    }

    pub fn lsh(dst: Reg, src: anytype) Insn {
        return alu(64, .lsh, dst, src);
    }

    pub fn rsh(dst: Reg, src: anytype) Insn {
        return alu(64, .rsh, dst, src);
    }

    pub fn neg(dst: Reg) Insn {
        return alu(64, .neg, dst, 0);
    }

    pub fn mod(dst: Reg, src: anytype) Insn {
        return alu(64, .mod, dst, src);
    }

    pub fn xor(dst: Reg, src: anytype) Insn {
        return alu(64, .xor, dst, src);
    }

    pub fn arsh(dst: Reg, src: anytype) Insn {
        return alu(64, .arsh, dst, src);
    }

    fn jmp(op: JmpOp, dst: Reg, src: anytype, off: i16) Insn {
        return imm_reg(JMP | @enumToInt(op), dst, src, off);
    }

    pub fn ja(off: i16) Insn {
        return jmp(.ja, .r0, 0, off);
    }

    pub fn jeq(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jeq, dst, src, off);
    }

    pub fn jgt(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jgt, dst, src, off);
    }

    pub fn jge(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jge, dst, src, off);
    }

    pub fn jlt(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jlt, dst, src, off);
    }

    pub fn jle(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jle, dst, src, off);
    }

    pub fn jset(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jset, dst, src, off);
    }

    pub fn jne(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jne, dst, src, off);
    }

    pub fn jsgt(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jsgt, dst, src, off);
    }

    pub fn jsge(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jsge, dst, src, off);
    }

    pub fn jslt(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jslt, dst, src, off);
    }

    pub fn jsle(dst: Reg, src: anytype, off: i16) Insn {
        return jmp(.jsle, dst, src, off);
    }

    pub fn xadd(dst: Reg, src: Reg) Insn {
        return Insn{
            .code = STX | XADD | DW,
            .dst = @enumToInt(dst),
            .src = @enumToInt(src),
            .off = 0,
            .imm = 0,
        };
    }

    fn ld(mode: Mode, size: Size, dst: Reg, src: Reg, imm: i32) Insn {
        return Insn{
            .code = @enumToInt(mode) | @enumToInt(size) | LD,
            .dst = @enumToInt(dst),
            .src = @enumToInt(src),
            .off = 0,
            .imm = imm,
        };
    }

    pub fn ld_abs(size: Size, dst: Reg, src: Reg, imm: i32) Insn {
        return ld(.abs, size, dst, src, imm);
    }

    pub fn ld_ind(size: Size, dst: Reg, src: Reg, imm: i32) Insn {
        return ld(.ind, size, dst, src, imm);
    }

    pub fn ldx(size: Size, dst: Reg, src: Reg, off: i16) Insn {
        return Insn{
            .code = MEM | @enumToInt(size) | LDX,
            .dst = @enumToInt(dst),
            .src = @enumToInt(src),
            .off = off,
            .imm = 0,
        };
    }

    fn ld_imm_impl1(dst: Reg, src: Reg, imm: u64) Insn {
        return Insn{
            .code = LD | DW | IMM,
            .dst = @enumToInt(dst),
            .src = @enumToInt(src),
            .off = 0,
            .imm = @intCast(i32, @truncate(u32, imm)),
        };
    }

    fn ld_imm_impl2(imm: u64) Insn {
        return Insn{
            .code = 0,
            .dst = 0,
            .src = 0,
            .off = 0,
            .imm = @intCast(i32, @truncate(u32, imm >> 32)),
        };
    }

    pub fn ld_dw1(dst: Reg, imm: u64) Insn {
        return ld_imm_impl1(dst, .r0, imm);
    }

    pub fn ld_dw2(imm: u64) Insn {
        return ld_imm_impl2(imm);
    }

    pub fn ld_map_fd1(dst: Reg, map_fd: fd_t) Insn {
        return ld_imm_impl1(dst, @intToEnum(Reg, PSEUDO_MAP_FD), @intCast(u64, map_fd));
    }

    pub fn ld_map_fd2(map_fd: fd_t) Insn {
        return ld_imm_impl2(@intCast(u64, map_fd));
    }

    pub fn st(comptime size: Size, dst: Reg, off: i16, imm: i32) Insn {
        if (size == .double_word) @compileError("TODO: need to determine how to correctly handle double words");
        return Insn{
            .code = MEM | @enumToInt(size) | ST,
            .dst = @enumToInt(dst),
            .src = 0,
            .off = off,
            .imm = imm,
        };
    }

    pub fn stx(size: Size, dst: Reg, off: i16, src: Reg) Insn {
        return Insn{
            .code = MEM | @enumToInt(size) | STX,
            .dst = @enumToInt(dst),
            .src = @enumToInt(src),
            .off = off,
            .imm = 0,
        };
    }

    fn endian_swap(endian: std.builtin.Endian, comptime size: Size, dst: Reg) Insn {
        return Insn{
            .code = switch (endian) {
                .Big => 0xdc,
                .Little => 0xd4,
            },
            .dst = @enumToInt(dst),
            .src = 0,
            .off = 0,
            .imm = switch (size) {
                .byte => @compileError("can't swap a single byte"),
                .half_word => 16,
                .word => 32,
                .double_word => 64,
            },
        };
    }

    pub fn le(comptime size: Size, dst: Reg) Insn {
        return endian_swap(.Little, size, dst);
    }

    pub fn be(comptime size: Size, dst: Reg) Insn {
        return endian_swap(.Big, size, dst);
    }

    pub fn call(helper: Helper) Insn {
        return Insn{
            .code = JMP | CALL,
            .dst = 0,
            .src = 0,
            .off = 0,
            .imm = @enumToInt(helper),
        };
    }

    /// exit BPF program
    pub fn exit() Insn {
        return Insn{
            .code = JMP | EXIT,
            .dst = 0,
            .src = 0,
            .off = 0,
            .imm = 0,
        };
    }
};

test "insn bitsize" {
    try expectEqual(@bitSizeOf(Insn), 64);
}

fn expect_opcode(code: u8, insn: Insn) !void {
    try expectEqual(code, insn.code);
}

// The opcodes were grabbed from https://github.com/iovisor/bpf-docs/blob/master/eBPF.md
test "opcodes" {
    // instructions that have a name that end with 1 or 2 are consecutive for
    // loading 64-bit immediates (imm is only 32 bits wide)

    // alu instructions
    try expect_opcode(0x07, Insn.add(.r1, 0));
    try expect_opcode(0x0f, Insn.add(.r1, .r2));
    try expect_opcode(0x17, Insn.sub(.r1, 0));
    try expect_opcode(0x1f, Insn.sub(.r1, .r2));
    try expect_opcode(0x27, Insn.mul(.r1, 0));
    try expect_opcode(0x2f, Insn.mul(.r1, .r2));
    try expect_opcode(0x37, Insn.div(.r1, 0));
    try expect_opcode(0x3f, Insn.div(.r1, .r2));
    try expect_opcode(0x47, Insn.alu_or(.r1, 0));
    try expect_opcode(0x4f, Insn.alu_or(.r1, .r2));
    try expect_opcode(0x57, Insn.alu_and(.r1, 0));
    try expect_opcode(0x5f, Insn.alu_and(.r1, .r2));
    try expect_opcode(0x67, Insn.lsh(.r1, 0));
    try expect_opcode(0x6f, Insn.lsh(.r1, .r2));
    try expect_opcode(0x77, Insn.rsh(.r1, 0));
    try expect_opcode(0x7f, Insn.rsh(.r1, .r2));
    try expect_opcode(0x87, Insn.neg(.r1));
    try expect_opcode(0x97, Insn.mod(.r1, 0));
    try expect_opcode(0x9f, Insn.mod(.r1, .r2));
    try expect_opcode(0xa7, Insn.xor(.r1, 0));
    try expect_opcode(0xaf, Insn.xor(.r1, .r2));
    try expect_opcode(0xb7, Insn.mov(.r1, 0));
    try expect_opcode(0xbf, Insn.mov(.r1, .r2));
    try expect_opcode(0xc7, Insn.arsh(.r1, 0));
    try expect_opcode(0xcf, Insn.arsh(.r1, .r2));

    // atomic instructions: might be more of these not documented in the wild
    try expect_opcode(0xdb, Insn.xadd(.r1, .r2));

    // TODO: byteswap instructions
    try expect_opcode(0xd4, Insn.le(.half_word, .r1));
    try expectEqual(@intCast(i32, 16), Insn.le(.half_word, .r1).imm);
    try expect_opcode(0xd4, Insn.le(.word, .r1));
    try expectEqual(@intCast(i32, 32), Insn.le(.word, .r1).imm);
    try expect_opcode(0xd4, Insn.le(.double_word, .r1));
    try expectEqual(@intCast(i32, 64), Insn.le(.double_word, .r1).imm);
    try expect_opcode(0xdc, Insn.be(.half_word, .r1));
    try expectEqual(@intCast(i32, 16), Insn.be(.half_word, .r1).imm);
    try expect_opcode(0xdc, Insn.be(.word, .r1));
    try expectEqual(@intCast(i32, 32), Insn.be(.word, .r1).imm);
    try expect_opcode(0xdc, Insn.be(.double_word, .r1));
    try expectEqual(@intCast(i32, 64), Insn.be(.double_word, .r1).imm);

    // memory instructions
    try expect_opcode(0x18, Insn.ld_dw1(.r1, 0));
    try expect_opcode(0x00, Insn.ld_dw2(0));

    //   loading a map fd
    try expect_opcode(0x18, Insn.ld_map_fd1(.r1, 0));
    try expectEqual(@intCast(u4, PSEUDO_MAP_FD), Insn.ld_map_fd1(.r1, 0).src);
    try expect_opcode(0x00, Insn.ld_map_fd2(0));

    try expect_opcode(0x38, Insn.ld_abs(.double_word, .r1, .r2, 0));
    try expect_opcode(0x20, Insn.ld_abs(.word, .r1, .r2, 0));
    try expect_opcode(0x28, Insn.ld_abs(.half_word, .r1, .r2, 0));
    try expect_opcode(0x30, Insn.ld_abs(.byte, .r1, .r2, 0));

    try expect_opcode(0x58, Insn.ld_ind(.double_word, .r1, .r2, 0));
    try expect_opcode(0x40, Insn.ld_ind(.word, .r1, .r2, 0));
    try expect_opcode(0x48, Insn.ld_ind(.half_word, .r1, .r2, 0));
    try expect_opcode(0x50, Insn.ld_ind(.byte, .r1, .r2, 0));

    try expect_opcode(0x79, Insn.ldx(.double_word, .r1, .r2, 0));
    try expect_opcode(0x61, Insn.ldx(.word, .r1, .r2, 0));
    try expect_opcode(0x69, Insn.ldx(.half_word, .r1, .r2, 0));
    try expect_opcode(0x71, Insn.ldx(.byte, .r1, .r2, 0));

    try expect_opcode(0x62, Insn.st(.word, .r1, 0, 0));
    try expect_opcode(0x6a, Insn.st(.half_word, .r1, 0, 0));
    try expect_opcode(0x72, Insn.st(.byte, .r1, 0, 0));

    try expect_opcode(0x63, Insn.stx(.word, .r1, 0, .r2));
    try expect_opcode(0x6b, Insn.stx(.half_word, .r1, 0, .r2));
    try expect_opcode(0x73, Insn.stx(.byte, .r1, 0, .r2));
    try expect_opcode(0x7b, Insn.stx(.double_word, .r1, 0, .r2));

    // branch instructions
    try expect_opcode(0x05, Insn.ja(0));
    try expect_opcode(0x15, Insn.jeq(.r1, 0, 0));
    try expect_opcode(0x1d, Insn.jeq(.r1, .r2, 0));
    try expect_opcode(0x25, Insn.jgt(.r1, 0, 0));
    try expect_opcode(0x2d, Insn.jgt(.r1, .r2, 0));
    try expect_opcode(0x35, Insn.jge(.r1, 0, 0));
    try expect_opcode(0x3d, Insn.jge(.r1, .r2, 0));
    try expect_opcode(0xa5, Insn.jlt(.r1, 0, 0));
    try expect_opcode(0xad, Insn.jlt(.r1, .r2, 0));
    try expect_opcode(0xb5, Insn.jle(.r1, 0, 0));
    try expect_opcode(0xbd, Insn.jle(.r1, .r2, 0));
    try expect_opcode(0x45, Insn.jset(.r1, 0, 0));
    try expect_opcode(0x4d, Insn.jset(.r1, .r2, 0));
    try expect_opcode(0x55, Insn.jne(.r1, 0, 0));
    try expect_opcode(0x5d, Insn.jne(.r1, .r2, 0));
    try expect_opcode(0x65, Insn.jsgt(.r1, 0, 0));
    try expect_opcode(0x6d, Insn.jsgt(.r1, .r2, 0));
    try expect_opcode(0x75, Insn.jsge(.r1, 0, 0));
    try expect_opcode(0x7d, Insn.jsge(.r1, .r2, 0));
    try expect_opcode(0xc5, Insn.jslt(.r1, 0, 0));
    try expect_opcode(0xcd, Insn.jslt(.r1, .r2, 0));
    try expect_opcode(0xd5, Insn.jsle(.r1, 0, 0));
    try expect_opcode(0xdd, Insn.jsle(.r1, .r2, 0));
    try expect_opcode(0x85, Insn.call(.unspec));
    try expect_opcode(0x95, Insn.exit());
}

pub const Cmd = extern enum(usize) {
    /// Create  a map and return a file descriptor that refers to the map.  The
    /// close-on-exec file descriptor flag is automatically enabled for the new
    /// file descriptor.
    ///
    /// uses MapCreateAttr
    map_create,

    /// Look up an element by key in a specified map and return its value.
    ///
    /// uses MapElemAttr
    map_lookup_elem,

    /// Create or update an element (key/value pair) in a specified map.
    ///
    /// uses MapElemAttr
    map_update_elem,

    /// Look up and delete an element by key in a specified map.
    ///
    /// uses MapElemAttr
    map_delete_elem,

    /// Look up an element by key in a specified map and return the key of the
    /// next element.
    map_get_next_key,

    /// Verify and load an eBPF program, returning a new file descriptor
    /// associated with  the  program.   The close-on-exec file descriptor flag
    /// is automatically enabled for the new file descriptor.
    ///
    /// uses ProgLoadAttr
    prog_load,

    /// Pin a map or eBPF program to a path within the minimal BPF filesystem
    ///
    /// uses ObjAttr
    obj_pin,

    /// Get the file descriptor of a BPF object pinned to a certain path
    ///
    /// uses ObjAttr
    obj_get,

    /// uses ProgAttachAttr
    prog_attach,

    /// uses ProgAttachAttr
    prog_detach,

    /// uses TestRunAttr
    prog_test_run,

    /// uses GetIdAttr
    prog_get_next_id,

    /// uses GetIdAttr
    map_get_next_id,

    /// uses GetIdAttr
    prog_get_fd_by_id,

    /// uses GetIdAttr
    map_get_fd_by_id,

    /// uses InfoAttr
    obj_get_info_by_fd,

    /// uses QueryAttr
    prog_query,

    /// uses RawTracepointAttr
    raw_tracepoint_open,

    /// uses BtfLoadAttr
    btf_load,

    /// uses GetIdAttr
    btf_get_fd_by_id,

    /// uses TaskFdQueryAttr
    task_fd_query,

    /// uses MapElemAttr
    map_lookup_and_delete_elem,
    map_freeze,

    /// uses GetIdAttr
    btf_get_next_id,

    /// uses MapBatchAttr
    map_lookup_batch,

    /// uses MapBatchAttr
    map_lookup_and_delete_batch,

    /// uses MapBatchAttr
    map_update_batch,

    /// uses MapBatchAttr
    map_delete_batch,

    /// uses LinkCreateAttr
    link_create,

    /// uses LinkUpdateAttr
    link_update,

    /// uses GetIdAttr
    link_get_fd_by_id,

    /// uses GetIdAttr
    link_get_next_id,

    /// uses EnableStatsAttr
    enable_stats,

    /// uses IterCreateAttr
    iter_create,
    link_detach,
    _,
};

pub const MapType = extern enum(u32) {
    unspec,
    hash,
    array,
    prog_array,
    perf_event_array,
    percpu_hash,
    percpu_array,
    stack_trace,
    cgroup_array,
    lru_hash,
    lru_percpu_hash,
    lpm_trie,
    array_of_maps,
    hash_of_maps,
    devmap,
    sockmap,
    cpumap,
    xskmap,
    sockhash,
    cgroup_storage,
    reuseport_sockarray,
    percpu_cgroup_storage,
    queue,
    stack,
    sk_storage,
    devmap_hash,
    struct_ops,

    /// An ordered and shared CPU version of perf_event_array. They have
    /// similar semantics:
    ///     - variable length records
    ///     - no blocking: when full, reservation fails
    ///     - memory mappable for ease and speed
    ///     - epoll notifications for new data, but can busy poll
    ///
    /// Ringbufs give BPF programs two sets of APIs:
    ///     - ringbuf_output() allows copy data from one place to a ring
    ///     buffer, similar to bpf_perf_event_output()
    ///     - ringbuf_reserve()/ringbuf_commit()/ringbuf_discard() split the
    ///     process into two steps. First a fixed amount of space is reserved,
    ///     if that is successful then the program gets a pointer to a chunk of
    ///     memory and can be submitted with commit() or discarded with
    ///     discard()
    ///
    /// ringbuf_output() will incurr an extra memory copy, but allows to submit
    /// records of the length that's not known beforehand, and is an easy
    /// replacement for perf_event_outptu().
    ///
    /// ringbuf_reserve() avoids the extra memory copy but requires a known size
    /// of memory beforehand.
    ///
    /// ringbuf_query() allows to query properties of the map, 4 are currently
    /// supported:
    ///     - BPF_RB_AVAIL_DATA: amount of unconsumed data in ringbuf
    ///     - BPF_RB_RING_SIZE: returns size of ringbuf
    ///     - BPF_RB_CONS_POS/BPF_RB_PROD_POS returns current logical position
    ///     of consumer and producer respectively
    ///
    /// key size: 0
    /// value size: 0
    /// max entries: size of ringbuf, must be power of 2
    ringbuf,

    _,
};

pub const ProgType = extern enum(u32) {
    unspec,

    /// context type: __sk_buff
    socket_filter,

    /// context type: bpf_user_pt_regs_t
    kprobe,

    /// context type: __sk_buff
    sched_cls,

    /// context type: __sk_buff
    sched_act,

    /// context type: u64
    tracepoint,

    /// context type: xdp_md
    xdp,

    /// context type: bpf_perf_event_data
    perf_event,

    /// context type: __sk_buff
    cgroup_skb,

    /// context type: bpf_sock
    cgroup_sock,

    /// context type: __sk_buff
    lwt_in,

    /// context type: __sk_buff
    lwt_out,

    /// context type: __sk_buff
    lwt_xmit,

    /// context type: bpf_sock_ops
    sock_ops,

    /// context type: __sk_buff
    sk_skb,

    /// context type: bpf_cgroup_dev_ctx
    cgroup_device,

    /// context type: sk_msg_md
    sk_msg,

    /// context type: bpf_raw_tracepoint_args
    raw_tracepoint,

    /// context type: bpf_sock_addr
    cgroup_sock_addr,

    /// context type: __sk_buff
    lwt_seg6local,

    /// context type: u32
    lirc_mode2,

    /// context type: sk_reuseport_md
    sk_reuseport,

    /// context type: __sk_buff
    flow_dissector,

    /// context type: bpf_sysctl
    cgroup_sysctl,

    /// context type: bpf_raw_tracepoint_args
    raw_tracepoint_writable,

    /// context type: bpf_sockopt
    cgroup_sockopt,

    /// context type: void *
    tracing,

    /// context type: void *
    struct_ops,

    /// context type: void *
    ext,

    /// context type: void *
    lsm,

    /// context type: bpf_sk_lookup
    sk_lookup,
    _,
};

pub const AttachType = extern enum(u32) {
    cgroup_inet_ingress,
    cgroup_inet_egress,
    cgroup_inet_sock_create,
    cgroup_sock_ops,
    sk_skb_stream_parser,
    sk_skb_stream_verdict,
    cgroup_device,
    sk_msg_verdict,
    cgroup_inet4_bind,
    cgroup_inet6_bind,
    cgroup_inet4_connect,
    cgroup_inet6_connect,
    cgroup_inet4_post_bind,
    cgroup_inet6_post_bind,
    cgroup_udp4_sendmsg,
    cgroup_udp6_sendmsg,
    lirc_mode2,
    flow_dissector,
    cgroup_sysctl,
    cgroup_udp4_recvmsg,
    cgroup_udp6_recvmsg,
    cgroup_getsockopt,
    cgroup_setsockopt,
    trace_raw_tp,
    trace_fentry,
    trace_fexit,
    modify_return,
    lsm_mac,
    trace_iter,
    cgroup_inet4_getpeername,
    cgroup_inet6_getpeername,
    cgroup_inet4_getsockname,
    cgroup_inet6_getsockname,
    xdp_devmap,
    cgroup_inet_sock_release,
    xdp_cpumap,
    sk_lookup,
    xdp,
    _,
};

const obj_name_len = 16;
/// struct used by Cmd.map_create command
pub const MapCreateAttr = extern struct {
    /// one of MapType
    map_type: u32,

    /// size of key in bytes
    key_size: u32,

    /// size of value in bytes
    value_size: u32,

    /// max number of entries in a map
    max_entries: u32,

    /// .map_create related flags
    map_flags: u32,

    /// fd pointing to the inner map
    inner_map_fd: fd_t,

    /// numa node (effective only if MapCreateFlags.numa_node is set)
    numa_node: u32,
    map_name: [obj_name_len]u8,

    /// ifindex of netdev to create on
    map_ifindex: u32,

    /// fd pointing to a BTF type data
    btf_fd: fd_t,

    /// BTF type_id of the key
    btf_key_type_id: u32,

    /// BTF type_id of the value
    bpf_value_type_id: u32,

    /// BTF type_id of a kernel struct stored as the map value
    btf_vmlinux_value_type_id: u32,
};

/// struct used by Cmd.map_*_elem commands
pub const MapElemAttr = extern struct {
    map_fd: fd_t,
    key: u64,
    result: extern union {
        value: u64,
        next_key: u64,
    },
    flags: u64,
};

/// struct used by Cmd.map_*_batch commands
pub const MapBatchAttr = extern struct {
    /// start batch, NULL to start from beginning
    in_batch: u64,

    /// output: next start batch
    out_batch: u64,
    keys: u64,
    values: u64,

    /// input/output:
    /// input: # of key/value elements
    /// output: # of filled elements
    count: u32,
    map_fd: fd_t,
    elem_flags: u64,
    flags: u64,
};

/// struct used by Cmd.prog_load command
pub const ProgLoadAttr = extern struct {
    /// one of ProgType
    prog_type: u32,
    insn_cnt: u32,
    insns: u64,
    license: u64,

    /// verbosity level of verifier
    log_level: u32,

    /// size of user buffer
    log_size: u32,

    /// user supplied buffer
    log_buf: u64,

    /// not used
    kern_version: u32,
    prog_flags: u32,
    prog_name: [obj_name_len]u8,

    /// ifindex of netdev to prep for.
    prog_ifindex: u32,

    /// For some prog types expected attach type must be known at load time to
    /// verify attach type specific parts of prog (context accesses, allowed
    /// helpers, etc).
    expected_attach_type: u32,

    /// fd pointing to BTF type data
    prog_btf_fd: fd_t,

    /// userspace bpf_func_info size
    func_info_rec_size: u32,
    func_info: u64,

    /// number of bpf_func_info records
    func_info_cnt: u32,

    /// userspace bpf_line_info size
    line_info_rec_size: u32,
    line_info: u64,

    /// number of bpf_line_info records
    line_info_cnt: u32,

    /// in-kernel BTF type id to attach to
    attact_btf_id: u32,

    /// 0 to attach to vmlinux
    attach_prog_id: u32,
};

/// struct used by Cmd.obj_* commands
pub const ObjAttr = extern struct {
    pathname: u64,
    bpf_fd: fd_t,
    file_flags: u32,
};

/// struct used by Cmd.prog_attach/detach commands
pub const ProgAttachAttr = extern struct {
    /// container object to attach to
    target_fd: fd_t,

    /// eBPF program to attach
    attach_bpf_fd: fd_t,

    attach_type: u32,
    attach_flags: u32,

    // TODO: BPF_F_REPLACE flags
    /// previously attached eBPF program to replace if .replace is used
    replace_bpf_fd: fd_t,
};

/// struct used by Cmd.prog_test_run command
pub const TestRunAttr = extern struct {
    prog_fd: fd_t,
    retval: u32,

    /// input: len of data_in
    data_size_in: u32,

    /// input/output: len of data_out. returns ENOSPC if data_out is too small.
    data_size_out: u32,
    data_in: u64,
    data_out: u64,
    repeat: u32,
    duration: u32,

    /// input: len of ctx_in
    ctx_size_in: u32,

    /// input/output: len of ctx_out. returns ENOSPC if ctx_out is too small.
    ctx_size_out: u32,
    ctx_in: u64,
    ctx_out: u64,
};

/// struct used by Cmd.*_get_*_id commands
pub const GetIdAttr = extern struct {
    id: extern union {
        start_id: u32,
        prog_id: u32,
        map_id: u32,
        btf_id: u32,
        link_id: u32,
    },
    next_id: u32,
    open_flags: u32,
};

/// struct used by Cmd.obj_get_info_by_fd command
pub const InfoAttr = extern struct {
    bpf_fd: fd_t,
    info_len: u32,
    info: u64,
};

/// struct used by Cmd.prog_query command
pub const QueryAttr = extern struct {
    /// container object to query
    target_fd: fd_t,
    attach_type: u32,
    query_flags: u32,
    attach_flags: u32,
    prog_ids: u64,
    prog_cnt: u32,
};

/// struct used by Cmd.raw_tracepoint_open command
pub const RawTracepointAttr = extern struct {
    name: u64,
    prog_fd: fd_t,
};

/// struct used by Cmd.btf_load command
pub const BtfLoadAttr = extern struct {
    btf: u64,
    btf_log_buf: u64,
    btf_size: u32,
    btf_log_size: u32,
    btf_log_level: u32,
};

/// struct used by Cmd.task_fd_query
pub const TaskFdQueryAttr = extern struct {
    /// input: pid
    pid: pid_t,

    /// input: fd
    fd: fd_t,

    /// input: flags
    flags: u32,

    /// input/output: buf len
    buf_len: u32,

    /// input/output:
    ///     tp_name for tracepoint
    ///     symbol for kprobe
    ///     filename for uprobe
    buf: u64,

    /// output: prod_id
    prog_id: u32,

    /// output: BPF_FD_TYPE
    fd_type: u32,

    /// output: probe_offset
    probe_offset: u64,

    /// output: probe_addr
    probe_addr: u64,
};

/// struct used by Cmd.link_create command
pub const LinkCreateAttr = extern struct {
    /// eBPF program to attach
    prog_fd: fd_t,

    /// object to attach to
    target_fd: fd_t,
    attach_type: u32,

    /// extra flags
    flags: u32,
};

/// struct used by Cmd.link_update command
pub const LinkUpdateAttr = extern struct {
    link_fd: fd_t,

    /// new program to update link with
    new_prog_fd: fd_t,

    /// extra flags
    flags: u32,

    /// expected link's program fd, it is specified only if BPF_F_REPLACE is
    /// set in flags
    old_prog_fd: fd_t,
};

/// struct used by Cmd.enable_stats command
pub const EnableStatsAttr = extern struct {
    type: u32,
};

/// struct used by Cmd.iter_create command
pub const IterCreateAttr = extern struct {
    link_fd: fd_t,
    flags: u32,
};

/// Mega struct that is passed to the bpf() syscall
pub const Attr = extern union {
    map_create: MapCreateAttr,
    map_elem: MapElemAttr,
    map_batch: MapBatchAttr,
    prog_load: ProgLoadAttr,
    obj: ObjAttr,
    prog_attach: ProgAttachAttr,
    test_run: TestRunAttr,
    get_id: GetIdAttr,
    info: InfoAttr,
    query: QueryAttr,
    raw_tracepoint: RawTracepointAttr,
    btf_load: BtfLoadAttr,
    task_fd_query: TaskFdQueryAttr,
    link_create: LinkCreateAttr,
    link_update: LinkUpdateAttr,
    enable_stats: EnableStatsAttr,
    iter_create: IterCreateAttr,
};

pub const Log = struct {
    level: u32,
    buf: []u8,
};

pub fn map_create(map_type: MapType, key_size: u32, value_size: u32, max_entries: u32) !fd_t {
    var attr = Attr{
        .map_create = std.mem.zeroes(MapCreateAttr),
    };

    attr.map_create.map_type = @enumToInt(map_type);
    attr.map_create.key_size = key_size;
    attr.map_create.value_size = value_size;
    attr.map_create.max_entries = max_entries;

    const rc = bpf(.map_create, &attr, @sizeOf(MapCreateAttr));
    return switch (errno(rc)) {
        0 => @intCast(fd_t, rc),
        EINVAL => error.MapTypeOrAttrInvalid,
        ENOMEM => error.SystemResources,
        EPERM => error.AccessDenied,
        else => |err| unexpectedErrno(rc),
    };
}

test "map_create" {
    const map = try map_create(.hash, 4, 4, 32);
    defer std.os.close(map);
}

pub fn map_lookup_elem(fd: fd_t, key: []const u8, value: []u8) !void {
    var attr = Attr{
        .map_elem = std.mem.zeroes(MapElemAttr),
    };

    attr.map_elem.map_fd = fd;
    attr.map_elem.key = @ptrToInt(key.ptr);
    attr.map_elem.result.value = @ptrToInt(value.ptr);

    const rc = bpf(.map_lookup_elem, &attr, @sizeOf(MapElemAttr));
    switch (errno(rc)) {
        0 => return,
        EBADF => return error.BadFd,
        EFAULT => unreachable,
        EINVAL => return error.FieldInAttrNeedsZeroing,
        ENOENT => return error.NotFound,
        EPERM => return error.AccessDenied,
        else => |err| return unexpectedErrno(rc),
    }
}

pub fn map_update_elem(fd: fd_t, key: []const u8, value: []const u8, flags: u64) !void {
    var attr = Attr{
        .map_elem = std.mem.zeroes(MapElemAttr),
    };

    attr.map_elem.map_fd = fd;
    attr.map_elem.key = @ptrToInt(key.ptr);
    attr.map_elem.result = .{ .value = @ptrToInt(value.ptr) };
    attr.map_elem.flags = flags;

    const rc = bpf(.map_update_elem, &attr, @sizeOf(MapElemAttr));
    switch (errno(rc)) {
        0 => return,
        E2BIG => return error.ReachedMaxEntries,
        EBADF => return error.BadFd,
        EFAULT => unreachable,
        EINVAL => return error.FieldInAttrNeedsZeroing,
        ENOMEM => return error.SystemResources,
        EPERM => return error.AccessDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn map_delete_elem(fd: fd_t, key: []const u8) !void {
    var attr = Attr{
        .map_elem = std.mem.zeroes(MapElemAttr),
    };

    attr.map_elem.map_fd = fd;
    attr.map_elem.key = @ptrToInt(key.ptr);

    const rc = bpf(.map_delete_elem, &attr, @sizeOf(MapElemAttr));
    switch (errno(rc)) {
        0 => return,
        EBADF => return error.BadFd,
        EFAULT => unreachable,
        EINVAL => return error.FieldInAttrNeedsZeroing,
        ENOENT => return error.NotFound,
        EPERM => return error.AccessDenied,
        else => |err| return unexpectedErrno(err),
    }
}

test "map lookup, update, and delete" {
    const key_size = 4;
    const value_size = 4;
    const map = try map_create(.hash, key_size, value_size, 1);
    defer std.os.close(map);

    const key = std.mem.zeroes([key_size]u8);
    var value = std.mem.zeroes([value_size]u8);

    // fails looking up value that doesn't exist
    try expectError(error.NotFound, map_lookup_elem(map, &key, &value));

    // succeed at updating and looking up element
    try map_update_elem(map, &key, &value, 0);
    try map_lookup_elem(map, &key, &value);

    // fails inserting more than max entries
    const second_key = [key_size]u8{ 0, 0, 0, 1 };
    try expectError(error.ReachedMaxEntries, map_update_elem(map, &second_key, &value, 0));

    // succeed at deleting an existing elem
    try map_delete_elem(map, &key);
    try expectError(error.NotFound, map_lookup_elem(map, &key, &value));

    // fail at deleting a non-existing elem
    try expectError(error.NotFound, map_delete_elem(map, &key));
}

pub fn prog_load(
    prog_type: ProgType,
    insns: []const Insn,
    log: ?*Log,
    license: []const u8,
    kern_version: u32,
) !fd_t {
    var attr = Attr{
        .prog_load = std.mem.zeroes(ProgLoadAttr),
    };

    attr.prog_load.prog_type = @enumToInt(prog_type);
    attr.prog_load.insns = @ptrToInt(insns.ptr);
    attr.prog_load.insn_cnt = @intCast(u32, insns.len);
    attr.prog_load.license = @ptrToInt(license.ptr);
    attr.prog_load.kern_version = kern_version;

    if (log) |l| {
        attr.prog_load.log_buf = @ptrToInt(l.buf.ptr);
        attr.prog_load.log_size = @intCast(u32, l.buf.len);
        attr.prog_load.log_level = l.level;
    }

    const rc = bpf(.prog_load, &attr, @sizeOf(ProgLoadAttr));
    return switch (errno(rc)) {
        0 => @intCast(fd_t, rc),
        EACCES => error.UnsafeProgram,
        EFAULT => unreachable,
        EINVAL => error.InvalidProgram,
        EPERM => error.AccessDenied,
        else => |err| unexpectedErrno(err),
    };
}

test "prog_load" {
    // this should fail because it does not set r0 before exiting
    const bad_prog = [_]Insn{
        Insn.exit(),
    };

    const good_prog = [_]Insn{
        Insn.mov(.r0, 0),
        Insn.exit(),
    };

    const prog = try prog_load(.socket_filter, &good_prog, null, "MIT", 0);
    defer std.os.close(prog);

    try expectError(error.UnsafeProgram, prog_load(.socket_filter, &bad_prog, null, "MIT", 0));
}
