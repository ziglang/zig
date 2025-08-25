/*
  regexec.c - TRE POSIX compatible matching functions (and more).

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

#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <wctype.h>
#include <limits.h>
#include <stdint.h>

#include <regex.h>

#include "tre.h"

#include <assert.h>

static void
tre_fill_pmatch(size_t nmatch, regmatch_t pmatch[], int cflags,
		const tre_tnfa_t *tnfa, regoff_t *tags, regoff_t match_eo);

/***********************************************************************
 from tre-match-utils.h
***********************************************************************/

#define GET_NEXT_WCHAR() do {                                                 \
    prev_c = next_c; pos += pos_add_next;                                     \
    if ((pos_add_next = mbtowc(&next_c, str_byte, MB_LEN_MAX)) <= 0) {        \
        if (pos_add_next < 0) { ret = REG_NOMATCH; goto error_exit; }         \
        else pos_add_next++;                                                  \
    }                                                                         \
    str_byte += pos_add_next;                                                 \
  } while (0)

#define IS_WORD_CHAR(c)	 ((c) == L'_' || tre_isalnum(c))

#define CHECK_ASSERTIONS(assertions)					      \
  (((assertions & ASSERT_AT_BOL)					      \
    && (pos > 0 || reg_notbol)						      \
    && (prev_c != L'\n' || !reg_newline))				      \
   || ((assertions & ASSERT_AT_EOL)					      \
       && (next_c != L'\0' || reg_noteol)				      \
       && (next_c != L'\n' || !reg_newline))				      \
   || ((assertions & ASSERT_AT_BOW)					      \
       && (IS_WORD_CHAR(prev_c) || !IS_WORD_CHAR(next_c)))	              \
   || ((assertions & ASSERT_AT_EOW)					      \
       && (!IS_WORD_CHAR(prev_c) || IS_WORD_CHAR(next_c)))		      \
   || ((assertions & ASSERT_AT_WB)					      \
       && (pos != 0 && next_c != L'\0'					      \
	   && IS_WORD_CHAR(prev_c) == IS_WORD_CHAR(next_c)))		      \
   || ((assertions & ASSERT_AT_WB_NEG)					      \
       && (pos == 0 || next_c == L'\0'					      \
	   || IS_WORD_CHAR(prev_c) != IS_WORD_CHAR(next_c))))

#define CHECK_CHAR_CLASSES(trans_i, tnfa, eflags)                             \
  (((trans_i->assertions & ASSERT_CHAR_CLASS)                                 \
       && !(tnfa->cflags & REG_ICASE)                                         \
       && !tre_isctype((tre_cint_t)prev_c, trans_i->u.class))                 \
    || ((trans_i->assertions & ASSERT_CHAR_CLASS)                             \
        && (tnfa->cflags & REG_ICASE)                                         \
        && !tre_isctype(tre_tolower((tre_cint_t)prev_c),trans_i->u.class)     \
	&& !tre_isctype(tre_toupper((tre_cint_t)prev_c),trans_i->u.class))    \
    || ((trans_i->assertions & ASSERT_CHAR_CLASS_NEG)                         \
        && tre_neg_char_classes_match(trans_i->neg_classes,(tre_cint_t)prev_c,\
                                      tnfa->cflags & REG_ICASE)))




/* Returns 1 if `t1' wins `t2', 0 otherwise. */
static int
tre_tag_order(int num_tags, tre_tag_direction_t *tag_directions,
	      regoff_t *t1, regoff_t *t2)
{
  int i;
  for (i = 0; i < num_tags; i++)
    {
      if (tag_directions[i] == TRE_TAG_MINIMIZE)
	{
	  if (t1[i] < t2[i])
	    return 1;
	  if (t1[i] > t2[i])
	    return 0;
	}
      else
	{
	  if (t1[i] > t2[i])
	    return 1;
	  if (t1[i] < t2[i])
	    return 0;
	}
    }
  /*  assert(0);*/
  return 0;
}

