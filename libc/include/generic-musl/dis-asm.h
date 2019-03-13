/* Interface between the opcode library and its callers.

   Copyright (C) 1999-2019 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street - Fifth Floor,
   Boston, MA 02110-1301, USA.

   Written by Cygnus Support, 1993.

   The opcode library (libopcodes.a) provides instruction decoders for
   a large variety of instruction sets, callable with an identical
   interface, for making instruction-processing programs more independent
   of the instruction set being processed.  */

#ifndef DIS_ASM_H
#define DIS_ASM_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <string.h>
#include "bfd.h"

  typedef int (*fprintf_ftype) (void *, const char*, ...) ATTRIBUTE_FPTR_PRINTF_2;

enum dis_insn_type
{
  dis_noninsn,			/* Not a valid instruction.  */
  dis_nonbranch,		/* Not a branch instruction.  */
  dis_branch,			/* Unconditional branch.  */
  dis_condbranch,		/* Conditional branch.  */
  dis_jsr,			/* Jump to subroutine.  */
  dis_condjsr,			/* Conditional jump to subroutine.  */
  dis_dref,			/* Data reference instruction.  */
  dis_dref2			/* Two data references in instruction.  */
};

/* This struct is passed into the instruction decoding routine,
   and is passed back out into each callback.  The various fields are used
   for conveying information from your main routine into your callbacks,
   for passing information into the instruction decoders (such as the
   addresses of the callback functions), or for passing information
   back from the instruction decoders to their callers.

   It must be initialized before it is first passed; this can be done
   by hand, or using one of the initialization macros below.  */

