// This header file is meant to be included withinin the body of a function
// which uses `__environ`. Code using `__environ` expects it will be initialized
// eagerly. `__wasilibc_environ` is initialized lazily. Provide `__environ` as
// an alias and arrange for the lazy initialization to be performed.

extern char **__wasilibc_environ;

__wasilibc_ensure_environ();

#ifndef __wasilibc_environ
#define __environ __wasilibc_environ
#endif
