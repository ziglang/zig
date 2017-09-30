const builtin = @import("builtin");

export nakedcc fn _aullrem() {
    @setDebugSafety(this, false);

    if (comptime builtin.os == builtin.Os.windows) {
        if (comptime builtin.arch == builtin.Arch.i386) {
            asm volatile (
                \\.intel_syntax noprefix
                \\
                \\         push        ebx
                \\         mov         eax,dword ptr [esp+14h]
                \\         or          eax,eax
                \\         jne         L1a
                \\         mov         ecx,dword ptr [esp+10h]
                \\         mov         eax,dword ptr [esp+0Ch]
                \\         xor         edx,edx
                \\         div         ecx
                \\         mov         eax,dword ptr [esp+8]
                \\         div         ecx
                \\         mov         eax,edx
                \\         xor         edx,edx
                \\         jmp         L2a
                \\ L1a:
                \\         mov         ecx,eax
                \\         mov         ebx,dword ptr [esp+10h]
                \\         mov         edx,dword ptr [esp+0Ch]
                \\         mov         eax,dword ptr [esp+8]
                \\ L3a:
                \\         shr         ecx,1
                \\         rcr         ebx,1
                \\         shr         edx,1
                \\         rcr         eax,1
                \\         or          ecx,ecx
                \\         jne         L3a
                \\         div         ebx
                \\         mov         ecx,eax
                \\         mul         dword ptr [esp+14h]
                \\         xchg        eax,ecx
                \\         mul         dword ptr [esp+10h]
                \\         add         edx,ecx
                \\         jb          L4a
                \\         cmp         edx,dword ptr [esp+0Ch]
                \\         ja          L4a
                \\         jb          L5a
                \\         cmp         eax,dword ptr [esp+8]
                \\         jbe         L5a
                \\ L4a:
                \\         sub         eax,dword ptr [esp+10h]
                \\         sbb         edx,dword ptr [esp+14h]
                \\ L5a:
                \\         sub         eax,dword ptr [esp+8]
                \\         sbb         edx,dword ptr [esp+0Ch]
                \\         neg         edx
                \\         neg         eax
                \\         sbb         edx,0
                \\ L2a:
                \\         pop         ebx
                \\         ret         10h
            );
            unreachable;
        }
    }

    @setGlobalLinkage(_aullrem, builtin.GlobalLinkage.Internal);
}
