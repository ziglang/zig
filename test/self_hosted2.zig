const case_namespace_fn_call = @import("cases/namespace_fn_call.zig");

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

fn testInlineSwitch() {
    const x = 3 + 4;
    const result = inline switch (x) {
        3 => 10,
        4 => 11,
        5, 6 => 12,
        7, 8 => 13,
        else => 14,
    };
    assert(result + 1 == 14);
}

fn testNamespaceFnCall() {
    assert(case_namespace_fn_call.foo() == 1234);
}

fn gotoAndLabels() {
    gotoLoop();
    assert(goto_counter == 10);
}
fn gotoLoop() {
    var i: i32 = 0;
    goto cond;
loop:
    i += 1;
cond:
    if (!(i < 10)) goto end;
    goto_counter += 1;
    goto loop;
end:
}
var goto_counter: i32 = 0;



struct FooA {
    fn add(a: i32, b: i32) -> i32 { a + b }
}
const foo_a = FooA {};

fn testStructStatic() {
    const result = FooA.add(3, 4);
    assert(result == 7);
}

const should_be_11 = FooA.add(5, 6);
fn testStaticFnEval() {
    assert(should_be_11 == 11);
}

fn fib(x: i32) -> i32 {
    if (x < 2) x else fib(x - 1) + fib(x - 2)
}

const fib_7 = fib(7);

fn testCompileTimeFib() {
    assert(fib_7 == 13);
}

fn max(inline T: type, a: T, b: T) -> T {
   if (a > b) a else b
}
const the_max = max(u32, 1234, 5678);

fn testCompileTimeGenericEval() {
    assert(the_max == 5678);
}

fn gimmeTheBigOne(a: u32, b: u32) -> u32 {
    max(u32, a, b)
}

fn shouldCallSameInstance(a: u32, b: u32) -> u32 {
    max(u32, a, b)
}

fn sameButWithFloats(a: f64, b: f64) -> f64 {
    max(f64, a, b)
}

fn testFnWithInlineArgs() {
    assert(gimmeTheBigOne(1234, 5678) == 5678);
    assert(shouldCallSameInstance(34, 12) == 34);
    assert(sameButWithFloats(0.43, 0.49) == 0.49);
}


fn testContinueInForLoop() {
    const array = []i32 {1, 2, 3, 4, 5};
    var sum : i32 = 0;
    for (array) |x| {
        sum += x;
        if (x < 3) {
            continue;
        }
        break;
    }
    assert(sum == 6);
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
    testInlineSwitch();
    testNamespaceFnCall();
    gotoAndLabels();
    testStructStatic();
    testStaticFnEval();
    testCompileTimeFib();
    testCompileTimeGenericEval();
    testFnWithInlineArgs();
    testContinueInForLoop();
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

