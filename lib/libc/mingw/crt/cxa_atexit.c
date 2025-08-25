/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

typedef void (__thiscall * dtor_fn)(void*);
int __cxa_atexit(dtor_fn dtor, void *obj, void *dso);
int __mingw_cxa_atexit(dtor_fn dtor, void *obj, void *dso);

int __cxa_atexit(dtor_fn dtor, void *obj, void *dso) {
  return __mingw_cxa_atexit(dtor, obj, dso);
}
