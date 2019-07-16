/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_PENWIN
#define _INC_PENWIN

#ifndef NOJAPAN
#ifndef JAPAN
#define JAPAN
#endif
#endif

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef PENVER
#define PENVER 0x0200
#endif

#define NOPENAPPS
#define NOPENDICT
#define NOPENRC1
#define NOPENVIRTEVENT
#define NOPENAPIFUN

#ifndef NOPENAPPS
#ifndef RC_INVOKED
#include <skbapi.h>
#endif
#endif

#ifdef NOPENCTL
#define NOPENBEDIT
#define NOPENIEDIT
#endif

#ifdef NOPENRES
#define NOPENBMP
#define NOPENCURS
#endif

#ifndef NOPENALC

#define ALC_DEFAULT __MSABI_LONG(0x00000000)
#define ALC_LCALPHA __MSABI_LONG(0x00000001)
#define ALC_UCALPHA __MSABI_LONG(0x00000002)
#define ALC_NUMERIC __MSABI_LONG(0x00000004)
#define ALC_PUNC __MSABI_LONG(0x00000008)
#define ALC_MATH __MSABI_LONG(0x00000010)
#define ALC_MONETARY __MSABI_LONG(0x00000020)
#define ALC_OTHER __MSABI_LONG(0x00000040)
#define ALC_ASCII __MSABI_LONG(0x00000080)
#define ALC_WHITE __MSABI_LONG(0x00000100)
#define ALC_NONPRINT __MSABI_LONG(0x00000200)
#define ALC_DBCS __MSABI_LONG(0x00000400)
#define ALC_JIS1 __MSABI_LONG(0x00000800)
#define ALC_GESTURE __MSABI_LONG(0x00004000)
#define ALC_USEBITMAP __MSABI_LONG(0x00008000)
#define ALC_HIRAGANA __MSABI_LONG(0x00010000)
#define ALC_KATAKANA __MSABI_LONG(0x00020000)
#define ALC_KANJI __MSABI_LONG(0x00040000)
#define ALC_GLOBALPRIORITY __MSABI_LONG(0x10000000)
#define ALC_OEM __MSABI_LONG(0x0FF80000)
#define ALC_RESERVED __MSABI_LONG(0xE0003000)
#define ALC_NOPRIORITY __MSABI_LONG(0x00000000)

#define ALC_ALPHA (ALC_LCALPHA | ALC_UCALPHA)
#define ALC_ALPHANUMERIC (ALC_ALPHA | ALC_NUMERIC)
#define ALC_SYSMINIMUM (ALC_ALPHANUMERIC | ALC_PUNC | ALC_WHITE | ALC_GESTURE)
#define ALC_ALL (ALC_SYSMINIMUM | ALC_MATH | ALC_MONETARY | ALC_OTHER | ALC_NONPRINT)
#define ALC_KANJISYSMINIMUM (ALC_SYSMINIMUM | ALC_HIRAGANA | ALC_KATAKANA | ALC_JIS1)
#define ALC_KANJIALL (ALC_ALL | ALC_HIRAGANA | ALC_KATAKANA | ALC_KANJI)
#endif

#ifndef NOPENBEDIT

#define BXS_NONE 0x0000U
#define BXS_RECT 0x0001U
#define BXS_BOXCROSS 0x0004U
#ifdef JAPAN
#define BXS_NOWRITING 0x0008U
#endif
#endif

#ifndef NOPENBMP

#define OBM_SKBBTNUP 32767
#define OBM_SKBBTNDOWN 32766
#define OBM_SKBBTNDISABLED 32765

#define OBM_ZENBTNUP 32764
#define OBM_ZENBTNDOWN 32763
#define OBM_ZENBTNDISABLED 32762

#define OBM_HANBTNUP 32761
#define OBM_HANBTNDOWN 32760
#define OBM_HANBTNDISABLED 32759

#define OBM_KKCBTNUP 32758
#define OBM_KKCBTNDOWN 32757
#define OBM_KKCBTNDISABLED 32756

#define OBM_SIPBTNUP 32755
#define OBM_SIPBTNDOWN 32754
#define OBM_SIPBTNDISABLED 32753

#define OBM_PTYBTNUP 32752
#define OBM_PTYBTNDOWN 32751
#define OBM_PTYBTNDISABLED 32750
#endif

#ifndef NOPENCURS

#define IDC_PEN MAKEINTRESOURCE(32631)

#define IDC_ALTSELECT MAKEINTRESOURCE(32501)
#endif

#ifndef NOPENHRC

#define SYV_NULL __MSABI_LONG(0x00000000)
#define SYV_UNKNOWN __MSABI_LONG(0x00000001)
#define SYV_EMPTY __MSABI_LONG(0x00000003)
#define SYV_BEGINOR __MSABI_LONG(0x00000010)
#define SYV_ENDOR __MSABI_LONG(0x00000011)
#define SYV_OR __MSABI_LONG(0x00000012)
#define SYV_SOFTNEWLINE __MSABI_LONG(0x00000020)
#define SYV_SPACENULL __MSABI_LONG(0x00010000)

#define SYV_SELECTFIRST __MSABI_LONG(0x0002FFC0)
#define SYV_LASSO __MSABI_LONG(0x0002FFC1)
#define SYV_SELECTLEFT __MSABI_LONG(0x0002FFC2)
#define SYV_SELECTRIGHT __MSABI_LONG(0x0002FFC3)
#define SYV_SELECTLAST __MSABI_LONG(0x0002FFCF)

#define SYV_CLEARCHAR __MSABI_LONG(0x0002FFD2)
#define SYV_HELP __MSABI_LONG(0x0002FFD3)
#define SYV_KKCONVERT __MSABI_LONG(0x0002FFD4)
#define SYV_CLEAR __MSABI_LONG(0x0002FFD5)
#define SYV_INSERT __MSABI_LONG(0x0002FFD6)
#define SYV_CONTEXT __MSABI_LONG(0x0002FFD7)
#define SYV_EXTENDSELECT __MSABI_LONG(0x0002FFD8)
#define SYV_UNDO __MSABI_LONG(0x0002FFD9)
#define SYV_COPY __MSABI_LONG(0x0002FFDA)
#define SYV_CUT __MSABI_LONG(0x0002FFDB)
#define SYV_PASTE __MSABI_LONG(0x0002FFDC)
#define SYV_CLEARWORD __MSABI_LONG(0x0002FFDD)
#define SYV_USER __MSABI_LONG(0x0002FFDE)
#define SYV_CORRECT __MSABI_LONG(0x0002FFDF)

#define SYV_BACKSPACE __MSABI_LONG(0x00020008)
#define SYV_TAB __MSABI_LONG(0x00020009)
#define SYV_RETURN __MSABI_LONG(0x0002000D)
#define SYV_SPACE __MSABI_LONG(0x00020020)

#define SYV_APPGESTUREMASK __MSABI_LONG(0x00020000)
#define SYV_CIRCLEUPA __MSABI_LONG(0x000224B6)
#define SYV_CIRCLEUPZ __MSABI_LONG(0x000224CF)
#define SYV_CIRCLELOA __MSABI_LONG(0x000224D0)
#define SYV_CIRCLELOZ __MSABI_LONG(0x000224E9)

#define SYV_SHAPELINE __MSABI_LONG(0x00040001)
#define SYV_SHAPEELLIPSE __MSABI_LONG(0x00040002)
#define SYV_SHAPERECT __MSABI_LONG(0x00040003)
#define SYV_SHAPEMIN SYV_SHAPELINE
#define SYV_SHAPEMAX SYV_SHAPERECT

#define SYVHI_SPECIAL 0
#define SYVHI_ANSI 1
#define SYVHI_GESTURE 2
#define SYVHI_KANJI 3
#define SYVHI_SHAPE 4
#define SYVHI_UNICODE 5
#define SYVHI_VKEY 6
#endif

#ifndef NOPENIEDIT

#define IEM_UNDO 1
#define IEM_CUT 2
#define IEM_COPY 3
#define IEM_PASTE 4
#define IEM_CLEAR 5
#define IEM_SELECTALL 6
#define IEM_ERASE 7
#define IEM_PROPERTIES 8
#define IEM_LASSO 9
#define IEM_RESIZE 10

#define IEM_USER 100

#define IES_BORDER 0x0001
#define IES_HSCROLL 0x0002
#define IES_VSCROLL 0x0004
#define IES_OWNERDRAW 0x0008
#endif

#ifndef RC_INVOKED

#ifndef NOPENDATA

#define AI_CBSTROKE 0xFFFF

#define AI_SKIPUPSTROKES 0x0001

#define CMPD_COMPRESS 0x0001
#define CMPD_DECOMPRESS 0x0002

#define CPDR_BOX 1
#define CPDR_LASSO 2

#define CPD_DEFAULT 0x047F
#define CPD_USERBYTE 0x0100
#define CPD_USERWORD 0x0200
#define CPD_USERDWORD 0x0300
#define CPD_TIME 0x0400

#define DPD_HDCPEN 0x0001
#define DPD_DRAWSEL 0x0002

#define EPDP_REMOVE 0x0001

#define EPDS_SELECT 1
#define EPDS_STROKEINDEX 2
#define EPDS_USER 3
#define EPDS_PENTIP 4
#define EPDS_TIPCOLOR 5
#define EPDS_TIPWIDTH 6
#define EPDS_TIPNIB 7
#define EPDS_INKSET 8

#define EPDS_EQ 0x0000
#define EPDS_LT 0x0010
#define EPDS_GT 0x0020
#define EPDS_NOT 0x0040
#define EPDS_NE 0x0040
#define EPDS_GTE 0x0050
#define EPDS_LTE 0x0060

#define EPDS_REMOVE 0x8000

#define GPA_MAXLEN 1
#define GPA_POINTS 2
#define GPA_PDTS 3
#define GPA_RATE 4
#define GPA_RECTBOUND 5
#define GPA_RECTBOUNDINK 6
#define GPA_SIZE 7
#define GPA_STROKES 8
#define GPA_TIME 9
#define GPA_USER 10
#define GPA_VERSION 11