typedef struct disassemble_info
{
  fprintf_ftype fprintf_func;
  void *stream;
  void *application_data;

  /* Target description.  We could replace this with a pointer to the bfd,
     but that would require one.  There currently isn't any such requirement
     so to avoid introducing one we record these explicitly.  */
  /* The bfd_flavour.  This can be bfd_target_unknown_flavour.  */
  enum bfd_flavour flavour;
  /* The bfd_arch value.  */
  enum bfd_architecture arch;
  /* The bfd_mach value.  */
  unsigned long mach;
  /* Endianness (for bi-endian cpus).  Mono-endian cpus can ignore this.  */
  enum bfd_endian endian;
  /* Endianness of code, for mixed-endian situations such as ARM BE8.  */
  enum bfd_endian endian_code;
  /* An arch/mach-specific bitmask of selected instruction subsets, mainly
     for processors with run-time-switchable instruction sets.  The default,
     zero, means that there is no constraint.  CGEN-based opcodes ports
     may use ISA_foo masks.  */
  void *insn_sets;

  /* Some targets need information about the current section to accurately
     display insns.  If this is NULL, the target disassembler function
     will have to make its best guess.  */
  asection *section;

  /* An array of pointers to symbols either at the location being disassembled
     or at the start of the function being disassembled.  The array is sorted
     so that the first symbol is intended to be the one used.  The others are
     present for any misc. purposes.  This is not set reliably, but if it is
     not NULL, it is correct.  */
  asymbol **symbols;
  /* Number of symbols in array.  */
  int num_symbols;

  /* Symbol table provided for targets that want to look at it.  This is
     used on Arm to find mapping symbols and determine Arm/Thumb code.  */
  asymbol **symtab;
  int symtab_pos;
  int symtab_size;

  /* For use by the disassembler.
     The top 16 bits are reserved for public use (and are documented here).
     The bottom 16 bits are for the internal use of the disassembler.  */
  unsigned long flags;
  /* Set if the disassembler has determined that there are one or more
     relocations associated with the instruction being disassembled.  */
#define INSN_HAS_RELOC	 (1 << 31)
  /* Set if the user has requested the disassembly of data as well as code.  */
#define DISASSEMBLE_DATA (1 << 30)
  /* Set if the user has specifically set the machine type encoded in the
     mach field of this structure.  */
#define USER_SPECIFIED_MACHINE_TYPE (1 << 29)

  /* Use internally by the target specific disassembly code.  */
  void *private_data;

  /* Function used to get bytes to disassemble.  MEMADDR is the
     address of the stuff to be disassembled, MYADDR is the address to
     put the bytes in, and LENGTH is the number of bytes to read.
     INFO is a pointer to this struct.
     Returns an errno value or 0 for success.  */
  int (*read_memory_func)
    (bfd_vma memaddr, bfd_byte *myaddr, unsigned int length,
     struct disassemble_info *dinfo);

  /* Function which should be called if we get an error that we can't
     recover from.  STATUS is the errno value from read_memory_func and
     MEMADDR is the address that we were trying to read.  INFO is a
     pointer to this struct.  */
  void (*memory_error_func)
    (int status, bfd_vma memaddr, struct disassemble_info *dinfo);

  /* Function called to print ADDR.  */
  void (*print_address_func)
    (bfd_vma addr, struct disassemble_info *dinfo);

  /* Function called to determine if there is a symbol at the given ADDR.
     If there is, the function returns 1, otherwise it returns 0.
     This is used by ports which support an overlay manager where
     the overlay number is held in the top part of an address.  In
     some circumstances we want to include the overlay number in the
     address, (normally because there is a symbol associated with
     that address), but sometimes we want to mask out the overlay bits.  */
  int (* symbol_at_address_func)
    (bfd_vma addr, struct disassemble_info *dinfo);

  /* Function called to check if a SYMBOL is can be displayed to the user.
     This is used by some ports that want to hide special symbols when
     displaying debugging outout.  */
  bfd_boolean (* symbol_is_valid)
    (asymbol *, struct disassemble_info *dinfo);

  /* These are for buffer_read_memory.  */
  bfd_byte *buffer;
  bfd_vma buffer_vma;
  size_t buffer_length;

  /* This variable may be set by the instruction decoder.  It suggests
      the number of bytes objdump should display on a single line.  If
      the instruction decoder sets this, it should always set it to
      the same value in order to get reasonable looking output.  */
  int bytes_per_line;

  /* The next two variables control the way objdump displays the raw data.  */
  /* For example, if bytes_per_line is 8 and bytes_per_chunk is 4, the */
  /* output will look like this:
     00:   00000000 00000000
     with the chunks displayed according to "display_endian". */
  int bytes_per_chunk;
  enum bfd_endian display_endian;

  /* Number of octets per incremented target address
     Normally one, but some DSPs have byte sizes of 16 or 32 bits.  */
  unsigned int octets_per_byte;

  /* The number of zeroes we want to see at the end of a section before we
     start skipping them.  */
  unsigned int skip_zeroes;

  /* The number of zeroes to skip at the end of a section.  If the number
     of zeroes at the end is between SKIP_ZEROES_AT_END and SKIP_ZEROES,
     they will be disassembled.  If there are fewer than
     SKIP_ZEROES_AT_END, they will be skipped.  This is a heuristic
     attempt to avoid disassembling zeroes inserted by section
     alignment.  */
  unsigned int skip_zeroes_at_end;

  /* Whether the disassembler always needs the relocations.  */
  bfd_boolean disassembler_needs_relocs;

  /* Results from instruction decoders.  Not all decoders yet support
     this information.  This info is set each time an instruction is
     decoded, and is only valid for the last such instruction.

     To determine whether this decoder supports this information, set
     insn_info_valid to 0, decode an instruction, then check it.  */

  char insn_info_valid;		/* Branch info has been set. */
  char branch_delay_insns;	/* How many sequential insn's will run before
				   a branch takes effect.  (0 = normal) */
  char data_size;		/* Size of data reference in insn, in bytes */
  enum dis_insn_type insn_type;	/* Type of instruction */
  bfd_vma target;		/* Target address of branch or dref, if known;
				   zero if unknown.  */
  bfd_vma target2;		/* Second target address for dref2 */

  /* Command line options specific to the target disassembler.  */
  const char *disassembler_options;

  /* If non-zero then try not disassemble beyond this address, even if
     there are values left in the buffer.  This address is the address
     of the nearest symbol forwards from the start of the disassembly,
     and it is assumed that it lies on the boundary between instructions.
     If an instruction spans this address then this is an error in the
     file being disassembled.  */
  bfd_vma stop_vma;

} disassemble_info;

