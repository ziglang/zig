#ifndef _STDIO_H
#define _STDIO_H

#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>
#include <stdint.h>

#define __NEED_FILE
#define __NEED___isoc_va_list
#define __NEED_size_t

#if __STDC_VERSION__ < 201112L
#define __NEED_struct__IO_FILE
#endif

#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) \
 || defined(_BSD_SOURCE)
#define __NEED_ssize_t
#define __NEED_off_t
#define __NEED_va_list
#endif

#include <bits/alltypes.h>

#ifdef __cplusplus
#define NULL 0L
#else
#define NULL ((void*)0)
#endif

#undef EOF
#define EOF (-1)

#undef SEEK_SET
#undef SEEK_CUR
#undef SEEK_END
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

#define _IOFBF 0
#define _IOLBF 1
#define _IONBF 2

#define BUFSIZ 1024
#define FILENAME_MAX 4096
#define FOPEN_MAX 1000
#define TMP_MAX 10000
#define L_tmpnam 20

typedef union _G_fpos64_t {
	char __opaque[16];
	long long __lldata;
	double __align;
} fpos_t;

extern FILE *const stdin;
extern FILE *const stdout;
extern FILE *const stderr;

#define stdin  (stdin)
#define stdout (stdout)
#define stderr (stderr)

FILE *fopen(const char *__restrict, const char *__restrict);
FILE *freopen(const char *__restrict, const char *__restrict, FILE *__restrict);
int fclose(FILE *);

int remove(const char *);
int rename(const char *, const char *);

int feof(FILE *);
int ferror(FILE *);
int fflush(FILE *);
void clearerr(FILE *);

int fseek(FILE *, long, int);
long ftell(FILE *);
void rewind(FILE *);

int fgetpos(FILE *__restrict, fpos_t *__restrict);
int fsetpos(FILE *, const fpos_t *);

size_t fread(void *__restrict, size_t, size_t, FILE *__restrict);
size_t fwrite(const void *__restrict, size_t, size_t, FILE *__restrict);

int fgetc(FILE *);
int getc(FILE *);
int getchar(void);
int ungetc(int, FILE *);

int fputc(int, FILE *);
int putc(int, FILE *);
int putchar(int);

char *fgets(char *__restrict, int, FILE *__restrict);
#if __STDC_VERSION__ < 201112L
char *gets(char *);
#endif

int fputs(const char *__restrict, FILE *__restrict);
int puts(const char *);

int printf(const char *__restrict, ...);
int fprintf(FILE *__restrict, const char *__restrict, ...);
int sprintf(char *__restrict, const char *__restrict, ...);
int snprintf(char *__restrict, size_t, const char *__restrict, ...);

int vprintf(const char *__restrict, __isoc_va_list);
int vfprintf(FILE *__restrict, const char *__restrict, __isoc_va_list);
int vsprintf(char *__restrict, const char *__restrict, __isoc_va_list);
int vsnprintf(char *__restrict, size_t, const char *__restrict, __isoc_va_list);

int scanf(const char *__restrict, ...);
int fscanf(FILE *__restrict, const char *__restrict, ...);
int sscanf(const char *__restrict, const char *__restrict, ...);
int vscanf(const char *__restrict, __isoc_va_list);
int vfscanf(FILE *__restrict, const char *__restrict, __isoc_va_list);
int vsscanf(const char *__restrict, const char *__restrict, __isoc_va_list);

void perror(const char *);

int setvbuf(FILE *__restrict, char *__restrict, int, size_t);
void setbuf(FILE *__restrict, char *__restrict);

char *tmpnam(char *);
FILE *tmpfile(void);

#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) \
 || defined(_BSD_SOURCE)
FILE *fmemopen(void *__restrict, size_t, const char *__restrict);
FILE *open_memstream(char **, size_t *);
FILE *fdopen(int, const char *);
FILE *popen(const char *, const char *);
int pclose(FILE *);
int fileno(FILE *);
int fseeko(FILE *, off_t, int);
off_t ftello(FILE *);
int dprintf(int, const char *__restrict, ...);
int vdprintf(int, const char *__restrict, __isoc_va_list);
void flockfile(FILE *);
int ftrylockfile(FILE *);
void funlockfile(FILE *);
int getc_unlocked(FILE *);
int getchar_unlocked(void);
int putc_unlocked(int, FILE *);
int putchar_unlocked(int);
ssize_t getdelim(char **__restrict, size_t *__restrict, int, FILE *__restrict);
ssize_t getline(char **__restrict, size_t *__restrict, FILE *__restrict);
int renameat(int, const char *, int, const char *);
#define RENAME_NOREPLACE (1 << 0)
#define RENAME_EXCHANGE  (1 << 1)
#define RENAME_WHITEOUT  (1 << 2)
int renameat2(int, const char *, int, const char *, unsigned int);
char *ctermid(char *);
#define L_ctermid 20
#endif


#if defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) \
 || defined(_BSD_SOURCE)
#define P_tmpdir "/tmp"
char *tempnam(const char *, const char *);
#endif

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define L_cuserid 20
void setlinebuf(FILE *);
void setbuffer(FILE *, char *, size_t);
int fgetc_unlocked(FILE *);
int fputc_unlocked(int, FILE *);
int fflush_unlocked(FILE *);
size_t fread_unlocked(void *, size_t, size_t, FILE *);
size_t fwrite_unlocked(const void *, size_t, size_t, FILE *);
void clearerr_unlocked(FILE *);
int feof_unlocked(FILE *);
int ferror_unlocked(FILE *);
int fileno_unlocked(FILE *);
int putw(int, FILE *);
char *fgetln(FILE *, size_t *);
int asprintf(char **, const char *, ...);
int vasprintf(char **, const char *, __isoc_va_list);
#endif

