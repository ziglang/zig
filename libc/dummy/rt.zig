const builtin = @import("builtin");
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    unreachable;
}

// This file exists to create a librt.so file so that LLD has something to look at
// and emit linker errors if an attempt to link against a non-existent C symbol happens.

export fn __mq_open_2() void {}
export fn aio_cancel() void {}
export fn aio_cancel64() void {}
export fn aio_error() void {}
export fn aio_error64() void {}
export fn aio_fsync() void {}
export fn aio_fsync64() void {}
export fn aio_init() void {}
export fn aio_read() void {}
export fn aio_read64() void {}
export fn aio_return() void {}
export fn aio_return64() void {}
export fn aio_suspend() void {}
export fn aio_suspend64() void {}
export fn aio_write() void {}
export fn aio_write64() void {}
export fn clock_getcpuclockid() void {}
export fn clock_getres() void {}
export fn clock_gettime() void {}
export fn clock_nanosleep() void {}
export fn clock_settime() void {}
export fn lio_listio() void {}
export fn lio_listio64() void {}
export fn mq_close() void {}
export fn mq_getattr() void {}
export fn mq_notify() void {}
export fn mq_open() void {}
export fn mq_receive() void {}
export fn mq_send() void {}
export fn mq_setattr() void {}
export fn mq_timedreceive() void {}
export fn mq_timedsend() void {}
export fn mq_unlink() void {}
export fn shm_open() void {}
export fn shm_unlink() void {}
export fn timer_create() void {}
export fn timer_delete() void {}
export fn timer_getoverrun() void {}
export fn timer_gettime() void {}
export fn timer_settime() void {}
