const std = @import("../../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const net = std.net;
const os = std.os;
const linux = os.linux;
const testing = std.testing;

// Known issues on older kernels:
// 5.5-5.6: send/recvmsg causes segfaults in kernel, https://lore.kernel.org/lkml/20200714184121.915085982@linuxfoundation.org/
// 5.11: enable_rings does not clear the DISABLED flag, https://lore.kernel.org/all/YPBxP6kNmTKLrxKI@kroah.com/T/

pub const IO_Uring = struct {
    fd: os.fd_t = -1,
    sq: SubmissionQueue,
    cq: CompletionQueue,
    flags: u32,
    features: u32,
    enter_ring_fd: os.fd_t,
    int_flags: IntFlags = .{},

    const IntFlags = packed struct {
        ring_registered: bool = false,
    };

    /// A friendly way to setup an io_uring, with default linux.io_uring_params.
    /// `entries` must be a power of two between 1 and 4096, although the kernel will make the final
    /// call on how many entries the submission and completion queues will ultimately have,
    /// see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L8027-L8050.
    /// Matches the interface of io_uring_queue_init() in liburing.
    pub fn init(entries: u13, flags: u32) !IO_Uring {
        var params = mem.zeroInit(linux.io_uring_params, .{
            .flags = flags,
            .sq_thread_idle = 1000,
        });
        return try IO_Uring.init_params(entries, &params);
    }

    /// A powerful way to setup an io_uring, if you want to tweak linux.io_uring_params such as submission
    /// queue thread cpu affinity or thread idle timeout (the kernel and our default is 1 second).
    /// `params` is passed by reference because the kernel needs to modify the parameters.
    /// Matches the interface of io_uring_queue_init_params() in liburing.
    pub fn init_params(entries: u13, p: *linux.io_uring_params) !IO_Uring {
        if (entries == 0) return error.EntriesZero;
        if (!std.math.isPowerOfTwo(entries)) return error.EntriesNotPowerOfTwo;

        assert(p.sq_entries == 0);
        assert(p.cq_entries == 0 or p.flags & linux.IORING_SETUP_CQSIZE != 0);
        assert(p.features == 0);
        assert(p.wq_fd == 0 or p.flags & linux.IORING_SETUP_ATTACH_WQ != 0);
        assert(p.resv[0] == 0);
        assert(p.resv[1] == 0);
        assert(p.resv[2] == 0);

        const res = linux.io_uring_setup(entries, p);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .FAULT => return error.ParamsOutsideAccessibleAddressSpace,
            // The resv array contains non-zero data, p.flags contains an unsupported flag,
            // entries out of bounds, IORING_SETUP_SQ_AFF was specified without IORING_SETUP_SQPOLL,
            // or IORING_SETUP_CQSIZE was specified but linux.io_uring_params.cq_entries was invalid:
            .INVAL => return error.ArgumentsInvalid,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOMEM => return error.SystemResources,
            // IORING_SETUP_SQPOLL was specified but effective user ID lacks sufficient privileges,
            // or a container seccomp policy prohibits io_uring syscalls:
            .PERM => return error.PermissionDenied,
            .NOSYS => return error.SystemOutdated,
            else => |errno| return os.unexpectedErrno(errno),
        }
        const fd = @intCast(os.fd_t, res);
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
        if ((p.features & linux.IORING_FEAT_SINGLE_MMAP) == 0) {
            return error.SystemOutdated;
        }

        // Check that the kernel has actually set params and that "impossible is nothing".
        assert(p.sq_entries != 0);
        assert(p.cq_entries != 0);
        assert(p.cq_entries >= p.sq_entries);

        // From here on, we only need to read from params, so pass `p` by value as immutable.
        // The completion queue shares the mmap with the submission queue, so pass `sq` there too.
        var sq = try SubmissionQueue.init(fd, p.*);
        errdefer sq.deinit();
        var cq = try CompletionQueue.init(fd, p.*, sq);
        errdefer cq.deinit();

        // Check that our starting state is as we expect.
        assert(sq.head.* == 0);
        assert(sq.tail.* == 0);
        assert(sq.mask == p.sq_entries - 1);
        // Allow flags.* to be non-zero, since the kernel may set IORING_SQ_NEED_WAKEUP at any time.
        assert(sq.dropped.* == 0);
        assert(sq.array.len == p.sq_entries);
        assert(sq.sqes.len == p.sq_entries);
        assert(sq.sqe_head == 0);
        assert(sq.sqe_tail == 0);

        assert(cq.head.* == 0);
        assert(cq.tail.* == 0);
        assert(cq.mask == p.cq_entries - 1);
        assert(cq.overflow.* == 0);
        assert(cq.cqes.len == p.cq_entries);

        return IO_Uring{
            .fd = fd,
            .sq = sq,
            .cq = cq,
            .flags = p.flags,
            .features = p.features,
            .enter_ring_fd = fd,
        };
    }

    pub fn deinit(self: *IO_Uring) void {
        assert(self.fd >= 0);
        // The mmaps depend on the fd, so the order of these calls is important:
        self.cq.deinit();
        self.sq.deinit();
        if (self.int_flags.ring_registered)
            self.unregister_ring_fd() catch {};
        os.close(self.fd);
        self.fd = -1;
        self.enter_ring_fd = -1;
    }

    /// Returns a pointer to a vacant SQE, or an error if the submission queue is full.
    /// We follow the implementation (and atomics) of liburing's `io_uring_get_sqe()` exactly.
    /// However, instead of a null we return an error to force safe handling.
    /// Any situation where the submission queue is full tends more towards a control flow error,
    /// and the null return in liburing is more a C idiom than anything else, for lack of a better
    /// alternative. In Zig, we have first-class error handling... so let's use it.
    /// Matches the implementation of io_uring_get_sqe() in liburing.
    pub fn get_sqe(self: *IO_Uring) !*linux.io_uring_sqe {
        const head = @atomicLoad(u32, self.sq.head, .Acquire);
        // Remember that these head and tail offsets wrap around every four billion operations.
        // We must therefore use wrapping addition and subtraction to avoid a runtime crash.
        const next = self.sq.sqe_tail +% 1;
        if (next -% head > self.sq.sqes.len) return error.SubmissionQueueFull;
        var sqe = &self.sq.sqes[self.sq.sqe_tail & self.sq.mask];
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
        const submitted = self.flush_sq();
        var flags: u32 = 0;
        if (self.sq_ring_needs_enter(&flags) or wait_nr > 0) {
            if (wait_nr > 0 or (self.flags & linux.IORING_SETUP_IOPOLL) != 0) {
                flags |= linux.IORING_ENTER_GETEVENTS;
            }
            return try self.enter(submitted, wait_nr, flags);
        }
        return submitted;
    }

    /// Tell the kernel we have submitted SQEs and/or want to wait for CQEs.
    /// Returns the number of SQEs submitted.
    pub fn enter(self: *IO_Uring, to_submit: u32, min_complete: u32, flags: u32) !u32 {
        assert(self.fd >= 0);
        var mflags: u32 = flags;
        if (self.int_flags.ring_registered)
            mflags |= linux.IORING_ENTER_REGISTERED_RING;
        const res = linux.io_uring_enter(self.enter_ring_fd, to_submit, min_complete, mflags, null);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            // The kernel was unable to allocate memory or ran out of resources for the request.
            // The application should wait for some completions and try again:
            .AGAIN => return error.SystemResources,
            // The SQE `fd` is invalid, or IOSQE_FIXED_FILE was set but no files were registered:
            .BADF => return error.FileDescriptorInvalid,
            // The file descriptor is valid, but the ring is not in the right state.
            // See io_uring_register(2) for how to enable the ring.
            .BADFD => return error.FileDescriptorInBadState,
            // The application attempted to overcommit the number of requests it can have pending.
            // The application should wait for some completions and try again:
            .BUSY => return error.CompletionQueueOvercommitted,
            // The SQE is invalid, or valid but the ring was setup with IORING_SETUP_IOPOLL:
            .INVAL => return error.SubmissionQueueEntryInvalid,
            // The buffer is outside the process' accessible address space, or IORING_OP_READ_FIXED
            // or IORING_OP_WRITE_FIXED was specified but no buffers were registered, or the range
            // described by `addr` and `len` is not within the buffer registered at `buf_index`:
            .FAULT => return error.BufferInvalid,
            .NXIO => return error.RingShuttingDown,
            // The kernel believes our `self.fd` does not refer to an io_uring instance,
            // or the opcode is valid but not supported by this kernel (more likely):
            .OPNOTSUPP => return error.OpcodeNotSupported,
            // The operation was interrupted by a delivery of a signal before it could complete.
            // This can happen while waiting for events with IORING_ENTER_GETEVENTS:
            .INTR => return error.SignalInterrupt,
            else => |errno| return os.unexpectedErrno(errno),
        }
        return @intCast(u32, res);
    }

    /// Sync internal state with kernel ring state on the SQ side.
    /// Returns the number of all pending events in the SQ ring, for the shared ring.
    /// This return value includes previously flushed SQEs, as per liburing.
    /// The rationale is to suggest that an io_uring_enter() call is needed rather than not.
    /// Matches the implementation of __io_uring_flush_sq() in liburing.
    pub fn flush_sq(self: *IO_Uring) u32 {
        if (self.sq.sqe_head != self.sq.sqe_tail) {
            // Fill in SQEs that we have queued up, adding them to the kernel ring.
            const to_submit = self.sq.sqe_tail -% self.sq.sqe_head;
            var tail = self.sq.tail.*;
            var i: usize = 0;
            while (i < to_submit) : (i += 1) {
                self.sq.array[tail & self.sq.mask] = self.sq.sqe_head & self.sq.mask;
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
    pub fn sq_ring_needs_enter(self: *IO_Uring, flags: *u32) bool {
        assert(flags.* == 0);
        if ((self.flags & linux.IORING_SETUP_SQPOLL) == 0) return true;
        if ((@atomicLoad(u32, self.sq.flags, .Unordered) & linux.IORING_SQ_NEED_WAKEUP) != 0) {
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
    pub fn copy_cqes(self: *IO_Uring, cqes: []linux.io_uring_cqe, wait_nr: u32) !u32 {
        const count = self.copy_cqes_ready(cqes, wait_nr);
        if (count > 0) return count;
        if (self.cq_ring_needs_flush() or wait_nr > 0) {
            _ = try self.enter(0, wait_nr, linux.IORING_ENTER_GETEVENTS);
            return self.copy_cqes_ready(cqes, wait_nr);
        }
        return 0;
    }

    fn copy_cqes_ready(self: *IO_Uring, cqes: []linux.io_uring_cqe, wait_nr: u32) u32 {
        _ = wait_nr;
        const ready = self.cq_ready();
        const count = std.math.min(cqes.len, ready);
        var head = self.cq.head.*;
        var tail = head +% count;
        // TODO Optimize this by using 1 or 2 memcpy's (if the tail wraps) rather than a loop.
        var i: usize = 0;
        // Do not use "less-than" operator since head and tail may wrap:
        while (head != tail) {
            cqes[i] = self.cq.cqes[head & self.cq.mask]; // Copy struct by value.
            head +%= 1;
            i += 1;
        }
        self.cq_advance(count);
        return count;
    }

    /// Returns a copy of an I/O completion, waiting for it if necessary, and advancing the CQ ring.
    /// A convenience method for `copy_cqes()` for when you don't need to batch or peek.
    pub fn copy_cqe(ring: *IO_Uring) !linux.io_uring_cqe {
        var cqes: [1]linux.io_uring_cqe = undefined;
        while (true) {
            const count = try ring.copy_cqes(&cqes, 1);
            if (count > 0) return cqes[0];
        }
    }

    /// Matches the implementation of cq_ring_needs_flush() in liburing.
    pub fn cq_ring_needs_flush(self: *IO_Uring) bool {
        return (@atomicLoad(u32, self.sq.flags, .Unordered) & linux.IORING_SQ_CQ_OVERFLOW) != 0;
    }

    /// For advanced use cases only that implement custom completion queue methods.
    /// If you use copy_cqes() or copy_cqe() you must not call cqe_seen() or cq_advance().
    /// Must be called exactly once after a zero-copy CQE has been processed by your application.
    /// Not idempotent, calling more than once will result in other CQEs being lost.
    /// Matches the implementation of cqe_seen() in liburing.
    pub fn cqe_seen(self: *IO_Uring, cqe: *linux.io_uring_cqe) void {
        _ = cqe;
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

    /// Queues (but does not submit) an SQE to perform an `fsync(2)`.
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    /// For example, for `fdatasync()` you can set `IORING_FSYNC_DATASYNC` in the SQE's `rw_flags`.
    /// N.B. While SQEs are initiated in the order in which they appear in the submission queue,
    /// operations execute in parallel and completions are unordered. Therefore, an application that
    /// submits a write followed by an fsync in the submission queue cannot expect the fsync to
    /// apply to the write, since the fsync may complete before the write is issued to the disk.
    /// You should preferably use `link_with_next_sqe()` on a write's SQE to link it with an fsync,
    /// or else insert a full write barrier using `drain_previous_sqes()` when queueing an fsync.
    pub fn fsync(self: *IO_Uring, user_data: u64, fd: os.fd_t, flags: u32) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_fsync(sqe, fd, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a no-op.
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    /// A no-op is more useful than may appear at first glance.
    /// For example, you could call `drain_previous_sqes()` on the returned SQE, to use the no-op to
    /// know when the ring is idle before acting on a kill signal.
    pub fn nop(self: *IO_Uring, user_data: u64) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_nop(sqe);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Used to select how the read should be handled.
    pub const ReadBuffer = union(enum) {
        /// io_uring will read directly into this buffer
        buffer: []u8,

        /// io_uring will read directly into these buffers using readv.
        iovecs: []const os.iovec,

        /// io_uring will select a buffer that has previously been provided with `provide_buffers`.
        /// The buffer group reference by `group_id` must contain at least one buffer for the read to work.
        /// `len` controls the number of bytes to read into the selected buffer.
        buffer_selection: struct {
            group_id: u16,
            len: usize,
        },
    };

    /// Queues (but does not submit) an SQE to perform a `read(2)` or `preadv` depending on the buffer type.
    /// * Reading into a `ReadBuffer.buffer` uses `read(2)`
    /// * Reading into a `ReadBuffer.iovecs` uses `preadv(2)`
    ///   If you want to do a `preadv2()` then set `rw_flags` on the returned SQE. See https://linux.die.net/man/2/preadv.
    ///
    /// Returns a pointer to the SQE.
    pub fn read(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: ReadBuffer,
        offset: u64,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        switch (buffer) {
            .buffer => |slice| io_uring_prep_read(sqe, fd, slice, offset),
            .iovecs => |vecs| io_uring_prep_readv(sqe, fd, vecs, offset),
            .buffer_selection => |selection| {
                io_uring_prep_rw(.READ, sqe, fd, 0, selection.len, offset);
                sqe.flags |= linux.IOSQE_BUFFER_SELECT;
                sqe.buf_index = selection.group_id;
            },
        }
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `readv(2)`.
    /// Returns a pointer to the SQE.
    pub fn readv(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        iovecs: []const os.iovec,
        offset: u64,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_readv(sqe, fd, iovecs, offset);
        sqe.rw_flags = flags;
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `write(2)`.
    /// Returns a pointer to the SQE.
    pub fn write(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: []const u8,
        offset: u64,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_write(sqe, fd, buffer, offset);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a IORING_OP_READ_FIXED.
    /// The `buffer` provided must be registered with the kernel by calling `register_buffers` first.
    /// The `buffer_index` must be the same as its index in the array provided to `register_buffers`.
    ///
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    pub fn read_fixed(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: *const os.iovec,
        offset: u64,
        buffer_index: u16,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_read_fixed(sqe, fd, buffer, offset, buffer_index);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `pwritev()`.
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    /// For example, if you want to do a `pwritev2()` then set `rw_flags` on the returned SQE.
    /// See https://linux.die.net/man/2/pwritev.
    pub fn writev(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        iovecs: []const os.iovec_const,
        offset: u64,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_writev(sqe, fd, iovecs, offset);
        sqe.rw_flags = flags;
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a IORING_OP_WRITE_FIXED.
    /// The `buffer` provided must be registered with the kernel by calling `register_buffers` first.
    /// The `buffer_index` must be the same as its index in the array provided to `register_buffers`.
    ///
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    pub fn write_fixed(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: *const os.iovec,
        offset: u64,
        buffer_index: u16,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_write_fixed(sqe, fd, buffer, offset, buffer_index);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `accept4(2)` on a socket.
    /// Returns a pointer to the SQE.
    pub fn accept(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: ?*os.sockaddr,
        addrlen: ?*os.socklen_t,
        flags: u32,
        opt_file_index: ?u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_accept(sqe, fd, addr, addrlen, flags);
        if (opt_file_index) |file_index|
            __io_uring_set_target_fixed_file(sqe, file_index);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn accept_multishot(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: ?*os.sockaddr,
        addrlen: ?*os.socklen_t,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.accept(user_data, fd, addr, addrlen, flags, null);
        sqe.ioprio |= linux.IORING_ACCEPT_MULTISHOT;
    }

    pub fn accept_multishot_direct(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: ?*os.sockaddr,
        addrlen: ?*os.socklen_t,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.accept_multishot(user_data, fd, addr, addrlen, flags, null);
        __io_uring_set_target_fixed_file(sqe, linux.IORING_FILE_INDEX_ALLOC - 1);
    }

    /// Queue (but does not submit) an SQE to perform a `connect(2)` on a socket.
    /// Returns a pointer to the SQE.
    pub fn connect(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: *const os.sockaddr,
        addrlen: os.socklen_t,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_connect(sqe, fd, addr, addrlen);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `epoll_ctl(2)`.
    /// Returns a pointer to the SQE.
    pub fn epoll_ctl(
        self: *IO_Uring,
        user_data: u64,
        epfd: os.fd_t,
        fd: os.fd_t,
        op: u32,
        ev: ?*linux.epoll_event,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_epoll_ctl(sqe, epfd, fd, op, ev);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Used to select how the recv call should be handled.
    pub const RecvBuffer = union(enum) {
        /// io_uring will recv directly into this buffer
        buffer: []u8,

        /// io_uring will select a buffer that has previously been provided with `provide_buffers`.
        /// The buffer group referenced by `group_id` must contain at least one buffer for the recv call to work.
        /// `len` controls the number of bytes to read into the selected buffer.
        buffer_selection: struct {
            group_id: u16,
            len: usize,
        },
    };

    /// Queues (but does not submit) an SQE to perform a `recv(2)`.
    /// Returns a pointer to the SQE.
    pub fn recv(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: RecvBuffer,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        switch (buffer) {
            .buffer => |slice| io_uring_prep_recv(sqe, fd, slice, flags),
            .buffer_selection => |selection| {
                io_uring_prep_rw(.RECV, sqe, fd, 0, selection.len, 0);
                sqe.rw_flags = flags;
                sqe.flags |= linux.IOSQE_BUFFER_SELECT;
                sqe.buf_index = selection.group_id;
            },
        }
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `send(2)`.
    /// Returns a pointer to the SQE.
    pub fn send(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: []const u8,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_send(sqe, fd, buffer, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an async zerocopy `send(2)`.
    /// Returns a pointer to the SQE.
    pub fn send_zc(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: []const u8,
        send_flags: u32,
        zc_flags: u16,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_send_zc(sqe, fd, buffer, send_flags, zc_flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an async zerocopy `send(2)`.
    /// Returns a pointer to the SQE.
    pub fn send_zc_fixed(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        buffer: []const u8,
        send_flags: u32,
        zc_flags: u16,
        buf_index: u16,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_send_zc_fixed(sqe, fd, buffer, send_flags, zc_flags, buf_index);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `recvmsg(2)`.
    /// Returns a pointer to the SQE.
    pub fn recvmsg(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        msg: *os.msghdr,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_recvmsg(sqe, fd, msg, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn recvmsg_multishot(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        msg: *os.msghdr,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.recvmsg(user_data, fd, msg, flags);
        sqe.ioprio |= linux.IORING_RECV_MULTISHOT;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `sendmsg(2)`.
    /// Returns a pointer to the SQE.
    pub fn sendmsg(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        msg: *const os.msghdr_const,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_sendmsg(sqe, fd, msg, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an async zerocopy `sendmsg(2)`.
    /// Returns a pointer to the SQE.
    pub fn sendmsg_zc(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        msg: *const os.msghdr_const,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_sendmsg_zc(sqe, fd, msg, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `openat(2)`.
    /// Returns a pointer to the SQE.
    pub fn openat(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        path: [*:0]const u8,
        flags: u32,
        mode: os.mode_t,
        opt_file_index: ?u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_openat(sqe, fd, path, flags, mode);
        if (opt_file_index) |file_index|
            __io_uring_set_target_fixed_file(sqe, file_index);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `openat2(2)`.
    /// Returns a pointer to the SQE.
    pub fn openat2(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        path: [*:0]const u8,
        how: *const linux.open_how,
        opt_file_index: ?u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_openat2(sqe, fd, path, how);
        if (opt_file_index) |file_index|
            __io_uring_set_target_fixed_file(sqe, file_index);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `close(2)`.
    /// Returns a pointer to the SQE.
    pub fn close(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        opt_file_index: ?u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_close(sqe, fd);
        if (opt_file_index) |file_index|
            __io_uring_set_target_fixed_file(sqe, file_index);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn files_update(self: *IO_Uring, user_data: u64, fds: []os.fd_t, off: u64) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_files_update(sqe, fds, off);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to register a timeout operation.
    /// Returns a pointer to the SQE.
    ///
    /// The timeout will complete when either the timeout expires, or after the specified number of
    /// events complete (if `count` is greater than `0`).
    ///
    /// `flags` may be `0` for a relative timeout, or `IORING_TIMEOUT_ABS` for an absolute timeout.
    ///
    /// The completion event result will be `-ETIME` if the timeout completed through expiration,
    /// `0` if the timeout completed after the specified number of events, or `-ECANCELED` if the
    /// timeout was removed before it expired.
    ///
    /// io_uring timeouts use the `CLOCK.MONOTONIC` clock source.
    pub fn timeout(
        self: *IO_Uring,
        user_data: u64,
        ts: *const os.linux.kernel_timespec,
        count: u32,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_timeout(sqe, ts, count, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to remove an existing timeout operation.
    /// Returns a pointer to the SQE.
    ///
    /// The timeout is identified by its `user_data`.
    ///
    /// The completion event result will be `0` if the timeout was found and cancelled successfully,
    /// `-EBUSY` if the timeout was found but expiration was already in progress, or
    /// `-ENOENT` if the timeout was not found.
    pub fn timeout_remove(
        self: *IO_Uring,
        user_data: u64,
        timeout_user_data: u64,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_timeout_remove(sqe, timeout_user_data, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to add a link timeout operation.
    /// Returns a pointer to the SQE.
    ///
    /// You need to set linux.IOSQE_IO_LINK to flags of the target operation
    /// and then call this method right after the target operation.
    /// See https://lwn.net/Articles/803932/ for detail.
    ///
    /// If the dependent request finishes before the linked timeout, the timeout
    /// is canceled. If the timeout finishes before the dependent request, the
    /// dependent request will be canceled.
    ///
    /// The completion event result of the link_timeout will be
    /// `-ETIME` if the timeout finishes before the dependent request
    /// (in this case, the completion event result of the dependent request will
    /// be `-ECANCELED`), or
    /// `-EALREADY` if the dependent request finishes before the linked timeout.
    pub fn link_timeout(
        self: *IO_Uring,
        user_data: u64,
        ts: *const os.linux.kernel_timespec,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_link_timeout(sqe, ts, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `poll(2)`.
    /// Returns a pointer to the SQE.
    pub fn poll_add(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        poll_mask: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_poll_add(sqe, fd, poll_mask);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn poll_multishot(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        poll_mask: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.poll_add(user_data, fd, poll_mask);
        sqe.len = linux.IORING_POLL_ADD_MULTI;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to remove an existing poll operation.
    /// Returns a pointer to the SQE.
    pub fn poll_remove(
        self: *IO_Uring,
        user_data: u64,
        target_user_data: u64,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_poll_remove(sqe, target_user_data);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to update the user data of an existing poll
    /// operation. Returns a pointer to the SQE.
    pub fn poll_update(
        self: *IO_Uring,
        user_data: u64,
        old_user_data: u64,
        new_user_data: u64,
        poll_mask: u32,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_poll_update(sqe, old_user_data, new_user_data, poll_mask, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `sync_file_range(2)`.
    /// Returns a pointer to the SQE.
    pub fn sync_file_range(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        len: u32,
        offset: u64,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_sync_file_range(sqe, fd, len, offset, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `fallocate(2)`.
    /// Returns a pointer to the SQE.
    pub fn fallocate(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        mode: i32,
        offset: u64,
        len: u64,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_fallocate(sqe, fd, mode, offset, len);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `statx(2)`.
    /// Returns a pointer to the SQE.
    pub fn statx(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        path: [:0]const u8,
        flags: u32,
        mask: u32,
        buf: *linux.Statx,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_statx(sqe, fd, path, flags, mask, buf);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `fadvise(2)`.
    /// Returns a pointer to the SQE.
    pub fn fadvise(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        offset: u64,
        len: u32,
        advice: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_fadvise(sqe, fd, offset, len, advice);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform an `madvise(2)`.
    /// Returns a pointer to the SQE.
    pub fn madvise(
        self: *IO_Uring,
        user_data: u64,
        addr: u64,
        len: u32,
        advice: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_madvise(sqe, addr, len, advice);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to remove an existing operation.
    /// Returns a pointer to the SQE.
    ///
    /// The operation is identified by its `user_data`.
    ///
    /// The completion event result will be `0` if the operation was found and cancelled successfully,
    /// `-EALREADY` if the operation was found but was already in progress, or
    /// `-ENOENT` if the operation was not found.
    pub fn cancel(
        self: *IO_Uring,
        user_data: u64,
        cancel_user_data: u64,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_cancel(sqe, cancel_user_data, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `shutdown(2)`.
    /// Returns a pointer to the SQE.
    ///
    /// The operation is identified by its `user_data`.
    pub fn shutdown(
        self: *IO_Uring,
        user_data: u64,
        sockfd: os.socket_t,
        how: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_shutdown(sqe, sockfd, how);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `renameat2(2)`.
    /// Returns a pointer to the SQE.
    pub fn renameat(
        self: *IO_Uring,
        user_data: u64,
        old_dir_fd: os.fd_t,
        old_path: [*:0]const u8,
        new_dir_fd: os.fd_t,
        new_path: [*:0]const u8,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_renameat(sqe, old_dir_fd, old_path, new_dir_fd, new_path, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `unlinkat(2)`.
    /// Returns a pointer to the SQE.
    pub fn unlinkat(
        self: *IO_Uring,
        user_data: u64,
        dir_fd: os.fd_t,
        path: [*:0]const u8,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_unlinkat(sqe, dir_fd, path, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `mkdirat(2)`.
    /// Returns a pointer to the SQE.
    pub fn mkdirat(
        self: *IO_Uring,
        user_data: u64,
        dir_fd: os.fd_t,
        path: [*:0]const u8,
        mode: os.mode_t,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_mkdirat(sqe, dir_fd, path, mode);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Alias of mkdirat with AT_FDCWD as dir_fd
    pub fn mkdir(
        self: *IO_Uring,
        user_data: u64,
        path: [*:0]const u8,
        mode: os.mode_t,
    ) !*linux.io_uring_sqe {
        return self.mkdirat(user_data, os.AT.FDCWD, path, mode);
    }

    /// Queues (but does not submit) an SQE to perform a `symlinkat(2)`.
    /// Returns a pointer to the SQE.
    pub fn symlinkat(
        self: *IO_Uring,
        user_data: u64,
        target: [*:0]const u8,
        new_dir_fd: os.fd_t,
        link_path: [*:0]const u8,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_symlinkat(sqe, target, new_dir_fd, link_path);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Alias of symlinkat with AT_FDCWD as dir_fd
    pub fn symlink(
        self: *IO_Uring,
        user_data: u64,
        target: [*:0]const u8,
        link_path: [*:0]const u8,
    ) !*linux.io_uring_sqe {
        return self.symlinkat(user_data, target, os.AT.FDCWD, link_path);
    }

    /// Queues (but does not submit) an SQE to perform a `linkat(2)`.
    /// Returns a pointer to the SQE.
    pub fn linkat(
        self: *IO_Uring,
        user_data: u64,
        old_dir_fd: os.fd_t,
        old_path: [*:0]const u8,
        new_dir_fd: os.fd_t,
        new_path: [*:0]const u8,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_linkat(sqe, old_dir_fd, old_path, new_dir_fd, new_path, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Alias of linkat with AT_FDCWD as old_dir_fd and new_dir_fd
    pub fn link(
        self: *IO_Uring,
        user_data: u64,
        old_path: [*:0]const u8,
        new_path: [*:0]const u8,
        flags: u32,
    ) !*linux.io_uring_sqe {
        return self.linkat(user_data, os.AT.FDCWD, old_path, os.AT.FDCWD, new_path, flags);
    }

    pub fn getxattr(
        self: *IO_Uring,
        user_data: u64,
        name: [*:0]const u8,
        path: [*:0]const u8,
        value: []u8,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_getxattr(sqe, name, path, value);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn setxattr(
        self: *IO_Uring,
        user_data: u64,
        name: [*:0]const u8,
        path: [*:0]const u8,
        value: []const u8,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_setxattr(sqe, name, path, value, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn fgetxattr(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        name: [*:0]const u8,
        value: []u8,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_fgetxattr(sqe, fd, name, value);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn fsetxattr(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        name: [*:0]const u8,
        value: []const u8,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_fsetxattr(sqe, fd, name, value, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn splice(
        self: *IO_Uring,
        user_data: u64,
        in_fd: os.fd_t,
        in_off: u64,
        out_fd: os.fd_t,
        out_off: u64,
        nbytes: u32,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_splice(sqe, in_fd, in_off, out_fd, out_off, nbytes, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn tee(
        self: *IO_Uring,
        user_data: u64,
        in_fd: os.fd_t,
        out_fd: os.fd_t,
        nbytes: u32,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_tee(sqe, in_fd, out_fd, nbytes, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn msg_ring(
        self: *IO_Uring,
        user_data: u64,
        target: *IO_Uring,
        len: u32,
        data: u64,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_msg_ring(sqe, target.fd, len, data, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    pub fn socket(
        self: *IO_Uring,
        user_data: u64,
        domain: u32,
        socket_type: u32,
        protocol: u32,
        flags: u32,
        opt_file_index: ?u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_socket(sqe, domain, socket_type, protocol, flags);
        if (opt_file_index) |file_index|
            __io_uring_set_target_fixed_file(sqe, file_index);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to provide a group of buffers used for commands that read/receive data.
    /// Returns a pointer to the SQE.
    ///
    /// Provided buffers can be used in `read`, `recv` or `recvmsg` commands via .buffer_selection.
    ///
    /// The kernel expects a contiguous block of memory of size (buffers_count * buffer_size).
    pub fn provide_buffers(
        self: *IO_Uring,
        user_data: u64,
        buffers: [*]u8,
        buffers_count: usize,
        buffer_size: usize,
        group_id: usize,
        buffer_id: usize,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_provide_buffers(sqe, buffers, buffers_count, buffer_size, group_id, buffer_id);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to remove a group of provided buffers.
    /// Returns a pointer to the SQE.
    pub fn remove_buffers(
        self: *IO_Uring,
        user_data: u64,
        buffers_count: usize,
        group_id: usize,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_remove_buffers(sqe, buffers_count, group_id);
        sqe.user_data = user_data;
        return sqe;
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
    pub fn register_files(self: *IO_Uring, fds: []const os.fd_t) !void {
        assert(self.fd >= 0);
        assert(fds.len > 0);
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_FILES,
            @ptrCast(*const anyopaque, fds.ptr),
            @intCast(u32, fds.len),
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .BUSY => return error.AlreadyRegistered,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    /// Updates registered file descriptors.
    ///
    /// Updates are applied starting at the provided offset in the original file descriptors slice.
    /// There are three kind of updates:
    /// * turning a sparse entry (where the fd is -1) into a real one
    /// * removing an existing entry (set the fd to -1)
    /// * replacing an existing entry with a new fd
    /// Adding new file descriptors must be done with `register_files`.
    pub fn register_files_update(self: *IO_Uring, offset: u32, fds: []const os.fd_t) !void {
        assert(self.fd >= 0);
        assert(fds.len > 0);
        var update = std.mem.zeroInit(linux.io_uring_files_update, .{
            .offset = offset,
            .fds = @as(u64, @ptrToInt(fds.ptr)),
        });
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_FILES_UPDATE,
            @ptrCast(*const anyopaque, &update),
            @intCast(u32, fds.len),
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    fn increase_rlimit_nofile(nr: os.rlim_t) !void {
        var rlim = try os.getrlimit(.NOFILE);
        if (rlim.cur < nr) {
            rlim.cur += nr;
            try os.setrlimit(.NOFILE, rlim);
        }
    }

    pub fn register_files_tags(self: *IO_Uring, fds: []const os.fd_t, tags: []u64) !void {
        assert(self.fd >= 0);
        assert(fds.len > 0);
        assert(fds.len == tags.len);
        assert(fds.len <= std.math.maxInt(u32));
        var reg = std.mem.zeroInit(linux.io_uring_rsrc_register, .{
            .nr = @intCast(u32, fds.len),
            .data = @ptrToInt(fds.ptr),
            .tags = @ptrToInt(tags.ptr),
        });
        var did_increase: bool = false;
        while (true) {
            const res = linux.io_uring_register(
                self.fd,
                .REGISTER_FILES2,
                &reg,
                @sizeOf(linux.io_uring_rsrc_register),
            );
            switch (linux.getErrno(res)) {
                .SUCCESS => {},
                .MFILE => if (!did_increase) {
                    did_increase = true;
                    try increase_rlimit_nofile(fds.len);
                    continue;
                },
                else => |errno| try handle_common_registration_errors(errno),
            }
            break;
        }
    }

    pub fn register_files_sparse(self: *IO_Uring, count: u32) !void {
        assert(self.fd >= 0);
        assert(count > 0);
        var reg = std.mem.zeroInit(linux.io_uring_rsrc_register, .{
            .nr = count,
            .flags = linux.IORING_RSRC_REGISTER_SPARSE,
        });
        var did_increase: bool = false;
        while (true) {
            const res = linux.io_uring_register(
                self.fd,
                .REGISTER_FILES2,
                &reg,
                @sizeOf(linux.io_uring_rsrc_register),
            );
            switch (linux.getErrno(res)) {
                .SUCCESS => {},
                .MFILE => if (!did_increase) {
                    did_increase = true;
                    try increase_rlimit_nofile(count);
                    continue;
                },
                else => |errno| try handle_common_registration_errors(errno),
            }
            break;
        }
    }

    pub fn register_files_update_tag(self: *IO_Uring, off: u32, fds: []const os.fd_t, tags: []const u64) !u32 {
        assert(self.fd >= 0);
        assert(fds.len > 0);
        assert(fds.len <= std.math.maxInt(u32));
        assert(fds.len == tags.len);
        var up = std.mem.zeroInit(linux.io_uring_rsrc_update2, .{
            .offset = off,
            .nr = @intCast(u32, fds.len),
            .data = @ptrToInt(fds.ptr),
            .tags = @ptrToInt(tags.ptr),
        });
        var did_increase: bool = false;
        while (true) {
            const res = linux.io_uring_register(
                self.fd,
                .REGISTER_FILES_UPDATE2,
                &up,
                @sizeOf(os.linux.io_uring_rsrc_update2),
            );
            switch (linux.getErrno(res)) {
                .SUCCESS => {},
                .MFILE => if (!did_increase) {
                    did_increase = true;
                    try increase_rlimit_nofile(fds.len);
                    continue;
                },
                .INVAL => return error.Disallowed,
                else => |errno| try handle_common_registration_errors(errno),
            }
            return @intCast(u32, res);
        }
    }

    /// Unregisters all registered file descriptors previously associated with the ring.
    pub fn unregister_files(self: *IO_Uring) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(self.fd, .UNREGISTER_FILES, null, 0);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .NXIO => return error.FilesNotRegistered,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    /// Registers the file descriptor for an eventfd that will be notified of completion events on
    ///  an io_uring instance.
    /// Only a single a eventfd can be registered at any given point in time.
    pub fn register_eventfd(self: *IO_Uring, fd: os.fd_t) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_EVENTFD,
            @ptrCast(*const anyopaque, &fd),
            1,
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    /// Registers the file descriptor for an eventfd that will be notified of completion events on
    /// an io_uring instance. Notifications are only posted for events that complete in an async manner.
    /// This means that events that complete inline while being submitted do not trigger a notification event.
    /// Only a single eventfd can be registered at any given point in time.
    pub fn register_eventfd_async(self: *IO_Uring, fd: os.fd_t) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_EVENTFD_ASYNC,
            @ptrCast(*const anyopaque, &fd),
            1,
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    /// Unregister the registered eventfd file descriptor.
    pub fn unregister_eventfd(self: *IO_Uring) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(
            self.fd,
            .UNREGISTER_EVENTFD,
            null,
            0,
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    /// Registers an array of buffers for use with `read_fixed` and `write_fixed`.
    pub fn register_buffers(self: *IO_Uring, buffers: []const os.iovec) !void {
        assert(self.fd >= 0);
        assert(buffers.len > 0);
        assert(buffers.len <= linux.IOV_MAX);
        assert(buffers.len < linux.IOV_MAX);
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_BUFFERS,
            buffers.ptr,
            @intCast(u32, buffers.len),
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .BUSY => return error.AlreadyRegistered,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_buffers_tags(self: *IO_Uring, buffers: []const os.iovec, tags: []u64) !void {
        assert(self.fd >= 0);
        assert(buffers.len > 0);
        assert(buffers.len <= linux.IOV_MAX);
        assert(buffers.len == tags.len);
        var reg = std.mem.zeroInit(linux.io_uring_rsrc_register, .{
            .nr = @intCast(u32, buffers.len),
            .data = @ptrToInt(buffers.ptr),
            .tags = @ptrToInt(tags.ptr),
        });
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_BUFFERS2,
            &reg,
            @sizeOf(linux.io_uring_rsrc_register),
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .BUSY => return error.AlreadyRegistered,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_buffers_sparse(self: *IO_Uring, count: u32) !void {
        assert(self.fd >= 0);
        assert(count > 0);
        var reg = std.mem.zeroInit(linux.io_uring_rsrc_register, .{
            .nr = count,
            .flags = linux.IORING_RSRC_REGISTER_SPARSE,
        });
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_BUFFERS2,
            &reg,
            @sizeOf(linux.io_uring_rsrc_register),
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .BUSY => return error.AlreadyRegistered,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_buffers_update_tag(self: *IO_Uring, off: u32, buffers: []const os.iovec, tags: []const u64) !u32 {
        assert(self.fd >= 0);
        assert(buffers.len > 0);
        assert(buffers.len <= linux.IOV_MAX);
        assert(buffers.len == tags.len);
        var up = std.mem.zeroInit(linux.io_uring_rsrc_update2, .{
            .offset = off,
            .data = @ptrToInt(buffers.ptr),
            .tags = @ptrToInt(tags.ptr),
            .nr = @intCast(u32, buffers.len),
        });
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_BUFFERS_UPDATE,
            &up,
            @sizeOf(linux.io_uring_rsrc_update2),
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .BUSY => return error.AlreadyRegistered,
            else => |errno| try handle_common_registration_errors(errno),
        }
        return @intCast(u32, res);
    }

    /// Unregister the registered buffers.
    pub fn unregister_buffers(self: *IO_Uring) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(self.fd, .UNREGISTER_BUFFERS, null, 0);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .NXIO => return error.BuffersNotRegistered,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_probe(self: *IO_Uring, store: *linux.io_uring_probe, nr_ops: u32) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_PROBE,
            store,
            nr_ops,
        );
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn get_probe() !ProbeStore {
        var ring = try IO_Uring.init(2, 0);
        defer ring.deinit();
        var result = ProbeStore{};
        try ring.register_probe(&result.probe, ProbeStore.store_length);
        return result;
    }

    pub fn register_personality(self: *IO_Uring) !u16 {
        const res = linux.io_uring_register(self.fd, .REGISTER_PERSONALITY, null, 0);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
        return @intCast(u16, res);
    }

    pub fn unregister_personality(self: *IO_Uring, id: u16) !void {
        const res = linux.io_uring_register(self.fd, .UNREGISTER_PERSONALITY, null, id);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .INVAL => return error.PersonalityNotRegistered,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_restrictions(self: *IO_Uring, restrictions: []const linux.io_uring_restriction) !void {
        assert(restrictions.len <= std.math.maxInt(u32));
        const res = linux.io_uring_register(self.fd, .REGISTER_RESTRICTIONS, restrictions.ptr, @intCast(u32, restrictions.len));
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .BADFD => return error.RingNotDisabled,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn enable_rings(self: *IO_Uring) !void {
        const res = linux.io_uring_register(self.fd, .REGISTER_ENABLE_RINGS, null, 0);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .BADFD => return error.RingNotDisabled,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_iowq_aff(self: *IO_Uring, cpusz: u32, mask: *const linux.cpu_set_t) !void {
        const res = linux.io_uring_register(self.fd, .REGISTER_IOWQ_AFF, mask, cpusz);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn unregister_iowq_aff(self: *IO_Uring) !void {
        const res = linux.io_uring_register(self.fd, .UNREGISTER_IOWQ_AFF, null, 0);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_iowq_max_workers(self: *IO_Uring, val: *u32) !void {
        const res = linux.io_uring_register(self.fd, .REGISTER_IOWQ_MAX_WORKERS, val, 2);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_ring_fd(self: *IO_Uring) !void {
        assert(self.fd >= 0);
        var up = std.mem.zeroInit(linux.io_uring_rsrc_update, .{
            .offset = std.math.maxInt(u32),
            .data = @intCast(u64, self.fd),
        });
        const res = linux.io_uring_register(self.fd, .REGISTER_RING_FDS, &up, 1);
        if (res == 1) {
            self.enter_ring_fd = @bitCast(os.fd_t, up.offset);
            self.int_flags.ring_registered = true;
        }
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn unregister_ring_fd(self: *IO_Uring) !void {
        var up = std.mem.zeroInit(linux.io_uring_rsrc_update, .{
            .offset = @bitCast(u32, self.enter_ring_fd),
        });
        const res = linux.io_uring_register(self.fd, .UNREGISTER_RING_FDS, &up, 1);
        if (res == 1) {
            self.enter_ring_fd = self.fd;
            self.int_flags.ring_registered = false;
        }
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_buf_ring(self: *IO_Uring, request: linux.io_uring_buf_reg, flags: u32) !void {
        _ = flags;
        assert(self.fd >= 0);
        const res = linux.io_uring_register(self.fd, .REGISTER_PBUF_RING, &request, 1);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .EXIST => return error.GroupIDAlreadyTaken,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn unregister_buf_ring(self: *IO_Uring, bgid: u16) !void {
        const request = std.mem.zeroInit(linux.io_uring_buf_reg, .{ .bgid = bgid });
        const res = linux.io_uring_register(self.fd, .UNREGISTER_PBUF_RING, &request, 1);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .INVAL => return error.UnknownGroupID,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_sync_cancel(self: *IO_Uring, reg: *const linux.io_uring_sync_cancel_reg) !void {
        const res = linux.io_uring_register(self.fd, .REGISTER_SYNC_CANCEL, reg, 1);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .TIME => return error.Timeout,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    pub fn register_file_alloc_range(self: *IO_Uring, off: u32, len: u32) !void {
        var range = std.mem.zeroInit(linux.io_uring_file_index_range, .{
            .off = off,
            .len = len,
        });
        const res = linux.io_uring_register(self.fd, .REGISTER_FILE_ALLOC_RANGE, &range, 0);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .OVERFLOW => return error.Overflow,
            else => |errno| try handle_common_registration_errors(errno),
        }
    }

    fn handle_common_registration_errors(errno: linux.E) !void {
        switch (errno) {
            .SUCCESS => {},
            // The opcode field is not allowed due to registered restrictions.
            .ACCES => return error.Restricted,
            // One or more fds in the fd array are invalid.
            .BADF => return error.FileDescriptorInvalid,
            // buffer is outside of the process' accessible address space, or iov_len is greater
            // than 1GiB.
            .FAULT => return error.Fault,
            // Along with invalid inputs, INVAL is also used to report unsuported operations.
            .INVAL => return error.NotSupported,
            // Insufficient kernel resources, or the caller had a non-zero RLIMIT_MEMLOCK soft
            // resource limit but tried to lock more memory than the limit permitted (not enforced
            // when the process is privileged with CAP_IPC_LOCK):
            .NOMEM => return error.SystemResources,
            // Attempt to register files or buffers on an io_uring instance that is already
            // undergoing file or buffer registration, or is being torn down.
            .NXIO => return error.RingShuttingDownOrAlreadyRegistering,
            // User buffers point to file-backed memory.
            .OPNOTSUPP => return error.FileBackedMemory,
            else => return os.unexpectedErrno(errno),
        }
    }
};

pub const SubmissionQueue = struct {
    head: *u32,
    tail: *u32,
    mask: u32,
    flags: *u32,
    dropped: *u32,
    array: []u32,
    sqes: []linux.io_uring_sqe,
    mmap: []align(mem.page_size) u8,
    mmap_sqes: []align(mem.page_size) u8,

    // We use `sqe_head` and `sqe_tail` in the same way as liburing:
    // We increment `sqe_tail` (but not `tail`) for each call to `get_sqe()`.
    // We then set `tail` to `sqe_tail` once, only when these events are actually submitted.
    // This allows us to amortize the cost of the @atomicStore to `tail` across multiple SQEs.
    sqe_head: u32 = 0,
    sqe_tail: u32 = 0,

    pub fn init(fd: os.fd_t, p: linux.io_uring_params) !SubmissionQueue {
        assert(fd >= 0);
        assert((p.features & linux.IORING_FEAT_SINGLE_MMAP) != 0);
        const size = std.math.max(
            p.sq_off.array + p.sq_entries * @sizeOf(u32),
            p.cq_off.cqes + p.cq_entries * @sizeOf(linux.io_uring_cqe),
        );
        const mmap = try os.mmap(
            null,
            size,
            os.PROT.READ | os.PROT.WRITE,
            os.MAP.SHARED | os.MAP.POPULATE,
            fd,
            linux.IORING_OFF_SQ_RING,
        );
        errdefer os.munmap(mmap);
        assert(mmap.len == size);

        // The motivation for the `sqes` and `array` indirection is to make it possible for the
        // application to preallocate static linux.io_uring_sqe entries and then replay them when needed.
        const size_sqes = p.sq_entries * @sizeOf(linux.io_uring_sqe);
        const mmap_sqes = try os.mmap(
            null,
            size_sqes,
            os.PROT.READ | os.PROT.WRITE,
            os.MAP.SHARED | os.MAP.POPULATE,
            fd,
            linux.IORING_OFF_SQES,
        );
        errdefer os.munmap(mmap_sqes);
        assert(mmap_sqes.len == size_sqes);

        const array = @ptrCast([*]u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.array]));
        const sqes = @ptrCast([*]linux.io_uring_sqe, @alignCast(@alignOf(linux.io_uring_sqe), &mmap_sqes[0]));
        // We expect the kernel copies p.sq_entries to the u32 pointed to by p.sq_off.ring_entries,
        // see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L7843-L7844.
        assert(
            p.sq_entries ==
                @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.ring_entries])).*,
        );
        return SubmissionQueue{
            .head = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.head])),
            .tail = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.tail])),
            .mask = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.ring_mask])).*,
            .flags = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.flags])),
            .dropped = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.sq_off.dropped])),
            .array = array[0..p.sq_entries],
            .sqes = sqes[0..p.sq_entries],
            .mmap = mmap,
            .mmap_sqes = mmap_sqes,
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
    mask: u32,
    overflow: *u32,
    cqes: []linux.io_uring_cqe,

    pub fn init(fd: os.fd_t, p: linux.io_uring_params, sq: SubmissionQueue) !CompletionQueue {
        assert(fd >= 0);
        assert((p.features & linux.IORING_FEAT_SINGLE_MMAP) != 0);
        const mmap = sq.mmap;
        const cqes = @ptrCast(
            [*]linux.io_uring_cqe,
            @alignCast(@alignOf(linux.io_uring_cqe), &mmap[p.cq_off.cqes]),
        );
        assert(p.cq_entries ==
            @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.ring_entries])).*);
        return CompletionQueue{
            .head = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.head])),
            .tail = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.tail])),
            .mask = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.ring_mask])).*,
            .overflow = @ptrCast(*u32, @alignCast(@alignOf(u32), &mmap[p.cq_off.overflow])),
            .cqes = cqes[0..p.cq_entries],
        };
    }

    pub fn deinit(self: *CompletionQueue) void {
        _ = self;
        // A no-op since we now share the mmap with the submission queue.
        // Here for symmetry with the submission queue, and for any future feature support.
    }
};

/// Stores the results of the register_probe operation, allowing to query what opcode are supported.
pub const ProbeStore = extern struct {
    const operations = @typeInfo(linux.IORING_OP).Enum.fields;
    pub const store_length = operations.len;

    probe: linux.io_uring_probe = .{
        .last_op = @intToEnum(linux.IORING_OP, 0),
        .ops_len = undefined,
        .resv = undefined,
        .resv2 = undefined,
    },
    operations: [store_length]linux.io_uring_probe_op = undefined,

    pub fn supported(self: *const ProbeStore, opcode: linux.IORING_OP) bool {
        const mask = @as(u32, linux.IO_URING_OP_SUPPORTED);
        const op_int = @enumToInt(opcode);
        if (op_int > @enumToInt(self.probe.last_op))
            return false;
        return self.operations[op_int].flags & mask != 0;
    }
};

/// Stores a "buf_ring" used in automatic buffer selection scenarios, like recv_multishot.
pub const BufferRing = struct {
    const Self = @This();

    bufs: []align(mem.page_size) linux.io_uring_buf,
    mask: u16,

    pub fn init(count: u16) !Self {
        if (!std.math.isPowerOfTwo(count))
            return error.CountNotPowerOfTwo;
        return Self{
            .bufs = std.mem.bytesAsSlice(linux.io_uring_buf, try os.mmap(
                null,
                count * @sizeOf(linux.io_uring_buf),
                os.PROT.READ | os.PROT.WRITE,
                os.MAP.SHARED | os.MAP.POPULATE | os.MAP.ANONYMOUS,
                0,
                0,
            )),
            .mask = count - 1,
        };
    }

    pub fn deinit(self: *Self) void {
        os.munmap(std.mem.sliceAsBytes(self.bufs));
    }

    /// Adds a buffer back to the pool when done with its data
    pub fn add_raw(self: *Self, addr: u64, len: u32, bid: u16, off: u16) void {
        const tail = self.bufs[0].resv;
        const slot = (tail + off) & self.mask;
        var target = &self.bufs[slot];
        target.addr = addr;
        target.len = len;
        target.bid = bid;
    }

    /// Adds a buffer back to the pool when done with its data
    pub fn add(self: *Self, buf: []u8, bid: u16) void {
        self.add_raw(@ptrToInt(buf.ptr), @intCast(u32, buf.len), bid, bid);
    }

    /// Commits count previously added buffers to the shared buffer ring
    pub fn advance(self: *Self, count: u16) void {
        _ = @atomicRmw(u16, &self.bufs[0].resv, .Add, count, .Release);
    }

    /// Helper to use with IO_Uring.register_buf_ring
    pub fn makeRegRequest(self: *const Self, bgid: u16) linux.io_uring_buf_reg {
        return std.mem.zeroInit(linux.io_uring_buf_reg, .{
            .ring_addr = @ptrToInt(self.bufs.ptr),
            .ring_entries = self.mask + 1,
            .bgid = bgid,
        });
    }
};

pub fn io_uring_prep_nop(sqe: *linux.io_uring_sqe) void {
    sqe.* = std.mem.zeroInit(linux.io_uring_sqe, .{
        .opcode = .NOP,
    });
}

pub fn io_uring_prep_fsync(sqe: *linux.io_uring_sqe, fd: os.fd_t, flags: u32) void {
    sqe.* = std.mem.zeroInit(linux.io_uring_sqe, .{
        .opcode = .FSYNC,
        .fd = fd,
        .rw_flags = flags,
    });
}

pub fn io_uring_prep_rw(
    op: linux.IORING_OP,
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    addr: u64,
    len: usize,
    offset: u64,
) void {
    sqe.* = std.mem.zeroInit(linux.io_uring_sqe, .{
        .opcode = op,
        .fd = fd,
        .off = offset,
        .addr = addr,
        .len = @intCast(u32, len),
    });
}

pub fn io_uring_prep_splice(
    sqe: *linux.io_uring_sqe,
    in_fd: os.fd_t,
    in_off: u64,
    out_fd: os.fd_t,
    out_off: u64,
    nbytes: u32,
    flags: u32,
) void {
    io_uring_prep_rw(.SPLICE, sqe, out_fd, in_off, nbytes, out_off);
    sqe.splice_fd_in = in_fd;
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_tee(
    sqe: *linux.io_uring_sqe,
    in_fd: os.fd_t,
    out_fd: os.fd_t,
    nbytes: u32,
    flags: u32,
) void {
    io_uring_prep_rw(.TEE, sqe, out_fd, 0, nbytes, 0);
    sqe.splice_fd_in = in_fd;
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_read(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []u8, offset: u64) void {
    io_uring_prep_rw(.READ, sqe, fd, @ptrToInt(buffer.ptr), buffer.len, offset);
}

pub fn io_uring_prep_write(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []const u8, offset: u64) void {
    io_uring_prep_rw(.WRITE, sqe, fd, @ptrToInt(buffer.ptr), buffer.len, offset);
}

pub fn io_uring_prep_readv(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    iovecs: []const os.iovec,
    offset: u64,
) void {
    io_uring_prep_rw(.READV, sqe, fd, @ptrToInt(iovecs.ptr), iovecs.len, offset);
}

pub fn io_uring_prep_writev(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    iovecs: []const os.iovec_const,
    offset: u64,
) void {
    io_uring_prep_rw(.WRITEV, sqe, fd, @ptrToInt(iovecs.ptr), iovecs.len, offset);
}

pub fn io_uring_prep_read_fixed(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: *const os.iovec, offset: u64, buffer_index: u16) void {
    io_uring_prep_rw(.READ_FIXED, sqe, fd, @ptrToInt(buffer.iov_base), buffer.iov_len, offset);
    sqe.buf_index = buffer_index;
}

pub fn io_uring_prep_write_fixed(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: *const os.iovec, offset: u64, buffer_index: u16) void {
    io_uring_prep_rw(.WRITE_FIXED, sqe, fd, @ptrToInt(buffer.iov_base), buffer.iov_len, offset);
    sqe.buf_index = buffer_index;
}

/// Poll masks previously used to comprise of 16 bits in the flags union of
/// a SQE, but were then extended to comprise of 32 bits in order to make
/// room for additional option flags. To ensure that the correct bits of
/// poll masks are consistently and properly read across multiple kernel
/// versions, poll masks are enforced to be little-endian.
/// https://www.spinics.net/lists/io-uring/msg02848.html
pub inline fn __io_uring_prep_poll_mask(poll_mask: u32) u32 {
    return std.mem.nativeToLittle(u32, poll_mask);
}

pub fn io_uring_prep_accept(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    addr: ?*os.sockaddr,
    addrlen: ?*os.socklen_t,
    flags: u32,
) void {
    // `addr` holds a pointer to `sockaddr`, and `addr2` holds a pointer to socklen_t`.
    // `addr2` maps to `sqe.off` (u64) instead of `sqe.len` (which is only a u32).
    io_uring_prep_rw(.ACCEPT, sqe, fd, @ptrToInt(addr), 0, @ptrToInt(addrlen));
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_connect(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    addr: *const os.sockaddr,
    addrlen: os.socklen_t,
) void {
    // `addrlen` maps to `sqe.off` (u64) instead of `sqe.len` (which is only a u32).
    io_uring_prep_rw(.CONNECT, sqe, fd, @ptrToInt(addr), 0, addrlen);
}

pub fn io_uring_prep_epoll_ctl(
    sqe: *linux.io_uring_sqe,
    epfd: os.fd_t,
    fd: os.fd_t,
    op: u32,
    ev: ?*linux.epoll_event,
) void {
    io_uring_prep_rw(.EPOLL_CTL, sqe, epfd, @ptrToInt(ev), op, @intCast(u64, fd));
}

pub fn io_uring_prep_recv(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []u8, flags: u32) void {
    io_uring_prep_rw(.RECV, sqe, fd, @ptrToInt(buffer.ptr), buffer.len, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_send(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []const u8, flags: u32) void {
    io_uring_prep_rw(.SEND, sqe, fd, @ptrToInt(buffer.ptr), buffer.len, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_send_zc(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []const u8, send_flags: u32, zc_flags: u16) void {
    io_uring_prep_rw(.SEND_ZC, sqe, fd, @ptrToInt(buffer.ptr), buffer.len, 0);
    sqe.rw_flags = send_flags;
    sqe.ioprio = zc_flags;
}

pub fn io_uring_prep_send_zc_fixed(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []const u8, send_flags: u32, zc_flags: u16, buf_index: u16) void {
    io_uring_prep_send_zc(sqe, fd, buffer, send_flags, zc_flags);
    sqe.ioprio |= linux.IORING_RECVSEND_FIXED_BUF;
    sqe.buf_index = buf_index;
}

pub fn io_uring_prep_sendmsg_zc(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    msg: *const os.msghdr_const,
    flags: u32,
) void {
    io_uring_prep_sendmsg(sqe, fd, msg, flags);
    sqe.opcode = .SENDMSG_ZC;
}

pub fn io_uring_prep_recvmsg(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    msg: *os.msghdr,
    flags: u32,
) void {
    linux.io_uring_prep_rw(.RECVMSG, sqe, fd, @ptrToInt(msg), 1, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_sendmsg(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    msg: *const os.msghdr_const,
    flags: u32,
) void {
    linux.io_uring_prep_rw(.SENDMSG, sqe, fd, @ptrToInt(msg), 1, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_send_set_addr(
    sqe: *linux.io_uring_sqe,
    dest_addr: *const os.sockaddr,
    addr_len: u16,
) void {
    sqe.off = @ptrToInt(dest_addr);
    sqe.splice_fd_in = @as(u32, addr_len) << 16;
}

pub fn io_uring_recvmsg_validate(buf: []const u8, msgh: *const linux.msghdr) !*const linux.io_uring_recvmsg_out {
    const header = msgh.controllen + msgh.namelen + @sizeOf(linux.io_uring_recvmsg_out);
    if (buf.len < header)
        return error.Truncated;
    const alignment = @alignOf(linux.io_uring_recvmsg_out);
    if ((@ptrToInt(buf.ptr) % alignment) != 0)
        return error.NotAligned;
    const aligned = @alignCast(alignment, buf.ptr);
    return @ptrCast(*const linux.io_uring_recvmsg_out, aligned);
}

pub fn io_uring_recvmsg_name(
    o: *const linux.io_uring_recvmsg_out,
) []const u8 {
    const end_ptr_as_u8 = @ptrCast([*]const u8, o) + @sizeOf(linux.io_uring_recvmsg_out);
    return end_ptr_as_u8[0..o.namelen];
}

pub fn io_uring_recvmsg_control(o: *const linux.io_uring_recvmsg_out, msgh: *const linux.msghdr) []const u8 {
    const end_ptr_as_u8 = @ptrCast([*]const u8, o) + @sizeOf(linux.io_uring_recvmsg_out);
    const offset = msgh.namelen;
    return end_ptr_as_u8[offset .. offset + o.controllen];
}

pub fn io_uring_recvmsg_payload(o: *const linux.io_uring_recvmsg_out, msgh: *const linux.msghdr) []const u8 {
    const end_ptr_as_u8 = @ptrCast([*]const u8, o) + @sizeOf(linux.io_uring_recvmsg_out);
    const offset = msgh.namelen + msgh.controllen;
    return end_ptr_as_u8[offset .. offset + o.payloadlen];
}

// TODO: Not def in linux, although defs exists for dragonfly&solaris
pub const cmsghdr = extern struct {
    cmsg_len: usize,
    cmsg_level: i32,
    cmsg_type: i32,
};

pub fn io_uring_cmsghdr_data(cmsg: *const cmsghdr) []const u8 {
    const ptr_as_u8 = @ptrCast([*]const u8, cmsg);
    return ptr_as_u8[@sizeOf(cmsghdr)..cmsg.cmsg_len];
}

pub fn io_uring_recvmsg_cmsg_firsthdr(o: *const linux.io_uring_recvmsg_out, msgh: *const linux.msghdr) ?*const cmsghdr {
    if (o.controllen < @sizeOf(cmsghdr))
        return null;

    const control = io_uring_recvmsg_control(o, msgh);
    const alignment = @alignOf(cmsghdr);
    if ((@ptrToInt(control.ptr) % alignment) != 0)
        return null;

    const aligned = @alignCast(alignment, control.ptr);
    return @ptrCast(*const cmsghdr, aligned);
}

pub fn io_uring_recvmsg_cmsg_nexthdr(
    o: *const linux.io_uring_recvmsg_out,
    msgh: *const linux.msghdr,
    cmsg: *const cmsghdr,
) ?*const cmsghdr {
    if (cmsg.cmsg_len < @sizeOf(cmsghdr))
        return null;

    const control = io_uring_recvmsg_control(o, msgh);
    const end_ptr = control.ptr + control.len;
    const current_ptr = @ptrCast([*]const u8, cmsg);
    const next_ptr = current_ptr + cmsg.cmsg_len;
    const alignment = @alignOf(cmsghdr);
    const aligned_raw = std.mem.alignForward(@ptrToInt(next_ptr), alignment);
    const aligned = @intToPtr([*]const u8, aligned_raw);
    if (@ptrToInt(aligned) >= @ptrToInt(end_ptr))
        return null;

    const aligned_ptr = @alignCast(alignment, aligned);
    return @ptrCast(*const cmsghdr, aligned_ptr);
}

pub fn io_uring_prep_openat(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    path: [*:0]const u8,
    flags: u32,
    mode: os.mode_t,
) void {
    io_uring_prep_rw(.OPENAT, sqe, fd, @ptrToInt(path), mode, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_openat2(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    path: [*:0]const u8,
    how: *const linux.open_how,
) void {
    io_uring_prep_rw(.OPENAT2, sqe, fd, @ptrToInt(path), @sizeOf(linux.open_how), @ptrToInt(how));
}

pub fn io_uring_prep_close(sqe: *linux.io_uring_sqe, fd: os.fd_t) void {
    sqe.* = std.mem.zeroInit(linux.io_uring_sqe, .{
        .opcode = .CLOSE,
        .fd = fd,
    });
}

pub fn io_uring_prep_files_update(sqe: *linux.io_uring_sqe, fds: []os.fd_t, off: u64) void {
    io_uring_prep_rw(.FILES_UPDATE, sqe, -1, @ptrToInt(fds.ptr), fds.len, off);
}

pub fn io_uring_prep_timeout(
    sqe: *linux.io_uring_sqe,
    ts: *const os.linux.kernel_timespec,
    count: u32,
    flags: u32,
) void {
    io_uring_prep_rw(.TIMEOUT, sqe, -1, @ptrToInt(ts), 1, count);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_timeout_remove(sqe: *linux.io_uring_sqe, timeout_user_data: u64, flags: u32) void {
    sqe.* = std.mem.zeroInit(linux.io_uring_sqe, .{
        .opcode = .TIMEOUT_REMOVE,
        .fd = -1,
        .addr = timeout_user_data,
        .rw_flags = flags,
    });
}

pub fn io_uring_prep_link_timeout(
    sqe: *linux.io_uring_sqe,
    ts: *const os.linux.kernel_timespec,
    flags: u32,
) void {
    linux.io_uring_prep_rw(.LINK_TIMEOUT, sqe, -1, @ptrToInt(ts), 1, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_poll_add(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    poll_mask: u32,
) void {
    io_uring_prep_rw(.POLL_ADD, sqe, fd, @ptrToInt(@as(?*anyopaque, null)), 0, 0);
    sqe.rw_flags = __io_uring_prep_poll_mask(poll_mask);
}

pub fn io_uring_prep_poll_remove(
    sqe: *linux.io_uring_sqe,
    target_user_data: u64,
) void {
    io_uring_prep_rw(.POLL_REMOVE, sqe, -1, target_user_data, 0, 0);
}

pub fn io_uring_prep_poll_update(
    sqe: *linux.io_uring_sqe,
    old_user_data: u64,
    new_user_data: u64,
    poll_mask: u32,
    flags: u32,
) void {
    io_uring_prep_rw(.POLL_REMOVE, sqe, -1, old_user_data, flags, new_user_data);
    sqe.rw_flags = __io_uring_prep_poll_mask(poll_mask);
}

pub fn io_uring_prep_sync_file_range(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    len: u32,
    offset: u64,
    flags: u32,
) void {
    io_uring_prep_rw(.SYNC_FILE_RANGE, sqe, fd, 0, len, offset);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_fallocate(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    mode: i32,
    offset: u64,
    len: u64,
) void {
    sqe.* = std.mem.zeroInit(linux.io_uring_sqe, .{
        .opcode = .FALLOCATE,
        .fd = fd,
        .off = offset,
        .addr = len,
        .len = @intCast(u32, mode),
    });
}

pub fn io_uring_prep_statx(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    path: [*:0]const u8,
    flags: u32,
    mask: u32,
    buf: *linux.Statx,
) void {
    io_uring_prep_rw(.STATX, sqe, fd, @ptrToInt(path), mask, @ptrToInt(buf));
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_fadvise(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    offset: u64,
    len: u32,
    advice: u32,
) void {
    io_uring_prep_rw(.FADVISE, sqe, fd, 0, len, offset);
    sqe.rw_flags = advice;
}

pub fn io_uring_prep_madvise(
    sqe: *linux.io_uring_sqe,
    addr: u64,
    len: u32,
    advice: u32,
) void {
    io_uring_prep_rw(.MADVISE, sqe, -1, addr, len, 0);
    sqe.rw_flags = advice;
}

pub fn io_uring_prep_cancel(
    sqe: *linux.io_uring_sqe,
    cancel_user_data: u64,
    flags: u32,
) void {
    io_uring_prep_rw(.ASYNC_CANCEL, sqe, -1, cancel_user_data, 0, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_shutdown(
    sqe: *linux.io_uring_sqe,
    sockfd: os.socket_t,
    how: u32,
) void {
    io_uring_prep_rw(.SHUTDOWN, sqe, sockfd, 0, how, 0);
}

pub fn io_uring_prep_renameat(
    sqe: *linux.io_uring_sqe,
    old_dir_fd: os.fd_t,
    old_path: [*:0]const u8,
    new_dir_fd: os.fd_t,
    new_path: [*:0]const u8,
    flags: u32,
) void {
    io_uring_prep_rw(
        .RENAMEAT,
        sqe,
        old_dir_fd,
        @ptrToInt(old_path),
        0,
        @ptrToInt(new_path),
    );
    sqe.len = @bitCast(u32, new_dir_fd);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_unlinkat(
    sqe: *linux.io_uring_sqe,
    dir_fd: os.fd_t,
    path: [*:0]const u8,
    flags: u32,
) void {
    io_uring_prep_rw(.UNLINKAT, sqe, dir_fd, @ptrToInt(path), 0, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_mkdirat(
    sqe: *linux.io_uring_sqe,
    dir_fd: os.fd_t,
    path: [*:0]const u8,
    mode: os.mode_t,
) void {
    io_uring_prep_rw(.MKDIRAT, sqe, dir_fd, @ptrToInt(path), mode, 0);
}

pub fn io_uring_prep_symlinkat(
    sqe: *linux.io_uring_sqe,
    target: [*:0]const u8,
    new_dir_fd: os.fd_t,
    link_path: [*:0]const u8,
) void {
    io_uring_prep_rw(
        .SYMLINKAT,
        sqe,
        new_dir_fd,
        @ptrToInt(target),
        0,
        @ptrToInt(link_path),
    );
}

pub fn io_uring_prep_linkat(
    sqe: *linux.io_uring_sqe,
    old_dir_fd: os.fd_t,
    old_path: [*:0]const u8,
    new_dir_fd: os.fd_t,
    new_path: [*:0]const u8,
    flags: u32,
) void {
    io_uring_prep_rw(
        .LINKAT,
        sqe,
        old_dir_fd,
        @ptrToInt(old_path),
        0,
        @ptrToInt(new_path),
    );
    sqe.len = @bitCast(u32, new_dir_fd);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_getxattr(sqe: *linux.io_uring_sqe, name: [*:0]const u8, path: [*:0]const u8, value: []u8) void {
    io_uring_prep_rw(.GETXATTR, sqe, 0, @ptrToInt(name), value.len, @ptrToInt(value.ptr));
    sqe.addr3 = @ptrToInt(path);
}

pub fn io_uring_prep_setxattr(
    sqe: *linux.io_uring_sqe,
    name: [*:0]const u8,
    path: [*:0]const u8,
    value: []const u8,
    flags: u32,
) void {
    io_uring_prep_rw(.SETXATTR, sqe, 0, @ptrToInt(name), value.len, @ptrToInt(value.ptr));
    sqe.addr3 = @ptrToInt(path);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_fgetxattr(sqe: *linux.io_uring_sqe, fd: os.fd_t, name: [*:0]const u8, value: []u8) void {
    io_uring_prep_rw(.FGETXATTR, sqe, fd, @ptrToInt(name), value.len, @ptrToInt(value.ptr));
}

pub fn io_uring_prep_fsetxattr(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    name: [*:0]const u8,
    value: []const u8,
    flags: u32,
) void {
    io_uring_prep_rw(.FSETXATTR, sqe, fd, @ptrToInt(name), value.len, @ptrToInt(value.ptr));
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_msg_ring(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    len: u32,
    data: u64,
    flags: u32,
) void {
    io_uring_prep_rw(.MSG_RING, sqe, fd, 0, len, data);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_socket(
    sqe: *linux.io_uring_sqe,
    domain: u32,
    socket_type: u32,
    protocol: u32,
    flags: u32,
) void {
    io_uring_prep_rw(.SOCKET, sqe, @bitCast(i32, domain), 0, protocol, socket_type);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_provide_buffers(
    sqe: *linux.io_uring_sqe,
    buffers: [*]u8,
    num: usize,
    buffer_len: usize,
    group_id: usize,
    buffer_id: usize,
) void {
    const ptr = @ptrToInt(buffers);
    io_uring_prep_rw(.PROVIDE_BUFFERS, sqe, @intCast(i32, num), ptr, buffer_len, buffer_id);
    sqe.buf_index = @intCast(u16, group_id);
}

pub fn io_uring_prep_remove_buffers(
    sqe: *linux.io_uring_sqe,
    num: usize,
    group_id: usize,
) void {
    io_uring_prep_rw(.REMOVE_BUFFERS, sqe, @intCast(i32, num), 0, 0, 0);
    sqe.buf_index = @intCast(u16, group_id);
}

pub fn __io_uring_set_target_fixed_file(
    sqe: *linux.io_uring_sqe,
    file_index: u32,
) void {
    sqe.splice_fd_in = @bitCast(i32, file_index);
}

fn testEnsureOpSupport(ring: *IO_Uring, comptime required_ops: []const linux.IORING_OP) !void {
    var probe_store = ProbeStore{};
    ring.register_probe(&probe_store.probe, ProbeStore.store_length) catch |err| switch (err) {
        // Skip test if probing isn't supported (any opcode introduced before won't be supported)
        error.NotSupported => return error.SkipZigTest,
        else => return err,
    };
    inline for (required_ops) |op| {
        // Probing API was introduced in 5.6, so you shouldn't probe for anything prior to that
        // You'll have to add explicit checks for EINVAL in cqes.
        const first_supported = linux.IORING_OP.FALLOCATE;
        if (@enumToInt(op) < @enumToInt(first_supported))
            @compileError("Probing for a opcode too old");
        if (!probe_store.supported(op))
            return error.SkipZigTest;
    }
}

test "structs/offsets/entries" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    try testing.expectEqual(@as(usize, 120), @sizeOf(linux.io_uring_params));
    try testing.expectEqual(@as(usize, 64), @sizeOf(linux.io_uring_sqe));
    try testing.expectEqual(@as(usize, 16), @sizeOf(linux.io_uring_cqe));

    try testing.expectEqual(0, linux.IORING_OFF_SQ_RING);
    try testing.expectEqual(0x8000000, linux.IORING_OFF_CQ_RING);
    try testing.expectEqual(0x10000000, linux.IORING_OFF_SQES);

    try testing.expectError(error.EntriesZero, IO_Uring.init(0, 0));
    try testing.expectError(error.EntriesNotPowerOfTwo, IO_Uring.init(3, 0));
}

test "nop" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer {
        ring.deinit();
        testing.expectEqual(@as(os.fd_t, -1), ring.fd) catch @panic("test failed");
    }

    const sqe = try ring.nop(0xaaaaaaaa);
    try testing.expectEqual(linux.io_uring_sqe{
        .opcode = .NOP,
        .flags = 0,
        .ioprio = 0,
        .fd = 0,
        .off = 0,
        .addr = 0,
        .len = 0,
        .rw_flags = 0,
        .user_data = 0xaaaaaaaa,
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    }, sqe.*);

    try testing.expectEqual(@as(u32, 0), ring.sq.sqe_head);
    try testing.expectEqual(@as(u32, 1), ring.sq.sqe_tail);
    try testing.expectEqual(@as(u32, 0), ring.sq.tail.*);
    try testing.expectEqual(@as(u32, 0), ring.cq.head.*);
    try testing.expectEqual(@as(u32, 1), ring.sq_ready());
    try testing.expectEqual(@as(u32, 0), ring.cq_ready());

    try testing.expectEqual(@as(u32, 1), try ring.submit());
    try testing.expectEqual(@as(u32, 1), ring.sq.sqe_head);
    try testing.expectEqual(@as(u32, 1), ring.sq.sqe_tail);
    try testing.expectEqual(@as(u32, 1), ring.sq.tail.*);
    try testing.expectEqual(@as(u32, 0), ring.cq.head.*);
    try testing.expectEqual(@as(u32, 0), ring.sq_ready());

    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xaaaaaaaa,
        .res = 0,
        .flags = 0,
    }, try ring.copy_cqe());
    try testing.expectEqual(@as(u32, 1), ring.cq.head.*);
    try testing.expectEqual(@as(u32, 0), ring.cq_ready());

    const sqe_barrier = try ring.nop(0xbbbbbbbb);
    sqe_barrier.flags |= linux.IOSQE_IO_DRAIN;
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xbbbbbbbb,
        .res = 0,
        .flags = 0,
    }, try ring.copy_cqe());
    try testing.expectEqual(@as(u32, 2), ring.sq.sqe_head);
    try testing.expectEqual(@as(u32, 2), ring.sq.sqe_tail);
    try testing.expectEqual(@as(u32, 2), ring.sq.tail.*);
    try testing.expectEqual(@as(u32, 2), ring.cq.head.*);
}

test "readv" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try os.openZ("/dev/zero", os.O.RDONLY | os.O.CLOEXEC, 0);
    defer os.close(fd);

    // Linux Kernel 5.4 supports IORING_REGISTER_FILES but not sparse fd sets (i.e. an fd of -1).
    // Linux Kernel 5.5 adds support for sparse fd sets.
    // Compare:
    // https://github.com/torvalds/linux/blob/v5.4/fs/io_uring.c#L3119-L3124 vs
    // https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L6687-L6691
    // We therefore avoid stressing sparse fd sets here:
    var registered_fds = [_]os.fd_t{0} ** 1;
    const fd_index = 0;
    registered_fds[fd_index] = fd;
    try ring.register_files(registered_fds[0..]);

    var buffer = [_]u8{42} ** 128;
    var iovecs = [_]os.iovec{os.iovec{ .iov_base = &buffer, .iov_len = buffer.len }};
    const sqe = try ring.read(0xcccccccc, fd_index, .{ .iovecs = iovecs[0..] }, 0);
    try testing.expectEqual(linux.IORING_OP.READV, sqe.opcode);
    sqe.flags |= linux.IOSQE_FIXED_FILE;

    try testing.expectError(error.SubmissionQueueFull, ring.nop(0));
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xcccccccc,
        .res = buffer.len,
        .flags = 0,
    }, try ring.copy_cqe());
    try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer.len), buffer[0..]);
}

test "writev/fsync/readv" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(4, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const path = "test_io_uring_writev_fsync_readv";
    const file = try std.fs.cwd().createFile(path, .{ .read = true, .truncate = true });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};
    const fd = file.handle;

    const buffer_write = [_]u8{42} ** 128;
    const iovecs_write = [_]os.iovec_const{
        os.iovec_const{ .iov_base = &buffer_write, .iov_len = buffer_write.len },
    };
    var buffer_read = [_]u8{0} ** 128;
    var iovecs_read = [_]os.iovec{
        os.iovec{ .iov_base = &buffer_read, .iov_len = buffer_read.len },
    };

    const sqe_writev = try ring.writev(0xdddddddd, fd, iovecs_write[0..], 17, 0);
    try testing.expectEqual(linux.IORING_OP.WRITEV, sqe_writev.opcode);
    try testing.expectEqual(@as(u64, 17), sqe_writev.off);
    sqe_writev.flags |= linux.IOSQE_IO_LINK;

    const sqe_fsync = try ring.fsync(0xeeeeeeee, fd, 0);
    try testing.expectEqual(linux.IORING_OP.FSYNC, sqe_fsync.opcode);
    try testing.expectEqual(fd, sqe_fsync.fd);
    sqe_fsync.flags |= linux.IOSQE_IO_LINK;

    const sqe_readv = try ring.read(0xffffffff, fd, .{ .iovecs = iovecs_read[0..] }, 17);
    try testing.expectEqual(linux.IORING_OP.READV, sqe_readv.opcode);
    try testing.expectEqual(@as(u64, 17), sqe_readv.off);

    try testing.expectEqual(@as(u32, 3), ring.sq_ready());
    try testing.expectEqual(@as(u32, 3), try ring.submit_and_wait(3));
    try testing.expectEqual(@as(u32, 0), ring.sq_ready());
    try testing.expectEqual(@as(u32, 3), ring.cq_ready());

    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xdddddddd,
        .res = buffer_write.len,
        .flags = 0,
    }, try ring.copy_cqe());
    try testing.expectEqual(@as(u32, 2), ring.cq_ready());

    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xeeeeeeee,
        .res = 0,
        .flags = 0,
    }, try ring.copy_cqe());
    try testing.expectEqual(@as(u32, 1), ring.cq_ready());

    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xffffffff,
        .res = buffer_read.len,
        .flags = 0,
    }, try ring.copy_cqe());
    try testing.expectEqual(@as(u32, 0), ring.cq_ready());

    try testing.expectEqualSlices(u8, buffer_write[0..], buffer_read[0..]);
}

test "write/read" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(2, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .WRITE, .READ });

    const path = "test_io_uring_write_read";
    const file = try std.fs.cwd().createFile(path, .{ .read = true, .truncate = true });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};
    const fd = file.handle;

    const buffer_write = [_]u8{97} ** 20;
    var buffer_read = [_]u8{98} ** 20;
    const sqe_write = try ring.write(0x11111111, fd, buffer_write[0..], 10);
    try testing.expectEqual(linux.IORING_OP.WRITE, sqe_write.opcode);
    try testing.expectEqual(@as(u64, 10), sqe_write.off);
    sqe_write.flags |= linux.IOSQE_IO_LINK;
    const sqe_read = try ring.read(0x22222222, fd, .{ .buffer = buffer_read[0..] }, 10);
    try testing.expectEqual(linux.IORING_OP.READ, sqe_read.opcode);
    try testing.expectEqual(@as(u64, 10), sqe_read.off);
    try testing.expectEqual(@as(u32, 2), try ring.submit());

    const cqe_write = try ring.copy_cqe();
    const cqe_read = try ring.copy_cqe();
    // Prior to Linux Kernel 5.6 this is the only way to test for read/write support:
    // https://lwn.net/Articles/809820/
    if (cqe_write.err() == .INVAL) return error.SkipZigTest;
    if (cqe_read.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x11111111,
        .res = buffer_write.len,
        .flags = 0,
    }, cqe_write);
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x22222222,
        .res = buffer_read.len,
        .flags = 0,
    }, cqe_read);
    try testing.expectEqualSlices(u8, buffer_write[0..], buffer_read[0..]);
}

test "write_fixed/read_fixed" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(2, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const path = "test_io_uring_write_read_fixed";
    const file = try std.fs.cwd().createFile(path, .{ .read = true, .truncate = true });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};
    const fd = file.handle;

    var raw_buffers: [2][11]u8 = undefined;
    // First buffer will be written to the file.
    std.mem.set(u8, &raw_buffers[0], 'z');
    std.mem.copy(u8, &raw_buffers[0], "foobar");

    var buffers = [2]os.iovec{
        .{ .iov_base = &raw_buffers[0], .iov_len = raw_buffers[0].len },
        .{ .iov_base = &raw_buffers[1], .iov_len = raw_buffers[1].len },
    };
    try ring.register_buffers(&buffers);

    const sqe_write = try ring.write_fixed(0x45454545, fd, &buffers[0], 3, 0);
    try testing.expectEqual(linux.IORING_OP.WRITE_FIXED, sqe_write.opcode);
    try testing.expectEqual(@as(u64, 3), sqe_write.off);
    sqe_write.flags |= linux.IOSQE_IO_LINK;

    const sqe_read = try ring.read_fixed(0x12121212, fd, &buffers[1], 0, 1);
    try testing.expectEqual(linux.IORING_OP.READ_FIXED, sqe_read.opcode);
    try testing.expectEqual(@as(u64, 0), sqe_read.off);

    try testing.expectEqual(@as(u32, 2), try ring.submit());

    const cqe_write = try ring.copy_cqe();
    const cqe_read = try ring.copy_cqe();

    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x45454545,
        .res = @intCast(i32, buffers[0].iov_len),
        .flags = 0,
    }, cqe_write);
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x12121212,
        .res = @intCast(i32, buffers[1].iov_len),
        .flags = 0,
    }, cqe_read);

    try testing.expectEqualSlices(u8, "\x00\x00\x00", buffers[1].iov_base[0..3]);
    try testing.expectEqualSlices(u8, "foobar", buffers[1].iov_base[3..9]);
    try testing.expectEqualSlices(u8, "zz", buffers[1].iov_base[9..11]);
}

test "openat" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.OPENAT});

    const path = "test_io_uring_openat";
    defer std.fs.cwd().deleteFile(path) catch {};

    // Workaround for LLVM bug: https://github.com/ziglang/zig/issues/12014
    const path_addr = if (builtin.zig_backend == .stage2_llvm) p: {
        var workaround = path;
        break :p @ptrToInt(workaround);
    } else @ptrToInt(path);

    const flags: u32 = os.O.CLOEXEC | os.O.RDWR | os.O.CREAT;
    const mode: os.mode_t = 0o666;
    const sqe_openat = try ring.openat(0x33333333, linux.AT.FDCWD, path, flags, mode, null);
    try testing.expectEqual(linux.io_uring_sqe{
        .opcode = .OPENAT,
        .flags = 0,
        .ioprio = 0,
        .fd = linux.AT.FDCWD,
        .off = 0,
        .addr = path_addr,
        .len = mode,
        .rw_flags = flags,
        .user_data = 0x33333333,
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    }, sqe_openat.*);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe_openat = try ring.copy_cqe();
    try testing.expectEqual(@as(u64, 0x33333333), cqe_openat.user_data);
    if (cqe_openat.err() == .INVAL) return error.SkipZigTest;
    // AT.FDCWD is not fully supported before kernel 5.6:
    // See https://lore.kernel.org/io-uring/20200207155039.12819-1-axboe@kernel.dk/T/
    // We use IORING_FEAT_RW_CUR_POS to know if we are pre-5.6 since that feature was added in 5.6.
    if (cqe_openat.err() == .BADF and (ring.features & linux.IORING_FEAT_RW_CUR_POS) == 0) {
        return error.SkipZigTest;
    }
    if (cqe_openat.res <= 0) std.debug.print("\ncqe_openat.res={}\n", .{cqe_openat.res});
    try testing.expect(cqe_openat.res > 0);
    try testing.expectEqual(@as(u32, 0), cqe_openat.flags);

    os.close(cqe_openat.res);
}

test "close" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.CLOSE});

    const path = "test_io_uring_close";
    const file = try std.fs.cwd().createFile(path, .{});
    errdefer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};

    const sqe_close = try ring.close(0x44444444, file.handle, null);
    try testing.expectEqual(linux.IORING_OP.CLOSE, sqe_close.opcode);
    try testing.expectEqual(file.handle, sqe_close.fd);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe_close = try ring.copy_cqe();
    if (cqe_close.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x44444444,
        .res = 0,
        .flags = 0,
    }, cqe_close);
}

test "accept/connect/send/recv" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .SEND, .RECV });

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    const buffer_send = [_]u8{ 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 };
    var buffer_recv = [_]u8{ 0, 1, 0, 1, 0 };

    const send = try ring.send(0xeeeeeeee, socket_test_harness.client, buffer_send[0..], 0);
    send.flags |= linux.IOSQE_IO_LINK;
    _ = try ring.recv(0xffffffff, socket_test_harness.server, .{ .buffer = buffer_recv[0..] }, 0);
    try testing.expectEqual(@as(u32, 2), try ring.submit());

    const cqe_send = try ring.copy_cqe();
    if (cqe_send.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xeeeeeeee,
        .res = buffer_send.len,
        .flags = 0,
    }, cqe_send);

    const cqe_recv = try ring.copy_cqe();
    if (cqe_recv.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xffffffff,
        .res = buffer_recv.len,
        // ignore IORING_CQE_F_SOCK_NONEMPTY since it is only set on some systems
        .flags = cqe_recv.flags & linux.IORING_CQE_F_SOCK_NONEMPTY,
    }, cqe_recv);

    try testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);
}

fn testSendRecvMsg(comptime send_zc: bool) !void {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(2, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    if (send_zc) {
        try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .SENDMSG_ZC });
    }

    const address_server = try net.Address.parseIp4("127.0.0.1", 3131);

    const server = try os.socket(address_server.any.family, os.SOCK.DGRAM, 0);
    defer os.close(server);
    try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEPORT, &mem.toBytes(@as(c_int, 1)));
    try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
    try os.bind(server, &address_server.any, address_server.getOsSockLen());

    const client = try os.socket(address_server.any.family, os.SOCK.DGRAM, 0);
    defer os.close(client);

    const buffer_send = [_]u8{42} ** 128;
    const iovecs_send = [_]os.iovec_const{
        os.iovec_const{ .iov_base = &buffer_send, .iov_len = buffer_send.len },
    };
    const msg_send = os.msghdr_const{
        .name = &address_server.any,
        .namelen = address_server.getOsSockLen(),
        .iov = &iovecs_send,
        .iovlen = 1,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    const sqe_sendmsg = if (send_zc) try ring.sendmsg_zc(0x11111111, client, &msg_send, 0)
                        else try ring.sendmsg(0x11111111, client, &msg_send, 0);
    sqe_sendmsg.flags |= linux.IOSQE_IO_LINK;
    try testing.expectEqual(if (send_zc) linux.IORING_OP.SENDMSG_ZC else linux.IORING_OP.SENDMSG, sqe_sendmsg.opcode);
    try testing.expectEqual(client, sqe_sendmsg.fd);

    var buffer_recv = [_]u8{0} ** 128;
    var iovecs_recv = [_]os.iovec{
        os.iovec{ .iov_base = &buffer_recv, .iov_len = buffer_recv.len },
    };
    var addr = [_]u8{0} ** 4;
    var address_recv = net.Address.initIp4(addr, 0);
    var msg_recv: os.msghdr = os.msghdr{
        .name = &address_recv.any,
        .namelen = address_recv.getOsSockLen(),
        .iov = &iovecs_recv,
        .iovlen = 1,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    const sqe_recvmsg = try ring.recvmsg(0x22222222, server, &msg_recv, 0);
    try testing.expectEqual(linux.IORING_OP.RECVMSG, sqe_recvmsg.opcode);
    try testing.expectEqual(server, sqe_recvmsg.fd);

    try testing.expectEqual(@as(u32, 2), ring.sq_ready());
    try testing.expectEqual(@as(u32, 2), try ring.submit_and_wait(2));
    try testing.expectEqual(@as(u32, 0), ring.sq_ready());
    try testing.expectEqual(@as(u32, if (send_zc) 3 else 2), ring.cq_ready());

    const cqe_sendmsg = try ring.copy_cqe();
    if (cqe_sendmsg.res == -@as(i32, @enumToInt(linux.E.INVAL))) return error.SkipZigTest;
    if (cqe_sendmsg.res == -@as(i32, @enumToInt(linux.E.AFNOSUPPORT))) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x11111111,
        .res = buffer_send.len,
        .flags = if (send_zc) linux.IORING_CQE_F_MORE else 0,
    }, cqe_sendmsg);

    const cqe_recvmsg = try ring.copy_cqe();
    if (cqe_recvmsg.res == -@as(i32, @enumToInt(linux.E.INVAL))) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x22222222,
        .res = buffer_recv.len,
        // ignore IORING_CQE_F_SOCK_NONEMPTY since it is set non-deterministically
        .flags = cqe_recvmsg.flags & linux.IORING_CQE_F_SOCK_NONEMPTY,
    }, cqe_recvmsg);

    try testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);
}

test "sendmsg/recvmsg" {
    try testSendRecvMsg(false);
}

test "timeout (after a relative time)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const ms = 10;
    const margin = 5;
    const ts = os.linux.kernel_timespec{ .tv_sec = 0, .tv_nsec = ms * 1000000 };

    const started = std.time.milliTimestamp();
    const sqe = try ring.timeout(0x55555555, &ts, 0, 0);
    try testing.expectEqual(linux.IORING_OP.TIMEOUT, sqe.opcode);
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    const cqe = try ring.copy_cqe();
    const stopped = std.time.milliTimestamp();

    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x55555555,
        .res = -@as(i32, @enumToInt(linux.E.TIME)),
        .flags = 0,
    }, cqe);

    // Tests should not depend on timings: skip test if outside margin.
    if (!std.math.approxEqAbs(f64, ms, @intToFloat(f64, stopped - started), margin)) return error.SkipZigTest;
}

test "timeout (after a number of completions)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(2, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const ts = os.linux.kernel_timespec{ .tv_sec = 3, .tv_nsec = 0 };
    const count_completions: u64 = 1;
    const sqe_timeout = try ring.timeout(0x66666666, &ts, count_completions, 0);
    try testing.expectEqual(linux.IORING_OP.TIMEOUT, sqe_timeout.opcode);
    try testing.expectEqual(count_completions, sqe_timeout.off);
    _ = try ring.nop(0x77777777);
    try testing.expectEqual(@as(u32, 2), try ring.submit());

    const cqe_nop = try ring.copy_cqe();
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x77777777,
        .res = 0,
        .flags = 0,
    }, cqe_nop);

    const cqe_timeout = try ring.copy_cqe();
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x66666666,
        .res = 0,
        .flags = 0,
    }, cqe_timeout);
}

test "timeout_remove" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(2, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const ts = os.linux.kernel_timespec{ .tv_sec = 3, .tv_nsec = 0 };
    const sqe_timeout = try ring.timeout(0x88888888, &ts, 0, 0);
    try testing.expectEqual(linux.IORING_OP.TIMEOUT, sqe_timeout.opcode);
    try testing.expectEqual(@as(u64, 0x88888888), sqe_timeout.user_data);

    const sqe_timeout_remove = try ring.timeout_remove(0x99999999, 0x88888888, 0);
    try testing.expectEqual(linux.IORING_OP.TIMEOUT_REMOVE, sqe_timeout_remove.opcode);
    try testing.expectEqual(@as(u64, 0x88888888), sqe_timeout_remove.addr);
    try testing.expectEqual(@as(u64, 0x99999999), sqe_timeout_remove.user_data);

    try testing.expectEqual(@as(u32, 2), try ring.submit());

    // The order in which the CQE arrive is not clearly documented and it changed with kernel 5.18:
    // * kernel 5.10 gives user data 0x88888888 first, 0x99999999 second
    // * kernel 5.18 gives user data 0x99999999 first, 0x88888888 second

    var cqes: [2]os.linux.io_uring_cqe = undefined;
    const cqes_count = try ring.copy_cqes(cqes[0..], 2);
    if (cqes_count == 1)
        return error.SkipZigTest; // TIMEOUT_REMOVE probably unrecognised, happens on linux <=5.4
    try testing.expectEqual(@as(u32, 2), cqes_count);

    for (cqes) |cqe| {
        // IORING_OP_TIMEOUT_REMOVE is not supported by this kernel version:
        // Timeout remove operations set the fd to -1, which results in EBADF before EINVAL.
        // We use IORING_FEAT_RW_CUR_POS as a safety check here to make sure we are at least pre-5.6.
        // We don't want to skip this test for newer kernels.
        if (cqe.user_data == 0x99999999 and
            cqe.err() == .BADF and
            (ring.features & linux.IORING_FEAT_RW_CUR_POS) == 0)
        {
            return error.SkipZigTest;
        }
        if (cqe.err() == .INVAL)
            return error.SkipZigTest;

        try testing.expect(cqe.user_data == 0x88888888 or cqe.user_data == 0x99999999);

        if (cqe.user_data == 0x88888888) {
            try testing.expectEqual(linux.io_uring_cqe{
                .user_data = 0x88888888,
                .res = -@as(i32, @enumToInt(linux.E.CANCELED)),
                .flags = 0,
            }, cqe);
        } else if (cqe.user_data == 0x99999999) {
            try testing.expectEqual(linux.io_uring_cqe{
                .user_data = 0x99999999,
                .res = 0,
                .flags = 0,
            }, cqe);
        }
    }
}

test "accept/connect/recv/link_timeout" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.RECV});

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    var buffer_recv = [_]u8{ 0, 1, 0, 1, 0 };

    const sqe_recv = try ring.recv(0xffffffff, socket_test_harness.server, .{ .buffer = buffer_recv[0..] }, 0);
    sqe_recv.flags |= linux.IOSQE_IO_LINK;

    const ts = os.linux.kernel_timespec{ .tv_sec = 0, .tv_nsec = 1000000 };
    _ = try ring.link_timeout(0x22222222, &ts, 0);

    const nr_wait = try ring.submit();
    try testing.expectEqual(@as(u32, 2), nr_wait);

    var i: usize = 0;
    while (i < nr_wait) : (i += 1) {
        const cqe = try ring.copy_cqe();
        switch (cqe.user_data) {
            0xffffffff => {
                if (cqe.res != -@as(i32, @enumToInt(linux.E.INTR)) and
                    cqe.res != -@as(i32, @enumToInt(linux.E.CANCELED)))
                {
                    std.debug.print("Req 0x{x} got {d}\n", .{ cqe.user_data, cqe.res });
                    try testing.expect(false);
                }
            },
            0x22222222 => {
                if (cqe.res != -@as(i32, @enumToInt(linux.E.ALREADY)) and
                    cqe.res != -@as(i32, @enumToInt(linux.E.TIME)))
                {
                    std.debug.print("Req 0x{x} got {d}\n", .{ cqe.user_data, cqe.res });
                    try testing.expect(false);
                }
            },
            else => @panic("should not happen"),
        }
    }
}

test "fallocate" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.FALLOCATE});

    const path = "test_io_uring_fallocate";
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};

    try testing.expectEqual(@as(u64, 0), (try file.stat()).size);

    const len: u64 = 65536;
    const sqe = try ring.fallocate(0xaaaaaaaa, file.handle, 0, 0, len);
    try testing.expectEqual(linux.IORING_OP.FALLOCATE, sqe.opcode);
    try testing.expectEqual(file.handle, sqe.fd);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel does not implement fallocate():
        .NOSYS => return error.SkipZigTest,
        // The filesystem containing the file referred to by fd does not support this operation;
        // or the mode is not supported by the filesystem containing the file referred to by fd:
        .OPNOTSUPP => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xaaaaaaaa,
        .res = 0,
        .flags = 0,
    }, cqe);

    try testing.expectEqual(len, (try file.stat()).size);
}

test "statx" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.STATX});

    const path = "test_io_uring_statx";
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};

    try testing.expectEqual(@as(u64, 0), (try file.stat()).size);

    try file.writeAll("foobar");

    var buf: linux.Statx = undefined;
    const sqe = try ring.statx(
        0xaaaaaaaa,
        linux.AT.FDCWD,
        path,
        0,
        linux.STATX_SIZE,
        &buf,
    );
    try testing.expectEqual(linux.IORING_OP.STATX, sqe.opcode);
    try testing.expectEqual(@as(i32, linux.AT.FDCWD), sqe.fd);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel does not implement statx():
        .NOSYS => return error.SkipZigTest,
        // The filesystem containing the file referred to by fd does not support this operation;
        // or the mode is not supported by the filesystem containing the file referred to by fd:
        .OPNOTSUPP => return error.SkipZigTest,
        // The kernel is too old to support FDCWD for dir_fd
        .BADF => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xaaaaaaaa,
        .res = 0,
        .flags = 0,
    }, cqe);

    try testing.expect(buf.mask & os.linux.STATX_SIZE == os.linux.STATX_SIZE);
    try testing.expectEqual(@as(u64, 6), buf.size);
}

test "accept/connect/recv/cancel" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.RECV});

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    var buffer_recv = [_]u8{ 0, 1, 0, 1, 0 };

    _ = try ring.recv(0xffffffff, socket_test_harness.server, .{ .buffer = buffer_recv[0..] }, 0);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const sqe_cancel = try ring.cancel(0x99999999, 0xffffffff, 0);
    try testing.expectEqual(linux.IORING_OP.ASYNC_CANCEL, sqe_cancel.opcode);
    try testing.expectEqual(@as(u64, 0xffffffff), sqe_cancel.addr);
    try testing.expectEqual(@as(u64, 0x99999999), sqe_cancel.user_data);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    var cqe_recv = try ring.copy_cqe();
    if (cqe_recv.err() == .INVAL) return error.SkipZigTest;
    var cqe_cancel = try ring.copy_cqe();
    if (cqe_cancel.err() == .INVAL) return error.SkipZigTest;

    // The recv/cancel CQEs may arrive in any order, the recv CQE will sometimes come first:
    if (cqe_recv.user_data == 0x99999999 and cqe_cancel.user_data == 0xffffffff) {
        const a = cqe_recv;
        const b = cqe_cancel;
        cqe_recv = b;
        cqe_cancel = a;
    }

    switch(cqe_recv.err()) {
        .INTR => {},
        .CANCELED => {},
        else => |err| return os.unexpectedErrno(err),
    }
    switch(cqe_cancel.err()) {
        .SUCCESS => {},
        .ALREADY => {},
        else => |err| return os.unexpectedErrno(err),
    }
}

test "register_files_update" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try os.openZ("/dev/zero", os.O.RDONLY | os.O.CLOEXEC, 0);
    defer os.close(fd);

    var registered_fds = [_]os.fd_t{0} ** 2;
    const fd_index = 0;
    const fd_index2 = 1;
    registered_fds[fd_index] = fd;
    registered_fds[fd_index2] = -1;

    ring.register_files(registered_fds[0..]) catch |err| switch (err) {
        // Happens when the kernel doesn't support sparse entry (-1) in the file descriptors array.
        error.FileDescriptorInvalid => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    };

    // Test IORING_REGISTER_FILES_UPDATE
    // Only available since Linux 5.5

    const fd2 = try os.openZ("/dev/zero", os.O.RDONLY | os.O.CLOEXEC, 0);
    defer os.close(fd2);

    registered_fds[fd_index] = fd2;
    registered_fds[fd_index2] = -1;
    ring.register_files_update(0, registered_fds[0..]) catch |err| switch (err) {
        error.NotSupported => return error.SkipZigTest,
        else => return err,
    };

    var buffer = [_]u8{42} ** 128;
    {
        const sqe = try ring.read(0xcccccccc, fd_index, .{ .buffer = &buffer }, 0);
        try testing.expectEqual(linux.IORING_OP.READ, sqe.opcode);
        sqe.flags |= linux.IOSQE_FIXED_FILE;

        try testing.expectEqual(@as(u32, 1), try ring.submit());
        const cqe = try ring.copy_cqe();
        if (cqe.res == -@as(i32, @enumToInt(linux.E.INVAL))) return error.SkipZigTest;
        try testing.expectEqual(linux.io_uring_cqe{
            .user_data = 0xcccccccc,
            .res = buffer.len,
            .flags = 0,
        }, cqe);
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer.len), buffer[0..]);
    }

    // Test with a non-zero offset

    registered_fds[fd_index] = -1;
    registered_fds[fd_index2] = -1;
    try ring.register_files_update(1, registered_fds[1..]);

    {
        // Next read should still work since fd_index in the registered file descriptors hasn't been updated yet.
        const sqe = try ring.read(0xcccccccc, fd_index, .{ .buffer = &buffer }, 0);
        try testing.expectEqual(linux.IORING_OP.READ, sqe.opcode);
        sqe.flags |= linux.IOSQE_FIXED_FILE;

        try testing.expectEqual(@as(u32, 1), try ring.submit());
        try testing.expectEqual(linux.io_uring_cqe{
            .user_data = 0xcccccccc,
            .res = buffer.len,
            .flags = 0,
        }, try ring.copy_cqe());
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer.len), buffer[0..]);
    }

    try ring.register_files_update(0, registered_fds[0..]);

    {
        // Now this should fail since both fds are sparse (-1)
        const sqe = try ring.read(0xcccccccc, fd_index, .{ .buffer = &buffer }, 0);
        try testing.expectEqual(linux.IORING_OP.READ, sqe.opcode);
        sqe.flags |= linux.IOSQE_FIXED_FILE;

        try testing.expectEqual(@as(u32, 1), try ring.submit());
        const cqe = try ring.copy_cqe();
        try testing.expectEqual(os.linux.E.BADF, cqe.err());
    }
}

test "unregister_files" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try os.openZ("/dev/zero", os.O.RDONLY, 0);
    defer os.close(fd);

    try std.testing.expectError(error.FilesNotRegistered, ring.unregister_files());
    try ring.register_files(&[_]os.fd_t{fd});

    // FIXME JBL: Next line takes up to 1min sometimes, possibly fixed in kernel 6.1
    try ring.unregister_files();
    try std.testing.expectError(error.FilesNotRegistered, ring.unregister_files());
}

test "shutdown" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.SHUTDOWN});

    const address = try net.Address.parseIp4("127.0.0.1", 3131);

    // Socket bound, expect shutdown to work
    {
        const server = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
        defer os.close(server);
        try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
        try os.bind(server, &address.any, address.getOsSockLen());
        try os.listen(server, 1);

        var shutdown_sqe = try ring.shutdown(0x445445445, server, os.linux.SHUT.RD);
        try testing.expectEqual(linux.IORING_OP.SHUTDOWN, shutdown_sqe.opcode);
        try testing.expectEqual(@as(i32, server), shutdown_sqe.fd);

        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            // This kernel's io_uring does not yet implement shutdown (kernel version < 5.11)
            .INVAL => return error.SkipZigTest,
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expectEqual(linux.io_uring_cqe{
            .user_data = 0x445445445,
            .res = 0,
            .flags = 0,
        }, cqe);
    }

    // Socket not bound, expect to fail with ENOTCONN
    {
        const server = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
        defer os.close(server);

        var shutdown_sqe = ring.shutdown(0x445445445, server, os.linux.SHUT.RD) catch |err| switch (err) {
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        };
        try testing.expectEqual(linux.IORING_OP.SHUTDOWN, shutdown_sqe.opcode);
        try testing.expectEqual(@as(i32, server), shutdown_sqe.fd);

        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        try testing.expectEqual(@as(u64, 0x445445445), cqe.user_data);
        try testing.expectEqual(os.linux.E.NOTCONN, cqe.err());
    }
}

test "renameat" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.RENAMEAT});

    const old_path = "test_io_uring_renameat_old";
    const new_path = "test_io_uring_renameat_new";

    // Write old file with data

    const old_file = try std.fs.cwd().createFile(old_path, .{ .truncate = true, .mode = 0o666 });
    defer {
        old_file.close();
        std.fs.cwd().deleteFile(new_path) catch {};
    }
    try old_file.writeAll("hello");

    // Submit renameat

    var sqe = try ring.renameat(
        0x12121212,
        linux.AT.FDCWD,
        old_path,
        linux.AT.FDCWD,
        new_path,
        0,
    );
    try testing.expectEqual(linux.IORING_OP.RENAMEAT, sqe.opcode);
    try testing.expectEqual(@as(i32, linux.AT.FDCWD), sqe.fd);
    try testing.expectEqual(@as(i32, linux.AT.FDCWD), @bitCast(i32, sqe.len));
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement renameat (kernel version < 5.11)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = 0,
    }, cqe);

    // Validate that the old file doesn't exist anymore
    {
        _ = std.fs.cwd().openFile(old_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {},
            else => std.debug.panic("unexpected error: {}", .{err}),
        };
    }

    // Validate that the new file exists with the proper content
    {
        const new_file = try std.fs.cwd().openFile(new_path, .{});
        defer new_file.close();

        var new_file_data: [16]u8 = undefined;
        const read = try new_file.readAll(&new_file_data);
        try testing.expectEqualStrings("hello", new_file_data[0..read]);
    }
}

