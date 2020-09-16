const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const os = std.os;
const linux = os.linux;
const mem = std.mem;
const net = std.net;
const testing = std.testing;

pub const io_uring_params = linux.io_uring_params;
pub const io_uring_cqe = linux.io_uring_cqe;

// TODO Update linux.zig's definition of linux.io_uring_sqe:
// linux.io_uring_sqe uses numbered unions, i.e. `union1` etc. that are not future-proof and need to
// be re-numbered whenever new unions are interposed by the kernel. Furthermore, Zig's unions do not
// support assignment by any union member directly as in C, without going through the union, so the
// kernel adding new unions would also break existing Zig code.
// We therefore use a flat struct without unions to avoid these two issues.
// Pending https://github.com/ziglang/zig/issues/6349.
pub const io_uring_sqe = extern struct {
    opcode: linux.IORING_OP,
    flags: u8 = 0,
    ioprio: u16 = 0,
    fd: i32 = 0,
    off: u64 = 0,
    addr: u64 = 0,
    len: u32 = 0,
    opflags: u32 = 0,
    user_data: u64 = 0,
    buffer: u16 = 0,
    personality: u16 = 0,
    splice_fd_in: i32 = 0,
    options: [2]u64 = [2]u64{ 0, 0 }
};

// TODO Add to zig/std/os/bits/linux.zig:
const IORING_SQ_CQ_OVERFLOW = 1 << 1;

comptime {
    assert(@sizeOf(io_uring_params) == 120);
    assert(@sizeOf(io_uring_sqe) == 64);
    assert(@sizeOf(io_uring_cqe) == 16);

    assert(linux.IORING_OFF_SQ_RING == 0);
    assert(linux.IORING_OFF_CQ_RING == 0x8000000);
    assert(linux.IORING_OFF_SQES == 0x10000000);
}

