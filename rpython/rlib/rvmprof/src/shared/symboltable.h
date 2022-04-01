#pragma once

#define _GNU_SOURCE 1

int vmp_resolve_addr(void * addr, char * name, int name_len, int * lineno,
                      char * srcfile, int srcfile_len);