test "unlinkat" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.UNLINKAT});

    const path = "test_io_uring_unlinkat";

    // Write old file with data

    const file = try std.fs.cwd().createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};

    // Submit unlinkat

    var sqe = try ring.unlinkat(
        0x12121212,
        linux.AT.FDCWD,
        path,
        0,
    );
    try testing.expectEqual(linux.IORING_OP.UNLINKAT, sqe.opcode);
    try testing.expectEqual(@as(i32, linux.AT.FDCWD), sqe.fd);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement unlinkat (kernel version < 5.11)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = 0,
    }, cqe);

    // Validate that the file doesn't exist anymore
    _ = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {},
        else => std.debug.panic("unexpected error: {}", .{err}),
    };
}

test "mkdirat" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.MKDIRAT});

    const path = "test_io_uring_mkdirat";

    defer std.fs.cwd().deleteDir(path) catch {};

    // Submit mkdirat

    var sqe = try ring.mkdirat(
        0x12121212,
        linux.AT.FDCWD,
        path,
        0o0755,
    );
    try testing.expectEqual(linux.IORING_OP.MKDIRAT, sqe.opcode);
    try testing.expectEqual(@as(i32, linux.AT.FDCWD), sqe.fd);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement mkdirat (kernel version < 5.15)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = 0,
    }, cqe);

    // Validate that the directory exist
    _ = try std.fs.cwd().openDir(path, .{});
}