pub const IO_Uring = struct {
    fd: i32 = -1,
    sq: SubmissionQueue,
    cq: CompletionQueue,
    flags: u32,

    /// A friendly way to setup an io_uring, with default io_uring_params.
    /// `entries` must be a power of two between 1 and 4096, although the kernel will make the final
    /// call on how many entries the submission and completion queues will ultimately have,
    /// see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L8027-L8050.
    /// Matches the interface of io_uring_queue_init() in liburing.
    pub fn init(entries: u32, flags: u32) !IO_Uring {
        var params = io_uring_params {
            .sq_entries = 0,
            .cq_entries = 0,
            .flags = flags,
            .sq_thread_cpu = 0,
            .sq_thread_idle = 1000,
            .features = 0,
            .wq_fd = 0,
            .resv = [_]u32{0} ** 3,
            .sq_off = undefined,
            .cq_off = undefined,
        };
        // The kernel will zero the memory of the sq_off and cq_off structs in io_uring_create(),
        // see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L7986-L8002.
        return try IO_Uring.init_params(entries, &params);
    }

    /// A powerful way to setup an io_uring, if you want to tweak io_uring_params such as submission
    /// queue thread cpu affinity or thread idle timeout (the kernel and our default is 1 second).
    /// `params` is passed by reference because the kernel needs to modify the parameters.
    /// You may only set the `flags`, `sq_thread_cpu` and `sq_thread_idle` parameters.
    /// Every other parameter belongs to the kernel and must be zeroed.
    /// Matches the interface of io_uring_queue_init_params() in liburing.
    pub fn init_params(entries: u32, p: *io_uring_params) !IO_Uring {
        assert(entries >= 1 and entries <= 4096 and std.math.isPowerOfTwo(entries));
        assert(p.*.sq_entries == 0);
        assert(p.*.cq_entries == 0);
        assert(p.*.features == 0);
        assert(p.*.wq_fd == 0);
        assert(p.*.resv[0] == 0);
        assert(p.*.resv[1] == 0);
        assert(p.*.resv[2] == 0);

        const res = linux.io_uring_setup(entries, p);
        try check_errno(res);
        const fd = @intCast(i32, res);
        assert(fd >= 0);
        errdefer os.close(fd);

        // Kernel versions 5.4 and up use only one mmap() for the submission and completion queues.
        // This is not an optional feature for us... if the kernel does it, we have to do it.
        // The thinking on this by the kernel developers was that both the submission and the
        // completion queue rings have sizes just over a power of two, but the submission queue ring
        // is significantly smaller with u32 slots. By bundling both in a single mmap, the kernel
        // gets the submission queue ring for free.
        // See https://patchwork.kernel.org/patch/11115257 for the kernel patch.
        // We do not support the double mmap() done before 5.4, because we want to keep the
        // init/deinit mmap paths simple and because io_uring has had many bug fixes even since 5.4.
        if ((p.*.features & linux.IORING_FEAT_SINGLE_MMAP) == 0) {
            return error.IO_UringKernelNotSupported;
        }

        // Check that the kernel has actually set params and that "impossible is nothing".
        assert(p.*.sq_entries != 0);
        assert(p.*.cq_entries != 0);
        assert(p.*.cq_entries >= p.*.sq_entries);

        // From here on, we only need to read from params, so pass `p` by value for convenience.
        // The completion queue shares the mmap with the submission queue, so pass `sq` there too.
        var sq = try SubmissionQueue.init(fd, p.*);
        errdefer sq.deinit();
        var cq = try CompletionQueue.init(fd, p.*, sq);
        errdefer cq.deinit();

        // Check that our starting state is as we expect.
        assert(sq.head.* == 0);
        assert(sq.tail.* == 0);
        assert(sq.mask.* == p.*.sq_entries - 1);
        // Allow flags.* to be non-zero, since the kernel may set IORING_SQ_NEED_WAKEUP at any time.
        assert(sq.dropped.* == 0);
        assert(sq.array.len == p.*.sq_entries);
        assert(sq.sqes.len == p.*.sq_entries);
        assert(sq.sqe_head == 0);
        assert(sq.sqe_tail == 0);

        assert(cq.head.* == 0);
        assert(cq.tail.* == 0);
        assert(cq.mask.* == p.*.cq_entries - 1);
        assert(cq.overflow.* == 0);
        assert(cq.cqes.len == p.*.cq_entries);

        // Alles in Ordnung!
        return IO_Uring {
            .fd = fd,
            .sq = sq,
            .cq = cq,
            .flags = p.*.flags
        };
    }

    pub fn deinit(self: *IO_Uring) void {
        assert(self.fd >= 0);
        // The mmaps depend on the fd, so the order of these calls is important:
        self.cq.deinit();
        self.sq.deinit();
        os.close(self.fd);
        self.fd = -1;
    }

    /// Returns a vacant SQE, or an error if the submission queue is full.
    /// We follow the implementation (and atomics) of liburing's `io_uring_get_sqe()` exactly.
    /// However, instead of a null we return an error to force safe handling.
    /// Any situation where the submission queue is full tends more towards a control flow error,
    /// and the null return in liburing is more a C idiom than anything else, for lack of a better
    /// alternative. In Zig, we have first-class error handling... so let's use it.
    /// Matches the implementation of io_uring_get_sqe() in liburing.
    pub fn get_sqe(self: *IO_Uring) !*io_uring_sqe {
        const head = @atomicLoad(u32, self.sq.head, .Acquire);
        // Remember that these head and tail offsets wrap around every four billion operations.
        // We must therefore use wrapping addition and subtraction to avoid a runtime crash.
        const next = self.sq.sqe_tail +% 1;
        if (next -% head > self.sq.sqes.len) return error.IO_UringSubmissionQueueFull;
        var sqe = &self.sq.sqes[self.sq.sqe_tail & self.sq.mask.*];
        self.sq.sqe_tail = next;
        return sqe;
    }

    /// Submits the SQEs acquired via get_sqe() to the kernel. You can call this once after you have
    /// called get_sqe() multiple times to setup multiple I/O requests.
    /// Returns the number of SQEs submitted.
    /// Matches the implementation of io_uring_submit() in liburing.
    pub fn submit(self: *IO_Uring) !u32 {
        return self.submit_and_wait(0);
    }

    /// Like submit(), but allows waiting for events as well.
    /// Returns the number of SQEs submitted.
    /// Matches the implementation of io_uring_submit_and_wait() in liburing.
    pub fn submit_and_wait(self: *IO_Uring, wait_nr: u32) !u32 {
        var submitted = self.flush_sq();
        var flags: u32 = 0;
        if (self.sq_ring_needs_enter(submitted, &flags) or wait_nr > 0) {
            if (wait_nr > 0 or (self.flags & linux.IORING_SETUP_IOPOLL) > 0) {
                flags |= linux.IORING_ENTER_GETEVENTS;
            }
            return try self.enter(submitted, wait_nr, flags);
        }
        return submitted;
    }

    // Tell the kernel we have submitted SQEs and/or want to wait for CQEs.
    // Returns the number of SQEs submitted.
    fn enter(self: *IO_Uring, to_submit: u32, min_complete: u32, flags: u32) !u32 {
        assert(self.fd >= 0);
        const res = linux.io_uring_enter(self.fd, to_submit, min_complete, flags, null);
        try check_errno(res);
        return @truncate(u32, res);
    }

    // Sync internal state with kernel ring state on the SQ side.
    // Returns the number of all pending events in the SQ ring, for the shared ring.
    // This return value includes previously flushed SQEs, as per liburing.
    // The reasoning for this is to suggest that an io_uring_enter() call is needed rather than not.
    // Matches the implementation of __io_uring_flush_sq() in liburing.
    fn flush_sq(self: *IO_Uring) u32 {
        if (self.sq.sqe_head != self.sq.sqe_tail) {
            // Fill in SQEs that we have queued up, adding them to the kernel ring.
            const to_submit = self.sq.sqe_tail -% self.sq.sqe_head;
            const mask = self.sq.mask.*;
            var tail = self.sq.tail.*;
            var i: usize = 0;
            while (i < to_submit) : (i += 1) {
                self.sq.array[tail & mask] = self.sq.sqe_head & mask;
                tail +%= 1;
                self.sq.sqe_head +%= 1;
            }
            // Ensure that the kernel can actually see the SQE updates when it sees the tail update.
            @atomicStore(u32, self.sq.tail, tail, .Release);
        }
        return self.sq_ready();
    }

    /// Returns true if we are not using an SQ thread (thus nobody submits but us),
    /// or if IORING_SQ_NEED_WAKEUP is set and the SQ thread must be explicitly awakened.
    /// For the latter case, we set the SQ thread wakeup flag.
    /// Matches the implementation of sq_ring_needs_enter() in liburing.
    fn sq_ring_needs_enter(self: *IO_Uring, submitted: u32, flags: *u32) bool {
        assert(flags.* == 0);
        if ((self.flags & linux.IORING_SETUP_SQPOLL) == 0 and submitted > 0) return true;
        if ((@atomicLoad(u32, self.sq.flags, .Unordered) & linux.IORING_SQ_NEED_WAKEUP) > 0) {
            flags.* |= linux.IORING_ENTER_SQ_WAKEUP;
            return true;
        }
        return false;
    }

    /// Returns the number of flushed and unflushed SQEs pending in the submission queue.
    /// In other words, this is the number of SQEs in the submission queue, i.e. its length.
    /// These are SQEs that the kernel is yet to consume.
    /// Matches the implementation of io_uring_sq_ready in liburing.
    pub fn sq_ready(self: *IO_Uring) u32 {
        // Always use the shared ring state (i.e. head and not sqe_head) to avoid going out of sync,
        // see https://github.com/axboe/liburing/issues/92.
        return self.sq.sqe_tail -% @atomicLoad(u32, self.sq.head, .Acquire);
    }

    /// Returns the number of CQEs in the completion queue, i.e. its length.
    /// These are CQEs that the application is yet to consume.
    /// Matches the implementation of io_uring_cq_ready in liburing.
    pub fn cq_ready(self: *IO_Uring) u32 {
        return @atomicLoad(u32, self.cq.tail, .Acquire) -% self.cq.head.*;
    }

    /// Copies as many CQEs as are ready, and that can fit into the destination `cqes` slice.
    /// If none are available, enters into the kernel to wait for at most `wait_nr` CQEs.
    /// Returns the number of CQEs copied, advancing the CQ ring.
    /// Provides all the wait/peek methods found in liburing, but with batching and a single method.
    /// The rationale for copying CQEs rather than copying pointers is that pointers are 8 bytes
    /// whereas CQEs are not much more at only 16 bytes, and this provides a safer faster interface.
    /// Safer, because you no longer need to call cqe_seen(), avoiding idempotency bugs.
    /// Faster, because we can now amortize the atomic store release to `cq.head` across the batch.
    /// See https://github.com/axboe/liburing/issues/103#issuecomment-686665007.
    /// Matches the implementation of io_uring_peek_batch_cqe() in liburing, but supports waiting.
    pub fn copy_cqes(self: *IO_Uring, cqes: []io_uring_cqe, wait_nr: u32) !u32 {
        const count = self.copy_cqes_ready(cqes, wait_nr);
        if (count > 0) return count;
        if (self.cq_ring_needs_flush() or wait_nr > 0) {
            _ = try self.enter(0, wait_nr, linux.IORING_ENTER_GETEVENTS);
            return self.copy_cqes_ready(cqes, wait_nr);
        }
        return 0;
    }

    fn copy_cqes_ready(self: *IO_Uring, cqes: []io_uring_cqe, wait_nr: u32) u32 {
        const ready = self.cq_ready();
        const count = std.math.min(cqes.len, ready);
        const mask = self.cq.mask.*;
        var head = self.cq.head.*;
        var tail = head +% count;
        // TODO Optimize this by using 1 or 2 memcpy's (if the tail wraps) rather than a loop.
        var i: usize = 0;
        // Do not use "less-than" operator since head and tail may wrap:
        while (head != tail) {
            cqes[i] = self.cq.cqes[head & mask]; // Copy struct by value.
            head +%= 1;
            i += 1;
        }
        self.cq_advance(count);
        return count;
    }

    /// Returns a copy of an I/O completion, waiting for it if necessary, and advancing the CQ ring.
    /// A convenience method for `copy_cqes()` for when you don't need to batch or peek.
    pub fn copy_cqe(ring: *IO_Uring) !io_uring_cqe {
        var cqes: [1]io_uring_cqe = undefined;
        const count = try ring.copy_cqes(&cqes, 1);
        assert(count == 1);
        return cqes[0];
    }

    // Matches the implementation of cq_ring_needs_flush() in liburing.
    fn cq_ring_needs_flush(self: *IO_Uring) bool {
        return (@atomicLoad(u32, self.sq.flags, .Unordered) & IORING_SQ_CQ_OVERFLOW) > 0;
    }

    /// For advanced use cases only that implement custom completion queue methods.
    /// If you use copy_cqes() or copy_cqe() you must not call cqe_seen() or cq_advance().
    /// Must be called exactly once after a zero-copy CQE has been processed by your application.
    /// Not idempotent, calling more than once will result in other CQEs being lost.
    /// Matches the implementation of cqe_seen() in liburing.
    pub fn cqe_seen(self: *IO_Uring, cqe: *io_uring_cqe) void {
        self.cq_advance(1);
    }

    /// For advanced use cases only that implement custom completion queue methods.
    /// Matches the implementation of cq_advance() in liburing.
    pub fn cq_advance(self: *IO_Uring, count: u32) void {
        if (count > 0) {
            // Ensure the kernel only sees the new head value after the CQEs have been read.
            @atomicStore(u32, self.cq.head, self.cq.head.* +% count, .Release);
        }
    }

    /// Queues (but does not submit) an SQE to perform an `accept4(2)` on a socket.
    /// Returns a pointer to the SQE.
    pub fn queue_accept(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: *os.sockaddr,
        addrlen: *os.socklen_t,
        accept_flags: u32
    ) !*io_uring_sqe {
        // "sqe->fd is the file descriptor, sqe->addr holds a pointer to struct sockaddr,
        // sqe->addr2 holds a pointer to socklen_t, and finally sqe->accept_flags holds the flags
        // for accept(4)." - https://lwn.net/ml/linux-block/20191025173037.13486-1-axboe@kernel.dk/
        const sqe = try self.get_sqe();
        sqe.* = .{
            .opcode = .ACCEPT,
            .fd = fd,
            .off = @ptrToInt(addrlen), // `addr2` is a newer union member that maps to `off`.
            .addr = @ptrToInt(addr),
            .user_data = user_data,
            .opflags = accept_flags
        };
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `fsync(2)`.
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    /// For example, for `fdatasync()` you can set `IORING_FSYNC_DATASYNC` in the SQE's `opflags`.
    /// N.B. While SQEs are initiated in the order in which they appear in the submission queue,
    /// operations execute in parallel and completions are unordered. Therefore, an application that
    /// submits a write followed by an fsync in the submission queue cannot expect the fsync to
    /// apply to the write, since the fsync may complete before the write is issued to the disk.
    /// You should preferably use `link_with_next_sqe()` on a write's SQE to link it with an fsync,
    /// or else insert a full write barrier using `drain_previous_sqes()` when queueing an fsync.
    pub fn queue_fsync(self: *IO_Uring, user_data: u64, fd: os.fd_t) !*io_uring_sqe {
        const sqe = try self.get_sqe();
        sqe.* = .{
            .opcode = .FSYNC,
            .fd = fd,
            .user_data = user_data
        };
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a no-op.
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    /// A no-op is more useful than may appear at first glance.
    /// For example, you could call `drain_previous_sqes()` on the returned SQE, to use the no-op to
    /// know when the ring is idle before acting on a kill signal.
    pub fn queue_nop(self: *IO_Uring, user_data: u64) !*io_uring_sqe {
        const sqe = try self.get_sqe();
        sqe.* = .{
            .opcode = .NOP,
            .user_data = user_data
        };
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `read(2)`.
    /// Returns a pointer to the SQE.
    pub fn queue_read(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: []u8,
        offset: u64
    ) !*io_uring_sqe {
        const sqe = try self.get_sqe();
        sqe.* = .{
            .opcode = .READ,
            .fd = fd,
            .off = offset,
            .addr = @ptrToInt(buffer.ptr),
            .len = @truncate(u32, buffer.len),
            .user_data = user_data
        };
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `write(2)`.
    /// Returns a pointer to the SQE.
    pub fn queue_write(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: []const u8,
        offset: u64
    ) !*io_uring_sqe {
        const sqe = try self.get_sqe();
        sqe.* = .{
            .opcode = .WRITE,
            .fd = fd,
            .off = offset,
            .addr = @ptrToInt(buffer.ptr),
            .len = @truncate(u32, buffer.len),
            .user_data = user_data
        };
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `preadv()`.
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    /// For example, if you want to do a `preadv2()` then set `opflags` on the returned SQE.
    /// See https://linux.die.net/man/2/preadv.
    pub fn queue_readv(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        iovecs: []const os.iovec,
        offset: u64
    ) !*io_uring_sqe {
        const sqe = try self.get_sqe();
        sqe.* = .{
            .opcode = .READV,
            .fd = fd,
            .off = offset,
            .addr = @ptrToInt(iovecs.ptr),
            .len = @truncate(u32, iovecs.len),
            .user_data = user_data
        };
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `pwritev()`.
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    /// For example, if you want to do a `pwritev2()` then set `opflags` on the returned SQE.
    /// See https://linux.die.net/man/2/pwritev.
    pub fn queue_writev(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        iovecs: []const os.iovec_const,
        offset: u64
    ) !*io_uring_sqe {
        const sqe = try self.get_sqe();
        sqe.* = .{
            .opcode = .WRITEV,
            .fd = fd,
            .off = offset,
            .addr = @ptrToInt(iovecs.ptr),
            .len = @truncate(u32, iovecs.len),
            .user_data = user_data
        };
        return sqe;
    }

    /// The next SQE will not be started until this one completes.
    /// This can be used to chain causally dependent SQEs, and the chain can be arbitrarily long.
    /// The tail of the chain is denoted by the first SQE that does not have this flag set.
    /// This flag has no effect on previous SQEs, nor does it impact SQEs outside the chain.
    /// This means that multiple chains can be executing in parallel, along with individual SQEs.
    /// Only members inside the chain are serialized.
    /// A chain will be broken if any SQE in the chain ends in error, where any unexpected result is
    /// considered an error. For example, a short read will terminate the remainder of the chain.
    pub fn link_with_next_sqe(self: *IO_Uring, sqe: *io_uring_sqe) void {
        sqe.*.flags |= linux.IOSQE_IO_LINK;
    }
    
    /// Like `link_with_next_sqe()` but stronger.
    /// For when you don't want the chain to fail in the event of a completion result error.
    /// For example, you may know that some commands will fail and may want the chain to continue.
    /// Hard links are resilient to completion results, but are not resilient to submission errors.
    pub fn hardlink_with_next_sqe(self: *IO_Uring, sqe: *io_uring_sqe) void {
        sqe.*.flags |= linux.IOSQE_IO_HARDLINK;
    }
    
    /// This creates a full pipeline barrier in the submission queue.
    /// This SQE will not be started until previous SQEs complete.
    /// Subsequent SQEs will not be started until this SQE completes.
    /// In other words, this stalls the entire submission queue.
    /// You should first consider using link_with_next_sqe() for more granular SQE sequence control.
    pub fn drain_previous_sqes(self: *IO_Uring, sqe: *io_uring_sqe) void {
        sqe.*.flags |= linux.IOSQE_IO_DRAIN;
    }

    /// Registers an array of file descriptors.
    /// Every time a file descriptor is put in an SQE and submitted to the kernel, the kernel must
    /// retrieve a reference to the file, and once I/O has completed the file reference must be
    /// dropped. The atomic nature of this file reference can be a slowdown for high IOPS workloads.
    /// This slowdown can be avoided by pre-registering file descriptors.
    /// To refer to a registered file descriptor, IOSQE_FIXED_FILE must be set in the SQE's flags,
    /// and the SQE's fd must be set to the index of the file descriptor in the registered array.
    /// Registering file descriptors will wait for the ring to idle.
    /// Files are automatically unregistered by the kernel when the ring is torn down.
    /// An application need unregister only if it wants to register a new array of file descriptors.
    pub fn register_files(self: *IO_Uring, fds: []const i32) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_FILES,
            fds.ptr,
            @truncate(u32, fds.len)
        );
        try check_errno(res);
    }

    /// Changes the semantics of the SQE's `fd` to refer to a pre-registered file descriptor.
    pub fn use_registered_fd(self: *IO_Uring, sqe: *io_uring_sqe) void {
        sqe.*.flags |= linux.IOSQE_FIXED_FILE;
    }

    /// Unregisters all registered file descriptors previously associated with the ring.
    pub fn unregister_files(self: *IO_Uring) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(self.fd, .UNREGISTER_FILES, null, 0);
        try check_errno(res);
    }
};


pub const SubmissionQueue = struct {
    head: *u32,
    tail: *u32,
    mask: *u32,
    flags: *u32,
    dropped: *u32,
    array: []u32,
    sqes: []io_uring_sqe,
    mmap: []align(std.mem.page_size) u8,
    mmap_sqes: []align(std.mem.page_size) u8,

    // We use `sqe_head` and `sqe_tail` in the same way as liburing:
    // We increment `sqe_tail` (but not `tail`) for each call to `get_sqe()`.
    // We then set `tail` to `sqe_tail` once, only when these events are actually submitted.
    // This allows us to amortize the cost of the @atomicStore to `tail` across multiple SQEs.
    sqe_head: u32 = 0,
    sqe_tail: u32 = 0,
    
    pub fn init(fd: i32, p: io_uring_params) !SubmissionQueue {
        assert(fd >= 0);
        assert((p.features & linux.IORING_FEAT_SINGLE_MMAP) > 0);
        const size = std.math.max(
            p.sq_off.array + p.sq_entries * @sizeOf(u32),
            p.cq_off.cqes + p.cq_entries * @sizeOf(io_uring_cqe)
        );
        const mmap = try os.mmap(
            null,
            size,
            os.PROT_READ | os.PROT_WRITE,
            os.MAP_SHARED | os.MAP_POPULATE,
            fd,
            linux.IORING_OFF_SQ_RING,
        );
        errdefer os.munmap(mmap);
        assert(mmap.len == size);

        // The motivation for the `sqes` and `array` indirection is to make it possible for the
        // application to preallocate static io_uring_sqe entries and then replay them when needed.
        const size_sqes = p.sq_entries * @sizeOf(io_uring_sqe);
        const mmap_sqes = try os.mmap(
            null,
            size_sqes,
            os.PROT_READ | os.PROT_WRITE,
            os.MAP_SHARED | os.MAP_POPULATE,
            fd,
            linux.IORING_OFF_SQES,
        );
        errdefer os.munmap(mmap_sqes);
        assert(mmap_sqes.len == size_sqes);

        const array = @ptrCast([*]u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.array]));
        const sqes = @ptrCast([*]io_uring_sqe, @alignCast(@alignOf(io_uring_sqe), &mmap_sqes[0]));
        // We expect the kernel copies p.sq_entries to the u32 pointed to by p.sq_off.ring_entries,
        // see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L7843-L7844.
        assert(
            p.sq_entries ==
            @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.ring_entries])).*
        );
        return SubmissionQueue {
            .head = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.head])),
            .tail = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.tail])),
            .mask = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.ring_mask])),
            .flags = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.flags])),
            .dropped = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.dropped])),
            .array = array[0..p.sq_entries],
            .sqes = sqes[0..p.sq_entries],
            .mmap = mmap,
            .mmap_sqes = mmap_sqes
        };
    }

    pub fn deinit(self: *SubmissionQueue) void {
        os.munmap(self.mmap_sqes);
        os.munmap(self.mmap);
    }
};

