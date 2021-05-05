#ifndef __wasilibc___include_inttypes_h
#define __wasilibc___include_inttypes_h

#include <stdint.h>

#define __need_wchar_t
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct { intmax_t quot, rem; } imaxdiv_t;

intmax_t  imaxabs(intmax_t);
imaxdiv_t imaxdiv(intmax_t, intmax_t);
intmax_t  strtoimax(const char *__restrict, char **__restrict, int);
uintmax_t strtoumax(const char *__restrict, char **__restrict, int);
intmax_t  wcstoimax(const wchar_t *__restrict, wchar_t **__restrict, int);
uintmax_t wcstoumax(const wchar_t *__restrict, wchar_t **__restrict, int);

#define PRId16 __INT16_FMTd__
#define PRIi16 __INT16_FMTi__
#define PRId32 __INT32_FMTd__
#define PRIi32 __INT32_FMTi__
#define PRId64 __INT64_FMTd__
#define PRIi64 __INT64_FMTi__
#define PRId8 __INT8_FMTd__
#define PRIi8 __INT8_FMTi__
#define PRIdMAX __INTMAX_FMTd__
#define PRIiMAX __INTMAX_FMTi__
#define PRIdPTR __INTPTR_FMTd__
#define PRIiPTR __INTPTR_FMTi__
#define PRIdFAST16 __INT_FAST16_FMTd__
#define PRIiFAST16 __INT_FAST16_FMTi__
#define PRIdFAST32 __INT_FAST32_FMTd__
#define PRIiFAST32 __INT_FAST32_FMTi__
#define PRIdFAST64 __INT_FAST64_FMTd__
#define PRIiFAST64 __INT_FAST64_FMTi__
#define PRIdFAST8 __INT_FAST8_FMTd__
#define PRIiFAST8 __INT_FAST8_FMTi__
#define PRIdLEAST16 __INT_LEAST16_FMTd__
#define PRIiLEAST16 __INT_LEAST16_FMTi__
#define PRIdLEAST32 __INT_LEAST32_FMTd__
#define PRIiLEAST32 __INT_LEAST32_FMTi__
#define PRIdLEAST64 __INT_LEAST64_FMTd__
#define PRIiLEAST64 __INT_LEAST64_FMTi__
#define PRIdLEAST8 __INT_LEAST8_FMTd__
#define PRIiLEAST8 __INT_LEAST8_FMTi__
#define PRIX16 __UINT16_FMTX__
#define PRIo16 __UINT16_FMTo__
#define PRIu16 __UINT16_FMTu__
#define PRIx16 __UINT16_FMTx__
#define PRIX32 __UINT32_FMTX__
#define PRIo32 __UINT32_FMTo__
#define PRIu32 __UINT32_FMTu__
#define PRIx32 __UINT32_FMTx__
#define PRIX64 __UINT64_FMTX__
#define PRIo64 __UINT64_FMTo__
#define PRIu64 __UINT64_FMTu__
#define PRIx64 __UINT64_FMTx__
#define PRIX8 __UINT8_FMTX__
#define PRIo8 __UINT8_FMTo__
#define PRIu8 __UINT8_FMTu__
#define PRIx8 __UINT8_FMTx__
#define PRIXMAX __UINTMAX_FMTX__
#define PRIoMAX __UINTMAX_FMTo__
#define PRIuMAX __UINTMAX_FMTu__
#define PRIxMAX __UINTMAX_FMTx__
#define PRIXPTR __UINTPTR_FMTX__
#define PRIoPTR __UINTPTR_FMTo__
#define PRIuPTR __UINTPTR_FMTu__
#define PRIxPTR __UINTPTR_FMTx__
#define PRIXFAST16 __UINT_FAST16_FMTX__
#define PRIoFAST16 __UINT_FAST16_FMTo__
#define PRIuFAST16 __UINT_FAST16_FMTu__
#define PRIxFAST16 __UINT_FAST16_FMTx__
#define PRIXFAST32 __UINT_FAST32_FMTX__
#define PRIoFAST32 __UINT_FAST32_FMTo__
#define PRIuFAST32 __UINT_FAST32_FMTu__
#define PRIxFAST32 __UINT_FAST32_FMTx__
#define PRIXFAST64 __UINT_FAST64_FMTX__
#define PRIoFAST64 __UINT_FAST64_FMTo__
#define PRIuFAST64 __UINT_FAST64_FMTu__
#define PRIxFAST64 __UINT_FAST64_FMTx__
#define PRIXFAST8 __UINT_FAST8_FMTX__
#define PRIoFAST8 __UINT_FAST8_FMTo__
#define PRIuFAST8 __UINT_FAST8_FMTu__
#define PRIxFAST8 __UINT_FAST8_FMTx__
#define PRIXLEAST16 __UINT_LEAST16_FMTX__
#define PRIoLEAST16 __UINT_LEAST16_FMTo__
#define PRIuLEAST16 __UINT_LEAST16_FMTu__
#define PRIxLEAST16 __UINT_LEAST16_FMTx__
#define PRIXLEAST32 __UINT_LEAST32_FMTX__
#define PRIoLEAST32 __UINT_LEAST32_FMTo__
#define PRIuLEAST32 __UINT_LEAST32_FMTu__
#define PRIxLEAST32 __UINT_LEAST32_FMTx__
#define PRIXLEAST64 __UINT_LEAST64_FMTX__
#define PRIoLEAST64 __UINT_LEAST64_FMTo__
#define PRIuLEAST64 __UINT_LEAST64_FMTu__
#define PRIxLEAST64 __UINT_LEAST64_FMTx__
#define PRIXLEAST8 __UINT_LEAST8_FMTX__
#define PRIoLEAST8 __UINT_LEAST8_FMTo__
#define PRIuLEAST8 __UINT_LEAST8_FMTu__
#define PRIxLEAST8 __UINT_LEAST8_FMTx__

