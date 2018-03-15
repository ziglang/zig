///////////////////////////
////  IPC structures   ////
///////////////////////////

pub const Message = struct {
    from:    MailboxId,
    to:      MailboxId,
    payload: usize,

    pub fn from(mailbox_id: MailboxId) Message {
        return Message {
            .from    = mailbox_id,
            .to      = undefined,
            .payload = undefined,
        };
    }
};

pub const MailboxId = union(enum) {
    Me,
    Kernel,
    Port:   u16,
    //Thread: u16,
};


//////////////////////////////
////  Reserved mailboxes  ////
//////////////////////////////

pub const MBOX_TERMINAL = MailboxId { .Port = 0 };


///////////////////////////
////  Syscall numbers  ////
///////////////////////////

pub const SYS_exit         = 0;
pub const SYS_createPort   = 1;
pub const SYS_send         = 2;
pub const SYS_receive      = 3;
pub const SYS_map          = 4;
pub const SYS_createThread = 5;


////////////////////
////  Syscalls  ////
////////////////////

pub fn exit(status: i32) noreturn {
    _ = syscall1(SYS_exit, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn createPort(id: u16) void {
    _ = syscall1(SYS_createPort, id);
}

pub fn send(message: &const Message) void {
    _ = syscall1(SYS_send, @ptrToInt(message));
}

pub fn receive(destination: &Message) void {
    _ = syscall1(SYS_receive, @ptrToInt(destination));
}

pub fn map(v_addr: usize, p_addr: usize, size: usize, writable: bool) bool {
    return syscall4(SYS_map, v_addr, p_addr, size, usize(writable)) != 0;
}

pub fn createThread(function: fn()void) u16 {
    return u16(syscall1(SYS_createThread, @ptrToInt(function)));
}


/////////////////////////
////  Syscall stubs  ////
/////////////////////////

pub inline fn syscall0(number: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number));
}

pub inline fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1));
}

pub inline fn syscall2(number: usize, arg1: usize, arg2: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2));
}

pub inline fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2),
            [arg3] "{ebx}" (arg3));
}

pub inline fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2),
            [arg3] "{ebx}" (arg3),
            [arg4] "{esi}" (arg4));
}

pub inline fn syscall5(number: usize, arg1: usize, arg2: usize, arg3: usize,
    arg4: usize, arg5: usize) usize
{
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2),
            [arg3] "{ebx}" (arg3),
            [arg4] "{esi}" (arg4),
            [arg5] "{edi}" (arg5));
}

pub inline fn syscall6(number: usize, arg1: usize, arg2: usize, arg3: usize,
    arg4: usize, arg5: usize, arg6: usize) usize
{
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2),
            [arg3] "{ebx}" (arg3),
            [arg4] "{esi}" (arg4),
            [arg5] "{edi}" (arg5),
            [arg6] "{ebp}" (arg6));
}