pub const CompletionQueue = struct {
    head: *u32,
    tail: *u32,
    mask: *u32,
    overflow: *u32,
    cqes: []io_uring_cqe,

    pub fn init(fd: i32, p: io_uring_params, sq: SubmissionQueue) !CompletionQueue {
        assert(fd >= 0);
        assert((p.features & linux.IORING_FEAT_SINGLE_MMAP) > 0);
        const mmap = sq.mmap;
        const cqes = @ptrCast(
            [*]io_uring_cqe,
            @alignCast(@alignOf(io_uring_cqe), &mmap[p.cq_off.cqes])
        );
        assert(
            p.cq_entries ==
            @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.ring_entries])).*
        );
        return CompletionQueue {
            .head = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.head])),
            .tail = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.tail])),
            .mask = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.ring_mask])),
            .overflow = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.overflow])),
            .cqes = cqes[0..p.cq_entries]
        };
    }

    pub fn deinit(self: *CompletionQueue) void {
        // A no-op since we now share the mmap with the submission queue.
        // Here for symmetry with the submission queue, and for any future feature support.
    }
};

inline fn check_errno(res: usize) !void {
    const errno = linux.getErrno(res);
    if (errno != 0) return os.unexpectedErrno(errno);
}

test "queue_nop" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = try IO_Uring.init(1, 0);
    defer {
        ring.deinit();
        testing.expectEqual(@as(i32, -1), ring.fd);
    }

    var sqe = try ring.queue_nop(@intCast(u64, 0xaaaaaaaa));
    testing.expectEqual(io_uring_sqe {
        .opcode = .NOP,
        .flags = 0,
        .ioprio = 0,
        .fd = 0,
        .off = 0,
        .addr = 0,
        .len = 0,
        .opflags = 0,
        .user_data = @intCast(u64, 0xaaaaaaaa),
        .buffer = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .options = [2]u64{ 0, 0 }
    }, sqe.*);

    testing.expectEqual(@as(u32, 0), ring.sq.sqe_head);
    testing.expectEqual(@as(u32, 1), ring.sq.sqe_tail);
    testing.expectEqual(@as(u32, 0), ring.sq.tail.*);
    testing.expectEqual(@as(u32, 0), ring.cq.head.*);
    testing.expectEqual(@as(u32, 1), ring.sq_ready());
    testing.expectEqual(@as(u32, 0), ring.cq_ready());

    testing.expectEqual(@as(u32, 1), try ring.submit());
    testing.expectEqual(@as(u32, 1), ring.sq.sqe_head);
    testing.expectEqual(@as(u32, 1), ring.sq.sqe_tail);
    testing.expectEqual(@as(u32, 1), ring.sq.tail.*);
    testing.expectEqual(@as(u32, 0), ring.cq.head.*);
    testing.expectEqual(@as(u32, 0), ring.sq_ready());

    testing.expectEqual(io_uring_cqe {
        .user_data = 0xaaaaaaaa,
        .res = 0,
        .flags = 0
    }, try ring.copy_cqe());
    testing.expectEqual(@as(u32, 1), ring.cq.head.*);
    testing.expectEqual(@as(u32, 0), ring.cq_ready());

    var sqe_barrier = try ring.queue_nop(@intCast(u64, 0xbbbbbbbb));
    ring.drain_previous_sqes(sqe_barrier);
    testing.expectEqual(@as(u8, linux.IOSQE_IO_DRAIN), sqe_barrier.*.flags);
    testing.expectEqual(@as(u32, 1), try ring.submit());
    testing.expectEqual(io_uring_cqe {
        .user_data = 0xbbbbbbbb,
        .res = 0,
        .flags = 0
    }, try ring.copy_cqe());
    testing.expectEqual(@as(u32, 2), ring.sq.sqe_head);
    testing.expectEqual(@as(u32, 2), ring.sq.sqe_tail);
    testing.expectEqual(@as(u32, 2), ring.sq.tail.*);
    testing.expectEqual(@as(u32, 2), ring.cq.head.*);
}