test "symlinkat" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.SYMLINKAT});

    const path = "test_io_uring_symlinkat";
    const link_path = "test_io_uring_symlinkat_link";

    const file = try std.fs.cwd().createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer {
        file.close();
        std.fs.cwd().deleteFile(path) catch {};
        std.fs.cwd().deleteFile(link_path) catch {};
    }

    // Submit symlinkat

    var sqe = try ring.symlinkat(
        0x12121212,
        path,
        linux.AT.FDCWD,
        link_path,
    );
    try testing.expectEqual(linux.IORING_OP.SYMLINKAT, sqe.opcode);
    try testing.expectEqual(@as(i32, linux.AT.FDCWD), sqe.fd);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement symlinkat (kernel version < 5.15)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = 0,
    }, cqe);

    // Validate that the symlink exist
    _ = try std.fs.cwd().openFile(link_path, .{});
}

test "linkat" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.LINKAT});

    const first_path = "test_io_uring_linkat_first";
    const second_path = "test_io_uring_linkat_second";

    // Write file with data

    const first_file = try std.fs.cwd().createFile(first_path, .{ .truncate = true, .mode = 0o666 });
    defer {
        first_file.close();
        std.fs.cwd().deleteFile(first_path) catch {};
        std.fs.cwd().deleteFile(second_path) catch {};
    }
    try first_file.writeAll("hello");

    // Submit linkat

    var sqe = try ring.linkat(
        0x12121212,
        linux.AT.FDCWD,
        first_path,
        linux.AT.FDCWD,
        second_path,
        0,
    );
    try testing.expectEqual(linux.IORING_OP.LINKAT, sqe.opcode);
    try testing.expectEqual(@as(i32, linux.AT.FDCWD), sqe.fd);
    try testing.expectEqual(@as(i32, linux.AT.FDCWD), @bitCast(i32, sqe.len));
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement linkat (kernel version < 5.15)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = 0,
    }, cqe);

    // Validate the second file
    const second_file = try std.fs.cwd().openFile(second_path, .{});
    defer second_file.close();

    var second_file_data: [16]u8 = undefined;
    const read = try second_file.readAll(&second_file_data);
    try testing.expectEqualStrings("hello", second_file_data[0..read]);
}

