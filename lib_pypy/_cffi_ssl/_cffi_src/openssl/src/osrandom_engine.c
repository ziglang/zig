/* osurandom engine
 *
 * Windows         CryptGenRandom()
 * macOS >= 10.12  getentropy()
 * OpenBSD 5.6+    getentropy()
 * other BSD       getentropy() if SYS_getentropy is defined
 * Linux 3.17+     getrandom() with fallback to /dev/urandom
 * other           /dev/urandom with cached fd
 *
 * The /dev/urandom, getrandom and getentropy code is derived from Python's
 * Python/random.c, written by Antoine Pitrou and Victor Stinner.
 *
 * Copyright 2001-2016 Python Software Foundation; All Rights Reserved.
 */

#ifdef __linux__
#include <poll.h>
#endif

#if CRYPTOGRAPHY_NEEDS_OSRANDOM_ENGINE
/* OpenSSL has ENGINE support and is older than 1.1.1d (the first version that
 * properly implements fork safety in its RNG) so build the engine. */
static const char *Cryptography_osrandom_engine_id = "osrandom";

/****************************************************************************
 * Windows
 */
#if CRYPTOGRAPHY_OSRANDOM_ENGINE == CRYPTOGRAPHY_OSRANDOM_ENGINE_CRYPTGENRANDOM
static const char *Cryptography_osrandom_engine_name = "osrandom_engine CryptGenRandom()";
static HCRYPTPROV hCryptProv = 0;

static int osrandom_init(ENGINE *e) {
    if (hCryptProv != 0) {
        return 1;
    }
    if (CryptAcquireContext(&hCryptProv, NULL, NULL,
                            PROV_RSA_FULL, CRYPT_VERIFYCONTEXT)) {
        return 1;
    } else {
        ERR_Cryptography_OSRandom_error(
            CRYPTOGRAPHY_OSRANDOM_F_INIT,
            CRYPTOGRAPHY_OSRANDOM_R_CRYPTACQUIRECONTEXT,
            __FILE__, __LINE__
        );
        return 0;
    }
}

static int osrandom_rand_bytes(unsigned char *buffer, int size) {
    if (hCryptProv == 0) {
        return 0;
    }

    if (!CryptGenRandom(hCryptProv, (DWORD)size, buffer)) {
        ERR_Cryptography_OSRandom_error(
            CRYPTOGRAPHY_OSRANDOM_F_RAND_BYTES,
            CRYPTOGRAPHY_OSRANDOM_R_CRYPTGENRANDOM,
            __FILE__, __LINE__
        );
        return 0;
    }
    return 1;
}

static int osrandom_finish(ENGINE *e) {
    if (CryptReleaseContext(hCryptProv, 0)) {
        hCryptProv = 0;
        return 1;
    } else {
        ERR_Cryptography_OSRandom_error(
            CRYPTOGRAPHY_OSRANDOM_F_FINISH,
            CRYPTOGRAPHY_OSRANDOM_R_CRYPTRELEASECONTEXT,
            __FILE__, __LINE__
        );
        return 0;
    }
}

static int osrandom_rand_status(void) {
    return hCryptProv != 0;
}

static const char *osurandom_get_implementation(void) {
    return "CryptGenRandom";
}

#endif /* CRYPTOGRAPHY_OSRANDOM_ENGINE_CRYPTGENRANDOM */

/****************************************************************************
 * /dev/urandom helpers for all non-BSD Unix platforms
 */
#ifdef CRYPTOGRAPHY_OSRANDOM_NEEDS_DEV_URANDOM

static struct {
    int fd;
    dev_t st_dev;
    ino_t st_ino;
} urandom_cache = { -1 };

static int open_cloexec(const char *path) {
    int open_flags = O_RDONLY;
#ifdef O_CLOEXEC
    open_flags |= O_CLOEXEC;
#endif

    int fd = open(path, open_flags);
    if (fd == -1) {
        return -1;
    }

#ifndef O_CLOEXEC
    int flags = fcntl(fd, F_GETFD);
    if (flags == -1) {
        return -1;
    }
    if (fcntl(fd, F_SETFD, flags | FD_CLOEXEC) == -1) {
        return -1;
    }
#endif
    return fd;
}

#ifdef __linux__
/* On Linux, we open("/dev/random") and use poll() to wait until it's readable
 * before we read from /dev/urandom, this ensures that we don't read from
 * /dev/urandom before the kernel CSPRNG is initialized. This isn't necessary on
 * other platforms because they don't have the same _bug_ as Linux does with
 * /dev/urandom and early boot. */
