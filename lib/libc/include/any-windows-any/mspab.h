/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define PAB_PROVIDER_ID { 0xB5,0x3b,0xc2,0xc0,0x2c,0x77,0x10,0x1a,0xa1,0xbc,0x08,0x00,0x2b,0x2a,0x56,0xc2 }

#define PR_PAB_PATH PROP_TAG(PT_TSTRING,0x6600)
#define PR_PAB_PATH_W PROP_TAG(PT_UNICODE,0x6600)
#define PR_PAB_PATH_A PROP_TAG(PT_STRING8,0x6600)

#define PR_PAB_DET_DIR_VIEW_BY PROP_TAG(PT_LONG,0x6601)

#define PAB_DIR_VIEW_FIRST_THEN_LAST 0
#define PAB_DIR_VIEW_LAST_THEN_FIRST 1
