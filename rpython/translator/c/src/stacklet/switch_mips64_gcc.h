static void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra)
{
  void *result;
  __asm__ volatile (
     "daddiu $sp, $sp, -0x50\n"
     "sd $s0, 0x0($sp)\n" /* push the registers specified as caller-save */
     "sd $s1, 0x8($sp)\n"
     "sd $s2, 0x10($sp)\n"
     "sd $s3, 0x18($sp)\n"
     "sd $s4, 0x20($sp)\n"
     "sd $s5, 0x28($sp)\n"
     "sd $s6, 0x30($sp)\n"
     "sd $s7, 0x38($sp)\n"
     "sd $fp, 0x40($sp)\n"
     "sd $ra, 0x48($sp)\n"

     "move $s0, %[rstate]\n" /* save 'restore_state' for later */
     "move $s1, %[extra]\n" /* save 'extra' for later */

     "move $a1, %[extra]\n"/* arg 2: extra */
     "move $a0, $sp\n" /* arg 1: current (old) stack pointer */
                           
     "move $t9, %[sstate]\n"
     "jalr $t9\n" /* call save_state() */

     "beqz $v0, 0f\n" /* skip the rest if the return value is null */

     "move $sp, $v0\n" /* change the stack pointer */

     /* From now on, the stack pointer is modified, but the content of the
        stack is not restored yet.  It contains only garbage here. */

     "move $a1, $s1\n" /* arg 2: extra */
     "move $a0, $v0\n" /* arg 1: current (new) stack pointer */
     "move $t9, $s0\n"
     "jalr $t9\n" /* call restore_state() */

     /* The stack's content is now restored. */

     "0:\n"
     "move %[result], $v0\n"
     "ld $s0, 0x0($sp)\n"
     "ld $s1, 0x8($sp)\n"
     "ld $s2, 0x10($sp)\n"
     "ld $s3, 0x18($sp)\n"
     "ld $s4, 0x20($sp)\n"
     "ld $s5, 0x28($sp)\n"
     "ld $s6, 0x30($sp)\n"
     "ld $s7, 0x38($sp)\n"
     "ld $fp, 0x40($sp)\n"
     "ld $ra, 0x48($sp)\n"
     "daddiu $sp, $sp, 0x50\n"

     : [result]"=&r"(result)
     : [sstate]"r"(save_state),
       [rstate]"r"(restore_state),
       [extra]"r"(extra)
     : "memory", "v0", "a0", "a1", "t9"
     );
  return result;
}
