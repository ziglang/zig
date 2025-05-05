#ifndef HEXAGON_ASM_USER_H
#define HEXAGON_ASM_USER_H

struct user_regs_struct {
  unsigned long r0;
  unsigned long r1;
  unsigned long r2;
  unsigned long r3;
  unsigned long r4;
  unsigned long r5;
  unsigned long r6;
  unsigned long r7;
  unsigned long r8;
  unsigned long r9;
  unsigned long r10;
  unsigned long r11;
  unsigned long r12;
  unsigned long r13;
  unsigned long r14;
  unsigned long r15;
  unsigned long r16;
  unsigned long r17;
  unsigned long r18;
  unsigned long r19;
  unsigned long r20;
  unsigned long r21;
  unsigned long r22;
  unsigned long r23;
  unsigned long r24;
  unsigned long r25;
  unsigned long r26;
  unsigned long r27;
  unsigned long r28;
  unsigned long r29;
  unsigned long r30;
  unsigned long r31;
  unsigned long sa0;
  unsigned long lc0;
  unsigned long sa1;
  unsigned long lc1;
  unsigned long m0;
  unsigned long m1;
  unsigned long usr;
  unsigned long p3_0;
  unsigned long gp;
  unsigned long ugp;
  unsigned long pc;
  unsigned long cause;
  unsigned long badva;
  unsigned long cs0;
  unsigned long cs1;
  unsigned long pad1;
};

#define ELF_NGREG 48
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];

typedef unsigned long elf_fpregset_t;

#endif