test "provide_buffers: read" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.PROVIDE_BUFFERS});

    const fd = try os.openZ("/dev/zero", os.O.RDONLY | os.O.CLOEXEC, 0);
    defer os.close(fd);

    const group_id = 1337;
    const buffer_id = 0;

    const buffer_len = 128;

    var buffers: [4][buffer_len]u8 = undefined;

    // Provide 4 buffers

    {
        const sqe = try ring.provide_buffers(0xcccccccc, @ptrCast([*]u8, &buffers), buffers.len, buffer_len, group_id, buffer_id);
        try testing.expectEqual(linux.IORING_OP.PROVIDE_BUFFERS, sqe.opcode);
        try testing.expectEqual(@as(i32, buffers.len), sqe.fd);
        try testing.expectEqual(@as(u32, buffers[0].len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Happens when the kernel is < 5.7
            .INVAL => return error.SkipZigTest,
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(@as(u64, 0xcccccccc), cqe.user_data);
    }

    // Do 4 reads which should consume all buffers

    var i: usize = 0;
    while (i < buffers.len) : (i += 1) {
        var sqe = try ring.read(0xdededede, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(linux.IORING_OP.READ, sqe.opcode);
        try testing.expectEqual(@as(i32, fd), sqe.fd);
        try testing.expectEqual(@as(u64, 0), sqe.addr);
        try testing.expectEqual(@as(u32, buffer_len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags & linux.IORING_CQE_F_BUFFER == linux.IORING_CQE_F_BUFFER);
        const used_buffer_id = cqe.flags >> 16;
        try testing.expect(used_buffer_id >= 0 and used_buffer_id <= 3);
        try testing.expectEqual(@as(i32, buffer_len), cqe.res);

        try testing.expectEqual(@as(u64, 0xdededede), cqe.user_data);
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer_len), buffers[used_buffer_id][0..@intCast(usize, cqe.res)]);
    }

    // This read should fail

    {
        var sqe = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(linux.IORING_OP.READ, sqe.opcode);
        try testing.expectEqual(@as(i32, fd), sqe.fd);
        try testing.expectEqual(@as(u64, 0), sqe.addr);
        try testing.expectEqual(@as(u32, buffer_len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Expected
            .NOBUFS => {},
            .SUCCESS => std.debug.panic("unexpected success", .{}),
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(@as(u64, 0xdfdfdfdf), cqe.user_data);
    }

    // Provide 1 buffer again

    // Deliberately put something we don't expect in the buffers
    mem.set(u8, mem.sliceAsBytes(&buffers), 42);

    const reprovided_buffer_id = 2;

    {
        _ = try ring.provide_buffers(0xabababab, @ptrCast([*]u8, &buffers[reprovided_buffer_id]), 1, buffer_len, group_id, reprovided_buffer_id);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
    }

    // Final read which should work

    {
        var sqe = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(linux.IORING_OP.READ, sqe.opcode);
        try testing.expectEqual(@as(i32, fd), sqe.fd);
        try testing.expectEqual(@as(u64, 0), sqe.addr);
        try testing.expectEqual(@as(u32, buffer_len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags & linux.IORING_CQE_F_BUFFER == linux.IORING_CQE_F_BUFFER);
        const used_buffer_id = cqe.flags >> 16;
        try testing.expectEqual(used_buffer_id, reprovided_buffer_id);
        try testing.expectEqual(@as(i32, buffer_len), cqe.res);
        try testing.expectEqual(@as(u64, 0xdfdfdfdf), cqe.user_data);
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer_len), buffers[used_buffer_id][0..@intCast(usize, cqe.res)]);
    }
}

test "remove_buffers" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .PROVIDE_BUFFERS, .REMOVE_BUFFERS });

    const fd = try os.openZ("/dev/zero", os.O.RDONLY | os.O.CLOEXEC, 0);
    defer os.close(fd);

    const group_id = 1337;
    const buffer_id = 0;

    const buffer_len = 128;

    var buffers: [4][buffer_len]u8 = undefined;

    // Provide 4 buffers

    {
        _ = try ring.provide_buffers(0xcccccccc, @ptrCast([*]u8, &buffers), buffers.len, buffer_len, group_id, buffer_id);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(@as(u64, 0xcccccccc), cqe.user_data);
    }

    // Remove 3 buffers

    {
        var sqe = try ring.remove_buffers(0xbababababa, 3, group_id);
        try testing.expectEqual(linux.IORING_OP.REMOVE_BUFFERS, sqe.opcode);
        try testing.expectEqual(@as(i32, 3), sqe.fd);
        try testing.expectEqual(@as(u64, 0), sqe.addr);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(@as(u64, 0xbababababa), cqe.user_data);
    }

    // This read should work

    {
        _ = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags & linux.IORING_CQE_F_BUFFER == linux.IORING_CQE_F_BUFFER);
        const used_buffer_id = cqe.flags >> 16;
        try testing.expect(used_buffer_id >= 0 and used_buffer_id < 4);
        try testing.expectEqual(@as(i32, buffer_len), cqe.res);
        try testing.expectEqual(@as(u64, 0xdfdfdfdf), cqe.user_data);
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer_len), buffers[used_buffer_id][0..@intCast(usize, cqe.res)]);
    }

    // Final read should _not_ work

    {
        _ = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Expected
            .NOBUFS => {},
            .SUCCESS => std.debug.panic("unexpected success", .{}),
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
    }
}

