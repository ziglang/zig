
#ifndef _NTNLS_
#define _NTNLS_

#ifdef __cplusplus
extern "C" {
#endif

#define MAXIMUM_LEADBYTES 12

/* Some documentation can be found here: http://www.ping.uio.no/~ovehk/nls/ */
typedef struct _CPTABLEINFO
{
   USHORT  CodePage;
   USHORT  MaximumCharacterSize;       /* 1 = SBCS, 2 = DBCS */
   USHORT  DefaultChar;                /* Default MultiByte Character for the CP->Unicode conversion */
   USHORT  UniDefaultChar;             /* Default Unicode Character for the CP->Unicode conversion */
   USHORT  TransDefaultChar;           /* Default MultiByte Character for the Unicode->CP conversion */
   USHORT  TransUniDefaultChar;        /* Default Unicode Character for the Unicode->CP conversion */
   USHORT  DBCSCodePage;
   UCHAR LeadByte[MAXIMUM_LEADBYTES];
   PUSHORT MultiByteTable;             /* Table for CP->Unicode conversion */
   PVOID WideCharTable;                /* Table for Unicode->CP conversion */
   PUSHORT DBCSRanges;
   PUSHORT DBCSOffsets;
} CPTABLEINFO, *PCPTABLEINFO;

typedef struct _NLSTABLEINFO
{
   CPTABLEINFO OemTableInfo;
   CPTABLEINFO AnsiTableInfo;
   PUSHORT UpperCaseTable;
   PUSHORT LowerCaseTable;
} NLSTABLEINFO, *PNLSTABLEINFO;

#ifdef __cplusplus
}
#endif

#endif /* _NTNLS_ */