/* This struct is used to pass information about valid disassembler
   option arguments from the target to the generic GDB functions
   that set and display them.  */

typedef struct
{
  /* Option argument name to use in descriptions.  */
  const char *name;

  /* Vector of acceptable option argument values, NULL-terminated.  */
  const char **values;
} disasm_option_arg_t;

/* This struct is used to pass information about valid disassembler
   options, their descriptions and arguments from the target to the
   generic GDB functions that set and display them.  Options are
   defined by tuples of vector entries at each index.  */

typedef struct
{
  /* Vector of option names, NULL-terminated.  */
  const char **name;

  /* Vector of option descriptions or NULL if none to be shown.  */
  const char **description;

  /* Vector of option argument information pointers or NULL if no
     option accepts an argument.  NULL entries denote individual
     options that accept no argument.  */
  const disasm_option_arg_t **arg;
} disasm_options_t;

/* This struct is used to pass information about valid disassembler
   options and arguments from the target to the generic GDB functions
   that set and display them.  */

typedef struct
{
  /* Valid disassembler options.  Individual options that support
     an argument will refer to entries in the ARGS vector.  */
  disasm_options_t options;

  /* Vector of acceptable option arguments, NULL-terminated.  This
     collects all possible option argument choices, some of which
     may be shared by different options from the OPTIONS member.  */
  disasm_option_arg_t *args;
} disasm_options_and_args_t;

/* Standard disassemblers.  Disassemble one instruction at the given
   target address.  Return number of octets processed.  */
typedef int (*disassembler_ftype) (bfd_vma, disassemble_info *);

/* Disassemblers used out side of opcodes library.  */
extern int print_insn_m32c		(bfd_vma, disassemble_info *);
extern int print_insn_mep		(bfd_vma, disassemble_info *);
extern int print_insn_s12z		(bfd_vma, disassemble_info *);
extern int print_insn_sh		(bfd_vma, disassemble_info *);
extern int print_insn_sparc		(bfd_vma, disassemble_info *);
extern int print_insn_rx		(bfd_vma, disassemble_info *);
extern int print_insn_rl78		(bfd_vma, disassemble_info *);
extern int print_insn_rl78_g10		(bfd_vma, disassemble_info *);
extern int print_insn_rl78_g13		(bfd_vma, disassemble_info *);
extern int print_insn_rl78_g14		(bfd_vma, disassemble_info *);

extern disassembler_ftype arc_get_disassembler (bfd *);
extern disassembler_ftype cris_get_disassembler (bfd *);

extern void print_aarch64_disassembler_options (FILE *);
extern void print_i386_disassembler_options (FILE *);
extern void print_mips_disassembler_options (FILE *);
extern void print_nfp_disassembler_options (FILE *);
extern void print_ppc_disassembler_options (FILE *);
extern void print_riscv_disassembler_options (FILE *);
extern void print_arm_disassembler_options (FILE *);
extern void print_arc_disassembler_options (FILE *);
extern void print_s390_disassembler_options (FILE *);
extern void print_wasm32_disassembler_options (FILE *);
extern bfd_boolean aarch64_symbol_is_valid (asymbol *, struct disassemble_info *);
extern bfd_boolean arm_symbol_is_valid (asymbol *, struct disassemble_info *);
extern bfd_boolean csky_symbol_is_valid (asymbol *, struct disassemble_info *);
extern bfd_boolean riscv_symbol_is_valid (asymbol *, struct disassemble_info *);
extern void disassemble_init_powerpc (struct disassemble_info *);
extern void disassemble_init_s390 (struct disassemble_info *);
extern void disassemble_init_wasm32 (struct disassemble_info *);
extern void disassemble_init_nds32 (struct disassemble_info *);
extern const disasm_options_and_args_t *disassembler_options_arm (void);
extern const disasm_options_and_args_t *disassembler_options_mips (void);
extern const disasm_options_and_args_t *disassembler_options_powerpc (void);
extern const disasm_options_and_args_t *disassembler_options_s390 (void);