test "provide_buffers: accept/connect/send/recv" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .PROVIDE_BUFFERS, .SEND, .RECV });

    const group_id = 1337;
    const buffer_id = 0;

    const buffer_len = 128;
    var buffers: [4][buffer_len]u8 = undefined;

    // Provide 4 buffers

    {
        const sqe = try ring.provide_buffers(0xcccccccc, @ptrCast([*]u8, &buffers), buffers.len, buffer_len, group_id, buffer_id);
        try testing.expectEqual(linux.IORING_OP.PROVIDE_BUFFERS, sqe.opcode);
        try testing.expectEqual(@as(i32, buffers.len), sqe.fd);
        try testing.expectEqual(@as(u32, buffer_len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Happens when the kernel is < 5.7
            .INVAL => return error.SkipZigTest,
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(@as(u64, 0xcccccccc), cqe.user_data);
    }

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    // Do 4 send on the socket

    {
        var i: usize = 0;
        while (i < buffers.len) : (i += 1) {
            _ = try ring.send(0xdeaddead, socket_test_harness.server, &([_]u8{'z'} ** buffer_len), 0);
            try testing.expectEqual(@as(u32, 1), try ring.submit());
        }

        var cqes: [4]linux.io_uring_cqe = undefined;
        try testing.expectEqual(@as(u32, 4), try ring.copy_cqes(&cqes, 4));
    }

    // Do 4 recv which should consume all buffers

    // Deliberately put something we don't expect in the buffers
    mem.set(u8, mem.sliceAsBytes(&buffers), 1);

    var i: usize = 0;
    while (i < buffers.len) : (i += 1) {
        var sqe = try ring.recv(0xdededede, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(linux.IORING_OP.RECV, sqe.opcode);
        try testing.expectEqual(@as(i32, socket_test_harness.client), sqe.fd);
        try testing.expectEqual(@as(u64, 0), sqe.addr);
        try testing.expectEqual(@as(u32, buffer_len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 0), sqe.rw_flags);
        try testing.expectEqual(@as(u32, linux.IOSQE_BUFFER_SELECT), sqe.flags);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags & linux.IORING_CQE_F_BUFFER == linux.IORING_CQE_F_BUFFER);
        const used_buffer_id = cqe.flags >> 16;
        try testing.expect(used_buffer_id >= 0 and used_buffer_id <= 3);
        try testing.expectEqual(@as(i32, buffer_len), cqe.res);

        try testing.expectEqual(@as(u64, 0xdededede), cqe.user_data);
        const buffer = buffers[used_buffer_id][0..@intCast(usize, cqe.res)];
        try testing.expectEqualSlices(u8, &([_]u8{'z'} ** buffer_len), buffer);
    }

    // This recv should fail

    {
        var sqe = try ring.recv(0xdfdfdfdf, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(linux.IORING_OP.RECV, sqe.opcode);
        try testing.expectEqual(@as(i32, socket_test_harness.client), sqe.fd);
        try testing.expectEqual(@as(u64, 0), sqe.addr);
        try testing.expectEqual(@as(u32, buffer_len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 0), sqe.rw_flags);
        try testing.expectEqual(@as(u32, linux.IOSQE_BUFFER_SELECT), sqe.flags);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Expected
            .NOBUFS => {},
            .SUCCESS => std.debug.panic("unexpected success", .{}),
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(@as(u64, 0xdfdfdfdf), cqe.user_data);
    }

    // Provide 1 buffer again

    const reprovided_buffer_id = 2;

    {
        _ = try ring.provide_buffers(0xabababab, @ptrCast([*]u8, &buffers[reprovided_buffer_id]), 1, buffer_len, group_id, reprovided_buffer_id);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
    }

    // Redo 1 send on the server socket

    {
        _ = try ring.send(0xdeaddead, socket_test_harness.server, &([_]u8{'w'} ** buffer_len), 0);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        _ = try ring.copy_cqe();
    }

    // Final recv which should work

    // Deliberately put something we don't expect in the buffers
    mem.set(u8, mem.sliceAsBytes(&buffers), 1);

    {
        var sqe = try ring.recv(0xdfdfdfdf, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(linux.IORING_OP.RECV, sqe.opcode);
        try testing.expectEqual(@as(i32, socket_test_harness.client), sqe.fd);
        try testing.expectEqual(@as(u64, 0), sqe.addr);
        try testing.expectEqual(@as(u32, buffer_len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 0), sqe.rw_flags);
        try testing.expectEqual(@as(u32, linux.IOSQE_BUFFER_SELECT), sqe.flags);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags & linux.IORING_CQE_F_BUFFER == linux.IORING_CQE_F_BUFFER);
        const used_buffer_id = cqe.flags >> 16;
        try testing.expectEqual(used_buffer_id, reprovided_buffer_id);
        try testing.expectEqual(@as(i32, buffer_len), cqe.res);
        try testing.expectEqual(@as(u64, 0xdfdfdfdf), cqe.user_data);
        const buffer = buffers[used_buffer_id][0..@intCast(usize, cqe.res)];
        try testing.expectEqualSlices(u8, &([_]u8{'w'} ** buffer_len), buffer);
    }
}

/// Used for testing server/client interactions.
const SocketTestHarness = struct {
    listener: os.socket_t,
    server: os.socket_t,
    client: os.socket_t,

    fn close(self: SocketTestHarness) void {
        os.closeSocket(self.client);
        os.closeSocket(self.listener);
    }
};

fn createSocketTestHarness(ring: *IO_Uring) !SocketTestHarness {
    // Create a TCP server socket

    const address = try net.Address.parseIp4("127.0.0.1", 3131);
    const kernel_backlog = 1;
    const listener_socket = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
    errdefer os.closeSocket(listener_socket);

    try os.setsockopt(listener_socket, os.SOL.SOCKET, os.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
    try os.bind(listener_socket, &address.any, address.getOsSockLen());
    try os.listen(listener_socket, kernel_backlog);

    // Submit 1 accept
    var accept_addr: os.sockaddr = undefined;
    var accept_addr_len: os.socklen_t = @sizeOf(@TypeOf(accept_addr));
    _ = try ring.accept(0xaaaaaaaa, listener_socket, &accept_addr, &accept_addr_len, 0, null);

    // Create a TCP client socket
    const client = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
    errdefer os.closeSocket(client);
    _ = try ring.connect(0xcccccccc, client, &address.any, address.getOsSockLen());

    try testing.expectEqual(@as(u32, 2), try ring.submit());

    var cqe_accept = try ring.copy_cqe();
    if (cqe_accept.err() == .INVAL) return error.SkipZigTest;
    var cqe_connect = try ring.copy_cqe();
    if (cqe_connect.err() == .INVAL) return error.SkipZigTest;

    // The accept/connect CQEs may arrive in any order, the connect CQE will sometimes come first:
    if (cqe_accept.user_data == 0xcccccccc and cqe_connect.user_data == 0xaaaaaaaa) {
        const a = cqe_accept;
        const b = cqe_connect;
        cqe_accept = b;
        cqe_connect = a;
    }

    try testing.expectEqual(@as(u64, 0xaaaaaaaa), cqe_accept.user_data);
    if (cqe_accept.res <= 0) std.debug.print("\ncqe_accept.res={}\n", .{cqe_accept.res});
    try testing.expect(cqe_accept.res > 0);
    try testing.expectEqual(@as(u32, 0), cqe_accept.flags);
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xcccccccc,
        .res = 0,
        .flags = 0,
    }, cqe_connect);

    // All good

    return SocketTestHarness{
        .listener = listener_socket,
        .server = cqe_accept.res,
        .client = client,
    };
}

fn ensureOpSupported(comptime size: u32, store: *const ProbeStore, op: linux.IORING_OP) !void {
    const op_int = @enumToInt(op);
    if (size > op_int)
        try std.testing.expect(store.supported(op));
}

fn verifyProbe(comptime size: u32, store: *const ProbeStore) !void {
    try std.testing.expect(@enumToInt(store.probe.last_op) > 0);

    if (size > 0)
        try std.testing.expect(store.probe.ops_len > 0);

    try ensureOpSupported(size, store, linux.IORING_OP.NOP);
    try ensureOpSupported(size, store, linux.IORING_OP.POLL_REMOVE);
}

test "register_probe" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    {
        var empty_store = ProbeStore{};
        ring.register_probe(&empty_store.probe, 0) catch |err| switch (err) {
            error.NotSupported => return error.SkipZigTest,
            else => return err,
        };
        try verifyProbe(0, &empty_store);
    }

    {
        const half_size = @enumToInt(linux.IORING_OP.TEE);
        var half_store = ProbeStore{};
        try ring.register_probe(&half_store.probe, half_size);
        try verifyProbe(half_size, &half_store);
    }

    {
        const full_size = ProbeStore.store_length;
        var full_store = ProbeStore{};
        try ring.register_probe(&full_store.probe, full_size);
        try verifyProbe(full_size, &full_store);
    }
}

