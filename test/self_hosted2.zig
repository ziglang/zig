pub const SYS_write = 1;
pub const SYS_exit = 60;
pub const stdout_fileno = 1;

// normal comment
/// this is a documentation comment
/// doc comment line 2
fn emptyFunctionWithComments() {
}

export fn disabledExternFn() {
    @setFnVisible(this, false);
}

fn inlinedLoop() {
    inline var i = 0;
    inline var sum = 0;
    inline while (i <= 5; i += 1)
        sum += i;
    assert(sum == 15);
}

fn switchWithNumbers() {
    testSwitchWithNumbers(13);
}

fn testSwitchWithNumbers(x: u32) {
    const result = switch (x) {
        1, 2, 3, 4 ... 8 => false,
        13 => true,
        else => false,
    };
    assert(result);
}

fn switchWithAllRanges() {
    assert(testSwitchWithAllRanges(50, 3) == 1);
    assert(testSwitchWithAllRanges(101, 0) == 2);
    assert(testSwitchWithAllRanges(300, 5) == 3);
    assert(testSwitchWithAllRanges(301, 6) == 6);
}

fn testSwitchWithAllRanges(x: u32, y: u32) -> u32 {
    switch (x) {
        0 ... 100 => 1,
        101 ... 200 => 2,
        201 ... 300 => 3,
        else => y,
    }
}

fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

fn runAllTests() {
    emptyFunctionWithComments();
    disabledExternFn();
    inlinedLoop();
    switchWithNumbers();
    switchWithAllRanges();
}

export nakedcc fn _start() -> unreachable {
    myMain();
}

fn myMain() -> unreachable {
    runAllTests();
    const text = "OK\n";
    write(stdout_fileno, &text[0], text.len);
    exit(0);
}

pub inline fn syscall1(number: usize, arg1: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

pub inline fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
            [arg1] "{rdi}" (arg1),
            [arg2] "{rsi}" (arg2),
            [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

pub fn write(fd: i32, buf: &const u8, count: usize) -> usize {
    syscall3(SYS_write, usize(fd), usize(buf), count)
}

pub fn exit(status: i32) -> unreachable {
    syscall1(SYS_exit, usize(status));
    @unreachable()
}

