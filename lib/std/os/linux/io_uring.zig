const std = @import("../../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const net = std.net;
const os = std.os;
const linux = os.linux;
const testing = std.testing;

pub const IO_Uring = struct {
    fd: os.fd_t = -1,
    sq: SubmissionQueue,
    cq: CompletionQueue,
    flags: u32,
    features: u32,

    /// A friendly way to setup an io_uring, with default linux.io_uring_params.
    /// `entries` must be a power of two between 1 and 32768, although the kernel will make the final
    /// call on how many entries the submission and completion queues will ultimately have,
    /// see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L8027-L8050.
    /// Matches the interface of io_uring_queue_init() in liburing.
    pub fn init(entries: u16, flags: u32) !IO_Uring {
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
    pub fn init_params(entries: u16, p: *linux.io_uring_params) !IO_Uring {
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
        const fd = @as(os.fd_t, @intCast(res));
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
        const sqe = &self.sq.sqes[self.sq.sqe_tail & self.sq.mask];
        self.sq.sqe_tail = next;
        return sqe;
    }

    /// Submits the SQEs acquired via get_sqe() to the kernel. You can call this once after you have
    /// called get_sqe() multiple times to setup multiple I/O requests.
    /// Returns the number of SQEs submitted, if not used alongside IORING_SETUP_SQPOLL.
    /// If the io_uring instance is uses IORING_SETUP_SQPOLL, the value returned on success is not
    /// guaranteed to match the amount of actually submitted sqes during this call. A value higher
    /// or lower, including 0, may be returned.
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
        const res = linux.io_uring_enter(self.fd, to_submit, min_complete, flags, null);
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
        return @as(u32, @intCast(res));
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
        const count = self.copy_cqes_ready(cqes);
        if (count > 0) return count;
        if (self.cq_ring_needs_flush() or wait_nr > 0) {
            _ = try self.enter(0, wait_nr, linux.IORING_ENTER_GETEVENTS);
            return self.copy_cqes_ready(cqes);
        }
        return 0;
    }

    fn copy_cqes_ready(self: *IO_Uring, cqes: []linux.io_uring_cqe) u32 {
        const ready = self.cq_ready();
        const count = @min(cqes.len, ready);
        const head = self.cq.head.* & self.cq.mask;
        const tail = (self.cq.head.* +% count) & self.cq.mask;

        if (head <= tail) {
            // head behind tail -> no wrapping
            @memcpy(cqes[0..count], self.cq.cqes[head..tail]);
        } else {
            // head in front of tail -> buffer wraps
            const two_copies_required: bool = self.cq.cqes.len - head < count;
            const amount_to_copy_in_first = if (two_copies_required) self.cq.cqes.len - head else count;
            @memcpy(cqes[0..amount_to_copy_in_first], self.cq.cqes[head .. head + amount_to_copy_in_first]);
            if (two_copies_required) {
                @memcpy(cqes[amount_to_copy_in_first..count], self.cq.cqes[0..tail]);
            }
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

    /// Queues (but does not submit) an SQE to perform a `read(2)` or `preadv(2)` depending on the buffer type.
    /// * Reading into a `ReadBuffer.buffer` uses `read(2)`
    /// * Reading into a `ReadBuffer.iovecs` uses `preadv(2)`
    ///   If you want to do a `preadv2(2)` then set `rw_flags` on the returned SQE. See https://man7.org/linux/man-pages/man2/preadv2.2.html
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

    /// Queues (but does not submit) an SQE to perform a `splice(2)`
    /// Either `fd_in` or `fd_out` must be a pipe.
    /// If `fd_in` refers to a pipe, `off_in` is ignored and must be set to std.math.maxInt(u64).
    /// If `fd_in` does not refer to a pipe and `off_in` is maxInt(u64), then `len` are read
    /// from `fd_in` starting from the file offset, which is incremented by the number of bytes read.
    /// If `fd_in` does not refer to a pipe and `off_in` is not maxInt(u64), then the starting offset of `fd_in` will be `off_in`.
    /// This splice operation can be used to implement sendfile by splicing to an intermediate pipe first,
    /// then splice to the final destination. In fact, the implementation of sendfile in kernel uses splice internally.
    ///
    /// NOTE that even if fd_in or fd_out refers to a pipe, the splice operation can still fail with EINVAL if one of the
    /// fd doesn't explicitly support splice peration, e.g. reading from terminal is unsupported from kernel 5.7 to 5.11.
    /// See https://github.com/axboe/liburing/issues/291
    ///
    /// Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
    pub fn splice(self: *IO_Uring, user_data: u64, fd_in: os.fd_t, off_in: u64, fd_out: os.fd_t, off_out: u64, len: usize) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_splice(sqe, fd_in, off_in, fd_out, off_out, len);
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
        buffer: *os.iovec,
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
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_writev(sqe, fd, iovecs, offset);
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
        buffer: *os.iovec,
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
    /// Available since 5.5
    pub fn accept(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: ?*os.sockaddr,
        addrlen: ?*os.socklen_t,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_accept(sqe, fd, addr, addrlen, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues an multishot accept on a socket.
    ///
    /// Multishot variant allows an application to issue a single accept request,
    /// which will repeatedly trigger a CQE when a connection request comes in.
    /// While IORING_CQE_F_MORE flag is set in CQE flags accept will generate
    /// further CQEs.
    ///
    /// Available since 5.19
    pub fn accept_multishot(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: ?*os.sockaddr,
        addrlen: ?*os.socklen_t,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_multishot_accept(sqe, fd, addr, addrlen, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues an accept using direct (registered) file descriptors.
    ///
    /// To use an accept direct variant, the application must first have registered
    /// a file table (with register_files). An unused table index will be
    /// dynamically chosen and returned in the CQE res field.
    ///
    /// After creation, they can be used by setting IOSQE_FIXED_FILE in the SQE
    /// flags member, and setting the SQE fd field to the direct descriptor value
    /// rather than the regular file descriptor.
    ///
    /// Available since 5.19
    pub fn accept_direct(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: ?*os.sockaddr,
        addrlen: ?*os.socklen_t,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_accept_direct(sqe, fd, addr, addrlen, flags, linux.IORING_FILE_INDEX_ALLOC);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues an multishot accept using direct (registered) file descriptors.
    /// Available since 5.19
    pub fn accept_multishot_direct(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        addr: ?*os.sockaddr,
        addrlen: ?*os.socklen_t,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_multishot_accept_direct(sqe, fd, addr, addrlen, flags);
        sqe.user_data = user_data;
        return sqe;
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
    /// Available since 5.6
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
    /// Available since 5.6
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
    ///
    /// This operation will most likely produce two CQEs. The flags field of the
    /// first cqe may likely contain IORING_CQE_F_MORE, which means that there will
    /// be a second cqe with the user_data field set to the same value. The user
    /// must not modify the data buffer until the notification is posted. The first
    /// cqe follows the usual rules and so its res field will contain the number of
    /// bytes sent or a negative error code. The notification's res field will be
    /// set to zero and the flags field will contain IORING_CQE_F_NOTIF. The two
    /// step model is needed because the kernel may hold on to buffers for a long
    /// time, e.g. waiting for a TCP ACK. Notifications responsible for controlling
    /// the lifetime of the buffers. Even errored requests may generate a
    /// notification.
    ///
    /// Available since 6.0
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
    /// Available since 6.0
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
    /// Available since 5.3
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

    /// Queues (but does not submit) an SQE to perform a `sendmsg(2)`.
    /// Returns a pointer to the SQE.
    /// Available since 5.3
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
    /// Available since 6.1
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
    /// Available since 5.6.
    pub fn openat(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        path: [*:0]const u8,
        flags: linux.O,
        mode: os.mode_t,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_openat(sqe, fd, path, flags, mode);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues an openat using direct (registered) file descriptors.
    ///
    /// To use an accept direct variant, the application must first have registered
    /// a file table (with register_files). An unused table index will be
    /// dynamically chosen and returned in the CQE res field.
    ///
    /// After creation, they can be used by setting IOSQE_FIXED_FILE in the SQE
    /// flags member, and setting the SQE fd field to the direct descriptor value
    /// rather than the regular file descriptor.
    ///
    /// Available since 5.15
    pub fn openat_direct(
        self: *IO_Uring,
        user_data: u64,
        fd: os.fd_t,
        path: [*:0]const u8,
        flags: linux.O,
        mode: os.mode_t,
        file_index: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_openat_direct(sqe, fd, path, flags, mode, file_index);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues (but does not submit) an SQE to perform a `close(2)`.
    /// Returns a pointer to the SQE.
    /// Available since 5.6.
    pub fn close(self: *IO_Uring, user_data: u64, fd: os.fd_t) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_close(sqe, fd);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Queues close of registered file descriptor.
    /// Available since 5.15
    pub fn close_direct(self: *IO_Uring, user_data: u64, file_index: u32) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_close_direct(sqe, file_index);
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
        buffer_size: usize,
        buffers_count: usize,
        group_id: usize,
        buffer_id: usize,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_provide_buffers(sqe, buffers, buffer_size, buffers_count, group_id, buffer_id);
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

    /// Queues (but does not submit) an SQE to perform a `waitid(2)`.
    /// Returns a pointer to the SQE.
    pub fn waitid(
        self: *IO_Uring,
        user_data: u64,
        id_type: linux.P,
        id: i32,
        infop: *linux.siginfo_t,
        options: u32,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_waitid(sqe, id_type, id, infop, options, flags);
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
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_FILES,
            @as(*const anyopaque, @ptrCast(fds.ptr)),
            @as(u32, @intCast(fds.len)),
        );
        try handle_registration_result(res);
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

        const FilesUpdate = extern struct {
            offset: u32,
            resv: u32,
            fds: u64 align(8),
        };
        var update = FilesUpdate{
            .offset = offset,
            .resv = @as(u32, 0),
            .fds = @as(u64, @intFromPtr(fds.ptr)),
        };

        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_FILES_UPDATE,
            @as(*const anyopaque, @ptrCast(&update)),
            @as(u32, @intCast(fds.len)),
        );
        try handle_registration_result(res);
    }

    /// Registers the file descriptor for an eventfd that will be notified of completion events on
    ///  an io_uring instance.
    /// Only a single a eventfd can be registered at any given point in time.
    pub fn register_eventfd(self: *IO_Uring, fd: os.fd_t) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_EVENTFD,
            @as(*const anyopaque, @ptrCast(&fd)),
            1,
        );
        try handle_registration_result(res);
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
            @as(*const anyopaque, @ptrCast(&fd)),
            1,
        );
        try handle_registration_result(res);
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
        try handle_registration_result(res);
    }

    /// Registers an array of buffers for use with `read_fixed` and `write_fixed`.
    pub fn register_buffers(self: *IO_Uring, buffers: []const os.iovec) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(
            self.fd,
            .REGISTER_BUFFERS,
            buffers.ptr,
            @as(u32, @intCast(buffers.len)),
        );
        try handle_registration_result(res);
    }

    /// Unregister the registered buffers.
    pub fn unregister_buffers(self: *IO_Uring) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(self.fd, .UNREGISTER_BUFFERS, null, 0);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .NXIO => return error.BuffersNotRegistered,
            else => |errno| return os.unexpectedErrno(errno),
        }
    }

    fn handle_registration_result(res: usize) !void {
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            // One or more fds in the array are invalid, or the kernel does not support sparse sets:
            .BADF => return error.FileDescriptorInvalid,
            .BUSY => return error.FilesAlreadyRegistered,
            .INVAL => return error.FilesEmpty,
            // Adding `nr_args` file references would exceed the maximum allowed number of files the
            // user is allowed to have according to the per-user RLIMIT_NOFILE resource limit and
            // the CAP_SYS_RESOURCE capability is not set, or `nr_args` exceeds the maximum allowed
            // for a fixed file set (older kernels have a limit of 1024 files vs 64K files):
            .MFILE => return error.UserFdQuotaExceeded,
            // Insufficient kernel resources, or the caller had a non-zero RLIMIT_MEMLOCK soft
            // resource limit but tried to lock more memory than the limit permitted (not enforced
            // when the process is privileged with CAP_IPC_LOCK):
            .NOMEM => return error.SystemResources,
            // Attempt to register files on a ring already registering files or being torn down:
            .NXIO => return error.RingShuttingDownOrAlreadyRegisteringFiles,
            else => |errno| return os.unexpectedErrno(errno),
        }
    }

    /// Unregisters all registered file descriptors previously associated with the ring.
    pub fn unregister_files(self: *IO_Uring) !void {
        assert(self.fd >= 0);
        const res = linux.io_uring_register(self.fd, .UNREGISTER_FILES, null, 0);
        switch (linux.getErrno(res)) {
            .SUCCESS => {},
            .NXIO => return error.FilesNotRegistered,
            else => |errno| return os.unexpectedErrno(errno),
        }
    }

    /// Prepares a socket creation request.
    /// New socket fd will be returned in completion result.
    /// Available since 5.19
    pub fn socket(
        self: *IO_Uring,
        user_data: u64,
        domain: u32,
        socket_type: u32,
        protocol: u32,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_socket(sqe, domain, socket_type, protocol, flags);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Prepares a socket creation request for registered file at index `file_index`.
    /// Available since 5.19
    pub fn socket_direct(
        self: *IO_Uring,
        user_data: u64,
        domain: u32,
        socket_type: u32,
        protocol: u32,
        flags: u32,
        file_index: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_socket_direct(sqe, domain, socket_type, protocol, flags, file_index);
        sqe.user_data = user_data;
        return sqe;
    }

    /// Prepares a socket creation request for registered file, index chosen by kernel (file index alloc).
    /// File index will be returned in CQE res field.
    /// Available since 5.19
    pub fn socket_direct_alloc(
        self: *IO_Uring,
        user_data: u64,
        domain: u32,
        socket_type: u32,
        protocol: u32,
        flags: u32,
    ) !*linux.io_uring_sqe {
        const sqe = try self.get_sqe();
        io_uring_prep_socket_direct_alloc(sqe, domain, socket_type, protocol, flags);
        sqe.user_data = user_data;
        return sqe;
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
        const size = @max(
            p.sq_off.array + p.sq_entries * @sizeOf(u32),
            p.cq_off.cqes + p.cq_entries * @sizeOf(linux.io_uring_cqe),
        );
        const mmap = try os.mmap(
            null,
            size,
            os.PROT.READ | os.PROT.WRITE,
            .{ .TYPE = .SHARED, .POPULATE = true },
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
            .{ .TYPE = .SHARED, .POPULATE = true },
            fd,
            linux.IORING_OFF_SQES,
        );
        errdefer os.munmap(mmap_sqes);
        assert(mmap_sqes.len == size_sqes);

        const array: [*]u32 = @ptrCast(@alignCast(&mmap[p.sq_off.array]));
        const sqes: [*]linux.io_uring_sqe = @ptrCast(@alignCast(&mmap_sqes[0]));
        // We expect the kernel copies p.sq_entries to the u32 pointed to by p.sq_off.ring_entries,
        // see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L7843-L7844.
        assert(p.sq_entries == @as(*u32, @ptrCast(@alignCast(&mmap[p.sq_off.ring_entries]))).*);
        return SubmissionQueue{
            .head = @ptrCast(@alignCast(&mmap[p.sq_off.head])),
            .tail = @ptrCast(@alignCast(&mmap[p.sq_off.tail])),
            .mask = @as(*u32, @ptrCast(@alignCast(&mmap[p.sq_off.ring_mask]))).*,
            .flags = @ptrCast(@alignCast(&mmap[p.sq_off.flags])),
            .dropped = @ptrCast(@alignCast(&mmap[p.sq_off.dropped])),
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
        const cqes: [*]linux.io_uring_cqe = @ptrCast(@alignCast(&mmap[p.cq_off.cqes]));
        assert(p.cq_entries == @as(*u32, @ptrCast(@alignCast(&mmap[p.cq_off.ring_entries]))).*);
        return CompletionQueue{
            .head = @ptrCast(@alignCast(&mmap[p.cq_off.head])),
            .tail = @ptrCast(@alignCast(&mmap[p.cq_off.tail])),
            .mask = @as(*u32, @ptrCast(@alignCast(&mmap[p.cq_off.ring_mask]))).*,
            .overflow = @ptrCast(@alignCast(&mmap[p.cq_off.overflow])),
            .cqes = cqes[0..p.cq_entries],
        };
    }

    pub fn deinit(self: *CompletionQueue) void {
        _ = self;
        // A no-op since we now share the mmap with the submission queue.
        // Here for symmetry with the submission queue, and for any future feature support.
    }
};

pub fn io_uring_prep_nop(sqe: *linux.io_uring_sqe) void {
    sqe.* = .{
        .opcode = .NOP,
        .flags = 0,
        .ioprio = 0,
        .fd = 0,
        .off = 0,
        .addr = 0,
        .len = 0,
        .rw_flags = 0,
        .user_data = 0,
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };
}

pub fn io_uring_prep_fsync(sqe: *linux.io_uring_sqe, fd: os.fd_t, flags: u32) void {
    sqe.* = .{
        .opcode = .FSYNC,
        .flags = 0,
        .ioprio = 0,
        .fd = fd,
        .off = 0,
        .addr = 0,
        .len = 0,
        .rw_flags = flags,
        .user_data = 0,
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };
}

pub fn io_uring_prep_rw(
    op: linux.IORING_OP,
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    addr: u64,
    len: usize,
    offset: u64,
) void {
    sqe.* = .{
        .opcode = op,
        .flags = 0,
        .ioprio = 0,
        .fd = fd,
        .off = offset,
        .addr = addr,
        .len = @as(u32, @intCast(len)),
        .rw_flags = 0,
        .user_data = 0,
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };
}

pub fn io_uring_prep_read(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []u8, offset: u64) void {
    io_uring_prep_rw(.READ, sqe, fd, @intFromPtr(buffer.ptr), buffer.len, offset);
}

pub fn io_uring_prep_write(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []const u8, offset: u64) void {
    io_uring_prep_rw(.WRITE, sqe, fd, @intFromPtr(buffer.ptr), buffer.len, offset);
}

pub fn io_uring_prep_splice(sqe: *linux.io_uring_sqe, fd_in: os.fd_t, off_in: u64, fd_out: os.fd_t, off_out: u64, len: usize) void {
    io_uring_prep_rw(.SPLICE, sqe, fd_out, undefined, len, off_out);
    sqe.addr = off_in;
    sqe.splice_fd_in = fd_in;
}

pub fn io_uring_prep_readv(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    iovecs: []const os.iovec,
    offset: u64,
) void {
    io_uring_prep_rw(.READV, sqe, fd, @intFromPtr(iovecs.ptr), iovecs.len, offset);
}

pub fn io_uring_prep_writev(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    iovecs: []const os.iovec_const,
    offset: u64,
) void {
    io_uring_prep_rw(.WRITEV, sqe, fd, @intFromPtr(iovecs.ptr), iovecs.len, offset);
}

pub fn io_uring_prep_read_fixed(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: *os.iovec, offset: u64, buffer_index: u16) void {
    io_uring_prep_rw(.READ_FIXED, sqe, fd, @intFromPtr(buffer.iov_base), buffer.iov_len, offset);
    sqe.buf_index = buffer_index;
}

pub fn io_uring_prep_write_fixed(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: *os.iovec, offset: u64, buffer_index: u16) void {
    io_uring_prep_rw(.WRITE_FIXED, sqe, fd, @intFromPtr(buffer.iov_base), buffer.iov_len, offset);
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
    io_uring_prep_rw(.ACCEPT, sqe, fd, @intFromPtr(addr), 0, @intFromPtr(addrlen));
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_accept_direct(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    addr: ?*os.sockaddr,
    addrlen: ?*os.socklen_t,
    flags: u32,
    file_index: u32,
) void {
    io_uring_prep_accept(sqe, fd, addr, addrlen, flags);
    __io_uring_set_target_fixed_file(sqe, file_index);
}

pub fn io_uring_prep_multishot_accept_direct(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    addr: ?*os.sockaddr,
    addrlen: ?*os.socklen_t,
    flags: u32,
) void {
    io_uring_prep_multishot_accept(sqe, fd, addr, addrlen, flags);
    __io_uring_set_target_fixed_file(sqe, linux.IORING_FILE_INDEX_ALLOC);
}

fn __io_uring_set_target_fixed_file(sqe: *linux.io_uring_sqe, file_index: u32) void {
    const sqe_file_index: u32 = if (file_index == linux.IORING_FILE_INDEX_ALLOC)
        linux.IORING_FILE_INDEX_ALLOC
    else
        // 0 means no fixed files, indexes should be encoded as "index + 1"
        file_index + 1;
    // This filed is overloaded in liburing:
    //   splice_fd_in: i32
    //   sqe_file_index: u32
    sqe.splice_fd_in = @bitCast(sqe_file_index);
}

pub fn io_uring_prep_connect(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    addr: *const os.sockaddr,
    addrlen: os.socklen_t,
) void {
    // `addrlen` maps to `sqe.off` (u64) instead of `sqe.len` (which is only a u32).
    io_uring_prep_rw(.CONNECT, sqe, fd, @intFromPtr(addr), 0, addrlen);
}

pub fn io_uring_prep_epoll_ctl(
    sqe: *linux.io_uring_sqe,
    epfd: os.fd_t,
    fd: os.fd_t,
    op: u32,
    ev: ?*linux.epoll_event,
) void {
    io_uring_prep_rw(.EPOLL_CTL, sqe, epfd, @intFromPtr(ev), op, @as(u64, @intCast(fd)));
}

pub fn io_uring_prep_recv(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []u8, flags: u32) void {
    io_uring_prep_rw(.RECV, sqe, fd, @intFromPtr(buffer.ptr), buffer.len, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_send(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []const u8, flags: u32) void {
    io_uring_prep_rw(.SEND, sqe, fd, @intFromPtr(buffer.ptr), buffer.len, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_send_zc(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []const u8, flags: u32, zc_flags: u16) void {
    io_uring_prep_rw(.SEND_ZC, sqe, fd, @intFromPtr(buffer.ptr), buffer.len, 0);
    sqe.rw_flags = flags;
    sqe.ioprio = zc_flags;
}

pub fn io_uring_prep_send_zc_fixed(sqe: *linux.io_uring_sqe, fd: os.fd_t, buffer: []const u8, flags: u32, zc_flags: u16, buf_index: u16) void {
    io_uring_prep_send_zc(sqe, fd, buffer, flags, zc_flags);
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
    linux.io_uring_prep_rw(.RECVMSG, sqe, fd, @intFromPtr(msg), 1, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_sendmsg(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    msg: *const os.msghdr_const,
    flags: u32,
) void {
    linux.io_uring_prep_rw(.SENDMSG, sqe, fd, @intFromPtr(msg), 1, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_openat(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    path: [*:0]const u8,
    flags: linux.O,
    mode: os.mode_t,
) void {
    io_uring_prep_rw(.OPENAT, sqe, fd, @intFromPtr(path), mode, 0);
    sqe.rw_flags = @bitCast(flags);
}

pub fn io_uring_prep_openat_direct(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    path: [*:0]const u8,
    flags: linux.O,
    mode: os.mode_t,
    file_index: u32,
) void {
    io_uring_prep_openat(sqe, fd, path, flags, mode);
    __io_uring_set_target_fixed_file(sqe, file_index);
}

pub fn io_uring_prep_close(sqe: *linux.io_uring_sqe, fd: os.fd_t) void {
    sqe.* = .{
        .opcode = .CLOSE,
        .flags = 0,
        .ioprio = 0,
        .fd = fd,
        .off = 0,
        .addr = 0,
        .len = 0,
        .rw_flags = 0,
        .user_data = 0,
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };
}

pub fn io_uring_prep_close_direct(sqe: *linux.io_uring_sqe, file_index: u32) void {
    io_uring_prep_close(sqe, 0);
    __io_uring_set_target_fixed_file(sqe, file_index);
}

pub fn io_uring_prep_timeout(
    sqe: *linux.io_uring_sqe,
    ts: *const os.linux.kernel_timespec,
    count: u32,
    flags: u32,
) void {
    io_uring_prep_rw(.TIMEOUT, sqe, -1, @intFromPtr(ts), 1, count);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_timeout_remove(sqe: *linux.io_uring_sqe, timeout_user_data: u64, flags: u32) void {
    sqe.* = .{
        .opcode = .TIMEOUT_REMOVE,
        .flags = 0,
        .ioprio = 0,
        .fd = -1,
        .off = 0,
        .addr = timeout_user_data,
        .len = 0,
        .rw_flags = flags,
        .user_data = 0,
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };
}

pub fn io_uring_prep_link_timeout(
    sqe: *linux.io_uring_sqe,
    ts: *const os.linux.kernel_timespec,
    flags: u32,
) void {
    linux.io_uring_prep_rw(.LINK_TIMEOUT, sqe, -1, @intFromPtr(ts), 1, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_poll_add(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    poll_mask: u32,
) void {
    io_uring_prep_rw(.POLL_ADD, sqe, fd, @intFromPtr(@as(?*anyopaque, null)), 0, 0);
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

pub fn io_uring_prep_fallocate(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    mode: i32,
    offset: u64,
    len: u64,
) void {
    sqe.* = .{
        .opcode = .FALLOCATE,
        .flags = 0,
        .ioprio = 0,
        .fd = fd,
        .off = offset,
        .addr = len,
        .len = @as(u32, @intCast(mode)),
        .rw_flags = 0,
        .user_data = 0,
        .buf_index = 0,
        .personality = 0,
        .splice_fd_in = 0,
        .addr3 = 0,
        .resv = 0,
    };
}

pub fn io_uring_prep_statx(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    path: [*:0]const u8,
    flags: u32,
    mask: u32,
    buf: *linux.Statx,
) void {
    io_uring_prep_rw(.STATX, sqe, fd, @intFromPtr(path), mask, @intFromPtr(buf));
    sqe.rw_flags = flags;
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
        @intFromPtr(old_path),
        0,
        @intFromPtr(new_path),
    );
    sqe.len = @bitCast(new_dir_fd);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_unlinkat(
    sqe: *linux.io_uring_sqe,
    dir_fd: os.fd_t,
    path: [*:0]const u8,
    flags: u32,
) void {
    io_uring_prep_rw(.UNLINKAT, sqe, dir_fd, @intFromPtr(path), 0, 0);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_mkdirat(
    sqe: *linux.io_uring_sqe,
    dir_fd: os.fd_t,
    path: [*:0]const u8,
    mode: os.mode_t,
) void {
    io_uring_prep_rw(.MKDIRAT, sqe, dir_fd, @intFromPtr(path), mode, 0);
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
        @intFromPtr(target),
        0,
        @intFromPtr(link_path),
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
        @intFromPtr(old_path),
        0,
        @intFromPtr(new_path),
    );
    sqe.len = @bitCast(new_dir_fd);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_provide_buffers(
    sqe: *linux.io_uring_sqe,
    buffers: [*]u8,
    buffer_len: usize,
    num: usize,
    group_id: usize,
    buffer_id: usize,
) void {
    const ptr = @intFromPtr(buffers);
    io_uring_prep_rw(.PROVIDE_BUFFERS, sqe, @as(i32, @intCast(num)), ptr, buffer_len, buffer_id);
    sqe.buf_index = @intCast(group_id);
}

pub fn io_uring_prep_remove_buffers(
    sqe: *linux.io_uring_sqe,
    num: usize,
    group_id: usize,
) void {
    io_uring_prep_rw(.REMOVE_BUFFERS, sqe, @as(i32, @intCast(num)), 0, 0, 0);
    sqe.buf_index = @intCast(group_id);
}

pub fn io_uring_prep_multishot_accept(
    sqe: *linux.io_uring_sqe,
    fd: os.fd_t,
    addr: ?*os.sockaddr,
    addrlen: ?*os.socklen_t,
    flags: u32,
) void {
    io_uring_prep_accept(sqe, fd, addr, addrlen, flags);
    sqe.ioprio |= linux.IORING_ACCEPT_MULTISHOT;
}

pub fn io_uring_prep_socket(
    sqe: *linux.io_uring_sqe,
    domain: u32,
    socket_type: u32,
    protocol: u32,
    flags: u32,
) void {
    io_uring_prep_rw(.SOCKET, sqe, @intCast(domain), 0, protocol, socket_type);
    sqe.rw_flags = flags;
}

pub fn io_uring_prep_socket_direct(
    sqe: *linux.io_uring_sqe,
    domain: u32,
    socket_type: u32,
    protocol: u32,
    flags: u32,
    file_index: u32,
) void {
    io_uring_prep_socket(sqe, domain, socket_type, protocol, flags);
    __io_uring_set_target_fixed_file(sqe, file_index);
}

pub fn io_uring_prep_socket_direct_alloc(
    sqe: *linux.io_uring_sqe,
    domain: u32,
    socket_type: u32,
    protocol: u32,
    flags: u32,
) void {
    io_uring_prep_socket(sqe, domain, socket_type, protocol, flags);
    __io_uring_set_target_fixed_file(sqe, linux.IORING_FILE_INDEX_ALLOC);
}

pub fn io_uring_prep_waitid(
    sqe: *linux.io_uring_sqe,
    id_type: linux.P,
    id: i32,
    infop: *linux.siginfo_t,
    options: u32,
    flags: u32,
) void {
    io_uring_prep_rw(.WAITID, sqe, id, 0, @intFromEnum(id_type), @intFromPtr(infop));
    sqe.rw_flags = flags;
    sqe.splice_fd_in = @bitCast(options);
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

    const fd = try os.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
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

    try ring.unregister_files();
}

test "writev/fsync/readv" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(4, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "test_io_uring_writev_fsync_readv";
    const file = try tmp.dir.createFile(path, .{ .read = true, .truncate = true });
    defer file.close();
    const fd = file.handle;

    const buffer_write = [_]u8{42} ** 128;
    const iovecs_write = [_]os.iovec_const{
        os.iovec_const{ .iov_base = &buffer_write, .iov_len = buffer_write.len },
    };
    var buffer_read = [_]u8{0} ** 128;
    var iovecs_read = [_]os.iovec{
        os.iovec{ .iov_base = &buffer_read, .iov_len = buffer_read.len },
    };

    const sqe_writev = try ring.writev(0xdddddddd, fd, iovecs_write[0..], 17);
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

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = "test_io_uring_write_read";
    const file = try tmp.dir.createFile(path, .{ .read = true, .truncate = true });
    defer file.close();
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

test "splice/read" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(4, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var tmp = std.testing.tmpDir(.{});
    const path_src = "test_io_uring_splice_src";
    const file_src = try tmp.dir.createFile(path_src, .{ .read = true, .truncate = true });
    defer file_src.close();
    const fd_src = file_src.handle;

    const path_dst = "test_io_uring_splice_dst";
    const file_dst = try tmp.dir.createFile(path_dst, .{ .read = true, .truncate = true });
    defer file_dst.close();
    const fd_dst = file_dst.handle;

    const buffer_write = [_]u8{97} ** 20;
    var buffer_read = [_]u8{98} ** 20;
    _ = try file_src.write(&buffer_write);

    const fds = try os.pipe();
    const pipe_offset: u64 = std.math.maxInt(u64);

    const sqe_splice_to_pipe = try ring.splice(0x11111111, fd_src, 0, fds[1], pipe_offset, buffer_write.len);
    try testing.expectEqual(linux.IORING_OP.SPLICE, sqe_splice_to_pipe.opcode);
    try testing.expectEqual(@as(u64, 0), sqe_splice_to_pipe.addr);
    try testing.expectEqual(pipe_offset, sqe_splice_to_pipe.off);
    sqe_splice_to_pipe.flags |= linux.IOSQE_IO_LINK;

    const sqe_splice_from_pipe = try ring.splice(0x22222222, fds[0], pipe_offset, fd_dst, 10, buffer_write.len);
    try testing.expectEqual(linux.IORING_OP.SPLICE, sqe_splice_from_pipe.opcode);
    try testing.expectEqual(pipe_offset, sqe_splice_from_pipe.addr);
    try testing.expectEqual(@as(u64, 10), sqe_splice_from_pipe.off);
    sqe_splice_from_pipe.flags |= linux.IOSQE_IO_LINK;

    const sqe_read = try ring.read(0x33333333, fd_dst, .{ .buffer = buffer_read[0..] }, 10);
    try testing.expectEqual(linux.IORING_OP.READ, sqe_read.opcode);
    try testing.expectEqual(@as(u64, 10), sqe_read.off);
    try testing.expectEqual(@as(u32, 3), try ring.submit());

    const cqe_splice_to_pipe = try ring.copy_cqe();
    const cqe_splice_from_pipe = try ring.copy_cqe();
    const cqe_read = try ring.copy_cqe();
    // Prior to Linux Kernel 5.6 this is the only way to test for splice/read support:
    // https://lwn.net/Articles/809820/
    if (cqe_splice_to_pipe.err() == .INVAL) return error.SkipZigTest;
    if (cqe_splice_from_pipe.err() == .INVAL) return error.SkipZigTest;
    if (cqe_read.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x11111111,
        .res = buffer_write.len,
        .flags = 0,
    }, cqe_splice_to_pipe);
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x22222222,
        .res = buffer_write.len,
        .flags = 0,
    }, cqe_splice_from_pipe);
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x33333333,
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

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "test_io_uring_write_read_fixed";
    const file = try tmp.dir.createFile(path, .{ .read = true, .truncate = true });
    defer file.close();
    const fd = file.handle;

    var raw_buffers: [2][11]u8 = undefined;
    // First buffer will be written to the file.
    @memset(&raw_buffers[0], 'z');
    raw_buffers[0][0.."foobar".len].* = "foobar".*;

    var buffers = [2]os.iovec{
        .{ .iov_base = &raw_buffers[0], .iov_len = raw_buffers[0].len },
        .{ .iov_base = &raw_buffers[1], .iov_len = raw_buffers[1].len },
    };
    ring.register_buffers(&buffers) catch |err| switch (err) {
        error.SystemResources => {
            // See https://github.com/ziglang/zig/issues/15362
            return error.SkipZigTest;
        },
        else => |e| return e,
    };

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
        .res = @as(i32, @intCast(buffers[0].iov_len)),
        .flags = 0,
    }, cqe_write);
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x12121212,
        .res = @as(i32, @intCast(buffers[1].iov_len)),
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

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "test_io_uring_openat";

    // Workaround for LLVM bug: https://github.com/ziglang/zig/issues/12014
    const path_addr = if (builtin.zig_backend == .stage2_llvm) p: {
        var workaround = path;
        _ = &workaround;
        break :p @intFromPtr(workaround);
    } else @intFromPtr(path);

    const flags: linux.O = .{ .CLOEXEC = true, .ACCMODE = .RDWR, .CREAT = true };
    const mode: os.mode_t = 0o666;
    const sqe_openat = try ring.openat(0x33333333, tmp.dir.fd, path, flags, mode);
    try testing.expectEqual(linux.io_uring_sqe{
        .opcode = .OPENAT,
        .flags = 0,
        .ioprio = 0,
        .fd = tmp.dir.fd,
        .off = 0,
        .addr = path_addr,
        .len = mode,
        .rw_flags = @bitCast(flags),
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
    if (cqe_openat.err() == .BADF) return error.SkipZigTest;
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

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "test_io_uring_close";
    const file = try tmp.dir.createFile(path, .{});
    errdefer file.close();

    const sqe_close = try ring.close(0x44444444, file.handle);
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

test "sendmsg/recvmsg" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(2, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var address_server = try net.Address.parseIp4("127.0.0.1", 0);

    const server = try os.socket(address_server.any.family, os.SOCK.DGRAM, 0);
    defer os.close(server);
    try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEPORT, &mem.toBytes(@as(c_int, 1)));
    try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
    try os.bind(server, &address_server.any, address_server.getOsSockLen());

    // set address_server to the OS-chosen IP/port.
    var slen: os.socklen_t = address_server.getOsSockLen();
    try os.getsockname(server, &address_server.any, &slen);

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
    const sqe_sendmsg = try ring.sendmsg(0x11111111, client, &msg_send, 0);
    sqe_sendmsg.flags |= linux.IOSQE_IO_LINK;
    try testing.expectEqual(linux.IORING_OP.SENDMSG, sqe_sendmsg.opcode);
    try testing.expectEqual(client, sqe_sendmsg.fd);

    var buffer_recv = [_]u8{0} ** 128;
    var iovecs_recv = [_]os.iovec{
        os.iovec{ .iov_base = &buffer_recv, .iov_len = buffer_recv.len },
    };
    const addr = [_]u8{0} ** 4;
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
    try testing.expectEqual(@as(u32, 2), ring.cq_ready());

    const cqe_sendmsg = try ring.copy_cqe();
    if (cqe_sendmsg.res == -@as(i32, @intFromEnum(linux.E.INVAL))) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x11111111,
        .res = buffer_send.len,
        .flags = 0,
    }, cqe_sendmsg);

    const cqe_recvmsg = try ring.copy_cqe();
    if (cqe_recvmsg.res == -@as(i32, @intFromEnum(linux.E.INVAL))) return error.SkipZigTest;
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x22222222,
        .res = buffer_recv.len,
        // ignore IORING_CQE_F_SOCK_NONEMPTY since it is set non-deterministically
        .flags = cqe_recvmsg.flags & linux.IORING_CQE_F_SOCK_NONEMPTY,
    }, cqe_recvmsg);

    try testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);
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
        .res = -@as(i32, @intFromEnum(linux.E.TIME)),
        .flags = 0,
    }, cqe);

    // Tests should not depend on timings: skip test if outside margin.
    if (!std.math.approxEqAbs(f64, ms, @as(f64, @floatFromInt(stopped - started)), margin)) return error.SkipZigTest;
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
    cqes[0] = try ring.copy_cqe();
    cqes[1] = try ring.copy_cqe();

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

        try testing.expect(cqe.user_data == 0x88888888 or cqe.user_data == 0x99999999);

        if (cqe.user_data == 0x88888888) {
            try testing.expectEqual(linux.io_uring_cqe{
                .user_data = 0x88888888,
                .res = -@as(i32, @intFromEnum(linux.E.CANCELED)),
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
                if (cqe.res != -@as(i32, @intFromEnum(linux.E.INTR)) and
                    cqe.res != -@as(i32, @intFromEnum(linux.E.CANCELED)))
                {
                    std.debug.print("Req 0x{x} got {d}\n", .{ cqe.user_data, cqe.res });
                    try testing.expect(false);
                }
            },
            0x22222222 => {
                if (cqe.res != -@as(i32, @intFromEnum(linux.E.ALREADY)) and
                    cqe.res != -@as(i32, @intFromEnum(linux.E.TIME)))
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

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "test_io_uring_fallocate";
    const file = try tmp.dir.createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer file.close();

    try testing.expectEqual(@as(u64, 0), (try file.stat()).size);

    const len: u64 = 65536;
    const sqe = try ring.fallocate(0xaaaaaaaa, file.handle, 0, 0, len);
    try testing.expectEqual(linux.IORING_OP.FALLOCATE, sqe.opcode);
    try testing.expectEqual(file.handle, sqe.fd);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement fallocate():
        .INVAL => return error.SkipZigTest,
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

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = "test_io_uring_statx";
    const file = try tmp.dir.createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer file.close();

    try testing.expectEqual(@as(u64, 0), (try file.stat()).size);

    try file.writeAll("foobar");

    var buf: linux.Statx = undefined;
    const sqe = try ring.statx(
        0xaaaaaaaa,
        tmp.dir.fd,
        path,
        0,
        linux.STATX_SIZE,
        &buf,
    );
    try testing.expectEqual(linux.IORING_OP.STATX, sqe.opcode);
    try testing.expectEqual(@as(i32, tmp.dir.fd), sqe.fd);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement statx():
        .INVAL => return error.SkipZigTest,
        // This kernel does not implement statx():
        .NOSYS => return error.SkipZigTest,
        // The filesystem containing the file referred to by fd does not support this operation;
        // or the mode is not supported by the filesystem containing the file referred to by fd:
        .OPNOTSUPP => return error.SkipZigTest,
        // not supported on older kernels (5.4)
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

    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xffffffff,
        .res = -@as(i32, @intFromEnum(linux.E.CANCELED)),
        .flags = 0,
    }, cqe_recv);

    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0x99999999,
        .res = 0,
        .flags = 0,
    }, cqe_cancel);
}

test "register_files_update" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try os.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
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

    const fd2 = try os.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer os.close(fd2);

    registered_fds[fd_index] = fd2;
    registered_fds[fd_index2] = -1;
    try ring.register_files_update(0, registered_fds[0..]);

    var buffer = [_]u8{42} ** 128;
    {
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

    try ring.unregister_files();
}

test "shutdown" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var address = try net.Address.parseIp4("127.0.0.1", 0);

    // Socket bound, expect shutdown to work
    {
        const server = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
        defer os.close(server);
        try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
        try os.bind(server, &address.any, address.getOsSockLen());
        try os.listen(server, 1);

        // set address to the OS-chosen IP/port.
        var slen: os.socklen_t = address.getOsSockLen();
        try os.getsockname(server, &address.any, &slen);

        const shutdown_sqe = try ring.shutdown(0x445445445, server, os.linux.SHUT.RD);
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

        const shutdown_sqe = ring.shutdown(0x445445445, server, os.linux.SHUT.RD) catch |err| switch (err) {
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

    const old_path = "test_io_uring_renameat_old";
    const new_path = "test_io_uring_renameat_new";

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Write old file with data

    const old_file = try tmp.dir.createFile(old_path, .{ .truncate = true, .mode = 0o666 });
    defer old_file.close();
    try old_file.writeAll("hello");

    // Submit renameat

    const sqe = try ring.renameat(
        0x12121212,
        tmp.dir.fd,
        old_path,
        tmp.dir.fd,
        new_path,
        0,
    );
    try testing.expectEqual(linux.IORING_OP.RENAMEAT, sqe.opcode);
    try testing.expectEqual(@as(i32, tmp.dir.fd), sqe.fd);
    try testing.expectEqual(@as(i32, tmp.dir.fd), @as(i32, @bitCast(sqe.len)));
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
        _ = tmp.dir.openFile(old_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {},
            else => std.debug.panic("unexpected error: {}", .{err}),
        };
    }

    // Validate that the new file exists with the proper content
    {
        const new_file = try tmp.dir.openFile(new_path, .{});
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

    const path = "test_io_uring_unlinkat";

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Write old file with data

    const file = try tmp.dir.createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer file.close();

    // Submit unlinkat

    const sqe = try ring.unlinkat(
        0x12121212,
        tmp.dir.fd,
        path,
        0,
    );
    try testing.expectEqual(linux.IORING_OP.UNLINKAT, sqe.opcode);
    try testing.expectEqual(@as(i32, tmp.dir.fd), sqe.fd);
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
    _ = tmp.dir.openFile(path, .{}) catch |err| switch (err) {
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

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "test_io_uring_mkdirat";

    // Submit mkdirat

    const sqe = try ring.mkdirat(
        0x12121212,
        tmp.dir.fd,
        path,
        0o0755,
    );
    try testing.expectEqual(linux.IORING_OP.MKDIRAT, sqe.opcode);
    try testing.expectEqual(@as(i32, tmp.dir.fd), sqe.fd);
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
    _ = try tmp.dir.openDir(path, .{});
}

test "symlinkat" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "test_io_uring_symlinkat";
    const link_path = "test_io_uring_symlinkat_link";

    const file = try tmp.dir.createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer file.close();

    // Submit symlinkat

    const sqe = try ring.symlinkat(
        0x12121212,
        path,
        tmp.dir.fd,
        link_path,
    );
    try testing.expectEqual(linux.IORING_OP.SYMLINKAT, sqe.opcode);
    try testing.expectEqual(@as(i32, tmp.dir.fd), sqe.fd);
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
    _ = try tmp.dir.openFile(link_path, .{});
}

test "linkat" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const first_path = "test_io_uring_linkat_first";
    const second_path = "test_io_uring_linkat_second";

    // Write file with data

    const first_file = try tmp.dir.createFile(first_path, .{ .truncate = true, .mode = 0o666 });
    defer first_file.close();
    try first_file.writeAll("hello");

    // Submit linkat

    const sqe = try ring.linkat(
        0x12121212,
        tmp.dir.fd,
        first_path,
        tmp.dir.fd,
        second_path,
        0,
    );
    try testing.expectEqual(linux.IORING_OP.LINKAT, sqe.opcode);
    try testing.expectEqual(@as(i32, tmp.dir.fd), sqe.fd);
    try testing.expectEqual(@as(i32, tmp.dir.fd), @as(i32, @bitCast(sqe.len)));
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
    const second_file = try tmp.dir.openFile(second_path, .{});
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

    const fd = try os.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer os.close(fd);

    const group_id = 1337;
    const buffer_id = 0;

    const buffer_len = 128;

    var buffers: [4][buffer_len]u8 = undefined;

    // Provide 4 buffers

    {
        const sqe = try ring.provide_buffers(0xcccccccc, @as([*]u8, @ptrCast(&buffers)), buffer_len, buffers.len, group_id, buffer_id);
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
        const sqe = try ring.read(0xdededede, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
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
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer_len), buffers[used_buffer_id][0..@as(usize, @intCast(cqe.res))]);
    }

    // This read should fail

    {
        const sqe = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
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
    @memset(mem.sliceAsBytes(&buffers), 42);

    const reprovided_buffer_id = 2;

    {
        _ = try ring.provide_buffers(0xabababab, @as([*]u8, @ptrCast(&buffers[reprovided_buffer_id])), buffer_len, 1, group_id, reprovided_buffer_id);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
    }

    // Final read which should work

    {
        const sqe = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
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
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer_len), buffers[used_buffer_id][0..@as(usize, @intCast(cqe.res))]);
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

    const fd = try os.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer os.close(fd);

    const group_id = 1337;
    const buffer_id = 0;

    const buffer_len = 128;

    var buffers: [4][buffer_len]u8 = undefined;

    // Provide 4 buffers

    {
        _ = try ring.provide_buffers(0xcccccccc, @as([*]u8, @ptrCast(&buffers)), buffer_len, buffers.len, group_id, buffer_id);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .INVAL => return error.SkipZigTest,
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(@as(u64, 0xcccccccc), cqe.user_data);
    }

    // Remove 3 buffers

    {
        const sqe = try ring.remove_buffers(0xbababababa, 3, group_id);
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
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer_len), buffers[used_buffer_id][0..@as(usize, @intCast(cqe.res))]);
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

    const group_id = 1337;
    const buffer_id = 0;

    const buffer_len = 128;
    var buffers: [4][buffer_len]u8 = undefined;

    // Provide 4 buffers

    {
        const sqe = try ring.provide_buffers(0xcccccccc, @as([*]u8, @ptrCast(&buffers)), buffer_len, buffers.len, group_id, buffer_id);
        try testing.expectEqual(linux.IORING_OP.PROVIDE_BUFFERS, sqe.opcode);
        try testing.expectEqual(@as(i32, buffers.len), sqe.fd);
        try testing.expectEqual(@as(u32, buffer_len), sqe.len);
        try testing.expectEqual(@as(u16, group_id), sqe.buf_index);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Happens when the kernel is < 5.7
            .INVAL => return error.SkipZigTest,
            // Happens on the kernel 5.4
            .BADF => return error.SkipZigTest,
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
    @memset(mem.sliceAsBytes(&buffers), 1);

    var i: usize = 0;
    while (i < buffers.len) : (i += 1) {
        const sqe = try ring.recv(0xdededede, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
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
        const buffer = buffers[used_buffer_id][0..@as(usize, @intCast(cqe.res))];
        try testing.expectEqualSlices(u8, &([_]u8{'z'} ** buffer_len), buffer);
    }

    // This recv should fail

    {
        const sqe = try ring.recv(0xdfdfdfdf, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
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
        _ = try ring.provide_buffers(0xabababab, @as([*]u8, @ptrCast(&buffers[reprovided_buffer_id])), buffer_len, 1, group_id, reprovided_buffer_id);
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
    @memset(mem.sliceAsBytes(&buffers), 1);

    {
        const sqe = try ring.recv(0xdfdfdfdf, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
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
        const buffer = buffers[used_buffer_id][0..@as(usize, @intCast(cqe.res))];
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
    var address = try net.Address.parseIp4("127.0.0.1", 0);
    const listener_socket = try createListenerSocket(&address);
    errdefer os.closeSocket(listener_socket);

    // Submit 1 accept
    var accept_addr: os.sockaddr = undefined;
    var accept_addr_len: os.socklen_t = @sizeOf(@TypeOf(accept_addr));
    _ = try ring.accept(0xaaaaaaaa, listener_socket, &accept_addr, &accept_addr_len, 0);

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

fn createListenerSocket(address: *net.Address) !os.socket_t {
    const kernel_backlog = 1;
    const listener_socket = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
    errdefer os.closeSocket(listener_socket);

    try os.setsockopt(listener_socket, os.SOL.SOCKET, os.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
    try os.bind(listener_socket, &address.any, address.getOsSockLen());
    try os.listen(listener_socket, kernel_backlog);

    // set address to the OS-chosen IP/port.
    var slen: os.socklen_t = address.getOsSockLen();
    try os.getsockname(listener_socket, &address.any, &slen);

    return listener_socket;
}

test "accept multishot" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var address = try net.Address.parseIp4("127.0.0.1", 0);
    const listener_socket = try createListenerSocket(&address);
    defer os.closeSocket(listener_socket);

    // submit multishot accept operation
    var addr: os.sockaddr = undefined;
    var addr_len: os.socklen_t = @sizeOf(@TypeOf(addr));
    const userdata: u64 = 0xaaaaaaaa;
    _ = try ring.accept_multishot(userdata, listener_socket, &addr, &addr_len, 0);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    var nr: usize = 4; // number of clients to connect
    while (nr > 0) : (nr -= 1) {
        // connect client
        const client = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
        errdefer os.closeSocket(client);
        try os.connect(client, &address.any, address.getOsSockLen());

        // test accept completion
        var cqe = try ring.copy_cqe();
        if (cqe.err() == .INVAL) return error.SkipZigTest;
        try testing.expect(cqe.res > 0);
        try testing.expect(cqe.user_data == userdata);
        try testing.expect(cqe.flags & linux.IORING_CQE_F_MORE > 0); // more flag is set

        os.closeSocket(client);
    }
}

test "accept/connect/send_zc/recv" {
    try skipKernelLessThan(.{ .major = 6, .minor = 0, .patch = 0 });

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    const buffer_send = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xa, 0xb, 0xc, 0xd, 0xe };
    var buffer_recv = [_]u8{0} ** 10;

    // zero-copy send
    const send = try ring.send_zc(0xeeeeeeee, socket_test_harness.client, buffer_send[0..], 0, 0);
    send.flags |= linux.IOSQE_IO_LINK;
    _ = try ring.recv(0xffffffff, socket_test_harness.server, .{ .buffer = buffer_recv[0..] }, 0);
    try testing.expectEqual(@as(u32, 2), try ring.submit());

    // First completion of zero-copy send.
    // IORING_CQE_F_MORE, means that there
    // will be a second completion event / notification for the
    // request, with the user_data field set to the same value.
    // buffer_send must be keep alive until second cqe.
    var cqe_send = try ring.copy_cqe();
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xeeeeeeee,
        .res = buffer_send.len,
        .flags = linux.IORING_CQE_F_MORE,
    }, cqe_send);

    const cqe_recv = try ring.copy_cqe();
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xffffffff,
        .res = buffer_recv.len,
        .flags = cqe_recv.flags & linux.IORING_CQE_F_SOCK_NONEMPTY,
    }, cqe_recv);

    try testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);

    // Second completion of zero-copy send.
    // IORING_CQE_F_NOTIF in flags signals that kernel is done with send_buffer
    cqe_send = try ring.copy_cqe();
    try testing.expectEqual(linux.io_uring_cqe{
        .user_data = 0xeeeeeeee,
        .res = 0,
        .flags = linux.IORING_CQE_F_NOTIF,
    }, cqe_send);
}

test "accept_direct" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    var address = try net.Address.parseIp4("127.0.0.1", 0);

    // register direct file descriptors
    var registered_fds = [_]os.fd_t{-1} ** 2;
    try ring.register_files(registered_fds[0..]);

    const listener_socket = try createListenerSocket(&address);
    defer os.closeSocket(listener_socket);

    const accept_userdata: u64 = 0xaaaaaaaa;
    const read_userdata: u64 = 0xbbbbbbbb;
    const data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xa, 0xb, 0xc, 0xd, 0xe };

    for (0..2) |_| {
        for (registered_fds, 0..) |_, i| {
            var buffer_recv = [_]u8{0} ** 16;
            const buffer_send: []const u8 = data[0 .. data.len - i]; // make it different at each loop

            // submit accept, will chose registered fd and return index in cqe
            _ = try ring.accept_direct(accept_userdata, listener_socket, null, null, 0);
            try testing.expectEqual(@as(u32, 1), try ring.submit());

            // connect
            const client = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
            try os.connect(client, &address.any, address.getOsSockLen());
            defer os.closeSocket(client);

            // accept completion
            const cqe_accept = try ring.copy_cqe();
            try testing.expectEqual(os.E.SUCCESS, cqe_accept.err());
            const fd_index = cqe_accept.res;
            try testing.expect(fd_index < registered_fds.len);
            try testing.expect(cqe_accept.user_data == accept_userdata);

            // send data
            _ = try os.send(client, buffer_send, 0);

            // Example of how to use registered fd:
            // Submit receive to fixed file returned by accept (fd_index).
            // Fd field is set to registered file index, returned by accept.
            // Flag linux.IOSQE_FIXED_FILE must be set.
            const recv_sqe = try ring.recv(read_userdata, fd_index, .{ .buffer = &buffer_recv }, 0);
            recv_sqe.flags |= linux.IOSQE_FIXED_FILE;
            try testing.expectEqual(@as(u32, 1), try ring.submit());

            // accept receive
            const recv_cqe = try ring.copy_cqe();
            try testing.expect(recv_cqe.user_data == read_userdata);
            try testing.expect(recv_cqe.res == buffer_send.len);
            try testing.expectEqualSlices(u8, buffer_send, buffer_recv[0..buffer_send.len]);
        }
        // no more available fds, accept will get NFILE error
        {
            // submit accept
            _ = try ring.accept_direct(accept_userdata, listener_socket, null, null, 0);
            try testing.expectEqual(@as(u32, 1), try ring.submit());
            // connect
            const client = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
            try os.connect(client, &address.any, address.getOsSockLen());
            defer os.closeSocket(client);
            // completion with error
            const cqe_accept = try ring.copy_cqe();
            try testing.expect(cqe_accept.user_data == accept_userdata);
            try testing.expectEqual(os.E.NFILE, cqe_accept.err());
        }
        // return file descriptors to kernel
        try ring.register_files_update(0, registered_fds[0..]);
    }
    try ring.unregister_files();
}

test "accept_multishot_direct" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var address = try net.Address.parseIp4("127.0.0.1", 0);

    var registered_fds = [_]os.fd_t{-1} ** 2;
    try ring.register_files(registered_fds[0..]);

    const listener_socket = try createListenerSocket(&address);
    defer os.closeSocket(listener_socket);

    const accept_userdata: u64 = 0xaaaaaaaa;

    for (0..2) |_| {
        // submit multishot accept
        // Will chose registered fd and return index of the selected registered file in cqe.
        _ = try ring.accept_multishot_direct(accept_userdata, listener_socket, null, null, 0);
        try testing.expectEqual(@as(u32, 1), try ring.submit());

        for (registered_fds) |_| {
            // connect
            const client = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
            try os.connect(client, &address.any, address.getOsSockLen());
            defer os.closeSocket(client);

            // accept completion
            const cqe_accept = try ring.copy_cqe();
            const fd_index = cqe_accept.res;
            try testing.expect(fd_index < registered_fds.len);
            try testing.expect(cqe_accept.user_data == accept_userdata);
            try testing.expect(cqe_accept.flags & linux.IORING_CQE_F_MORE > 0); // has more is set
        }
        // No more available fds, accept will get NFILE error.
        // Multishot is terminated (more flag is not set).
        {
            // connect
            const client = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
            try os.connect(client, &address.any, address.getOsSockLen());
            defer os.closeSocket(client);
            // completion with error
            const cqe_accept = try ring.copy_cqe();
            try testing.expect(cqe_accept.user_data == accept_userdata);
            try testing.expectEqual(os.E.NFILE, cqe_accept.err());
            try testing.expect(cqe_accept.flags & linux.IORING_CQE_F_MORE == 0); // has more is not set
        }
        // return file descriptors to kernel
        try ring.register_files_update(0, registered_fds[0..]);
    }
    try ring.unregister_files();
}

test "socket" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IO_Uring.init(1, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    // prepare, submit socket operation
    _ = try ring.socket(0, linux.AF.INET, os.SOCK.STREAM, 0, 0);
    try testing.expectEqual(@as(u32, 1), try ring.submit());

    // test completion
    var cqe = try ring.copy_cqe();
    try testing.expectEqual(os.E.SUCCESS, cqe.err());
    const fd: os.fd_t = @intCast(cqe.res);
    try testing.expect(fd > 2);

    os.close(fd);
}

test "socket_direct/socket_direct_alloc/close_direct" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IO_Uring.init(2, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var registered_fds = [_]os.fd_t{-1} ** 3;
    try ring.register_files(registered_fds[0..]);

    // create socket in registered file descriptor at index 0 (last param)
    _ = try ring.socket_direct(0, linux.AF.INET, os.SOCK.STREAM, 0, 0, 0);
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    var cqe_socket = try ring.copy_cqe();
    try testing.expectEqual(os.E.SUCCESS, cqe_socket.err());
    try testing.expect(cqe_socket.res == 0);

    // create socket in registered file descriptor at index 1 (last param)
    _ = try ring.socket_direct(0, linux.AF.INET, os.SOCK.STREAM, 0, 0, 1);
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    cqe_socket = try ring.copy_cqe();
    try testing.expectEqual(os.E.SUCCESS, cqe_socket.err());
    try testing.expect(cqe_socket.res == 0); // res is 0 when index is specified

    // create socket in kernel chosen file descriptor index (_alloc version)
    // completion res has index from registered files
    _ = try ring.socket_direct_alloc(0, linux.AF.INET, os.SOCK.STREAM, 0, 0);
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    cqe_socket = try ring.copy_cqe();
    try testing.expectEqual(os.E.SUCCESS, cqe_socket.err());
    try testing.expect(cqe_socket.res == 2); // returns registered file index

    // use sockets from registered_fds in connect operation
    var address = try net.Address.parseIp4("127.0.0.1", 0);
    const listener_socket = try createListenerSocket(&address);
    defer os.closeSocket(listener_socket);
    const accept_userdata: u64 = 0xaaaaaaaa;
    const connect_userdata: u64 = 0xbbbbbbbb;
    const close_userdata: u64 = 0xcccccccc;
    for (registered_fds, 0..) |_, fd_index| {
        // prepare accept
        _ = try ring.accept(accept_userdata, listener_socket, null, null, 0);
        // prepare connect with fixed socket
        const connect_sqe = try ring.connect(connect_userdata, @intCast(fd_index), &address.any, address.getOsSockLen());
        connect_sqe.flags |= linux.IOSQE_FIXED_FILE; // fd is fixed file index
        // submit both
        try testing.expectEqual(@as(u32, 2), try ring.submit());
        // get completions
        var cqe_connect = try ring.copy_cqe();
        var cqe_accept = try ring.copy_cqe();
        // ignore order
        if (cqe_connect.user_data == accept_userdata and cqe_accept.user_data == connect_userdata) {
            const a = cqe_accept;
            const b = cqe_connect;
            cqe_accept = b;
            cqe_connect = a;
        }
        // test connect completion
        try testing.expect(cqe_connect.user_data == connect_userdata);
        try testing.expectEqual(os.E.SUCCESS, cqe_connect.err());
        // test accept completion
        try testing.expect(cqe_accept.user_data == accept_userdata);
        try testing.expectEqual(os.E.SUCCESS, cqe_accept.err());

        //  submit and test close_direct
        _ = try ring.close_direct(close_userdata, @intCast(fd_index));
        try testing.expectEqual(@as(u32, 1), try ring.submit());
        var cqe_close = try ring.copy_cqe();
        try testing.expect(cqe_close.user_data == close_userdata);
        try testing.expectEqual(os.E.SUCCESS, cqe_close.err());
    }

    try ring.unregister_files();
}

test "openat_direct/close_direct" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IO_Uring.init(2, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var registered_fds = [_]os.fd_t{-1} ** 3;
    try ring.register_files(registered_fds[0..]);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = "test_io_uring_close_direct";
    const flags: linux.O = .{ .ACCMODE = .RDWR, .CREAT = true };
    const mode: os.mode_t = 0o666;
    const user_data: u64 = 0;

    // use registered file at index 0 (last param)
    _ = try ring.openat_direct(user_data, tmp.dir.fd, path, flags, mode, 0);
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    var cqe = try ring.copy_cqe();
    try testing.expectEqual(os.E.SUCCESS, cqe.err());
    try testing.expect(cqe.res == 0);

    // use registered file at index 1
    _ = try ring.openat_direct(user_data, tmp.dir.fd, path, flags, mode, 1);
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    cqe = try ring.copy_cqe();
    try testing.expectEqual(os.E.SUCCESS, cqe.err());
    try testing.expect(cqe.res == 0); // res is 0 when we specify index

    // let kernel choose registered file index
    _ = try ring.openat_direct(user_data, tmp.dir.fd, path, flags, mode, linux.IORING_FILE_INDEX_ALLOC);
    try testing.expectEqual(@as(u32, 1), try ring.submit());
    cqe = try ring.copy_cqe();
    try testing.expectEqual(os.E.SUCCESS, cqe.err());
    try testing.expect(cqe.res == 2); // chosen index is in res

    // close all open file descriptors
    for (registered_fds, 0..) |_, fd_index| {
        _ = try ring.close_direct(user_data, @intCast(fd_index));
        try testing.expectEqual(@as(u32, 1), try ring.submit());
        var cqe_close = try ring.copy_cqe();
        try testing.expectEqual(os.E.SUCCESS, cqe_close.err());
    }
    try ring.unregister_files();
}

test "waitid" {
    try skipKernelLessThan(.{ .major = 6, .minor = 7, .patch = 0 });

    var ring = IO_Uring.init(16, 0) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const pid = try os.fork();
    if (pid == 0) {
        os.exit(7);
    }

    var siginfo: os.siginfo_t = undefined;
    _ = try ring.waitid(0, .PID, pid, &siginfo, os.W.EXITED, 0);

    try testing.expectEqual(1, try ring.submit());

    const cqe_waitid = try ring.copy_cqe();
    try testing.expectEqual(0, cqe_waitid.res);
    try testing.expectEqual(pid, siginfo.fields.common.first.piduid.pid);
    try testing.expectEqual(7, siginfo.fields.common.second.sigchld.status);
}

/// For use in tests. Returns SkipZigTest is kernel version is less than required.
inline fn skipKernelLessThan(required: std.SemanticVersion) !void {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    var uts: linux.utsname = undefined;
    const res = linux.uname(&uts);
    switch (linux.getErrno(res)) {
        .SUCCESS => {},
        else => |errno| return os.unexpectedErrno(errno),
    }

    const release = mem.sliceTo(&uts.release, 0);
    var current = try std.SemanticVersion.parse(release);
    current.pre = null; // don't check pre field
    if (required.order(current) == .gt) return error.SkipZigTest;
}
