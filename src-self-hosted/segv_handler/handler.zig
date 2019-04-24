const std = @import("std");
const c = @import("c.zig");

pub fn attach() void {
    var act: c.sigaction_t = c.sigaction_t {
        .sa_handler = undefined,
        .sa_mask = undefined,
        .sa_flags = (c.SA_SIGINFO | c.SA_RESTART | c.SA_NODEFER),
        .sa_restorer = null,
    };
    
    act.sa_handler.sa_sigaction = handler;
    _ = c.sigemptyset(&act.sa_mask);
    
    _ = c.sigaction(c.SIGSEGV, &act, null);
}

var segfaulted: u8 = 0;

extern fn handler(sig: c_int, info: ?*const c.siginfo_t, ctx_ptr: ?*const c_void) noreturn {
    const ctx = @ptrCast(?*const c.ucontext_t, @alignCast(@alignOf(*c.ucontext_t), ctx_ptr));
    
    const ip = @intCast(usize, ctx.?.uc_mcontext.gregs[c.REG_IP]);
    const bp = @intCast(usize, ctx.?.uc_mcontext.gregs[c.REG_BP]);
    const sp = @intCast(usize, ctx.?.uc_mcontext.gregs[c.REG_SP]);
    const addr = @ptrToInt(info.?._si_fields._sigfault.si_addr);
    
    std.debug.warn(
        \\Received SIGSEGV at instruction 0x{x} (addr=0x{x})
        \\Frame address: 0x{x}
        \\Stack address: 0x{x}
        \\
    , ip, addr, bp, sp);
    
    if (@atomicRmw(u8, &segfaulted, .Xchg, 1, .SeqCst) == 1) {
        // Segfaulted while handling sigsegv.
        std.os.abort();
    }
    
    // Using some tricks we can link stacks
    // and safely unwind from here
    
    // a call to panic needs a big stack
    var buf: [2560]usize = undefined;
    const newStack = @sliceToBytes(buf[0..]);
    @newStackCall(newStack, entryPanic, bp, ip);
}

inline fn entryPanic(bp: usize, ip: usize) noreturn {
    @noInlineCall(segvPanic, bp, ip);
}

fn segvPanic(bp: usize, ip: usize) noreturn {
    // Does this ensure that %rbp is pushed onto the stack
    // and %rsp is moved to %rbp?
    const frame_addr = @frameAddress();
    
    // replace frame pointer
    @intToPtr(*usize, frame_addr).* = bp;

    // replace instruction pointer
    @intToPtr(*usize, frame_addr + @sizeOf(usize)).* = ip;
    
    @panic(""); // Segmentation fault
}
