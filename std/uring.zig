const builtin = @import("builtin");
const std = @import("std.zig");
const os = std.os;
const linux = os.linux;
const assert = std.debug.assert;
const testing = std.testing;

/// The Linux kernel submission queue abstraction
///
/// The submission queue is conceptually a circular queue of submission queue
/// entries ("SQE"s). A userland process appends to the tail, while the kernel
/// reads from the head.
/// The kernel has a layer of indirection from `.array` to `.sqes` to enable
/// userland schemes where userland objects may choose to 'own' an sqe slot.
const LinuxSQ = struct {
    khead: *align(4096) u32, // kernel modifies
    fn getHead(sq: LinuxSQ) u32 {
        return @atomicLoad(u32, sq.khead, .Acquire);
    }

    ktail: *u32, // kernel reads
    fn getTail(sq: LinuxSQ) u32 {
        return sq.ktail.*;
    }
    fn setTail(sq: LinuxSQ, val: u32) void {
        // TODO @atomicStore https://github.com/ziglang/zig/issues/2995
        _ = @atomicRmw(u32, sq.ktail, .Xchg, val, .Release);
    }

    ring_mask: u32, // never modified by kernel after creation

    kflags: *u32, // kernel modifies while entered
    fn getFlags(sq: LinuxSQ) u32 {
        return @atomicLoad(u32, sq.kflags, .Monotonic);
    }

    kdropped: *u32,
    /// counter of invalid submissions
    fn getDropped(sq: LinuxSQ) u32 {
        return @atomicLoad(u32, sq.kdropped, .Monotonic);
    }

    /// contains indexes into `.sqes`
    array: []u32, // kernel reads from array

    /// submission queue entries
    sqes: [] align(4096) linux.io_uring_sqe, // kernel reads from array

    // pub fn queueSQEs(sq: LinuxSQ, sqe_indices: []const u32) u32 {
    //     const head = sq.getHead();
    //     const tail = sq.getTail();
    //     const n_can_fit = std.math.min(tail -% head, @intCast(u32, sqe_indices.len));
    //     for (sqe_indices[0..n_can_fit]) |sqe_index| {
    //         assert(sqe_index < sq.sqes.len);
    //     }
    //     std.mem.copy(u32, sq.array[tail & sq.ring_mask..], sqe_indices[0..n_can_fit]);
    //     sq.setTail(tail +% n_can_fit);
    //     return n_can_fit;
    // }

    pub fn map(fd: i32, p: linux.io_uring_params) !LinuxSQ {
        assert(p.sq_off.head == 0); // assumed by unmap below

        const ring_sz = p.sq_off.array + p.sq_entries * @sizeOf(u32);
        const sq_ring = try os.mmap(null, ring_sz, os.PROT_READ | os.PROT_WRITE, os.MAP_SHARED | linux.MAP_POPULATE, fd, linux.IORING_OFF_SQ_RING);
        errdefer os.munmap(sq_ring);

        const ring_entries = @ptrCast(*u32, @alignCast(@alignOf(u32), &sq_ring[p.sq_off.ring_entries])).*;
        const array = @ptrCast([*]u32, @alignCast(@alignOf(u32), &sq_ring[p.sq_off.array]));
        @memset(@ptrCast([*]u8, array), undefined, ring_entries * @sizeOf(u32));

        const sqes_size = p.sq_entries * @sizeOf(linux.io_uring_sqe);
        const sqes_raw = try os.mmap(null, sqes_size, os.PROT_READ | os.PROT_WRITE, os.MAP_SHARED | linux.MAP_POPULATE, fd, linux.IORING_OFF_SQES);
        errdefer os.munmap(sqes_raw);
        @memset(sqes_raw.ptr, undefined, sqes_size);

        return LinuxSQ{
            // .khead = @ptrCast(*u32, @alignCast(@alignOf(u32), &sq_ring[p.sq_off.head])),
            .khead = @ptrCast(*u32, sq_ring.ptr),
            .ktail = @ptrCast(*u32, @alignCast(@alignOf(u32), &sq_ring[p.sq_off.tail])),
            .ring_mask = @ptrCast(*u32, @alignCast(@alignOf(u32), &sq_ring[p.sq_off.ring_mask])).*,
            .kflags = @ptrCast(*u32, @alignCast(@alignOf(u32), &sq_ring[p.sq_off.flags])),
            .kdropped = @ptrCast(*u32, @alignCast(@alignOf(u32), &sq_ring[p.sq_off.dropped])),
            .array = array[0..ring_entries],
            .sqes = @ptrCast([*]linux.io_uring_sqe, sqes_raw.ptr)[0..p.sq_entries],
        };
    }

    pub fn unmap(sq: LinuxSQ) void {
        os.munmap(@ptrCast([*]u8, sq.sqes.ptr)[0..sq.sqes.len * @sizeOf(linux.io_uring_sqe)]);
        const sq_len = @ptrToInt(sq.array.ptr) - @ptrToInt(sq.khead) + (sq.array.len * @sizeOf(u32));
        os.munmap(@ptrCast([*]u8, sq.khead)[0..sq_len]);
    }
};


