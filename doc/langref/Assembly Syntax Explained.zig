pub fn syscall1(number: usize, arg1: usize) usize {
    // Inline assembly is an expression which returns a value.
    // the `asm` keyword begins the expression.
    return asm
    // `volatile` is an optional modifier that tells Zig this
    // inline assembly expression has side-effects. Without
    // `volatile`, Zig is allowed to delete the inline assembly
    // code if the result is unused.
    volatile (
    // Next is a comptime string which is the assembly code.
    // Inside this string one may use `%[ret]`, `%[number]`,
    // or `%[arg1]` where a register is expected, to specify
    // the register that Zig uses for the argument or return value,
    // if the register constraint strings are used. However in
    // the below code, this is not used. A literal `%` can be
    // obtained by escaping it with a double percent: `%%`.
    // Often multiline string syntax comes in handy here.
        \\syscall
        // Next is the output. It is possible in the future Zig will
        // support multiple outputs, depending on how
        // https://github.com/ziglang/zig/issues/215 is resolved.
        // It is allowed for there to be no outputs, in which case
        // this colon would be directly followed by the colon for the inputs.
        :
        // This specifies the name to be used in `%[ret]` syntax in
        // the above assembly string. This example does not use it,
        // but the syntax is mandatory.
          [ret]
          // Next is the output constraint string. This feature is still
          // considered unstable in Zig, and so LLVM/GCC documentation
          // must be used to understand the semantics.
          // http://releases.llvm.org/10.0.0/docs/LangRef.html#inline-asm-constraint-string
          // https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html
          // In this example, the constraint string means "the result value of
          // this inline assembly instruction is whatever is in $rax".
          "={rax}"
          // Next is either a value binding, or `->` and then a type. The
          // type is the result type of the inline assembly expression.
          // If it is a value binding, then `%[ret]` syntax would be used
          // to refer to the register bound to the value.
          (-> usize),
          // Next is the list of inputs.
          // The constraint for these inputs means, "when the assembly code is
          // executed, $rax shall have the value of `number` and $rdi shall have
          // the value of `arg1`". Any number of input parameters is allowed,
          // including none.
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
          // Next is the list of clobbers. These declare a set of registers whose
          // values will not be preserved by the execution of this assembly code.
          // These do not include output or input registers. The special clobber
          // value of "memory" means that the assembly writes to arbitrary undeclared
          // memory locations - not only the memory pointed to by a declared indirect
          // output. In this example we list $rcx and $r11 because it is known the
          // kernel syscall does not preserve these registers.
        : "rcx", "r11"
    );
}

// syntax