test "queue_readv" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = try IO_Uring.init(1, 0);
    defer ring.deinit();

    const fd = try os.openZ("/dev/zero", os.O_RDONLY | os.O_CLOEXEC, 0);
    defer os.close(fd);
    
    var registered_fds = [_]i32{-1} ** 10;
    const fd_index = 9;
    registered_fds[fd_index] = fd;
    try ring.register_files(registered_fds[0..]);

    var buffer = [_]u8{42} ** 128;
    var iovecs = [_]os.iovec{ os.iovec { .iov_base = &buffer, .iov_len = buffer.len } };
    var sqe = try ring.queue_readv(0xcccccccc, fd_index, iovecs[0..], 0);
    ring.use_registered_fd(sqe);
    testing.expectEqual(@as(u8, linux.IOSQE_FIXED_FILE), sqe.*.flags);

    testing.expectError(error.IO_UringSubmissionQueueFull, ring.queue_nop(0));
    testing.expectEqual(@as(u32, 1), try ring.submit());
    testing.expectEqual(linux.io_uring_cqe {
        .user_data = 0xcccccccc,
        .res = buffer.len,
        .flags = 0,
    }, try ring.copy_cqe());
    testing.expectEqualSlices(u8, &([_]u8{0} ** buffer.len), buffer[0..]);

    try ring.unregister_files();
}