static int
tre_neg_char_classes_match(tre_ctype_t *classes, tre_cint_t wc, int icase)
{
  while (*classes != (tre_ctype_t)0)
    if ((!icase && tre_isctype(wc, *classes))
	|| (icase && (tre_isctype(tre_toupper(wc), *classes)
		      || tre_isctype(tre_tolower(wc), *classes))))
      return 1; /* Match. */
    else
      classes++;
  return 0; /* No match. */
}


/***********************************************************************
 from tre-match-parallel.c
***********************************************************************/

/*
  This algorithm searches for matches basically by reading characters
  in the searched string one by one, starting at the beginning.	 All
  matching paths in the TNFA are traversed in parallel.	 When two or
  more paths reach the same state, exactly one is chosen according to
  tag ordering rules; if returning submatches is not required it does
  not matter which path is chosen.

  The worst case time required for finding the leftmost and longest
  match, or determining that there is no match, is always linearly
  dependent on the length of the text being searched.

  This algorithm cannot handle TNFAs with back referencing nodes.
  See `tre-match-backtrack.c'.
*/

typedef struct {
  tre_tnfa_transition_t *state;
  regoff_t *tags;
} tre_tnfa_reach_t;

typedef struct {
  regoff_t pos;
  regoff_t **tags;
} tre_reach_pos_t;


