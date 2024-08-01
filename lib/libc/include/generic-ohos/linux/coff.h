/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI_LINUX_COFF_H
#define _UAPI_LINUX_COFF_H
#define E_SYMNMLEN 8
#define E_FILNMLEN 14
#define E_DIMNUM 4
#define COFF_SHORT_L(ps) ((short) (((unsigned short) ((unsigned char) ps[1]) << 8) | ((unsigned short) ((unsigned char) ps[0]))))
#define COFF_LONG_L(ps) (((long) (((unsigned long) ((unsigned char) ps[3]) << 24) | ((unsigned long) ((unsigned char) ps[2]) << 16) | ((unsigned long) ((unsigned char) ps[1]) << 8) | ((unsigned long) ((unsigned char) ps[0])))))
#define COFF_SHORT_H(ps) ((short) (((unsigned short) ((unsigned char) ps[0]) << 8) | ((unsigned short) ((unsigned char) ps[1]))))
#define COFF_LONG_H(ps) (((long) (((unsigned long) ((unsigned char) ps[0]) << 24) | ((unsigned long) ((unsigned char) ps[1]) << 16) | ((unsigned long) ((unsigned char) ps[2]) << 8) | ((unsigned long) ((unsigned char) ps[3])))))
#define COFF_LONG(v) COFF_LONG_L(v)
#define COFF_SHORT(v) COFF_SHORT_L(v)
struct COFF_filehdr {
  char f_magic[2];
  char f_nscns[2];
  char f_timdat[4];
  char f_symptr[4];
  char f_nsyms[4];
  char f_opthdr[2];
  char f_flags[2];
};
#define COFF_F_RELFLG 0000001
#define COFF_F_EXEC 0000002
#define COFF_F_LNNO 0000004
#define COFF_F_LSYMS 0000010
#define COFF_F_MINMAL 0000020
#define COFF_F_UPDATE 0000040
#define COFF_F_SWABD 0000100
#define COFF_F_AR16WR 0000200
#define COFF_F_AR32WR 0000400
#define COFF_F_AR32W 0001000
#define COFF_F_PATCH 0002000
#define COFF_F_NODF 0002000
#define COFF_I386MAGIC 0x14c
#define COFF_I386BADMAG(x) (COFF_SHORT((x).f_magic) != COFF_I386MAGIC)
#define COFF_FILHDR struct COFF_filehdr
#define COFF_FILHSZ sizeof(COFF_FILHDR)
typedef struct {
  char magic[2];
  char vstamp[2];
  char tsize[4];
  char dsize[4];
  char bsize[4];
  char entry[4];
  char text_start[4];
  char data_start[4];
} COFF_AOUTHDR;
#define COFF_AOUTSZ (sizeof(COFF_AOUTHDR))
#define COFF_STMAGIC 0401
#define COFF_OMAGIC 0404
#define COFF_JMAGIC 0407
#define COFF_DMAGIC 0410
#define COFF_ZMAGIC 0413
#define COFF_SHMAGIC 0443
struct COFF_scnhdr {
  char s_name[8];
  char s_paddr[4];
  char s_vaddr[4];
  char s_size[4];
  char s_scnptr[4];
  char s_relptr[4];
  char s_lnnoptr[4];
  char s_nreloc[2];
  char s_nlnno[2];
  char s_flags[4];
};
#define COFF_SCNHDR struct COFF_scnhdr
#define COFF_SCNHSZ sizeof(COFF_SCNHDR)
#define COFF_TEXT ".text"
#define COFF_DATA ".data"
#define COFF_BSS ".bss"
#define COFF_COMMENT ".comment"
#define COFF_LIB ".lib"
#define COFF_SECT_TEXT 0
#define COFF_SECT_DATA 1
#define COFF_SECT_BSS 2
#define COFF_SECT_REQD 3
#define COFF_STYP_REG 0x00
#define COFF_STYP_DSECT 0x01
#define COFF_STYP_NOLOAD 0x02
#define COFF_STYP_GROUP 0x04
#define COFF_STYP_PAD 0x08
#define COFF_STYP_COPY 0x10
#define COFF_STYP_TEXT 0x20
#define COFF_STYP_DATA 0x40
#define COFF_STYP_BSS 0x80
#define COFF_STYP_INFO 0x200
#define COFF_STYP_OVER 0x400
#define COFF_STYP_LIB 0x800
struct COFF_slib {
  char sl_entsz[4];
  char sl_pathndx[4];
};
#define COFF_SLIBHD struct COFF_slib
#define COFF_SLIBSZ sizeof(COFF_SLIBHD)
struct COFF_lineno {
  union {
    char l_symndx[4];
    char l_paddr[4];
  } l_addr;
  char l_lnno[2];
};
#define COFF_LINENO struct COFF_lineno
#define COFF_LINESZ 6
#define COFF_E_SYMNMLEN 8
#define COFF_E_FILNMLEN 14
#define COFF_E_DIMNUM 4
struct COFF_syment {
  union {
    char e_name[E_SYMNMLEN];
    struct {
      char e_zeroes[4];
      char e_offset[4];
    } e;
  } e;
  char e_value[4];
  char e_scnum[2];
  char e_type[2];
  char e_sclass[1];
  char e_numaux[1];
};
#define COFF_N_BTMASK (0xf)
#define COFF_N_TMASK (0x30)
#define COFF_N_BTSHFT (4)
#define COFF_N_TSHIFT (2)
union COFF_auxent {
  struct {
    char x_tagndx[4];
    union {
      struct {
        char x_lnno[2];
        char x_size[2];
      } x_lnsz;
      char x_fsize[4];
    } x_misc;
    union {
      struct {
        char x_lnnoptr[4];
        char x_endndx[4];
      } x_fcn;
      struct {
        char x_dimen[E_DIMNUM][2];
      } x_ary;
    } x_fcnary;
    char x_tvndx[2];
  } x_sym;
  union {
    char x_fname[E_FILNMLEN];
    struct {
      char x_zeroes[4];
      char x_offset[4];
    } x_n;
  } x_file;
  struct {
    char x_scnlen[4];
    char x_nreloc[2];
    char x_nlinno[2];
  } x_scn;
  struct {
    char x_tvfill[4];
    char x_tvlen[2];
    char x_tvran[2][2];
  } x_tv;
};
#define COFF_SYMENT struct COFF_syment
#define COFF_SYMESZ 18
#define COFF_AUXENT union COFF_auxent
#define COFF_AUXESZ 18
#define COFF_ETEXT "etext"
struct COFF_reloc {
  char r_vaddr[4];
  char r_symndx[4];
  char r_type[2];
};
#define COFF_RELOC struct COFF_reloc
#define COFF_RELSZ 10
#define COFF_DEF_DATA_SECTION_ALIGNMENT 4
#define COFF_DEF_BSS_SECTION_ALIGNMENT 4
#define COFF_DEF_TEXT_SECTION_ALIGNMENT 4
#define COFF_DEF_SECTION_ALIGNMENT 4
#endif