#define GSA_PENTIP 1
#define GSA_PENTIPCLASS 2
#define GSA_USER 3
#define GSA_USERCLASS 4
#define GSA_TIME 5
#define GSA_SIZE 6
#define GSA_SELECT 7
#define GSA_DOWN 8
#define GSA_RECTBOUND 9

#define GSA_PENTIPTABLE 10
#define GSA_SIZETABLE 11
#define GSA_USERTABLE 12

#ifndef IX_END
#define IX_END 0xFFFF
#endif

#define PENTIP_NIBDEFAULT ((BYTE)0)
#define PENTIP_HEIGHTDEFAULT ((BYTE)0)
#define PENTIP_OPAQUE ((BYTE)0xFF)
#define PENTIP_HILITE ((BYTE)0x80)
#define PENTIP_TRANSPARENT ((BYTE)0)

#define PDR_NOHIT 3
#define PDR_HIT 2
#define PDR_OK 1
#define PDR_CANCEL 0

#define PDR_ERROR (-1)
#define PDR_PNDTERR (-2)
#define PDR_VERSIONERR (-3)
#define PDR_COMPRESSED (-4)
#define PDR_STRKINDEXERR (-5)
#define PDR_PNTINDEXERR (-6)
#define PDR_MEMERR (-7)
#define PDR_INKSETERR (-8)
#define PDR_ABORT (-9)
#define PDR_NA (-10)

#define PDR_USERDATAERR (-16)
#define PDR_SCALINGERR (-17)
#define PDR_TIMESTAMPERR (-18)
#define PDR_OEMDATAERR (-19)
#define PDR_SCTERR (-20)

#define PDTS_LOMETRIC 0
#define PDTS_HIMETRIC 1
#define PDTS_HIENGLISH 2
#define PDTS_STANDARDSCALE 2
#define PDTS_DISPLAY 3
#define PDTS_ARBITRARY 4
#define PDTS_SCALEMASK 0x000F

#define PDTT_DEFAULT 0x0000
#define PDTT_PENINFO 0x0100
#define PDTT_UPPOINTS 0x0200
#define PDTT_OEMDATA 0x0400
#define PDTT_COLLINEAR 0x0800
#define PDTT_COLINEAR 0x0800
#define PDTT_DECOMPRESS 0x4000
#define PDTT_COMPRESS 0x8000
#define PDTT_ALL 0x0F00

#define PHW_NONE 0x0000
#define PHW_PRESSURE 0x0001
#define PHW_HEIGHT 0x0002
#define PHW_ANGLEXY 0x0004
#define PHW_ANGLEZ 0x0008
#define PHW_BARRELROTATION 0x0010
#define PHW_OEMSPECIFIC 0x0020
#define PHW_PDK 0x0040
#define PHW_ALL 0x007F

#define PDTS_COMPRESS2NDDERIV 0x0010
#define PDTS_COMPRESSMETHOD 0x00F0
#define PDTS_NOPENINFO 0x0100
#define PDTS_NOUPPOINTS 0x0200
#define PDTS_NOOEMDATA 0x0400
#define PDTS_NOCOLLINEAR 0x0800
#define PDTS_NOCOLINEAR 0x0800
#define PDTS_NOTICK 0x1000
#define PDTS_NOUSER 0x2000
#define PDTS_NOEMPTYSTROKES 0x4000
#define PDTS_COMPRESSED 0x8000

#define SSA_PENTIP 1
#define SSA_PENTIPCLASS 2
#define SSA_USER 3
#define SSA_USERCLASS 4
#define SSA_TIME 5
#define SSA_SELECT 6
#define SSA_DOWN 7

#define SSA_PENTIPTABLE 8
#define SSA_USERTABLE 9

#define TIP_ERASECOLOR 1

#define TPD_RECALCSIZE 0x0000
#define TPD_USER 0x0080
#define TPD_TIME 0x0100
#define TPD_UPPOINTS 0x0200
#define TPD_COLLINEAR 0x0400
#define TPD_COLINEAR 0x0400
#define TPD_PENINFO 0x0800
#define TPD_PHW 0x1000
#define TPD_OEMDATA 0x1000
#define TPD_EMPTYSTROKES 0x2000
#define TPD_EVERYTHING 0x3FFF
#endif

#ifndef NOPENDICT

#define cbDictPathMax 255
#define DIRQ_QUERY 1
#define DIRQ_DESCRIPTION 2
#define DIRQ_CONFIGURE 3
#define DIRQ_OPEN 4
#define DIRQ_CLOSE 5
#define DIRQ_SETWORDLISTS 6
#define DIRQ_STRING 7
#define DIRQ_SUGGEST 8
#define DIRQ_ADD 9
#define DIRQ_DELETE 10
#define DIRQ_FLUSH 11
#define DIRQ_RCCHANGE 12
#define DIRQ_SYMBOLGRAPH 13
#define DIRQ_INIT 14
#define DIRQ_CLEANUP 15
#define DIRQ_COPYRIGHT 16
#define DIRQ_USER 4096
#endif

#ifndef NOPENDRIVER

#define BITPENUP 0x8000

#define DRV_SetPenDriverEntryPoints DRV_RESERVED+1
#define DRV_SetEntryPoints DRV_RESERVED+1
#define DRV_RemovePenDriverEntryPoints DRV_RESERVED+2
#define DRV_RemoveEntryPoints DRV_RESERVED+2
#define DRV_SetPenSamplingRate DRV_RESERVED+3
#define DRV_SetPenSamplingDist DRV_RESERVED+4
#define DRV_GetName DRV_RESERVED+5
#define DRV_GetVersion DRV_RESERVED+6
#define DRV_GetPenInfo DRV_RESERVED+7
#define DRV_PenPlayStart DRV_RESERVED+8
#define DRV_PenPlayBack DRV_RESERVED+9
#define DRV_PenPlayStop DRV_RESERVED+10
#define DRV_GetCalibration DRV_RESERVED+11
#define DRV_SetCalibration DRV_RESERVED+12
#define DRV_Reserved1 DRV_RESERVED+13
#define DRV_Reserved2 DRV_RESERVED+14
#define DRV_Query DRV_RESERVED+15
#define DRV_GetPenSamplingRate DRV_RESERVED+16
#define DRV_Calibrate DRV_RESERVED+17

#define PLAY_VERSION_10_DATA 0
#define PLAY_VERSION_20_DATA 1

#define DRV_FAILURE 0x00000000
#define DRV_SUCCESS 0x00000001
#define DRV_BADPARAM1 0xFFFFFFFF
#define DRV_BADPARAM2 0xFFFFFFFE
#define DRV_BADSTRUCT 0xFFFFFFFD

#define PENREG_DEFAULT 0x00000002
#define PENREG_WILLHANDLEMOUSE 0x00000001

#define MAXOEMDATAWORDS 6

#define PCM_PENUP __MSABI_LONG(0x00000001)
#define PCM_RANGE __MSABI_LONG(0x00000002)
#define PCM_INVERT __MSABI_LONG(0x00000020)
#define PCM_RECTEXCLUDE __MSABI_LONG(0x00002000)
#define PCM_RECTBOUND __MSABI_LONG(0x00004000)
#define PCM_TIMEOUT __MSABI_LONG(0x00008000)

#define PCM_RGNBOUND __MSABI_LONG(0x00010000)
#define PCM_RGNEXCLUDE __MSABI_LONG(0x00020000)
#define PCM_DOPOLLING __MSABI_LONG(0x00040000)
#define PCM_TAPNHOLD __MSABI_LONG(0x00080000)
#define PCM_ADDDEFAULTS RC_LDEFAULTFLAGS

#define PDC_INTEGRATED __MSABI_LONG(0x00000001)
#define PDC_PROXIMITY __MSABI_LONG(0x00000002)
#define PDC_RANGE __MSABI_LONG(0x00000004)
#define PDC_INVERT __MSABI_LONG(0x00000008)
#define PDC_RELATIVE __MSABI_LONG(0x00000010)
#define PDC_BARREL1 __MSABI_LONG(0x00000020)
#define PDC_BARREL2 __MSABI_LONG(0x00000040)
#define PDC_BARREL3 __MSABI_LONG(0x00000080)

#define PDK_NULL 0x0000
#define PDK_UP 0x0000
#define PDK_DOWN 0x0001
#define PDK_BARREL1 0x0002
#define PDK_BARREL2 0x0004
#define PDK_BARREL3 0x0008
#define PDK_SWITCHES 0x000f
#define PDK_TRANSITION 0x0010
#define PDK_UNUSED10 0x0020
#define PDK_UNUSED20 0x0040
#define PDK_INVERTED 0x0080
#define PDK_PENIDMASK 0x0F00
#define PDK_UNUSED1000 0x1000
#define PDK_INKSTOPPED 0x2000
#define PDK_OUTOFRANGE 0x4000
#define PDK_DRIVER 0x8000

#define PDK_TIPMASK 0x0001

#define PDT_NULL 0
#define PDT_PRESSURE 1
#define PDT_HEIGHT 2
#define PDT_ANGLEXY 3
#define PDT_ANGLEZ 4
#define PDT_BARRELROTATION 5
#define PDT_OEMSPECIFIC 16

#define PID_CURRENT (UINT)(-1)

#define REC_OEM (-1024)
#define REC_LANGUAGE (-48)
#define REC_GUIDE (-47)
#define REC_PARAMERROR (-46)
#define REC_INVALIDREF (-45)
#define REC_RECTEXCLUDE (-44)
#define REC_RECTBOUND (-43)
#define REC_PCM (-42)
#define REC_RESULTMODE (-41)
#define REC_HWND (-40)
#define REC_ALC (-39)
#define REC_ERRORLEVEL (-38)
#define REC_CLVERIFY (-37)
#define REC_DICT (-36)
#define REC_HREC (-35)
#define REC_BADEVENTREF (-33)
#define REC_NOCOLLECTION (-32)
#define REC_DEBUG (-32)
#define REC_POINTEREVENT (-31)
#define REC_BADHPENDATA (-9)
#define REC_OOM (-8)
#define REC_NOINPUT (-7)
#define REC_NOTABLET (-6)
#define REC_BUSY (-5)
#define REC_BUFFERTOOSMALL (-4)
#define REC_ABORT (-3)
#define REC_NA (-2)
#define REC_OVERFLOW (-1)
#define REC_OK 0
#define REC_TERMBOUND 1
#define REC_TERMEX 2
#define REC_TERMPENUP 3
#define REC_TERMRANGE 4
#define REC_TERMTIMEOUT 5
#define REC_DONE 6
#define REC_TERMOEM 512
#endif