test "get_probe" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var probe = IO_Uring.get_probe() catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        error.NotSupported => return error.SkipZigTest,
        else => return err,
    };
    try verifyProbe(ProbeStore.store_length, &probe);
}

fn bufRingRead(ring: *IO_Uring, fd: os.fd_t, bgid: u16, read_size: u16) !u16 {
    const read_selection = IO_Uring.ReadBuffer{ .buffer_selection = .{ .group_id = bgid, .len = read_size } };
    const sqe = try ring.read(1, fd, read_selection, 0);
    try std.testing.expectEqual(@as(u8, linux.IOSQE_BUFFER_SELECT), sqe.flags & linux.IOSQE_BUFFER_SELECT);
    try std.testing.expectEqual(bgid, sqe.buf_index);

    _ = try ring.submit();
    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        .NOBUFS => return error.NoBuffers,
        else => |errno| return os.unexpectedErrno(errno),
    }
    try std.testing.expectEqual(@as(i32, read_size), cqe.res);
    const shifted = std.math.shr(u32, cqe.flags, linux.IORING_CQE_BUFFER_SHIFT);
    return @intCast(u16, shifted);
}

test "buf_ring" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .PROVIDE_BUFFERS, .REMOVE_BUFFERS });

    const buf_count = 8;
    const buf_size = 16;
    const buf_hsize = buf_size / 2;
    const bgid = 0;

    // test_reg_unreg
    {
        var pool = try BufferRing.init(buf_count);
        defer pool.deinit();

        ring.register_buf_ring(pool.makeRegRequest(bgid), 0) catch |err| switch (err) {
            error.NotSupported => return error.SkipZigTest,
            else => return err,
        };
        ring.unregister_buf_ring(bgid) catch |err| switch (err) {
            error.NotSupported => return error.SkipZigTest,
            else => return err,
        };
    }

    // test_bad_count
    {
        try std.testing.expectError(error.CountNotPowerOfTwo, BufferRing.init(3));
    }

    // test_double_reg_unreg
    {
        var pool = try BufferRing.init(buf_count);
        defer pool.deinit();

        try ring.register_buf_ring(pool.makeRegRequest(bgid), 0);
        try std.testing.expectError(error.GroupIDAlreadyTaken, ring.register_buf_ring(pool.makeRegRequest(bgid), 0));
        try ring.unregister_buf_ring(bgid);
        try std.testing.expectError(error.UnknownGroupID, ring.unregister_buf_ring(bgid));
    }

    // test_bad_reg
    {
        const request = std.mem.zeroInit(linux.io_uring_buf_reg, .{
            .ring_addr = 4096,
            .ring_entries = 32,
            .bgid = bgid,
        });
        try std.testing.expectError(error.Fault, ring.register_buf_ring(request, 0));
    }

    // test_mixed_reg
    {
        const buffer_len = 128;
        var buffers: [4][buffer_len]u8 = undefined;
        _ = try ring.provide_buffers(0, @ptrCast([*]u8, &buffers), buffers.len, buffer_len, bgid, 0);
        _ = try ring.submit();
        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Happens when the kernel is < 5.7
            .INVAL => return error.SkipZigTest,
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        var pool = try BufferRing.init(buf_count);
        defer pool.deinit();

        try std.testing.expectError(error.GroupIDAlreadyTaken, ring.register_buf_ring(pool.makeRegRequest(bgid), 0));

        _ = try ring.remove_buffers(0, buffers.len, bgid);
        _ = try ring.submit();
        _ = try ring.copy_cqe();

        try ring.register_buf_ring(pool.makeRegRequest(bgid), 0);
        try ring.unregister_buf_ring(bgid);
    }

    // test_mixed_reg2
    {
        var pool = try BufferRing.init(buf_count);
        defer pool.deinit();

        try ring.register_buf_ring(pool.makeRegRequest(bgid), 0);

        const buffer_len = 128;
        var buffers: [4][buffer_len]u8 = undefined;
        _ = try ring.provide_buffers(0, @ptrCast([*]u8, &buffers), buffers.len, buffer_len, bgid, 0);
        _ = try ring.submit();
        const cqe = try ring.copy_cqe();
        try std.testing.expectEqual(linux.E.INVAL, cqe.err());

        try ring.unregister_buf_ring(bgid);
    }

    // test_running
    {
        var pool = try BufferRing.init(buf_count);
        defer pool.deinit();

        try ring.register_buf_ring(pool.makeRegRequest(bgid), 0);

        const fd = try os.openZ("/dev/zero", os.O.RDONLY | os.O.CLOEXEC, 0);
        defer os.close(fd);

        var buf_used: [buf_count]bool = [_]bool{false} ** buf_count;
        var buffer: [buf_size]u8 = [_]u8{0x00} ** buf_size;
        var loops: u32 = 8;
        while (loops > 0) : (loops -= 1) {
            std.mem.set(bool, &buf_used, false);

            var buf_index: u16 = 0;
            while (buf_index < buf_count) : (buf_index += 1) {
                pool.add(&buffer, buf_index);
            }
            pool.advance(buf_count);

            var ent_index: u16 = 0;
            while (ent_index < buf_count) : (ent_index += 1) {
                std.mem.set(u8, &buffer, 0xFF);
                const buf_id = try bufRingRead(&ring, fd, bgid, buf_hsize);
                try std.testing.expect(buf_used[buf_id] == false); // reused buffer

                var addr = @intToPtr([*]u8, pool.bufs[buf_id].addr);
                try std.testing.expect(std.mem.allEqual(u8, addr[0..buf_hsize], 0x00));
                try std.testing.expect(std.mem.allEqual(u8, addr[buf_hsize..buf_size], 0xFF));
                buf_used[buf_id] = true;
            }
            try std.testing.expect(std.mem.allEqual(bool, &buf_used, true));
            try std.testing.expectError(error.NoBuffers, bufRingRead(&ring, fd, bgid, buf_hsize));
        }

        try ring.unregister_buf_ring(bgid);
    }
}

