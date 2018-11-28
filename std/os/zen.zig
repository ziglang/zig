const std = @import("../index.zig");
const assert = std.debug.assert;

//////////////////////////
////  IPC structures  ////
//////////////////////////

pub const Message = struct {
    sender: MailboxId,
    receiver: MailboxId,
    code: usize,
    args: [5]usize,
    payload: ?[]const u8,

    pub fn from(mailbox_id: MailboxId) Message {
        return Message{
            .sender = MailboxId.Undefined,
            .receiver = mailbox_id,
            .code = undefined,
            .args = undefined,
            .payload = null,
        };
    }

    pub fn to(mailbox_id: MailboxId, msg_code: usize, args: ...) Message {
        var message = Message{
            .sender = MailboxId.This,
            .receiver = mailbox_id,
            .code = msg_code,
            .args = undefined,
            .payload = null,
        };

        assert(args.len <= message.args.len);
        comptime var i = 0;
        inline while (i < args.len) : (i += 1) {
            message.args[i] = args[i];
        }

        return message;
    }

    pub fn as(self: Message, sender: MailboxId) Message {
        var message = self;
        message.sender = sender;
        return message;
    }

    pub fn withPayload(self: Message, payload: []const u8) Message {
        var message = self;
        message.payload = payload;
        return message;
    }
};

pub const MailboxId = union(enum) {
    Undefined,
    This,
    Kernel,
    Port: u16,
    Thread: u16,
};

//////////////////////////////////////
////  Ports reserved for servers  ////
//////////////////////////////////////

pub const Server = struct {
    pub const Keyboard = MailboxId{ .Port = 0 };
    pub const Terminal = MailboxId{ .Port = 1 };
};

////////////////////////
////  POSIX things  ////
////////////////////////

// Standard streams.
pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

// FIXME: let's borrow Linux's error numbers for now.
use @import("linux/errno.zig");
// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

// TODO: implement this correctly.
pub fn read(fd: i32, buf: [*]u8, count: usize) usize {
    switch (fd) {
        STDIN_FILENO => {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                send(&Message.to(Server.Keyboard, 0));

                // FIXME: we should be certain that we are receiving from Keyboard.
                var message = Message.from(MailboxId.This);
                receive(&message);

                buf[i] = @intCast(u8, message.args[0]);
            }
        },
        else => unreachable,
    }
    return count;
}

// TODO: implement this correctly.
pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    switch (fd) {
        STDOUT_FILENO, STDERR_FILENO => {
            send(&Message.to(Server.Terminal, 1).withPayload(buf[0..count]));
        },
        else => unreachable,
    }
    return count;
}

///////////////////////////
////  Syscall numbers  ////
///////////////////////////

pub const Syscall = enum(usize) {
    exit = 0,
    send = 1,
    receive = 2,
    subscribeIRQ = 3,
    inb = 4,
    outb = 5,
    map = 6,
    createThread = 7,
};

////////////////////
////  Syscalls  ////
////////////////////

pub fn exit(status: i32) noreturn {
    _ = syscall1(Syscall.exit, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn send(message: *const Message) void {
    _ = syscall1(Syscall.send, @ptrToInt(message));
}

pub fn receive(destination: *Message) void {
    _ = syscall1(Syscall.receive, @ptrToInt(destination));
}

pub fn subscribeIRQ(irq: u8, mailbox_id: *const MailboxId) void {
    _ = syscall2(Syscall.subscribeIRQ, irq, @ptrToInt(mailbox_id));
}

pub fn inb(port: u16) u8 {
    return @intCast(u8, syscall1(Syscall.inb, port));
}

pub fn outb(port: u16, value: u8) void {
    _ = syscall2(Syscall.outb, port, value);
}

pub fn map(v_addr: usize, p_addr: usize, size: usize, writable: bool) bool {
    return syscall4(Syscall.map, v_addr, p_addr, size, @boolToInt(writable)) != 0;
}

pub fn createThread(function: fn () void) u16 {
    return u16(syscall1(Syscall.createThread, @ptrToInt(function)));
}

/////////////////////////
////  Syscall stubs  ////
/////////////////////////

inline fn syscall0(number: Syscall) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number)
    );
}

inline fn syscall1(number: Syscall, arg1: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
          [arg1] "{ecx}" (arg1)
    );
}

inline fn syscall2(number: Syscall, arg1: usize, arg2: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
          [arg1] "{ecx}" (arg1),
          [arg2] "{edx}" (arg2)
    );
}

inline fn syscall3(number: Syscall, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
          [arg1] "{ecx}" (arg1),
          [arg2] "{edx}" (arg2),
          [arg3] "{ebx}" (arg3)
    );
}

inline fn syscall4(number: Syscall, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
          [arg1] "{ecx}" (arg1),
          [arg2] "{edx}" (arg2),
          [arg3] "{ebx}" (arg3),
          [arg4] "{esi}" (arg4)
    );
}

inline fn syscall5(
    number: Syscall,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
          [arg1] "{ecx}" (arg1),
          [arg2] "{edx}" (arg2),
          [arg3] "{ebx}" (arg3),
          [arg4] "{esi}" (arg4),
          [arg5] "{edi}" (arg5)
    );
}

inline fn syscall6(
    number: Syscall,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    arg6: usize,
) usize {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> usize)
        : [number] "{eax}" (number),
          [arg1] "{ecx}" (arg1),
          [arg2] "{edx}" (arg2),
          [arg3] "{ebx}" (arg3),
          [arg4] "{esi}" (arg4),
          [arg5] "{edi}" (arg5),
          [arg6] "{ebp}" (arg6)
    );
}