#ifndef NOPENHRC

#define GRH_ALL 0
#define GRH_GESTURE 1
#define GRH_NONGESTURE 2

#ifdef JAPAN
#define GST_SEL __MSABI_LONG(0x00000001)
#define GST_CLIP __MSABI_LONG(0x00000002)
#define GST_WHITE __MSABI_LONG(0x00000004)
#define GST_KKCONVERT __MSABI_LONG(0x00000008)
#define GST_EDIT __MSABI_LONG(0x00000010)
#define GST_SYS __MSABI_LONG(0x0000001F)
#define GST_CIRCLELO __MSABI_LONG(0x00000100)
#define GST_CIRCLEUP __MSABI_LONG(0x00000200)
#define GST_CIRCLE __MSABI_LONG(0x00000300)
#define GST_ALL __MSABI_LONG(0x0000031F)
#else
#define GST_SEL __MSABI_LONG(0x00000001)
#define GST_CLIP __MSABI_LONG(0x00000002)
#define GST_WHITE __MSABI_LONG(0x00000004)
#define GST_EDIT __MSABI_LONG(0x00000010)
#define GST_SYS __MSABI_LONG(0x00000017)
#define GST_CIRCLELO __MSABI_LONG(0x00000100)
#define GST_CIRCLEUP __MSABI_LONG(0x00000200)
#define GST_CIRCLE __MSABI_LONG(0x00000300)
#define GST_ALL __MSABI_LONG(0x00000317)
#endif

#define HRCR_NORESULTS 4
#define HRCR_COMPLETE 3
#define HRCR_GESTURE 2
#define HRCR_OK 1
#define HRCR_INCOMPLETE 0
#define HRCR_ERROR (-1)
#define HRCR_MEMERR (-2)
#define HRCR_INVALIDGUIDE (-3)
#define HRCR_INVALIDPNDT (-4)
#define HRCR_UNSUPPORTED (-5)
#define HRCR_CONFLICT (-6)
#define HRCR_HOOKED (-8)

#define HWL_SYSTEM ((HWL)1)

#define ISR_ERROR (-1)
#define ISR_BADINKSET (-2)
#define ISR_BADINDEX (-3)

#ifndef IX_END
#define IX_END 0xFFFF
#endif

#define MAXHOTSPOT 8

#define PH_MAX __MSABI_LONG(0xFFFFFFFF)
#define PH_DEFAULT __MSABI_LONG(0xFFFFFFFE)
#define PH_MIN __MSABI_LONG(0xFFFFFFFD)

#define RHH_STD 0
#define RHH_BOX 1

#define SCH_NONE 0
#define SCH_ADVISE 1
#define SCH_FORCE 2

#define SCIM_INSERT 0
#define SCIM_OVERWRITE 1

#define SRH_HOOKALL (HREC)1

#define SSH_RD 1
#define SSH_RU 2
#define SSH_LD 3
#define SSH_LU 4
#define SSH_DL 5
#define SSH_DR 6
#define SSH_UL 7
#define SSH_UR 8

#define SIH_ALLANSICHAR 1

#define TH_QUERY 0
#define TH_FORCE 1
#define TH_SUGGEST 2

#define TRAIN_NONE 0x0000
#define TRAIN_DEFAULT 0x0001
#define TRAIN_CUSTOM 0x0002
#define TRAIN_BOTH (TRAIN_DEFAULT | TRAIN_CUSTOM)

#define TRAIN_SAVE 0
#define TRAIN_REVERT 1
#define TRAIN_RESET 2

#define WCR_RECOGNAME 0
#define WCR_QUERY 1
#define WCR_CONFIGDIALOG 2
#define WCR_DEFAULT 3
#define WCR_RCCHANGE 4
#define WCR_VERSION 5
#define WCR_TRAIN 6
#define WCR_TRAINSAVE 7
#define WCR_TRAINMAX 8
#define WCR_TRAINDIRTY 9
#define WCR_TRAINCUSTOM 10
#define WCR_QUERYLANGUAGE 11
#define WCR_USERCHANGE 12

#define WCR_PWVERSION 13
#define WCR_GETALCPRIORITY 14
#define WCR_SETALCPRIORITY 15
#define WCR_GETANSISTATE 16
#define WCR_SETANSISTATE 17
#define WCR_GETHAND 18
#define WCR_SETHAND 19
#define WCR_GETDIRECTION 20
#define WCR_SETDIRECTION 21
#define WCR_INITRECOGNIZER 22
#define WCR_CLOSERECOGNIZER 23

#define WCR_PRIVATE 1024

#define CRUC_NOTIFY 0
#define CRUC_REMOVE 1

#define WLT_STRING 0
#define WLT_STRINGTABLE 1
#define WLT_EMPTY 2
#define WLT_WORDLIST 3
#endif

#ifndef NOPENIEDIT

#define IEB_DEFAULT 0
#define IEB_BRUSH 1
#define IEB_BIT_UL 2
#define IEB_BIT_CENTER 3
#define IEB_BIT_TILE 4
#define IEB_BIT_STRETCH 5
#define IEB_OWNERDRAW 6

#define IEDO_NONE 0x0000
#define IEDO_FAST 0x0001
#define IEDO_SAVEUPSTROKES 0x0002
#define IEDO_RESERVED 0xFFFC

#define IEI_MOVE 0x0001
#define IEI_RESIZE 0x0002
#define IEI_CROP 0x0004
#define IEI_DISCARD 0x0008
#define IEI_RESERVED 0xFFF0

#define IEGI_ALL 0x0000
#define IEGI_SELECTION 0x0001

#define IEMODE_READY 0
#define IEMODE_ERASE 1
#define IEMODE_LASSO 2

#define IEN_NULL 0x0000
#define IEN_PDEVENT 0x0001
#define IEN_PAINT 0x0002
#define IEN_FOCUS 0x0004
#define IEN_SCROLL 0x0008
#define IEN_EDIT 0x0010
#define IEN_PROPERTIES 0x0020
#define IEN_RESERVED 0xFF80

#define IER_OK 0
#define IER_NO 0
#define IER_YES 1
#define IER_ERROR (-1)
#define IER_PARAMERR (-2)
#define IER_OWNERDRAW (-3)
#define IER_SECURITY (-4)
#define IER_SELECTION (-5)
#define IER_SCALE (-6)
#define IER_MEMERR (-7)
#define IER_NOCOMMAND (-8)
#define IER_NOGESTURE (-9)
#define IER_NOPDEVENT (-10)
#define IER_NOTINPAINT (-11)
#define IER_PENDATA (-12)

#define IEREC_NONE 0x0000
#define IEREC_GESTURE 0x0001
#define IEREC_ALL (IEREC_GESTURE)
#define IEREC_RESERVED 0xFFFE

#define IESEC_NOCOPY 0x0001
#define IESEC_NOCUT 0x0002
#define IESEC_NOPASTE 0x0004
#define IESEC_NOUNDO 0x0008
#define IESEC_NOINK 0x0010
#define IESEC_NOERASE 0x0020
#define IESEC_NOGET 0x0040
#define IESEC_NOSET 0x0080
#define IESEC_RESERVED 0xFF00

#define IESF_ALL 0x0001
#define IESF_SELECTION 0x0002
#define IESF_STROKE 0x0004

#define IESF_TIPCOLOR 0x0008
#define IESF_TIPWIDTH 0x0010
#define IESF_PENTIP (IESF_TIPCOLOR|IESF_TIPWIDTH)

#define IESI_REPLACE 0x0000
#define IESI_APPEND 0x0001

#define IN_PDEVENT ((IEN_PDEVENT<<8)|0)
#define IN_ERASEBKGND ((IEN_NULL<<8)|1)
#define IN_PREPAINT ((IEN_PAINT<<8)|2)
#define IN_PAINT ((IEN_NULL<<8)|3)
#define IN_POSTPAINT ((IEN_PAINT<<8)|4)
#define IN_MODECHANGED ((IEN_EDIT<<8)|5)
#define IN_CHANGE ((IEN_EDIT<<8)|6)
#define IN_UPDATE ((IEN_EDIT<<8)|7)
#define IN_SETFOCUS ((IEN_FOCUS<<8)|8)
#define IN_KILLFOCUS ((IEN_FOCUS<<8)|9)
#define IN_MEMERR ((IEN_NULL<<8)|10)
#define IN_HSCROLL ((IEN_SCROLL<<8)|11)
#define IN_VSCROLL ((IEN_SCROLL<<8)|12)
#define IN_GESTURE ((IEN_EDIT<<8)|13)
#define IN_COMMAND ((IEN_EDIT<<8)|14)
#define IN_CLOSE ((IEN_NULL<<8)|15)
#define IN_PROPERTIES ((IEN_PROPERTIES<<8)|16)
#endif

#ifndef NOPENINKPUT

#define LRET_DONE __MSABI_LONG(1)
#define LRET_ABORT (__MSABI_LONG(-1))
#define LRET_HRC (__MSABI_LONG(-2))
#define LRET_HPENDATA (__MSABI_LONG(-3))
#define LRET_PRIVATE (__MSABI_LONG(-4))

#define PCMR_OK 0
#define PCMR_ALREADYCOLLECTING (-1)
#define PCMR_INVALIDCOLLECTION (-2)
#define PCMR_EVENTLOCK (-3)
#define PCMR_INVALID_PACKETID (-4)
#define PCMR_TERMTIMEOUT (-5)
#define PCMR_TERMRANGE (-6)
#define PCMR_TERMPENUP (-7)
#define PCMR_TERMEX (-8)
#define PCMR_TERMBOUND (-9)
#define PCMR_APPTERMINATED (-10)
#define PCMR_TAP (-11)
#define PCMR_SELECT (-12)
#define PCMR_OVERFLOW (-13)
#define PCMR_ERROR (-14)
#define PCMR_DISPLAYERR (-15)
#define PCMR_TERMINVERT (-16)