fn fileUpdateAlloc(ring: *IO_Uring, fds: []os.fd_t) !void {
    _ = try ring.files_update(0xcccc, fds, linux.IORING_FILE_INDEX_ALLOC);
    _ = try ring.submit();
    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        .NFILE => return error.FileTableOverflow,
        else => |errno| return os.unexpectedErrno(errno),
    }
}

test "file_alloc_ranges" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const pipe_fds = try os.pipe();
    defer os.close(pipe_fds[0]);
    defer os.close(pipe_fds[1]);

    ring.register_files_sparse(10) catch |e| switch (e) {
        error.NotSupported => return error.SkipZigTest,
        else => return e,
    };

    ring.register_file_alloc_range(0, 1) catch |e| switch (e) {
        error.NotSupported => return error.SkipZigTest,
        else => return e,
    };

    // test_overallocating_file_range
    {
        const roff = 7;
        const rlen = 2;

        try ring.register_file_alloc_range(roff, rlen);
        var index: u32 = 0;
        while (index < rlen) : (index += 1) {
            var fds = [_]os.fd_t{pipe_fds[0]};
            try fileUpdateAlloc(&ring, &fds);
            try std.testing.expect(fds[0] >= roff and fds[0] < (roff + rlen));
        }

        var fds = [_]os.fd_t{pipe_fds[0]};
        try std.testing.expectError(error.FileTableOverflow, fileUpdateAlloc(&ring, &fds));
    }

    // test_out_of_range_file_ranges
    {
        try std.testing.expectError(error.NotSupported, ring.register_file_alloc_range(8, 3));
        try std.testing.expectError(error.NotSupported, ring.register_file_alloc_range(10, 1));
        try std.testing.expectError(error.Overflow, ring.register_file_alloc_range(7, std.math.maxInt(u32)));
    }

    // test_zero_range_alloc
    {
        try ring.register_file_alloc_range(7, 0);

        var fds = [_]os.fd_t{pipe_fds[0]};
        try std.testing.expectError(error.FileTableOverflow, fileUpdateAlloc(&ring, &fds));
    }
}

fn checkEmptyCQE(ring: *IO_Uring) !void {
    os.nanosleep(0, std.time.ns_per_ms * 1);
    try std.testing.expectEqual(@as(u32, 0), ring.cq_ready());
}

test "rsrc_tags" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    if (ring.features & linux.IORING_FEAT_RSRC_TAGS == 0)
        return error.SkipZigTest;

    const pipe_fds = try os.pipe();
    defer os.close(pipe_fds[0]);
    defer os.close(pipe_fds[1]);

    // test_files
    {
        const nr = 50;
        var files = [_]os.fd_t{pipe_fds[0]} ** nr;
        var tags: [nr]u64 = undefined;
        for (tags) |*tag, index| {
            tag.* = index + 1;
        }

        ring.register_files_tags(&files, &tags) catch |err| switch (err) {
            error.NotSupported => return error.SkipZigTest,
            else => return err,
        };

        // test that tags are set
        {
            tags[0] = 1337;
            try std.testing.expectEqual(@as(u32, 1), try ring.register_files_update_tag(0, files[0..1], tags[0..1]));
            const cqe = try ring.copy_cqe();
            try std.testing.expectEqual(@as(i32, 0), cqe.res);
            try std.testing.expectEqual(@as(u64, 1), cqe.user_data);
        }

        // test that tags are updated
        {
            tags[0] = 0;
            try std.testing.expectEqual(@as(u32, 1), try ring.register_files_update_tag(0, files[0..1], tags[0..1]));
            const cqe = try ring.copy_cqe();
            try std.testing.expectEqual(@as(i32, 0), cqe.res);
            try std.testing.expectEqual(@as(u64, 1337), cqe.user_data);
        }

        // test that tag=0 doesn't emit CQE
        {
            tags[0] = 1;
            try std.testing.expectEqual(@as(u32, 1), try ring.register_files_update_tag(0, files[0..1], tags[0..1]));
            try checkEmptyCQE(&ring);
        }

        const off = 5;
        // check update did update tag
        {
            try ring.register_files_update(off, &[_]os.fd_t{-1}); // FIXME: Should expect that this returns 1, but only for rsrc?
            const cqe = try ring.copy_cqe();
            try std.testing.expectEqual(@as(i32, 0), cqe.res);
            try std.testing.expectEqual(tags[off], cqe.user_data);
        }

        // remove removed file, shouldn't emit old tag
        {
            try ring.register_files_update(off, &[_]os.fd_t{-1}); // FIXME: Should expect that this returns <=1, but only for rsrc?
            try checkEmptyCQE(&ring);
        }
        // non-zero tag with remove update is disallowed
        {
            try std.testing.expectError(error.Disallowed, ring.register_files_update_tag(off + 1, &[_]os.fd_t{-1}, &[_]u64{1}));
        }
    }

    // test_buffers_update
    {
        var tmp_buf: [1024]u8 = undefined;
        const nr = 5;
        const default_vec = os.iovec{ .iov_base = &tmp_buf, .iov_len = tmp_buf.len };
        var vecs = [_]os.iovec{default_vec} ** nr;
        var tags: [nr]u64 = undefined;
        for (tags) |*tag, index| {
            tag.* = index + 1;
        }

        try ring.register_buffers_tags(&vecs, &tags);

        // test that tags are set
        {
            tags[0] = 1337;
            try std.testing.expectEqual(@as(u32, 1), try ring.register_buffers_update_tag(0, vecs[0..1], tags[0..1]));
            const cqe = try ring.copy_cqe();
            try std.testing.expectEqual(@as(i32, 0), cqe.res);
            try std.testing.expectEqual(@as(u64, 1), cqe.user_data);
        }

        // test that tags are updated
        {
            tags[0] = 0;
            try std.testing.expectEqual(@as(u32, 1), try ring.register_buffers_update_tag(0, vecs[0..1], tags[0..1]));
            const cqe = try ring.copy_cqe();
            try std.testing.expectEqual(@as(i32, 0), cqe.res);
            try std.testing.expectEqual(@as(u64, 1337), cqe.user_data);
        }

        // test that tag=0 doesn't emit CQE
        {
            tags[0] = 1;
            try std.testing.expectEqual(@as(u32, 1), try ring.register_buffers_update_tag(0, vecs[0..1], tags[0..1]));
            try checkEmptyCQE(&ring);
        }
    }
}

fn tryOpenPersonality(ring: *IO_Uring, parent: os.fd_t, path: [*:0]const u8, personality: ?u16) !os.E {
    var sqe = try ring.openat(2, parent, path, os.O.RDONLY, 0, null);
    if (personality) |value|
        sqe.personality = value;

    try std.testing.expectEqual(@as(u32, 1), try ring.submit());

    var cqe = try ring.copy_cqe();
    var err = cqe.err();
    if (err == linux.E.SUCCESS) {
        switch (linux.getErrno(linux.close(cqe.res))) {
            .SUCCESS => return err,
            else => |errno| return os.unexpectedErrno(errno),
        }
    }
    return err;
}

test "personality" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    // Requires being root
    if (linux.geteuid() != 0) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const use_uid: os.uid_t = 1000;
    const fname = ".tmp.access";
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // test_personality
    {
        var personality = ring.register_personality() catch |err| switch (err) {
            error.NotSupported => return error.SkipZigTest,
            else => return err,
        };

        // create file only owner can open
        var create_res = linux.openat(tmp.dir.fd, fname, os.O.RDONLY | os.O.CREAT, 0o600);
        switch (linux.getErrno(create_res)) {
            .SUCCESS => {},
            else => |errno| return os.unexpectedErrno(errno),
        }

        // verify we can open it
        try std.testing.expectEqual(os.E.SUCCESS, try tryOpenPersonality(&ring, tmp.dir.fd, fname, null));

        switch (linux.getErrno(linux.seteuid(use_uid))) {
            .SUCCESS => {},
            else => |errno| return os.unexpectedErrno(errno),
        }

        // verify we can't open it with current credentials
        try std.testing.expectEqual(os.E.ACCES, try tryOpenPersonality(&ring, tmp.dir.fd, fname, null));

        // verify we can open with registered credentials
        try std.testing.expectEqual(os.E.SUCCESS, try tryOpenPersonality(&ring, tmp.dir.fd, fname, personality));

        switch (linux.getErrno(linux.seteuid(0))) {
            .SUCCESS => {},
            else => |errno| return os.unexpectedErrno(errno),
        }

        try ring.unregister_personality(personality);
    }

    // test_invalid_personality
    {
        try std.testing.expectEqual(os.E.INVAL, try tryOpenPersonality(&ring, tmp.dir.fd, fname, 2));
    }

    // test_invalid_unregister
    {
        try std.testing.expectError(error.PersonalityNotRegistered, ring.unregister_personality(2));
    }
}

test "enable_rings" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, linux.IORING_SETUP_R_DISABLED) catch |err| switch (err) {
        error.ArgumentsInvalid => return error.SkipZigTest,
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const pipe_fds = try os.pipe();
    defer os.close(pipe_fds[0]);
    defer os.close(pipe_fds[1]);

    var buffer: [8]u8 = undefined;
    _ = try ring.write(0x88, pipe_fds[0], buffer[0..], 0);
    // Expected, ring still disabled
    try std.testing.expectError(error.FileDescriptorInBadState, ring.submit_and_wait(1));

    try ring.enable_rings();

    // Expected, ring already enabled
    try std.testing.expectError(error.RingNotDisabled, ring.enable_rings());

    try std.testing.expectEqual(@as(u32, 1), try ring.submit_and_wait(1));
}

test "register-restrictions" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, linux.IORING_SETUP_R_DISABLED) catch |err| switch (err) {
        error.ArgumentsInvalid => return error.SkipZigTest,
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    // test_restrictions_sqe_op
    {
        const pipe_fds = try os.pipe();
        defer os.close(pipe_fds[0]);
        defer os.close(pipe_fds[1]);

        var restrictions = [_]linux.io_uring_restriction{
            std.mem.zeroInit(linux.io_uring_restriction, .{ .opcode = .SQE_OP, .arg = .{
                .sqe_op = .WRITEV,
            } }),
            std.mem.zeroInit(linux.io_uring_restriction, .{ .opcode = .SQE_OP, .arg = .{
                .sqe_op = .WRITE,
            } }),
        };

        ring.register_restrictions(&restrictions) catch |err| switch (err) {
            error.NotSupported => return error.SkipZigTest,
            else => return err,
        };
        try ring.enable_rings();

        var buffer: [8]u8 = undefined;
        var rvec = os.iovec{ .iov_base = &buffer, .iov_len = buffer.len };
        var wvec = os.iovec_const{ .iov_base = &buffer, .iov_len = buffer.len };

        _ = try ring.writev(1, pipe_fds[1], &[_]os.iovec_const{wvec}, 0, 0);
        _ = try ring.readv(2, pipe_fds[0], &[_]os.iovec{rvec}, 0, 0);
        try std.testing.expectEqual(@as(u32, 2), try ring.submit());

        os.nanosleep(0, 10 * std.time.ns_per_ms);
        if (ring.cq_ready() == 1)
            return error.SkipZigTest; // Randomly happens on kernel 5.14.21

        var cqes: [2]linux.io_uring_cqe = undefined;
        for (cqes) |*cqe| {
            cqe.* = try ring.copy_cqe();
            switch (cqe.user_data) {
                1 => { // writev
                    try std.testing.expectEqual(os.E.SUCCESS, cqe.err());
                    try std.testing.expectEqual(@intCast(i32, wvec.iov_len), cqe.res);
                },
                2 => { // readv
                    try std.testing.expectEqual(os.E.ACCES, cqe.err());
                },
                else => unreachable,
            }
        }
    }

    // Not all tests included, we just needed to make sure register_restrictions works
}

test "sync-cancel" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    // Both SEND_ZC op and REGISTER_SYNC_CANCEL were introduced in 6.0
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .SEND_ZC });

    // test_sync_cancel_timeout
    {
        const pipe_fds = try os.pipe();
        defer os.close(pipe_fds[0]);
        defer os.close(pipe_fds[1]);

        var buf: [32]u8 = undefined;
        var sqe = try ring.read(0x89, pipe_fds[0], IO_Uring.ReadBuffer{ .buffer = buf[0..] }, 0);
        sqe.flags |= linux.IOSQE_ASYNC;
        try std.testing.expectEqual(@as(u32, 1), try ring.submit());

        os.nanosleep(0, 10 * std.time.ns_per_ms);

        var reg = std.mem.zeroInit(linux.io_uring_sync_cancel_reg, .{
            .addr = 0x89,
            .timeout = std.mem.zeroInit(linux.kernel_timespec, .{
                .tv_nsec = 1,
            }),
        });
        ring.register_sync_cancel(&reg) catch |err| switch (err) {
            error.NotSupported => return error.SkipZigTest,
            error.Timeout => {}, // we expect -ETIME here, but can race and get no error
            else => return err,
        };

        try std.testing.expectEqual(@as(u32, 1), ring.cq_ready());
        const cqe = try ring.copy_cqe();
        try std.testing.expect(cqe.err() != os.E.SUCCESS);
    }
}

test "register_ring_fd" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try os.openZ("/dev/zero", os.O.RDONLY | os.O.CLOEXEC, 0);
    defer os.close(fd);

    var buffer: [32]u8 = undefined;
    var rvec = os.iovec{ .iov_base = &buffer, .iov_len = 32 };

    // Ensure ring is ok at creation
    std.mem.set(u8, &buffer, 0xFF);
    _ = try ring.readv(0x1, fd, &[_]os.iovec{rvec}, 0, 0);
    _ = try ring.submit();
    try std.testing.expectEqual(os.E.SUCCESS, (try ring.copy_cqe()).err());
    try std.testing.expect(std.mem.allEqual(u8, &buffer, 0x00));

    ring.register_ring_fd() catch |err| switch (err) {
        error.NotSupported => return error.SkipZigTest,
        else => return err,
    };

    // Ensure ring still ok after register_ring_fd
    std.mem.set(u8, &buffer, 0xFF);
    _ = try ring.readv(0x1, fd, &[_]os.iovec{rvec}, 0, 0);
    _ = try ring.submit();
    try std.testing.expectEqual(os.E.SUCCESS, (try ring.copy_cqe()).err());
    try std.testing.expect(std.mem.allEqual(u8, &buffer, 0x00));

    try ring.unregister_ring_fd();

    // Ensure ring still ok after unregister_ring_fd
    std.mem.set(u8, &buffer, 0xFF);
    _ = try ring.readv(0x1, fd, &[_]os.iovec{rvec}, 0, 0);
    _ = try ring.submit();
    try std.testing.expectEqual(os.E.SUCCESS, (try ring.copy_cqe()).err());
    try std.testing.expect(std.mem.allEqual(u8, &buffer, 0x00));
}

