;; ml64 hello64.asm /link /subsystem:windows /defaultlib:kernel32 \
;;    /defaultlib:user32 /out:hello64.exe /entry:main

extern ExitProcess : PROC
extern MessageBoxA : PROC
extern ImportByOrdinal: PROC

.data
        caption db 'Hello', 0
        message db 'Hello World!', 0

.code
main PROC
        sub rsp,28h
        mov rcx, 0
        lea rdx, message
        lea r8, caption
        mov r9d, 0
        call MessageBoxA
        mov ecx, 0
        call ExitProcess
        call ImportByOrdinal
main ENDP
END
