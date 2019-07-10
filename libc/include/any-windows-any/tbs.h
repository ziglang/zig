/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_TBS
#define _INC_TBS

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

  typedef UINT32 TBS_RESULT;

  typedef enum _TBS_COMMAND_LOCALITY {
    TBS_COMMAND_LOCALITY_ZERO = 0,
    TBS_COMMAND_LOCALITY_ONE,
    TBS_COMMAND_LOCALITY_TWO,
    TBS_COMMAND_LOCALITY_THREE,
    TBS_COMMAND_LOCALITY_FOUR
  } TBS_COMMAND_LOCALITY;

  typedef enum _TBS_COMMAND_PRIORITY {
    TBS_COMMAND_PRIORITY_LOW = 100,
    TBS_COMMAND_PRIORITY_NORMAL = 200,
    TBS_COMMAND_PRIORITY_HIGH = 300,
    TBS_COMMAND_PRIORITY_SYSTEM = 400,
    TBS_COMMAND_PRIORITY_MAX = 0x80000000
  } TBS_COMMAND_PRIORITY;

  typedef struct _TBS_CONTEXT_PARAMS {
    UINT32 version;
  } TBS_CONTEXT_PARAMS;

  typedef LPVOID TBS_HCONTEXT;

  TBS_RESULT WINAPI Tbsi_Context_Create(const TBS_CONTEXT_PARAMS *pContextParams,TBS_HCONTEXT *phContext);
  TBS_RESULT WINAPI Tbsi_Get_TCG_Log(TBS_HCONTEXT hContext,BYTE *pOutputBuf,UINT32 *pOutputBufLen);
  TBS_RESULT WINAPI Tbsi_Physical_Presence_Command(TBS_HCONTEXT hContext,const BYTE *pInputBuf,UINT32 InputBufLen,BYTE *pOutputBuf,UINT32 *pOutputBufLen);
  TBS_RESULT WINAPI Tbsip_Cancel_Commands(TBS_HCONTEXT hContext);
  TBS_RESULT WINAPI Tbsip_Context_Close(TBS_HCONTEXT hContext);
  TBS_RESULT WINAPI Tbsip_Submit_Command(TBS_HCONTEXT hContext,TBS_COMMAND_LOCALITY locality,TBS_COMMAND_PRIORITY priority,const BYTE *pCommandBuf,UINT32 commandBufLen,BYTE *pResultBuf,UINT32 *pResultBufLen);

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_TBH*/