static reg_errcode_t
tre_tnfa_run_parallel(const tre_tnfa_t *tnfa, const void *string,
		      regoff_t *match_tags, int eflags,
		      regoff_t *match_end_ofs)
{
  /* State variables required by GET_NEXT_WCHAR. */
  tre_char_t prev_c = 0, next_c = 0;
  const char *str_byte = string;
  regoff_t pos = -1;
  regoff_t pos_add_next = 1;
#ifdef TRE_MBSTATE
  mbstate_t mbstate;
#endif /* TRE_MBSTATE */
  int reg_notbol = eflags & REG_NOTBOL;
  int reg_noteol = eflags & REG_NOTEOL;
  int reg_newline = tnfa->cflags & REG_NEWLINE;
  reg_errcode_t ret;

  char *buf;
  tre_tnfa_transition_t *trans_i;
  tre_tnfa_reach_t *reach, *reach_next, *reach_i, *reach_next_i;
  tre_reach_pos_t *reach_pos;
  int *tag_i;
  int num_tags, i;

  regoff_t match_eo = -1;	   /* end offset of match (-1 if no match found yet) */
  int new_match = 0;
  regoff_t *tmp_tags = NULL;
  regoff_t *tmp_iptr;

#ifdef TRE_MBSTATE
  memset(&mbstate, '\0', sizeof(mbstate));
#endif /* TRE_MBSTATE */

  if (!match_tags)
    num_tags = 0;
  else
    num_tags = tnfa->num_tags;

  /* Allocate memory for temporary data required for matching.	This needs to
     be done for every matching operation to be thread safe.  This allocates
     everything in a single large block with calloc(). */
  {
    size_t tbytes, rbytes, pbytes, xbytes, total_bytes;
    char *tmp_buf;

    /* Ensure that tbytes and xbytes*num_states cannot overflow, and that
     * they don't contribute more than 1/8 of SIZE_MAX to total_bytes. */
    if (num_tags > SIZE_MAX/(8 * sizeof(regoff_t) * tnfa->num_states))
      return REG_ESPACE;

    /* Likewise check rbytes. */
    if (tnfa->num_states+1 > SIZE_MAX/(8 * sizeof(*reach_next)))
      return REG_ESPACE;

    /* Likewise check pbytes. */
    if (tnfa->num_states > SIZE_MAX/(8 * sizeof(*reach_pos)))
      return REG_ESPACE;

    /* Compute the length of the block we need. */
    tbytes = sizeof(*tmp_tags) * num_tags;
    rbytes = sizeof(*reach_next) * (tnfa->num_states + 1);
    pbytes = sizeof(*reach_pos) * tnfa->num_states;
    xbytes = sizeof(regoff_t) * num_tags;
    total_bytes =
      (sizeof(long) - 1) * 4 /* for alignment paddings */
      + (rbytes + xbytes * tnfa->num_states) * 2 + tbytes + pbytes;

    /* Allocate the memory. */
    buf = calloc(total_bytes, 1);
    if (buf == NULL)
      return REG_ESPACE;

    /* Get the various pointers within tmp_buf (properly aligned). */
    tmp_tags = (void *)buf;
    tmp_buf = buf + tbytes;
    tmp_buf += ALIGN(tmp_buf, long);
    reach_next = (void *)tmp_buf;
    tmp_buf += rbytes;
    tmp_buf += ALIGN(tmp_buf, long);
    reach = (void *)tmp_buf;
    tmp_buf += rbytes;
    tmp_buf += ALIGN(tmp_buf, long);
    reach_pos = (void *)tmp_buf;
    tmp_buf += pbytes;
    tmp_buf += ALIGN(tmp_buf, long);
    for (i = 0; i < tnfa->num_states; i++)
      {
	reach[i].tags = (void *)tmp_buf;
	tmp_buf += xbytes;
	reach_next[i].tags = (void *)tmp_buf;
	tmp_buf += xbytes;
      }
  }

  for (i = 0; i < tnfa->num_states; i++)
    reach_pos[i].pos = -1;

  GET_NEXT_WCHAR();
  pos = 0;

  reach_next_i = reach_next;
  while (1)
    {
      /* If no match found yet, add the initial states to `reach_next'. */
      if (match_eo < 0)
	{
	  trans_i = tnfa->initial;
	  while (trans_i->state != NULL)
	    {
	      if (reach_pos[trans_i->state_id].pos < pos)
		{
		  if (trans_i->assertions
		      && CHECK_ASSERTIONS(trans_i->assertions))
		    {
		      trans_i++;
		      continue;
		    }

		  reach_next_i->state = trans_i->state;
		  for (i = 0; i < num_tags; i++)
		    reach_next_i->tags[i] = -1;
		  tag_i = trans_i->tags;
		  if (tag_i)
		    while (*tag_i >= 0)
		      {
			if (*tag_i < num_tags)
			  reach_next_i->tags[*tag_i] = pos;
			tag_i++;
		      }
		  if (reach_next_i->state == tnfa->final)
		    {
		      match_eo = pos;
		      new_match = 1;
		      for (i = 0; i < num_tags; i++)
			match_tags[i] = reach_next_i->tags[i];
		    }
		  reach_pos[trans_i->state_id].pos = pos;
		  reach_pos[trans_i->state_id].tags = &reach_next_i->tags;
		  reach_next_i++;
		}
	      trans_i++;
	    }
	  reach_next_i->state = NULL;
	}
      else
	{
	  if (num_tags == 0 || reach_next_i == reach_next)
	    /* We have found a match. */
	    break;
	}

      /* Check for end of string. */
      if (!next_c) break;

      GET_NEXT_WCHAR();

      /* Swap `reach' and `reach_next'. */
      reach_i = reach;
      reach = reach_next;
      reach_next = reach_i;

      /* For each state in `reach', weed out states that don't fulfill the
	 minimal matching conditions. */
      if (tnfa->num_minimals && new_match)
	{
	  new_match = 0;
	  reach_next_i = reach_next;
	  for (reach_i = reach; reach_i->state; reach_i++)
	    {
	      int skip = 0;
	      for (i = 0; tnfa->minimal_tags[i] >= 0; i += 2)
		{
		  int end = tnfa->minimal_tags[i];
		  int start = tnfa->minimal_tags[i + 1];
		  if (end >= num_tags)
		    {
		      skip = 1;
		      break;
		    }
		  else if (reach_i->tags[start] == match_tags[start]
			   && reach_i->tags[end] < match_tags[end])
		    {
		      skip = 1;
		      break;
		    }
		}
	      if (!skip)
		{
		  reach_next_i->state = reach_i->state;
		  tmp_iptr = reach_next_i->tags;
		  reach_next_i->tags = reach_i->tags;
		  reach_i->tags = tmp_iptr;
		  reach_next_i++;
		}
	    }
	  reach_next_i->state = NULL;

	  /* Swap `reach' and `reach_next'. */
	  reach_i = reach;
	  reach = reach_next;
	  reach_next = reach_i;
	}

      /* For each state in `reach' see if there is a transition leaving with
	 the current input symbol to a state not yet in `reach_next', and
	 add the destination states to `reach_next'. */
      reach_next_i = reach_next;
      for (reach_i = reach; reach_i->state; reach_i++)
	{
	  for (trans_i = reach_i->state; trans_i->state; trans_i++)
	    {
	      /* Does this transition match the input symbol? */
	      if (trans_i->code_min <= (tre_cint_t)prev_c &&
		  trans_i->code_max >= (tre_cint_t)prev_c)
		{
		  if (trans_i->assertions
		      && (CHECK_ASSERTIONS(trans_i->assertions)
			  || CHECK_CHAR_CLASSES(trans_i, tnfa, eflags)))
		    {
		      continue;
		    }

		  /* Compute the tags after this transition. */
		  for (i = 0; i < num_tags; i++)
		    tmp_tags[i] = reach_i->tags[i];
		  tag_i = trans_i->tags;
		  if (tag_i != NULL)
		    while (*tag_i >= 0)
		      {
			if (*tag_i < num_tags)
			  tmp_tags[*tag_i] = pos;
			tag_i++;
		      }

		  if (reach_pos[trans_i->state_id].pos < pos)
		    {
		      /* Found an unvisited node. */
		      reach_next_i->state = trans_i->state;
		      tmp_iptr = reach_next_i->tags;
		      reach_next_i->tags = tmp_tags;
		      tmp_tags = tmp_iptr;
		      reach_pos[trans_i->state_id].pos = pos;
		      reach_pos[trans_i->state_id].tags = &reach_next_i->tags;

		      if (reach_next_i->state == tnfa->final
			  && (match_eo == -1
			      || (num_tags > 0
				  && reach_next_i->tags[0] <= match_tags[0])))
			{
			  match_eo = pos;
			  new_match = 1;
			  for (i = 0; i < num_tags; i++)
			    match_tags[i] = reach_next_i->tags[i];
			}
		      reach_next_i++;

		    }
		  else
		    {
		      assert(reach_pos[trans_i->state_id].pos == pos);
		      /* Another path has also reached this state.  We choose
			 the winner by examining the tag values for both
			 paths. */
		      if (tre_tag_order(num_tags, tnfa->tag_directions,
					tmp_tags,
					*reach_pos[trans_i->state_id].tags))
			{
			  /* The new path wins. */
			  tmp_iptr = *reach_pos[trans_i->state_id].tags;
			  *reach_pos[trans_i->state_id].tags = tmp_tags;
			  if (trans_i->state == tnfa->final)
			    {
			      match_eo = pos;
			      new_match = 1;
			      for (i = 0; i < num_tags; i++)
				match_tags[i] = tmp_tags[i];
			    }
			  tmp_tags = tmp_iptr;
			}
		    }
		}
	    }
	}
      reach_next_i->state = NULL;
    }

  *match_end_ofs = match_eo;
  ret = match_eo >= 0 ? REG_OK : REG_NOMATCH;
error_exit:
  xfree(buf);
  return ret;
}