static int wait_on_devrandom(void) {
    struct pollfd pfd = {};
    int ret = 0;
    int random_fd = open_cloexec("/dev/random");
    if (random_fd < 0) {
        return -1;
    }
    pfd.fd = random_fd;
    pfd.events = POLLIN;
    pfd.revents = 0;
    do {
        ret = poll(&pfd, 1, -1);
    } while (ret < 0 && (errno == EINTR || errno == EAGAIN));
    close(random_fd);
    return ret;
}
#endif

/* return -1 on error */
static int dev_urandom_fd(void) {
    int fd = -1;
    struct stat st;

    /* Check that fd still points to the correct device */
    if (urandom_cache.fd >= 0) {
        if (fstat(urandom_cache.fd, &st)
                || st.st_dev != urandom_cache.st_dev
                || st.st_ino != urandom_cache.st_ino) {
            /* Somebody replaced our FD. Invalidate our cache but don't
             * close the fd. */
            urandom_cache.fd = -1;
        }
    }
    if (urandom_cache.fd < 0) {
#ifdef __linux__
        if (wait_on_devrandom() < 0) {
            goto error;
        }
#endif

        fd = open_cloexec("/dev/urandom");
        if (fd < 0) {
            goto error;
        }
        if (fstat(fd, &st)) {
            goto error;
        }
        /* Another thread initialized the fd */
        if (urandom_cache.fd >= 0) {
            close(fd);
            return urandom_cache.fd;
        }
        urandom_cache.st_dev = st.st_dev;
        urandom_cache.st_ino = st.st_ino;
        urandom_cache.fd = fd;
    }
    return urandom_cache.fd;

  error:
    if (fd != -1) {
        close(fd);
    }
    ERR_Cryptography_OSRandom_error(
        CRYPTOGRAPHY_OSRANDOM_F_DEV_URANDOM_FD,
        CRYPTOGRAPHY_OSRANDOM_R_DEV_URANDOM_OPEN_FAILED,
        __FILE__, __LINE__
    );
    return -1;
}

static int dev_urandom_read(unsigned char *buffer, int size) {
    int fd;
    int n;

    fd = dev_urandom_fd();
    if (fd < 0) {
        return 0;
    }

    while (size > 0) {
        do {
            n = (int)read(fd, buffer, (size_t)size);
        } while (n < 0 && errno == EINTR);

        if (n <= 0) {
            ERR_Cryptography_OSRandom_error(
                CRYPTOGRAPHY_OSRANDOM_F_DEV_URANDOM_READ,
                CRYPTOGRAPHY_OSRANDOM_R_DEV_URANDOM_READ_FAILED,
                __FILE__, __LINE__
            );
            return 0;
        }
        buffer += n;
        size -= n;
    }
    return 1;
}

static void dev_urandom_close(void) {
    if (urandom_cache.fd >= 0) {
        int fd;
        struct stat st;

        if (fstat(urandom_cache.fd, &st)
                && st.st_dev == urandom_cache.st_dev
                && st.st_ino == urandom_cache.st_ino) {
            fd = urandom_cache.fd;
            urandom_cache.fd = -1;
            close(fd);
        }
    }
}
#endif /* CRYPTOGRAPHY_OSRANDOM_NEEDS_DEV_URANDOM */

/****************************************************************************
 * BSD getentropy
 */
#if CRYPTOGRAPHY_OSRANDOM_ENGINE == CRYPTOGRAPHY_OSRANDOM_ENGINE_GETENTROPY
static const char *Cryptography_osrandom_engine_name = "osrandom_engine getentropy()";

static int getentropy_works = CRYPTOGRAPHY_OSRANDOM_GETENTROPY_NOT_INIT;

static int osrandom_init(ENGINE *e) {
#if !defined(__APPLE__)
    getentropy_works = CRYPTOGRAPHY_OSRANDOM_GETENTROPY_WORKS;
#else
    if (__builtin_available(macOS 10.12, *)) {
        getentropy_works = CRYPTOGRAPHY_OSRANDOM_GETENTROPY_WORKS;
    } else {
        getentropy_works = CRYPTOGRAPHY_OSRANDOM_GETENTROPY_FALLBACK;
        int fd = dev_urandom_fd();
        if (fd < 0) {
            return 0;
        }
    }
#endif
    return 1;
}

