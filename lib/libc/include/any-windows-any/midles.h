/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __MIDLES_H__
#define __MIDLES_H__

#include <rpcndr.h>

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum {
    MES_ENCODE,MES_DECODE,MES_ENCODE_NDR64
  } MIDL_ES_CODE;

  typedef enum {
    MES_INCREMENTAL_HANDLE,MES_FIXED_BUFFER_HANDLE,MES_DYNAMIC_BUFFER_HANDLE
  } MIDL_ES_HANDLE_STYLE;

  typedef void (__RPC_API *MIDL_ES_ALLOC)(void *state,char **pbuffer,unsigned int *psize);
  typedef void (__RPC_API *MIDL_ES_WRITE)(void *state,char *buffer,unsigned int size);
  typedef void (__RPC_API *MIDL_ES_READ)(void *state,char **pbuffer,unsigned int *psize);
  typedef handle_t MIDL_ES_HANDLE;

  typedef struct _MIDL_TYPE_PICKLING_INFO {
    unsigned __LONG32 Version;
    unsigned __LONG32 Flags;
    UINT_PTR Reserved[3];
  } MIDL_TYPE_PICKLING_INFO,*PMIDL_TYPE_PICKLING_INFO;

  RPC_STATUS RPC_ENTRY MesEncodeIncrementalHandleCreate(void *UserState,MIDL_ES_ALLOC AllocFn,MIDL_ES_WRITE WriteFn,handle_t *pHandle);
  RPC_STATUS RPC_ENTRY MesDecodeIncrementalHandleCreate(void *UserState,MIDL_ES_READ ReadFn,handle_t *pHandle);
  RPC_STATUS RPC_ENTRY MesIncrementalHandleReset(handle_t Handle,void *UserState,MIDL_ES_ALLOC AllocFn,MIDL_ES_WRITE WriteFn,MIDL_ES_READ ReadFn,MIDL_ES_CODE Operation);
  RPC_STATUS RPC_ENTRY MesEncodeFixedBufferHandleCreate(char *pBuffer,unsigned __LONG32 BufferSize,unsigned __LONG32 *pEncodedSize,handle_t *pHandle);
  RPC_STATUS RPC_ENTRY MesEncodeDynBufferHandleCreate(char **pBuffer,unsigned __LONG32 *pEncodedSize,handle_t *pHandle);
  RPC_STATUS RPC_ENTRY MesDecodeBufferHandleCreate(char *pBuffer,unsigned __LONG32 BufferSize,handle_t *pHandle);
  RPC_STATUS RPC_ENTRY MesBufferHandleReset(handle_t Handle,unsigned __LONG32 HandleStyle,MIDL_ES_CODE Operation,char **pBuffer,unsigned __LONG32 BufferSize,unsigned __LONG32 *pEncodedSize);
  RPC_STATUS RPC_ENTRY MesHandleFree(handle_t Handle);
  RPC_STATUS RPC_ENTRY MesInqProcEncodingId(handle_t Handle,PRPC_SYNTAX_IDENTIFIER pInterfaceId,unsigned __LONG32 *pProcNum);
  size_t RPC_ENTRY NdrMesSimpleTypeAlignSize (handle_t);
  void RPC_ENTRY NdrMesSimpleTypeDecode(handle_t Handle,void *pObject,short Size);
  void RPC_ENTRY NdrMesSimpleTypeEncode(handle_t Handle,const MIDL_STUB_DESC *pStubDesc,const void *pObject,short Size);
  size_t RPC_ENTRY NdrMesTypeAlignSize(handle_t Handle,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,const void *pObject);
  void RPC_ENTRY NdrMesTypeEncode(handle_t Handle,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,const void *pObject);
  void RPC_ENTRY NdrMesTypeDecode(handle_t Handle,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,void *pObject);
  size_t RPC_ENTRY NdrMesTypeAlignSize2(handle_t Handle,const MIDL_TYPE_PICKLING_INFO *pPicklingInfo,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,const void *pObject);
  void RPC_ENTRY NdrMesTypeEncode2(handle_t Handle,const MIDL_TYPE_PICKLING_INFO *pPicklingInfo,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,const void *pObject);
  void RPC_ENTRY NdrMesTypeDecode2(handle_t Handle,const MIDL_TYPE_PICKLING_INFO *pPicklingInfo,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,void *pObject);
  void RPC_ENTRY NdrMesTypeFree2(handle_t Handle,const MIDL_TYPE_PICKLING_INFO *pPicklingInfo,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,void *pObject);
  void RPC_VAR_ENTRY NdrMesProcEncodeDecode(handle_t Handle,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,...);
  CLIENT_CALL_RETURN RPC_VAR_ENTRY NdrMesProcEncodeDecode2(handle_t Handle,const MIDL_STUB_DESC *pStubDesc,PFORMAT_STRING pFormatString,...);
  size_t RPC_ENTRY NdrMesTypeAlignSize3(handle_t Handle,const MIDL_TYPE_PICKLING_INFO *pPicklingInfo,const MIDL_STUBLESS_PROXY_INFO *pProxyInfo,const unsigned __LONG32 **ArrTypeOffset,unsigned __LONG32 nTypeIndex,const void *pObject);
  void RPC_ENTRY NdrMesTypeEncode3(handle_t Handle,const MIDL_TYPE_PICKLING_INFO *pPicklingInfo,const MIDL_STUBLESS_PROXY_INFO *pProxyInfo,const unsigned __LONG32 **ArrTypeOffset,unsigned __LONG32 nTypeIndex,const void *pObject);
  void RPC_ENTRY NdrMesTypeDecode3(handle_t Handle,const MIDL_TYPE_PICKLING_INFO *pPicklingInfo,const MIDL_STUBLESS_PROXY_INFO *pProxyInfo,const unsigned __LONG32 **ArrTypeOffset,unsigned __LONG32 nTypeIndex,void *pObject);
  void RPC_ENTRY NdrMesTypeFree3(handle_t Handle,const MIDL_TYPE_PICKLING_INFO *pPicklingInfo,const MIDL_STUBLESS_PROXY_INFO *pProxyInfo,const unsigned __LONG32 **ArrTypeOffset,unsigned __LONG32 nTypeIndex,void *pObject);
  CLIENT_CALL_RETURN RPC_VAR_ENTRY NdrMesProcEncodeDecode3(handle_t Handle,const MIDL_STUBLESS_PROXY_INFO *pProxyInfo,unsigned __LONG32 nProcNum,void *pReturnValue,...);
  void RPC_ENTRY NdrMesSimpleTypeDecodeAll(handle_t Handle,const MIDL_STUBLESS_PROXY_INFO *pProxyInfo,void *pObject,short Size);
  void RPC_ENTRY NdrMesSimpleTypeEncodeAll(handle_t Handle,const MIDL_STUBLESS_PROXY_INFO *pProxyInfo,const void *pObject,short Size);
  size_t RPC_ENTRY NdrMesSimpleTypeAlignSizeAll (handle_t Handle,const MIDL_STUBLESS_PROXY_INFO *pProxyInfo);

#ifdef __cplusplus
}
#endif
#endif