const LinuxCQ = struct {
    khead: *align(4096) u32, // kernel reads
    fn getHead(cq: LinuxCQ) u32 {
        return cq.khead.*;
    }
    fn setHead(cq: LinuxCQ, val: u32) void {
        // TODO @atomicStore https://github.com/ziglang/zig/issues/2995
        _ = @atomicRmw(u32, cq.khead, .Xchg, val, .Release);
    }

    ktail: *u32, // kernel modifies
    fn getTail(cq: LinuxCQ) u32 {
        return @atomicLoad(u32, cq.ktail, .Acquire);
    }

    ring_mask: u32,

    koverflow: *u32,
    fn getOverflow(cq: LinuxCQ) u32 {
        return @atomicLoad(u32, cq.koverflow, .Monotonic);
    }

    cqes: []linux.io_uring_cqe,

    pub fn map(fd: i32, p: linux.io_uring_params) !LinuxCQ {
        assert(p.cq_off.head == 0); // assumed by unmap below
        const ring_sz = p.cq_off.cqes + p.cq_entries * @sizeOf(linux.io_uring_cqe);
        const cq_ring = try os.mmap(null, ring_sz, os.PROT_READ | os.PROT_WRITE, os.MAP_SHARED | linux.MAP_POPULATE, fd, linux.IORING_OFF_CQ_RING);
        errdefer os.munmap(cq_ring);

        const ring_entries = @ptrCast(*u32, @alignCast(@alignOf(u32), &cq_ring[p.cq_off.ring_entries])).*;

        return LinuxCQ{
            // .khead = @ptrCast(*u32, @alignCast(@alignOf(u32), &cq_ring[p.cq_off.head])),
            .khead = @ptrCast(*u32, cq_ring.ptr),
            .ktail = @ptrCast(*u32, @alignCast(@alignOf(u32), &cq_ring[p.cq_off.tail])),
            .ring_mask = @ptrCast(*u32, @alignCast(@alignOf(u32), &cq_ring[p.cq_off.ring_mask])).*,
            .koverflow = @ptrCast(*u32, @alignCast(@alignOf(u32), &cq_ring[p.cq_off.overflow])),
            .cqes = @ptrCast([*]linux.io_uring_cqe, @alignCast(@alignOf(linux.io_uring_cqe), &cq_ring[p.cq_off.cqes]))[0..ring_entries],
        };
    }

    pub fn unmap(cq: LinuxCQ) void {
        const cq_len = @ptrToInt(cq.cqes.ptr) - @ptrToInt(cq.khead) + (cq.cqes.len * @sizeOf(linux.io_uring_cqe));
        os.munmap(@ptrCast([*]u8, cq.khead)[0..cq_len]);
    }

    fn peek(cq: LinuxCQ, n: u32) ?*linux.io_uring_cqe {
        const head = cq.getHead();
        const n_available = cq.getTail() -% head;
        if (n > n_available) {
            return null;
        }
        return &cq.cqes[(head +% n) & cq.ring_mask];
    }

    fn seen(cq: LinuxCQ, n: u32) void {
        cq.setHead(cq.getHead() +% n);
    }
};