static int osrandom_rand_bytes(unsigned char *buffer, int size) {
    int len;
    int res;

    switch(getentropy_works) {
#if defined(__APPLE__)
    case CRYPTOGRAPHY_OSRANDOM_GETENTROPY_FALLBACK:
        return dev_urandom_read(buffer, size);
#endif
    case CRYPTOGRAPHY_OSRANDOM_GETENTROPY_WORKS:
        while (size > 0) {
            /* OpenBSD and macOS restrict maximum buffer size to 256. */
            len = size > 256 ? 256 : size;
/* on mac, availability is already checked using `__builtin_available` above */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
            res = getentropy(buffer, (size_t)len);
#pragma clang diagnostic pop
            if (res < 0) {
                ERR_Cryptography_OSRandom_error(
                    CRYPTOGRAPHY_OSRANDOM_F_RAND_BYTES,
                    CRYPTOGRAPHY_OSRANDOM_R_GETENTROPY_FAILED,
                    __FILE__, __LINE__
                );
                return 0;
            }
            buffer += len;
            size -= len;
        }
        return 1;
    }
    __builtin_unreachable();
}

static int osrandom_finish(ENGINE *e) {
    return 1;
}

static int osrandom_rand_status(void) {
    return 1;
}

static const char *osurandom_get_implementation(void) {
    switch(getentropy_works) {
    case CRYPTOGRAPHY_OSRANDOM_GETENTROPY_FALLBACK:
        return "/dev/urandom";
    case CRYPTOGRAPHY_OSRANDOM_GETENTROPY_WORKS:
        return "getentropy";
    }
    __builtin_unreachable();
}
#endif /* CRYPTOGRAPHY_OSRANDOM_ENGINE_GETENTROPY */

/****************************************************************************
 * Linux getrandom engine with fallback to dev_urandom
 */

#if CRYPTOGRAPHY_OSRANDOM_ENGINE == CRYPTOGRAPHY_OSRANDOM_ENGINE_GETRANDOM
static const char *Cryptography_osrandom_engine_name = "osrandom_engine getrandom()";

static int getrandom_works = CRYPTOGRAPHY_OSRANDOM_GETRANDOM_NOT_INIT;

static int osrandom_init(ENGINE *e) {
    /* We try to detect working getrandom until we succeed. */
    if (getrandom_works != CRYPTOGRAPHY_OSRANDOM_GETRANDOM_WORKS) {
        long n;
        char dest[1];
        /* if the kernel CSPRNG is not initialized this will block */
        n = syscall(SYS_getrandom, dest, sizeof(dest), 0);
        if (n == sizeof(dest)) {
            getrandom_works = CRYPTOGRAPHY_OSRANDOM_GETRANDOM_WORKS;
        } else {
            int e = errno;
            switch(e) {
            case ENOSYS:
                /* Fallback: Kernel does not support the syscall. */
                getrandom_works = CRYPTOGRAPHY_OSRANDOM_GETRANDOM_FALLBACK;
                break;
            case EPERM:
                /* Fallback: seccomp prevents syscall */
                getrandom_works = CRYPTOGRAPHY_OSRANDOM_GETRANDOM_FALLBACK;
                break;
            default:
                /* EINTR cannot occur for buflen < 256. */
                ERR_Cryptography_OSRandom_error(
                    CRYPTOGRAPHY_OSRANDOM_F_INIT,
                    CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_INIT_FAILED_UNEXPECTED,
                    "errno", e
                );
                getrandom_works = CRYPTOGRAPHY_OSRANDOM_GETRANDOM_INIT_FAILED;
                break;
            }
        }
    }

    /* fallback to dev urandom */
    if (getrandom_works == CRYPTOGRAPHY_OSRANDOM_GETRANDOM_FALLBACK) {
        int fd = dev_urandom_fd();
        if (fd < 0) {
            return 0;
        }
    }
    return 1;
}

static int osrandom_rand_bytes(unsigned char *buffer, int size) {
    long n;

    switch(getrandom_works) {
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_INIT_FAILED:
        ERR_Cryptography_OSRandom_error(
            CRYPTOGRAPHY_OSRANDOM_F_RAND_BYTES,
            CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_INIT_FAILED,
            __FILE__, __LINE__
        );
        return 0;
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_NOT_INIT:
        ERR_Cryptography_OSRandom_error(
            CRYPTOGRAPHY_OSRANDOM_F_RAND_BYTES,
            CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_NOT_INIT,
            __FILE__, __LINE__
        );
        return 0;
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_FALLBACK:
        return dev_urandom_read(buffer, size);
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_WORKS:
        while (size > 0) {
            do {
                n = syscall(SYS_getrandom, buffer, size, 0);
            } while (n < 0 && errno == EINTR);

            if (n <= 0) {
                ERR_Cryptography_OSRandom_error(
                    CRYPTOGRAPHY_OSRANDOM_F_RAND_BYTES,
                    CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_FAILED,
                    __FILE__, __LINE__
                );
                return 0;
            }
            buffer += n;
            size -= (int)n;
        }
        return 1;
    }
    __builtin_unreachable();
}

