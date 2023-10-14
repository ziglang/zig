/* Some compiler optimizations may transform loops into memset/memmove
   calls and without proper declaration it may generate PLT calls.  */
#if !defined __ASSEMBLER__ && IS_IN (libc) && defined SHARED \
    && !defined LIBC_NONSHARED
asm ("memmove = __GI_memmove");
asm ("memset = __GI_memset");
asm ("memcpy = __GI_memcpy");

/* Some targets do not use __stack_chk_fail_local.  In libc.so,
   redirect __stack_chk_fail to a hidden reference
   __stack_chk_fail_local, to avoid the PLT reference.
   __stack_chk_fail itself is a global symbol, exported from libc.so,
   and cannot be made hidden.  */

# if IS_IN (libc) && defined SHARED \
  && defined STACK_PROTECTOR_LEVEL && STACK_PROTECTOR_LEVEL > 0
asm (".hidden __stack_chk_fail_local\n"
     "__stack_chk_fail = __stack_chk_fail_local");
# endif
#endif
