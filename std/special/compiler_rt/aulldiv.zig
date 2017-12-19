pub nakedcc fn _aulldiv() {
    @setDebugSafety(this, false);
    asm volatile (
        \\.intel_syntax noprefix
        \\
        \\         push        ebx
        \\         push        esi
        \\         mov         eax,dword ptr [esp+18h]
        \\         or          eax,eax
        \\         jne         L1
        \\         mov         ecx,dword ptr [esp+14h]
        \\         mov         eax,dword ptr [esp+10h]
        \\         xor         edx,edx
        \\         div         ecx
        \\         mov         ebx,eax
        \\         mov         eax,dword ptr [esp+0Ch]
        \\         div         ecx
        \\         mov         edx,ebx
        \\         jmp         L2
        \\ L1:
        \\         mov         ecx,eax
        \\         mov         ebx,dword ptr [esp+14h]
        \\         mov         edx,dword ptr [esp+10h]
        \\         mov         eax,dword ptr [esp+0Ch]
        \\ L3:
        \\         shr         ecx,1
        \\         rcr         ebx,1
        \\         shr         edx,1
        \\         rcr         eax,1
        \\         or          ecx,ecx
        \\         jne         L3
        \\         div         ebx
        \\         mov         esi,eax
        \\         mul         dword ptr [esp+18h]
        \\         mov         ecx,eax
        \\         mov         eax,dword ptr [esp+14h]
        \\         mul         esi
        \\         add         edx,ecx
        \\         jb          L4
        \\         cmp         edx,dword ptr [esp+10h]
        \\         ja          L4
        \\         jb          L5
        \\         cmp         eax,dword ptr [esp+0Ch]
        \\         jbe         L5
        \\ L4:
        \\         dec         esi
        \\ L5:
        \\         xor         edx,edx
        \\         mov         eax,esi
        \\ L2:
        \\         pop         esi
        \\         pop         ebx
        \\         ret         10h
    );
}