test "queue_writev/queue_fsync" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = try IO_Uring.init(2, 0);
    defer ring.deinit();
    
    const path = "test_io_uring_queue_writev";
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};
    const fd = file.handle;

    var buffer = [_]u8{42} ** 128;
    var iovecs = [_]os.iovec_const {
        os.iovec_const { .iov_base = &buffer, .iov_len = buffer.len }
    };
    var sqe_writev = try ring.queue_writev(0xdddddddd, fd, iovecs[0..], 0);
    ring.link_with_next_sqe(sqe_writev);
    testing.expectEqual(@as(u8, linux.IOSQE_IO_LINK), sqe_writev.*.flags);
    
    var sqe_fsync = try ring.queue_fsync(0xeeeeeeee, fd);
    testing.expectEqual(fd, sqe_fsync.*.fd);

    testing.expectEqual(@as(u32, 2), ring.sq_ready());
    testing.expectEqual(@as(u32, 2), try ring.submit_and_wait(2));
    testing.expectEqual(@as(u32, 0), ring.sq_ready());
    testing.expectEqual(@as(u32, 2), ring.cq_ready());
    testing.expectEqual(linux.io_uring_cqe {
        .user_data = 0xdddddddd,
        .res = buffer.len,
        .flags = 0,
    }, try ring.copy_cqe());
    testing.expectEqual(@as(u32, 1), ring.cq_ready());
    testing.expectEqual(linux.io_uring_cqe {
        .user_data = 0xeeeeeeee,
        .res = 0,
        .flags = 0,
    }, try ring.copy_cqe());
    testing.expectEqual(@as(u32, 0), ring.cq_ready());
}

test "queue_write/queue_read" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // This test may require newer kernel versions.

    var ring = try IO_Uring.init(2, 0);
    defer ring.deinit();
    
    const path = "test_io_uring_queue_write";
    const file = try std.fs.cwd().createFile(path, .{ .read = true, .truncate = true });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};
    const fd = file.handle;

    var buffer_write = [_]u8{97} ** 20;
    var buffer_read = [_]u8{98} ** 20;
    var sqe_write = try ring.queue_write(123, fd, buffer_write[0..], 10);
    ring.link_with_next_sqe(sqe_write);
    var sqe_read = try ring.queue_read(456, fd, buffer_read[0..], 10);
    testing.expectEqual(@as(u32, 2), try ring.submit());
    testing.expectEqual(linux.io_uring_cqe {
        .user_data = 123,
        .res = buffer_write.len,
        .flags = 0,
    }, try ring.copy_cqe());
    testing.expectEqual(linux.io_uring_cqe {
        .user_data = 456,
        .res = buffer_read.len,
        .flags = 0,
    }, try ring.copy_cqe());
    testing.expectEqualSlices(u8, buffer_write[0..], buffer_read[0..]);
}