/***********************************************************************
 from tre-match-backtrack.c
***********************************************************************/

/*
  This matcher is for regexps that use back referencing.  Regexp matching
  with back referencing is an NP-complete problem on the number of back
  references.  The easiest way to match them is to use a backtracking
  routine which basically goes through all possible paths in the TNFA
  and chooses the one which results in the best (leftmost and longest)
  match.  This can be spectacularly expensive and may run out of stack
  space, but there really is no better known generic algorithm.	 Quoting
  Henry Spencer from comp.compilers:
  <URL: http://compilers.iecc.com/comparch/article/93-03-102>

    POSIX.2 REs require longest match, which is really exciting to
    implement since the obsolete ("basic") variant also includes
    \<digit>.  I haven't found a better way of tackling this than doing
    a preliminary match using a DFA (or simulation) on a modified RE
    that just replicates subREs for \<digit>, and then doing a
    backtracking match to determine whether the subRE matches were
    right.  This can be rather slow, but I console myself with the
    thought that people who use \<digit> deserve very slow execution.
    (Pun unintentional but very appropriate.)

*/

typedef struct {
  regoff_t pos;
  const char *str_byte;
  tre_tnfa_transition_t *state;
  int state_id;
  int next_c;
  regoff_t *tags;
#ifdef TRE_MBSTATE
  mbstate_t mbstate;
#endif /* TRE_MBSTATE */
} tre_backtrack_item_t;