#define PII_INKCLIPRECT 0x0001
#define PII_INKSTOPRECT 0x0002
#define PII_INKCLIPRGN 0x0004
#define PII_INKSTOPRGN 0x0008
#define PII_INKPENTIP 0x0010
#define PII_SAVEBACKGROUND 0x0020
#define PII_CLIPSTOP 0x0040

#define PIT_RGNBOUND 0x0001
#define PIT_RGNEXCLUDE 0x0002
#define PIT_TIMEOUT 0x0004
#define PIT_TAPNHOLD 0x0008
#endif

#ifndef NOPENMISC

#define CL_NULL 0
#define CL_MINIMUM 1
#define CL_MAXIMUM 100
#define cwRcReservedMax 8
#define ENUM_MINIMUM 1
#define ENUM_MAXIMUM 4096

#define HKP_SETHOOK 0
#define HKP_UNHOOK 0xFFFF

#define HWR_RESULTS 0
#define HWR_APPWIDE 1

#define iSycNull (-1)
#define LPDFNULL ((LPDF)NULL)
#define MAXDICTIONARIES 16
#define wPntAll (UINT)0xFFFF
#define cbRcLanguageMax 44
#define cbRcUserMax 32
#define cbRcrgbfAlcMax 32
#define RC_WDEFAULT 0xffff
#define RC_LDEFAULT __MSABI_LONG(0xffffffff)
#define RC_WDEFAULTFLAGS 0x8000
#define RC_LDEFAULTFLAGS __MSABI_LONG(0x80000000)

#define CWR_REPLACECR 0x0001
#define CWR_STRIPCR CWR_REPLACECR
#define CWR_STRIPLF 0x0002
#define CWR_REPLACETAB 0x0004
#define CWR_STRIPTAB CWR_REPLACETAB
#define CWR_SINGLELINEEDIT (CWR_REPLACECR|CWR_STRIPLF|CWR_REPLACETAB)
#define CWR_INSERT 0x0008
#define CWR_TITLE 0x0010
#define CWR_SIMPLE 0x0040
#define CWR_HEDIT 0x0080
#define CWR_KEYBOARD 0x0100
#define CWR_BOXES 0x0200

#define CWRK_DEFAULT 0
#define CWRK_BASIC 1
#define CWRK_FULL 2
#define CWRK_NUMPAD 3
#define CWRK_TELPAD 4

#ifdef JAPAN

#define CBCAPTIONCWX 256
#define CKBCWX 6
#define XCWX 20
#define YCWX 20
#define CXCWX 300
#define CYCWX 200

#define CWX_TOPMOST __MSABI_LONG(0x00000001)
#define CWX_NOTOOLTIPS __MSABI_LONG(0x00000002)
#define CWX_EPERIOD __MSABI_LONG(0x00000004)
#define CWX_ECOMMA __MSABI_LONG(0x00000008)
#define CWX_DEFAULT __MSABI_LONG(0x00000000)

#define CWXA_CONTEXT 0x0001
#define CWXA_KBD 0x0002
#define CWXA_STATE 0x0004
#define CWXA_PTUL 0x0008
#define CWXA_SIZE 0x0010
#define CWXA_NOUPDATEMRU 0x0020

#define CWXK_HW 0
#define CWXK_FIRST 0x0100
#define CWXK_50 0x0100
#define CWXK_QWERTY 0x0101
#define CWXK_NUM 0x0102
#define CWXK_KANJI 0x0103
#define CWXK_CODE 0x0104
#define CWXK_YOMI 0x0105

#define CWXKS_DEFAULT 0xffff
#define CWXKS_ZEN 0
#define CWXKS_HAN 1
#define CWXKS_ROMAZEN 2
#define CWXKS_ROMAHAN 3
#define CWXKS_HIRAZEN 4
#define CWXKS_KATAZEN 5
#define CWXKS_KATAHAN 6

#define CWXR_ERROR -1
#define CWXR_UNMODIFIED 0
#define CWXR_MODIFIED 1
#endif

#ifdef JAPAN
#define GPMI_OK __MSABI_LONG(0)
#define GPMI_INVALIDPMI __MSABI_LONG(0x8000)
#endif

#define INKWIDTH_MINIMUM 0
#define INKWIDTH_MAXIMUM 15

#define PMI_RCCHANGE 0

#define PMI_BEDIT 1
#define PMI_CXTABLET 3
#define PMI_CYTABLET 4
#define PMI_PENTIP 6
#define PMI_ENABLEFLAGS 7
#define PMI_TIMEOUT 8
#define PMI_TIMEOUTGEST 9
#define PMI_TIMEOUTSEL 10
#define PMI_SYSFLAGS 11
#define PMI_INDEXFROMRGB 12
#define PMI_RGBFROMINDEX 13
#define PMI_SYSREC 14
#define PMI_TICKREF 15

#define PMI_SAVE 0x1000

#ifdef JAPAN

#define GPR_CURSPEN 1
#define GPR_CURSCOPY 2
#define GPR_CURSUNKNOWN 3
#define GPR_CURSERASE 4

#define GPR_BMCRMONO 5
#define GPR_BMLFMONO 6
#define GPR_BMTABMONO 7
#define GPR_BMDELETE 8
#define GPR_BMLENSBTN 9

#ifdef JAPAN
#define GPR_BMHSPMONO 10
#define GPR_BMZSPMONO 11
#endif
#endif

#define PWE_AUTOWRITE 0x0001
#define PWE_ACTIONHANDLES 0x0002
#define PWE_INPUTCURSOR 0x0004
#define PWE_LENS 0x0008

#define PWF_RC1 0x0001
#define PWF_PEN 0x0004
#define PWF_INKDISPLAY 0x0008
#define PWF_RECOGNIZER 0x0010
#define PWF_BEDIT 0x0100
#define PWF_HEDIT 0x0200
#define PWF_IEDIT 0x0400
#define PWF_ENHANCED 0x1000
#define PWF_FULL PWF_RC1|PWF_PEN|PWF_INKDISPLAY|PWF_RECOGNIZER| PWF_BEDIT|PWF_HEDIT |PWF_IEDIT|PWF_ENHANCED

#define RPA_DEFAULT 0x0001
#define RPA_HEDIT 0x0001
#define RPA_KANJIFIXEDBEDIT 0x0002
#define RPA_DBCSPRIORITY 0x0004
#define RPA_SBCSPRIORITY 0x0008

#define PMIR_OK __MSABI_LONG(0)
#define PMIR_INDEX (__MSABI_LONG(-1))
#define PMIR_VALUE (__MSABI_LONG(-2))
#define PMIR_INVALIDBOXEDITINFO (__MSABI_LONG(-3))
#define PMIR_INIERROR (__MSABI_LONG(-4))
#define PMIR_ERROR (__MSABI_LONG(-5))
#define PMIR_NA (__MSABI_LONG(-6))

#ifdef JAPAN
#define SPMI_OK __MSABI_LONG(0)
#define SPMI_INVALIDBOXEDITINFO __MSABI_LONG(1)
#define SPMI_INIERROR __MSABI_LONG(2)
#define SPMI_INVALIDPMI __MSABI_LONG(0x8000)
#endif
#endif

#ifndef NOPENRC1

#define GGRC_OK 0
#define GGRC_DICTBUFTOOSMALL 1
#define GGRC_PARAMERROR 2
#define GGRC_NA 3

#define RCD_DEFAULT 0
#define RCD_LR 1
#define RCD_RL 2
#define RCD_TB 3
#define RCD_BT 4

#define RCIP_ALLANSICHAR 0x0001
#define RCIP_MASK 0x0001

#define RCO_NOPOINTEREVENT __MSABI_LONG(0x00000001)
#define RCO_SAVEALLDATA __MSABI_LONG(0x00000002)
#define RCO_SAVEHPENDATA __MSABI_LONG(0x00000004)
#define RCO_NOFLASHUNKNOWN __MSABI_LONG(0x00000008)
#define RCO_TABLETCOORD __MSABI_LONG(0x00000010)
#define RCO_NOSPACEBREAK __MSABI_LONG(0x00000020)
#define RCO_NOHIDECURSOR __MSABI_LONG(0x00000040)
#define RCO_NOHOOK __MSABI_LONG(0x00000080)
#define RCO_BOXED __MSABI_LONG(0x00000100)
#define RCO_SUGGEST __MSABI_LONG(0x00000200)
#define RCO_DISABLEGESMAP __MSABI_LONG(0x00000400)
#define RCO_NOFLASHCURSOR __MSABI_LONG(0x00000800)
#define RCO_BOXCROSS __MSABI_LONG(0x00001000)
#define RCO_COLDRECOG __MSABI_LONG(0x00008000)
#define RCO_SAVEBACKGROUND __MSABI_LONG(0x00010000)
#define RCO_DODEFAULT __MSABI_LONG(0x00020000)

#define RCOR_NORMAL 1
#define RCOR_RIGHT 2
#define RCOR_UPSIDEDOWN 3
#define RCOR_LEFT 4

#define RCP_LEFTHAND 0x0001
#define RCP_MAPCHAR 0x0004

#define RCRT_DEFAULT 0x0000
#define RCRT_UNIDENTIFIED 0x0001
#define RCRT_GESTURE 0x0002
#define RCRT_NOSYMBOLMATCH 0x0004
#define RCRT_PRIVATE 0x4000
#define RCRT_NORECOG 0x8000
#define RCRT_ALREADYPROCESSED 0x0008
#define RCRT_GESTURETRANSLATED 0x0010
#define RCRT_GESTURETOKEYS 0x0020

#define RRM_STROKE 0
#define RRM_SYMBOL 1
#define RRM_WORD 2
#define RRM_NEWLINE 3
#define RRM_COMPLETE 16

