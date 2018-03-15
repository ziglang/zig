///////////////////////////
////  IPC structures   ////
///////////////////////////

pub const Message = struct {
    sender:   MailboxId,
    receiver: MailboxId,
    payload:  usize,

    pub fn withReceiver(mailbox_id: &const MailboxId) Message {
        return Message {
            .sender   = undefined,
            .receiver = *mailbox_id,
            .payload  = undefined,
        };
    }
};

pub const MailboxId = union(enum) {
    This,
    Kernel,
    Port:   u16,
    //Thread: u16,
};


///////////////////////////////////////
////  Ports reserved for services  ////
///////////////////////////////////////

pub const Service = struct {
    pub const Terminal = MailboxId { .Port = 0 };
    pub const Keyboard = MailboxId { .Port = 1 };
};


///////////////////////////
////  Syscall numbers  ////
///////////////////////////

pub const Syscall = enum {
    exit         = 0,
    createPort   = 1,
    send         = 2,
    receive      = 3,
    map          = 4,
    createThread = 5,
};


////////////////////
////  Syscalls  ////
////////////////////

pub fn exit(status: i32) noreturn {
    _ = syscall1(Syscall.exit, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn createPort(id: u16) void {
    _ = syscall1(Syscall.createPort, id);
}

pub fn send(message: &const Message) void {
    _ = syscall1(Syscall.send, @ptrToInt(message));
}

pub fn receive(destination: &Message) void {
    _ = syscall1(Syscall.receive, @ptrToInt(destination));
}

pub fn map(v_addr: usize, p_addr: usize, size: usize, writable: bool) bool {
    return syscall4(Syscall.map, v_addr, p_addr, size, usize(writable)) != 0;
}

pub fn createThread(function: fn()void) u16 {
    return u16(syscall1(Syscall.createThread, @ptrToInt(function)));
}


/////////////////////////
////  Syscall stubs  ////
/////////////////////////

inline fn syscall0(number: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number));
}

inline fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1));
}

inline fn syscall2(number: usize, arg1: usize, arg2: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2));
}

inline fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2),
            [arg3] "{ebx}" (arg3));
}

inline fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2),
            [arg3] "{ebx}" (arg3),
            [arg4] "{esi}" (arg4));
}

inline fn syscall5(number: usize, arg1: usize, arg2: usize, arg3: usize,
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

inline fn syscall6(number: usize, arg1: usize, arg2: usize, arg3: usize,
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