#ifdef _GNU_SOURCE
char *fgets_unlocked(char *, int, FILE *);
int fputs_unlocked(const char *, FILE *);

typedef ssize_t (cookie_read_function_t)(void *, char *, size_t);
typedef ssize_t (cookie_write_function_t)(void *, const char *, size_t);
typedef int (cookie_seek_function_t)(void *, off_t *, int);
typedef int (cookie_close_function_t)(void *);

typedef struct _IO_cookie_io_functions_t {
	cookie_read_function_t *read;
	cookie_write_function_t *write;
	cookie_seek_function_t *seek;
	cookie_close_function_t *close;
} cookie_io_functions_t;
FILE *fopencookie(void *, const char *, cookie_io_functions_t);
#endif

#if defined(_LARGEFILE64_SOURCE) || defined(_GNU_SOURCE)
#define tmpfile64 tmpfile
#define fopen64 fopen
#define freopen64 freopen
#define fseeko64 fseeko
#define ftello64 ftello
#define fgetpos64 fgetpos
#define fsetpos64 fsetpos
#define fpos64_t fpos_t
#define off64_t off_t
#endif

/**
 * @brief Enumerates fd owner type.
 *
 * @since 12
 */
enum fdsan_owner_type {
    /* Default type value */
    FDSAN_OWNER_TYPE_DEFAULT = 0,
    /* Max value */
    FDSAN_OWNER_TYPE_MAX = 255,
    /* File */
    FDSAN_OWNER_TYPE_FILE = 1,
    /* Directory */
    FDSAN_OWNER_TYPE_DIRECTORY = 2,
    /* Unique fd */
    FDSAN_OWNER_TYPE_UNIQUE_FD = 3,
    /* Zip archive */
    FDSAN_OWNER_TYPE_ZIP_ARCHIVE = 4,
};

/**
 * @brief Create an owner tag using specified fdsan_owner_type and at least 56 bits tag value.
 *
 * @param type: Indicate the specified fdsan_owner_type.
 * @param tag: Indicate the specified tag value, at least 56 bits, usually specified as sturct address such as FILE*.
 * @return Return the created tag, which can be used to exchange.
 * @since 12
 */
uint64_t fdsan_create_owner_tag(enum fdsan_owner_type type, uint64_t tag);

/**
 * @brief Exchange owner tag for specified fd.
 *
 * This method will check if param expected_tag is euqal to current owner tag, fdsan error will occur if not.
 *
 * @param fd: Specified fd.
 * @param expected_tag: Used to check if equal to current owner tag.
 * @param new_tag: Used to exchange the specified fd owner tag.
 * @since 12
 */
void fdsan_exchange_owner_tag(int fd, uint64_t expected_tag, uint64_t new_tag);

/**
 * @brief Check fd owner tag and close fd.
 *
 * This method will check if param tag is euqal to current owner tag, fdsan error will occur if not,
 * then call syscall to close fd.
 *
 * @param fd: Specified fd.
 * @param tag: Used to check if equal to current owner tag.
 * @return Return close result, 0 success and -1 if fail.
 * @since 12
 */
int fdsan_close_with_tag(int fd, uint64_t tag);

/**
 * @brief Get specified fd's owner tag.
 *
 * @param fd: Specified fd.
 * @return Return tag value of specified fd, return 0 if fd is not in fd table.
 * @since 12
 */
uint64_t fdsan_get_owner_tag(int fd);

/**
 * @brief Get owner fd type
 *
 * @param tag: Specified tag, which usually comes from {@link fdsan_get_owner_tag}
 * @return Return type value of tag, possible value: FILE*, DIR*, unique_fd, ZipArchive, unknown type and so on.
 * @since 12
 */
const char* fdsan_get_tag_type(uint64_t tag);

/**
 * @brief Get owner fd tag value.
 *
 * @param tag: Specified tag, which usually comes from {@link fdsan_get_owner_tag}
 * @return Return value of tag, last 56 bits are valid.
 * @since 12
 */
uint64_t fdsan_get_tag_value(uint64_t tag);

/**
 * @brief Enumerates fdsan error level.
 *
 * @since 12
 */
enum fdsan_error_level {
    /* Do nothing if fdsan error occurs. */
    FDSAN_ERROR_LEVEL_DISABLED,
    /* Warning once if fdsan error occurs, and then downgrade to FDSAN_ERROR_LEVEL_DISABLED. */
    FDSAN_ERROR_LEVEL_WARN_ONCE,
    /* Keep warning only if fdsan error occurs. */
    FDSAN_ERROR_LEVEL_WARN_ALWAYS,
    /* Abort on fdsan error. */
    FDSAN_ERROR_LEVEL_FATAL,
};

/**
 * @brief Get fdsan error level.
 *
 * @return Return fdsan error level enumerate value.
 * @since 12
 */
enum fdsan_error_level fdsan_get_error_level();

/**
 * @brief Set fdsan error level.
 *
 * @param new_level: Used to set fdsan error level.
 * @return Return old fdsan error level enumerate value.
 * @since 12
 */
enum fdsan_error_level fdsan_set_error_level(enum fdsan_error_level new_level);

#include <fortify/stdio.h>

#ifdef __cplusplus
}
#endif

#endif