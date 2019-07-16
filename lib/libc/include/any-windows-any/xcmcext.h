/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _XCMCEXT_H
#define _XCMCEXT_H

#include <xcmc.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CMC_XS_COM ((CMC_uint32) 0)
#define CMC_X_COM_SUPPORT_EXT ((CMC_uint32) 16)

  typedef struct {
    CMC_uint32 item_code;
    CMC_flags flags;
  } CMC_X_COM_support;

#define CMC_X_COM_SUPPORTED ((CMC_flags) 1)
#define CMC_X_COM_NOT_SUPPORTED ((CMC_flags) 2)
#define CMC_X_COM_DATA_EXT_SUPPORTED ((CMC_flags) 4)
#define CMC_X_COM_FUNC_EXT_SUPPORTED ((CMC_flags) 8)
#define CMC_X_COM_SUP_EXCLUDE ((CMC_flags) 16)

#define CMC_X_COM_CONFIG_DATA ((CMC_uint32) 17)

  typedef struct {
    CMC_uint16 ver_spec;
    CMC_uint16 ver_implem;
    CMC_object_identifier *character_set;
    CMC_enum line_term;
    CMC_string default_service;
    CMC_string default_user;
    CMC_enum req_password;
    CMC_enum req_service;
    CMC_enum req_user;
    CMC_boolean ui_avail;
    CMC_boolean sup_nomkmsgread;
    CMC_boolean sup_counted_str;
  } CMC_X_COM_configuration;

#define CMC_X_COM_CAN_SEND_RECIP ((CMC_uint32) 18)
#define CMC_X_COM_READY ((CMC_enum) 0)
#define CMC_X_COM_NOT_READY ((CMC_enum) 1)
#define CMC_X_COM_DEFER ((CMC_enum) 2)
#define CMC_X_COM_SAVE_MESSAGE ((CMC_uint32) 19)
#define CMC_X_COM_SENT_MESSAGE ((CMC_uint32) 20)
#define CMC_X_COM_TIME_RECEIVED ((CMC_uint32) 128)
#define CMC_X_COM_RECIP_ID ((CMC_uint32) 129)
#define CMC_X_COM_ATTACH_CHARPOS ((CMC_uint32) 130)
#define CMC_X_COM_PRIORITY ((CMC_uint32) 131)
#define CMC_X_COM_NORMAL ((CMC_enum) 0)
#define CMC_X_COM_URGENT ((CMC_enum) 1)
#define CMC_X_COM_LOW ((CMC_enum) 2)

#ifdef __cplusplus
}
#endif
#endif
