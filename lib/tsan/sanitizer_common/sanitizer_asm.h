//===-- sanitizer_asm.h -----------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Various support for assembler.
//
//===----------------------------------------------------------------------===//

// Some toolchains do not support .cfi asm directives, so we have to hide
// them inside macros.
#if defined(__clang__) ||                                                      \
    (defined(__GNUC__) && defined(__GCC_HAVE_DWARF2_CFI_ASM))
  // GCC defined __GCC_HAVE_DWARF2_CFI_ASM if it supports CFI.
  // Clang seems to support CFI by default (or not?).
  // We need two versions of macros: for inline asm and standalone asm files.
# define CFI_INL_ADJUST_CFA_OFFSET(n) ".cfi_adjust_cfa_offset " #n ";"

# define CFI_STARTPROC .cfi_startproc
# define CFI_ENDPROC .cfi_endproc
# define CFI_ADJUST_CFA_OFFSET(n) .cfi_adjust_cfa_offset n
# define CFI_DEF_CFA_OFFSET(n) .cfi_def_cfa_offset n
# define CFI_REL_OFFSET(reg, n) .cfi_rel_offset reg, n
# define CFI_OFFSET(reg, n) .cfi_offset reg, n
# define CFI_DEF_CFA_REGISTER(reg) .cfi_def_cfa_register reg
# define CFI_DEF_CFA(reg, n) .cfi_def_cfa reg, n
# define CFI_RESTORE(reg) .cfi_restore reg

#else  // No CFI
# define CFI_INL_ADJUST_CFA_OFFSET(n)
# define CFI_STARTPROC
# define CFI_ENDPROC
# define CFI_ADJUST_CFA_OFFSET(n)
# define CFI_DEF_CFA_OFFSET(n)
# define CFI_REL_OFFSET(reg, n)
# define CFI_OFFSET(reg, n)
# define CFI_DEF_CFA_REGISTER(reg)
# define CFI_DEF_CFA(reg, n)
# define CFI_RESTORE(reg)
#endif

#if defined(__x86_64__) || defined(__i386__) || defined(__sparc__)
# define ASM_TAIL_CALL jmp
#elif defined(__arm__) || defined(__aarch64__) || defined(__mips__) || \
    defined(__powerpc__) || defined(__loongarch_lp64)
# define ASM_TAIL_CALL b
#elif defined(__s390__)
# define ASM_TAIL_CALL jg
#elif defined(__riscv)
# define ASM_TAIL_CALL tail
#endif

#if defined(__ELF__) && defined(__x86_64__) || defined(__i386__) || \
    defined(__riscv)
# define ASM_PREEMPTIBLE_SYM(sym) sym@plt
#else
# define ASM_PREEMPTIBLE_SYM(sym) sym
#endif

#if !defined(__APPLE__)
# define ASM_HIDDEN(symbol) .hidden symbol
# define ASM_TYPE_FUNCTION(symbol) .type symbol, %function
# define ASM_SIZE(symbol) .size symbol, .-symbol
# define ASM_SYMBOL(symbol) symbol
# define ASM_SYMBOL_INTERCEPTOR(symbol) symbol
# if defined(__i386__) || defined(__powerpc__) || defined(__s390__) || \
     defined(__sparc__)
// For details, see interception.h
#  define ASM_WRAPPER_NAME(symbol) __interceptor_##symbol
#  define ASM_TRAMPOLINE_ALIAS(symbol, name)                                   \
         .weak symbol;                                                         \
         .set symbol, ASM_WRAPPER_NAME(name)
#  define ASM_INTERCEPTOR_TRAMPOLINE(name)
#  define ASM_INTERCEPTOR_TRAMPOLINE_SUPPORT 0
# else  // Architecture supports interceptor trampoline
// Keep trampoline implementation in sync with interception/interception.h
#  define ASM_WRAPPER_NAME(symbol) ___interceptor_##symbol
#  define ASM_TRAMPOLINE_ALIAS(symbol, name)                                   \
         .weak symbol;                                                         \
         .set symbol, __interceptor_trampoline_##name
#  define ASM_INTERCEPTOR_TRAMPOLINE(name)                                     \
         .weak __interceptor_##name;                                           \
         .set __interceptor_##name, ASM_WRAPPER_NAME(name);                    \
         .globl __interceptor_trampoline_##name;                               \
         ASM_TYPE_FUNCTION(__interceptor_trampoline_##name);                   \
         __interceptor_trampoline_##name:                                      \
                 CFI_STARTPROC;                                                \
                 ASM_TAIL_CALL ASM_PREEMPTIBLE_SYM(__interceptor_##name);      \
                 CFI_ENDPROC;                                                  \
         ASM_SIZE(__interceptor_trampoline_##name)
#  define ASM_INTERCEPTOR_TRAMPOLINE_SUPPORT 1
# endif  // Architecture supports interceptor trampoline
#else
# define ASM_HIDDEN(symbol)
# define ASM_TYPE_FUNCTION(symbol)
# define ASM_SIZE(symbol)
# define ASM_SYMBOL(symbol) _##symbol
# define ASM_SYMBOL_INTERCEPTOR(symbol) _wrap_##symbol
# define ASM_WRAPPER_NAME(symbol) __interceptor_##symbol
#endif

#if defined(__ELF__) && (defined(__GNU__) || defined(__FreeBSD__) || \
                         defined(__Fuchsia__) || defined(__linux__))
// clang-format off
#define NO_EXEC_STACK_DIRECTIVE .section .note.GNU-stack,"",%progbits
// clang-format on
#else
#define NO_EXEC_STACK_DIRECTIVE
#endif

#if (defined(__x86_64__) || defined(__i386__)) && defined(__has_include) && __has_include(<cet.h>)
#include <cet.h>
#endif
#ifndef _CET_ENDBR
#define _CET_ENDBR
#endif