#define SCNd16 __INT16_FMTd__
#define SCNi16 __INT16_FMTi__
#define SCNd32 __INT32_FMTd__
#define SCNi32 __INT32_FMTi__
#define SCNd64 __INT64_FMTd__
#define SCNi64 __INT64_FMTi__
#define SCNd8 __INT8_FMTd__
#define SCNi8 __INT8_FMTi__
#define SCNdMAX __INTMAX_FMTd__
#define SCNiMAX __INTMAX_FMTi__
#define SCNdPTR __INTPTR_FMTd__
#define SCNiPTR __INTPTR_FMTi__
#define SCNdFAST16 __INT_FAST16_FMTd__
#define SCNiFAST16 __INT_FAST16_FMTi__
#define SCNdFAST32 __INT_FAST32_FMTd__
#define SCNiFAST32 __INT_FAST32_FMTi__
#define SCNdFAST64 __INT_FAST64_FMTd__
#define SCNiFAST64 __INT_FAST64_FMTi__
#define SCNdFAST8 __INT_FAST8_FMTd__
#define SCNiFAST8 __INT_FAST8_FMTi__
#define SCNdLEAST16 __INT_LEAST16_FMTd__
#define SCNiLEAST16 __INT_LEAST16_FMTi__
#define SCNdLEAST32 __INT_LEAST32_FMTd__
#define SCNiLEAST32 __INT_LEAST32_FMTi__
#define SCNdLEAST64 __INT_LEAST64_FMTd__
#define SCNiLEAST64 __INT_LEAST64_FMTi__
#define SCNdLEAST8 __INT_LEAST8_FMTd__
#define SCNiLEAST8 __INT_LEAST8_FMTi__
#define SCNo16 __UINT16_FMTo__
#define SCNu16 __UINT16_FMTu__
#define SCNx16 __UINT16_FMTx__
#define SCNo32 __UINT32_FMTo__
#define SCNu32 __UINT32_FMTu__
#define SCNx32 __UINT32_FMTx__
#define SCNo64 __UINT64_FMTo__
#define SCNu64 __UINT64_FMTu__
#define SCNx64 __UINT64_FMTx__
#define SCNo8 __UINT8_FMTo__
#define SCNu8 __UINT8_FMTu__
#define SCNx8 __UINT8_FMTx__
#define SCNoMAX __UINTMAX_FMTo__
#define SCNuMAX __UINTMAX_FMTu__
#define SCNxMAX __UINTMAX_FMTx__
#define SCNoPTR __UINTPTR_FMTo__
#define SCNuPTR __UINTPTR_FMTu__
#define SCNxPTR __UINTPTR_FMTx__
#define SCNoFAST16 __UINT_FAST16_FMTo__
#define SCNuFAST16 __UINT_FAST16_FMTu__
#define SCNxFAST16 __UINT_FAST16_FMTx__
#define SCNoFAST32 __UINT_FAST32_FMTo__
#define SCNuFAST32 __UINT_FAST32_FMTu__
#define SCNxFAST32 __UINT_FAST32_FMTx__
#define SCNoFAST64 __UINT_FAST64_FMTo__
#define SCNuFAST64 __UINT_FAST64_FMTu__
#define SCNxFAST64 __UINT_FAST64_FMTx__
#define SCNoFAST8 __UINT_FAST8_FMTo__
#define SCNuFAST8 __UINT_FAST8_FMTu__
#define SCNxFAST8 __UINT_FAST8_FMTx__
#define SCNoLEAST16 __UINT_LEAST16_FMTo__
#define SCNuLEAST16 __UINT_LEAST16_FMTu__
#define SCNxLEAST16 __UINT_LEAST16_FMTx__
#define SCNoLEAST32 __UINT_LEAST32_FMTo__
#define SCNuLEAST32 __UINT_LEAST32_FMTu__
#define SCNxLEAST32 __UINT_LEAST32_FMTx__
#define SCNoLEAST64 __UINT_LEAST64_FMTo__
#define SCNuLEAST64 __UINT_LEAST64_FMTu__
#define SCNxLEAST64 __UINT_LEAST64_FMTx__
#define SCNoLEAST8 __UINT_LEAST8_FMTo__
#define SCNuLEAST8 __UINT_LEAST8_FMTu__
#define SCNxLEAST8 __UINT_LEAST8_FMTx__

#ifdef __cplusplus
}
#endif

#endif
