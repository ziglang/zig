/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef XCMCMSXT_H
#define XCMCMSXT_H

#ifdef __cplusplus
extern "C" {
#endif

#define MS_EXT_SET_ID (512)

#define CMC_XS_MS ((CMC_uint32) MS_EXT_SET_ID)
#define CMC_X_MS_SESSION_FLAGS ((CMC_uint32) MS_EXT_SET_ID + 16)
#define CMC_X_MS_NEW_SESSION ((CMC_flags) 1)
#define CMC_X_MS_FORCE_DOWNLOAD ((CMC_flags) 4)
#define CMC_X_MS_FUNCTION_FLAGS ((CMC_uint32) MS_EXT_SET_ID + 17)
#define CMC_X_MS_READ_ENV_ONLY ((CMC_flags) 1)
#define CMC_X_MS_READ_BODY_AS_FILE ((CMC_flags) 2)
#define CMC_X_MS_LIST_GUARANTEE_FIFO ((CMC_flags) 4)
#define CMC_X_MS_AB_NO_MODIFY ((CMC_flags) 8)
#define CMC_X_MS_ADDRESS_UI ((CMC_uint32) MS_EXT_SET_ID + 18)
#define CMC_X_MS_ATTACH_DATA ((CMC_uint32) MS_EXT_SET_ID + 128)
#define CMC_X_MS_ATTACH_OLE ((CMC_flags) 1)
#define CMC_X_MS_ATTACH_OLE_STATIC ((CMC_flags) 2)
#define CMC_X_MS_MESSAGE_DATA ((CMC_uint32) MS_EXT_SET_ID + 129)
#define CMC_X_MS_MSG_RECEIPT_REQ ((CMC_flags) 1)

#ifdef __cplusplus
}
#endif
#endif