typedef struct tre_backtrack_struct {
  tre_backtrack_item_t item;
  struct tre_backtrack_struct *prev;
  struct tre_backtrack_struct *next;
} *tre_backtrack_t;

#ifdef TRE_MBSTATE
#define BT_STACK_MBSTATE_IN  stack->item.mbstate = (mbstate)
#define BT_STACK_MBSTATE_OUT (mbstate) = stack->item.mbstate
#else /* !TRE_MBSTATE */
#define BT_STACK_MBSTATE_IN
#define BT_STACK_MBSTATE_OUT
#endif /* !TRE_MBSTATE */

#define tre_bt_mem_new		  tre_mem_new
#define tre_bt_mem_alloc	  tre_mem_alloc
#define tre_bt_mem_destroy	  tre_mem_destroy


#define BT_STACK_PUSH(_pos, _str_byte, _str_wide, _state, _state_id, _next_c, _tags, _mbstate) \
  do									      \
    {									      \
      int i;								      \
      if (!stack->next)							      \
	{								      \
	  tre_backtrack_t s;						      \
	  s = tre_bt_mem_alloc(mem, sizeof(*s));			      \
	  if (!s)							      \
	    {								      \
	      tre_bt_mem_destroy(mem);					      \
	      if (tags)							      \
		xfree(tags);						      \
	      if (pmatch)						      \
		xfree(pmatch);						      \
	      if (states_seen)						      \
		xfree(states_seen);					      \
	      return REG_ESPACE;					      \
	    }								      \
	  s->prev = stack;						      \
	  s->next = NULL;						      \
	  s->item.tags = tre_bt_mem_alloc(mem,				      \
					  sizeof(*tags) * tnfa->num_tags);    \
	  if (!s->item.tags)						      \
	    {								      \
	      tre_bt_mem_destroy(mem);					      \
	      if (tags)							      \
		xfree(tags);						      \
	      if (pmatch)						      \
		xfree(pmatch);						      \
	      if (states_seen)						      \
		xfree(states_seen);					      \
	      return REG_ESPACE;					      \
	    }								      \
	  stack->next = s;						      \
	  stack = s;							      \
	}								      \
      else								      \
	stack = stack->next;						      \
      stack->item.pos = (_pos);						      \
      stack->item.str_byte = (_str_byte);				      \
      stack->item.state = (_state);					      \
      stack->item.state_id = (_state_id);				      \
      stack->item.next_c = (_next_c);					      \
      for (i = 0; i < tnfa->num_tags; i++)				      \
	stack->item.tags[i] = (_tags)[i];				      \
      BT_STACK_MBSTATE_IN;						      \
    }									      \
  while (0)

#define BT_STACK_POP()							      \
  do									      \
    {									      \
      int i;								      \
      assert(stack->prev);						      \
      pos = stack->item.pos;						      \
      str_byte = stack->item.str_byte;					      \
      state = stack->item.state;					      \
      next_c = stack->item.next_c;					      \
      for (i = 0; i < tnfa->num_tags; i++)				      \
	tags[i] = stack->item.tags[i];					      \
      BT_STACK_MBSTATE_OUT;						      \
      stack = stack->prev;						      \
    }									      \
  while (0)

#undef MIN
#define MIN(a, b) ((a) <= (b) ? (a) : (b))

