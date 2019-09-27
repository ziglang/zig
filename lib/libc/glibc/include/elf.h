#ifndef _ELF_H
#include <elf/elf.h>

#ifndef _ISOMAC

# include <libc-pointer-arith.h>

/* Compute the offset of the note descriptor from size of note entry's
   owner string and note alignment.  */
# define ELF_NOTE_DESC_OFFSET(namesz, align) \
  ALIGN_UP (sizeof (ElfW(Nhdr)) + (namesz), (align))

/* Compute the offset of the next note entry from size of note entry's
   owner string, size of the note descriptor and note alignment.  */
# define ELF_NOTE_NEXT_OFFSET(namesz, descsz, align) \
  ALIGN_UP (ELF_NOTE_DESC_OFFSET ((namesz), (align)) + (descsz), (align))

/* Some information which is not meant for the public and therefore not
   in <elf.h>.  */
# include <dl-dtprocnum.h>
# ifdef DT_1_SUPPORTED_MASK
#  error DT_1_SUPPORTED_MASK is defined!
# endif
# define DT_1_SUPPORTED_MASK \
   (DF_1_NOW | DF_1_NODELETE | DF_1_INITFIRST | DF_1_NOOPEN \
    | DF_1_ORIGIN | DF_1_NODEFLIB | DF_1_PIE)

#endif /* !_ISOMAC */
#endif /* elf.h */
