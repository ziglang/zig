.text
.global _longjmp
.global longjmp
.type _longjmp,%function
.type longjmp,%function
_longjmp:
longjmp:
    { r17:16=memd(r0+#0)
      r19:18=memd(r0+#8) }
    { r21:20=memd(r0+#16)
      r23:22=memd(r0+#24) }
    { r25:24=memd(r0+#32)
      r27:26=memd(r0+#40) }
    { r29:28=memd(r0+#48)
      r31:30=memd(r0+#56) }

    r0 = r1
    r1 = #0
    p0 = cmp.eq(r0,r1)
    if (!p0) jumpr r31
    r0 = #1

    jumpr r31
.size _longjmp, .-_longjmp
.size longjmp, .-longjmp