static reg_errcode_t
tre_tnfa_run_backtrack(const tre_tnfa_t *tnfa, const void *string,
		       regoff_t *match_tags, int eflags, regoff_t *match_end_ofs)
{
  /* State variables required by GET_NEXT_WCHAR. */
  tre_char_t prev_c = 0, next_c = 0;
  const char *str_byte = string;
  regoff_t pos = 0;
  regoff_t pos_add_next = 1;
#ifdef TRE_MBSTATE
  mbstate_t mbstate;
#endif /* TRE_MBSTATE */
  int reg_notbol = eflags & REG_NOTBOL;
  int reg_noteol = eflags & REG_NOTEOL;
  int reg_newline = tnfa->cflags & REG_NEWLINE;

  /* These are used to remember the necessary values of the above
     variables to return to the position where the current search
     started from. */
  int next_c_start;
  const char *str_byte_start;
  regoff_t pos_start = -1;
#ifdef TRE_MBSTATE
  mbstate_t mbstate_start;
#endif /* TRE_MBSTATE */

  /* End offset of best match so far, or -1 if no match found yet. */
  regoff_t match_eo = -1;
  /* Tag arrays. */
  int *next_tags;
  regoff_t *tags = NULL;
  /* Current TNFA state. */
  tre_tnfa_transition_t *state;
  int *states_seen = NULL;

  /* Memory allocator to for allocating the backtracking stack. */
  tre_mem_t mem = tre_bt_mem_new();

  /* The backtracking stack. */
  tre_backtrack_t stack;

  tre_tnfa_transition_t *trans_i;
  regmatch_t *pmatch = NULL;
  int ret;

#ifdef TRE_MBSTATE
  memset(&mbstate, '\0', sizeof(mbstate));
#endif /* TRE_MBSTATE */

  if (!mem)
    return REG_ESPACE;
  stack = tre_bt_mem_alloc(mem, sizeof(*stack));
  if (!stack)
    {
      ret = REG_ESPACE;
      goto error_exit;
    }
  stack->prev = NULL;
  stack->next = NULL;

  if (tnfa->num_tags)
    {
      tags = xmalloc(sizeof(*tags) * tnfa->num_tags);
      if (!tags)
	{
	  ret = REG_ESPACE;
	  goto error_exit;
	}
    }
  if (tnfa->num_submatches)
    {
      pmatch = xmalloc(sizeof(*pmatch) * tnfa->num_submatches);
      if (!pmatch)
	{
	  ret = REG_ESPACE;
	  goto error_exit;
	}
    }
  if (tnfa->num_states)
    {
      states_seen = xmalloc(sizeof(*states_seen) * tnfa->num_states);
      if (!states_seen)
	{
	  ret = REG_ESPACE;
	  goto error_exit;
	}
    }

 retry:
  {
    int i;
    for (i = 0; i < tnfa->num_tags; i++)
      {
	tags[i] = -1;
	if (match_tags)
	  match_tags[i] = -1;
      }
    for (i = 0; i < tnfa->num_states; i++)
      states_seen[i] = 0;
  }

  state = NULL;
  pos = pos_start;
  GET_NEXT_WCHAR();
  pos_start = pos;
  next_c_start = next_c;
  str_byte_start = str_byte;
#ifdef TRE_MBSTATE
  mbstate_start = mbstate;
#endif /* TRE_MBSTATE */

  /* Handle initial states. */
  next_tags = NULL;
  for (trans_i = tnfa->initial; trans_i->state; trans_i++)
    {
      if (trans_i->assertions && CHECK_ASSERTIONS(trans_i->assertions))
	{
	  continue;
	}
      if (state == NULL)
	{
	  /* Start from this state. */
	  state = trans_i->state;
	  next_tags = trans_i->tags;
	}
      else
	{
	  /* Backtrack to this state. */
	  BT_STACK_PUSH(pos, str_byte, 0, trans_i->state,
			trans_i->state_id, next_c, tags, mbstate);
	  {
	    int *tmp = trans_i->tags;
	    if (tmp)
	      while (*tmp >= 0)
		stack->item.tags[*tmp++] = pos;
	  }
	}
    }

  if (next_tags)
    for (; *next_tags >= 0; next_tags++)
      tags[*next_tags] = pos;


  if (state == NULL)
    goto backtrack;

  while (1)
    {
      tre_tnfa_transition_t *next_state;
      int empty_br_match;

      if (state == tnfa->final)
	{
	  if (match_eo < pos
	      || (match_eo == pos
		  && match_tags
		  && tre_tag_order(tnfa->num_tags, tnfa->tag_directions,
				   tags, match_tags)))
	    {
	      int i;
	      /* This match wins the previous match. */
	      match_eo = pos;
	      if (match_tags)
		for (i = 0; i < tnfa->num_tags; i++)
		  match_tags[i] = tags[i];
	    }
	  /* Our TNFAs never have transitions leaving from the final state,
	     so we jump right to backtracking. */
	  goto backtrack;
	}

      /* Go to the next character in the input string. */
      empty_br_match = 0;
      trans_i = state;
      if (trans_i->state && trans_i->assertions & ASSERT_BACKREF)
	{
	  /* This is a back reference state.  All transitions leaving from
	     this state have the same back reference "assertion".  Instead
	     of reading the next character, we match the back reference. */
	  regoff_t so, eo;
	  int bt = trans_i->u.backref;
	  regoff_t bt_len;
	  int result;

	  /* Get the substring we need to match against.  Remember to
	     turn off REG_NOSUB temporarily. */
	  tre_fill_pmatch(bt + 1, pmatch, tnfa->cflags & ~REG_NOSUB,
			  tnfa, tags, pos);
	  so = pmatch[bt].rm_so;
	  eo = pmatch[bt].rm_eo;
	  bt_len = eo - so;

	  result = strncmp((const char*)string + so, str_byte - 1,
				 (size_t)bt_len);

	  if (result == 0)
	    {
	      /* Back reference matched.  Check for infinite loop. */
	      if (bt_len == 0)
		empty_br_match = 1;
	      if (empty_br_match && states_seen[trans_i->state_id])
		{
		  goto backtrack;
		}

	      states_seen[trans_i->state_id] = empty_br_match;

	      /* Advance in input string and resync `prev_c', `next_c'
		 and pos. */
	      str_byte += bt_len - 1;
	      pos += bt_len - 1;
	      GET_NEXT_WCHAR();
	    }
	  else
	    {
	      goto backtrack;
	    }
	}
      else
	{
	  /* Check for end of string. */
	  if (next_c == L'\0')
		goto backtrack;

	  /* Read the next character. */
	  GET_NEXT_WCHAR();
	}

      next_state = NULL;
      for (trans_i = state; trans_i->state; trans_i++)
	{
	  if (trans_i->code_min <= (tre_cint_t)prev_c
	      && trans_i->code_max >= (tre_cint_t)prev_c)
	    {
	      if (trans_i->assertions
		  && (CHECK_ASSERTIONS(trans_i->assertions)
		      || CHECK_CHAR_CLASSES(trans_i, tnfa, eflags)))
		{
		  continue;
		}

	      if (next_state == NULL)
		{
		  /* First matching transition. */
		  next_state = trans_i->state;
		  next_tags = trans_i->tags;
		}
	      else
		{
		  /* Second matching transition.  We may need to backtrack here
		     to take this transition instead of the first one, so we
		     push this transition in the backtracking stack so we can
		     jump back here if needed. */
		  BT_STACK_PUSH(pos, str_byte, 0, trans_i->state,
				trans_i->state_id, next_c, tags, mbstate);
		  {
		    int *tmp;
		    for (tmp = trans_i->tags; tmp && *tmp >= 0; tmp++)
		      stack->item.tags[*tmp] = pos;
		  }
#if 0 /* XXX - it's important not to look at all transitions here to keep
	 the stack small! */
		  break;
#endif
		}
	    }
	}

      if (next_state != NULL)
	{
	  /* Matching transitions were found.  Take the first one. */
	  state = next_state;

	  /* Update the tag values. */
	  if (next_tags)
	    while (*next_tags >= 0)
	      tags[*next_tags++] = pos;
	}
      else
	{
	backtrack:
	  /* A matching transition was not found.  Try to backtrack. */
	  if (stack->prev)
	    {
	      if (stack->item.state->assertions & ASSERT_BACKREF)
		{
		  states_seen[stack->item.state_id] = 0;
		}

	      BT_STACK_POP();
	    }
	  else if (match_eo < 0)
	    {
	      /* Try starting from a later position in the input string. */
	      /* Check for end of string. */
	      if (next_c == L'\0')
		    {
		      break;
		    }
	      next_c = next_c_start;
#ifdef TRE_MBSTATE
	      mbstate = mbstate_start;
#endif /* TRE_MBSTATE */
	      str_byte = str_byte_start;
	      goto retry;
	    }
	  else
	    {
	      break;
	    }
	}
    }

  ret = match_eo >= 0 ? REG_OK : REG_NOMATCH;
  *match_end_ofs = match_eo;

 error_exit:
  tre_bt_mem_destroy(mem);
#ifndef TRE_USE_ALLOCA
  if (tags)
    xfree(tags);
  if (pmatch)
    xfree(pmatch);
  if (states_seen)
    xfree(states_seen);
#endif /* !TRE_USE_ALLOCA */

  return ret;
}

