typedef _Atomic(int) AtomicInt;

// translate-c
// target=x86_64-linux
// c_frontend=aro
//
// tmp.c:1:22: warning: unsupported type: '_Atomic(int)'
// pub const AtomicInt = @compileError("unable to resolve typedef child type");
