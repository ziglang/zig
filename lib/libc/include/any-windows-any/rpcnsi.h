/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __RPCNSI_H__
#define __RPCNSI_H__

#include <_mingw_unicode.h>

typedef void *RPC_NS_HANDLE;

#define RPC_C_NS_SYNTAX_DEFAULT 0
#define RPC_C_NS_SYNTAX_DCE 3

#define RPC_C_PROFILE_DEFAULT_ELT 0
#define RPC_C_PROFILE_ALL_ELT 1
#define RPC_C_PROFILE_ALL_ELTS RPC_C_PROFILE_ALL_ELT
#define RPC_C_PROFILE_MATCH_BY_IF 2
#define RPC_C_PROFILE_MATCH_BY_MBR 3
#define RPC_C_PROFILE_MATCH_BY_BOTH 4

#define RPC_C_NS_DEFAULT_EXP_AGE -1

RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingExportA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_IF_HANDLE IfSpec,RPC_BINDING_VECTOR *BindingVec,UUID_VECTOR *ObjectUuidVec);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingUnexportA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_IF_HANDLE IfSpec,UUID_VECTOR *ObjectUuidVec);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingExportW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_IF_HANDLE IfSpec,RPC_BINDING_VECTOR *BindingVec,UUID_VECTOR *ObjectUuidVec);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingUnexportW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_IF_HANDLE IfSpec,UUID_VECTOR *ObjectUuidVec);
RPC_STATUS RPC_ENTRY RpcNsBindingExportPnPA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_IF_HANDLE IfSpec,UUID_VECTOR *ObjectVector);
RPC_STATUS RPC_ENTRY RpcNsBindingUnexportPnPA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_IF_HANDLE IfSpec,UUID_VECTOR *ObjectVector);
RPC_STATUS RPC_ENTRY RpcNsBindingExportPnPW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_IF_HANDLE IfSpec,UUID_VECTOR *ObjectVector);
RPC_STATUS RPC_ENTRY RpcNsBindingUnexportPnPW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_IF_HANDLE IfSpec,UUID_VECTOR *ObjectVector);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingLookupBeginA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_IF_HANDLE IfSpec,UUID *ObjUuid,unsigned __LONG32 BindingMaxCount,RPC_NS_HANDLE *LookupContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingLookupBeginW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_IF_HANDLE IfSpec,UUID *ObjUuid,unsigned __LONG32 BindingMaxCount,RPC_NS_HANDLE *LookupContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingLookupNext(RPC_NS_HANDLE LookupContext,RPC_BINDING_VECTOR **BindingVec);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingLookupDone(RPC_NS_HANDLE *LookupContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupDeleteA(unsigned __LONG32 GroupNameSyntax,RPC_CSTR GroupName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrAddA(unsigned __LONG32 GroupNameSyntax,RPC_CSTR GroupName,unsigned __LONG32 MemberNameSyntax,RPC_CSTR MemberName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrRemoveA(unsigned __LONG32 GroupNameSyntax,RPC_CSTR GroupName,unsigned __LONG32 MemberNameSyntax,RPC_CSTR MemberName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrInqBeginA(unsigned __LONG32 GroupNameSyntax,RPC_CSTR GroupName,unsigned __LONG32 MemberNameSyntax,RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrInqNextA(RPC_NS_HANDLE InquiryContext,RPC_CSTR *MemberName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupDeleteW(unsigned __LONG32 GroupNameSyntax,RPC_WSTR GroupName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrAddW(unsigned __LONG32 GroupNameSyntax,RPC_WSTR GroupName,unsigned __LONG32 MemberNameSyntax,RPC_WSTR MemberName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrRemoveW(unsigned __LONG32 GroupNameSyntax,RPC_WSTR GroupName,unsigned __LONG32 MemberNameSyntax,RPC_WSTR MemberName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrInqBeginW(unsigned __LONG32 GroupNameSyntax,RPC_WSTR GroupName,unsigned __LONG32 MemberNameSyntax,RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrInqNextW(RPC_NS_HANDLE InquiryContext,RPC_WSTR *MemberName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsGroupMbrInqDone(RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileDeleteA(unsigned __LONG32 ProfileNameSyntax,RPC_CSTR ProfileName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltAddA(unsigned __LONG32 ProfileNameSyntax,RPC_CSTR ProfileName,RPC_IF_ID *IfId,unsigned __LONG32 MemberNameSyntax,RPC_CSTR MemberName,unsigned __LONG32 Priority,RPC_CSTR Annotation);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltRemoveA(unsigned __LONG32 ProfileNameSyntax,RPC_CSTR ProfileName,RPC_IF_ID *IfId,unsigned __LONG32 MemberNameSyntax,RPC_CSTR MemberName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltInqBeginA(unsigned __LONG32 ProfileNameSyntax,RPC_CSTR ProfileName,unsigned __LONG32 InquiryType,RPC_IF_ID *IfId,unsigned __LONG32 VersOption,unsigned __LONG32 MemberNameSyntax,RPC_CSTR MemberName,RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltInqNextA(RPC_NS_HANDLE InquiryContext,RPC_IF_ID *IfId,RPC_CSTR *MemberName,unsigned __LONG32 *Priority,RPC_CSTR *Annotation);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileDeleteW(unsigned __LONG32 ProfileNameSyntax,RPC_WSTR ProfileName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltAddW(unsigned __LONG32 ProfileNameSyntax,RPC_WSTR ProfileName,RPC_IF_ID *IfId,unsigned __LONG32 MemberNameSyntax,RPC_WSTR MemberName,unsigned __LONG32 Priority,RPC_WSTR Annotation);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltRemoveW(unsigned __LONG32 ProfileNameSyntax,RPC_WSTR ProfileName,RPC_IF_ID *IfId,unsigned __LONG32 MemberNameSyntax,RPC_WSTR MemberName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltInqBeginW(unsigned __LONG32 ProfileNameSyntax,RPC_WSTR ProfileName,unsigned __LONG32 InquiryType,RPC_IF_ID *IfId,unsigned __LONG32 VersOption,unsigned __LONG32 MemberNameSyntax,RPC_WSTR MemberName,RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltInqNextW(RPC_NS_HANDLE InquiryContext,RPC_IF_ID *IfId,RPC_WSTR *MemberName,unsigned __LONG32 *Priority,RPC_WSTR *Annotation);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsProfileEltInqDone(RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsEntryObjectInqBeginA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsEntryObjectInqBeginW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsEntryObjectInqNext(RPC_NS_HANDLE InquiryContext,UUID *ObjUuid);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsEntryObjectInqDone(RPC_NS_HANDLE *InquiryContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsEntryExpandNameA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_CSTR *ExpandedName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtBindingUnexportA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_IF_ID *IfId,unsigned __LONG32 VersOption,UUID_VECTOR *ObjectUuidVec);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtEntryCreateA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtEntryDeleteA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtEntryInqIfIdsA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_IF_ID_VECTOR **IfIdVec);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtHandleSetExpAge(RPC_NS_HANDLE NsHandle,unsigned __LONG32 ExpirationAge);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtInqExpAge(unsigned __LONG32 *ExpirationAge);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtSetExpAge(unsigned __LONG32 ExpirationAge);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsEntryExpandNameW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_WSTR *ExpandedName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtBindingUnexportW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_IF_ID *IfId,unsigned __LONG32 VersOption,UUID_VECTOR *ObjectUuidVec);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtEntryCreateW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtEntryDeleteW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsMgmtEntryInqIfIdsW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_IF_ID_VECTOR **IfIdVec);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingImportBeginA(unsigned __LONG32 EntryNameSyntax,RPC_CSTR EntryName,RPC_IF_HANDLE IfSpec,UUID *ObjUuid,RPC_NS_HANDLE *ImportContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingImportBeginW(unsigned __LONG32 EntryNameSyntax,RPC_WSTR EntryName,RPC_IF_HANDLE IfSpec,UUID *ObjUuid,RPC_NS_HANDLE *ImportContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingImportNext(RPC_NS_HANDLE ImportContext,RPC_BINDING_HANDLE *Binding);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingImportDone(RPC_NS_HANDLE *ImportContext);
RPCNSAPI RPC_STATUS RPC_ENTRY RpcNsBindingSelect(RPC_BINDING_VECTOR *BindingVec,RPC_BINDING_HANDLE *Binding);

#define RpcNsBindingLookupBegin __MINGW_NAME_AW(RpcNsBindingLookupBegin)
#define RpcNsBindingImportBegin __MINGW_NAME_AW(RpcNsBindingImportBegin)
#define RpcNsBindingExport __MINGW_NAME_AW(RpcNsBindingExport)
#define RpcNsBindingUnexport __MINGW_NAME_AW(RpcNsBindingUnexport)
#define RpcNsGroupDelete __MINGW_NAME_AW(RpcNsGroupDelete)
#define RpcNsGroupMbrAdd __MINGW_NAME_AW(RpcNsGroupMbrAdd)
#define RpcNsGroupMbrRemove __MINGW_NAME_AW(RpcNsGroupMbrRemove)
#define RpcNsGroupMbrInqBegin __MINGW_NAME_AW(RpcNsGroupMbrInqBegin)
#define RpcNsGroupMbrInqNext __MINGW_NAME_AW(RpcNsGroupMbrInqNext)
#define RpcNsEntryExpandName __MINGW_NAME_AW(RpcNsEntryExpandName)
#define RpcNsEntryObjectInqBegin __MINGW_NAME_AW(RpcNsEntryObjectInqBegin)
#define RpcNsMgmtBindingUnexport __MINGW_NAME_AW(RpcNsMgmtBindingUnexport)
#define RpcNsMgmtEntryCreate __MINGW_NAME_AW(RpcNsMgmtEntryCreate)
#define RpcNsMgmtEntryDelete __MINGW_NAME_AW(RpcNsMgmtEntryDelete)
#define RpcNsMgmtEntryInqIfIds __MINGW_NAME_AW(RpcNsMgmtEntryInqIfIds)
#define RpcNsProfileDelete __MINGW_NAME_AW(RpcNsProfileDelete)
#define RpcNsProfileEltAdd __MINGW_NAME_AW(RpcNsProfileEltAdd)
#define RpcNsProfileEltRemove __MINGW_NAME_AW(RpcNsProfileEltRemove)
#define RpcNsProfileEltInqBegin __MINGW_NAME_AW(RpcNsProfileEltInqBegin)
#define RpcNsProfileEltInqNext __MINGW_NAME_AW(RpcNsProfileEltInqNext)
#define RpcNsBindingExportPnP __MINGW_NAME_AW(RpcNsBindingExportPnP)
#define RpcNsBindingUnexportPnP __MINGW_NAME_AW(RpcNsBindingUnexportPnP)

#endif