/***********************************************************************
 from regexec.c
***********************************************************************/

/* Fills the POSIX.2 regmatch_t array according to the TNFA tag and match
   endpoint values. */
static void
tre_fill_pmatch(size_t nmatch, regmatch_t pmatch[], int cflags,
		const tre_tnfa_t *tnfa, regoff_t *tags, regoff_t match_eo)
{
  tre_submatch_data_t *submatch_data;
  unsigned int i, j;
  int *parents;

  i = 0;
  if (match_eo >= 0 && !(cflags & REG_NOSUB))
    {
      /* Construct submatch offsets from the tags. */
      submatch_data = tnfa->submatch_data;
      while (i < tnfa->num_submatches && i < nmatch)
	{
	  if (submatch_data[i].so_tag == tnfa->end_tag)
	    pmatch[i].rm_so = match_eo;
	  else
	    pmatch[i].rm_so = tags[submatch_data[i].so_tag];

	  if (submatch_data[i].eo_tag == tnfa->end_tag)
	    pmatch[i].rm_eo = match_eo;
	  else
	    pmatch[i].rm_eo = tags[submatch_data[i].eo_tag];

	  /* If either of the endpoints were not used, this submatch
	     was not part of the match. */
	  if (pmatch[i].rm_so == -1 || pmatch[i].rm_eo == -1)
	    pmatch[i].rm_so = pmatch[i].rm_eo = -1;

	  i++;
	}
      /* Reset all submatches that are not within all of their parent
	 submatches. */
      i = 0;
      while (i < tnfa->num_submatches && i < nmatch)
	{
	  if (pmatch[i].rm_eo == -1)
	    assert(pmatch[i].rm_so == -1);
	  assert(pmatch[i].rm_so <= pmatch[i].rm_eo);

	  parents = submatch_data[i].parents;
	  if (parents != NULL)
	    for (j = 0; parents[j] >= 0; j++)
	      {
		if (pmatch[i].rm_so < pmatch[parents[j]].rm_so
		    || pmatch[i].rm_eo > pmatch[parents[j]].rm_eo)
		  pmatch[i].rm_so = pmatch[i].rm_eo = -1;
	      }
	  i++;
	}
    }

  while (i < nmatch)
    {
      pmatch[i].rm_so = -1;
      pmatch[i].rm_eo = -1;
      i++;
    }
}