pub const IoURing = struct {
    fd: i32,

    /// Submission queue
    const SQ = struct {
        linuxSQ: LinuxSQ,

        sqe_head: u32,
        sqe_tail: u32,

        // pub fn init(allocator: *std.mem.Allocator, fd: i32, p: linux.io_uring_params) SQ {
        pub fn init(fd: i32, p: linux.io_uring_params) !SQ {
            return SQ{
                .linuxSQ = try LinuxSQ.map(fd, p),
                .sqe_head = 0,
                .sqe_tail = 0,
            };
        }

        pub fn deinit(self: *const SQ) void {
            self.linuxSQ.unmap();
        }

        /// Return an sqe to fill. Application must later call IoURing.submit()
        /// when it's ready to tell the kernel about it. The caller may call this
        /// function multiple times before calling IoURing.submit().
        ///
        /// Returns a vacant sqe, or `null` if we're full.
        fn getSQE(sq: *SQ) ?*linux.io_uring_sqe {
            const next = sq.sqe_tail +% 1;

            if (next -% sq.sqe_head > sq.linuxSQ.sqes.len) {
                // All sqes are used
                return null;
            }

            var sqe = &sq.linuxSQ.sqes[sq.sqe_tail & sq.linuxSQ.ring_mask];
            sq.sqe_tail = next;
            return sqe;
        }

        // fn pushSQE(sq: *SQ) void {
        //     while (sq.sqe_head != sq.sqe_tail) {
        //         const indices = []u32{sq.sqe_head};
        //         sq.linuxSQ.queueSQEs(indices[0..1]);
        //         sq.sqe_head +%= 1;
        //     }
        // }
    };
    sq: SQ,

    /// Completion queue
    const CQ = struct {
        linuxCQ: LinuxCQ,

        // pub fn init(allocator: *std.mem.Allocator, fd: i32, p: linux.io_uring_params) SQ {
        pub fn init(fd: i32, p: linux.io_uring_params) !CQ {
            return CQ{
                .linuxCQ = try LinuxCQ.map(fd, p),
            };
        }

        pub fn deinit(self: *const CQ) void {
            self.linuxCQ.unmap();
        }
    };
    cq: CQ,

    const Self = @This();

    fn mmapQueues(fd: i32, p: linux.io_uring_params) !Self {
        const sq = try SQ.init(fd, p);
        errdefer sq.deinit();

        const cq = try CQ.init(fd, p);
        errdefer cq.deinit();

        return Self{
            .fd = fd,
            .sq = sq,
            .cq = cq,
        };
    }

    pub fn init(entries: u13, flags: u32) !Self {
        assert(entries >= 1 and entries <= 4096 and std.math.isPowerOfTwo(entries));
        var p = linux.io_uring_params{
            .sq_entries = undefined,
            .cq_entries = undefined,
            .flags = flags,
            .sq_thread_cpu = 0,
            .sq_thread_idle = 1000,
            .resv = [_]u32{0} ** 5,
            .sq_off = undefined,
            .cq_off = undefined,
        };
        const fd = blk: {
            const res = linux.io_uring_setup(entries, &p);
            const errno = linux.getErrno(res);
            if (errno != 0) return os.unexpectedErrno(errno);
            break :blk @truncate(u31, res);
        };
        errdefer os.close(fd);

        return IoURing.mmapQueues(fd, p);
    }

    pub fn deinit(self: *Self) void {
        self.sq.deinit();
        self.cq.deinit();
        os.close(self.fd);
    }

    pub fn registerFiles(self: *Self, fds: []const i32) !void {
        const res = linux.io_uring_register(self.fd, linux.IORING_REGISTER_FILES, fds.ptr, @truncate(u32, fds.len));
        const errno = linux.getErrno(res);
        if (errno != 0) return os.unexpectedErrno(errno);
    }

    pub fn unregisterFiles(self: *Self) !void {
        const res = linux.io_uring_register(self.fd, linux.IORING_UNREGISTER_FILES, null, 0);
        const errno = linux.getErrno(res);
        if (errno != 0) return os.unexpectedErrno(errno);
    }

    pub fn registerBuffer(self: *Self, iovecs: []const linux.iovec) !void {
        const res = linux.io_uring_register(self.fd, linux.IORING_REGISTER_BUFFERS, iovecs.ptr, iovecs.len);
        const errno = linux.getErrno(res);
        if (errno != 0) return os.unexpectedErrno(errno);
    }

    pub fn unregisterBuffer(self: *Self) !void {
        const res = linux.io_uring_register(self.fd, linux.IORING_UNREGISTER_BUFFERS, null, 0);
        const errno = linux.getErrno(res);
        if (errno != 0) return os.unexpectedErrno(errno);
    }

    pub const FileReference = union(enum) {
        fd: i32,
        fixed: i32,
    };

    pub fn queueRead(self: *Self, user_data: u64, fd: FileReference, iovecs: []const os.iovec, offset: u64) !void {
        const sqe = self.sq.getSQE() orelse return error.NoSpaceLeft;
        sqe.* = linux.io_uring_sqe{
            .opcode = linux.IORING_OP_READV,
            .flags = switch (fd) {
                .fixed => u8(linux.IOSQE_FIXED_FILE),
                else => 0,
            },
            .ioprio = 0,
            .fd = switch (fd) {
                .fd => |f| f,
                .fixed => |f| f,
            },
            .off = offset,
            .addr = @ptrToInt(iovecs.ptr),
            .len = @truncate(u32, iovecs.len),
            .union1 = linux.io_uring_sqe.union1{ .rw_flags = 0 },
            .user_data = user_data,
            .union2 = linux.io_uring_sqe.union2{ .__pad2 = [3]u64{0,0,0} },
        };
    }

    pub fn queueReadFixed(self: *Self, user_data: u64, fd: FileReference, buf: []u8, offset: u64) !void {
        const sqe = self.sq.getSQE() orelse return error.NoSpaceLeft;
        sqe.* = linux.io_uring_sqe{
            .opcode = linux.IORING_OP_READ_FIXED,
            .flags = switch (fd) {
                .fixed => u8(linux.IOSQE_FIXED_FILE),
                else => 0,
            },
            .ioprio = 0,
            .fd = switch (fd) {
                .fd => |f| f,
                .fixed => |f| f,
            },
            .off = offset,
            .addr = @ptrToInt(buf.ptr),
            .len = buf.len,
            .union1 = linux.io_uring_sqe.union1{ .rw_flags = 0 },
            .user_data = user_data,
            .union2 = undefined,
        };
    }

    pub fn queueWrite(self: *Self, user_data: u64, fd: FileReference, iovecs: []const os.iovec_const, offset: u64, rw_flags: os.kernel_rwf) !void {
        const sqe = self.sq.getSQE() orelse return error.NoSpaceLeft;
        sqe.* = linux.io_uring_sqe{
            .opcode = linux.IORING_OP_WRITEV,
            .flags = switch (fd) {
                .fixed => u8(linux.IOSQE_FIXED_FILE),
                else => 0,
            },
            .ioprio = 0,
            .fd = switch (fd) {
                .fd => |f| f,
                .fixed => |f| f,
            },
            .off = offset,
            .addr = @ptrToInt(iovecs.ptr),
            .len = @truncate(u32, iovecs.len),
            .union1 = linux.io_uring_sqe.union1{ .rw_flags = rw_flags },
            .user_data = user_data,
            .union2 = linux.io_uring_sqe.union2{ .__pad2 = [3]u64{0,0,0} },
        };
    }

    pub fn queueWriteFixed(self: *Self, user_data: u64, fd: FileReference, buf: []u8, offset: u64) !void {
        const sqe = self.sq.getSQE() orelse return error.NoSpaceLeft;
        sqe.* = linux.io_uring_sqe{
            .opcode = linux.IORING_OP_WRITE_FIXED,
            .flags = switch (fd) {
                .fixed => u8(linux.IOSQE_FIXED_FILE),
                else => 0,
            },
            .ioprio = 0,
            .fd = switch (fd) {
                .fd => |f| f,
                .fixed => |f| f,
            },
            .off = offset,
            .addr = @ptrToInt(buf.ptr),
            .len = buf.len,
            .union1 = linux.io_uring_sqe.union1{ .rw_flags = 0 },
            .user_data = user_data,
            .union2 = undefined,
        };
    }

    pub fn queuePollAdd(self: *Self, user_data: u64, fd: FileReference, poll_mask: u16) !void {
        const sqe = self.sq.getSQE() orelse return error.NoSpaceLeft;
        sqe.* = linux.io_uring_sqe{
            .opcode = linux.IORING_OP_POLL_ADD,
            .flags = switch (fd) {
                .fixed => u8(linux.IOSQE_FIXED_FILE),
                else => 0,
            },
            .ioprio = 0,
            .fd = switch (fd) {
                .fd => |f| f,
                .fixed => |f| f,
            },
            .off = 0,
            .addr = 0,
            .len = 0,
            .union1 = linux.io_uring_sqe.union1{ .poll_event = poll_mask },
            .user_data = user_data,
            .union2 = undefined,
        };
    }

    pub fn queuePollRemove(self: *Self, user_data: u64, remove_user_data: u64) !void {
        const sqe = self.sq.getSQE() orelse return error.NoSpaceLeft;
        sqe.* = linux.io_uring_sqe{
            .opcode = linux.IORING_OP_POLL_REMOVE,
            .flags = 0,
            .ioprio = 0,
            .fd = 0,
            .off = 0,
            .addr = remove_user_data,
            .len = 0,
            .union1 = undefined,
            .user_data = user_data,
            .union2 = undefined,
        };
    }

    pub fn queueFsync(self: *Self, user_data: u64, fd: FileReference, fsync_flags: u16) !void {
        const sqe = self.sq.getSQE() orelse return error.NoSpaceLeft;
        sqe.* = linux.io_uring_sqe{
            .opcode = linux.IORING_OP_FSYNC,
            .flags = switch (fd) {
                .fixed => u8(linux.IOSQE_FIXED_FILE),
                else => 0,
            },
            .ioprio = 0,
            .fd = switch (fd) {
                .fd => |f| f,
                .fixed => |f| f,
            },
            .off = 0,
            .addr = 0,
            .len = 0,
            .union1 = linux.io_uring_sqe.union1{ .fsync_flags = fsync_flags },
            .user_data = user_data,
            .union2 = undefined,
        };
    }

    pub fn queueNop(self: *Self, user_data: u64) !void {
        const sqe = self.sq.getSQE() orelse return error.NoSpaceLeft;
        sqe.* = linux.io_uring_sqe{
            .opcode = linux.IORING_OP_NOP,
            .flags = 0,
            .ioprio = undefined,
            .fd = undefined,
            .off = undefined,
            .addr = undefined,
            .len = undefined,
            .union1 = undefined,
            .user_data = user_data,
            .union2 = undefined,
        };
    }

    /// Submit sqes to the kernel.
    ///
    /// Returns number of sqes submitted
    pub fn submit(self: *Self) !u32 {
        var submitted: u32 = undefined;

        var ktail_next = self.sq.linuxSQ.getTail();
        if (self.sq.linuxSQ.getHead() != ktail_next) {
            submitted = @intCast(u32, self.sq.linuxSQ.array.len);
        } else if (self.sq.sqe_head == self.sq.sqe_tail) {
            // nothing to submit
            return 0;
        } else {
            // Fill in sqes that we have queued up, adding them to the kernel ring
            submitted = 0;
            while (self.sq.sqe_head + submitted < self.sq.sqe_tail) : (submitted += 1) {
                const sqe_index = self.sq.sqe_head & self.sq.linuxSQ.ring_mask;
                self.sq.linuxSQ.array[(ktail_next +% submitted) & self.sq.linuxSQ.ring_mask] = sqe_index;
            }

            if (submitted > 0) {
                // Write barrier ensures that the SQE stores are updated
                // with the tail update. This is needed so that the kernel
                // will never see a tail update without the preceeding sQE
                // stores being done.
                @fence(.SeqCst);

                self.sq.sqe_head += submitted;
                self.sq.linuxSQ.setTail(ktail_next +% submitted);

                // The kernel has the matching read barrrier for reading the
                // SQ tail.
                @fence(.SeqCst);
            }
        }

        const res = linux.io_uring_enter(self.fd, submitted, 0, 0, null);
        const errno = linux.getErrno(res);
        if (errno != 0) return os.unexpectedErrno(errno);

        return @truncate(u32, res);
    }

    pub fn getCompletion(self: Self) !?linux.io_uring_cqe {
        // TODO: return null if no operations are pending
        while (true) {
            if (self.cq.linuxCQ.peek(0)) |pcqe| {
                // FIXME: Issue is here: it seems the read/dereference of pcqe happens before the kernel has written to it.
                //os.nanosleep(0,0);
                @fence(.SeqCst);
                const result = pcqe.*;
                std.debug.warn("{}\n", &result);
                self.cq.linuxCQ.seen(1);
                return result;
            }

            const res = linux.io_uring_enter(self.fd, 0, 1, linux.IORING_ENTER_GETEVENTS, null);
            const errno = linux.getErrno(res);
            if (errno != 0) return os.unexpectedErrno(errno);
        }
    }
};

