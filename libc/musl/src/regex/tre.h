/*
  tre-internal.h - TRE internal definitions

  Copyright (c) 2001-2009 Ville Laurikari <vl@iki.fi>
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS
  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#include <regex.h>
#include <wchar.h>
#include <wctype.h>

#undef  TRE_MBSTATE

#define NDEBUG

#define TRE_REGEX_T_FIELD __opaque
typedef int reg_errcode_t;

typedef wchar_t tre_char_t;

#define DPRINT(msg) do { } while(0)

#define elementsof(x)	( sizeof(x) / sizeof(x[0]) )

#define tre_mbrtowc(pwc, s, n, ps) (mbtowc((pwc), (s), (n)))

/* Wide characters. */
typedef wint_t tre_cint_t;
#define TRE_CHAR_MAX 0x10ffff

#define tre_isalnum iswalnum
#define tre_isalpha iswalpha
#define tre_isblank iswblank
#define tre_iscntrl iswcntrl
#define tre_isdigit iswdigit
#define tre_isgraph iswgraph
#define tre_islower iswlower
#define tre_isprint iswprint
#define tre_ispunct iswpunct
#define tre_isspace iswspace
#define tre_isupper iswupper
#define tre_isxdigit iswxdigit

#define tre_tolower towlower
#define tre_toupper towupper
#define tre_strlen  wcslen

/* Use system provided iswctype() and wctype(). */
typedef wctype_t tre_ctype_t;
#define tre_isctype iswctype
#define tre_ctype   wctype

/* Returns number of bytes to add to (char *)ptr to make it
   properly aligned for the type. */
#define ALIGN(ptr, type) \
  ((((long)ptr) % sizeof(type)) \
   ? (sizeof(type) - (((long)ptr) % sizeof(type))) \
   : 0)

#undef MAX
#undef MIN
#define MAX(a, b) (((a) >= (b)) ? (a) : (b))
#define MIN(a, b) (((a) <= (b)) ? (a) : (b))

/* TNFA transition type. A TNFA state is an array of transitions,
   the terminator is a transition with NULL `state'. */
typedef struct tnfa_transition tre_tnfa_transition_t;

struct tnfa_transition {
  /* Range of accepted characters. */
  tre_cint_t code_min;
  tre_cint_t code_max;
  /* Pointer to the destination state. */
  tre_tnfa_transition_t *state;
  /* ID number of the destination state. */
  int state_id;
  /* -1 terminated array of tags (or NULL). */
  int *tags;
  /* Assertion bitmap. */
  int assertions;
  /* Assertion parameters. */
  union {
    /* Character class assertion. */
    tre_ctype_t class;
    /* Back reference assertion. */
    int backref;
  } u;
  /* Negative character class assertions. */
  tre_ctype_t *neg_classes;
};


/* Assertions. */
#define ASSERT_AT_BOL		  1   /* Beginning of line. */
#define ASSERT_AT_EOL		  2   /* End of line. */
#define ASSERT_CHAR_CLASS	  4   /* Character class in `class'. */
#define ASSERT_CHAR_CLASS_NEG	  8   /* Character classes in `neg_classes'. */
#define ASSERT_AT_BOW		 16   /* Beginning of word. */
#define ASSERT_AT_EOW		 32   /* End of word. */
#define ASSERT_AT_WB		 64   /* Word boundary. */
#define ASSERT_AT_WB_NEG	128   /* Not a word boundary. */
#define ASSERT_BACKREF		256   /* A back reference in `backref'. */
#define ASSERT_LAST		256

/* Tag directions. */
typedef enum {
  TRE_TAG_MINIMIZE = 0,
  TRE_TAG_MAXIMIZE = 1
} tre_tag_direction_t;

/* Instructions to compute submatch register values from tag values
   after a successful match.  */
struct tre_submatch_data {
  /* Tag that gives the value for rm_so (submatch start offset). */
  int so_tag;
  /* Tag that gives the value for rm_eo (submatch end offset). */
  int eo_tag;
  /* List of submatches this submatch is contained in. */
  int *parents;
};

typedef struct tre_submatch_data tre_submatch_data_t;


/* TNFA definition. */
typedef struct tnfa tre_tnfa_t;

struct tnfa {
  tre_tnfa_transition_t *transitions;
  unsigned int num_transitions;
  tre_tnfa_transition_t *initial;
  tre_tnfa_transition_t *final;
  tre_submatch_data_t *submatch_data;
  char *firstpos_chars;
  int first_char;
  unsigned int num_submatches;
  tre_tag_direction_t *tag_directions;
  int *minimal_tags;
  int num_tags;
  int num_minimals;
  int end_tag;
  int num_states;
  int cflags;
  int have_backrefs;
  int have_approx;
};

/* from tre-mem.h: */

#define TRE_MEM_BLOCK_SIZE 1024

typedef struct tre_list {
  void *data;
  struct tre_list *next;
} tre_list_t;

typedef struct tre_mem_struct {
  tre_list_t *blocks;
  tre_list_t *current;
  char *ptr;
  size_t n;
  int failed;
  void **provided;
} *tre_mem_t;

#define tre_mem_new_impl   __tre_mem_new_impl
#define tre_mem_alloc_impl __tre_mem_alloc_impl
#define tre_mem_destroy    __tre_mem_destroy

hidden tre_mem_t tre_mem_new_impl(int provided, void *provided_block);
hidden void *tre_mem_alloc_impl(tre_mem_t mem, int provided, void *provided_block,
                                int zero, size_t size);

/* Returns a new memory allocator or NULL if out of memory. */
#define tre_mem_new()  tre_mem_new_impl(0, NULL)

/* Allocates a block of `size' bytes from `mem'.  Returns a pointer to the
   allocated block or NULL if an underlying malloc() failed. */
#define tre_mem_alloc(mem, size) tre_mem_alloc_impl(mem, 0, NULL, 0, size)

/* Allocates a block of `size' bytes from `mem'.  Returns a pointer to the
   allocated block or NULL if an underlying malloc() failed.  The memory
   is set to zero. */
#define tre_mem_calloc(mem, size) tre_mem_alloc_impl(mem, 0, NULL, 1, size)

#ifdef TRE_USE_ALLOCA
/* alloca() versions.  Like above, but memory is allocated with alloca()
   instead of malloc(). */

#define tre_mem_newa() \
  tre_mem_new_impl(1, alloca(sizeof(struct tre_mem_struct)))

#define tre_mem_alloca(mem, size)					      \
  ((mem)->n >= (size)							      \
   ? tre_mem_alloc_impl((mem), 1, NULL, 0, (size))			      \
   : tre_mem_alloc_impl((mem), 1, alloca(TRE_MEM_BLOCK_SIZE), 0, (size)))
#endif /* TRE_USE_ALLOCA */


/* Frees the memory allocator and all memory allocated with it. */
hidden void tre_mem_destroy(tre_mem_t mem);

#define xmalloc malloc
#define xcalloc calloc
#define xfree free
#define xrealloc realloc

