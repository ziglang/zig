const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

// These tests should work with all platforms, but we're using linux_x64 for
// now for consistency. Will be expanded eventually.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    ctx.c("empty start function", linux_x64,
        \\export fn _start() noreturn {}
    ,
        \\noreturn void _start(void) {}
        \\
    );
    ctx.c("less empty start function", linux_x64,
        \\fn main() noreturn {}
        \\
        \\export fn _start() noreturn {
        \\	main();
        \\}
    ,
        \\noreturn void main(void);
        \\
        \\noreturn void _start(void) {
        \\	main();
        \\}
        \\
        \\noreturn void main(void) {}
        \\
    );
    // TODO: implement return values
    // TODO: figure out a way to prevent asm constants from being generated
    ctx.c("inline asm", linux_x64,
        \\fn exitGood() void {
        \\	asm volatile ("syscall"
        \\ 		:
        \\		: [number] "{rax}" (231),
        \\		  [arg1] "{rdi}" (0)
        \\	);
        \\}
        \\
        \\export fn _start() noreturn {
        \\	exitGood();
        \\}
    ,
        \\#include <stddef.h>
        \\
        \\void exitGood(void);
        \\
        \\const char *const exitGood__anon_0 = "{rax}";
        \\const char *const exitGood__anon_1 = "{rdi}";
        \\const char *const exitGood__anon_2 = "syscall";
        \\
        \\noreturn void _start(void) {
        \\	exitGood();
        \\}
        \\
        \\void exitGood(void) {
        \\	register size_t rax_constant __asm__("rax") = 231;
        \\	register size_t rdi_constant __asm__("rdi") = 0;
        \\	__asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
        \\	return;
        \\}
        \\
    );
    ctx.c("basic return", linux_x64,
        \\fn main() u8 {
        \\	return 103;
        \\}
        \\
        \\export fn _start() noreturn {
        \\	_ = main();
        \\}
    ,
        \\#include <stdint.h>
        \\
        \\uint8_t main(void);
        \\
        \\noreturn void _start(void) {
        \\	(void)main();
        \\}
        \\
        \\uint8_t main(void) {
        \\	return 103;
        \\}
        \\
    );
}