#define SGRC_OK 0x0000
#define SGRC_USER 0x0001
#define SGRC_PARAMERROR 0x0002
#define SGRC_RC 0x0004
#define SGRC_RECOGNIZER 0x0008
#define SGRC_DICTIONARY 0x0010
#define SGRC_INIFILE 0x0020
#define SGRC_NA 0x8000
#endif

#ifndef NOPENTARGET

#define TPT_CLOSEST 0x0001
#define TPT_INTERSECTINK 0x0002
#define TPT_TEXTUAL 0x0004
#define TPT_DEFAULT (TPT_TEXTUAL | TPT_INTERSECTINK | TPT_CLOSEST)
#endif

#ifndef NOPENVIRTEVENT

#define VWM_MOUSEMOVE 0x0001
#define VWM_MOUSELEFTDOWN 0x0002
#define VWM_MOUSELEFTUP 0x0004
#define VWM_MOUSERIGHTDOWN 0x0008
#define VWM_MOUSERIGHTUP 0x0010
#endif
#endif

#ifndef NOPENMSGS

#ifndef NOPENRC1
#define WM_RCRESULT (WM_PENWINFIRST+1)
#define WM_HOOKRCRESULT (WM_PENWINFIRST+2)
#endif

#define WM_PENMISCINFO (WM_PENWINFIRST+3)
#define WM_GLOBALRCCHANGE (WM_PENWINFIRST+3)

#ifndef NOPENAPPS
#define WM_SKB (WM_PENWINFIRST+4)
#endif

#define WM_PENCTL (WM_PENWINFIRST+5)
#define WM_HEDITCTL (WM_PENWINFIRST+5)

#define HE_GETUNDERLINE 7
#define HE_SETUNDERLINE 8
#define HE_GETINKHANDLE 9
#define HE_SETINKMODE 10
#define HE_STOPINKMODE 11
#define HE_DEFAULTFONT 13
#define HE_CHARPOSITION 14
#define HE_CHAROFFSET 15
#define HE_GETBOXLAYOUT 20
#define HE_SETBOXLAYOUT 21
#ifdef JAPAN
#define HE_KKCONVERT 30
#define HE_GETKKCONVERT 31
#define HE_CANCELKKCONVERT 32
#define HE_FIXKKCONVERT 33
#define HE_GETKKSTATUS 34
#define HE_SETCONVERTRANGE 35
#define HE_GETCONVERTRANGE 36
#define HE_PUTCONVERTCHAR 37
#endif
#define HE_ENABLEALTLIST 40
#define HE_SHOWALTLIST 41
#define HE_HIDEALTLIST 42
#ifndef JAPAN
#define HE_GETLENSTYPE 43
#define HE_SETLENSTYPE 44
#endif

#ifdef JAPAN

#define HEKK_DEFAULT 0
#define HEKK_CONVERT 1
#define HEKK_CANDIDATE 2
#define HEKK_DBCSCHAR 3
#define HEKK_SBCSCHAR 4
#define HEKK_HIRAGANA 5
#define HEKK_KATAKANA 6

#define HEKKR_NOCONVERT 0
#define HEKKR_PRECONVERT 1
#define HEKKR_CONVERT 2
#endif

#define HEP_NORECOG 0
#define HEP_RECOG 1
#define HEP_WAITFORTAP 2

#define HN_ENDREC 4
#define HN_DELAYEDRECOGFAIL 5
#define HN_RESULT 20
#ifdef JAPAN
#define HN_ENDKKCONVERT 30
#endif
#define HN_BEGINDIALOG 40

#define HN_ENDDIALOG 41

#ifndef NOPENIEDIT

#define IE_GETMODIFY (EM_GETMODIFY)
#define IE_SETMODIFY (EM_SETMODIFY)
#define IE_CANUNDO (EM_CANUNDO)
#define IE_UNDO (EM_UNDO)
#define IE_EMPTYUNDOBUFFER (EM_EMPTYUNDOBUFFER)

#define IE_MSGFIRST (WM_USER+150)

#define IE_GETINK (IE_MSGFIRST+0)
#define IE_SETINK (IE_MSGFIRST+1)
#define IE_GETPENTIP (IE_MSGFIRST+2)
#define IE_SETPENTIP (IE_MSGFIRST+3)
#define IE_GETERASERTIP (IE_MSGFIRST+4)
#define IE_SETERASERTIP (IE_MSGFIRST+5)
#define IE_GETBKGND (IE_MSGFIRST+6)
#define IE_SETBKGND (IE_MSGFIRST+7)
#define IE_GETGRIDORIGIN (IE_MSGFIRST+8)
#define IE_SETGRIDORIGIN (IE_MSGFIRST+9)
#define IE_GETGRIDPEN (IE_MSGFIRST+10)
#define IE_SETGRIDPEN (IE_MSGFIRST+11)
#define IE_GETGRIDSIZE (IE_MSGFIRST+12)
#define IE_SETGRIDSIZE (IE_MSGFIRST+13)
#define IE_GETMODE (IE_MSGFIRST+14)
#define IE_SETMODE (IE_MSGFIRST+15)
#define IE_GETINKRECT (IE_MSGFIRST+16)

#define IE_GETAPPDATA (IE_MSGFIRST+34)
#define IE_SETAPPDATA (IE_MSGFIRST+35)
#define IE_GETDRAWOPTS (IE_MSGFIRST+36)
#define IE_SETDRAWOPTS (IE_MSGFIRST+37)
#define IE_GETFORMAT (IE_MSGFIRST+38)
#define IE_SETFORMAT (IE_MSGFIRST+39)
#define IE_GETINKINPUT (IE_MSGFIRST+40)
#define IE_SETINKINPUT (IE_MSGFIRST+41)
#define IE_GETNOTIFY (IE_MSGFIRST+42)
#define IE_SETNOTIFY (IE_MSGFIRST+43)
#define IE_GETRECOG (IE_MSGFIRST+44)
#define IE_SETRECOG (IE_MSGFIRST+45)
#define IE_GETSECURITY (IE_MSGFIRST+46)
#define IE_SETSECURITY (IE_MSGFIRST+47)
#define IE_GETSEL (IE_MSGFIRST+48)
#define IE_SETSEL (IE_MSGFIRST+49)
#define IE_DOCOMMAND (IE_MSGFIRST+50)
#define IE_GETCOMMAND (IE_MSGFIRST+51)
#define IE_GETCOUNT (IE_MSGFIRST+52)
#define IE_GETGESTURE (IE_MSGFIRST+53)
#define IE_GETMENU (IE_MSGFIRST+54)
#define IE_GETPAINTDC (IE_MSGFIRST+55)
#define IE_GETPDEVENT (IE_MSGFIRST+56)
#define IE_GETSELCOUNT (IE_MSGFIRST+57)
#define IE_GETSELITEMS (IE_MSGFIRST+58)
#define IE_GETSTYLE (IE_MSGFIRST+59)
#endif

#ifndef NOPENHEDIT

#define CIH_NOGDMSG 0x0001
#define CIH_NOACTIONHANDLE 0x0002
#define CIH_NOEDITTEXT 0x0004
#define CIH_NOFLASHCURSOR 0x0008
#endif

#ifndef NOPENBEDIT

#define HEAL_DEFAULT __MSABI_LONG(-1)

#define BEI_FACESIZE 32
#define BEIF_BOXCROSS 0x0001

#define BESC_DEFAULT 0
#define BESC_ROMANFIXED 1
#define BESC_KANJIFIXED 2
#define BESC_USERDEFINED 3

#define CIB_NOGDMSG 0x0001
#define CIB_NOACTIONHANDLE 0x0002
#define CIB_NOFLASHCURSOR 0x0004
#ifdef JAPAN
#define CIB_NOWRITING 0x0010
#endif

#define BXD_CELLWIDTH 12
#define BXD_CELLHEIGHT 16
#define BXD_BASEHEIGHT 13
#define BXD_BASEHORZ 0
#define BXD_MIDFROMBASE 0
#define BXD_CUSPHEIGHT 2
#define BXD_ENDCUSPHEIGHT 4

#define BXDK_CELLWIDTH 32
#define BXDK_CELLHEIGHT 32
#define BXDK_BASEHEIGHT 28
#define BXDK_BASEHORZ 0
#define BXDK_MIDFROMBASE 0
#define BXDK_CUSPHEIGHT 28
#define BXDK_ENDCUSPHEIGHT 10
#endif

#define WM_PENMISC (WM_PENWINFIRST+6)

#define PMSC_BEDITCHANGE 1
#define PMSC_GETPCMINFO 5
#define PMSC_SETPCMINFO 6
#define PMSC_GETINKINGINFO 7
#define PMSC_SETINKINGINFO 8
#define PMSC_GETHRC 9
#define PMSC_SETHRC 10
#define PMSC_GETSYMBOLCOUNT 11
#define PMSC_GETSYMBOLS 12
#define PMSC_SETSYMBOLS 13
#define PMSC_LOADPW 15
#define PMSC_INKSTOP 16

#define PMSCL_UNLOADED __MSABI_LONG(0)
#define PMSCL_LOADED __MSABI_LONG(1)
#define PMSCL_UNLOADING __MSABI_LONG(2)

#define WM_CTLINIT (WM_PENWINFIRST+7)

#define CTLINIT_HEDIT 1
#define CTLINIT_BEDIT 7
#define CTLINIT_IEDIT 9
#define CTLINIT_MAX 10

#define WM_PENEVENT (WM_PENWINFIRST+8)

#define PE_PENDOWN 1
#define PE_PENUP 2
#define PE_PENMOVE 3
#define PE_TERMINATING 4
#define PE_TERMINATED 5
#define PE_BUFFERWARNING 6
#define PE_BEGININPUT 7
#define PE_SETTARGETS 8
#define PE_BEGINDATA 9
#define PE_MOREDATA 10
#define PE_ENDDATA 11
#define PE_GETPCMINFO 12
#define PE_GETINKINGINFO 13
#define PE_ENDINPUT 14

#define PE_RESULT 15
#endif

#ifndef RC_INVOKED

#ifndef NOPENDRIVER

