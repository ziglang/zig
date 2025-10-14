const IoUring = @This();
const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const net = std.Io.net;
const posix = std.posix;
const linux = std.os.linux;
const testing = std.testing;
const is_linux = builtin.os.tag == .linux;
const page_size_min = std.heap.page_size_min;

fd: posix.fd_t = -1,
sq: Sq,
cq: Cq,
flags: uflags.Setup,
features: uflags.Features,

/// A friendly way to setup an io_uring, with default linux.io_uring_params.
/// `entries` must be a power of two between 1 and 32768, although the kernel
/// will make the final call on how many entries the submission and completion
/// queues will ultimately have,
/// see https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L8027-L8050.
/// Matches the interface of `io_uring_queue_init()` in liburing.
pub fn init(entries: u16, flags: uflags.Setup) !IoUring {
    var params = mem.zeroInit(Params, .{
        .flags = flags,
        .sq_thread_idle = 1000,
    });
    return try .init_params(entries, &params);
}

/// A powerful way to setup an io_uring, if you want to tweak
/// linux.io_uring_params such as submission queue thread cpu affinity or
/// thread idle timeout (the kernel and our default is 1 second).
/// `params` is passed by reference because the kernel needs to modify the
/// parameters.
/// Matches the interface of `io_uring_queue_init_params()` in liburing.
pub fn init_params(entries: u16, p: *Params) !IoUring {
    if (entries == 0) return error.EntriesZero;
    if (!math.isPowerOfTwo(entries)) return error.EntriesNotPowerOfTwo;
    assert(p.sq_entries == 0);
    assert(p.features.empty());
    assert(p.resv[0] == 0);
    assert(p.resv[1] == 0);
    assert(p.resv[2] == 0);

    assert(p.cq_entries == 0 or p.flags.cqsize);
    assert(p.wq_fd == 0 or p.flags.attach_wq);

    // flags compatibility
    if (p.flags.sqpoll) assert(!(p.flags.coop_taskrun or p.flags.taskrun_flag or p.flags.defer_taskrun));
    if (p.flags.sq_aff) assert(p.flags.sqpoll);
    if (p.flags.defer_taskrun) assert(p.flags.single_issuer);

    const res = linux.io_uring_setup(entries, p);
    switch (linux.errno(res)) {
        .SUCCESS => {},
        .FAULT => return error.ParamsOutsideAccessibleAddressSpace,
        // The resv array contains non-zero data, p.flags contains an
        // unsupported flag, entries out of bounds, IORING_SETUP_SQ_AFF was
        // specified without IORING_SETUP_SQPOLL, or IORING_SETUP_CQSIZE was
        // specified but linux.io_uring_params.cq_entries was invalid:
        .INVAL => return error.ArgumentsInvalid,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
        // IORING_SETUP_SQPOLL was specified but effective user ID lacks
        // sufficient privileges, or a container seccomp policy prohibits
        // io_uring syscalls:
        .PERM => return error.PermissionDenied,
        .NOSYS => return error.SystemOutdated,
        else => |errno| return posix.unexpectedErrno(errno),
    }
    const fd: linux.fd_t = @intCast(res);
    assert(fd >= 0);
    errdefer posix.close(fd);

    // Kernel versions 5.4 and up use only one mmap() for the submission and
    // completion queues.
    // This is not an optional feature for us... if the kernel does it, we have
    // to do it. The thinking on this by the kernel developers was that both
    // the submission and the completion queue rings have sizes just over a
    // power of two, but the submission queue ring is significantly smaller
    // with u32 slots. By bundling both in a single mmap, the kernel gets the
    // submission queue ring for free.
    // See https://patchwork.kernel.org/patch/11115257 for the kernel patch.
    // We do not support the double mmap() done before 5.4, because we want to
    // keep the init/deinit mmap paths simple and because io_uring has had many
    // bug fixes even since 5.4.
    if (!p.features.single_mmap) {
        return error.SystemOutdated;
    }

    // Check that the kernel has actually set params and that "impossible is nothing".
    assert(p.sq_entries != 0);
    assert(p.cq_entries != 0);
    assert(p.cq_entries >= p.sq_entries);

    // From here on, we only need to read from params, so pass `p` by value as
    // immutable.
    // The completion queue shares the mmap with the submission queue, so pass
    // `sq` there too.
    var sq: Sq = try .init(fd, p.*);
    errdefer sq.deinit();
    var cq: Cq = try .init(fd, p.*, sq);
    errdefer cq.deinit();

    // Check that our starting state is as we expect.
    assert(sq.head.* == 0);
    assert(sq.tail.* == 0);
    assert(sq.mask == p.sq_entries - 1);
    // Allow flags.* to be non-zero, since the kernel may set
    // IORING_SQ_NEED_WAKEUP at any time.
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

    return .{
        .fd = fd,
        .sq = sq,
        .cq = cq,
        .flags = p.flags,
        .features = p.features,
    };
}

pub fn deinit(self: *IoUring) void {
    assert(self.fd >= 0);
    // The mmaps depend on the fd, so the order of these calls is important:
    self.cq.deinit();
    self.sq.deinit();
    posix.close(self.fd);
    self.fd = -1;
}

/// Returns a pointer to a vacant SQE, or an error if the submission queue is
/// full. We follow the implementation (and atomics) of liburing's
/// `io_uring_get_sqe()` exactly.
/// However, instead of a null we return an error to force safe handling.
/// Any situation where the submission queue is full tends more towards a
/// control flow error, and the null return in liburing is more a C idiom than
/// anything else, for lack of a better alternative. In Zig, we have
/// first-class error handling... so let's use it.
/// Matches the implementation of `io_uring_get_sqe()` in liburing.
pub fn get_sqe(self: *IoUring) !*Sqe {
    const head = @atomicLoad(u32, self.sq.head, .acquire);
    // Remember that these head and tail offsets wrap around every four billion
    // operations. We must therefore use wrapping addition and subtraction to
    // avoid a runtime crash.
    const next = self.sq.sqe_tail +% 1;
    if (next -% head > self.sq.sqes.len) return error.SubmissionQueueFull;
    const sqe = &self.sq.sqes[self.sq.sqe_tail & self.sq.mask];
    self.sq.sqe_tail = next;
    return sqe;
}

/// Submits the SQEs acquired via `get_sqe()` to the kernel. You can call this
/// once after you have called `get_sqe()` multiple times to setup multiple I/O
/// requests.
/// Returns the number of SQEs submitted, if not used alongside
/// IORING_SETUP_SQPOLL.
/// If the io_uring instance uses IORING_SETUP_SQPOLL, the value returned on
/// success is not guaranteed to match the amount of actually submitted sqes
/// during this call. A value higher or lower, including 0, may be returned.
/// Matches the implementation of `io_uring_submit()` in liburing.
pub fn submit(self: *IoUring) !u32 {
    return self.submit_and_wait(0);
}

/// Like `submit()`, but allows waiting for events as well.
/// Returns the number of SQEs submitted.
/// Matches the implementation of `io_uring_submit_and_wait()` in liburing.
pub fn submit_and_wait(self: *IoUring, wait_nr: u32) !u32 {
    const submitted = self.flush_sq();
    var flags: uflags.Enter = .{};
    if (self.sq_ring_needs_enter(&flags) or wait_nr > 0) {
        if (wait_nr > 0 or self.flags.iopoll) {
            flags.getevents = true;
        }
        return try self.enter(submitted, wait_nr, flags);
    }
    return submitted;
}

/// Tell the kernel we have submitted SQEs and/or want to wait for CQEs.
/// Returns the number of SQEs submitted.
pub fn enter(self: *IoUring, to_submit: u32, min_complete: u32, flags: uflags.Enter) !u32 {
    assert(self.fd >= 0);
    const res = linux.io_uring_enter(self.fd, to_submit, min_complete, flags, null);
    switch (linux.errno(res)) {
        .SUCCESS => {},
        // The kernel was unable to allocate memory or ran out of resources for
        // the request. The application should wait for some completions and
        // try again:
        .AGAIN => return error.SystemResources,
        // The SQE `fd` is invalid, or IOSQE_FIXED_FILE was set but no files
        // were registered:
        .BADF => return error.FileDescriptorInvalid,
        // The file descriptor is valid, but the ring is not in the right state.
        // See io_uring_register(2) for how to enable the ring.
        .BADFD => return error.FileDescriptorInBadState,
        // The application attempted to overcommit the number of requests it
        // can have pending. The application should wait for some completions
        // and try again:
        .BUSY => return error.CompletionQueueOvercommitted,
        // The SQE is invalid, or valid but the ring was setup with
        // IORING_SETUP_IOPOLL:
        .INVAL => return error.SubmissionQueueEntryInvalid,
        // The buffer is outside the process' accessible address space, or
        // IORING_OP_READ_FIXED or IORING_OP_WRITE_FIXED was specified but no
        // buffers were registered, or the range described by `addr` and `len`
        // is not within the buffer registered at `buf_index`:
        .FAULT => return error.BufferInvalid,
        .NXIO => return error.RingShuttingDown,
        // The kernel believes our `self.fd` does not refer to an io_uring
        // instance, or the opcode is valid but not supported by this kernel
        // (more likely):
        .OPNOTSUPP => return error.OpcodeNotSupported,
        // The operation was interrupted by a delivery of a signal before it
        // could complete. This can happen while waiting for events with
        // IORING_ENTER_GETEVENTS:
        .INTR => return error.SignalInterrupt,
        else => |errno| return posix.unexpectedErrno(errno),
    }
    return @intCast(res);
}

/// Sync internal state with kernel ring state on the SQ side.
/// Returns the number of all pending events in the SQ ring, for the shared
/// ring. This return value includes previously flushed SQEs, as per liburing.
/// The rationale is to suggest that an `io_uring_enter()` call is needed rather
/// than not.
/// Matches the implementation of `__io_uring_flush_sq()` in liburing.
pub fn flush_sq(self: *IoUring) u32 {
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
        // Ensure that the kernel can actually see the SQE updates when it sees
        // the tail update.
        @atomicStore(u32, self.sq.tail, tail, .release);
    }
    return self.sq_ready();
}

/// Returns true if we are not using an SQ thread (thus nobody submits but us),
/// or if IORING_SQ_NEED_WAKEUP is set and the SQ thread must be explicitly
/// awakened. For the latter case, we set the SQ thread wakeup flag.
/// Matches the implementation of `sq_ring_needs_enter()` in liburing.
pub fn sq_ring_needs_enter(self: *IoUring, flags: *uflags.Enter) bool {
    assert(flags.*.empty());
    if (!self.flags.sqpoll) return true;
    if (@atomicLoad(Sq.Flags, self.sq.flags, .unordered).need_wakeup) {
        flags.*.sq_wakeup = true;
        return true;
    }
    return false;
}

/// Returns the number of flushed and unflushed SQEs pending in the submission
/// queue. In other words, this is the number of SQEs in the submission queue,
/// i.e. its length. These are SQEs that the kernel is yet to consume.
/// Matches the implementation of `io_uring_sq_ready()` in liburing.
pub fn sq_ready(self: *IoUring) u32 {
    // Always use the shared ring state (i.e. head and not sqe_head) to avoid
    // going out of sync, see https://github.com/axboe/liburing/issues/92.
    return self.sq.sqe_tail -% @atomicLoad(u32, self.sq.head, .acquire);
}

/// Returns the number of CQEs in the completion queue, i.e. its length.
/// These are CQEs that the application is yet to consume.
/// Matches the implementation of `io_uring_cq_ready()` in liburing.
pub fn cq_ready(self: *IoUring) u32 {
    return @atomicLoad(u32, self.cq.tail, .acquire) -% self.cq.head.*;
}

/// Copies as many CQEs as are ready, and that can fit into the destination
/// `cqes` slice. If none are available, enters into the kernel to wait for at
/// most `wait_nr` CQEs.
/// Returns the number of CQEs copied, advancing the CQ ring.
/// Provides all the wait/peek methods found in liburing, but with batching and
/// a single method.
/// The rationale for copying CQEs rather than copying pointers is that
/// pointers are 8 bytes whereas CQEs are not much more at only 16 bytes, and
/// this provides a safer faster interface.
/// Safer, because you no longer need to call `cqe_seen()`, avoiding idempotency
/// bugs. Faster, because we can now amortize the atomic store release to
/// `cq.head` across the batch.
/// See https://github.com/axboe/liburing/issues/103#issuecomment-686665007.
/// Matches the implementation of `io_uring_peek_batch_cqe()` in liburing, but
/// supports waiting.
pub fn copy_cqes(self: *IoUring, cqes: []Cqe, wait_nr: u32) !u32 {
    const count = self.copy_cqes_ready(cqes);
    if (count > 0) return count;
    if (self.cq_ring_needs_flush() or wait_nr > 0) {
        _ = try self.enter(0, wait_nr, .{ .getevents = true });
        return self.copy_cqes_ready(cqes);
    }
    return 0;
}

fn copy_cqes_ready(self: *IoUring, cqes: []Cqe) u32 {
    const ready = self.cq_ready();
    const count = @min(cqes.len, ready);
    const head = self.cq.head.* & self.cq.mask;

    // before wrapping
    const n = @min(self.cq.cqes.len - head, count);
    @memcpy(cqes[0..n], self.cq.cqes[head..][0..n]);

    if (count > n) {
        // wrap self.cq.cqes
        const w = count - n;
        @memcpy(cqes[n..][0..w], self.cq.cqes[0..w]);
    }

    self.cq_advance(count);
    return count;
}

/// Returns a copy of an I/O completion, waiting for it if necessary, and
/// advancing the CQ ring.
/// A convenience method for `copy_cqes()` for when you don't need to batch or
/// peek.
pub fn copy_cqe(ring: *IoUring) !Cqe {
    var cqes: [1]Cqe = undefined;
    while (true) {
        const count = try ring.copy_cqes(&cqes, 1);
        if (count > 0) return cqes[0];
    }
}

/// Matches the implementation of `cq_ring_needs_flush()` in liburing.
pub fn cq_ring_needs_flush(self: *IoUring) bool {
    const sq_flags = @atomicLoad(Sq.Flags, self.sq.flags, .unordered);
    if (sq_flags.cq_overflow or sq_flags.taskrun) return true;
    return false;
}

/// For advanced use cases only that implement custom completion queue methods.
/// If you use `copy_cqes()` or `copy_cqe()` you must not call `cqe_seen()` or
/// `cq_advance()`. Must be called exactly once after a zero-copy CQE has been
/// processed by your application.
/// Not idempotent, calling more than once will result in other CQEs being lost.
/// Matches the implementation of `cqe_seen()` in liburing.
pub fn cqe_seen(self: *IoUring, cqe: *Cqe) void {
    _ = cqe;
    self.cq_advance(1);
}

/// For advanced use cases only that implement custom completion queue methods.
/// Matches the implementation of `cq_advance()` in liburing.
pub fn cq_advance(self: *IoUring, count: u32) void {
    if (count > 0) {
        // Ensure the kernel only sees the new head value after the CQEs have
        // been read.
        @atomicStore(u32, self.cq.head, self.cq.head.* +% count, .release);
    }
}

/// Queues (but does not submit) an SQE to perform a `splice(2)`
/// Either `fd_in` or `fd_out` must be a pipe.
/// If `fd_in` refers to a pipe, `off_in` is ignored and must be set to
/// math.maxInt(u64).
/// If `fd_in` does not refer to a pipe and `off_in` is maxInt(u64), then `len`
/// are read from `fd_in` starting from the file offset, which is incremented
/// by the number of bytes read.
/// If `fd_in` does not refer to a pipe and `off_in` is not maxInt(u64), then
/// the starting offset of `fd_in` will be `off_in`.
///
/// This splice operation can be used to implement sendfile by splicing to an
/// intermediate pipe first, then splice to the final destination. In fact, the
/// implementation of sendfile in kernel uses splice internally.
///
/// NOTE that even if `fd_in` or `fd_out` refers to a pipe, the splice operation
/// can still fail with EINVAL if one of the fd doesn't explicitly support
/// splice operation, e.g. reading from terminal is unsupported from kernel 5.7
/// to 5.11. See https://github.com/axboe/liburing/issues/291
///
/// Returns a pointer to the SQE so that you can further modify the SQE for
/// advanced use cases.
pub fn splice(
    self: *IoUring,
    user_data: u64,
    fd_in: posix.fd_t,
    off_in: u64,
    fd_out: posix.fd_t,
    off_out: u64,
    len: usize,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_splice(fd_in, off_in, fd_out, off_out, len);
    sqe.user_data = user_data;
    return sqe;
}