test "uring" {
    if (builtin.os != builtin.Os.linux) return error.SkipZigTest;

    var uring = try IoURing.init(128, 0);
    defer uring.deinit();

    testing.expectEqual(u32(0), try uring.submit());

    { // try nop operation
        try uring.queueNop(0xdeadbeef);
        testing.expectEqual(u32(1), try uring.submit());
        testing.expectEqual(linux.io_uring_cqe{
            .user_data = 0xdeadbeef,
            .res = 0,
            .flags = 0,
        }, (try uring.getCompletion()).?);
    }

    const zero = try os.openC(c"/dev/zero", os.O_RDONLY | os.O_CLOEXEC, 0);
    defer os.close(zero);

    { // read some 0 bytes from /dev/zero
        var buf: [100]u8 = undefined;
        try uring.queueRead(
            0xcafebabe,
            IoURing.FileReference{ .fd = zero },
            [_]os.iovec{os.iovec{ .iov_base = buf[0..].ptr, .iov_len = buf.len }},
            0,
        );
        testing.expectEqual(u32(1), try uring.submit());
        testing.expectEqual(linux.io_uring_cqe{
            .user_data = 0xcafebabe,
            .res = 100,
            .flags = 0,
        }, (try uring.getCompletion()).?);
        testing.expectEqualSlices(u8, [_]u8{0} ** 100, buf[0..]);
    }

    { // read some 0 bytes from /dev/zero using a fixed file reference
        try uring.registerFiles(([_]i32{zero})[0..]);
        var buf: [100]u8 = undefined;
        try uring.queueRead(
            0xcafed00d,
            IoURing.FileReference{ .fixed = 0 },
            [_]os.iovec{os.iovec{ .iov_base = buf[0..].ptr, .iov_len = buf.len }},
            0,
        );
        testing.expectEqual(u32(1), try uring.submit());
        testing.expectEqual(linux.io_uring_cqe{
            .user_data = 0xcafed00d,
            .res = 100,
            .flags = 0,
        }, (try uring.getCompletion()).?);
        testing.expectEqualSlices(u8, [_]u8{0} ** 100, buf[0..]);
        // TODO: .unregisterFiles makes the following operation hang.
        // try uring.unregisterFiles();
    }

    const d_null = try os.openC(c"/dev/null", os.O_WRONLY | os.O_CLOEXEC, 0);
    defer os.close(d_null);
    { // write some bytes to /dev/null
        const data = "hello world";
        try uring.queueWrite(
            0xbaddcafe,
            IoURing.FileReference{ .fd = d_null },
            [_]os.iovec_const{os.iovec_const{ .iov_base = &data, .iov_len = data.len }},
            0,
            0,
        );
        testing.expectEqual(u32(1), try uring.submit());
        testing.expectEqual(linux.io_uring_cqe{
            .user_data = 0xbaddcafe,
            .res = data.len,
            .flags = 0,
        }, (try uring.getCompletion()).?);
    }

    testing.expectEqual(u32(0), uring.sq.linuxSQ.getDropped());
}
