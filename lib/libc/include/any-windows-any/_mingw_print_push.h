/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

/* Undefine __mingw_<printf> macros.  */
#if defined(__USE_MINGW_ANSI_STDIO) && ((__USE_MINGW_ANSI_STDIO + 0) != 0)

/* Redefine to MS specific PRI... and SCN... macros.  */
#if defined(_INTTYPES_H_) && defined(PRId64)
#undef PRId64
#undef PRIdLEAST64
#undef PRIdFAST64
#undef PRIdMAX
#undef PRIi64
#undef PRIiLEAST64
#undef PRIiFAST64
#undef PRIiMAX
#undef PRIo64
#undef PRIoLEAST64
#undef PRIoFAST64
#undef PRIoMAX
#undef PRIu64
#undef PRIuLEAST64
#undef PRIuFAST64
#undef PRIuMAX
#undef PRIx64
#undef PRIxLEAST64
#undef PRIxFAST64
#undef PRIxMAX
#undef PRIX64
#undef PRIXLEAST64
#undef PRIXFAST64
#undef PRIXMAX

#undef SCNd64
#undef SCNdLEAST64
#undef SCNdFAST64
#undef SCNdMAX
#undef SCNi64
#undef SCNiLEAST64
#undef SCNiFAST64
#undef SCNiMAX
#undef SCNo64
#undef SCNoLEAST64
#undef SCNoFAST64
#undef SCNoMAX
#undef SCNx64
#undef SCNxLEAST64
#undef SCNxFAST64
#undef SCNxMAX
#undef SCNu64
#undef SCNuLEAST64
#undef SCNuFAST64
#undef SCNuMAX

#ifdef _WIN64
#undef PRIdPTR
#undef PRIiPTR
#undef PRIoPTR
#undef PRIuPTR
#undef PRIxPTR
#undef PRIXPTR

#undef SCNdPTR
#undef SCNiPTR
#undef SCNoPTR
#undef SCNxPTR
#undef SCNuPTR
#endif /* _WIN64 */

#define PRId64 "lld"
#define PRIdLEAST64 "lld"
#define PRIdFAST64 "lld"
#define PRIdMAX "lld"
#define PRIi64 "lli"
#define PRIiLEAST64 "lli"
#define PRIiFAST64 "lli"
#define PRIiMAX "lli"
#define PRIo64 "llo"
#define PRIoLEAST64 "llo"
#define PRIoFAST64 "llo"
#define PRIoMAX "llo"
#define PRIu64 "llu"
#define PRIuLEAST64 "llu"
#define PRIuFAST64 "llu"
#define PRIuMAX "llu"
#define PRIx64 "llx"
#define PRIxLEAST64 "llx"
#define PRIxFAST64 "llx"
#define PRIxMAX "llx"
#define PRIX64 "llX"
#define PRIXLEAST64 "llX"
#define PRIXFAST64 "llX"
#define PRIXMAX "llX"

#define SCNd64 "lld"
#define SCNdLEAST64 "lld"
#define SCNdFAST64 "lld"
#define SCNdMAX "lld"
#define SCNi64 "lli"
#define SCNiLEAST64 "lli"
#define SCNiFAST64 "lli"
#define SCNiMAX "lli"
#define SCNo64 "llo"
#define SCNoLEAST64 "llo"
#define SCNoFAST64 "llo"
#define SCNoMAX "llo"
#define SCNx64 "llx"
#define SCNxLEAST64 "llx"
#define SCNxFAST64 "llx"
#define SCNxMAX "llx"
#define SCNu64 "llu"
#define SCNuLEAST64 "llu"
#define SCNuFAST64 "llu"
#define SCNuMAX "llu"

#ifdef _WIN64
#define PRIdPTR "lld"
#define PRIiPTR "lli"
#define PRIoPTR "llo"
#define PRIuPTR "llu"
#define PRIxPTR "llx"
#define PRIXPTR "llX"

#define SCNdPTR "lld"
#define SCNiPTR "lli"
#define SCNoPTR "llo"
#define SCNxPTR "llx"
#define SCNuPTR "llu"
#endif /* _WIN64 */

#endif /* defined(_INTTYPES_H_) && defined(PRId64) */

#endif /* defined(__USE_MINGW_ANSI_STDIO) && __USE_MINGW_ANSI_STDIO != 0 */
