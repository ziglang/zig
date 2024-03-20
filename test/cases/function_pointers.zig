const std = @import("std");

const PrintFn = *const fn () void;

pub fn main() void {
    var printFn: PrintFn = stopSayingThat;
    var i: u32 = 0;
    while (i < 4) : (i += 1) printFn();

    printFn = moveEveryZig;
    printFn();
}

fn stopSayingThat() void {
    _ = std.posix.write(1, "Hello, my name is Inigo Montoya; you killed my father, prepare to die.\n") catch {};
}

fn moveEveryZig() void {
    _ = std.posix.write(1, "All your codebase are belong to us\n") catch {};
}

// run
// target=x86_64-macos
//
// Hello, my name is Inigo Montoya; you killed my father, prepare to die.
// Hello, my name is Inigo Montoya; you killed my father, prepare to die.
// Hello, my name is Inigo Montoya; you killed my father, prepare to die.
// Hello, my name is Inigo Montoya; you killed my father, prepare to die.
// All your codebase are belong to us
//