test "fsync" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // test_sync_file_range
    {
        var file = try tmp.dir.createFile(".sync_file_range", .{});
        defer file.close();

        const data: u64 = 0xAAAAAAAAAAAAAAAA;
        var count: u32 = 1024;
        while (count > 0) : (count -= 1)
            try file.writeAll(&std.mem.toBytes(data));

        _ = try ring.sync_file_range(1, file.handle, 0, 0, 0);
        _ = try ring.submit();
        const cqe = try ring.copy_cqe();
        if (cqe.err() == os.E.INVAL)
            return error.SkipZigTest;
        try std.testing.expectEqual(os.E.SUCCESS, cqe.err());
    }
}

test "at-aliases" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .MKDIRAT, .SYMLINKAT, .LINKAT });

    var previous_cwd = try std.fs.cwd().openDir(".", .{});
    defer previous_cwd.close();
    defer previous_cwd.setAsCwd() catch unreachable;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.setAsCwd();

    _ = try ring.mkdir(1, ".mkdir", std.fs.File.default_mode);
    _ = try ring.symlink(2, ".mkdir", ".symlink");
    _ = try ring.link(3, ".symlink", ".link", 0);
    _ = try ring.submit_and_wait(3);

    var cqes: [3]linux.io_uring_cqe = undefined;
    try std.testing.expectEqual(@as(u32, 3), try ring.copy_cqes(&cqes, 3));
    for (cqes) |cqe|
        try std.testing.expectEqual(os.E.SUCCESS, cqe.err());
}

test "openat2" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.OPENAT2});

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const how = std.mem.zeroInit(os.linux.open_how, .{
        .flags = os.O.RDWR | os.O.CREAT | os.O.EXCL,
        .mode = 0o600,
        .resolve = os.linux.RESOLVE.IN_ROOT,
    });

    var sqe = try ring.openat2(1, tmp.dir.fd, "/openat2", &how, null);
    try std.testing.expectEqual(linux.IORING_OP.OPENAT2, sqe.opcode);
    _ = try ring.submit_and_wait(1);

    var cqe = try ring.copy_cqe();
    try std.testing.expectEqual(os.E.SUCCESS, cqe.err());
}

test "fadvise" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.FADVISE});

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var file = try tmp.dir.createFile("file", .{});

    var sqe = try ring.fadvise(1, file.handle, 0, 16 * 1024, os.POSIX_FADV.SEQUENTIAL);
    try std.testing.expectEqual(linux.IORING_OP.FADVISE, sqe.opcode);
    _ = try ring.submit_and_wait(1);

    var cqe = try ring.copy_cqe();
    try std.testing.expectEqual(os.E.SUCCESS, cqe.err());

    // TODO: Import more tests from liburing/test/fadvise.c
}

test "madvise" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.MADVISE});

    var mmap = try os.mmap(
        null,
        32 * 1024,
        os.PROT.READ | os.PROT.WRITE,
        os.MAP.SHARED | os.MAP.POPULATE | os.MAP.ANONYMOUS,
        0,
        0,
    );

    var sqe = try ring.madvise(1, @ptrToInt(mmap.ptr), 16 * 1024, os.MADV.SEQUENTIAL);
    try std.testing.expectEqual(linux.IORING_OP.MADVISE, sqe.opcode);
    _ = try ring.submit_and_wait(1);

    var cqe = try ring.copy_cqe();
    try std.testing.expectEqual(os.E.SUCCESS, cqe.err());

    // TODO: Import more tests from liburing/test/madvise.c
}

test "splice" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.TEE, .SPLICE});

    if ((ring.features & linux.IORING_FEAT_FAST_POLL) == 0) return error.SkipZigTest;

    const buf_size = 16 * 4096;

    // check_splice_support & check_tee_support
    {
        const sqe_splice = try ring.splice(1, -1, 0, -1, 0, buf_size, 0);
        try std.testing.expectEqual(linux.IORING_OP.SPLICE, sqe_splice.opcode);

        const sqe_tee = try ring.tee(1, -1, -1, buf_size, 0);
        try std.testing.expectEqual(linux.IORING_OP.TEE, sqe_tee.opcode);

        const sqes_submited = try ring.submit_and_wait(2);
        if (sqes_submited == 1)
            return error.SkipZigTest;

        try std.testing.expectEqual(@as(u32, 2), sqes_submited);
        var cqes: [2]linux.io_uring_cqe = undefined;
        try std.testing.expectEqual(@as(u32, 2), try ring.copy_cqes(&cqes, 0));

        for (cqes) |cqe| {
            if (cqe.err() != linux.E.BADF)
                return error.SkipZigTest;
        }
    }

    // TODO: Import more tests from liburing/test/splice.c
}

test "msg-ring" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(8, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.MSG_RING});

    // test_own
    {
        const sqe = try ring.msg_ring(1, &ring, 0x10, 0x1234, 0);
        try std.testing.expectEqual(linux.IORING_OP.MSG_RING, sqe.opcode);

        try std.testing.expectEqual(@as(u32, 1), try ring.submit_and_wait(1));

        var cqe_seen: u32 = 0;
        while (cqe_seen < 2) : (cqe_seen += 1) {
            const cqe = try ring.copy_cqe();
            switch (cqe.user_data) {
                1 => {
                    const err = cqe.err();
                    if (err == linux.E.INVAL or err == linux.E.OPNOTSUPP)
                        return error.SkipZigTest;
                    if (cqe.res != 0)
                        return error.InvalidResultCode;
                },
                0x1234 => {
                    if (cqe.res != 0x10)
                        return error.InvalidResultCode;
                },
                else => return error.InvalidUserData,
            }
        }
    }

    // TODO: Import more tests from liburing/test/msg-ring.c
}

test "socket" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(8, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.SOCKET});

    {
        const sqe = try ring.socket(1, linux.AF.INET, linux.SOCK.DGRAM, 0, 0, null);
        try std.testing.expectEqual(linux.IORING_OP.SOCKET, sqe.opcode);

        try std.testing.expectEqual(@as(u32, 1), try ring.submit_and_wait(1));
        const cqe = try ring.copy_cqe();
        const err = cqe.err();
        if (err != linux.E.SUCCESS)
            return os.unexpectedErrno(err);

        try std.testing.expectEqual(linux.E.SUCCESS, os.errno(linux.close(cqe.res)));
    }

    // TODO: Import more tests from liburing/test/socket.c
}

test "xattr" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(8, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{ .FSETXATTR, .FGETXATTR, .SETXATTR, .GETXATTR });

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const filename = "xattr.test";
    const key1 = "user.val1";
    const key2 = "user.val2";
    const value1 = "value1";
    const value2 = "value2-a-lot-longer";

    // test_fxattr
    {
        var fd = try os.openat(tmp.dir.fd, filename, linux.O.CREAT | linux.O.RDWR, 0o644);
        defer os.close(fd);

        {
            var sqe_fset1 = try ring.fsetxattr(1, fd, key1, value1, 0);
            try std.testing.expectEqual(linux.IORING_OP.FSETXATTR, sqe_fset1.opcode);
            _ = try ring.fsetxattr(2, fd, key2, value2, 0);

            try std.testing.expectEqual(@as(u32, 2), try ring.submit_and_wait(2));
            var cqes: [2]linux.io_uring_cqe = undefined;
            try std.testing.expectEqual(@as(u32, 2), try ring.copy_cqes(&cqes, 0));

            for (cqes) |cqe| {
                switch (cqe.err()) {
                    .INVAL => return error.SkipZigTest,
                    .SUCCESS => {},
                    else => |errno| return os.unexpectedErrno(errno),
                }
            }
        }

        {
            var buf1: [255]u8 = undefined;
            var buf2: [255]u8 = undefined;

            var sqe_fget1 = try ring.fgetxattr(1, fd, key1, &buf1);
            try std.testing.expectEqual(linux.IORING_OP.FGETXATTR, sqe_fget1.opcode);
            _ = try ring.fgetxattr(2, fd, key2, &buf2);

            try std.testing.expectEqual(@as(u32, 2), try ring.submit_and_wait(2));
            var cqes: [2]linux.io_uring_cqe = undefined;
            try std.testing.expectEqual(@as(u32, 2), try ring.copy_cqes(&cqes, 0));

            for (cqes) |cqe| {
                switch (cqe.err()) {
                    .SUCCESS => {},
                    else => |errno| return os.unexpectedErrno(errno),
                }
                const len = @intCast(usize, cqe.res);
                switch (cqe.user_data) {
                    1 => {
                        try std.testing.expectEqual(value1.len, len);
                        try std.testing.expectEqualSlices(u8, value1, buf1[0..len]);
                    },
                    2 => {
                        try std.testing.expectEqual(value2.len, len);
                        try std.testing.expectEqualSlices(u8, value2, buf2[0..len]);
                    },
                    else => return error.InvalidUserData,
                }
            }
        }
    }

    // test_xattr
    {
        var file = try os.open(filename, os.O.CREAT, 0o600);
        os.close(file);
        defer os.unlink(filename) catch unreachable;

        {
            var sqe_fset1 = try ring.setxattr(1, key1, filename, value1, 0);
            try std.testing.expectEqual(linux.IORING_OP.SETXATTR, sqe_fset1.opcode);
            _ = try ring.setxattr(2, key2, filename, value2, 0);

            try std.testing.expectEqual(@as(u32, 2), try ring.submit_and_wait(2));
            var cqes: [2]linux.io_uring_cqe = undefined;
            try std.testing.expectEqual(@as(u32, 2), try ring.copy_cqes(&cqes, 0));

            for (cqes) |cqe| {
                switch (cqe.err()) {
                    .INVAL => return error.SkipZigTest,
                    .SUCCESS => {},
                    else => |errno| return os.unexpectedErrno(errno),
                }
            }
        }

        {
            var buf1: [255]u8 = undefined;
            var buf2: [255]u8 = undefined;

            var sqe_fget1 = try ring.getxattr(1, key1, filename, &buf1);
            try std.testing.expectEqual(linux.IORING_OP.GETXATTR, sqe_fget1.opcode);
            _ = try ring.getxattr(2, key2, filename, &buf2);

            try std.testing.expectEqual(@as(u32, 2), try ring.submit_and_wait(2));
            var cqes: [2]linux.io_uring_cqe = undefined;
            try std.testing.expectEqual(@as(u32, 2), try ring.copy_cqes(&cqes, 0));

            for (cqes) |cqe| {
                switch (cqe.err()) {
                    .SUCCESS => {},
                    else => |errno| return os.unexpectedErrno(errno),
                }
                const len = @intCast(usize, cqe.res);
                switch (cqe.user_data) {
                    1 => {
                        try std.testing.expectEqual(value1.len, len);
                        try std.testing.expectEqualSlices(u8, value1, buf1[0..len]);
                    },
                    2 => {
                        try std.testing.expectEqual(value2.len, len);
                        try std.testing.expectEqualSlices(u8, value2, buf2[0..len]);
                    },
                    else => return error.InvalidUserData,
                }
            }
        }
    }

    // TODO: Import more tests from liburing/test/xattr.c
}

test "send_zc" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(8, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    try testEnsureOpSupport(&ring, &[_]linux.IORING_OP{.SEND_ZC});

    var sockets = try createSocketTestHarness(&ring);
    defer sockets.close();
    const enable = mem.toBytes(@as(c_int, 1));
    try os.setsockopt(sockets.client, os.SOL.SOCKET, os.SO.ZEROCOPY, &enable);
    try os.setsockopt(sockets.server, os.SOL.SOCKET, os.SO.ZEROCOPY, &enable);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const len = 32 * 1024 * 1024;
    const tx_buffer = try allocator.alignedAlloc(u8, std.mem.page_size, len);
    const rx_buffer = try allocator.alignedAlloc(u8, std.mem.page_size, len);

    // test_basic_send
    const payload_size = 100;
    const sqe = try ring.send_zc(1, sockets.client, tx_buffer[0..payload_size], 0, 0);
    try std.testing.expectEqual(linux.IORING_OP.SEND_ZC, sqe.opcode);

    _ = try ring.submit_and_wait(1);

    try std.testing.expectEqual(@as(u32, 2), ring.cq_ready());

    const cqe_more = try ring.copy_cqe();
    try std.testing.expectEqual(os.E.SUCCESS, cqe_more.err());
    try std.testing.expectEqual(@as(u64, 1), cqe_more.user_data);
    try std.testing.expectEqual(@as(i32, payload_size), cqe_more.res);
    try std.testing.expect((cqe_more.flags & linux.IORING_CQE_F_MORE) == linux.IORING_CQE_F_MORE);

    const cqe_done = try ring.copy_cqe();
    try std.testing.expectEqual(os.E.SUCCESS, cqe_done.err());
    try std.testing.expectEqual(@as(i32, 0), cqe_done.res);
    try std.testing.expectEqual(@as(u64, 1), cqe_done.user_data);
    try std.testing.expect((cqe_done.flags & linux.IORING_CQE_F_NOTIF) == linux.IORING_CQE_F_NOTIF);
    try std.testing.expect((cqe_done.flags & linux.IORING_CQE_F_MORE) == 0);

    try std.testing.expectEqual(@as(u64, payload_size), try os.recv(sockets.server, rx_buffer[0..payload_size], 0));

    // TODO: Import more tests from liburing/test/send-zerocopy.c
}

test "sendmsg_zc" {
    try testSendRecvMsg(true);
}

test "recvmsg-multishot" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    // inspired from liburing/examples/io_uring-udp.c

    const hdr_len = @sizeOf(linux.io_uring_recvmsg_out);
    const name_len = 64;
    const ctrl_len = 128;
    const payload_len = 256;
    const padding_len = 16;
    const msg_len = hdr_len + name_len + ctrl_len + payload_len;
    const buf_len = msg_len + padding_len;
    const buf_count = 4;
    const bgid = 7;
    var buffers: [buf_count][buf_len]u8 align(16) = undefined;

    // setup_context
    const QD = 64;
    var msg = std.mem.zeroInit(linux.msghdr, .{
        .namelen = name_len,
        .controllen = ctrl_len,
    });
    var params = std.mem.zeroInit(linux.io_uring_params, .{
        .cq_entries = QD * 8,
        .flags = linux.IORING_SETUP_SUBMIT_ALL | linux.IORING_SETUP_COOP_TASKRUN | linux.IORING_SETUP_CQSIZE,
    });
    var ring = IO_Uring.init_params(QD, &params) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        error.ArgumentsInvalid => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    // setup_sock
    var sock_recv = try os.socket(os.AF.INET, os.SOCK.DGRAM, 0);
    defer os.closeSocket(sock_recv);
    const address = try net.Address.parseIp4("127.0.0.1", 3333);
    try os.bind(sock_recv, &address.any, address.getOsSockLen());
    // force some cmsgs to come back to us
    const enable = mem.toBytes(@as(c_int, 1));
    try os.setsockopt(sock_recv, os.SOL.IP, linux.IP.RECVORIGDSTADDR, &enable);
    try ring.register_files(&[_]os.fd_t{sock_recv});

    // setup_buffer_pool
    var pool = try BufferRing.init(buf_count);
    defer pool.deinit();
    var buf_index: u16 = 0;
    while (buf_index < buf_count) : (buf_index += 1) {
        pool.add(&buffers[buf_index], buf_index);
    }
    pool.advance(buf_count);
    ring.register_buf_ring(pool.makeRegRequest(bgid), 0) catch |err| switch (err) {
        error.NotSupported => return error.SkipZigTest,
        else => return err,
    };

    // add_recv
    var recv_sqe = try ring.recvmsg_multishot(buf_count + 1, 0, // the socket is our only registered files, so its index is 0
        &msg, os.MSG.TRUNC);
    recv_sqe.flags |= linux.IOSQE_FIXED_FILE;
    recv_sqe.flags |= linux.IOSQE_BUFFER_SELECT;
    recv_sqe.buf_index = bgid; // setting buf_group (union)
    try std.testing.expectEqual(@as(u32, 1), try ring.submit());

    // Send a couple messages
    var sock_send = try os.socket(os.AF.INET, os.SOCK.DGRAM, 0);
    defer os.closeSocket(sock_send);
    try os.connect(sock_send, &address.any, address.getOsSockLen());
    var expected_send_addr: std.net.Ip4Address = undefined;
    var expected_send_addr_len: linux.socklen_t = expected_send_addr.getOsSockLen();
    try os.getsockname(sock_send, @ptrCast(*os.sockaddr, &expected_send_addr.sa), &expected_send_addr_len);
    const out_payload = [_]u8{0xff} ** payload_len;
    const out_iov = os.iovec_const{
        .iov_base = &out_payload,
        .iov_len = out_payload.len,
    };
    const out_msg = std.mem.zeroInit(os.msghdr_const, .{
        .iov = @ptrCast([*]const os.iovec_const, &out_iov),
        .iovlen = 1,
    });
    const msg_count = buf_count;
    var msg_index: u32 = 0;
    while (msg_index < msg_count) : (msg_index += 1) {
        _ = try os.sendmsg(sock_send, &out_msg, 0);
    }

    // Expect 4 cqe for the sent messages above, plus a message notifying we don't have anymore buffers
    const expected_cqes = msg_count + 1;
    var cqes: [expected_cqes]linux.io_uring_cqe = undefined;
    const cqes_count = try ring.copy_cqes(&cqes, expected_cqes);
    if (cqes_count == 1) // IORING_RECV_MULTISHOT flag probably not supported (req linux 6.0)
        return error.SkipZigTest;
    try std.testing.expectEqual(@as(u32, expected_cqes), cqes_count);
    try std.testing.expectEqual(linux.E.SUCCESS, cqes[0].err());

    for (cqes) |cqe, cqe_index| {
        if (cqe.err() == os.E.INVAL)
            return error.SkipZigTest;
        if (cqe_index < buf_count) {
            try std.testing.expectEqual(linux.E.SUCCESS, cqe.err());
            try std.testing.expectEqual(@as(i32, msg_len), cqe.res);
            try std.testing.expectEqual(@as(u64, buf_count + 1), cqe.user_data);

            const dstbuf_index = cqe.flags >> linux.IORING_CQE_BUFFER_SHIFT;
            const dstbuf = &buffers[dstbuf_index];
            // dstbuf consists of io_uring_recvmsg_out+name+control+payload+padding

            const msgout = try io_uring_recvmsg_validate(dstbuf, &msg);
            try std.testing.expectEqual(@as(u32, @sizeOf(os.sockaddr.in)), msgout.namelen);
            try std.testing.expectEqual(@as(u32, @sizeOf(cmsghdr) + @sizeOf(os.sockaddr.in)), msgout.controllen);
            try std.testing.expectEqual(@as(u32, payload_len), msgout.payloadlen);

            const name = io_uring_recvmsg_name(msgout);
            try std.testing.expectEqual(@as(usize, msgout.namelen), name.len);
            try std.testing.expectEqual(@ptrCast([*]const u8, @alignCast(1, dstbuf)) + @sizeOf(linux.io_uring_recvmsg_out), name.ptr);
            try std.testing.expectEqualSlices(u8, &std.mem.toBytes(expected_send_addr.sa), name);

            const control = io_uring_recvmsg_control(msgout, &msg);
            try std.testing.expectEqual(@as(usize, msgout.controllen), control.len);
            try std.testing.expectEqual(name.ptr + name_len, control.ptr);
            const cfirst = io_uring_recvmsg_cmsg_firsthdr(msgout, &msg).?;
            try std.testing.expectEqual(@as(usize, @sizeOf(cmsghdr) + @sizeOf(os.sockaddr.in)), cfirst.cmsg_len);
            try std.testing.expectEqual(@as(i32, linux.IPPROTO.IP), cfirst.cmsg_level);
            try std.testing.expectEqual(@as(i32, linux.IP.RECVORIGDSTADDR), cfirst.cmsg_type);
            try std.testing.expectEqualSlices(u8, &std.mem.toBytes(address.in.sa), io_uring_cmsghdr_data(cfirst));
            try std.testing.expect(io_uring_recvmsg_cmsg_nexthdr(msgout, &msg, cfirst) == null);
            // TODO: Have more than one cmsg to further test io_uring_recvmsg_cmsg_nexthdr

            const payload = io_uring_recvmsg_payload(msgout, &msg);
            try std.testing.expectEqual(@as(usize, payload_len), payload.len);
            try std.testing.expectEqual(control.ptr + ctrl_len, payload.ptr);
            try std.testing.expect(std.mem.allEqual(u8, payload, 0xFF));
        } else {
            try std.testing.expectEqual(linux.E.NOBUFS, cqe.err());
        }
    }
}