/* Fetch the disassembler for a given architecture ARC, endianess (big
   endian if BIG is true), bfd_mach value MACH, and ABFD, if that support
   is available.  ABFD may be NULL.  */
extern disassembler_ftype disassembler (enum bfd_architecture arc,
					bfd_boolean big, unsigned long mach,
					bfd *abfd);

/* Amend the disassemble_info structure as necessary for the target architecture.
   Should only be called after initialising the info->arch field.  */
extern void disassemble_init_for_target (struct disassemble_info * dinfo);

/* Document any target specific options available from the disassembler.  */
extern void disassembler_usage (FILE *);

/* Remove whitespace and consecutive commas.  */
extern char *remove_whitespace_and_extra_commas (char *);

/* Like STRCMP, but treat ',' the same as '\0' so that we match
   strings like "foobar" against "foobar,xxyyzz,...".  */
extern int disassembler_options_cmp (const char *, const char *);

/* A helper function for FOR_EACH_DISASSEMBLER_OPTION.  */
static inline const char *
next_disassembler_option (const char *options)
{
  const char *opt = strchr (options, ',');
  if (opt != NULL)
    opt++;
  return opt;
}

/* A macro for iterating over each comma separated option in OPTIONS.  */
#define FOR_EACH_DISASSEMBLER_OPTION(OPT, OPTIONS) \
  for ((OPT) = (OPTIONS); \
       (OPT) != NULL; \
       (OPT) = next_disassembler_option (OPT))


/* This block of definitions is for particular callers who read instructions
   into a buffer before calling the instruction decoder.  */

/* Here is a function which callers may wish to use for read_memory_func.
   It gets bytes from a buffer.  */
extern int buffer_read_memory
  (bfd_vma, bfd_byte *, unsigned int, struct disassemble_info *);

/* This function goes with buffer_read_memory.
   It prints a message using info->fprintf_func and info->stream.  */
extern void perror_memory (int, bfd_vma, struct disassemble_info *);


/* Just print the address in hex.  This is included for completeness even
   though both GDB and objdump provide their own (to print symbolic
   addresses).  */
extern void generic_print_address
  (bfd_vma, struct disassemble_info *);

/* Always true.  */
extern int generic_symbol_at_address
  (bfd_vma, struct disassemble_info *);

/* Also always true.  */
extern bfd_boolean generic_symbol_is_valid
  (asymbol *, struct disassemble_info *);

/* Method to initialize a disassemble_info struct.  This should be
   called by all applications creating such a struct.  */
extern void init_disassemble_info (struct disassemble_info *dinfo, void *stream,
				   fprintf_ftype fprintf_func);

/* For compatibility with existing code.  */
#define INIT_DISASSEMBLE_INFO(INFO, STREAM, FPRINTF_FUNC) \
  init_disassemble_info (&(INFO), (STREAM), (fprintf_ftype) (FPRINTF_FUNC))
#define INIT_DISASSEMBLE_INFO_NO_ARCH(INFO, STREAM, FPRINTF_FUNC) \
  init_disassemble_info (&(INFO), (STREAM), (fprintf_ftype) (FPRINTF_FUNC))


#ifdef __cplusplus
}
#endif

#endif /* ! defined (DIS_ASM_H) */