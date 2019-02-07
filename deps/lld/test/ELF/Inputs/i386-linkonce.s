.section .gnu.linkonce.t.__i686.get_pc_thunk.bx
.global __i686.get_pc_thunk.bx
__i686.get_pc_thunk.bx:
    mov    (%esp),%ebx
    ret

.section .text
.global _strchr1
_strchr1:
    call __i686.get_pc_thunk.bx
    ret