/*
  Wrapper functions for POSIX compatible regexp matching.
*/

int
regexec(const regex_t *restrict preg, const char *restrict string,
	  size_t nmatch, regmatch_t pmatch[restrict], int eflags)
{
  tre_tnfa_t *tnfa = (void *)preg->TRE_REGEX_T_FIELD;
  reg_errcode_t status;
  regoff_t *tags = NULL, eo;
  if (tnfa->cflags & REG_NOSUB) nmatch = 0;
  if (tnfa->num_tags > 0 && nmatch > 0)
    {
      tags = xmalloc(sizeof(*tags) * tnfa->num_tags);
      if (tags == NULL)
	return REG_ESPACE;
    }

  /* Dispatch to the appropriate matcher. */
  if (tnfa->have_backrefs)
    {
      /* The regex has back references, use the backtracking matcher. */
      status = tre_tnfa_run_backtrack(tnfa, string, tags, eflags, &eo);
    }
  else
    {
      /* Exact matching, no back references, use the parallel matcher. */
      status = tre_tnfa_run_parallel(tnfa, string, tags, eflags, &eo);
    }

  if (status == REG_OK)
    /* A match was found, so fill the submatch registers. */
    tre_fill_pmatch(nmatch, pmatch, tnfa->cflags, tnfa, tags, eo);
  if (tags)
    xfree(tags);
  return status;
}
