.text
.global __setjmp
.global _setjmp
.global setjmp
.type __setjmp,@function
.type _setjmp,@function
.type setjmp,@function
__setjmp:
_setjmp:
setjmp:
    { memd(r0+#0)=r17:16
      memd(r0+#8)=r19:18 }
    { memd(r0+#16)=r21:20
      memd(r0+#24)=r23:22 }
    { memd(r0+#32)=r25:24
      memd(r0+#40)=r27:26 }
    { memd(r0+#48)=r29:28
      memd(r0+#56)=r31:30 }

    r0 = #0
    jumpr r31
.size __setjmp, .-__setjmp
.size _setjmp, .-_setjmp
.size setjmp, .-setjmp