// COMMIT: ignored flags for splice and tee lets see if they become important
// in the future
pub fn tee(
    self: *IoUring,
    user_data: u64,
    fd_in: posix.fd_t,
    fd_out: posix.fd_t,
    len: usize,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_tee(fd_in, fd_out, len);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `pread(2)` or `preadv(2)`
/// depending on the buffer type.
/// * Reading into a `ReadBuffer.buffer` uses `pread(2)`
/// * Reading into a `ReadBuffer.iovecs` uses `preadv(2)`
///
/// If you want to do a `preadv2(2)` then set `rw_flags` on the returned SQE.
/// See https://man7.org/linux/man-pages/man2/preadv2.2.html
///
/// Returns a pointer to the SQE.
pub fn read(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    buffer: ReadBuffer,
    offset: u64,
) !*Sqe {
    const sqe = try self.get_sqe();
    switch (buffer) {
        .buffer => |slice| sqe.prep_read(fd, slice, offset),
        .iovecs => |vecs| sqe.prep_readv(fd, vecs, offset),
        .buffer_selection => |selection| {
            sqe.prep_rw(.read, fd, 0, selection.len, offset);
            sqe.flags.buffer_select = true;
            sqe.buf_index = selection.group_id;
        },
    }
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a IORING_OP_READ_FIXED.
/// The `buffer` provided must be registered with the kernel by calling
/// `register_buffers()` first. The `buffer_index` must be the same as its
/// index in the array provided to `register_buffers()`.
///
/// Returns a pointer to the SQE so that you can further modify the SQE for
/// advanced use cases.
pub fn read_fixed(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    buffer: ReadBuffer,
    offset: u64,
    buffer_index: u16,
) !*Sqe {
    const sqe = try self.get_sqe();
    switch (buffer) {
        .buffer => |slice| sqe.prep_read_fixed(fd, slice, offset, buffer_index),
        .iovecs => |vecs| sqe.prep_readv_fixed(fd, vecs, offset, buffer_index),
        .buffer_selection => |selection| {
            sqe.prep_rw(.read_fixed, fd, 0, selection.len, offset);
            sqe.flags.buffer_select = true;
            sqe.buf_index = selection.group_id;
        },
    }
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `pwrite(2)` or `pwritev(2)`
/// depending on the write buffer type.
/// * Reading into a `WriteBuffer.buffer` uses `pwrite(2)`
/// * Reading into a `WriteBuffer.iovecs` uses `pwritev(2)`
///
/// Returns a pointer to the SQE so that you can further modify the SQE for
/// advanced use cases.
/// For example, if you want to do a `pwritev2()` then set `rw_flags` on the
/// returned SQE. See https://linux.die.net/man/2/pwritev.
pub fn write(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    buffer: WriteBuffer,
    offset: u64,
) !*Sqe {
    const sqe = try self.get_sqe();
    switch (buffer) {
        .buffer => |slice| sqe.prep_write(fd, slice, offset),
        .iovecs => |vecs| sqe.prep_writev(fd, vecs, offset),
    }
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a IORING_OP_WRITE_FIXED.
/// The `buffer` provided must be registered with the kernel by calling
/// `register_buffers()` first. The `buffer_index` must be the same as its index
/// in the array provided to `register_buffers()`.
///
/// Returns a pointer to the SQE so that you can further modify the SQE for
/// advanced use cases.
pub fn write_fixed(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    buffer: WriteBuffer,
    offset: u64,
    buffer_index: u16,
) !*Sqe {
    const sqe = try self.get_sqe();
    switch (buffer) {
        .buffer => |slice| {
            sqe.prep_write_fixed(fd, slice, offset, buffer_index);
        },
        .iovecs => |vecs| {
            sqe.prep_writev_fixed(fd, vecs, offset, buffer_index);
        },
    }
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `recvmsg(2)`.
/// Returns a pointer to the SQE.
/// Available since 5.3
pub fn recvmsg(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    msg: *posix.msghdr,
    flags: linux.Msg,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_recvmsg(fd, msg, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a multishot `recvmsg(2)`.
/// Returns a pointer to the SQE.
pub fn recvmsg_multishot(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    msg: *posix.msghdr,
    flags: linux.Msg,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_recvmsg_multishot(fd, msg, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `sendmsg(2)`.
/// Returns a pointer to the SQE.
/// Available since 5.3
pub fn sendmsg(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    msg: *const posix.msghdr_const,
    flags: linux.Msg,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_sendmsg(fd, msg, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `poll(2)`.
/// Returns a pointer to the SQE.
pub fn poll_add(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    poll_mask: linux.Epoll,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_poll_add(fd, poll_mask);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a multishot `poll(2)`.
/// Returns a pointer to the SQE.
pub fn poll_multishot(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    poll_mask: linux.Epoll,
) !*Sqe {
    const sqe = try self.poll_add(user_data, fd, poll_mask);
    sqe.len = @bitCast(uflags.Poll{ .add_multi = true });
    return sqe;
}

/// Queues (but does not submit) an SQE to remove an existing poll operation.
/// Returns a pointer to the SQE.
pub fn poll_remove(
    self: *IoUring,
    user_data: u64,
    target_user_data: u64,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_poll_remove(target_user_data);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to update the user data of an existing
/// poll operation. Returns a pointer to the SQE.
pub fn poll_update(
    self: *IoUring,
    user_data: u64,
    old_user_data: u64,
    new_user_data: u64,
    poll_mask: linux.Epoll,
    flags: uflags.Poll,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_poll_update(old_user_data, new_user_data, poll_mask, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `fsync(2)`.
/// Returns a pointer to the SQE so that you can further modify the SQE for
/// advanced use cases.
/// For example, for `fdatasync()` you can set `IORING_FSYNC_DATASYNC` in the
/// SQE's `rw_flags`.
/// N.B. While SQEs are initiated in the order in which they appear in the
/// submission queue, operations execute in parallel and completions are
/// unordered. Therefore, an application that submits a write followed by an
/// fsync in the submission queue cannot expect the fsync to apply to the write,
/// since the fsync may complete before the write is issued to the disk.
/// You should preferably use `link_with_next_sqe()` on a write's SQE to link
/// it with an fsync, or else insert a full write barrier using
/// `drain_previous_sqes()` when queueing an fsync.
pub fn fsync(self: *IoUring, user_data: u64, fd: posix.fd_t, flags: uflags.Fsync) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_fsync(fd, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a no-op.
/// Returns a pointer to the SQE so that you can further modify the SQE for
/// advanced use cases.
/// A no-op is more useful than may appear at first glance.
/// For example, you could call `drain_previous_sqes()` on the returned SQE, to
/// use the no-op to know when the ring is idle before acting on a kill signal.
pub fn nop(self: *IoUring, user_data: u64) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_nop();
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to register a timeout operation.
/// Returns a pointer to the SQE.
///
/// The timeout will complete when either the timeout expires, or after the
/// specified number of events complete (if `count` is greater than `0`).
///
/// `flags` may be `0` for a relative timeout, or `IORING_TIMEOUT_ABS` for an
/// absolute timeout.
///
/// The completion event result will be `-ETIME` if the timeout completed
/// through expiration, `0` if the timeout completed after the specified number
/// of events, or `-ECANCELED` if the timeout was removed before it expired.
///
/// io_uring timeouts use the `CLOCK.MONOTONIC` clock source.
pub fn timeout(
    self: *IoUring,
    user_data: u64,
    ts: *const linux.kernel_timespec,
    count: u32,
    flags: uflags.Timeout,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_timeout(ts, count, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to remove an existing timeout operation.
/// Returns a pointer to the SQE.
///
/// The timeout is identified by its `user_data`.
///
/// The completion event result will be `0` if the timeout was found and
/// cancelled successfully else:
/// `-EBUSY` if the timeout was found but expiration was already in progress, or
/// `-ENOENT` if the timeout was not found.
pub fn timeout_remove(
    self: *IoUring,
    user_data: u64,
    timeout_user_data: u64,
    flags: uflags.Timeout,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_timeout_remove(timeout_user_data, flags);
    sqe.user_data = user_data;
    return sqe;
}

pub fn timeout_update(
    self: *IoUring,
    user_data: u64,
    timeout_user_data: u64,
    ts: *const linux.kernel_timespec,
    flags: uflags.Timeout,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_timeout_update(timeout_user_data, ts, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `accept4(2)` on a socket.
/// Returns a pointer to the SQE.
/// Available since 5.5
pub fn accept(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    addr: ?*posix.sockaddr,
    addrlen: ?*posix.socklen_t,
    flags: linux.Sock,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_accept(fd, addr, addrlen, flags);
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
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    addr: ?*posix.sockaddr,
    addrlen: ?*posix.socklen_t,
    flags: linux.Sock,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_accept_direct(fd, addr, addrlen, flags, constants.FILE_INDEX_ALLOC);
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
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    addr: ?*posix.sockaddr,
    addrlen: ?*posix.socklen_t,
    flags: linux.Sock,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_multishot_accept(fd, addr, addrlen, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues an multishot accept using direct (registered) file descriptors.
/// Available since 5.19
pub fn accept_multishot_direct(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    addr: ?*posix.sockaddr,
    addrlen: ?*posix.socklen_t,
    flags: linux.Sock,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_multishot_accept_direct(fd, addr, addrlen, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to remove an existing operation.
/// Returns a pointer to the SQE.
///
/// The operation is identified by its `user_data`.
///
/// The completion event result will be `0` if the operation was found and
/// cancelled successfully else either of:
/// `-EALREADY` if the operation was found but was already in progress
/// `-ENOENT` if the operation was not found.
pub fn cancel(
    self: *IoUring,
    user_data: u64,
    cancel_user_data: u64,
    flags: uflags.AsyncCancel,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_cancel(cancel_user_data, flags);
    sqe.user_data = user_data;
    return sqe;
}

pub fn cancel_fd(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    flags: uflags.AsyncCancel,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_cancel_fd(fd, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to add a link timeout operation.
/// Returns a pointer to the SQE.
///
/// You need to set IOSQE_IO_LINK to flags of the target operation and then
/// call this method right after the target operation.
/// See https://lwn.net/Articles/803932/ for detail.
///
/// If the dependent request finishes before the linked timeout, the timeout
/// is canceled. If the timeout finishes before the dependent request, the
/// dependent request will be canceled.
///
/// The completion event result of the link_timeout will be either of:
/// `-ETIME` if the timeout finishes before the dependent request (in this case,
/// the completion event result of the dependent request will be `-ECANCELED`)
/// `-EALREADY` if the dependent request finishes before the linked timeout.
pub fn link_timeout(
    self: *IoUring,
    user_data: u64,
    ts: *const linux.kernel_timespec,
    flags: uflags.Timeout,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_link_timeout(ts, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queue (but does not submit) an SQE to perform a `connect(2)` on a socket.
/// Returns a pointer to the SQE.
pub fn connect(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    addr: *const posix.sockaddr,
    addrlen: posix.socklen_t,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_connect(fd, addr, addrlen);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `bind(2)` on a socket.
/// Returns a pointer to the SQE.
/// Available since 6.11
pub fn bind(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    addr: *const posix.sockaddr,
    addrlen: posix.socklen_t,
    // liburing doesn't have this flag, hence 0 should be passed
    // TODO: consider removing this and all flags like this
    flags: u32,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_bind(fd, addr, addrlen, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `listen(2)` on a socket.
/// Returns a pointer to the SQE.
/// Available since 6.11
pub fn listen(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    backlog: usize,
    // liburing doesn't have this flag, hence 0 should be passed
    // TODO: consider removing this and all flags like this
    flags: u32,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_listen(fd, backlog, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `epoll_wait(2)`.
/// Returns a pointer to the SQE.
pub fn epoll_wait(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    events: ?*linux.epoll_event,
    max_events: u32,
    flags: linux.Epoll,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_epoll_wait(fd, events, max_events, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `epoll_ctl(2)`.
/// Returns a pointer to the SQE.
pub fn epoll_ctl(
    self: *IoUring,
    user_data: u64,
    epfd: linux.fd_t,
    fd: linux.fd_t,
    op: linux.EpollOp,
    ev: ?*linux.epoll_event,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_epoll_ctl(epfd, fd, op, ev);
    sqe.user_data = user_data;
    return sqe;
}

pub fn files_update(
    self: *IoUring,
    user_data: u64,
    fds: []const linux.fd_t,
    offset: u32,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_files_update(fds, offset);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `fallocate(2)`.
/// Returns a pointer to the SQE.
pub fn fallocate(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    mode: i32,
    offset: u64,
    len: u64,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_fallocate(fd, mode, offset, len);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `openat(2)`.
/// Returns a pointer to the SQE.
/// Available since 5.6.
pub fn openat(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    path: [*:0]const u8,
    flags: linux.O,
    mode: posix.mode_t,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_openat(fd, path, flags, mode);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues an openat using direct (registered) file descriptors.
///
/// To use an accept direct variant, the application must first have registered
/// a file table (with register_files()). An unused table index will be
/// dynamically chosen and returned in the CQE res field.
///
/// After creation, they can be used by setting IOSQE_FIXED_FILE in the SQE
/// flags member, and setting the SQE fd field to the direct descriptor value
/// rather than the regular file descriptor.
///
/// Available since 5.15
pub fn openat_direct(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    path: [*:0]const u8,
    flags: linux.O,
    mode: posix.mode_t,
    file_index: u32,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_openat_direct(fd, path, flags, mode, file_index);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `open(2)`.
/// Returns a pointer to the SQE.
pub fn open(
    self: *IoUring,
    user_data: u64,
    path: [*:0]const u8,
    flags: linux.O,
    mode: posix.mode_t,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_openat(linux.At.fdcwd, path, flags, mode);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues an open using direct (registered) file descriptors.
///
/// To use an accept direct variant, the application must first have registered
/// a file table (with register_files()). An unused table index will be
/// dynamically chosen and returned in the CQE res field.
///
/// After creation, they can be used by setting IOSQE_FIXED_FILE in the SQE
/// flags member, and setting the SQE fd field to the direct descriptor value
/// rather than the regular file descriptor.
pub fn open_direct(
    self: *IoUring,
    user_data: u64,
    path: [*:0]const u8,
    flags: linux.O,
    mode: posix.mode_t,
    file_index: u32,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_openat_direct(linux.At.fdcwd, path, flags, mode, file_index);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `close(2)`.
/// Returns a pointer to the SQE.
/// Available since 5.6.
pub fn close(self: *IoUring, user_data: u64, fd: posix.fd_t) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_close(fd);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues close of registered file descriptor.
/// Available since 5.15
pub fn close_direct(self: *IoUring, user_data: u64, file_index: u32) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_close_direct(file_index);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `statx(2)`.
/// Returns a pointer to the SQE.
pub fn statx(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    path: [:0]const u8,
    flags: linux.At,
    mask: linux.Statx.Mask,
    buf: *linux.Statx,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_statx(fd, path, flags, mask, buf);
    sqe.user_data = user_data;
    return sqe;
}

// COMMIT: don't implement f/madvice64 for now I dought it is used by a lot of people in practice
/// Queues (but does not submit) an SQE to perform an `posix_fadvise(2)`.
/// Returns a pointer to the SQE.
pub fn fadvice(
    self: *IoUring,
    user_data: u64,
    fd: posix.fd_t,
    offset: u64,
    len: u32,
    advice: linux.Fadvice,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_fadvice(fd, offset, len, advice);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an `madvise(2)`.
/// Returns a pointer to the SQE.
pub fn madvice(
    self: *IoUring,
    user_data: u64,
    memory: []u8,
    advice: linux.Fadvice,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_madvice(memory, advice);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `recv(2)`.
/// Returns a pointer to the SQE.
/// Available since 5.6
pub fn recv(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    buffer: RecvBuffer,
    flags: linux.Msg,
) !*Sqe {
    const sqe = try self.get_sqe();
    switch (buffer) {
        .buffer => |slice| sqe.prep_recv(fd, slice, flags),
        .buffer_selection => |selection| {
            sqe.prep_rw(.recv, fd, 0, selection.len, 0);
            sqe.rw_flags = @bitCast(flags);
            sqe.flags.buffer_select = true;
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
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    buffer: []const u8,
    flags: linux.Msg,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_send(fd, buffer, flags);
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
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    buffer: []const u8,
    send_flags: linux.Msg,
    zc_flags: Sqe.SendRecv,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_send_zc(fd, buffer, send_flags, zc_flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an async zerocopy `send(2)`.
/// Returns a pointer to the SQE.
/// Available since 6.0
pub fn send_zc_fixed(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    buffer: []const u8,
    send_flags: linux.Msg,
    zc_flags: Sqe.SendRecv,
    buf_index: u16,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_send_zc_fixed(fd, buffer, send_flags, zc_flags, buf_index);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform an async zerocopy `sendmsg(2)`.
/// Returns a pointer to the SQE.
/// Available since 6.1
pub fn sendmsg_zc(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    msg: *const linux.msghdr_const,
    flags: linux.Msg,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_sendmsg_zc(fd, msg, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `shutdown(2)`.
/// Returns a pointer to the SQE.
///
/// The operation is identified by its `user_data`.
pub fn shutdown(
    self: *IoUring,
    user_data: u64,
    sockfd: posix.socket_t,
    how: linux.Shut,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_shutdown(sockfd, how);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `renameat2(2)`.
/// Returns a pointer to the SQE.
pub fn renameat(
    self: *IoUring,
    user_data: u64,
    old_dir_fd: linux.fd_t,
    old_path: [*:0]const u8,
    new_dir_fd: linux.fd_t,
    new_path: [*:0]const u8,
    flags: linux.Rename,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_renameat(old_dir_fd, old_path, new_dir_fd, new_path, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `unlinkat(2)`.
/// Returns a pointer to the SQE.
pub fn unlinkat(
    self: *IoUring,
    user_data: u64,
    dir_fd: linux.fd_t,
    path: [*:0]const u8,
    flags: linux.At,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_unlinkat(dir_fd, path, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `mkdirat(2)`.
/// Returns a pointer to the SQE.
pub fn mkdirat(
    self: *IoUring,
    user_data: u64,
    dir_fd: linux.fd_t,
    path: [*:0]const u8,
    mode: posix.mode_t,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_mkdirat(dir_fd, path, mode);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `symlinkat(2)`.
/// Returns a pointer to the SQE.
pub fn symlinkat(
    self: *IoUring,
    user_data: u64,
    target: [*:0]const u8,
    new_dir_fd: linux.fd_t,
    link_path: [*:0]const u8,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_symlinkat(target, new_dir_fd, link_path);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `linkat(2)`.
/// Returns a pointer to the SQE.
pub fn linkat(
    self: *IoUring,
    user_data: u64,
    old_dir_fd: linux.fd_t,
    old_path: [*:0]const u8,
    new_dir_fd: linux.fd_t,
    new_path: [*:0]const u8,
    flags: linux.At,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_linkat(old_dir_fd, old_path, new_dir_fd, new_path, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to provide a group of buffers used for
/// commands that read/receive data. Returns a pointer to the SQE.
///
/// Provided buffers can be used in `read`, `recv` or `recvmsg` commands via
/// buffer_selection.
///
/// The kernel expects a contiguous block of memory of size (buffers_count *
/// buffer_size).
// TODO: why not use a slice with `buffers_count`
pub fn provide_buffers(
    self: *IoUring,
    user_data: u64,
    buffers: [*]u8,
    buffer_size: usize,
    buffers_count: usize,
    group_id: usize,
    buffer_id: usize,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_provide_buffers(buffers, buffer_size, buffers_count, group_id, buffer_id);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to remove a group of provided buffers.
/// Returns a pointer to the SQE.
pub fn remove_buffers(
    self: *IoUring,
    user_data: u64,
    buffers_count: usize,
    group_id: usize,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_remove_buffers(buffers_count, group_id);
    sqe.user_data = user_data;
    return sqe;
}

/// Queues (but does not submit) an SQE to perform a `waitid(2)`.
/// Returns a pointer to the SQE.
pub fn waitid(
    self: *IoUring,
    user_data: u64,
    id_type: linux.P,
    id: i32,
    infop: *linux.siginfo_t,
    options: linux.W,
    flags: u32, // They are currently unused, and hence 0 should be passed
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_waitid(id_type, id, infop, options, flags);
    sqe.user_data = user_data;
    return sqe;
}

pub fn register_buffers_sparse(self: *IoUring, nr: u32) !void {
    assert(self.fd >= 0);

    const reg: RsrcRegister = .{
        .flags = .{ .register_sparse = true },
        .nr = nr,
    };

    const res = linux.io_uring_register(self.fd, .register_buffers2, &reg, @sizeOf(RsrcRegister));
    try handle_registration_result(res);
}

/// Registers an array of buffers for use with `read_fixed`, `readv_fixed`,
/// `write_fixed` and `writev_fixed`.
pub fn register_buffers(self: *IoUring, buffers: []const posix.iovec) !void {
    assert(self.fd >= 0);

    const res = linux.io_uring_register(self.fd, .register_buffers, buffers.ptr, @intCast(buffers.len));
    try handle_registration_result(res);
}

/// Unregister the registered buffers.
pub fn unregister_buffers(self: *IoUring) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .unregister_buffers, null, 0);
    switch (linux.E.init(res)) {
        .SUCCESS => {},
        .NXIO => return error.BuffersNotRegistered,
        else => |errno| return posix.unexpectedErrno(errno),
    }
}

/// Updates registered file descriptors.
///
/// Updates are applied starting at the provided offset in the original file
/// descriptors slice.
/// There are three kind of updates:
/// * turning a sparse entry (where the fd is -1) into a real one
/// * removing an existing entry (set the fd to -1)
/// * replacing an existing entry with a new fd
///
/// Adding new file descriptors must be done with `register_files`.
pub fn register_files_update(self: *IoUring, offset: u32, fds: []const posix.fd_t) !void {
    assert(self.fd >= 0);

    var update = mem.zeroInit(RsrcUpdate, .{
        .offset = offset,
        .data = @intFromPtr(fds.ptr),
    });

    const res = linux.io_uring_register(self.fd, .register_files_update, &update, @intCast(fds.len));
    try handle_registration_result(res);
}

/// Registers an empty (-1) file table of `nr_files` number of file descriptors.
pub fn register_files_sparse(self: *IoUring, nr_files: u32) !void {
    assert(self.fd >= 0);

    const reg = mem.zeroInit(RsrcRegister, .{
        .nr = nr_files,
        .flags = .{ .register_sparse = true },
    });

    const res = linux.io_uring_register(self.fd, .register_files2, &reg, @sizeOf(RsrcRegister));

    return handle_registration_result(res);
}
/// Registers an array of file descriptors.
///
/// Every time a file descriptor is put in an SQE and submitted to the kernel,
/// the kernel must retrieve a reference to the file, and once I/O has
/// completed, the file reference must be dropped. The atomic nature of this
/// file reference can be a slowdown for high IOPS workloads. This slowdown can
/// be avoided by pre-registering file descriptors.
///
/// To refer to a registered file descriptor, IOSQE_FIXED_FILE must be set in
/// the SQE's flags, and the SQE's fd must be set to the index of the file
/// descriptor in the registered array.
///
/// Registering file descriptors will wait for the ring to idle and files are
/// automatically unregistered by the kernel when the ring is torn down.
///
/// An application need unregister only if it wants to register a new array of
/// file descriptors.
pub fn register_files(self: *IoUring, fds: []const linux.fd_t) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_files, fds.ptr, @intCast(fds.len));
    try handle_registration_result(res);
}

/// Unregisters all registered file descriptors previously associated with the
/// ring.
pub fn unregister_files(self: *IoUring) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .unregister_files, null, 0);
    switch (linux.E.init(res)) {
        .SUCCESS => {},
        .NXIO => return error.FilesNotRegistered,
        else => |errno| return posix.unexpectedErrno(errno),
    }
}

/// Registers the file descriptor for an eventfd that will be notified of
/// completion events on an io_uring instance.
/// Only a single a eventfd can be registered at any given point in time.
pub fn register_eventfd(self: *IoUring, fd: linux.fd_t) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_eventfd, &fd, 1);
    try handle_registration_result(res);
}

/// Registers the file descriptor for an eventfd that will be notified of
/// completion events on an io_uring instance. Notifications are only posted
/// for events that complete in an async manner. This means that events that
/// complete inline while being submitted do not trigger a notification event.
/// Only a single eventfd can be registered at any given point in time.
pub fn register_eventfd_async(self: *IoUring, fd: linux.fd_t) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_eventfd_async, &fd, 1);
    try handle_registration_result(res);
}

/// Unregister the registered eventfd file descriptor.
pub fn unregister_eventfd(self: *IoUring) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .unregister_eventfd, null, 0);
    try handle_registration_result(res);
}

pub fn register_probe(self: *IoUring, probe: []Probe) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_probe, probe.ptr, @intCast(probe.len));
    try handle_registration_result(res);
}

/// See https://github.com/axboe/liburing/issues/357 for how to use personality
/// matches `io_uring_register_personality()` in liburing
pub fn register_personality(self: *IoUring) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_personality, null, 0);
    try handle_registration_result(res);
}

pub fn unregister_personality(self: *IoUring, credential_id: u32) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .unregister_personality, null, credential_id);
    try handle_registration_result(res);
}

pub fn register_restrictions(self: *IoUring, restriction: []Restriction) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_restrictions, restriction.ptr, @intCast(restriction.len));
    try handle_registration_result(res);
}

pub fn enable_rings(self: *IoUring) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_enable_rings, null, 0);
    try handle_registration_result(res);
}

pub fn register_iowq_aff(self: *IoUring, cpusz: u32, mask: *linux.cpu_set_t) !void {
    assert(self.fd >= 0);

    if (cpusz >= math.maxInt(u32)) return error.ArgumentsInvalid;

    const res = linux.io_uring_register(self.fd, .register_iowq_aff, mask, cpusz);
    try handle_registration_result(res);
}

pub fn unregister_iowq_aff(self: *IoUring) !void {
    assert(self.fd >= 0);

    const res = linux.io_uring_register(self.fd, .unregister_iowq_aff, null, 0);
    try handle_registration_result(res);
}

/// `max_workers`: `max_workers[0]` should contain the maximum number of
/// desired bounded workers, and the `max_workers[1]` the maximum number of
/// desired unbounded workers.
/// If both values are set to 0, the existing values are returned
/// Read `io_uring_register_iowq_max_workers(3)` for more info
pub fn register_iowq_max_workers(self: *IoUring, max_workers: [2]u32) !void {
    assert(self.fd >= 0);

    const res = linux.io_uring_register(self.fd, .register_iowq_max_workers, &max_workers, 2);
    try handle_registration_result(res);
}

/// See `io_uring_register_sync_cancel(3)`
pub fn register_sync_cancel(self: *IoUring, cancel_reg: *SyncCancelRegister) !void {
    assert(self.fd >= 0);

    const res = linux.io_uring_register(self.fd, .register_sync_cancel, cancel_reg, 1);
    try handle_registration_result(res);
}

/// See `io_uring_register_sync_msg(3)`
pub fn register_sync_msg(self: *IoUring, sqe: *Sqe) !void {
    assert(self.fd >= 0);

    const res = linux.io_uring_register(-1, .register_send_msg_ring, sqe, 1);
    try handle_registration_result(res);
}

// COMMIT: fix register file alloc range taking @sizeOf(FileIndexRange) instead of zero in register syscall
/// Registers range for fixed file allocations.
/// Available since 6.0
pub fn register_file_alloc_range(self: *IoUring, offset: u32, len: u32) !void {
    assert(self.fd >= 0);

    const range: FileIndexRange = .{
        .off = offset,
        .len = len,
        .resv = 0,
    };

    const res = linux.io_uring_register(self.fd, .register_file_alloc_range, &range, 0);

    return handle_registration_result(res);
}

pub fn register_napi(self: *IoUring, napi: *Napi) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_napi, napi, 1);
    try handle_registration_result(res);
}

pub fn unregister_napi(self: *IoUring, napi: *Napi) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .unregister_napi, napi, 1);
    try handle_registration_result(res);
}

pub fn register_clock(self: *IoUring, clock_reg: *ClockRegister) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_clock, clock_reg, 0);
    try handle_registration_result(res);
}

pub fn register_ifq(self: *IoUring, ifq_reg: *ZcrxIfqRegister) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_zcrx_ifq, ifq_reg, 1);
    try handle_registration_result(res);
}

pub fn register_resize_rings(self: *IoUring, _: *Params) !void {
    assert(self.fd >= 0);
    return error.Unimplemented;
}

pub fn register_region(self: *IoUring, mem_reg: *MemRegionRegister) !void {
    assert(self.fd >= 0);
    const res = linux.io_uring_register(self.fd, .register_mem_region, mem_reg, 1);
    try handle_registration_result(res);
}

/// Returns a Probe which is used to probe the capabilities of the
/// io_uring subsystem of the running kernel. The Probe contains the
/// list of supported operations.
pub fn get_probe(self: *IoUring) !Probe {
    var probe = mem.zeroInit(Probe, .{});
    const res = linux.io_uring_register(self.fd, .register_probe, &probe, probe.ops.len);
    try handle_register_buf_ring_result(res);
    return probe;
}

fn handle_registration_result(res: usize) !void {
    switch (linux.errno(res)) {
        .SUCCESS => {},
        // One or more fds in the array are invalid, or the kernel does not
        // support sparse sets:
        .BADF => return error.FileDescriptorInvalid,
        .BUSY => return error.FilesAlreadyRegistered,
        .INVAL => return error.FilesEmpty,
        // Adding `nr_args` file references would exceed the maximum allowed
        // number of files the user is allowed to have according to the
        // per-user RLIMIT_NOFILE resource limit and the CAP_SYS_RESOURCE
        // capability is not set, or `nr_args` exceeds the maximum allowed
        // for a fixed file set (older kernels have a limit of 1024 files vs
        // 64K files):
        .MFILE => return error.UserFdQuotaExceeded,
        // Insufficient kernel resources, or the caller had a non-zero
        // RLIMIT_MEMLOCK soft resource limit but tried to lock more memory
        // than the limit permitted (not enforced when the process is
        // privileged with CAP_IPC_LOCK):
        .NOMEM => return error.SystemResources,
        // Attempt to register files on a ring already registering files or
        // being torn down:
        .NXIO => return error.RingShuttingDownOrAlreadyRegisteringFiles,
        else => |errno| return posix.unexpectedErrno(errno),
    }
}

/// Prepares a socket creation request.
/// New socket fd will be returned in completion result.
/// Available since 5.19
pub fn socket(
    self: *IoUring,
    user_data: u64,
    domain: linux.Af,
    socket_type: linux.Sock,
    protocol: linux.IpProto,
    flags: u32, // flags is unused
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_socket(domain, socket_type, protocol, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Prepares a socket creation request for registered file at index `file_index`.
/// Available since 5.19
pub fn socket_direct(
    self: *IoUring,
    user_data: u64,
    domain: linux.Af,
    socket_type: linux.Sock,
    protocol: linux.IpProto,
    /// flags is unused
    flags: u32,
    file_index: u32,
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_socket_direct(domain, socket_type, protocol, flags, file_index);
    sqe.user_data = user_data;
    return sqe;
}

/// Prepares a socket creation request for registered file, index chosen by
/// kernel (file index alloc).
/// File index will be returned in CQE res field.
/// Available since 5.19
pub fn socket_direct_alloc(
    self: *IoUring,
    user_data: u64,
    domain: linux.Af,
    socket_type: linux.Sock,
    protocol: linux.IpProto,
    flags: u32, // flags unused
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_socket_direct_alloc(domain, socket_type, protocol, flags);
    sqe.user_data = user_data;
    return sqe;
}

/// Prepares an cmd request for a socket.
/// See: https://man7.org/linux/man-pages/man3/io_uring_prep_cmd.3.html
/// Available since 6.7.
pub fn cmd_sock(
    self: *IoUring,
    user_data: u64,
    cmd_op: SocketOp,
    fd: linux.fd_t,
    level: linux.Sol,
    optname: linux.So,
    optval: u64, // pointer to the option value
    optlen: u32, // size of the option value
) !*Sqe {
    const sqe = try self.get_sqe();
    sqe.prep_cmd_sock(cmd_op, fd, level, optname, optval, optlen);
    sqe.user_data = user_data;
    return sqe;
}

/// Prepares set socket option for the optname argument, at the protocol
/// level specified by the level argument.
/// Available since 6.7.n
pub fn setsockopt(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    level: linux.Sol,
    optname: linux.So,
    opt: []const u8,
) !*Sqe {
    return try self.cmd_sock(
        user_data,
        .setsockopt,
        fd,
        level,
        optname,
        @intFromPtr(opt.ptr),
        @intCast(opt.len),
    );
}

/// Prepares get socket option to retrieve the value for the option specified by
/// the option_name argument for the socket specified by the fd argument.
/// Available since 6.7.
pub fn getsockopt(
    self: *IoUring,
    user_data: u64,
    fd: linux.fd_t,
    level: linux.Sol,
    optname: linux.So,
    opt: []u8,
) !*Sqe {
    return try self.cmd_sock(
        user_data,
        .getsockopt,
        fd,
        level,
        optname,
        @intFromPtr(opt.ptr),
        @intCast(opt.len),
    );
}

// TODO: move buf_ring fns into BufferRing type
/// Registers a shared buffer ring to be used with provided buffers. `entries`
/// number of `io_uring_buf` structures is mem mapped and shared by kernel.
///
/// `entries` is the number of entries requested in the buffer ring and must be
/// a power of 2.
/// `fd` is IO_Uring.fd for which the provided buffer ring is being registered.
/// `group_id` is the chosen buffer group ID, unique in IO_Uring.
/// matches `io_uring_setup_buf_ring()` in liburing
pub fn init_buffer_ring(
    self: *IoUring,
    entries: u16,
    group_id: u16,
    flags: BufferRegister.Flags,
) !*align(page_size_min) BufferRing {
    assert(self.fd >= 0);
    if (entries == 0 or entries > math.maxInt(u16)) return error.EntriesNotInRange;
    if (!math.isPowerOfTwo(entries)) return error.EntriesNotPowerOfTwo;

    const mmap_size: usize = entries * @sizeOf(Buffer);
    const mmap = try posix.mmap(
        null,
        mmap_size,
        posix.PROT.READ | posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );
    errdefer posix.munmap(mmap);
    assert(mmap.len == mmap_size);

    const buffer_ring: *align(page_size_min) BufferRing = @ptrCast(mmap.ptr);
    var reg = mem.zeroInit(BufferRegister, .{
        .ring_addr = @intFromPtr(buffer_ring),
        .ring_entries = entries,
        .bgid = group_id,
        .flags = flags,
    });
    try self.register_buffer_ring(&reg);
    buffer_ring.init();
    return buffer_ring;
}

/// matches `io_uring_register_buf_ring`
pub fn register_buffer_ring(self: *IoUring, buf_reg: *BufferRegister) !void {
    var res = linux.io_uring_register(self.fd, .register_pbuf_ring, buf_reg, 1);
    if (linux.E.init(res) == .INVAL and buf_reg.flags.iou_pbuf_ring_inc) {
        // Retry without incremental buffer consumption.
        // It is available since kernel 6.12. returns INVAL on older.
        buf_reg.flags.iou_pbuf_ring_inc = false;
        res = linux.io_uring_register(self.fd, .register_pbuf_ring, buf_reg, 1);
    }
    try handle_register_buf_ring_result(res);
}

/// matches `io_uring_unregister_buf_ring`
pub fn unregister_buffer_ring(self: *IoUring, buf_group_id: u16) !void {
    var reg = mem.zeroInit(BufferRegister, .{
        .bgid = buf_group_id,
    });
    const res = linux.io_uring_register(self.fd, .unregister_pbuf_ring, &reg, 1);
    try handle_register_buf_ring_result(res);
}

fn handle_register_buf_ring_result(res: usize) !void {
    switch (linux.errno(res)) {
        .SUCCESS => {},
        .INVAL => return error.ArgumentsInvalid,
        else => |errno| return posix.unexpectedErrno(errno),
    }
}

/// IO completion data structure (Completion Queue Entry)
pub const Cqe = extern struct {
    /// sqe.user_data value passed back
    user_data: u64,
    /// result code for this event
    res: i32,
    flags: Flags,
    // TODO: add support for the IORING_SETUP_CQE32 case
    /// If the ring is initialized with IORING_SETUP_CQE32, then this field
    /// contains 16-bytes of padding, doubling the size of the CQE.
    // big_cqe: ?[2]u64,

    /// cqe.flags
    pub const Flags = packed struct(u32) {
        /// IORING_CQE_F_BUFFER If set, the upper 16 bits are the buffer ID
        f_buffer: bool = false,
        /// IORING_CQE_F_MORE If set, parent SQE will generate more CQE entries
        f_more: bool = false,
        /// IORING_CQE_F_SOCK_NONEMPTY If set, more data to read after socket
        /// recv
        f_sock_nonempty: bool = false,
        /// IORING_CQE_F_NOTIF Set for notification CQEs. Can be used to
        /// distinct them from sends.
        f_notif: bool = false,
        /// IORING_CQE_F_BUF_MORE If set, the buffer ID set in the completion
        /// will get more completions. In other words, the buffer is being
        /// partially consumed, and will be used by the kernel for more
        /// completions. This is only set for buffers used via the incremental
        /// buffer consumption, as provided by a ring buffer setup with
        /// IOU_PBUF_RING_INC. For any other provided buffer type, all
        /// completions with a buffer passed back is automatically returned to
        /// the application.
        f_buf_more: bool = false,
        // COMMIT: new flags
        /// IORING_CQE_F_SKIP If set, then the application/liburing must ignore
        /// this CQE. It's only purpose is to fill a gap in the ring, if a
        /// large CQE is attempted posted when the ring has just a single small
        /// CQE worth of space left before wrapping.
        f_skip: bool = false,
        _7: u9 = 0,
        /// IORING_CQE_F_32 If set, this is a 32b/big-cqe posting. Use with
        /// rings setup in a mixed CQE mode, where both 16b and 32b CQEs may be
        /// posted to the CQ ring.
        f_32: bool = false,
        _17: u16 = 0,
    };

    /// Retrive the 64-bit cqe `user_data`, as `*T` after completion of an Sqe
    /// this data is passed through `Sqe` -> `Cqe` unchanged
    pub fn get_data(cqe: Cqe, comptime T: type) *T {
        return @ptrFromInt(cqe.user_data);
    }

    pub fn err(self: Cqe) linux.E {
        if (self.res > -4096 and self.res < 0) {
            return @enumFromInt(-self.res);
        }
        return .SUCCESS;
    }

    /// On successful completion of the provided buffers IO request, the CQE
    /// flags field will have IORING_CQE_F_BUFFER set and the selected buffer
    /// ID will be indicated by the upper 16-bits of the flags field.
    pub fn buffer_id(self: Cqe) !u16 {
        if (!self.flags.f_buffer) {
            return error.NoBufferSelected;
        }
        return @intCast(@as(u32, @bitCast(self.flags)) >> constants.CQE_BUFFER_SHIFT);
    }
};

/// IO submission data structure (Submission Queue Entry)
/// matches `io_uring_sqe` in liburing
pub const Sqe = extern struct {
    /// type of operation for this sqe
    opcode: Op,
    /// IOSQE_* flags
    flags: IoSqe,
    /// ioprio for the request
    ioprio: packed union {
        send_recv: SendRecv,
        accept: Accept,
        const Ioprio = @This();

        pub fn init_empty() Ioprio {
            return @bitCast(@as(u16, 0));
        }
    },
    /// file descriptor to do IO on
    fd: i32,
    /// offset into file
    off: u64,
    /// pointer to buffer or iovecs
    addr: u64,
    /// buffer size or number of iovecs
    len: u32,
    /// flags for any Sqe operation
    /// rw_flags | fsync_flags | poll_event | poll32_event | sync_range_flags |
    /// msg_flags | timeout_flags | accept_flags | cancel_flags | open_flags |
    /// statx_flags | fadvise_advice | splice_flags | rename_flags |
    /// unlink_flags | hardlink_flags xattr_flags | msg_ring_flags |
    /// uring_cmd_flags | waitid_flags | futex_flags install_fd_flags |
    /// nop_flags | pipe_flags
    rw_flags: u32,
    /// data to be passed back at completion time
    user_data: u64,
    /// index into fixed buffers or for grouped buffer selection
    buf_index: u16,
    personality: u16,
    splice_fd_in: i32,
    addr3: u64,
    resv: u64,

    /// sqe.flags
    pub const IoSqe = packed struct(u8) {
        /// use fixed fileset
        fixed_file: bool = false,
        /// issue after inflight IO
        io_drain: bool = false,
        /// links next sqe
        io_link: bool = false,
        /// like LINK, but stronger
        io_hardlink: bool = false,
        /// always go async
        async: bool = false,
        /// select buffer from sqe->buf_group
        buffer_select: bool = false,
        /// don't post CQE if request succeeded
        cqe_skip_success: bool = false,
        _: u1 = 0,
    };

    /// send/sendmsg and recv/recvmsg flags (sqe.ioprio)
    pub const SendRecv = packed struct(u16) {
        /// IORING_RECVSEND_POLL_FIRST
        /// If set, instead of first attempting to send or receive and arm poll
        /// if that yields an -EAGAIN result, arm poll upfront and skip the
        /// initial transfer attempt.
        recvsend_poll_first: bool = false,
        /// IORING_RECV_MULTISHOT
        /// Multishot recv. Sets IORING_CQE_F_MORE if the handler will continue
        /// to report CQEs on behalf of the same SQE.
        recv_multishot: bool = false,
        /// IORING_RECVSEND_FIXED_BUF
        /// Use registered buffers, the index is stored in the buf_index field.
        recvsend_fixed_buf: bool = false,
        /// IORING_SEND_ZC_REPORT_USAGE
        /// If set, SEND[MSG]_ZC should report the zerocopy usage in cqe.res
        /// for the IORING_CQE_F_NOTIF cqe. 0 is reported if zerocopy was
        /// actually possible. IORING_NOTIF_USAGE_ZC_COPIED if data was copied
        /// (at least partially).
        send_zc_report_usage: bool = false,
        /// IORING_RECVSEND_BUNDLE
        /// Used with IOSQE_BUFFER_SELECT. If set, send or recv will grab as
        /// many buffers from the buffer group ID given and send them all.
        /// The completion result will be the number of buffers send, with the
        /// starting buffer ID in cqe.flags as per usual for provided buffer
        /// usage. The buffers will be contiguous from the starting buffer ID.
        recvsend_bundle: bool = false,
        // COMMIT: new flags
        /// IORING_SEND_VECTORIZED
        /// If set, SEND[_ZC] will take a pointer to a io_vec to allow
        /// vectorized send operations.
        send_vectorized: bool = false,
        _: u10 = 0,
    };

    /// accept flags stored in sqe.ioprio
    pub const Accept = packed struct(u16) {
        multishot: bool = false,
        // COMMIT: new Flags
        dontwait: bool = false,
        poll_first: bool = false,
        _: u13 = 0,
    };

    pub fn prep_nop(sqe: *Sqe) void {
        sqe.* = .{
            .opcode = .nop,
            .flags = .{},
            .ioprio = .init_empty(),
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

    pub fn prep_fsync(sqe: *Sqe, fd: linux.fd_t, flags: uflags.Fsync) void {
        sqe.* = .{
            .opcode = .fsync,
            .flags = .{},
            .ioprio = .init_empty(),
            .fd = fd,
            .off = 0,
            .addr = 0,
            .len = 0,
            .rw_flags = @bitCast(flags),
            .user_data = 0,
            .buf_index = 0,
            .personality = 0,
            .splice_fd_in = 0,
            .addr3 = 0,
            .resv = 0,
        };
    }

    pub fn prep_rw(
        sqe: *Sqe,
        op: Op,
        fd: linux.fd_t,
        addr: u64,
        len: usize,
        offset: u64,
    ) void {
        sqe.* = .{
            .opcode = op,
            .flags = .{},
            .ioprio = .init_empty(),
            .fd = fd,
            .off = offset,
            .addr = addr,
            .len = @intCast(len),
            .rw_flags = 0,
            .user_data = 0,
            .buf_index = 0,
            .personality = 0,
            .splice_fd_in = 0,
            .addr3 = 0,
            .resv = 0,
        };
    }

    pub fn prep_write(sqe: *Sqe, fd: linux.fd_t, buffer: []const u8, offset: u64) void {
        sqe.prep_rw(.write, fd, @intFromPtr(buffer.ptr), buffer.len, offset);
    }

    pub fn prep_writev(
        sqe: *Sqe,
        fd: linux.fd_t,
        iovecs: []const std.posix.iovec_const,
        offset: u64,
    ) void {
        sqe.prep_rw(.writev, fd, @intFromPtr(iovecs.ptr), iovecs.len, offset);
    }

    pub fn prep_write_fixed(sqe: *Sqe, fd: linux.fd_t, buffer: []const u8, offset: u64, buffer_index: u16) void {
        sqe.prep_rw(.write_fixed, fd, @intFromPtr(buffer.ptr), buffer.len, offset);
        sqe.buf_index = buffer_index;
    }

    pub fn prep_writev_fixed(sqe: *Sqe, fd: linux.fd_t, iovecs: []const posix.iovec_const, offset: u64, buffer_index: u16) void {
        sqe.prep_rw(.write_fixed, fd, @intFromPtr(iovecs.ptr), iovecs.len, offset);
        sqe.buf_index = buffer_index;
    }

    pub fn prep_splice(sqe: *Sqe, fd_in: linux.fd_t, off_in: u64, fd_out: linux.fd_t, off_out: u64, len: usize) void {
        sqe.prep_rw(.splice, fd_out, undefined, len, off_out);
        sqe.addr = off_in;
        sqe.splice_fd_in = fd_in;
    }

    pub fn prep_tee(sqe: *Sqe, fd_in: linux.fd_t, fd_out: linux.fd_t, len: usize) void {
        sqe.prep_rw(.tee, fd_out, undefined, len, 0);
        sqe.addr = undefined;
        sqe.splice_fd_in = fd_in;
    }

    pub fn prep_read(sqe: *Sqe, fd: linux.fd_t, buffer: []u8, offset: u64) void {
        sqe.prep_rw(.read, fd, @intFromPtr(buffer.ptr), buffer.len, offset);
    }

    pub fn prep_readv(
        sqe: *Sqe,
        fd: linux.fd_t,
        iovecs: []const std.posix.iovec,
        offset: u64,
    ) void {
        sqe.prep_rw(.readv, fd, @intFromPtr(iovecs.ptr), iovecs.len, offset);
    }

    pub fn prep_read_fixed(
        sqe: *Sqe,
        fd: linux.fd_t,
        buffer: []u8,
        offset: u64,
        buffer_index: u16,
    ) void {
        sqe.prep_rw(.read_fixed, fd, @intFromPtr(buffer.ptr), buffer.len, offset);
        sqe.buf_index = buffer_index;
    }

    pub fn prep_readv_fixed(
        sqe: *Sqe,
        fd: linux.fd_t,
        iovecs: []const std.posix.iovec,
        offset: u64,
        buffer_index: u16,
    ) void {
        sqe.prep_rw(.read_fixed, fd, @intFromPtr(iovecs.ptr), iovecs.len, offset);
        sqe.buf_index = buffer_index;
    }

    pub fn prep_accept(
        sqe: *Sqe,
        fd: linux.fd_t,
        addr: ?*linux.sockaddr,
        addrlen: ?*linux.socklen_t,
        flags: linux.Sock,
    ) void {
        // `addr` holds a pointer to `sockaddr`, and `addr2` holds a pointer to
        // socklen_t`.
        // `addr2` maps to `sqe.off` (u64) instead of `sqe.len` (which is only
        // a u32).
        sqe.prep_rw(.accept, fd, @intFromPtr(addr), 0, @intFromPtr(addrlen));
        sqe.rw_flags = @bitCast(flags);
    }

    /// accept directly into the fixed file table
    pub fn prep_accept_direct(
        sqe: *Sqe,
        fd: linux.fd_t,
        addr: ?*linux.sockaddr,
        addrlen: ?*linux.socklen_t,
        flags: linux.Sock,
        file_index: u32,
    ) void {
        prep_accept(sqe, fd, addr, addrlen, flags);
        set_target_fixed_file(sqe, file_index);
    }

    pub fn prep_multishot_accept(
        sqe: *Sqe,
        fd: linux.fd_t,
        addr: ?*linux.sockaddr,
        addrlen: ?*linux.socklen_t,
        flags: linux.Sock,
    ) void {
        prep_accept(sqe, fd, addr, addrlen, flags);
        sqe.ioprio = .{ .accept = .{ .multishot = true } };
    }

    /// multishot accept directly into the fixed file table
    pub fn prep_multishot_accept_direct(
        sqe: *Sqe,
        fd: linux.fd_t,
        addr: ?*linux.sockaddr,
        addrlen: ?*linux.socklen_t,
        flags: linux.Sock,
    ) void {
        prep_multishot_accept(sqe, fd, addr, addrlen, flags);
        set_target_fixed_file(sqe, constants.FILE_INDEX_ALLOC);
    }

    fn set_target_fixed_file(sqe: *Sqe, file_index: u32) void {
        const sqe_file_index: u32 = if (file_index == constants.FILE_INDEX_ALLOC)
            constants.FILE_INDEX_ALLOC
        else
            // 0 means no fixed files, indexes should be encoded as "index + 1"
            file_index + 1;
        // This filed is overloaded in liburing:
        //   splice_fd_in: i32
        //   sqe_file_index: u32
        sqe.splice_fd_in = @bitCast(sqe_file_index);
    }

    pub fn prep_connect(
        sqe: *Sqe,
        fd: linux.fd_t,
        addr: *const linux.sockaddr,
        addrlen: linux.socklen_t,
    ) void {
        // `addrlen` maps to `sqe.off` (u64) instead of `sqe.len` (which is
        // only a u32).
        sqe.prep_rw(.connect, fd, @intFromPtr(addr), 0, addrlen);
    }

    pub fn prep_epoll_wait(
        sqe: *Sqe,
        fd: linux.fd_t,
        event: ?*linux.epoll_event,
        max_events: u32,
        flags: linux.Epoll,
    ) void {
        sqe.prep_rw(.epoll_wait, fd, @intFromPtr(event), max_events, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_epoll_ctl(
        sqe: *Sqe,
        epfd: linux.fd_t,
        fd: linux.fd_t,
        op: linux.EpollOp,
        ev: ?*linux.epoll_event,
    ) void {
        sqe.prep_rw(.epoll_ctl, epfd, @intFromPtr(ev), @intFromEnum(op), @intCast(fd));
    }

    pub fn prep_recv(sqe: *Sqe, fd: linux.fd_t, buffer: []u8, flags: linux.Msg) void {
        sqe.prep_rw(.recv, fd, @intFromPtr(buffer.ptr), buffer.len, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_recv_multishot(
        sqe: *Sqe,
        fd: linux.fd_t,
        buffer: []u8,
        flags: linux.Msg,
    ) void {
        sqe.prep_recv(fd, buffer, flags);
        sqe.ioprio = .{ .send_recv = .{ .recv_multishot = true } };
    }

    pub fn prep_recvmsg(
        sqe: *Sqe,
        fd: linux.fd_t,
        msg: *linux.msghdr,
        flags: linux.Msg,
    ) void {
        sqe.prep_rw(.recvmsg, fd, @intFromPtr(msg), 1, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_recvmsg_multishot(
        sqe: *Sqe,
        fd: linux.fd_t,
        msg: *linux.msghdr,
        flags: linux.Msg,
    ) void {
        sqe.prep_recvmsg(fd, msg, flags);
        sqe.ioprio = .{ .send_recv = .{ .recv_multishot = true } };
    }

    // COMMIT: fix send[|recv] flag param type
    pub fn prep_send(sqe: *Sqe, fd: linux.fd_t, buffer: []const u8, flags: linux.Msg) void {
        sqe.prep_rw(.send, fd, @intFromPtr(buffer.ptr), buffer.len, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_send_zc(sqe: *Sqe, fd: linux.fd_t, buffer: []const u8, flags: linux.Msg, zc_flags: Sqe.SendRecv) void {
        sqe.prep_rw(.send_zc, fd, @intFromPtr(buffer.ptr), buffer.len, 0);
        sqe.rw_flags = @bitCast(flags);
        sqe.ioprio = .{ .send_recv = zc_flags };
    }

    pub fn prep_send_zc_fixed(sqe: *Sqe, fd: linux.fd_t, buffer: []const u8, flags: linux.Msg, zc_flags: Sqe.SendRecv, buf_index: u16) void {
        const zc_flags_fixed = blk: {
            var updated_flags = zc_flags;
            updated_flags.recvsend_fixed_buf = true;
            break :blk updated_flags;
        };
        prep_send_zc(sqe, fd, buffer, flags, zc_flags_fixed);
        sqe.buf_index = buf_index;
    }

    pub fn prep_sendmsg(
        sqe: *Sqe,
        fd: linux.fd_t,
        msg: *const linux.msghdr_const,
        flags: linux.Msg,
    ) void {
        sqe.prep_rw(.sendmsg, fd, @intFromPtr(msg), 1, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_sendmsg_zc(
        sqe: *Sqe,
        fd: linux.fd_t,
        msg: *const linux.msghdr_const,
        flags: linux.Msg,
    ) void {
        prep_sendmsg(sqe, fd, msg, flags);
        sqe.opcode = .sendmsg_zc;
    }

    pub fn prep_openat(
        sqe: *Sqe,
        fd: linux.fd_t,
        path: [*:0]const u8,
        flags: linux.O,
        mode: linux.mode_t,
    ) void {
        sqe.prep_rw(.openat, fd, @intFromPtr(path), mode, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_openat_direct(
        sqe: *Sqe,
        fd: linux.fd_t,
        path: [*:0]const u8,
        flags: linux.O,
        mode: linux.mode_t,
        file_index: u32,
    ) void {
        prep_openat(sqe, fd, path, flags, mode);
        set_target_fixed_file(sqe, file_index);
    }

    pub fn prep_close(sqe: *Sqe, fd: linux.fd_t) void {
        sqe.* = .{
            .opcode = .close,
            .flags = .{},
            .ioprio = .init_empty(),
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

    pub fn prep_close_direct(sqe: *Sqe, file_index: u32) void {
        prep_close(sqe, 0);
        set_target_fixed_file(sqe, file_index);
    }

    pub fn prep_timeout(
        sqe: *Sqe,
        ts: *const linux.kernel_timespec,
        count: u32,
        flags: uflags.Timeout,
    ) void {
        sqe.prep_rw(.timeout, -1, @intFromPtr(ts), 1, count);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_timeout_remove(sqe: *Sqe, timeout_user_data: u64, flags: uflags.Timeout) void {
        sqe.prep_rw(.timeout_remove, -1, timeout_user_data, 0, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_timeout_update(sqe: *Sqe, timeout_user_data: u64, ts: *const linux.kernel_timespec, flags: uflags.Timeout) void {
        sqe.prep_rw(.timeout_remove, -1, timeout_user_data, 0, @intFromPtr(ts));
        const enable_timeout_update = if (flags.timeout_update) flags else blk: {
            var tflags = flags;
            tflags.timeout_update = true;
            break :blk tflags;
        };
        sqe.rw_flags = @bitCast(enable_timeout_update);
    }

    pub fn prep_link_timeout(
        sqe: *Sqe,
        ts: *const linux.kernel_timespec,
        flags: uflags.Timeout,
    ) void {
        sqe.prep_rw(.link_timeout, -1, @intFromPtr(ts), 1, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_poll_add(
        sqe: *Sqe,
        fd: linux.fd_t,
        poll_mask: linux.Epoll,
    ) void {
        sqe.prep_rw(.poll_add, fd, @intFromPtr(@as(?*anyopaque, null)), 0, 0);
        // Poll masks previously used to comprise of 16 bits in the flags union
        // of a SQE, but were then extended to comprise of 32 bits in order to
        // make room for additional option flags. To ensure that the correct
        // bits of poll masks are consistently and properly read across
        // multiple kernel versions, poll masks are enforced to be
        // little-endian. https://www.spinics.net/lists/io-uring/msg02848.html
        sqe.rw_flags = std.mem.nativeToLittle(u32, @bitCast(poll_mask));
    }

    pub fn prep_poll_remove(
        sqe: *Sqe,
        target_user_data: u64,
    ) void {
        sqe.prep_rw(.poll_remove, -1, target_user_data, 0, 0);
    }

    pub fn prep_poll_update(
        sqe: *Sqe,
        old_user_data: u64,
        new_user_data: u64,
        poll_mask: linux.Epoll,
        flags: uflags.Poll,
    ) void {
        sqe.prep_rw(.poll_remove, -1, old_user_data, flags, new_user_data);
        // Poll masks previously used to comprise of 16 bits in the flags union
        // of a SQE, but were then extended to comprise of 32 bits in order to
        // make room for additional option flags. To ensure that the correct
        // bits of poll masks are consistently and properly read across
        // multiple kernel versions, poll masks are enforced to be
        // little-endian. https://www.spinics.net/lists/io-uring/msg02848.html
        sqe.rw_flags = std.mem.nativeToLittle(u32, @bitCast(poll_mask));
    }

    pub fn prep_fallocate(
        sqe: *Sqe,
        fd: linux.fd_t,
        mode: i32,
        offset: u64,
        len: u64,
    ) void {
        sqe.* = .{
            .opcode = .fallocate,
            .flags = .{},
            .ioprio = .init_empty(),
            .fd = fd,
            .off = offset,
            .addr = len,
            .len = @intCast(mode),
            .rw_flags = 0,
            .user_data = 0,
            .buf_index = 0,
            .personality = 0,
            .splice_fd_in = 0,
            .addr3 = 0,
            .resv = 0,
        };
    }

    pub fn prep_statx(
        sqe: *Sqe,
        fd: linux.fd_t,
        path: [*:0]const u8,
        flags: linux.At,
        mask: linux.Statx.Mask,
        buf: *linux.Statx,
    ) void {
        sqe.prep_rw(.statx, fd, @intFromPtr(path), @as(u32, @bitCast(mask)), @intFromPtr(buf));
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_fadvice(
        sqe: *Sqe,
        fd: linux.fd_t,
        offset: u64,
        len: u32,
        advice: linux.Fadvice,
    ) void {
        sqe.prep_rw(.fadvise, fd, undefined, len, offset);
        sqe.rw_flags = @intFromEnum(advice);
    }

    pub fn prep_madvice(
        sqe: *Sqe,
        memory: []u8,
        advice: linux.Madvice,
    ) void {
        sqe.prep_rw(.madvise, -1, @intFromPtr(memory.ptr), memory.len, 0);
        sqe.rw_flags = @intFromEnum(advice);
    }

    pub fn prep_cancel(
        sqe: *Sqe,
        cancel_user_data: u64,
        flags: uflags.AsyncCancel,
    ) void {
        sqe.prep_rw(.async_cancel, -1, cancel_user_data, 0, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_cancel_fd(
        sqe: *Sqe,
        fd: linux.fd_t,
        flags: uflags.AsyncCancel,
    ) void {
        sqe.prep_rw(.async_cancel, fd, undefined, 0, 0);
        const enable_cancel_fd = if (flags.cancel_fd) flags else blk: {
            var cancel_flags = flags;
            cancel_flags.cancel_fd = true;
            break :blk cancel_flags;
        };
        sqe.rw_flags = @bitCast(enable_cancel_fd);
    }

    pub fn prep_shutdown(
        sqe: *Sqe,
        sockfd: linux.socket_t,
        how: linux.Shut,
    ) void {
        sqe.prep_rw(.shutdown, sockfd, 0, @intFromEnum(how), 0);
    }

    pub fn prep_renameat(
        sqe: *Sqe,
        old_dir_fd: linux.fd_t,
        old_path: [*:0]const u8,
        new_dir_fd: linux.fd_t,
        new_path: [*:0]const u8,
        flags: linux.Rename,
    ) void {
        sqe.prep_rw(
            .renameat,
            old_dir_fd,
            @intFromPtr(old_path),
            0,
            @intFromPtr(new_path),
        );
        sqe.len = @bitCast(new_dir_fd);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_unlinkat(
        sqe: *Sqe,
        dir_fd: linux.fd_t,
        path: [*:0]const u8,
        flags: linux.At,
    ) void {
        sqe.prep_rw(.unlinkat, dir_fd, @intFromPtr(path), 0, 0);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_mkdirat(
        sqe: *Sqe,
        dir_fd: linux.fd_t,
        path: [*:0]const u8,
        mode: linux.mode_t,
    ) void {
        sqe.prep_rw(.mkdirat, dir_fd, @intFromPtr(path), mode, 0);
    }

    pub fn prep_symlinkat(
        sqe: *Sqe,
        target: [*:0]const u8,
        new_dir_fd: linux.fd_t,
        link_path: [*:0]const u8,
    ) void {
        sqe.prep_rw(
            .symlinkat,
            new_dir_fd,
            @intFromPtr(target),
            0,
            @intFromPtr(link_path),
        );
    }

    pub fn prep_linkat(
        sqe: *Sqe,
        old_dir_fd: linux.fd_t,
        old_path: [*:0]const u8,
        new_dir_fd: linux.fd_t,
        new_path: [*:0]const u8,
        flags: linux.At,
    ) void {
        sqe.prep_rw(
            .linkat,
            old_dir_fd,
            @intFromPtr(old_path),
            0,
            @intFromPtr(new_path),
        );
        sqe.len = @bitCast(new_dir_fd);
        sqe.rw_flags = @bitCast(flags);
    }

    pub fn prep_files_update(
        sqe: *Sqe,
        fds: []const linux.fd_t,
        offset: u32,
    ) void {
        sqe.prep_rw(.files_update, -1, @intFromPtr(fds.ptr), fds.len, @intCast(offset));
    }

    pub fn prep_files_update_alloc(
        sqe: *Sqe,
        fds: []linux.fd_t,
    ) void {
        sqe.prep_rw(.files_update, -1, @intFromPtr(fds.ptr), fds.len, constants.FILE_INDEX_ALLOC);
    }

    // TODO: why can't slice be used here ?
    pub fn prep_provide_buffers(
        sqe: *Sqe,
        buffers: [*]u8,
        buffer_len: usize,
        num: usize,
        group_id: usize,
        buffer_id: usize,
    ) void {
        const ptr = @intFromPtr(buffers);
        sqe.prep_rw(.provide_buffers, @intCast(num), ptr, buffer_len, buffer_id);
        sqe.buf_index = @intCast(group_id);
    }

    pub fn prep_remove_buffers(
        sqe: *Sqe,
        num: usize,
        group_id: usize,
    ) void {
        sqe.prep_rw(.remove_buffers, @intCast(num), 0, 0, 0);
        sqe.buf_index = @intCast(group_id);
    }

    pub fn prep_socket(
        sqe: *Sqe,
        domain: linux.Af,
        socket_type: linux.Sock,
        protocol: linux.IpProto,
        flags: u32, // flags is unused
    ) void {
        sqe.prep_rw(.socket, @intFromEnum(domain), 0, @intFromEnum(protocol), @as(u32, @bitCast(socket_type)));
        sqe.rw_flags = flags;
    }

    pub fn prep_socket_direct(
        sqe: *Sqe,
        domain: linux.Af,
        socket_type: linux.Sock,
        protocol: linux.IpProto,
        flags: u32, // flags is unused
        file_index: u32,
    ) void {
        prep_socket(sqe, domain, socket_type, protocol, flags);
        set_target_fixed_file(sqe, file_index);
    }

    pub fn prep_socket_direct_alloc(
        sqe: *Sqe,
        domain: linux.Af,
        socket_type: linux.Sock,
        protocol: linux.IpProto,
        flags: u32, // flags is unused
    ) void {
        prep_socket(sqe, domain, socket_type, protocol, flags);
        set_target_fixed_file(sqe, constants.FILE_INDEX_ALLOC);
    }

    pub fn prep_waitid(
        sqe: *Sqe,
        id_type: linux.P,
        id: i32,
        infop: *linux.siginfo_t,
        options: linux.W,
        flags: u32, // flags is unused
    ) void {
        sqe.prep_rw(.waitid, id, 0, @intFromEnum(id_type), @intFromPtr(infop));
        sqe.rw_flags = flags;
        sqe.splice_fd_in = @bitCast(options);
    }

    // TODO: maybe remove unused flag fields?
    pub fn prep_bind(
        sqe: *Sqe,
        fd: linux.fd_t,
        addr: *const linux.sockaddr,
        addrlen: linux.socklen_t,
        flags: u32, // flags is unused and does't exist in io_uring's api
    ) void {
        sqe.prep_rw(.bind, fd, @intFromPtr(addr), 0, addrlen);
        sqe.rw_flags = flags;
    }

    pub fn prep_listen(
        sqe: *Sqe,
        fd: linux.fd_t,
        backlog: usize,
        flags: u32, // flags is unused and does't exist in io_uring's api
    ) void {
        sqe.prep_rw(.listen, fd, 0, backlog, 0);
        sqe.rw_flags = flags;
    }

    pub fn prep_cmd_sock(
        sqe: *Sqe,
        cmd_op: SocketOp,
        fd: linux.fd_t,
        level: linux.Sol,
        optname: linux.So,
        optval: u64,
        optlen: u32,
    ) void {
        sqe.prep_rw(.uring_cmd, fd, 0, 0, 0);
        // off is overloaded with cmd_op, https://github.com/axboe/liburing/blob/e1003e496e66f9b0ae06674869795edf772d5500/src/include/liburing/io_uring.h#L39
        sqe.off = @intFromEnum(cmd_op);
        // addr is overloaded, https://github.com/axboe/liburing/blob/e1003e496e66f9b0ae06674869795edf772d5500/src/include/liburing/io_uring.h#L46
        sqe.addr = @bitCast(packed struct {
            level: u32,
            optname: u32,
        }{
            .level = @intFromEnum(level),
            .optname = @intFromEnum(optname),
        });
        // splice_fd_in if overloaded u32 -> i32
        sqe.splice_fd_in = @bitCast(optlen);
        // addr3 is overloaded, https://github.com/axboe/liburing/blob/e1003e496e66f9b0ae06674869795edf772d5500/src/include/liburing/io_uring.h#L102
        sqe.addr3 = optval;
    }

    pub fn set_flags(sqe: *Sqe, flags: Sqe.IoSqe) void {
        const updated_flags = @as(u8, @bitCast(sqe.flags)) | @as(u8, @bitCast(flags));
        sqe.flags = @bitCast(updated_flags);
    }

    /// This SQE forms a link with the next SQE in the submission ring. Next SQE
    /// will not be started before this one completes. Forms a chain of SQEs.
    pub fn link_next(sqe: *Sqe) void {
        sqe.flags.io_link = true;
    }
};

/// matches `io_uring_sq` in liburing
pub const Sq = struct {
    head: *u32,
    tail: *u32,
    mask: u32,
    flags: *Flags,
    dropped: *u32,
    array: []u32,
    sqes: []Sqe,
    mmap: []align(page_size_min) u8,
    mmap_sqes: []align(page_size_min) u8,
    // We use `sqe_head` and `sqe_tail` in the same way as liburing:
    // We increment `sqe_tail` (but not `tail`) for each call to `get_sqe()`.
    // We then set `tail` to `sqe_tail` once, only when these events are
    // actually submitted. This allows us to amortize the cost of the
    // @atomicStore to `tail` across multiple SQEs.
    sqe_head: u32 = 0,
    sqe_tail: u32 = 0,

    /// sq_ring.flags
    pub const Flags = packed struct(u32) {
        /// needs io_uring_enter wakeup
        need_wakeup: bool = false,
        /// CQ ring is overflown
        cq_overflow: bool = false,
        /// task should enter the kernel
        taskrun: bool = false,
        _: u29 = 0,
    };

    pub fn init(fd: posix.fd_t, p: Params) !Sq {
        assert(fd >= 0);
        assert(p.features.single_mmap);
        const size = @max(
            p.sq_off.array + p.sq_entries * @sizeOf(u32),
            p.cq_off.cqes + p.cq_entries * @sizeOf(Cqe),
        );
        const mmap = try posix.mmap(
            null,
            size,
            posix.PROT.READ | posix.PROT.WRITE,
            .{ .TYPE = .SHARED, .POPULATE = true },
            fd,
            constants.OFF_SQ_RING,
        );
        errdefer posix.munmap(mmap);
        assert(mmap.len == size);

        // The motivation for the `sqes` and `array` indirection is to make it
        // possible for the application to preallocate static io_uring_sqe
        // entries and then replay them when needed.
        const size_sqes = p.sq_entries * @sizeOf(Sqe);
        const mmap_sqes = try posix.mmap(
            null,
            size_sqes,
            posix.PROT.READ | posix.PROT.WRITE,
            .{ .TYPE = .SHARED, .POPULATE = true },
            fd,
            constants.OFF_SQES,
        );
        errdefer posix.munmap(mmap_sqes);
        assert(mmap_sqes.len == size_sqes);

        const array: [*]u32 = @ptrCast(@alignCast(&mmap[p.sq_off.array]));
        const sqes: [*]Sqe = @ptrCast(@alignCast(&mmap_sqes[0]));
        // We expect the kernel copies p.sq_entries to the u32 pointed to by
        // p.sq_off.ring_entries, See https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L7843-L7844.
        assert(p.sq_entries == @as(*u32, @ptrCast(@alignCast(&mmap[p.sq_off.ring_entries]))).*);
        return .{
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

    pub fn deinit(self: *Sq) void {
        posix.munmap(self.mmap_sqes);
        posix.munmap(self.mmap);
    }
};

/// matches `io_uring_cq` in liburing
pub const Cq = struct {
    head: *u32,
    tail: *u32,
    mask: u32,
    overflow: *u32,
    cqes: []Cqe,

    /// cq_ring.flags
    pub const Flags = packed struct(u32) {
        /// disable eventfd notifications
        eventfd_disabled: bool = false,
        _: u31 = 0,
    };

    pub fn init(fd: posix.fd_t, p: Params, sq: Sq) !Cq {
        assert(fd >= 0);
        assert(p.features.single_mmap);
        const mmap = sq.mmap;
        const cqes: [*]Cqe = @ptrCast(@alignCast(&mmap[p.cq_off.cqes]));
        assert(p.cq_entries == @as(*u32, @ptrCast(@alignCast(&mmap[p.cq_off.ring_entries]))).*);
        return .{
            .head = @ptrCast(@alignCast(&mmap[p.cq_off.head])),
            .tail = @ptrCast(@alignCast(&mmap[p.cq_off.tail])),
            .mask = @as(*u32, @ptrCast(@alignCast(&mmap[p.cq_off.ring_mask]))).*,
            .overflow = @ptrCast(@alignCast(&mmap[p.cq_off.overflow])),
            .cqes = cqes[0..p.cq_entries],
        };
    }

    pub fn deinit(self: *Cq) void {
        _ = self;
        // A no-op since we now share the mmap with the submission queue.
        // Here for symmetry with the submission queue, and for any future
        // feature support.
    }
};

/// Group of application provided buffers. Uses newer type, called ring mapped
/// buffers, supported since kernel 5.19. Buffers are identified by a buffer
/// group ID, and within that group, a buffer ID. IO_Uring can have multiple
/// buffer groups, each with unique group ID.
///
/// In `init` application provides contiguous block of memory `buffers` for
/// `buffers_count` buffers of size `buffers_size`. Application can then submit
/// `recv` operation without providing buffer upfront. Once the operation is
/// ready to receive data, a buffer is picked automatically and the resulting
/// CQE will contain the buffer ID in `cqe.buffer_id()`. Use `get` method to get
/// buffer for buffer ID identified by CQE. Once the application has processed
/// the buffer, it may hand ownership back to the kernel, by calling `put()`
/// allowing the cycle to repeat.
///
/// Depending on the rate of arrival of data, it is possible that a given buffer
/// group will run out of buffers before those in CQEs can be put back to the
/// kernel. If this happens, a `cqe.err()` will have ENOBUFS as the error value.
pub const BufferGroup = struct {
    /// Parent ring for which this group is registered.
    ring: *IoUring,
    /// Pointer to the memory shared by the kernel.
    /// `buffers_count` of `io_uring_buf` structures are shared by the kernel.
    /// First `io_uring_buf` is overlaid by `io_uring_buf_ring` struct.
    br: *align(page_size_min) BufferRing,
    /// Contiguous block of memory of size (buffers_count * buffer_size).
    buffers: []u8,
    /// Size of each buffer in buffers.
    buffer_size: u32,
    /// Number of buffers in `buffers`, number of `io_uring_buf structures` in br.
    buffers_count: u16,
    /// Head of unconsumed part of each buffer, if incremental consumption is enabled
    heads: []u32,
    /// ID of this group, must be unique in ring.
    group_id: u16,

    pub fn init(
        ring: *IoUring,
        allocator: mem.Allocator,
        group_id: u16,
        buffer_size: u32,
        buffers_count: u16,
    ) !BufferGroup {
        const buffers = try allocator.alloc(u8, buffer_size * buffers_count);
        errdefer allocator.free(buffers);
        const heads = try allocator.alloc(u32, buffers_count);
        errdefer allocator.free(heads);

        const br = try ring.init_buffer_ring(buffers_count, group_id, .{ .iou_pbuf_ring_inc = true });

        const mask = br.mask(buffers_count);
        var i: u16 = 0;
        while (i < buffers_count) : (i += 1) {
            const pos = buffer_size * i;
            const buf = buffers[pos .. pos + buffer_size];
            heads[i] = 0;
            br.add(buf, i, mask, i);
        }
        br.advance(buffers_count);

        return .{
            .ring = ring,
            .group_id = group_id,
            .br = br,
            .buffers = buffers,
            .heads = heads,
            .buffer_size = buffer_size,
            .buffers_count = buffers_count,
        };
    }

    pub fn deinit(self: *BufferGroup, allocator: mem.Allocator) void {
        self.br.deinit(self.ring, self.buffers_count, self.group_id);
        allocator.free(self.buffers);
        allocator.free(self.heads);
    }

    /// Prepare multishot read operation which will select buffer from this
    /// group.
    pub fn read_multishot(
        self: *BufferGroup,
        user_data: u64,
        fd: posix.fd_t,
        nbytes: u32,
        offset: u64,
    ) !*Sqe {
        var sqe = try self.ring.get_sqe();
        sqe.prep_rw(.read_multishot, fd, undefined, nbytes, offset);
        sqe.flags.buffer_select = true;
        sqe.buf_index = self.group_id;
        sqe.user_data = user_data;
        return sqe;
    }

    /// Prepare recv operation which will select buffer from this group.
    pub fn recv(
        self: *BufferGroup,
        user_data: u64,
        fd: posix.fd_t,
        flags: linux.Msg,
    ) !*Sqe {
        var sqe = try self.ring.get_sqe();
        sqe.prep_rw(.recv, fd, 0, 0, 0);
        sqe.rw_flags = @bitCast(flags);
        sqe.flags.buffer_select = true;
        sqe.buf_index = self.group_id;
        sqe.user_data = user_data;
        return sqe;
    }

    /// Prepare multishot recv operation which will select buffer from this
    /// group.
    pub fn recv_multishot(
        self: *BufferGroup,
        user_data: u64,
        fd: posix.fd_t,
        flags: linux.Msg,
    ) !*Sqe {
        var sqe = try self.recv(user_data, fd, flags);
        sqe.ioprio.send_recv.recv_multishot = true;
        return sqe;
    }

    // Get buffer by id.
    fn get_by_id(self: *BufferGroup, buffer_id: u16) []u8 {
        const pos = self.buffer_size * buffer_id;
        return self.buffers[pos .. pos + self.buffer_size][self.heads[buffer_id]..];
    }

    /// Get buffer by CQE.
    pub fn get(self: *BufferGroup, cqe: Cqe) ![]u8 {
        const buffer_id = try cqe.buffer_id();
        const used_len: usize = @intCast(cqe.res);
        return self.get_by_id(buffer_id)[0..used_len];
    }

    /// Release buffer from CQE to the kernel.
    pub fn put(self: *BufferGroup, cqe: Cqe) !void {
        const buffer_id = try cqe.buffer_id();
        if (cqe.flags.f_buf_more) {
            // Incremental consumption active, kernel will write to the this
            // buffer again
            const used_len: u32 = @intCast(cqe.res);
            // Track what part of the buffer is used
            self.heads[buffer_id] += used_len;
            return;
        }
        self.heads[buffer_id] = 0;

        // Release buffer to the kernel.
        const mask = self.br.mask(self.buffers_count);
        self.br.add(self.get_by_id(buffer_id), buffer_id, mask, 0);
        self.br.advance(1);
    }
};

/// Used to select how the read should be handled.
pub const ReadBuffer = union(enum) {
    /// io_uring will read directly into this buffer
    buffer: []u8,
    /// io_uring will read directly into these buffers using readv.
    iovecs: []const posix.iovec,
    /// io_uring will select a buffer that has previously been provided with
    /// `provide_buffers`.
    /// `group_id` must contain at least one buffer for the read to work.
    /// `len` controls the number of bytes to read into the selected buffer.
    buffer_selection: struct {
        group_id: u16,
        len: usize,
    },
};

/// Used to select how the write should be handled.
pub const WriteBuffer = union(enum) {
    /// io_uring will write data from this buffer into fd.
    buffer: []const u8,
    /// io_uring will write data from iovecs into fd using pwritev.
    iovecs: []const posix.iovec_const,
};

/// Used to select how the recv call should be handled.
pub const RecvBuffer = union(enum) {
    /// io_uring will recv directly into this buffer
    buffer: []u8,
    /// io_uring will select a buffer that has previously been provided with
    /// `provide_buffers`.
    /// `group_id` must contain at least one buffer for the recv call to work.
    /// `len` controls the number of bytes to read into the selected buffer.
    buffer_selection: struct {
        group_id: u16,
        len: usize,
    },
};

/// Filled with the offset for `mmap(2)`
/// matches `io_sqring_offsets` in liburing
pub const SqOffsets = extern struct {
    /// offset of ring head
    head: u32,
    /// offset of ring tail
    tail: u32,
    /// ring mask value
    ring_mask: u32,
    /// entries in ring
    ring_entries: u32,
    /// ring flags index
    flags: u32,
    /// number of sqes not submitted
    dropped: u32,
    /// sqe index array
    array: u32,
    resv1: u32,
    user_addr: u64,
};

/// matches `io_cqring_offsets` in liburing
pub const CqOffsets = extern struct {
    head: u32,
    tail: u32,
    ring_mask: u32,
    ring_entries: u32,
    overflow: u32,
    cqes: u32,
    flags: u32, // flags index
    resv: u32,
    user_addr: u64,
};

/// Passed in for `io_uring_setup(2)`. Copied back with updated info on success
/// matches `io_uring_params` in liburing
pub const Params = extern struct {
    sq_entries: u32,
    cq_entries: u32,
    flags: uflags.Setup,
    sq_thread_cpu: u32,
    sq_thread_idle: u32,
    features: uflags.Features,
    wq_fd: u32,
    resv: [3]u32,
    sq_off: SqOffsets,
    cq_off: CqOffsets,
};

// COMMIT: remove deprecated io_uring_rsrc_update struct
// deprecated, see struct io_uring_rsrc_update

// COMMIT: add new io_uring_region_desc struct
/// matches `io_uring_region_desc` in liburing
pub const RegionDesc = extern struct {
    user_addr: u64,
    size: u64,
    flags: Flags,
    id: u32,
    mmap_offset: u64,
    __resv: [4]u64,

    // COMMIT: new constant
    /// initialise with user provided memory pointed by user_addr
    pub const Flags = packed struct(u32) {
        type_user: bool = false,
        _: u31 = 0,
    };
};

// COMMIT: add new io_uring_mem_region_reg struct
/// matches `io_uring_mem_region_reg` in liburing
pub const MemRegionRegister = extern struct {
    /// struct io_uring_region_desc (RegionDesc in Zig)
    region_uptr: u64,
    flags: Flags,
    __resv: [2]u64,

    /// expose the region as registered wait arguments
    pub const Flags = packed struct(u64) {
        reg_wait_arg: bool = false,
        _: u63 = 0,
    };
};

/// matches `io_uring_rsrc_register` in liburing
pub const RsrcRegister = extern struct {
    nr: u32,
    flags: Flags,
    resv2: u64,
    data: u64,
    tags: u64,

    pub const Flags = packed struct(u32) {
        /// Register a fully sparse file space, rather than pass in an array of
        /// all -1 file descriptors.
        register_sparse: bool = false,
        _: 31 = 0,
    };
};

/// matches `io_uring_rsrc_update` in liburing
pub const RsrcUpdate = extern struct {
    offset: u32,
    resv: u32,
    data: u64,
};

/// matches `io_uring_rsrc_update2` in liburing
pub const RsrcUpdate2 = extern struct {
    offset: u32,
    resv: u32,
    data: u64,
    tags: u64,
    nr: u32,
    resv2: u32,
};

/// matches `io_uring_probe_op` in liburing
pub const ProbeOp = extern struct {
    op: Op,
    resv: u8,
    flags: Flags,
    resv2: u32,

    pub const Flags = packed struct(u16) {
        op_supported: bool = false,
        _: u15 = 0,
    };

    pub fn is_supported(self: ProbeOp) bool {
        return self.flags.op_supported;
    }
};

/// matches `io_uring_probe` in liburing
pub const Probe = extern struct {
    /// Last opcode supported
    last_op: Op,
    /// Length of ops[] array below
    ops_len: u8,
    resv: u16,
    resv2: [3]u32,
    ops: [256]ProbeOp,

    /// Is the operation supported on the running kernel.
    pub fn is_supported(self: *const Probe, op: Op) bool {
        const i = @intFromEnum(op);
        if (i > @intFromEnum(self.last_op) or i >= self.ops_len)
            return false;
        return self.ops[i].is_supported();
    }
};

// COMMIT: fix defination of io_uring_restriction
// RegisterOp is actually u8
/// matches `io_uring_restriction` in liburing
pub const Restriction = extern struct {
    opcode: RestrictionOp,
    arg: extern union {
        /// IORING_RESTRICTION_REGISTER_OP
        register_op: RegisterOp,
        /// IORING_RESTRICTION_SQE_OP
        sqe_op: Op,
        /// IORING_RESTRICTION_SQE_FLAGS_*
        sqe_flags: Sqe.IoSqe,
    },
    resv: u8,
    resv2: [3]u32,
};

// COMMIT: add new struct type
/// matches `io_uring_clock_register` in liburing
pub const ClockRegister = extern struct {
    clockid: u32,
    __resv: [3]u32,
};

// COMMIT: add new struct type
/// matches `io_uring_clone_buffers` in liburing
pub const CloneBuffers = extern struct {
    src_fd: u32,
    flags: Flags,
    src_off: u32,
    dst_off: u32,
    nr: u32,
    pad: [3]u32,

    // COMMIT: new flags
    pub const Flags = packed struct(u32) {
        register_src_registered: bool = false,
        register_dst_replace: bool = false,
        _: u30 = 0,
    };
};

/// matches `io_uring_buf` in liburing
pub const Buffer = extern struct {
    addr: u64,
    len: u32,
    bid: u16,
    resv: u16,
};

/// matches `io_uring_buf_ring` in liburing
pub const BufferRing = extern struct {
    resv1: u64,
    resv2: u32,
    resv3: u16,
    tail: u16,

    /// Initialises `br` so that it is ready to be used.
    /// matches `io_uring_buf_ring_init` in liburing
    fn init(br: *align(page_size_min) BufferRing) void {
        br.tail = 0;
    }

    // Unregisters a previously registered shared buffer ring, returned from
    // io_uring_setup_buf_ring.
    pub fn deinit(br: *align(page_size_min) BufferRing, uring: *IoUring, entries: u32, group_id: u16) void {
        uring.unregister_buffer_ring(group_id) catch {};
        var mmap: []align(page_size_min) u8 = undefined;
        mmap.ptr = @ptrCast(br);
        mmap.len = entries * @sizeOf(Buffer);
        posix.munmap(mmap);
    }

    /// Calculates the appropriate size mask for a buffer ring.
    /// `entries` is the ring entries as specified in io_uring_register_buf_ring
    pub fn mask(_: *align(page_size_min) BufferRing, entries: u16) u16 {
        return entries - 1;
    }

    /// Assigns `buffer` with the `br` buffer ring.
    /// `buffer_id` is identifier which will be returned in the CQE.
    /// `buffer_offset` is the offset to insert at from the current tail.
    /// If just one buffer is provided before the ring tail is committed with
    /// advance then offset should be 0.
    /// If buffers are provided in a loop before being committed, the offset must
    /// be incremented by one for each buffer added.
    pub fn add(
        br: *align(page_size_min) BufferRing,
        buffer: []u8,
        buffer_id: u16,
        buffer_mask: u16,
        buffer_offset: u16,
    ) void {
        const bufs: [*]Buffer = @ptrCast(br);
        const buf: *Buffer = &bufs[(br.tail +% buffer_offset) & buffer_mask];

        buf.addr = @intFromPtr(buffer.ptr);
        buf.len = @intCast(buffer.len);
        buf.bid = buffer_id;
    }

    /// Make `count` new buffers visible to the kernel. Called after
    /// `io_uring_buf_ring_add` has been called `count` times to fill in new
    /// buffers.
    pub fn advance(br: *align(page_size_min) BufferRing, count: u16) void {
        const tail: u16 = br.tail +% count;
        @atomicStore(u16, &br.tail, tail, .release);
    }
};

/// argument for IORING_(UN)REGISTER_PBUF_RING
/// matches `io_uring_buf_reg` in liburing
pub const BufferRegister = extern struct {
    ring_addr: u64,
    ring_entries: u32,
    bgid: u16,
    flags: Flags,
    resv: [3]u64,

    // COMMIT: new IORING_REGISTER_PBUF_RING flags
    /// Flags for IORING_REGISTER_PBUF_RING.
    pub const Flags = packed struct(u16) {
        /// IOU_PBUF_RING_MMAP:
        /// If set, kernel will allocate the memory for the ring.
        /// The application must not set a ring_addr in struct io_uring_buf_reg
        /// instead it must subsequently call mmap(2) with the offset set
        /// as: IORING_OFF_PBUF_RING | (bgid << IORING_OFF_PBUF_SHIFT) to get
        /// a virtual mapping for the ring.
        iou_pbuf_ring_mmap: bool = false,
        /// IOU_PBUF_RING_INC:
        /// If set, buffers consumed from this buffer ring can be
        /// consumed incrementally. Normally one (or more) buffers
        /// are fully consumed. With incremental consumptions, it's
        /// feasible to register big ranges of buffers, and each
        /// use of it will consume only as much as it needs. This
        /// requires that both the kernel and application keep
        /// track of where the current read/recv index is at.
        iou_pbuf_ring_inc: bool = false,
        _: u14 = 0,
    };
};

/// argument for IORING_REGISTER_PBUF_STATUS
/// matches `io_uring_buf_status` in liburing
pub const BufferStatus = extern struct {
    /// input
    buf_group: u32,
    /// output
    head: u32,
    resv: [8]u32,
};

/// argument for IORING_(UN)REGISTER_NAPI
/// matches `io_uring_napi` in liburing
pub const Napi = extern struct {
    busy_poll_to: u32,
    prefer_busy_poll: u8,
    pad: [3]u8,
    resv: u64,
};

// COMMIT: new struct type
/// Argument for io_uring_enter(2) with IORING_GETEVENTS | IORING_ENTER_EXT_ARG_REG
/// set, where the actual argument is an index into a previously registered
/// fixed wait region described by the below structure.
/// matches `io_uring_reg_wait` in liburing
pub const RegisterWait = extern struct {
    ts: linux.kernel_timespec,
    min_wait_usec: u32,
    flags: Flags,
    sigmask: u64,
    sigmask_sz: u32,
    pad: [3]u32,
    pad2: [2]u64,

    // COMMIT: new constant
    pub const Flags = packed struct(u32) {
        reg_wait_ts: bool = false,
        _: u31 = 0,
    };
};

/// Argument for `io_uring_enter(2)` with IORING_GETEVENTS |
/// IORING_ENTER_EXT_ARG
/// matches `io_uring_getevents_arg` in liburing
pub const GetEventsArg = extern struct {
    sigmask: u64,
    sigmask_sz: u32,
    pad: u32,
    ts: u64,
};

// COMMIT: fix type definition of io_uring_sync_cancel_reg
/// Argument for IORING_REGISTER_SYNC_CANCEL
/// matches `io_uring_sync_cancel_reg` in liburing
pub const SyncCancelRegister = extern struct {
    addr: u64,
    fd: i32,
    flags: uflags.AsyncCancel,
    timeout: linux.kernel_timespec,
    opcode: Op,
    pad: [7]u8,
    pad2: [4]u64,
};

/// Argument for IORING_REGISTER_FILE_ALLOC_RANGE
/// The range is specified as [off, off + len)
/// matches `io_uring_file_index_range` in liburing
pub const FileIndexRange = extern struct {
    off: u32,
    len: u32,
    resv: u64,
};

/// matches `io_uring_recvmsg_out` in liburing
pub const RecvmsgOut = extern struct {
    namelen: u32,
    controllen: u32,
    payloadlen: u32,
    flags: linux.Msg,
};

/// Zero copy receive refill queue entry
/// matches `io_uring_zcrx_rqe` in liburing
pub const ZcrxRqe = extern struct {
    off: u64,
    len: u32,
    __pad: u32,
};

/// matches `io_uring_zcrx_cqe` in liburing
pub const ZcrxCqe = extern struct {
    off: u64,
    __pad: u64,
};

/// matches `io_uring_zcrx_offsets` in liburing
pub const ZcrxOffsets = extern struct {
    head: u32,
    tail: u32,
    rqes: u32,
    __resv2: u32,
    __resv: [2]u64,
};

/// matches `io_uring_zcrx_area_reg` in liburing
pub const ZcrxAreaRegister = extern struct {
    addr: u64,
    len: u64,
    rq_area_token: u64,
    flags: Flags,
    dmabuf_fd: u32,
    __resv2: [2]u64,

    pub const Flags = packed struct(u32) {
        dmabuf: bool = false,
        _: u31 = 0,
    };
};

/// Argument for IORING_REGISTER_ZCRX_IFQ
/// matches `io_uring_zcrx_ifq_reg` in liburing
pub const ZcrxIfqRegister = extern struct {
    if_idx: u32,
    if_rxq: u32,
    rq_entries: u32,
    // FIXME: I don't know what these flags are yet even after my research
    flags: u32,
    /// pointer to struct io_uring_zcrx_area_reg
    area_ptr: u64,
    /// struct io_uring_region_desc
    region_ptr: u64,
    offsets: ZcrxOffsets, // the kernel fill in the offsets
    zcrx_id: u32,
    __resv2: u32,
    __resv: [3]u64,
};

// COMMIT: move IoUring constants to Constants
pub const constants = struct {
    /// If sqe.file_index (splice_fd_in in Zig Struct) is set to this for
    /// opcodes that instantiate a new an available direct descriptor instead
    /// of having the application pass one direct descriptor
    /// (like openat/openat2/accept), then io_uring will allocate in. The
    /// picked direct descriptor will be returned in cqe.res, or -ENFILE
    /// if the space is full.
    pub const FILE_INDEX_ALLOC = math.maxInt(u32);

    pub const CMD_MASK = 1 << 0;

    pub const TIMEOUT_CLOCK_MASK = ((1 << 2) | (1 << 3));
    pub const TIMEOUT_UPDATE_MASK = ((1 << 1) | (1 << 4));

    pub const CQE_BUFFER_SHIFT = 16;

    /// cqe.res for IORING_CQE_F_NOTIF if IORING_SEND_ZC_REPORT_USAGE was
    /// requested It should be treated as a flag, all other bits of cqe.res
    /// should be treated as reserved!
    pub const NOTIF_USAGE_ZC_COPIED = (1 << 31);

    //Magic offsets for the application to mmap the data it needs
    pub const OFF_SQ_RING = 0;
    pub const OFF_CQ_RING = 0x8000000;
    pub const OFF_SQES = 0x10000000;
    // COMMIT: new magic constants
    pub const OFF_PBUF_RING = 0x80000000;
    pub const OFF_PBUF_SHIFT = 16;
    pub const OFF_MMAP_MASK = 0xf8000000;

    /// Skip updating fd indexes set to this value in the fd table
    pub const REGISTER_FILES_SKIP = -2;

    // COMMIT: new TX Timestamp definition
    /// SOCKET_URING_OP_TX_TIMESTAMP definitions
    pub const TIMESTAMP_HW_SHIFT = 16;
    /// The cqe.flags bit from which the timestamp type is stored
    pub const TIMESTAMP_TYPE_SHIFT = (TIMESTAMP_HW_SHIFT + 1);
    /// The cqe.flags flag signifying whether it's a hardware timestamp
    pub const CQE_F_TSTAMP_HW = (1 << TIMESTAMP_HW_SHIFT);

    /// The bit from which area id is encoded into offsets
    pub const ZCRX_AREA_SHIFT = 48;
    pub const ZCRX_AREA_MASK = (~((1 << ZCRX_AREA_SHIFT) - 1));

    // flag added to the opcode to use a registered ring fd
    pub const REGISTER_USE_REGISTERED_RING = 1 << 31;
};

// COMMIT: move IoUring flags to Flags struct
pub const uflags = struct {
    /// io_uring_setup() flags
    pub const Setup = packed struct(u32) {
        /// io_context is polled
        iopoll: bool = false,
        /// SQ poll thread
        sqpoll: bool = false,
        /// sq_thread_cpu is valid
        sq_aff: bool = false,
        /// app defines CQ size
        cqsize: bool = false,
        /// clamp SQ/CQ ring sizes
        clamp: bool = false,
        /// attach to existing wq
        attach_wq: bool = false,
        /// start with ring disabled
        r_disabled: bool = false,
        /// continue submit on error
        submit_all: bool = false,
        /// Cooperative task running. When requests complete, they often require
        /// forcing the submitter to transition to the kernel to complete. If
        /// this flag is set, work will be done when the task transitions
        /// anyway, rather than force an inter-processor interrupt reschedule.
        /// This avoids interrupting a task running in userspace, and saves an
        /// IPI.
        coop_taskrun: bool = false,
        /// If COOP_TASKRUN is set, get notified if task work is available for
        /// running and a kernel transition would be needed to run it. This sets
        /// IORING_SQ_TASKRUN in the sq ring flags. Not valid with COOP_TASKRUN.
        taskrun_flag: bool = false,
        /// SQEs are 128 byte
        sqe128: bool = false,
        /// CQEs are 32 byte
        cqe32: bool = false,
        /// Only one task is allowed to submit requests
        single_issuer: bool = false,
        /// Defer running task work to get events.
        /// Rather than running bits of task work whenever the task transitions
        /// try to do it just before it is needed.
        defer_taskrun: bool = false,
        /// Application provides the memory for the rings
        no_mmap: bool = false,
        /// Register the ring fd in itself for use with
        /// IORING_REGISTER_USE_REGISTERED_RING; return a registered fd index
        /// rather than an fd.
        registered_fd_only: bool = false,
        /// Removes indirection through the SQ index array.
        no_sqarray: bool = false,
        // COMMIT: new setup flags
        /// Use hybrid poll in iopoll process
        hybrid_iopoll: bool = false,
        /// Allow both 16b and 32b CQEs. If a 32b CQE is posted, it will have
        /// IORING_CQE_F_32 set in cqe.flags.
        cqe_mixed: bool = false,
        _20: u13 = 0,
    };

    /// sqe.uring_cmd_flags (rw_flags in the Zig struct)
    /// top 8bits aren't available for userspace
    /// use registered buffer; pass this flag along with setting sqe.buf_index.
    pub const Cmd = packed struct(u32) {
        cmd_fixed: bool = false,
        _2: u31 = 0,
    };

    /// sqe.fsync_flags (rw_flags in the Zig struct)
    pub const Fsync = packed struct(u32) {
        datasync: bool = false,
        _2: u31 = 0,
    };

    /// sqe.timeout_flags
    pub const Timeout = packed struct(u32) {
        timeout_abs: bool = false,
        /// Available since Linux 5.11
        timeout_update: bool = false,
        /// Available since Linux 5.15
        timeout_boottime: bool = false,
        /// Available since Linux 5.15
        timeout_realtime: bool = false,
        /// Available since Linux 5.15
        link_timeout_update: bool = false,
        /// Available since Linux 5.16
        timeout_etime_success: bool = false,
        // COMMIT: new Timeout Flag
        // TODO: add when it became available
        timeout_multishot: bool = false,
        _8: u25 = 0,
    };

    /// sqe.splice_flags (rw_flags in Zig Struct)
    /// extends splice(2) flags
    pub const Splice = packed struct(u32) {
        _1: u31 = 0,
        /// the last bit of __u32
        f_fd_in_fixed: bool = false,
    };

    /// POLL_ADD flags. Note that since sqe.poll_events (rw_flags in Zig Struct)
    /// is the flag space, the command flags for POLL_ADD are stored in sqe.len.
    pub const Poll = packed struct(u32) {
        /// IORING_POLL_ADD_MULTI
        /// Multishot poll. Sets IORING_CQE_F_MORE if the poll handler will
        /// continue to report CQEs on behalf of the same SQE.
        add_multi: bool = false,
        // TODO: verify this doc comment is valid for the 2 flags below
        /// IORING_POLL_UPDATE
        /// Update existing poll request, matching sqe.addr as the old user_data
        /// field.
        update_events: bool = false,
        /// IORING_POLL_UPDATE
        /// Update existing poll request, matching sqe.addr as the old user_data
        /// field.
        update_user_data: bool = false,
        /// IORING_POLL_LEVEL
        /// Level triggered poll.
        add_level: bool = false,
        _5: u28 = 0,
    };

    /// ASYNC_CANCEL flags.
    pub const AsyncCancel = packed struct(u32) {
        /// IORING_ASYNC_CANCEL_ALL
        /// Cancel all requests that match the given key
        cancel_all: bool = false,
        /// IORING_ASYNC_CANCEL_FD
        /// Key off 'fd' for cancelation rather than the request 'user_data'
        cancel_fd: bool = false,
        /// IORING_ASYNC_CANCEL_ANY
        /// Match any request
        cancel_any: bool = false,
        /// IORING_ASYNC_CANCEL_FD_FIXED
        /// 'fd' passed in is a fixed descriptor
        cancel_fd_fixed: bool = false,
        // COMMIT: new AsyncCancel Flags
        /// IORING_ASYNC_CANCEL_USERDATA
        /// Match on user_data, default for no other key
        cancel_userdata: bool = false,
        /// IORING_ASYNC_CANCEL_OP
        /// Match request based on opcode
        cancel_op: bool = false,
        _7: u26 = 0,
    };

    /// IORING_OP_MSG_RING flags (sqe.msg_ring_flags or sqe.rw_flags in Zig Struct)
    pub const MsgRing = packed struct(u32) {
        /// IORING_MSG_RING_CQE_SKIP Don't post a CQE to the target ring.
        /// Not applicable for IORING_MSG_DATA, obviously.
        cqe_skip: bool = false,
        /// Pass through the flags from sqe.file_index to cqe.flags
        flags_pass: bool = false,
        _3: u30 = 0,
    };

    // COMMIT: new flag
    /// IORING_OP_FIXED_FD_INSTALL flags (sqe.install_fd_flags or sqe.rw_flags in Zig Struct)
    pub const FixedFd = packed struct(u32) {
        /// IORING_FIXED_FD_NO_CLOEXEC Don't mark the fd as O_CLOEXEC
        no_cloexec: bool = false,
    };

    /// COMMIT: new flags
    /// IORING_OP_NOP flags (sqe.nop_flags or sqe.rw_flags in Zig Struct)
    pub const Nop = packed struct(u32) {
        /// IORING_NOP_INJECT_RESULT Inject result from sqe.result
        inject_result: bool = false,
        _2: u4 = 0,
        cqe32: bool = false,
        _7: u26 = 0,
    };

    /// io_uring_enter(2) flags
    pub const Enter = packed struct(u32) {
        getevents: bool = false,
        sq_wakeup: bool = false,
        sq_wait: bool = false,
        ext_arg: bool = false,
        registered_ring: bool = false,
        // commit: new flags
        abs_timer: bool = false,
        ext_arg_reg: bool = false,
        no_iowait: bool = false,
        _9: u24 = 0,

        pub fn empty(enter_flags: Enter) bool {
            return @as(u32, @bitCast(enter_flags)) == 0;
        }
    };

    /// io_uring_params.features flags
    const Features = packed struct(u32) {
        single_mmap: bool = false,
        nodrop: bool = false,
        submit_stable: bool = false,
        rw_cur_pos: bool = false,
        cur_personality: bool = false,
        fast_poll: bool = false,
        poll_32bits: bool = false,
        sqpoll_nonfixed: bool = false,
        ext_arg: bool = false,
        native_workers: bool = false,
        rsrc_tags: bool = false,
        cqe_skip: bool = false,
        linked_file: bool = false,
        // commit: add new feature flags
        reg_reg_ring: bool = false,
        recvsend_bundle: bool = false,
        min_timeout: bool = false,
        rw_attr: bool = false,
        no_iowait: bool = false,
        _19: u14 = 0,

        pub fn empty(features: Features) bool {
            return @as(u32, @bitCast(features)) == 0;
        }
    };
};
/// `io_uring_register(2)` opcodes and arguments
/// matches `io_uring_register_op` in liburing
pub const RegisterOp = enum(u8) {
    register_buffers,
    unregister_buffers,
    register_files,
    unregister_files,
    register_eventfd,
    unregister_eventfd,
    register_files_update,
    register_eventfd_async,
    register_probe,
    register_personality,
    unregister_personality,
    register_restrictions,
    register_enable_rings,

    // extended with tagging
    register_files2,
    register_files_update2,
    register_buffers2,
    register_buffers_update,

    // set/clear io-wq thread affinities
    register_iowq_aff,
    unregister_iowq_aff,

    // set/get max number of io-wq workers
    register_iowq_max_workers,

    // register/unregister io_uring fd with the ring
    register_ring_fds,
    unregister_ring_fds,

    // register ring based provide buffer group
    register_pbuf_ring,
    unregister_pbuf_ring,

    // sync cancelation API
    register_sync_cancel,

    // register a range of fixed file slots for automatic slot allocation
    register_file_alloc_range,

    // return status information for a buffer group
    register_pbuf_status,

    // set/clear busy poll settings
    register_napi,
    unregister_napi,

    register_clock,

    // clone registered buffers from source ring to current ring
    register_clone_buffers,

    // send MSG_RING without having a ring
    register_send_msg_ring,

    // register a netdev hw rx queue for zerocopy
    register_zcrx_ifq,

    // resize CQ ring
    register_resize_rings,

    register_mem_region,

    // COMMIT: new register opcode
    // query various aspects of io_uring, see linux/io_uring/query.h
    register_query,

    _,
};

/// io-wq worker categories
/// matches `io_wq_type` in liburing
pub const IoWqCategory = enum(u8) {
    bound,
    unbound,
    _,
};

/// matches `io_uring_socket_op` in liburing
pub const SocketOp = enum(u16) {
    siocin,
    siocoutq,
    getsockopt,
    setsockopt,
    // COMMIT: new socket op
    tx_timestamp,
    _,
};

/// io_uring_restriction.opcode values
/// matches `io_uring_register_restriction_op` in liburing
pub const RestrictionOp = enum(u16) {
    /// Allow an io_uring_register(2) opcode
    register_op = 0,
    /// Allow an sqe opcode
    sqe_op = 1,
    /// Allow sqe flags
    sqe_flags_allowed = 2,
    /// Require sqe flags (these flags must be set on each submission)
    sqe_flags_required = 3,

    _,
};

/// IORING_OP_MSG_RING command types, stored in sqe.addr
/// matches `io_uring_msg_ring_flags` in liburing
pub const MsgRingCmd = enum {
    /// pass sqe->len as 'res' and off as user_data
    data,
    /// send a registered fd to another ring
    send_fd,
};

// COMMIT: OP to IoUring
/// matches `io_uring_op` in liburing
pub const Op = enum(u8) {
    nop,
    readv,
    writev,
    fsync,
    read_fixed,
    write_fixed,
    poll_add,
    poll_remove,
    sync_file_range,
    sendmsg,
    recvmsg,
    timeout,
    timeout_remove,
    accept,
    async_cancel,
    link_timeout,
    connect,
    fallocate,
    openat,
    close,
    files_update,
    statx,
    read,
    write,
    fadvise,
    madvise,
    send,
    recv,
    epoll_ctl,
    openat2,
    splice,
    provide_buffers,
    remove_buffers,
    tee,
    shutdown,
    renameat,
    unlinkat,
    mkdirat,
    symlinkat,
    linkat,
    msg_ring,
    fsetxattr,
    setxattr,
    fgetxattr,
    getxattr,
    socket,
    uring_cmd,
    send_zc,
    sendmsg_zc,
    read_multishot,
    waitid,
    futex_wait,
    futex_wake,
    futex_waitv,
    fixed_fd_install,
    ftruncate,
    bind,
    listen,
    recv_zc,
    // COMMIT: new OPs
    // TODO: to be implemented
    epoll_wait,
    readv_fixed,
    writev_fixed,
    pipe,

    _,
};

test "structs/offsets/entries" {
    if (!is_linux) return error.SkipZigTest;

    try testing.expectEqual(120, @sizeOf(Params));
    try testing.expectEqual(64, @sizeOf(Sqe));
    try testing.expectEqual(16, @sizeOf(Cqe));

    try testing.expectEqual(0, constants.OFF_SQ_RING);
    try testing.expectEqual(0x8000000, constants.OFF_CQ_RING);
    try testing.expectEqual(0x10000000, constants.OFF_SQES);

    try testing.expectError(error.EntriesZero, IoUring.init(0, .{}));
    try testing.expectError(error.EntriesNotPowerOfTwo, IoUring.init(3, .{}));
}

test "nop" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer {
        ring.deinit();
        testing.expectEqual(-1, ring.fd) catch @panic("test failed");
    }

    const sqe = try ring.nop(0xaaaaaaaa);
    try testing.expectEqual(Sqe{
        .opcode = .nop,
        .flags = .{},
        .ioprio = .init_empty(),
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

    try testing.expectEqual(0, ring.sq.sqe_head);
    try testing.expectEqual(1, ring.sq.sqe_tail);
    try testing.expectEqual(0, ring.sq.tail.*);
    try testing.expectEqual(0, ring.cq.head.*);
    try testing.expectEqual(1, ring.sq_ready());
    try testing.expectEqual(0, ring.cq_ready());

    try testing.expectEqual(1, try ring.submit());
    try testing.expectEqual(1, ring.sq.sqe_head);
    try testing.expectEqual(1, ring.sq.sqe_tail);
    try testing.expectEqual(1, ring.sq.tail.*);
    try testing.expectEqual(0, ring.cq.head.*);
    try testing.expectEqual(0, ring.sq_ready());

    try testing.expectEqual(Cqe{
        .user_data = 0xaaaaaaaa,
        .res = 0,
        .flags = .{},
    }, try ring.copy_cqe());
    try testing.expectEqual(1, ring.cq.head.*);
    try testing.expectEqual(0, ring.cq_ready());

    const sqe_barrier = try ring.nop(0xbbbbbbbb);
    sqe_barrier.flags.io_drain = true;
    try testing.expectEqual(1, try ring.submit());
    try testing.expectEqual(Cqe{
        .user_data = 0xbbbbbbbb,
        .res = 0,
        .flags = .{},
    }, try ring.copy_cqe());
    try testing.expectEqual(2, ring.sq.sqe_head);
    try testing.expectEqual(2, ring.sq.sqe_tail);
    try testing.expectEqual(2, ring.sq.tail.*);
    try testing.expectEqual(2, ring.cq.head.*);
}

test "readv" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try posix.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer posix.close(fd);

    // Linux Kernel 5.4 supports IORING_REGISTER_FILES but not sparse fd sets (i.e. an fd of -1).
    // Linux Kernel 5.5 adds support for sparse fd sets.
    // Compare:
    // https://github.com/torvalds/linux/blob/v5.4/fs/io_uring.c#L3119-L3124 vs
    // https://github.com/torvalds/linux/blob/v5.8/fs/io_uring.c#L6687-L6691
    // We therefore avoid stressing sparse fd sets here:
    var registered_fds = [_]linux.fd_t{0} ** 1;
    const fd_index = 0;
    registered_fds[fd_index] = fd;
    try ring.register_files(registered_fds[0..]);

    var buffer = [_]u8{42} ** 128;
    var iovecs = [_]posix.iovec{posix.iovec{ .base = &buffer, .len = buffer.len }};
    const sqe = try ring.read(0xcccccccc, fd_index, .{ .iovecs = iovecs[0..] }, 0);
    try testing.expectEqual(Op.readv, sqe.opcode);
    sqe.flags.fixed_file = true;

    try testing.expectError(error.SubmissionQueueFull, ring.nop(0));
    try testing.expectEqual(1, try ring.submit());
    try testing.expectEqual(Cqe{
        .user_data = 0xcccccccc,
        .res = buffer.len,
        .flags = .{},
    }, try ring.copy_cqe());
    try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer.len), buffer[0..]);

    try ring.unregister_files();
}

test "writev/fsync/readv" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(4, .{}) catch |err| switch (err) {
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
    const iovecs_write = [_]posix.iovec_const{
        posix.iovec_const{ .base = &buffer_write, .len = buffer_write.len },
    };
    var buffer_read = [_]u8{0} ** 128;
    var iovecs_read = [_]posix.iovec{
        posix.iovec{ .base = &buffer_read, .len = buffer_read.len },
    };

    const sqe_writev = try ring.write(0xdddddddd, fd, .{ .iovecs = iovecs_write[0..] }, 17);
    try testing.expectEqual(Op.writev, sqe_writev.opcode);
    try testing.expectEqual(17, sqe_writev.off);
    sqe_writev.link_next();

    const sqe_fsync = try ring.fsync(0xeeeeeeee, fd, .{});
    try testing.expectEqual(.fsync, sqe_fsync.opcode);
    try testing.expectEqual(fd, sqe_fsync.fd);
    sqe_fsync.link_next();

    const sqe_readv = try ring.read(0xffffffff, fd, .{ .iovecs = iovecs_read[0..] }, 17);
    try testing.expectEqual(Op.readv, sqe_readv.opcode);
    try testing.expectEqual(17, sqe_readv.off);

    try testing.expectEqual(3, ring.sq_ready());
    try testing.expectEqual(3, try ring.submit_and_wait(3));
    try testing.expectEqual(0, ring.sq_ready());
    try testing.expectEqual(3, ring.cq_ready());

    try testing.expectEqual(Cqe{
        .user_data = 0xdddddddd,
        .res = buffer_write.len,
        .flags = .{},
    }, try ring.copy_cqe());
    try testing.expectEqual(2, ring.cq_ready());

    try testing.expectEqual(Cqe{
        .user_data = 0xeeeeeeee,
        .res = 0,
        .flags = .{},
    }, try ring.copy_cqe());
    try testing.expectEqual(1, ring.cq_ready());

    try testing.expectEqual(Cqe{
        .user_data = 0xffffffff,
        .res = buffer_read.len,
        .flags = .{},
    }, try ring.copy_cqe());
    try testing.expectEqual(0, ring.cq_ready());

    try testing.expectEqualSlices(u8, buffer_write[0..], buffer_read[0..]);
}

test "write/read" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(2, .{}) catch |err| switch (err) {
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
    const sqe_write = try ring.write(0x11111111, fd, .{ .buffer = buffer_write[0..] }, 10);
    try testing.expectEqual(Op.write, sqe_write.opcode);
    try testing.expectEqual(10, sqe_write.off);
    sqe_write.flags.io_link = true;
    const sqe_read = try ring.read(0x22222222, fd, .{ .buffer = buffer_read[0..] }, 10);
    try testing.expectEqual(Op.read, sqe_read.opcode);
    try testing.expectEqual(10, sqe_read.off);
    try testing.expectEqual(2, try ring.submit());

    const cqe_write = try ring.copy_cqe();
    const cqe_read = try ring.copy_cqe();
    // Prior to Linux Kernel 5.6 this is the only way to test for read/write support:
    // https://lwn.net/Articles/809820/
    if (cqe_write.err() == .INVAL) return error.SkipZigTest;
    if (cqe_read.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(Cqe{
        .user_data = 0x11111111,
        .res = buffer_write.len,
        .flags = .{},
    }, cqe_write);
    try testing.expectEqual(Cqe{
        .user_data = 0x22222222,
        .res = buffer_read.len,
        .flags = .{},
    }, cqe_read);
    try testing.expectEqualSlices(u8, buffer_write[0..], buffer_read[0..]);
}

test "splice/read" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(4, .{}) catch |err| switch (err) {
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

    const fds = try posix.pipe();
    const pipe_offset: u64 = math.maxInt(u64);

    const sqe_splice_to_pipe = try ring.splice(0x11111111, fd_src, 0, fds[1], pipe_offset, buffer_write.len);
    try testing.expectEqual(Op.splice, sqe_splice_to_pipe.opcode);
    try testing.expectEqual(0, sqe_splice_to_pipe.addr);
    try testing.expectEqual(pipe_offset, sqe_splice_to_pipe.off);
    sqe_splice_to_pipe.link_next();

    const sqe_splice_from_pipe = try ring.splice(0x22222222, fds[0], pipe_offset, fd_dst, 10, buffer_write.len);
    try testing.expectEqual(Op.splice, sqe_splice_from_pipe.opcode);
    try testing.expectEqual(pipe_offset, sqe_splice_from_pipe.addr);
    try testing.expectEqual(10, sqe_splice_from_pipe.off);
    sqe_splice_from_pipe.link_next();

    const sqe_read = try ring.read(0x33333333, fd_dst, .{ .buffer = buffer_read[0..] }, 10);
    try testing.expectEqual(Op.read, sqe_read.opcode);
    try testing.expectEqual(10, sqe_read.off);
    try testing.expectEqual(3, try ring.submit());

    const cqe_splice_to_pipe = try ring.copy_cqe();
    const cqe_splice_from_pipe = try ring.copy_cqe();
    const cqe_read = try ring.copy_cqe();
    // Prior to Linux Kernel 5.6 this is the only way to test for splice/read support:
    // https://lwn.net/Articles/809820/
    if (cqe_splice_to_pipe.err() == .INVAL) return error.SkipZigTest;
    if (cqe_splice_from_pipe.err() == .INVAL) return error.SkipZigTest;
    if (cqe_read.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(Cqe{
        .user_data = 0x11111111,
        .res = buffer_write.len,
        .flags = .{},
    }, cqe_splice_to_pipe);
    try testing.expectEqual(Cqe{
        .user_data = 0x22222222,
        .res = buffer_write.len,
        .flags = .{},
    }, cqe_splice_from_pipe);
    try testing.expectEqual(Cqe{
        .user_data = 0x33333333,
        .res = buffer_read.len,
        .flags = .{},
    }, cqe_read);
    try testing.expectEqualSlices(u8, buffer_write[0..], buffer_read[0..]);
}

test "write_fixed/read_fixed" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(2, .{}) catch |err| switch (err) {
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

    var buffers = [2]posix.iovec{
        .{ .base = &raw_buffers[0], .len = raw_buffers[0].len },
        .{ .base = &raw_buffers[1], .len = raw_buffers[1].len },
    };
    ring.register_buffers(&buffers) catch |err| switch (err) {
        error.SystemResources => {
            // See https://github.com/ziglang/zig/issues/15362
            return error.SkipZigTest;
        },
        else => |e| return e,
    };

    const sqe_write = try ring.write_fixed(0x45454545, fd, .{ .buffer = raw_buffers[0][0..] }, 3, 0);
    try testing.expectEqual(Op.write_fixed, sqe_write.opcode);
    try testing.expectEqual(3, sqe_write.off);
    sqe_write.link_next();

    const sqe_read = try ring.read_fixed(0x12121212, fd, .{ .buffer = raw_buffers[1][0..] }, 0, 1);
    try testing.expectEqual(Op.read_fixed, sqe_read.opcode);
    try testing.expectEqual(0, sqe_read.off);

    try testing.expectEqual(2, try ring.submit());

    const cqe_write = try ring.copy_cqe();
    const cqe_read = try ring.copy_cqe();

    try testing.expectEqual(Cqe{
        .user_data = 0x45454545,
        .res = @intCast(buffers[0].len),
        .flags = .{},
    }, cqe_write);
    try testing.expectEqual(Cqe{
        .user_data = 0x12121212,
        .res = @intCast(buffers[1].len),
        .flags = .{},
    }, cqe_read);

    try testing.expectEqualSlices(u8, "\x00\x00\x00", buffers[1].base[0..3]);
    try testing.expectEqualSlices(u8, "foobar", buffers[1].base[3..9]);
    try testing.expectEqualSlices(u8, "zz", buffers[1].base[9..11]);
}

test "openat" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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
    const mode: posix.mode_t = 0o666;
    const sqe_openat = try ring.openat(0x33333333, tmp.dir.fd, path, flags, mode);
    try testing.expectEqual(Sqe{
        .opcode = .openat,
        .flags = .{},
        .ioprio = .init_empty(),
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
    try testing.expectEqual(1, try ring.submit());

    const cqe_openat = try ring.copy_cqe();
    try testing.expectEqual(0x33333333, cqe_openat.user_data);
    if (cqe_openat.err() == .INVAL) return error.SkipZigTest;
    if (cqe_openat.err() == .BADF) return error.SkipZigTest;
    if (cqe_openat.res <= 0) std.debug.print("\ncqe_openat.res={}\n", .{cqe_openat.res});
    try testing.expect(cqe_openat.res > 0);
    try testing.expectEqual(@as(Cqe.Flags, .{}), cqe_openat.flags);

    posix.close(cqe_openat.res);
}

test "close" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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
    try testing.expectEqual(Op.close, sqe_close.opcode);
    try testing.expectEqual(file.handle, sqe_close.fd);
    try testing.expectEqual(1, try ring.submit());

    const cqe_close = try ring.copy_cqe();
    if (cqe_close.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(Cqe{
        .user_data = 0x44444444,
        .res = 0,
        .flags = .{},
    }, cqe_close);
}

test "accept/connect/send/recv" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    const buffer_send = [_]u8{ 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 };
    var buffer_recv = [_]u8{ 0, 1, 0, 1, 0 };

    const sqe_send = try ring.send(0xeeeeeeee, socket_test_harness.client, buffer_send[0..], .{});
    sqe_send.link_next();

    _ = try ring.recv(0xffffffff, socket_test_harness.server, .{ .buffer = buffer_recv[0..] }, .{});
    try testing.expectEqual(2, try ring.submit());

    const cqe_send = try ring.copy_cqe();
    if (cqe_send.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(Cqe{
        .user_data = 0xeeeeeeee,
        .res = buffer_send.len,
        .flags = .{},
    }, cqe_send);

    const cqe_recv = try ring.copy_cqe();
    if (cqe_recv.err() == .INVAL) return error.SkipZigTest;
    try testing.expectEqual(Cqe{
        .user_data = 0xffffffff,
        .res = buffer_recv.len,
        // Only check IORING_CQE_F_SOCK_NONEMPTY flag, as other flags are
        // system-dependent
        .flags = .{ .f_sock_nonempty = cqe_recv.flags.f_sock_nonempty },
    }, cqe_recv);

    try testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);
}

test "sendmsg/recvmsg" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(2, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var address_server: linux.sockaddr.in = .{
        .port = 0,
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };

    const server = try posix.socket(address_server.family, posix.SOCK.DGRAM, 0);
    defer posix.close(server);
    try posix.setsockopt(server, posix.SOL.SOCKET, posix.SO.REUSEPORT, &mem.toBytes(@as(u32, 1)));
    try posix.setsockopt(server, posix.SOL.SOCKET, posix.SO.REUSEADDR, &mem.toBytes(@as(u32, 1)));
    try posix.bind(server, addrAny(&address_server), @sizeOf(linux.sockaddr.in));

    // set address_server to the OS-chosen IP/port.
    var slen: posix.socklen_t = @sizeOf(linux.sockaddr.in);
    try posix.getsockname(server, addrAny(&address_server), &slen);

    const client = try posix.socket(address_server.family, posix.SOCK.DGRAM, 0);
    defer posix.close(client);

    const buffer_send = [_]u8{42} ** 128;
    const iovecs_send = [_]posix.iovec_const{
        posix.iovec_const{ .base = &buffer_send, .len = buffer_send.len },
    };
    const msg_send: linux.msghdr_const = .{
        .name = addrAny(&address_server),
        .namelen = @sizeOf(linux.sockaddr.in),
        .iov = &iovecs_send,
        .iovlen = 1,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    const sqe_sendmsg = try ring.sendmsg(0x11111111, client, &msg_send, .{});
    sqe_sendmsg.flags.io_link = true;
    try testing.expectEqual(Op.sendmsg, sqe_sendmsg.opcode);
    try testing.expectEqual(client, sqe_sendmsg.fd);

    var buffer_recv = [_]u8{0} ** 128;
    var iovecs_recv = [_]posix.iovec{
        posix.iovec{ .base = &buffer_recv, .len = buffer_recv.len },
    };
    var address_recv: linux.sockaddr.in = .{
        .port = 0,
        .addr = 0,
    };
    var msg_recv: linux.msghdr = .{
        .name = addrAny(&address_recv),
        .namelen = @sizeOf(linux.sockaddr.in),
        .iov = &iovecs_recv,
        .iovlen = 1,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    const sqe_recvmsg = try ring.recvmsg(0x22222222, server, &msg_recv, .{});
    try testing.expectEqual(Op.recvmsg, sqe_recvmsg.opcode);
    try testing.expectEqual(server, sqe_recvmsg.fd);

    try testing.expectEqual(2, ring.sq_ready());
    try testing.expectEqual(2, try ring.submit_and_wait(2));
    try testing.expectEqual(0, ring.sq_ready());
    try testing.expectEqual(2, ring.cq_ready());

    const cqe_sendmsg = try ring.copy_cqe();
    if (cqe_sendmsg.res == -@as(i32, @intFromEnum(linux.E.INVAL))) return error.SkipZigTest;
    try testing.expectEqual(Cqe{
        .user_data = 0x11111111,
        .res = buffer_send.len,
        .flags = .{},
    }, cqe_sendmsg);

    const cqe_recvmsg = try ring.copy_cqe();
    if (cqe_recvmsg.res == -@as(i32, @intFromEnum(linux.E.INVAL))) return error.SkipZigTest;
    try testing.expectEqual(Cqe{
        .user_data = 0x22222222,
        .res = buffer_recv.len,
        // ignore IORING_CQE_F_SOCK_NONEMPTY since it is set non-deterministically
        .flags = .{ .f_sock_nonempty = cqe_recvmsg.flags.f_sock_nonempty },
    }, cqe_recvmsg);

    try testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);
}

test "timeout (after a relative time)" {
    if (!is_linux) return error.SkipZigTest;
    const io = std.testing.io;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const ms = 10;
    const ts: linux.kernel_timespec = .{ .sec = 0, .nsec = ms * 1000000 };

    const started = try std.Io.Clock.awake.now(io);
    const sqe = try ring.timeout(0x55555555, &ts, 0, .{});
    try testing.expectEqual(Op.timeout, sqe.opcode);
    try testing.expectEqual(1, try ring.submit());
    const cqe = try ring.copy_cqe();
    const stopped = try std.Io.Clock.awake.now(io);

    try testing.expectEqual(Cqe{
        .user_data = 0x55555555,
        .res = -@as(i32, @intFromEnum(linux.E.TIME)),
        .flags = .{},
    }, cqe);

    // Tests should not depend on timings: skip test if outside margin.
    const margin = 5;
    const ms_elapsed = started.durationTo(stopped).toMilliseconds();
    if (ms_elapsed > margin) return error.SkipZigTest;
}

test "timeout (after a number of completions)" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(2, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const ts: linux.kernel_timespec = .{ .sec = 3, .nsec = 0 };
    const count_completions: u64 = 1;
    const sqe_timeout = try ring.timeout(0x66666666, &ts, count_completions, .{});
    try testing.expectEqual(Op.timeout, sqe_timeout.opcode);
    try testing.expectEqual(count_completions, sqe_timeout.off);
    _ = try ring.nop(0x77777777);
    try testing.expectEqual(2, try ring.submit());

    const cqe_nop = try ring.copy_cqe();
    try testing.expectEqual(Cqe{
        .user_data = 0x77777777,
        .res = 0,
        .flags = .{},
    }, cqe_nop);

    const cqe_timeout = try ring.copy_cqe();
    try testing.expectEqual(Cqe{
        .user_data = 0x66666666,
        .res = 0,
        .flags = .{},
    }, cqe_timeout);
}

test "timeout_remove" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(2, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const ts: linux.kernel_timespec = .{ .sec = 3, .nsec = 0 };
    const sqe_timeout = try ring.timeout(0x88888888, &ts, 0, .{});
    try testing.expectEqual(Op.timeout, sqe_timeout.opcode);
    try testing.expectEqual(0x88888888, sqe_timeout.user_data);

    const sqe_timeout_remove = try ring.timeout_remove(0x99999999, 0x88888888, .{});
    try testing.expectEqual(Op.timeout_remove, sqe_timeout_remove.opcode);
    try testing.expectEqual(0x88888888, sqe_timeout_remove.addr);
    try testing.expectEqual(0x99999999, sqe_timeout_remove.user_data);

    try testing.expectEqual(2, try ring.submit());

    // The order in which the CQE arrive is not clearly documented and it changed with kernel 5.18:
    // * kernel 5.10 gives user data 0x88888888 first, 0x99999999 second
    // * kernel 5.18 gives user data 0x99999999 first, 0x88888888 second

    var cqes: [2]Cqe = undefined;
    cqes[0] = try ring.copy_cqe();
    cqes[1] = try ring.copy_cqe();

    for (cqes) |cqe| {
        // IORING_OP_TIMEOUT_REMOVE is not supported by this kernel version:
        // Timeout remove operations set the fd to -1, which results in EBADF before EINVAL.
        // We use IORING_FEAT_RW_CUR_POS as a safety check here to make sure we are at least pre-5.6.
        // We don't want to skip this test for newer kernels.
        if (cqe.user_data == 0x99999999 and
            cqe.err() == .BADF and
            (!ring.features.rw_cur_pos))
        {
            return error.SkipZigTest;
        }

        try testing.expect(cqe.user_data == 0x88888888 or cqe.user_data == 0x99999999);

        if (cqe.user_data == 0x88888888) {
            try testing.expectEqual(Cqe{
                .user_data = 0x88888888,
                .res = -@as(i32, @intFromEnum(linux.E.CANCELED)),
                .flags = .{},
            }, cqe);
        } else if (cqe.user_data == 0x99999999) {
            try testing.expectEqual(Cqe{
                .user_data = 0x99999999,
                .res = 0,
                .flags = .{},
            }, cqe);
        }
    }
}

test "accept/connect/recv/link_timeout" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    var buffer_recv = [_]u8{ 0, 1, 0, 1, 0 };

    const sqe_recv = try ring.recv(0xffffffff, socket_test_harness.server, .{ .buffer = buffer_recv[0..] }, .{});
    sqe_recv.link_next();

    const ts = linux.kernel_timespec{ .sec = 0, .nsec = 1000000 };
    _ = try ring.link_timeout(0x22222222, &ts, .{});

    const nr_wait = try ring.submit();
    try testing.expectEqual(2, nr_wait);

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
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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

    try testing.expectEqual(0, (try file.stat()).size);

    const len: u64 = 65536;
    const sqe = try ring.fallocate(0xaaaaaaaa, file.handle, 0, 0, len);
    try testing.expectEqual(Op.fallocate, sqe.opcode);
    try testing.expectEqual(file.handle, sqe.fd);
    try testing.expectEqual(1, try ring.submit());

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
    try testing.expectEqual(Cqe{
        .user_data = 0xaaaaaaaa,
        .res = 0,
        .flags = .{},
    }, cqe);

    try testing.expectEqual(len, (try file.stat()).size);
}

test "statx" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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

    try testing.expectEqual(0, (try file.stat()).size);

    try file.writeAll("foobar");

    var buf: linux.Statx = undefined;
    const sqe = try ring.statx(
        0xaaaaaaaa,
        tmp.dir.fd,
        path,
        .{},
        .{ .size = true },
        &buf,
    );
    try testing.expectEqual(Op.statx, sqe.opcode);
    try testing.expectEqual(tmp.dir.fd, sqe.fd);
    try testing.expectEqual(1, try ring.submit());

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
    try testing.expectEqual(Cqe{
        .user_data = 0xaaaaaaaa,
        .res = 0,
        .flags = .{},
    }, cqe);

    try testing.expect(buf.mask.size);
    try testing.expectEqual(6, buf.size);
}

test "accept/connect/recv/cancel" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    var buffer_recv = [_]u8{ 0, 1, 0, 1, 0 };

    _ = try ring.recv(0xffffffff, socket_test_harness.server, .{ .buffer = buffer_recv[0..] }, .{});
    try testing.expectEqual(1, try ring.submit());

    const sqe_cancel = try ring.cancel(0x99999999, 0xffffffff, .{});
    try testing.expectEqual(Op.async_cancel, sqe_cancel.opcode);
    try testing.expectEqual(0xffffffff, sqe_cancel.addr);
    try testing.expectEqual(0x99999999, sqe_cancel.user_data);
    try testing.expectEqual(1, try ring.submit());

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

    try testing.expectEqual(Cqe{
        .user_data = 0xffffffff,
        .res = -@as(i32, @intFromEnum(linux.E.CANCELED)),
        .flags = .{},
    }, cqe_recv);

    try testing.expectEqual(Cqe{
        .user_data = 0x99999999,
        .res = 0,
        .flags = .{},
    }, cqe_cancel);
}

test "register_files_update" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try posix.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer posix.close(fd);

    var registered_fds = [_]linux.fd_t{0} ** 2;
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

    const fd2 = try posix.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer posix.close(fd2);

    registered_fds[fd_index] = fd2;
    registered_fds[fd_index2] = -1;
    try ring.register_files_update(0, registered_fds[0..]);

    var buffer = [_]u8{42} ** 128;
    {
        const sqe = try ring.read(0xcccccccc, fd_index, .{ .buffer = &buffer }, 0);
        try testing.expectEqual(Op.read, sqe.opcode);
        sqe.set_flags(.{ .fixed_file = true });

        try testing.expectEqual(1, try ring.submit());
        try testing.expectEqual(Cqe{
            .user_data = 0xcccccccc,
            .res = buffer.len,
            .flags = .{},
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
        try testing.expectEqual(Op.read, sqe.opcode);
        sqe.set_flags(.{ .fixed_file = true });

        try testing.expectEqual(1, try ring.submit());
        try testing.expectEqual(Cqe{
            .user_data = 0xcccccccc,
            .res = buffer.len,
            .flags = .{},
        }, try ring.copy_cqe());
        try testing.expectEqualSlices(u8, &([_]u8{0} ** buffer.len), buffer[0..]);
    }

    try ring.register_files_update(0, registered_fds[0..]);

    {
        // Now this should fail since both fds are sparse (-1)
        const sqe = try ring.read(0xcccccccc, fd_index, .{ .buffer = &buffer }, 0);
        try testing.expectEqual(Op.read, sqe.opcode);
        sqe.set_flags(.{ .fixed_file = true });

        try testing.expectEqual(1, try ring.submit());
        const cqe = try ring.copy_cqe();
        try testing.expectEqual(linux.E.BADF, cqe.err());
    }

    try ring.unregister_files();
}

test "shutdown" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var address: linux.sockaddr.in = .{
        .port = 0,
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };

    // Socket bound, expect shutdown to work
    {
        // TODO: update posix later to use Typed Flags
        const server = try posix.socket(address.any.family, @as(u32, @bitCast(linux.Sock{ .type = .stream, .flags = .{ .cloexec = true } })), 0);
        defer posix.close(server);
        try posix.setsockopt(server, posix.SOL.SOCKET, posix.SO.REUSEADDR, &mem.toBytes(@as(u32, 1)));
        try posix.bind(server, addrAny(&address), @sizeOf(linux.sockaddr.in));
        try posix.listen(server, 1);

        // set address to the OS-chosen IP/port.
        var slen: posix.socklen_t = @sizeOf(linux.sockaddr.in);
        try posix.getsockname(server, addrAny(&address), &slen);

        const shutdown_sqe = try ring.shutdown(0x445445445, server, .rd);
        try testing.expectEqual(Op.shutdown, shutdown_sqe.opcode);
        try testing.expectEqual(server, shutdown_sqe.fd);

        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            // This kernel's io_uring does not yet implement shutdown (kernel version < 5.11)
            .INVAL => return error.SkipZigTest,
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expectEqual(Cqe{
            .user_data = 0x445445445,
            .res = 0,
            .flags = .{},
        }, cqe);
    }

    // Socket not bound, expect to fail with ENOTCONN
    {
        const server = try posix.socket(address.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
        defer posix.close(server);

        const shutdown_sqe = ring.shutdown(0x445445445, server, .rd) catch |err| switch (err) {
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        };
        try testing.expectEqual(Op.shutdown, shutdown_sqe.opcode);
        try testing.expectEqual(server, shutdown_sqe.fd);

        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        try testing.expectEqual(0x445445445, cqe.user_data);
        try testing.expectEqual(linux.E.NOTCONN, cqe.err());
    }
}

test "renameat" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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
        .{},
    );
    try testing.expectEqual(Op.renameat, sqe.opcode);
    try testing.expectEqual(tmp.dir.fd, sqe.fd);
    try testing.expectEqual(tmp.dir.fd, @as(i32, @intCast(sqe.len)));
    try testing.expectEqual(1, try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement renameat (kernel version < 5.11)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(Cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = .{},
    }, cqe);

    // Validate that the old file doesn't exist anymore
    try testing.expectError(error.FileNotFound, tmp.dir.openFile(old_path, .{}));

    // Validate that the new file exists with the proper content
    var new_file_data: [16]u8 = undefined;
    try testing.expectEqualStrings("hello", try tmp.dir.readFile(new_path, &new_file_data));
}

test "unlinkat" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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
        .{},
    );
    try testing.expectEqual(Op.unlinkat, sqe.opcode);
    try testing.expectEqual(tmp.dir.fd, sqe.fd);
    try testing.expectEqual(1, try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement unlinkat (kernel version < 5.11)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(Cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = .{},
    }, cqe);

    // Validate that the file doesn't exist anymore
    _ = tmp.dir.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {},
        else => std.debug.panic("unexpected error: {}", .{err}),
    };
}

test "mkdirat" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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
    try testing.expectEqual(Op.mkdirat, sqe.opcode);
    try testing.expectEqual(tmp.dir.fd, sqe.fd);
    try testing.expectEqual(1, try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement mkdirat (kernel version < 5.15)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(Cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = .{},
    }, cqe);

    // Validate that the directory exist
    _ = try tmp.dir.openDir(path, .{});
}

test "symlinkat" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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
    try testing.expectEqual(Op.symlinkat, sqe.opcode);
    try testing.expectEqual(tmp.dir.fd, sqe.fd);
    try testing.expectEqual(1, try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement symlinkat (kernel version < 5.15)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(Cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = .{},
    }, cqe);

    // Validate that the symlink exist
    _ = try tmp.dir.openFile(link_path, .{});
}

test "linkat" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
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
        .{},
    );
    try testing.expectEqual(Op.linkat, sqe.opcode);
    try testing.expectEqual(tmp.dir.fd, sqe.fd);
    try testing.expectEqual(tmp.dir.fd, @as(i32, @intCast(sqe.len)));
    try testing.expectEqual(1, try ring.submit());

    const cqe = try ring.copy_cqe();
    switch (cqe.err()) {
        .SUCCESS => {},
        // This kernel's io_uring does not yet implement linkat (kernel version < 5.15)
        .BADF, .INVAL => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }
    try testing.expectEqual(Cqe{
        .user_data = 0x12121212,
        .res = 0,
        .flags = .{},
    }, cqe);

    // Validate the second file
    var second_file_data: [16]u8 = undefined;
    try testing.expectEqualStrings("hello", try tmp.dir.readFile(second_path, &second_file_data));
}

test "provide_buffers: read" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try posix.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer posix.close(fd);

    const group_id = 1337;
    const buffer_id = 0;

    const buffer_len = 128;

    var buffers: [4][buffer_len]u8 = undefined;

    // Provide 4 buffers

    {
        const sqe = try ring.provide_buffers(0xcccccccc, @ptrCast(&buffers), buffer_len, buffers.len, group_id, buffer_id);
        try testing.expectEqual(Op.provide_buffers, sqe.opcode);
        try testing.expectEqual(@as(i32, buffers.len), sqe.fd);
        try testing.expectEqual(buffers[0].len, sqe.len);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Happens when the kernel is < 5.7
            .INVAL, .BADF => return error.SkipZigTest,
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(0xcccccccc, cqe.user_data);
    }

    // Do 4 reads which should consume all buffers

    var i: usize = 0;
    while (i < buffers.len) : (i += 1) {
        const sqe = try ring.read(0xdededede, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(Op.read, sqe.opcode);
        try testing.expectEqual(fd, sqe.fd);
        try testing.expectEqual(0, sqe.addr);
        try testing.expectEqual(buffer_len, sqe.len);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags.f_buffer);
        const used_buffer_id = try cqe.buffer_id();
        try testing.expect(used_buffer_id >= 0 and used_buffer_id <= 3);
        try testing.expectEqual(buffer_len, cqe.res);

        try testing.expectEqual(0xdededede, cqe.user_data);
        const empty: [buffer_len]u8 = @splat(0);
        try testing.expectEqualSlices(u8, empty[0..], buffers[used_buffer_id][0..@intCast(cqe.res)]);
    }

    // This read should fail

    {
        const sqe = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(Op.read, sqe.opcode);
        try testing.expectEqual(fd, sqe.fd);
        try testing.expectEqual(0, sqe.addr);
        try testing.expectEqual(buffer_len, sqe.len);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Expected
            .NOBUFS => {},
            .SUCCESS => std.debug.panic("unexpected success", .{}),
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(0xdfdfdfdf, cqe.user_data);
    }

    // Provide 1 buffer again

    // Deliberately put something we don't expect in the buffers
    @memset(mem.sliceAsBytes(&buffers), 42);

    const reprovided_buffer_id = 2;

    {
        _ = try ring.provide_buffers(0xabababab, @ptrCast(&buffers[reprovided_buffer_id]), buffer_len, 1, group_id, reprovided_buffer_id);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
    }

    // Final read which should work

    {
        const sqe = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(Op.read, sqe.opcode);
        try testing.expectEqual(fd, sqe.fd);
        try testing.expectEqual(0, sqe.addr);
        try testing.expectEqual(buffer_len, sqe.len);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags.f_buffer);
        const used_buffer_id = try cqe.buffer_id();
        try testing.expectEqual(used_buffer_id, reprovided_buffer_id);
        try testing.expectEqual(buffer_len, cqe.res);
        try testing.expectEqual(0xdfdfdfdf, cqe.user_data);
        const empty: [buffer_len]u8 = @splat(0);
        try testing.expectEqualSlices(u8, empty[0..], buffers[used_buffer_id][0..@intCast(cqe.res)]);
    }
}

test "remove_buffers" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const fd = try posix.openZ("/dev/zero", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer posix.close(fd);

    const group_id = 1337;
    const buffer_id = 0;

    const buffer_len = 128;

    var buffers: [4][buffer_len]u8 = undefined;

    // Provide 4 buffers

    {
        _ = try ring.provide_buffers(0xcccccccc, @ptrCast(&buffers), buffer_len, buffers.len, group_id, buffer_id);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .INVAL, .BADF => return error.SkipZigTest,
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(0xcccccccc, cqe.user_data);
    }

    // Remove 3 buffers

    {
        const sqe = try ring.remove_buffers(0xbababababa, 3, group_id);
        try testing.expectEqual(Op.remove_buffers, sqe.opcode);
        try testing.expectEqual(3, sqe.fd);
        try testing.expectEqual(0, sqe.addr);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(0xbababababa, cqe.user_data);
    }

    // This read should work

    {
        _ = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags.f_buffer);
        const used_buffer_id = try cqe.buffer_id();
        try testing.expect(used_buffer_id >= 0 and used_buffer_id < 4);
        try testing.expectEqual(buffer_len, cqe.res);
        try testing.expectEqual(0xdfdfdfdf, cqe.user_data);
        const empty: [buffer_len]u8 = @splat(0);
        try testing.expectEqualSlices(u8, empty[0..], buffers[used_buffer_id][0..@intCast(cqe.res)]);
    }

    // Final read should _not_ work

    {
        _ = try ring.read(0xdfdfdfdf, fd, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, 0);
        try testing.expectEqual(1, try ring.submit());

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
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
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
        const sqe = try ring.provide_buffers(0xcccccccc, @ptrCast(&buffers), buffer_len, buffers.len, group_id, buffer_id);
        try testing.expectEqual(Op.provide_buffers, sqe.opcode);
        try testing.expectEqual(@as(i32, buffers.len), sqe.fd);
        try testing.expectEqual(buffer_len, sqe.len);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Happens when the kernel is < 5.7
            .INVAL => return error.SkipZigTest,
            // Happens on the kernel 5.4
            .BADF => return error.SkipZigTest,
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(0xcccccccc, cqe.user_data);
    }

    const socket_test_harness = try createSocketTestHarness(&ring);
    defer socket_test_harness.close();

    // Do 4 send on the socket

    {
        var i: usize = 0;
        while (i < buffers.len) : (i += 1) {
            _ = try ring.send(0xdeaddead, socket_test_harness.server, &([_]u8{'z'} ** buffer_len), .{});
            try testing.expectEqual(1, try ring.submit());
        }

        var cqes: [4]Cqe = undefined;
        try testing.expectEqual(4, try ring.copy_cqes(&cqes, 4));
    }

    // Do 4 recv which should consume all buffers

    // Deliberately put something we don't expect in the buffers
    @memset(mem.sliceAsBytes(&buffers), 1);

    var i: usize = 0;
    while (i < buffers.len) : (i += 1) {
        const sqe = try ring.recv(0xdededede, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, .{});
        try testing.expectEqual(Op.recv, sqe.opcode);
        try testing.expectEqual(@as(i32, socket_test_harness.client), sqe.fd);
        try testing.expectEqual(0, sqe.addr);
        try testing.expectEqual(buffer_len, sqe.len);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(0, sqe.rw_flags);
        try testing.expectEqual(Sqe.IoSqe{ .buffer_select = true }, sqe.flags);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags.f_buffer);
        const used_buffer_id = try cqe.buffer_id();
        try testing.expect(used_buffer_id >= 0 and used_buffer_id <= 3);
        try testing.expectEqual(buffer_len, cqe.res);

        try testing.expectEqual(0xdededede, cqe.user_data);
        const zzz: [buffer_len]u8 = @splat('z');
        try testing.expectEqualSlices(u8, zzz[0..], buffers[used_buffer_id][0..@intCast(cqe.res)]);
    }

    // This recv should fail

    {
        const sqe = try ring.recv(0xdfdfdfdf, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, .{});
        try testing.expectEqual(Op.recv, sqe.opcode);
        try testing.expectEqual(@as(i32, socket_test_harness.client), sqe.fd);
        try testing.expectEqual(0, sqe.addr);
        try testing.expectEqual(buffer_len, sqe.len);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(0, sqe.rw_flags);
        try testing.expectEqual(Sqe.IoSqe{ .buffer_select = true }, sqe.flags);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            // Expected
            .NOBUFS => {},
            .SUCCESS => std.debug.panic("unexpected success", .{}),
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
        try testing.expectEqual(0xdfdfdfdf, cqe.user_data);
    }

    // Provide 1 buffer again

    const reprovided_buffer_id = 2;

    {
        _ = try ring.provide_buffers(0xabababab, @ptrCast(&buffers[reprovided_buffer_id]), buffer_len, 1, group_id, reprovided_buffer_id);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }
    }

    // Redo 1 send on the server socket

    {
        _ = try ring.send(0xdeaddead, socket_test_harness.server, &([_]u8{'w'} ** buffer_len), .{});
        try testing.expectEqual(1, try ring.submit());

        _ = try ring.copy_cqe();
    }

    // Final recv which should work

    // Deliberately put something we don't expect in the buffers
    @memset(mem.sliceAsBytes(&buffers), 1);

    {
        const sqe = try ring.recv(0xdfdfdfdf, socket_test_harness.client, .{ .buffer_selection = .{ .group_id = group_id, .len = buffer_len } }, .{});
        try testing.expectEqual(Op.recv, sqe.opcode);
        try testing.expectEqual(@as(i32, socket_test_harness.client), sqe.fd);
        try testing.expectEqual(0, sqe.addr);
        try testing.expectEqual(buffer_len, sqe.len);
        try testing.expectEqual(group_id, sqe.buf_index);
        try testing.expectEqual(0, sqe.rw_flags);
        try testing.expectEqual(Sqe.IoSqe{ .buffer_select = true }, sqe.flags);
        try testing.expectEqual(1, try ring.submit());

        const cqe = try ring.copy_cqe();
        switch (cqe.err()) {
            .SUCCESS => {},
            else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
        }

        try testing.expect(cqe.flags.f_buffer);
        const used_buffer_id = try cqe.buffer_id();
        try testing.expectEqual(used_buffer_id, reprovided_buffer_id);
        try testing.expectEqual(buffer_len, cqe.res);
        try testing.expectEqual(0xdfdfdfdf, cqe.user_data);
        const www: [buffer_len]u8 = @splat('w');
        try testing.expectEqualSlices(u8, www[0..], buffers[used_buffer_id][0..@intCast(cqe.res)]);
    }
}

/// Used for testing server/client interactions.
const SocketTestHarness = struct {
    listener: posix.socket_t,
    server: posix.socket_t,
    client: posix.socket_t,

    fn close(self: SocketTestHarness) void {
        posix.close(self.client);
        posix.close(self.listener);
    }
};

fn createSocketTestHarness(ring: *IoUring) !SocketTestHarness {
    // Create a TCP server socket
    var address: linux.sockaddr.in = .{
        .port = 0,
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };
    const listener_socket = try createListenerSocket(&address);
    errdefer posix.close(listener_socket);

    // Submit 1 accept
    var accept_addr: posix.sockaddr = undefined;
    var accept_addr_len: posix.socklen_t = @sizeOf(@TypeOf(accept_addr));
    _ = try ring.accept(0xaaaaaaaa, listener_socket, &accept_addr, &accept_addr_len, .{});

    // Create a TCP client socket
    const client = try posix.socket(address.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(client);
    _ = try ring.connect(0xcccccccc, client, addrAny(&address), @sizeOf(linux.sockaddr.in));

    try testing.expectEqual(2, try ring.submit());

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

    try testing.expectEqual(0xaaaaaaaa, cqe_accept.user_data);
    if (cqe_accept.res <= 0) std.debug.print("\ncqe_accept.res={}\n", .{cqe_accept.res});
    try testing.expect(cqe_accept.res > 0);
    try testing.expectEqual(@as(Cqe.Flags, .{}), cqe_accept.flags);
    try testing.expectEqual(Cqe{
        .user_data = 0xcccccccc,
        .res = 0,
        .flags = .{},
    }, cqe_connect);

    // All good

    return .{
        .listener = listener_socket,
        .server = cqe_accept.res,
        .client = client,
    };
}

fn createListenerSocket(address: *linux.sockaddr.in) !posix.socket_t {
    const kernel_backlog = 1;
    const listener_socket = try posix.socket(address.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(listener_socket);

    try posix.setsockopt(listener_socket, posix.SOL.SOCKET, posix.SO.REUSEADDR, &mem.toBytes(@as(u32, 1)));
    try posix.bind(listener_socket, addrAny(address), @sizeOf(linux.sockaddr.in));
    try posix.listen(listener_socket, kernel_backlog);

    // set address to the OS-chosen IP/port.
    var slen: posix.socklen_t = @sizeOf(linux.sockaddr.in);
    try posix.getsockname(listener_socket, addrAny(address), &slen);

    return listener_socket;
}

test "accept multishot" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var address: linux.sockaddr.in = .{
        .port = 0,
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };
    const listener_socket = try createListenerSocket(&address);
    defer posix.close(listener_socket);

    // submit multishot accept operation
    var addr: posix.sockaddr = undefined;
    var addr_len: posix.socklen_t = @sizeOf(@TypeOf(addr));
    const userdata: u64 = 0xaaaaaaaa;
    _ = try ring.accept_multishot(userdata, listener_socket, &addr, &addr_len, .{});
    try testing.expectEqual(1, try ring.submit());

    var nr: usize = 4; // number of clients to connect
    while (nr > 0) : (nr -= 1) {
        // connect client
        const client = try posix.socket(address.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
        errdefer posix.close(client);
        try posix.connect(client, addrAny(&address), @sizeOf(linux.sockaddr.in));

        // test accept completion
        var cqe = try ring.copy_cqe();
        if (cqe.err() == .INVAL) return error.SkipZigTest;
        try testing.expect(cqe.res > 0);
        try testing.expect(cqe.user_data == userdata);
        try testing.expect(cqe.flags.f_more); // more flag is set

        posix.close(client);
    }
}

test "accept/connect/send_zc/recv" {
    try skipKernelLessThan(.{ .major = 6, .minor = 0, .patch = 0 });

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
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
    const sqe_send = try ring.send_zc(0xeeeeeeee, socket_test_harness.client, buffer_send[0..], .{}, .{});
    sqe_send.link_next();
    _ = try ring.recv(0xffffffff, socket_test_harness.server, .{ .buffer = buffer_recv[0..] }, .{});
    try testing.expectEqual(2, try ring.submit());

    var cqe_send = try ring.copy_cqe();
    // First completion of zero-copy send.
    // IORING_CQE_F_MORE, means that there
    // will be a second completion event / notification for the
    // request, with the user_data field set to the same value.
    // buffer_send must be keep alive until second cqe.
    try testing.expectEqual(Cqe{
        .user_data = 0xeeeeeeee,
        .res = buffer_send.len,
        .flags = .{ .f_more = true },
    }, cqe_send);

    cqe_send, const cqe_recv = brk: {
        const cqe1 = try ring.copy_cqe();
        const cqe2 = try ring.copy_cqe();
        break :brk if (cqe1.user_data == 0xeeeeeeee) .{ cqe1, cqe2 } else .{ cqe2, cqe1 };
    };

    try testing.expectEqual(Cqe{
        .user_data = 0xffffffff,
        .res = buffer_recv.len,
        .flags = .{ .f_sock_nonempty = cqe_recv.flags.f_sock_nonempty },
    }, cqe_recv);
    try testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);

    // Second completion of zero-copy send.
    // IORING_CQE_F_NOTIF in flags signals that kernel is done with send_buffer
    try testing.expectEqual(Cqe{
        .user_data = 0xeeeeeeee,
        .res = 0,
        .flags = .{ .f_notif = true },
    }, cqe_send);
}

test "accept_direct" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();
    var address: linux.sockaddr.in = .{
        .port = 0,
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };

    // register direct file descriptors
    var registered_fds = [_]linux.fd_t{-1} ** 2;
    try ring.register_files(registered_fds[0..]);

    const listener_socket = try createListenerSocket(&address);
    defer posix.close(listener_socket);

    const accept_userdata: u64 = 0xaaaaaaaa;
    const read_userdata: u64 = 0xbbbbbbbb;
    const data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xa, 0xb, 0xc, 0xd, 0xe };

    for (0..2) |_| {
        for (registered_fds, 0..) |_, i| {
            var buffer_recv: [16]u8 = @splat(0);
            const buffer_send: []const u8 = data[0 .. data.len - i]; // make it different at each loop

            // submit accept, will chose registered fd and return index in cqe
            _ = try ring.accept_direct(accept_userdata, listener_socket, null, null, .{});
            try testing.expectEqual(1, try ring.submit());

            // connect
            const client = try posix.socket(address.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
            try posix.connect(client, addrAny(&address), @sizeOf(linux.sockaddr.in));
            defer posix.close(client);

            // accept completion
            const cqe_accept = try ring.copy_cqe();
            try testing.expectEqual(posix.E.SUCCESS, cqe_accept.err());
            const fd_index = cqe_accept.res;
            try testing.expect(fd_index < registered_fds.len);
            try testing.expect(cqe_accept.user_data == accept_userdata);

            // send data
            _ = try posix.send(client, buffer_send, 0);

            // Example of how to use registered fd:
            // Submit receive to fixed file returned by accept (fd_index).
            // Fd field is set to registered file index, returned by accept.
            // Flag linux.IOSQE_FIXED_FILE must be set.
            const recv_sqe = try ring.recv(read_userdata, fd_index, .{ .buffer = &buffer_recv }, .{});
            recv_sqe.set_flags(.{ .fixed_file = true });

            try testing.expectEqual(1, try ring.submit());

            // accept receive
            const recv_cqe = try ring.copy_cqe();
            try testing.expect(recv_cqe.user_data == read_userdata);
            try testing.expect(recv_cqe.res == buffer_send.len);
            try testing.expectEqualSlices(u8, buffer_send, buffer_recv[0..buffer_send.len]);
        }
        // no more available fds, accept will get NFILE error
        {
            // submit accept
            _ = try ring.accept_direct(accept_userdata, listener_socket, null, null, .{});
            try testing.expectEqual(1, try ring.submit());
            // connect
            const client = try posix.socket(address.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
            try posix.connect(client, addrAny(&address), @sizeOf(linux.sockaddr.in));
            defer posix.close(client);
            // completion with error
            const cqe_accept = try ring.copy_cqe();
            try testing.expect(cqe_accept.user_data == accept_userdata);
            try testing.expectEqual(posix.E.NFILE, cqe_accept.err());
        }
        // return file descriptors to kernel
        try ring.register_files_update(0, registered_fds[0..]);
    }
    try ring.unregister_files();
}

test "accept_multishot_direct" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    if (builtin.cpu.arch == .riscv64) {
        // https://github.com/ziglang/zig/issues/25734
        return error.SkipZigTest;
    }

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var address: linux.sockaddr.in = .{
        .port = 0,
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };

    var registered_fds = [_]linux.fd_t{-1} ** 2;
    try ring.register_files(registered_fds[0..]);

    const listener_socket = try createListenerSocket(&address);
    defer posix.close(listener_socket);

    const accept_userdata: u64 = 0xaaaaaaaa;

    for (0..2) |_| {
        // submit multishot accept
        // Will chose registered fd and return index of the selected registered file in cqe.
        _ = try ring.accept_multishot_direct(accept_userdata, listener_socket, null, null, .{});
        try testing.expectEqual(1, try ring.submit());

        for (registered_fds) |_| {
            // connect
            const client = try posix.socket(address.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
            try posix.connect(client, addrAny(&address), @sizeOf(linux.sockaddr.in));
            defer posix.close(client);

            // accept completion
            const cqe_accept = try ring.copy_cqe();
            const fd_index = cqe_accept.res;
            try testing.expect(fd_index < registered_fds.len);
            try testing.expect(cqe_accept.user_data == accept_userdata);
            try testing.expect(cqe_accept.flags.f_more); // has more is set
        }
        // No more available fds, accept will get NFILE error.
        // Multishot is terminated (more flag is not set).
        {
            // connect
            const client = try posix.socket(address.family, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
            try posix.connect(client, addrAny(&address), @sizeOf(linux.sockaddr.in));
            defer posix.close(client);
            // completion with error
            const cqe_accept = try ring.copy_cqe();
            try testing.expect(cqe_accept.user_data == accept_userdata);
            try testing.expectEqual(posix.E.NFILE, cqe_accept.err());
            try testing.expect(!cqe_accept.flags.f_more); // has more is not set
        }
        // return file descriptors to kernel
        try ring.register_files_update(0, registered_fds[0..]);
    }
    try ring.unregister_files();
}

test "socket" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IoUring.init(1, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    // prepare, submit socket operation
    _ = try ring.socket(0, .inet, .{ .type = .stream }, .default, 0);
    try testing.expectEqual(1, try ring.submit());

    // test completion
    var cqe = try ring.copy_cqe();
    try testing.expectEqual(posix.E.SUCCESS, cqe.err());
    const fd: linux.fd_t = @intCast(cqe.res);
    try testing.expect(fd > 2);

    posix.close(fd);
}

test "socket_direct/socket_direct_alloc/close_direct" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IoUring.init(2, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var registered_fds = [_]linux.fd_t{-1} ** 3;
    try ring.register_files(registered_fds[0..]);

    // create socket in registered file descriptor at index 0 (last param)
    _ = try ring.socket_direct(0, .inet, .{ .type = .stream }, .default, 0, 0);
    try testing.expectEqual(1, try ring.submit());
    var cqe_socket = try ring.copy_cqe();
    try testing.expectEqual(posix.E.SUCCESS, cqe_socket.err());
    try testing.expect(cqe_socket.res == 0);

    // create socket in registered file descriptor at index 1 (last param)
    _ = try ring.socket_direct(0, .inet, .{ .type = .stream }, .default, 0, 1);
    try testing.expectEqual(1, try ring.submit());
    cqe_socket = try ring.copy_cqe();
    try testing.expectEqual(posix.E.SUCCESS, cqe_socket.err());
    try testing.expect(cqe_socket.res == 0); // res is 0 when index is specified

    // create socket in kernel chosen file descriptor index (_alloc version)
    // completion res has index from registered files
    _ = try ring.socket_direct_alloc(0, .inet, .{ .type = .stream }, .default, 0);
    try testing.expectEqual(1, try ring.submit());
    cqe_socket = try ring.copy_cqe();
    try testing.expectEqual(posix.E.SUCCESS, cqe_socket.err());
    try testing.expect(cqe_socket.res == 2); // returns registered file index

    // use sockets from registered_fds in connect operation
    var address: linux.sockaddr.in = .{
        .port = 0,
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };
    const listener_socket = try createListenerSocket(&address);
    defer posix.close(listener_socket);
    const accept_userdata: u64 = 0xaaaaaaaa;
    const connect_userdata: u64 = 0xbbbbbbbb;
    const close_userdata: u64 = 0xcccccccc;
    for (registered_fds, 0..) |_, fd_index| {
        // prepare accept
        _ = try ring.accept(accept_userdata, listener_socket, null, null, .{});
        // prepare connect with fixed socket
        const connect_sqe = try ring.connect(connect_userdata, @intCast(fd_index), addrAny(&address), @sizeOf(linux.sockaddr.in));
        // fd is fixed file index
        connect_sqe.set_flags(.{ .fixed_file = true });
        // submit both
        try testing.expectEqual(2, try ring.submit());
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
        try testing.expectEqual(posix.E.SUCCESS, cqe_connect.err());
        // test accept completion
        try testing.expect(cqe_accept.user_data == accept_userdata);
        try testing.expectEqual(posix.E.SUCCESS, cqe_accept.err());

        //  submit and test close_direct
        _ = try ring.close_direct(close_userdata, @intCast(fd_index));
        try testing.expectEqual(1, try ring.submit());
        var cqe_close = try ring.copy_cqe();
        try testing.expect(cqe_close.user_data == close_userdata);
        try testing.expectEqual(posix.E.SUCCESS, cqe_close.err());
    }

    try ring.unregister_files();
}

test "openat_direct/close_direct" {
    try skipKernelLessThan(.{ .major = 5, .minor = 19, .patch = 0 });

    var ring = IoUring.init(2, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    var registered_fds = [_]linux.fd_t{-1} ** 3;
    try ring.register_files(registered_fds[0..]);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = "test_io_uring_close_direct";
    const flags: linux.O = .{ .ACCMODE = .RDWR, .CREAT = true };
    const mode: posix.mode_t = 0o666;
    const user_data: u64 = 0;

    // use registered file at index 0 (last param)
    _ = try ring.openat_direct(user_data, tmp.dir.fd, path, flags, mode, 0);
    try testing.expectEqual(1, try ring.submit());
    var cqe = try ring.copy_cqe();
    try testing.expectEqual(posix.E.SUCCESS, cqe.err());
    try testing.expect(cqe.res == 0);

    // use registered file at index 1
    _ = try ring.openat_direct(user_data, tmp.dir.fd, path, flags, mode, 1);
    try testing.expectEqual(1, try ring.submit());
    cqe = try ring.copy_cqe();
    try testing.expectEqual(posix.E.SUCCESS, cqe.err());
    try testing.expect(cqe.res == 0); // res is 0 when we specify index

    // let kernel choose registered file index
    _ = try ring.openat_direct(user_data, tmp.dir.fd, path, flags, mode, constants.FILE_INDEX_ALLOC);
    try testing.expectEqual(1, try ring.submit());
    cqe = try ring.copy_cqe();
    try testing.expectEqual(posix.E.SUCCESS, cqe.err());
    try testing.expect(cqe.res == 2); // chosen index is in res

    // close all open file descriptors
    for (registered_fds, 0..) |_, fd_index| {
        _ = try ring.close_direct(user_data, @intCast(fd_index));
        try testing.expectEqual(1, try ring.submit());
        var cqe_close = try ring.copy_cqe();
        try testing.expectEqual(posix.E.SUCCESS, cqe_close.err());
    }
    try ring.unregister_files();
}

test "waitid" {
    try skipKernelLessThan(.{ .major = 6, .minor = 7, .patch = 0 });

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const pid = try posix.fork();
    if (pid == 0) {
        posix.exit(7);
    }

    var siginfo: posix.siginfo_t = undefined;
    _ = try ring.waitid(0, .PID, pid, &siginfo, .{ .exited = true }, 0);

    try testing.expectEqual(1, try ring.submit());

    const cqe_waitid = try ring.copy_cqe();
    try testing.expectEqual(0, cqe_waitid.res);
    try testing.expectEqual(pid, siginfo.fields.common.first.piduid.pid);
    try testing.expectEqual(7, siginfo.fields.common.second.sigchld.status);
}

/// For use in tests. Returns SkipZigTest if kernel version is less than required.
inline fn skipKernelLessThan(required: std.SemanticVersion) !void {
    if (!is_linux) return error.SkipZigTest;

    var uts: linux.utsname = undefined;
    const res = linux.uname(&uts);
    switch (linux.errno(res)) {
        .SUCCESS => {},
        else => |errno| return posix.unexpectedErrno(errno),
    }

    const release = mem.sliceTo(&uts.release, 0);
    // Make sure the input don't rely on the extra we are about to stripped
    try testing.expect(required.pre == null and required.build == null);

    const stripped = blk: {
        // Strips potential extra, as kernel version might not be semver compliant, example "6.8.9-300.fc40.x86_64"
        const extra_index = std.mem.findAny(u8, release, "-+");
        const stripped = release[0..(extra_index orelse release.len)];

        // wsl kernel isn't semver compliant
        // .ie 6.6.87.2-microsoft-standard-WSL2 strip the extra .2 after 87
        const wsl = "WSL2";
        if (std.mem.eql(u8, release[release.len - wsl.len ..][0..wsl.len], wsl)) {
            const wsl_stripped, _ = std.mem.cutScalarLast(u8, stripped, '.') orelse unreachable;
            break :blk wsl_stripped;
        }
        break :blk stripped;
    };
    var current = try std.SemanticVersion.parse(stripped);
    current.pre = null; // don't check pre field

    if (required.order(current) == .gt) return error.SkipZigTest;
}

test BufferGroup {
    if (!is_linux) return error.SkipZigTest;

    // Init IoUring
    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    // Init buffer group for ring
    const group_id: u16 = 1; // buffers group id
    const buffers_count: u16 = 1; // number of buffers in buffer group
    const buffer_size: usize = 128; // size of each buffer in group
    var buf_grp = BufferGroup.init(
        &ring,
        testing.allocator,
        group_id,
        buffer_size,
        buffers_count,
    ) catch |err| switch (err) {
        // kernel older than 5.19
        error.ArgumentsInvalid => return error.SkipZigTest,
        else => return err,
    };
    defer buf_grp.deinit(testing.allocator);

    // Create client/server fds
    const fds = try createSocketTestHarness(&ring);
    defer fds.close();
    const data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xa, 0xb, 0xc, 0xd, 0xe };

    // Client sends data
    {
        _ = try ring.send(1, fds.client, data[0..], .{});
        const submitted = try ring.submit();
        try testing.expectEqual(1, submitted);
        const cqe_send = try ring.copy_cqe();
        if (cqe_send.err() == .INVAL) return error.SkipZigTest;
        try testing.expectEqual(Cqe{ .user_data = 1, .res = data.len, .flags = .{} }, cqe_send);
    }

    // Server uses buffer group receive
    {
        // Submit recv operation, buffer will be chosen from buffer group
        _ = try buf_grp.recv(2, fds.server, .{});
        const submitted = try ring.submit();
        try testing.expectEqual(1, submitted);

        // ... when we have completion for recv operation
        const cqe = try ring.copy_cqe();
        try testing.expectEqual(2, cqe.user_data); // matches submitted user_data
        try testing.expect(cqe.res >= 0); // success
        try testing.expectEqual(posix.E.SUCCESS, cqe.err());
        try testing.expectEqual(@as(i32, data.len), cqe.res); // cqe.res holds received data len

        // Get buffer from pool
        const buf = try buf_grp.get(cqe);
        try testing.expectEqualSlices(u8, &data, buf);
        // Release buffer to the kernel when application is done with it
        try buf_grp.put(cqe);
    }
}

test "ring mapped buffers recv" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    // init buffer group
    const group_id: u16 = 1; // buffers group id
    const buffers_count: u16 = 2; // number of buffers in buffer group
    const buffer_size: usize = 4; // size of each buffer in group
    var buf_grp = BufferGroup.init(
        &ring,
        testing.allocator,
        group_id,
        buffer_size,
        buffers_count,
    ) catch |err| switch (err) {
        // kernel older than 5.19
        error.ArgumentsInvalid => return error.SkipZigTest,
        else => return err,
    };
    defer buf_grp.deinit(testing.allocator);

    // create client/server fds
    const fds = try createSocketTestHarness(&ring);
    defer fds.close();

    // for random user_data in sqe/cqe
    var Rnd = std.Random.DefaultPrng.init(std.testing.random_seed);
    var rnd = Rnd.random();

    var round: usize = 4; // repeat send/recv cycle round times
    while (round > 0) : (round -= 1) {
        // client sends data
        const data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xa, 0xb, 0xc, 0xd, 0xe };
        {
            const user_data = rnd.int(u64);
            _ = try ring.send(user_data, fds.client, data[0..], .{});
            try testing.expectEqual(1, try ring.submit());
            const cqe_send = try ring.copy_cqe();
            if (cqe_send.err() == .INVAL) return error.SkipZigTest;
            try testing.expectEqual(Cqe{ .user_data = user_data, .res = data.len, .flags = .{} }, cqe_send);
        }
        var pos: usize = 0;

        // read first chunk
        const cqe1 = try buf_grp_recv_submit_get_cqe(&ring, &buf_grp, fds.server, rnd.int(u64));
        var buf = try buf_grp.get(cqe1);
        try testing.expectEqualSlices(u8, data[pos..][0..buf.len], buf);
        pos += buf.len;
        // second chunk
        const cqe2 = try buf_grp_recv_submit_get_cqe(&ring, &buf_grp, fds.server, rnd.int(u64));
        buf = try buf_grp.get(cqe2);
        try testing.expectEqualSlices(u8, data[pos..][0..buf.len], buf);
        pos += buf.len;

        // both buffers provided to the kernel are used so we get error
        // 'no more buffers', until we put buffers to the kernel
        {
            const user_data = rnd.int(u64);
            _ = try buf_grp.recv(user_data, fds.server, .{});
            try testing.expectEqual(1, try ring.submit());
            const cqe = try ring.copy_cqe();
            try testing.expectEqual(user_data, cqe.user_data);
            try testing.expect(cqe.res < 0); // fail
            try testing.expectEqual(posix.E.NOBUFS, cqe.err());
            try testing.expect(!cqe.flags.f_buffer); // IORING_CQE_F_BUFFER flags is set on success only
            try testing.expectError(error.NoBufferSelected, cqe.buffer_id());
        }

        // put buffers back to the kernel
        try buf_grp.put(cqe1);
        try buf_grp.put(cqe2);

        // read remaining data
        while (pos < data.len) {
            const cqe = try buf_grp_recv_submit_get_cqe(&ring, &buf_grp, fds.server, rnd.int(u64));
            buf = try buf_grp.get(cqe);
            try testing.expectEqualSlices(u8, data[pos..][0..buf.len], buf);
            pos += buf.len;
            try buf_grp.put(cqe);
        }
    }
}

test "ring mapped buffers multishot recv" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(16, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    // init buffer group
    const group_id: u16 = 1; // buffers group id
    const buffers_count: u16 = 2; // number of buffers in buffer group
    const buffer_size: usize = 4; // size of each buffer in group
    var buf_grp = BufferGroup.init(
        &ring,
        testing.allocator,
        group_id,
        buffer_size,
        buffers_count,
    ) catch |err| switch (err) {
        // kernel older than 5.19
        error.ArgumentsInvalid => return error.SkipZigTest,
        else => return err,
    };
    defer buf_grp.deinit(testing.allocator);

    // create client/server fds
    const fds = try createSocketTestHarness(&ring);
    defer fds.close();

    // for random user_data in sqe/cqe
    var Rnd = std.Random.DefaultPrng.init(std.testing.random_seed);
    var rnd = Rnd.random();

    var round: usize = 4; // repeat send/recv cycle round times
    while (round > 0) : (round -= 1) {
        // client sends data
        const data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xa, 0xb, 0xc, 0xd, 0xe, 0xf };
        {
            const user_data = rnd.int(u64);
            _ = try ring.send(user_data, fds.client, data[0..], .{});
            try testing.expectEqual(1, try ring.submit());
            const cqe_send = try ring.copy_cqe();
            if (cqe_send.err() == .INVAL) return error.SkipZigTest;
            try testing.expectEqual(Cqe{ .user_data = user_data, .res = data.len, .flags = .{} }, cqe_send);
        }

        // start multishot recv
        var recv_user_data = rnd.int(u64);
        _ = try buf_grp.recv_multishot(recv_user_data, fds.server, .{});
        try testing.expectEqual(1, try ring.submit()); // submit

        // server reads data into provided buffers
        // there are 2 buffers of size 4, so each read gets only chunk of data
        // we read four chunks of 4, 4, 4, 4 bytes each
        var chunk: []const u8 = data[0..buffer_size]; // first chunk
        const cqe1 = try expect_buf_grp_cqe(&ring, &buf_grp, recv_user_data, chunk);
        try testing.expect(cqe1.flags.f_more);

        chunk = data[buffer_size .. buffer_size * 2]; // second chunk
        const cqe2 = try expect_buf_grp_cqe(&ring, &buf_grp, recv_user_data, chunk);
        try testing.expect(cqe2.flags.f_more);

        // both buffers provided to the kernel are used so we get error
        // 'no more buffers', until we put buffers to the kernel
        {
            const cqe = try ring.copy_cqe();
            try testing.expectEqual(recv_user_data, cqe.user_data);
            try testing.expect(cqe.res < 0); // fail
            try testing.expectEqual(posix.E.NOBUFS, cqe.err());
            // IORING_CQE_F_BUFFER flags is set on success only
            try testing.expect(!cqe.flags.f_buffer);
            // has more is not set
            // indicates that multishot is finished
            try testing.expect(!cqe.flags.f_more);
            try testing.expectError(error.NoBufferSelected, cqe.buffer_id());
        }

        // put buffers back to the kernel
        try buf_grp.put(cqe1);
        try buf_grp.put(cqe2);

        // restart multishot
        recv_user_data = rnd.int(u64);
        _ = try buf_grp.recv_multishot(recv_user_data, fds.server, .{});
        try testing.expectEqual(1, try ring.submit()); // submit

        chunk = data[buffer_size * 2 .. buffer_size * 3]; // third chunk
        const cqe3 = try expect_buf_grp_cqe(&ring, &buf_grp, recv_user_data, chunk);
        try testing.expect(cqe3.flags.f_more);
        try buf_grp.put(cqe3);

        chunk = data[buffer_size * 3 ..]; // last chunk
        const cqe4 = try expect_buf_grp_cqe(&ring, &buf_grp, recv_user_data, chunk);
        try testing.expect(cqe4.flags.f_more);
        try buf_grp.put(cqe4);

        // cancel pending multishot recv operation
        {
            const cancel_user_data = rnd.int(u64);
            _ = try ring.cancel(cancel_user_data, recv_user_data, .{});
            try testing.expectEqual(1, try ring.submit());

            // expect completion of cancel operation and completion of recv operation
            var cqe_cancel = try ring.copy_cqe();
            if (cqe_cancel.err() == .INVAL) return error.SkipZigTest;
            var cqe_recv = try ring.copy_cqe();
            if (cqe_recv.err() == .INVAL) return error.SkipZigTest;

            // don't depend on order of completions
            if (cqe_cancel.user_data == recv_user_data and cqe_recv.user_data == cancel_user_data) {
                const a = cqe_cancel;
                const b = cqe_recv;
                cqe_cancel = b;
                cqe_recv = a;
            }

            // Note on different kernel results:
            // on older kernel (tested with v6.0.16, v6.1.57, v6.2.12, v6.4.16)
            //   cqe_cancel.err() == .NOENT
            //   cqe_recv.err() == .NOBUFS
            // on kernel (tested with v6.5.0, v6.5.7)
            //   cqe_cancel.err() == .SUCCESS
            //   cqe_recv.err() == .CANCELED
            // Upstream reference: https://github.com/axboe/liburing/issues/984

            // cancel operation is success (or NOENT on older kernels)
            try testing.expectEqual(cancel_user_data, cqe_cancel.user_data);
            try testing.expect(cqe_cancel.err() == .NOENT or cqe_cancel.err() == .SUCCESS);

            // recv operation is failed with err CANCELED (or NOBUFS on older kernels)
            try testing.expectEqual(recv_user_data, cqe_recv.user_data);
            try testing.expect(cqe_recv.res < 0);
            try testing.expect(cqe_recv.err() == .NOBUFS or cqe_recv.err() == .CANCELED);
            try testing.expect(!cqe_recv.flags.f_more);
        }
    }
}

// Prepare, submit recv and get cqe using buffer group.
fn buf_grp_recv_submit_get_cqe(
    ring: *IoUring,
    buf_grp: *BufferGroup,
    fd: linux.fd_t,
    user_data: u64,
) !Cqe {
    // prepare and submit recv
    const sqe = try buf_grp.recv(user_data, fd, .{});
    try testing.expect(sqe.flags.buffer_select);
    try testing.expect(sqe.buf_index == buf_grp.group_id);
    try testing.expectEqual(1, try ring.submit()); // submit
    // get cqe, expect success
    const cqe = try ring.copy_cqe();
    try testing.expectEqual(user_data, cqe.user_data);
    try testing.expect(cqe.res >= 0); // success
    try testing.expectEqual(posix.E.SUCCESS, cqe.err());
    try testing.expect(cqe.flags.f_buffer); // IORING_CQE_F_BUFFER flag is set

    return cqe;
}

fn expect_buf_grp_cqe(
    ring: *IoUring,
    buf_grp: *BufferGroup,
    user_data: u64,
    expected: []const u8,
) !Cqe {
    // get cqe
    const cqe = try ring.copy_cqe();
    try testing.expectEqual(user_data, cqe.user_data);
    try testing.expect(cqe.res >= 0); // success
    try testing.expect(cqe.flags.f_buffer); // IORING_CQE_F_BUFFER flag is set
    try testing.expectEqual(@as(i32, @intCast(expected.len)), cqe.res);
    try testing.expectEqual(posix.E.SUCCESS, cqe.err());

    // get buffer from pool
    const buffer_id = try cqe.buffer_id();
    const len: usize = @intCast(cqe.res);
    const buf = buf_grp.get_by_id(buffer_id)[0..len];
    try testing.expectEqualSlices(u8, expected, buf);

    return cqe;
}

test "copy_cqes with wrapping sq.cqes buffer" {
    if (!is_linux) return error.SkipZigTest;

    var ring = IoUring.init(2, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    try testing.expectEqual(2, ring.sq.sqes.len);
    try testing.expectEqual(4, ring.cq.cqes.len);

    // submit 2 entries, receive 2 completions
    var cqes: [8]Cqe = undefined;
    {
        for (0..2) |_| {
            const sqe = try ring.get_sqe();
            sqe.prep_timeout(&.{ .sec = 0, .nsec = 10000 }, 0, .{});
            try testing.expect(try ring.submit() == 1);
        }
        var cqe_count: u32 = 0;
        while (cqe_count < 2) {
            cqe_count += try ring.copy_cqes(&cqes, 2 - cqe_count);
        }
    }

    try testing.expectEqual(2, ring.cq.head.*);

    // sq.sqes len is 4, starting at position 2
    // every 4 entries submit wraps completion buffer
    // we are reading ring.cq.cqes at indexes 2,3,0,1
    for (1..1024) |i| {
        for (0..4) |_| {
            const sqe = try ring.get_sqe();
            sqe.prep_timeout(&.{ .sec = 0, .nsec = 10000 }, 0, .{});
            try testing.expect(try ring.submit() == 1);
        }
        var cqe_count: u32 = 0;
        while (cqe_count < 4) {
            cqe_count += try ring.copy_cqes(&cqes, 4 - cqe_count);
        }
        try testing.expectEqual(4, cqe_count);
        try testing.expectEqual(2 + 4 * i, ring.cq.head.*);
    }
}

test "bind/listen/connect" {
    if (builtin.cpu.arch == .s390x) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/25956

    var ring = IoUring.init(4, .{}) catch |err| switch (err) {
        error.SystemOutdated => return error.SkipZigTest,
        error.PermissionDenied => return error.SkipZigTest,
        else => return err,
    };
    defer ring.deinit();

    const probe = ring.get_probe() catch return error.SkipZigTest;
    // LISTEN is higher required operation
    if (!probe.is_supported(.listen)) return error.SkipZigTest;

    var addr: linux.sockaddr.in = .{
        .port = 0,
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };
    // TODO: switch family to IpProto type
    // const proto: linux.IpProto = switch (addr.any.family) {
    //     .unix => .default,
    //     else => .tcp,
    // };
    const proto: u32 = if (addr.family == linux.AF.UNIX) 0 else linux.IPPROTO.TCP;

    const listen_fd = brk: {
        // Create socket
        _ = try ring.socket(1, @enumFromInt(addr.any.family), .{ .type = .stream, .flags = .{ .cloexec = true } }, @enumFromInt(proto), 0);
        try testing.expectEqual(1, try ring.submit());
        var cqe = try ring.copy_cqe();
        try testing.expectEqual(1, cqe.user_data);
        try testing.expectEqual(posix.E.SUCCESS, cqe.err());
        const listen_fd: linux.fd_t = @intCast(cqe.res);
        try testing.expect(listen_fd > 2);

        // Prepare: set socket option * 2, bind, listen
        var optval: u32 = 1;
        (try ring.setsockopt(2, listen_fd, .socket, .reuseaddr, mem.asBytes(&optval))).link_next();
        (try ring.setsockopt(3, listen_fd, .socket, .reuseport, mem.asBytes(&optval))).link_next();
        (try ring.bind(4, listen_fd, addrAny(&addr), @sizeOf(linux.sockaddr.in), 0)).link_next();
        _ = try ring.listen(5, listen_fd, 1, 0);
        // Submit 4 operations
        try testing.expectEqual(4, try ring.submit());
        // Expect all to succeed
        for (2..6) |user_data| {
            cqe = try ring.copy_cqe();
            try testing.expectEqual(user_data, cqe.user_data);
            try testing.expectEqual(posix.E.SUCCESS, cqe.err());
        }

        // Check that socket option is set
        optval = 0;
        _ = try ring.getsockopt(5, listen_fd, .socket, .reuseaddr, mem.asBytes(&optval));
        try testing.expectEqual(1, try ring.submit());
        cqe = try ring.copy_cqe();
        try testing.expectEqual(5, cqe.user_data);
        try testing.expectEqual(posix.E.SUCCESS, cqe.err());
        try testing.expectEqual(1, optval);

        // Read system assigned port into addr
        var addr_len: posix.socklen_t = @sizeOf(linux.sockaddr.in);
        try posix.getsockname(listen_fd, addrAny(&addr), &addr_len);

        break :brk listen_fd;
    };

    const connect_fd = brk: {
        // Create connect socket
        _ = try ring.socket(6, @enumFromInt(addr.family), .{ .type = .stream, .flags = .{ .cloexec = true } }, @enumFromInt(proto), 0);
        try testing.expectEqual(1, try ring.submit());
        const cqe = try ring.copy_cqe();
        try testing.expectEqual(6, cqe.user_data);
        try testing.expectEqual(posix.E.SUCCESS, cqe.err());
        // Get connect socket fd
        const connect_fd: linux.fd_t = @intCast(cqe.res);
        try testing.expect(connect_fd > 2 and connect_fd != listen_fd);
        break :brk connect_fd;
    };

    // Prepare accept/connect operations
    _ = try ring.accept(7, listen_fd, null, null, .{});
    _ = try ring.connect(8, connect_fd, addrAny(&addr), @sizeOf(linux.sockaddr.in));
    try testing.expectEqual(2, try ring.submit());
    // Get listener accepted socket
    var accept_fd: posix.socket_t = 0;
    for (0..2) |_| {
        const cqe = try ring.copy_cqe();
        try testing.expectEqual(posix.E.SUCCESS, cqe.err());
        if (cqe.user_data == 7) {
            accept_fd = @intCast(cqe.res);
        } else {
            try testing.expectEqual(8, cqe.user_data);
        }
    }
    try testing.expect(accept_fd > 2 and accept_fd != listen_fd and accept_fd != connect_fd);

    // Communicate
    try testSendRecv(&ring, connect_fd, accept_fd);
    try testSendRecv(&ring, accept_fd, connect_fd);

    // Shutdown and close all sockets
    for ([_]posix.socket_t{ connect_fd, accept_fd, listen_fd }) |fd| {
        (try ring.shutdown(9, fd, .rdwr)).link_next();
        _ = try ring.close(10, fd);
        try testing.expectEqual(2, try ring.submit());
        for (0..2) |i| {
            const cqe = try ring.copy_cqe();
            try testing.expectEqual(posix.E.SUCCESS, cqe.err());
            try testing.expectEqual(9 + i, cqe.user_data);
        }
    }
}

fn testSendRecv(ring: *IoUring, send_fd: posix.socket_t, recv_fd: posix.socket_t) !void {
    const buffer_send = "0123456789abcdf" ** 10;
    var buffer_recv: [buffer_send.len * 2]u8 = undefined;

    // 2 sends
    _ = try ring.send(1, send_fd, buffer_send, .{ .waitall = true });
    _ = try ring.send(2, send_fd, buffer_send, .{ .waitall = true });
    try testing.expectEqual(2, try ring.submit());
    for (0..2) |i| {
        const cqe = try ring.copy_cqe();
        try testing.expectEqual(1 + i, cqe.user_data);
        try testing.expectEqual(posix.E.SUCCESS, cqe.err());
        try testing.expectEqual(@as(i32, buffer_send.len), cqe.res);
    }

    // receive
    var recv_len: usize = 0;
    while (recv_len < buffer_send.len * 2) {
        _ = try ring.recv(3, recv_fd, .{ .buffer = buffer_recv[recv_len..] }, .{});
        try testing.expectEqual(1, try ring.submit());
        const cqe = try ring.copy_cqe();
        try testing.expectEqual(3, cqe.user_data);
        try testing.expectEqual(posix.E.SUCCESS, cqe.err());
        recv_len += @intCast(cqe.res);
    }

    // inspect recv buffer
    try testing.expectEqualSlices(u8, buffer_send, buffer_recv[0..buffer_send.len]);
    try testing.expectEqualSlices(u8, buffer_send, buffer_recv[buffer_send.len..]);
}

fn addrAny(addr: *linux.sockaddr.in) *linux.sockaddr {
    return @ptrCast(addr);
}
