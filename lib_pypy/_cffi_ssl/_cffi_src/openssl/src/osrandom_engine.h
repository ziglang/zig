#ifndef OPENSSL_NO_ENGINE
/* OpenSSL has ENGINE support so include all of this. */
#ifdef _WIN32
  #include <Wincrypt.h>
#else
  #include <fcntl.h>
  #include <unistd.h>
   /* for defined(BSD) */
  #include <sys/param.h>

  #ifdef BSD
    /* for SYS_getentropy */
    #include <sys/syscall.h>
  #endif

  #ifdef __APPLE__
    #include <sys/random.h>
    /* To support weak linking we need to declare this as a weak import even if
     * it's not present in sys/random (e.g. macOS < 10.12). */
    extern int getentropy(void *buffer, size_t size) __attribute((weak_import));
  #endif

  #ifdef __linux__
    /* for SYS_getrandom */
    #include <sys/syscall.h>
    #ifndef GRND_NONBLOCK
      #define GRND_NONBLOCK 0x0001
    #endif /* GRND_NONBLOCK */

    #ifndef SYS_getrandom
      /* We only bother to define the constants for platforms where we ship
       * wheels, since that's the predominant way you get a situation where
       * you don't have SYS_getrandom at compile time but do have the syscall
       * at runtime */
      #if defined __x86_64__
        #define SYS_getrandom 318
      #elif defined(__i386__)
        #define SYS_getrandom 355
      #endif
    #endif
  #endif /* __linux__ */
#endif /* _WIN32 */

#define CRYPTOGRAPHY_OSRANDOM_ENGINE_CRYPTGENRANDOM 1
#define CRYPTOGRAPHY_OSRANDOM_ENGINE_GETENTROPY 2
#define CRYPTOGRAPHY_OSRANDOM_ENGINE_GETRANDOM 3
#define CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM 4

#ifndef CRYPTOGRAPHY_OSRANDOM_ENGINE
  #if defined(_WIN32)
    /* Windows */
    #define CRYPTOGRAPHY_OSRANDOM_ENGINE CRYPTOGRAPHY_OSRANDOM_ENGINE_CRYPTGENRANDOM
  #elif defined(BSD) && defined(SYS_getentropy)
    /* OpenBSD 5.6+ & macOS with SYS_getentropy defined, although < 10.12 will fallback
     * to urandom */
    #define CRYPTOGRAPHY_OSRANDOM_ENGINE CRYPTOGRAPHY_OSRANDOM_ENGINE_GETENTROPY
  #elif defined(__linux__) && defined(SYS_getrandom)
    /* Linux 3.17+ */
    #define CRYPTOGRAPHY_OSRANDOM_ENGINE CRYPTOGRAPHY_OSRANDOM_ENGINE_GETRANDOM
  #else
    /* Keep this as last entry, fall back to /dev/urandom */
    #define CRYPTOGRAPHY_OSRANDOM_ENGINE CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM
  #endif
#endif /* CRYPTOGRAPHY_OSRANDOM_ENGINE */

/* Fallbacks need /dev/urandom helper functions. */
#if CRYPTOGRAPHY_OSRANDOM_ENGINE == CRYPTOGRAPHY_OSRANDOM_ENGINE_GETRANDOM || \
     CRYPTOGRAPHY_OSRANDOM_ENGINE == CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM || \
     (CRYPTOGRAPHY_OSRANDOM_ENGINE == CRYPTOGRAPHY_OSRANDOM_ENGINE_GETENTROPY && \
     defined(__APPLE__))
  #define CRYPTOGRAPHY_OSRANDOM_NEEDS_DEV_URANDOM 1
#endif

enum {
    CRYPTOGRAPHY_OSRANDOM_GETRANDOM_INIT_FAILED = -2,
    CRYPTOGRAPHY_OSRANDOM_GETRANDOM_NOT_INIT,
    CRYPTOGRAPHY_OSRANDOM_GETRANDOM_FALLBACK,
    CRYPTOGRAPHY_OSRANDOM_GETRANDOM_WORKS
};

enum {
    CRYPTOGRAPHY_OSRANDOM_GETENTROPY_NOT_INIT,
    CRYPTOGRAPHY_OSRANDOM_GETENTROPY_FALLBACK,
    CRYPTOGRAPHY_OSRANDOM_GETENTROPY_WORKS
};

/* engine ctrl */
#define CRYPTOGRAPHY_OSRANDOM_GET_IMPLEMENTATION ENGINE_CMD_BASE

/* error reporting */
static void ERR_load_Cryptography_OSRandom_strings(void);
static void ERR_Cryptography_OSRandom_error(int function, int reason,
                                            char *file, int line);

#define CRYPTOGRAPHY_OSRANDOM_F_INIT 100
#define CRYPTOGRAPHY_OSRANDOM_F_RAND_BYTES 101
#define CRYPTOGRAPHY_OSRANDOM_F_FINISH 102
#define CRYPTOGRAPHY_OSRANDOM_F_DEV_URANDOM_FD 300
#define CRYPTOGRAPHY_OSRANDOM_F_DEV_URANDOM_READ 301

#define CRYPTOGRAPHY_OSRANDOM_R_CRYPTACQUIRECONTEXT 100
#define CRYPTOGRAPHY_OSRANDOM_R_CRYPTGENRANDOM 101
#define CRYPTOGRAPHY_OSRANDOM_R_CRYPTRELEASECONTEXT 102

#define CRYPTOGRAPHY_OSRANDOM_R_GETENTROPY_FAILED 200

#define CRYPTOGRAPHY_OSRANDOM_R_DEV_URANDOM_OPEN_FAILED 300
#define CRYPTOGRAPHY_OSRANDOM_R_DEV_URANDOM_READ_FAILED 301

#define CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_INIT_FAILED 400
#define CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_INIT_FAILED_UNEXPECTED 402
#define CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_FAILED 403
#define CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_NOT_INIT 404
#endif