static int osrandom_finish(ENGINE *e) {
    dev_urandom_close();
    return 1;
}

static int osrandom_rand_status(void) {
    switch(getrandom_works) {
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_INIT_FAILED:
        return 0;
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_NOT_INIT:
        return 0;
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_FALLBACK:
        return urandom_cache.fd >= 0;
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_WORKS:
        return 1;
    }
    __builtin_unreachable();
}

static const char *osurandom_get_implementation(void) {
    switch(getrandom_works) {
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_INIT_FAILED:
        return "<failed>";
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_NOT_INIT:
        return "<not initialized>";
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_FALLBACK:
        return "/dev/urandom";
    case CRYPTOGRAPHY_OSRANDOM_GETRANDOM_WORKS:
        return "getrandom";
    }
    __builtin_unreachable();
}
#endif /* CRYPTOGRAPHY_OSRANDOM_ENGINE_GETRANDOM */

/****************************************************************************
 * dev_urandom engine for all remaining platforms
 */

#if CRYPTOGRAPHY_OSRANDOM_ENGINE == CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM
static const char *Cryptography_osrandom_engine_name = "osrandom_engine /dev/urandom";

static int osrandom_init(ENGINE *e) {
    int fd = dev_urandom_fd();
    if (fd < 0) {
        return 0;
    }
    return 1;
}

static int osrandom_rand_bytes(unsigned char *buffer, int size) {
    return dev_urandom_read(buffer, size);
}

static int osrandom_finish(ENGINE *e) {
    dev_urandom_close();
    return 1;
}

static int osrandom_rand_status(void) {
    return urandom_cache.fd >= 0;
}

static const char *osurandom_get_implementation(void) {
    return "/dev/urandom";
}
#endif /* CRYPTOGRAPHY_OSRANDOM_ENGINE_DEV_URANDOM */

/****************************************************************************
 * ENGINE boiler plate
 */

/* This replicates the behavior of the OpenSSL FIPS RNG, which returns a
   -1 in the event that there is an error when calling RAND_pseudo_bytes. */
static int osrandom_pseudo_rand_bytes(unsigned char *buffer, int size) {
    int res = osrandom_rand_bytes(buffer, size);
    if (res == 0) {
        return -1;
    } else {
        return res;
    }
}

static RAND_METHOD osrandom_rand = {
    NULL,
    osrandom_rand_bytes,
    NULL,
    NULL,
    osrandom_pseudo_rand_bytes,
    osrandom_rand_status,
};

static const ENGINE_CMD_DEFN osrandom_cmd_defns[] = {
    {CRYPTOGRAPHY_OSRANDOM_GET_IMPLEMENTATION,
     "get_implementation",
     "Get CPRNG implementation.",
     ENGINE_CMD_FLAG_NO_INPUT},
     {0, NULL, NULL, 0}
};

static int osrandom_ctrl(ENGINE *e, int cmd, long i, void *p, void (*f) (void)) {
    const char *name;
    size_t len;

    switch (cmd) {
    case CRYPTOGRAPHY_OSRANDOM_GET_IMPLEMENTATION:
        /* i: buffer size, p: char* buffer */
        name = osurandom_get_implementation();
        len = strlen(name);
        if ((p == NULL) && (i == 0)) {
            /* return required buffer len */
            return (int)len;
        }
        if ((p == NULL) || i < 0 || ((size_t)i <= len)) {
            /* no buffer or buffer too small */
            ENGINEerr(ENGINE_F_ENGINE_CTRL, ENGINE_R_INVALID_ARGUMENT);
            return 0;
        }
        strcpy((char *)p, name);
        return (int)len;
    default:
        ENGINEerr(ENGINE_F_ENGINE_CTRL, ENGINE_R_CTRL_COMMAND_NOT_IMPLEMENTED);
        return 0;
    }
}

/* error reporting */
#define ERR_FUNC(func) ERR_PACK(0, func, 0)
#define ERR_REASON(reason) ERR_PACK(0, 0, reason)

static ERR_STRING_DATA CRYPTOGRAPHY_OSRANDOM_lib_name[] = {
    {0, "osrandom_engine"},
    {0, NULL}
};