#define FPenUpX(x) ((WINBOOL)(((x) & BITPENUP)!=0))
#define GetWEventRef() (LOWORD(GetMessageExtraInfo()))
#endif

#ifndef NOPENALC

#define MpAlcB(lprc,i) ((lprc)->rgbfAlc[((i) & 0xff) >> 3])
#define MpIbf(i) ((BYTE)(1 << ((i) & 7)))
#define SetAlcBitAnsi(lprc,i) do {MpAlcB(lprc,i) |= MpIbf(i);} while (0)
#define ResetAlcBitAnsi(lprc,i) do {MpAlcB(lprc,i) &= ~MpIbf(i);} while (0)
#define IsAlcBitAnsi(lprc,i) ((MpAlcB(lprc,i) & MpIbf(i))!=0)
#endif

#ifndef NOPENDATA

#define DrawPenDataFmt(hdc,lprect,hpndt) DrawPenDataEx(hdc,lprect,hpndt,0,IX_END,0,IX_END,NULL,NULL,0)
#endif

#ifndef NOPENHRC

#define dwDiffAT(at1,at2) (1000*((at2).sec - (at1).sec) - (DWORD)(at1).ms + (DWORD)(at2).ms)
#define FLTAbsTime(at1,at2) ((at1).sec < (at2).sec || ((at1).sec==(at2).sec && (at1).ms < (at2).ms))
#define FLTEAbsTime(at1,at2) ((at1).sec < (at2).sec || ((at1).sec==(at2).sec && (at1).ms <= (at2).ms))
#define FEQAbsTime(at1,at2) ((at1).sec==(at2).sec && (at1).ms==(at2).ms)
#define FAbsTimeInInterval(at,lpi) (FLTEAbsTime((lpi)->atBegin,at) && FLTEAbsTime(at,(lpi)->atEnd))
#define FIntervalInInterval(lpiT,lpiS) (FLTEAbsTime((lpiS)->atBegin,(lpiT)->atBegin) && FLTEAbsTime((lpiT)->atEnd,(lpiS)->atEnd))
#define FIntervalXInterval(lpiT,lpiS) (!(FLTAbsTime((lpiT)->atEnd,(lpiS)->atBegin) || FLTAbsTime((lpiS)->atEnd,(lpiT)->atBegin)))
#define dwDurInterval(lpi) dwDiffAT((lpi)->atBegin,(lpi)->atEnd)
#define MakeAbsTime(lpat,sec,ms) do { (lpat)->sec = sec + ((ms) / 1000); (lpat)->ms = (ms) % 1000; } while (0)

#define FIsSpecial(syv) (HIWORD((syv))==SYVHI_SPECIAL)
#define FIsAnsi(syv) (HIWORD((syv))==SYVHI_ANSI)
#define FIsGesture(syv) (HIWORD((syv))==SYVHI_GESTURE)
#define FIsKanji(syv) (HIWORD((syv))==SYVHI_KANJI)
#define FIsShape(syv) (HIWORD((syv))==SYVHI_SHAPE)
#define FIsUniCode(syv) (HIWORD((syv))==SYVHI_UNICODE)
#define FIsVKey(syv) (HIWORD((syv))==SYVHI_VKEY)

#define ChSyvToAnsi(syv) ((BYTE) (LOBYTE(LOWORD((syv)))))
#define WSyvToKanji(syv) ((WORD) (LOWORD((syv))))
#define SyvCharacterToSymbol(c) ((LONG)(unsigned char)(c) | 0x00010000)
#define SyvKanjiToSymbol(c) ((LONG)(UINT)(c) | 0x00030000)

#define FIsSelectGesture(syv) ((syv) >= SYVSELECTFIRST && (syv) <= SYVSELECTLAST)

#define FIsStdGesture(syv) (FIsSelectGesture(syv) || (syv)==SYV_CLEAR || (syv)==SYV_HELP || (syv)==SYV_EXTENDSELECT || (syv)==SYV_UNDO || (syv)==SYV_COPY || (syv)==SYV_CUT || (syv)==SYV_PASTE || (syv)==SYV_CLEARWORD || (syv)==SYV_KKCONVERT || (syv)==SYV_USER || (syv)==SYV_CORRECT)

#define FIsAnsiGesture(syv) ((syv)==SYV_BACKSPACE || (syv)==SYV_TAB || (syv)==SYV_RETURN || (syv)==SYV_SPACE)
#endif

#ifndef NOPENINKPUT
#define SubPenMsgFromWpLp(wp,lp) (LOWORD(wp))
#define EventRefFromWpLp(wp,lp) (HIWORD(wp))
#define TerminationFromWpLp(wp,lp) ((int)HIWORD(wp))
#define HpcmFromWpLp(wp,lp) ((HPCM)(lp))
#endif

#ifndef NOPENTARGET
#define HwndFromHtrg(htrg) ((HWND)(DWORD)(htrg))
#define HtrgFromHwnd(hwnd) ((HTRG)(UINT)(hwnd))
#endif

  typedef LONG ALC;
  typedef int CL;
  typedef UINT HKP;
  typedef int REC;
  typedef LONG SYV;

#ifndef DECLARE_HANDLE32
#define DECLARE_HANDLE32(name) struct name##__ { int unused; }; typedef const struct name##__ *name
#endif

  DECLARE_HANDLE32(HTRG);
  DECLARE_HANDLE(HPCM);
  DECLARE_HANDLE(HPENDATA);
  DECLARE_HANDLE(HREC);

  typedef ALC *LPALC;
  typedef LPVOID LPOEM;
  typedef SYV *LPSYV;
  typedef HPENDATA *LPHPENDATA;

  typedef int (CALLBACK *ENUMPROC)(LPSYV,int,VOID *);
  typedef int (CALLBACK *LPDF)(int,LPVOID,LPVOID,int,DWORD,DWORD);
  typedef WINBOOL (CALLBACK *RCYIELDPROC)(VOID);

  typedef struct tagABSTIME {
    DWORD sec;
    UINT ms;
  } ABSTIME,*LPABSTIME;

#ifndef NOPENHEDIT
  typedef struct tagCTLINITHEDIT {
    DWORD cbSize;
    HWND hwnd;
    int id;
    DWORD dwFlags;
    DWORD dwReserved;
  } CTLINITHEDIT,*LPCTLINITHEDIT;
#endif

#ifndef NOPENBEDIT

  typedef struct tagBOXLAYOUT {
    int cyCusp;
    int cyEndCusp;
    UINT style;
    DWORD dwReserved1;
    DWORD dwReserved2;
    DWORD dwReserved3;
  } BOXLAYOUT,*LPBOXLAYOUT;

  typedef struct tagCTLINITBEDIT {
    DWORD cbSize;
    HWND hwnd;
    int id;
    WORD wSizeCategory;
    WORD wFlags;
    DWORD dwReserved;
  } CTLINITBEDIT,*LPCTLINITBEDIT;

  typedef struct tagBOXEDITINFO {
    int cxBox;
    int cyBox;
    int cxBase;
    int cyBase;
    int cyMid;
    BOXLAYOUT boxlayout;
    UINT wFlags;
    BYTE szFaceName[BEI_FACESIZE];
    UINT wFontHeight;
    UINT rgwReserved[8];
  } BOXEDITINFO,*LPBOXEDITINFO;
#endif

#ifndef NOPENCTL

  typedef struct tagRECTOFS {
    int dLeft;
    int dTop;
    int dRight;
    int dBottom;
  } RECTOFS,*LPRECTOFS;
#endif

#ifndef NOPENDATA
  typedef struct tagPENDATAHEADER {
    UINT wVersion;
    UINT cbSizeUsed;
    UINT cStrokes;
    UINT cPnt;
    UINT cPntStrokeMax;
    RECT rectBound;
    UINT wPndts;
    int nInkWidth;
    DWORD rgbInk;
  } PENDATAHEADER,*LPPENDATAHEADER,*LPPENDATA;

  typedef struct tagSTROKEINFO {
    UINT cPnt;
    UINT cbPnts;
    UINT wPdk;
    DWORD dwTick;
  } STROKEINFO,*LPSTROKEINFO;

  typedef struct tagPENTIP {
    DWORD cbSize;
    BYTE btype;
    BYTE bwidth;
    BYTE bheight;
    BYTE bOpacity;
    COLORREF rgb;
    DWORD dwFlags;
    DWORD dwReserved;
  } PENTIP,*LPPENTIP;

  typedef WINBOOL (CALLBACK *ANIMATEPROC)(HPENDATA,UINT,UINT,UINT *,LPARAM);

  typedef struct tagANIMATEINFO {
    DWORD cbSize;
    UINT uSpeedPct;
    UINT uPeriodCB;
    UINT fuFlags;
    LPARAM lParam;
    DWORD dwReserved;
  } ANIMATEINFO,*LPANIMATEINFO;
#endif

#ifndef NOPENDRIVER
  typedef struct tagOEMPENINFO {
    UINT wPdt;
    UINT wValueMax;
    UINT wDistinct;
  } OEMPENINFO,*LPOEMPENINFO;

  typedef struct tagPENPACKET {
    UINT wTabletX;
    UINT wTabletY;
    UINT wPDK;
    UINT rgwOemData[MAXOEMDATAWORDS];
  } PENPACKET,*LPPENPACKET;

  typedef struct tagOEM_PENPACKET {
    UINT wTabletX;
    UINT wTabletY;
    UINT wPDK;
    UINT rgwOemData[MAXOEMDATAWORDS];
    DWORD dwTime;
  } OEM_PENPACKET,*LPOEM_PENPACKET;

  typedef struct tagPENINFO {
    UINT cxRawWidth;
    UINT cyRawHeight;
    UINT wDistinctWidth;
    UINT wDistinctHeight;
    int nSamplingRate;
    int nSamplingDist;
    LONG lPdc;
    int cPens;
    int cbOemData;
    OEMPENINFO rgoempeninfo[MAXOEMDATAWORDS];
    UINT rgwReserved[7];
    UINT fuOEM;
  } PENINFO,*LPPENINFO;

  typedef struct tagCALBSTRUCT {
    int wOffsetX;
    int wOffsetY;
    int wDistinctWidth;
    int wDistinctHeight;
  } CALBSTRUCT,*LPCALBSTRUCT;

  typedef WINBOOL (CALLBACK *LPFNRAWHOOK)(LPPENPACKET);
