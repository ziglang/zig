#include <string.h>
#include <regex.h>
#include <stdio.h>
#include "locale_impl.h"

/* Error message strings for error codes listed in `regex.h'.  This list
   needs to be in sync with the codes listed there, naturally. */

/* Converted to single string by Rich Felker to remove the need for
 * data relocations at runtime, 27 Feb 2006. */

static const char messages[] = {
  "No error\0"
  "No match\0"
  "Invalid regexp\0"
  "Unknown collating element\0"
  "Unknown character class name\0"
  "Trailing backslash\0"
  "Invalid back reference\0"
  "Missing ']'\0"
  "Missing ')'\0"
  "Missing '}'\0"
  "Invalid contents of {}\0"
  "Invalid character range\0"
  "Out of memory\0"
  "Repetition not preceded by valid expression\0"
  "\0Unknown error"
};

size_t regerror(int e, const regex_t *restrict preg, char *restrict buf, size_t size)
{
	const char *s;
	for (s=messages; e && *s; e--, s+=strlen(s)+1);
	if (!*s) s++;
	s = LCTRANS_CUR(s);
	return 1+snprintf(buf, size, "%s", s);
}