static ERR_STRING_DATA CRYPTOGRAPHY_OSRANDOM_str_funcs[] = {
    {ERR_FUNC(CRYPTOGRAPHY_OSRANDOM_F_INIT),
     "osrandom_init"},
    {ERR_FUNC(CRYPTOGRAPHY_OSRANDOM_F_RAND_BYTES),
     "osrandom_rand_bytes"},
    {ERR_FUNC(CRYPTOGRAPHY_OSRANDOM_F_FINISH),
     "osrandom_finish"},
    {ERR_FUNC(CRYPTOGRAPHY_OSRANDOM_F_DEV_URANDOM_FD),
     "dev_urandom_fd"},
    {ERR_FUNC(CRYPTOGRAPHY_OSRANDOM_F_DEV_URANDOM_READ),
     "dev_urandom_read"},
    {0, NULL}
};

static ERR_STRING_DATA CRYPTOGRAPHY_OSRANDOM_str_reasons[] = {
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_CRYPTACQUIRECONTEXT),
     "CryptAcquireContext() failed."},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_CRYPTGENRANDOM),
     "CryptGenRandom() failed."},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_CRYPTRELEASECONTEXT),
     "CryptReleaseContext() failed."},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_GETENTROPY_FAILED),
     "getentropy() failed"},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_DEV_URANDOM_OPEN_FAILED),
     "open('/dev/urandom') failed."},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_DEV_URANDOM_READ_FAILED),
     "Reading from /dev/urandom fd failed."},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_INIT_FAILED),
     "getrandom() initialization failed."},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_INIT_FAILED_UNEXPECTED),
     "getrandom() initialization failed with unexpected errno."},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_FAILED),
     "getrandom() syscall failed."},
    {ERR_REASON(CRYPTOGRAPHY_OSRANDOM_R_GETRANDOM_NOT_INIT),
     "getrandom() engine was not properly initialized."},
    {0, NULL}
};

static int Cryptography_OSRandom_lib_error_code = 0;

static void ERR_load_Cryptography_OSRandom_strings(void)
{
    if (Cryptography_OSRandom_lib_error_code == 0) {
        Cryptography_OSRandom_lib_error_code = ERR_get_next_error_library();
        ERR_load_strings(Cryptography_OSRandom_lib_error_code,
                         CRYPTOGRAPHY_OSRANDOM_lib_name);
        ERR_load_strings(Cryptography_OSRandom_lib_error_code,
                         CRYPTOGRAPHY_OSRANDOM_str_funcs);
        ERR_load_strings(Cryptography_OSRandom_lib_error_code,
                         CRYPTOGRAPHY_OSRANDOM_str_reasons);
    }
}

static void ERR_Cryptography_OSRandom_error(int function, int reason,
                                            char *file, int line)
{
    ERR_PUT_error(Cryptography_OSRandom_lib_error_code, function, reason,
                  file, line);
}

/* Returns 1 if successfully added, 2 if engine has previously been added,
   and 0 for error. */
int Cryptography_add_osrandom_engine(void) {
    ENGINE *e;

    ERR_load_Cryptography_OSRandom_strings();

    e = ENGINE_by_id(Cryptography_osrandom_engine_id);
    if (e != NULL) {
        ENGINE_free(e);
        return 2;
    } else {
        ERR_clear_error();
    }

    e = ENGINE_new();
    if (e == NULL) {
        return 0;
    }
    if (!ENGINE_set_id(e, Cryptography_osrandom_engine_id) ||
            !ENGINE_set_name(e, Cryptography_osrandom_engine_name) ||
            !ENGINE_set_RAND(e, &osrandom_rand) ||
            !ENGINE_set_init_function(e, osrandom_init) ||
            !ENGINE_set_finish_function(e, osrandom_finish) ||
            !ENGINE_set_cmd_defns(e, osrandom_cmd_defns) ||
            !ENGINE_set_ctrl_function(e, osrandom_ctrl)) {
        ENGINE_free(e);
        return 0;
    }
    if (!ENGINE_add(e)) {
        ENGINE_free(e);
        return 0;
    }
    if (!ENGINE_free(e)) {
        return 0;
    }

    return 1;
}

#else
/* If OpenSSL has no ENGINE support then we don't want
 * to compile the osrandom engine, but we do need some
 * placeholders */
static const char *Cryptography_osrandom_engine_id = "no-engine-support";
static const char *Cryptography_osrandom_engine_name = "osrandom_engine disabled";

int Cryptography_add_osrandom_engine(void) {
    return 0;
}

#endif