#endif

#ifndef NOPENHRC
  DECLARE_HANDLE32(HRC);
  DECLARE_HANDLE32(HRCRESULT);
  DECLARE_HANDLE32(HWL);
  DECLARE_HANDLE32(HRECHOOK);

  typedef HRC *LPHRC;
  typedef HRCRESULT *LPHRCRESULT;
  typedef HWL *LPHWL;

  typedef WINBOOL (CALLBACK *HRCRESULTHOOKPROC)(HREC,HRC,UINT,UINT,UINT,LPVOID);

  DECLARE_HANDLE(HINKSET);
  typedef HINKSET *LPHINKSET;

  typedef struct tagINTERVAL {
    ABSTIME atBegin;
    ABSTIME atEnd;
  } INTERVAL,*LPINTERVAL;

  typedef struct tagBOXRESULTS {
    UINT indxBox;
    HINKSET hinksetBox;
    SYV rgSyv[1];
  } BOXRESULTS,*LPBOXRESULTS;

  typedef struct tagGUIDE {
    int xOrigin;
    int yOrigin;
    int cxBox;
    int cyBox;
    int cxBase;
    int cyBase;
    int cHorzBox;
    int cVertBox;
    int cyMid;
  } GUIDE,*LPGUIDE;
#endif

#ifndef NOPENIEDIT
  typedef struct tagCTLINITIEDIT {
    DWORD cbSize;
    HWND hwnd;
    int id;
    WORD ieb;
    WORD iedo;
    WORD iei;
    WORD ien;
    WORD ierec;
    WORD ies;
    WORD iesec;
    WORD pdts;
    HPENDATA hpndt;
    HGDIOBJ hgdiobj;
    HPEN hpenGrid;
    POINT ptOrgGrid;
    WORD wVGrid;
    WORD wHGrid;
    DWORD dwApp;
    DWORD dwReserved;
  } CTLINITIEDIT,*LPCTLINITIEDIT;

  typedef struct tagPDEVENT {
    DWORD cbSize;
    HWND hwnd;
    UINT wm;
    WPARAM wParam;
    LPARAM lParam;
    POINT pt;
    WINBOOL fPen;
    LONG lExInfo;
    DWORD dwReserved;
  } PDEVENT,*LPPDEVENT;

  typedef struct tagSTRKFMT {
    DWORD cbSize;
    UINT iesf;
    UINT iStrk;
    PENTIP tip;
    DWORD dwUser;
    DWORD dwReserved;
  } STRKFMT,*LPSTRKFMT;
#endif

#ifndef NOPENINKPUT

  typedef struct tagPCMINFO {
    DWORD cbSize;
    DWORD dwPcm;
    RECT rectBound;
    RECT rectExclude;
    HRGN hrgnBound;
    HRGN hrgnExclude;
    DWORD dwTimeout;
  } PCMINFO,*LPPCMINFO;

  typedef struct tagINKINGINFO {
    DWORD cbSize;
    UINT wFlags;
    PENTIP tip;
    RECT rectClip;
    RECT rectInkStop;
    HRGN hrgnClip;
    HRGN hrgnInkStop;
  } INKINGINFO,*LPINKINGINFO;
#endif

#ifndef NOPENRC1

  typedef struct tagSYC {
    UINT wStrokeFirst;
    UINT wPntFirst;
    UINT wStrokeLast;
    UINT wPntLast;
    WINBOOL fLastSyc;
  } SYC,*LPSYC;

  typedef struct tagSYE {
    SYV syv;
    LONG lRecogVal;
    CL cl;
    int iSyc;
  } SYE,*LPSYE;

  typedef struct tagSYG {
    POINT rgpntHotSpots[MAXHOTSPOT];
    int cHotSpot;
    int nFirstBox;
    LONG lRecogVal;
    LPSYE lpsye;
    int cSye;
    LPSYC lpsyc;
    int cSyc;
  } SYG,*LPSYG;

  typedef struct tagRC {
    HREC hrec;
    HWND hwnd;
    UINT wEventRef;
    UINT wRcPreferences;
    LONG lRcOptions;
    RCYIELDPROC lpfnYield;
    BYTE lpUser[cbRcUserMax];
    UINT wCountry;
    UINT wIntlPreferences;
    char lpLanguage[cbRcLanguageMax];
    LPDF rglpdf[MAXDICTIONARIES];
    UINT wTryDictionary;
    CL clErrorLevel;
    ALC alc;
    ALC alcPriority;
    BYTE rgbfAlc[cbRcrgbfAlcMax];
    UINT wResultMode;
    UINT wTimeOut;
    LONG lPcm;
    RECT rectBound;
    RECT rectExclude;
    GUIDE guide;
    UINT wRcOrient;
    UINT wRcDirect;
    int nInkWidth;
    COLORREF rgbInk;
    DWORD dwAppParam;
    DWORD dwDictParam;
    DWORD dwRecognizer;
    UINT rgwReserved[cwRcReservedMax];
  } RC,*LPRC;

  typedef struct tagRCRESULT {
    SYG syg;
    UINT wResultsType;
    int cSyv;
    LPSYV lpsyv;
    HANDLE hSyv;
    int nBaseLine;
    int nMidLine;
    HPENDATA hpendata;
    RECT rectBoundInk;
    POINT pntEnd;
    LPRC lprc;
  } RCRESULT,*LPRCRESULT;

  typedef int (CALLBACK *LPFUNCRESULTS)(LPRCRESULT,REC);
#endif

#ifndef NOPENTARGET

  typedef struct tagTARGET {
    DWORD dwFlags;
    DWORD idTarget;
    HTRG htrgTarget;
    RECTL rectBound;
    DWORD dwData;
    RECTL rectBoundInk;
    RECTL rectBoundLastInk;
  } TARGET,*LPTARGET;

  typedef struct tagTARGINFO {
    DWORD cbSize;
    DWORD dwFlags;
    HTRG htrgOwner;
    WORD cTargets;
    WORD iTargetLast;
    TARGET rgTarget[1];
  } TARGINFO,*LPTARGINFO;

  typedef struct tagINPPARAMS {
    DWORD cbSize;
    DWORD dwFlags;
    HPENDATA hpndt;
    TARGET target;
  } INPPARAMS,*LPINPPARAMS;
#endif

#ifdef JAPAN
  typedef struct tagCWX {
    DWORD cbSize;
    WORD wApplyFlags;
    HWND hwndText;
    HRC hrc;
    char szCaption[CBCAPTIONCWX];
    DWORD dwEditStyle;
    DWORD dwSel;
    DWORD dwFlags;
    WORD ixkb;
    WORD rgState[CKBCWX];
    POINT ptUL;
    SIZE sizeHW;
  } CWX,*LPCWX;
#endif

  LRESULT CALLBACK DefPenWindowProc(HWND,UINT,WPARAM,LPARAM);

#ifndef NOPENAPPS
  WINBOOL WINAPI ShowKeyboard(HWND,UINT,LPPOINT,LPSKBINFO);
#endif

#ifndef NOPENDATA

#ifndef NOPENAPIFUN
  LPPENDATA WINAPI BeginEnumStrokes(HPENDATA);
  LPPENDATA WINAPI EndEnumStrokes(HPENDATA);
  HPENDATA WINAPI CompactPenData(HPENDATA,UINT);
  HPENDATA WINAPI CreatePenData(LPPENINFO,int,UINT,UINT);
  VOID WINAPI DrawPenData(HDC,LPRECT,HPENDATA);
  WINBOOL WINAPI GetPenDataStroke(LPPENDATA,UINT,LPPOINT *,LPVOID *,LPSTROKEINFO);
#endif
  HPENDATA WINAPI AddPointsPenData(HPENDATA,LPPOINT,LPVOID,LPSTROKEINFO);
  int WINAPI CompressPenData(HPENDATA,UINT,DWORD);
  HPENDATA WINAPI CreatePenDataEx(LPPENINFO,UINT,UINT,UINT);
  HRGN WINAPI CreatePenDataRegion(HPENDATA,UINT);
  WINBOOL WINAPI DestroyPenData(HPENDATA);
  int WINAPI DrawPenDataEx(HDC,LPRECT,HPENDATA,UINT,UINT,UINT,UINT,ANIMATEPROC,LPANIMATEINFO,UINT);
  HPENDATA WINAPI DuplicatePenData(HPENDATA,UINT);
  int WINAPI ExtractPenDataPoints(HPENDATA,UINT,UINT,UINT,LPPOINT,LPVOID,UINT);
  int WINAPI ExtractPenDataStrokes(HPENDATA,UINT,LPARAM,LPHPENDATA,UINT);
  int WINAPI GetPenDataAttributes(HPENDATA,LPVOID,UINT);
  WINBOOL WINAPI GetPenDataInfo(HPENDATA,LPPENDATAHEADER,LPPENINFO,DWORD);
  WINBOOL WINAPI GetPointsFromPenData(HPENDATA,UINT,UINT,UINT,LPPOINT);
  int WINAPI GetStrokeAttributes(HPENDATA,UINT,LPVOID,UINT);
  int WINAPI GetStrokeTableAttributes(HPENDATA,UINT,LPVOID,UINT);
  int WINAPI HitTestPenData(HPENDATA,LPPOINT,UINT,UINT *,UINT *);
  int WINAPI InsertPenData(HPENDATA,HPENDATA,UINT);
  int WINAPI InsertPenDataPoints(HPENDATA,UINT,UINT,UINT,LPPOINT,LPVOID);
  int WINAPI InsertPenDataStroke(HPENDATA,UINT,LPPOINT,LPVOID,LPSTROKEINFO);
  WINBOOL WINAPI MetricScalePenData(HPENDATA,UINT);
  WINBOOL WINAPI OffsetPenData(HPENDATA,int,int);
  LONG WINAPI PenDataFromBuffer(LPHPENDATA,UINT,LPBYTE,LONG,LPDWORD);
  LONG WINAPI PenDataToBuffer(HPENDATA,LPBYTE,LONG,LPDWORD);
  WINBOOL WINAPI RedisplayPenData(HDC,HPENDATA,LPPOINT,LPPOINT,int,DWORD);
  int WINAPI RemovePenDataStrokes(HPENDATA,UINT,UINT);
  WINBOOL WINAPI ResizePenData(HPENDATA,LPRECT);
  int WINAPI SetStrokeAttributes(HPENDATA,UINT,LPARAM,UINT);
  int WINAPI SetStrokeTableAttributes(HPENDATA,UINT,LPARAM,UINT);
  int WINAPI TrimPenData(HPENDATA,DWORD,DWORD);
