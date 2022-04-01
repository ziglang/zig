#pragma once

#include "vmprof.h"

#ifndef RPYTHON_VMPROF
#  if PY_MAJOR_VERSION >= 3
      #define PyStr_AS_STRING PyBytes_AS_STRING
      #define PyStr_GET_SIZE PyBytes_GET_SIZE
      #define PyStr_NEW      PyUnicode_FromString
      #define PyStr_n_NEW      PyUnicode_FromStringAndSize
      #define PyLong_NEW     PyLong_FromSsize_t
#  else
      #define PyStr_AS_STRING PyString_AS_STRING
      #define PyStr_GET_SIZE PyString_GET_SIZE
      #define PyStr_NEW      PyString_FromString
      #define PyStr_n_NEW      PyString_FromStringAndSize
      #define PyLong_NEW     PyInt_FromSsize_t
      #define PyLong_AsLong  PyInt_AsLong
#  endif
#endif

int vmp_write_all(const char *buf, size_t bufsize);
int vmp_write_time_now(int marker);
int vmp_write_meta(const char * key, const char * value);

int vmp_profile_fileno(void);
void vmp_set_profile_fileno(int fileno);
