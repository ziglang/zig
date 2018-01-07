//////////////////////////////
////  Reserved mailboxes  ////
//////////////////////////////

pub const MBOX_TERMINAL = 1;


///////////////////////////
////  Syscall numbers  ////
///////////////////////////

pub const SYS_createMailbox = 0;
pub const SYS_send = 1;
pub const SYS_receive = 2;
pub const SYS_map = 3;


////////////////////
////  Syscalls  ////
////////////////////

pub fn createMailbox(id: u16) {
    _ = syscall1(SYS_createMailbox, id);
}

pub fn send(mailbox_id: u16, data: usize) {
    _ = syscall2(SYS_send, mailbox_id, data);
}

pub fn receive(mailbox_id: u16) -> usize {
    return syscall1(SYS_receive, mailbox_id);
}

pub fn map(v_addr: usize, p_addr: usize, size: usize, writable: bool) -> bool {
    return syscall4(SYS_map, v_addr, p_addr, size, usize(writable)) != 0;
}


/////////////////////////
////  Syscall stubs  ////
/////////////////////////

pub inline fn syscall0(number: usize) -> usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number));
}

pub inline fn syscall1(number: usize, arg1: usize) -> usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1));
}

pub inline fn syscall2(number: usize, arg1: usize, arg2: usize) -> usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2));
}

pub inline fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) -> usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2),
            [arg3] "{ebx}" (arg3));
}

pub inline fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) -> usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
            [arg1] "{ecx}" (arg1),
            [arg2] "{edx}" (arg2),
            [arg3] "{ebx}" (arg3),
            [arg4] "{esi}" (arg4));
}

pub inline fn syscall5(number: usize, arg1: usize, arg2: usize, arg3: usize,
    arg4: usize, arg5: usize) -> usize
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