#endif

#ifndef NOPENDICT
  WINBOOL WINAPI DictionarySearch(LPRC,LPSYE,int,LPSYV,int);
#endif

#ifndef NOPENDRIVER

#ifndef NOPENAPIFUN
  WINBOOL WINAPI EndPenCollection(REC);
  REC WINAPI GetPenHwData(LPPOINT,LPVOID,int,UINT,LPSTROKEINFO);
  REC WINAPI GetPenHwEventData(UINT,UINT,LPPOINT,LPVOID,int,LPSTROKEINFO);
  WINBOOL WINAPI SetPenHook(HKP,LPFNRAWHOOK);
  VOID WINAPI UpdatePenInfo(LPPENINFO);
#endif
  WINBOOL WINAPI GetPenAsyncState(UINT);
  WINBOOL WINAPI IsPenEvent(UINT,LONG);
#endif

#ifndef NOPENHRC
  int WINAPI AddPenDataHRC(HRC,HPENDATA);
  int WINAPI AddPenInputHRC(HRC,LPPOINT,LPVOID,UINT,LPSTROKEINFO);
  int WINAPI AddWordsHWL(HWL,LPSTR,UINT);
  int WINAPI ConfigHREC(HREC,UINT,WPARAM,LPARAM);
  HRC WINAPI CreateCompatibleHRC(HRC,HREC);
  HWL WINAPI CreateHWL(HREC,LPSTR,UINT,DWORD);
  HINKSET WINAPI CreateInksetHRCRESULT(HRCRESULT,UINT,UINT);
  HPENDATA WINAPI CreatePenDataHRC(HRC);
  int WINAPI DestroyHRC(HRC);
  int WINAPI DestroyHRCRESULT(HRCRESULT);
  int WINAPI DestroyHWL(HWL);
  int WINAPI EnableGestureSetHRC(HRC,SYV,WINBOOL);
  int WINAPI EnableSystemDictionaryHRC(HRC,WINBOOL);
  int WINAPI EndPenInputHRC(HRC);
  int WINAPI GetAlphabetHRC(HRC,LPALC,LPBYTE);
  int WINAPI GetAlphabetPriorityHRC(HRC,LPALC,LPBYTE);
  int WINAPI GetAlternateWordsHRCRESULT(HRCRESULT,UINT,UINT,LPHRCRESULT,UINT);
  int WINAPI GetBoxMappingHRCRESULT(HRCRESULT,UINT,UINT,UINT *);
  int WINAPI GetBoxResultsHRC(HRC,UINT,UINT,UINT,LPBOXRESULTS,WINBOOL);
  int WINAPI GetGuideHRC(HRC,LPGUIDE,UINT *);
  int WINAPI GetHotspotsHRCRESULT(HRCRESULT,UINT,LPPOINT,UINT);
  HREC WINAPI GetHRECFromHRC(HRC);
  int WINAPI GetInternationalHRC(HRC,UINT *,LPSTR,UINT *,UINT *);
  int WINAPI GetMaxResultsHRC(HRC);
  int WINAPI GetResultsHRC(HRC,UINT,LPHRCRESULT,UINT);
  int WINAPI GetSymbolCountHRCRESULT(HRCRESULT);
  int WINAPI GetSymbolsHRCRESULT(HRCRESULT,UINT,LPSYV,UINT);
  int WINAPI GetWordlistHRC(HRC,LPHWL);
  int WINAPI GetWordlistCoercionHRC(HRC);
  int WINAPI ProcessHRC(HRC,DWORD);
  int WINAPI ReadHWL(HWL,HFILE);
  int WINAPI SetAlphabetHRC(HRC,ALC,LPBYTE);
  int WINAPI SetAlphabetPriorityHRC(HRC,ALC,LPBYTE);
  int WINAPI SetBoxAlphabetHRC(HRC,LPALC,UINT);
  int WINAPI SetGuideHRC(HRC,LPGUIDE,UINT);
  int WINAPI SetInternationalHRC(HRC,UINT,LPCSTR,UINT,UINT);
  int WINAPI SetMaxResultsHRC(HRC,UINT);
  HRECHOOK WINAPI SetResultsHookHREC(HREC,HRCRESULTHOOKPROC);
  int WINAPI SetWordlistCoercionHRC(HRC,UINT);
  int WINAPI SetWordlistHRC(HRC,HWL);
  int WINAPI TrainHREC(HREC,LPSYV,UINT,HPENDATA,UINT);
  int WINAPI UnhookResultsHookHREC(HREC,HRECHOOK);
  int WINAPI WriteHWL(HWL,HFILE);
  HREC WINAPI InstallRecognizer(LPSTR);
  VOID WINAPI UninstallRecognizer(HREC);
  WINBOOL WINAPI AddInksetInterval(HINKSET,LPINTERVAL);
  HINKSET WINAPI CreateInkset(UINT);
  WINBOOL WINAPI DestroyInkset(HINKSET);
  int WINAPI GetInksetInterval(HINKSET,UINT,LPINTERVAL);
  int WINAPI GetInksetIntervalCount(HINKSET);
  int WINAPI CharacterToSymbol(LPSTR,int,LPSYV);
  WINBOOL WINAPI SymbolToCharacter(LPSYV,int,LPSTR,LPINT);
#endif

#ifndef NOPENINKPUT
  int WINAPI DoDefaultPenInput(HWND,UINT);
  int WINAPI GetPenInput(HPCM,LPPOINT,LPVOID,UINT,UINT,LPSTROKEINFO);
  int WINAPI PeekPenInput(HPCM,UINT,LPPOINT,LPVOID,UINT);
  int WINAPI StartInking(HPCM,UINT,LPINKINGINFO);
  HPCM WINAPI StartPenInput(HWND,UINT,LPPCMINFO,LPINT);
  int WINAPI StopInking(HPCM);
  int WINAPI StopPenInput(HPCM,UINT,int);
#endif

#ifndef NOPENMISC
  VOID WINAPI BoundingRectFromPoints(LPPOINT,UINT,LPRECT);
  WINBOOL WINAPI DPtoTP(LPPOINT,int);
  UINT WINAPI GetPenAppFlags(VOID);
  VOID WINAPI SetPenAppFlags(UINT,UINT);
  LONG WINAPI GetPenMiscInfo(WPARAM,LPARAM);
  UINT WINAPI GetVersionPenWin(VOID);
  LONG WINAPI SetPenMiscInfo(WPARAM,LPARAM);
  WINBOOL WINAPI TPtoDP(LPPOINT,int);
  WINBOOL WINAPI CorrectWriting(HWND,LPSTR,UINT,LPVOID,DWORD,DWORD);
#ifdef JAPAN
  int WINAPI CorrectWritingEx(HWND,LPSTR,UINT,LPCWX);
#endif
#ifdef JAPAN
  HANDLE WINAPI GetPenResource(WPARAM);
#endif
#endif

#ifndef NOPENRC1
  VOID WINAPI EmulatePen(WINBOOL);
  UINT WINAPI EnumSymbols(LPSYG,UINT,ENUMPROC,LPVOID);
  WINBOOL WINAPI ExecuteGesture(HWND,SYV,LPRCRESULT);
  VOID WINAPI FirstSymbolFromGraph(LPSYG,LPSYV,int,LPINT);
  UINT WINAPI GetGlobalRC(LPRC,LPSTR,LPSTR,int);
  int WINAPI GetSymbolCount(LPSYG);
  int WINAPI GetSymbolMaxLength(LPSYG);
  VOID WINAPI InitRC(HWND,LPRC);
  REC WINAPI ProcessWriting(HWND,LPRC);
  REC WINAPI Recognize(LPRC);
  REC WINAPI RecognizeData(LPRC,HPENDATA);
  UINT WINAPI SetGlobalRC(LPRC,LPSTR,LPSTR);
  WINBOOL WINAPI SetRecogHook(UINT,UINT,HWND);
  WINBOOL WINAPI TrainContext(LPRCRESULT,LPSYE,int,LPSYC,int);
  WINBOOL WINAPI TrainInk(LPRC,HPENDATA,LPSYV);

  VOID WINAPI CloseRecognizer(VOID);
  UINT WINAPI ConfigRecognizer(UINT,WPARAM,LPARAM);
  WINBOOL WINAPI InitRecognizer(LPRC);
  REC WINAPI RecognizeDataInternal(LPRC,HPENDATA,LPFUNCRESULTS);
  REC WINAPI RecognizeInternal(LPRC,LPFUNCRESULTS);
  WINBOOL WINAPI TrainContextInternal(LPRCRESULT,LPSYE,int,LPSYC,int);
  WINBOOL WINAPI TrainInkInternal(LPRC,HPENDATA,LPSYV);
#endif

#ifndef NOPENTARGET
  int WINAPI TargetPoints(LPTARGINFO,LPPOINT,DWORD,UINT,LPSTROKEINFO);
#endif

#ifndef NOPENVIRTEVENT

  VOID WINAPI AtomicVirtualEvent(WINBOOL);
  VOID WINAPI PostVirtualKeyEvent(UINT,WINBOOL);
  VOID WINAPI PostVirtualMouseEvent(UINT,int,int);
#endif

#ifdef JAPAN
  WINBOOL WINAPI KKConvert(HWND hwndConvert,HWND hwndCaller,LPSTR lpBuf,UINT cbBuf,LPPOINT lpPnt);
#endif
#endif

#ifdef __cplusplus
}
#endif

#endif
