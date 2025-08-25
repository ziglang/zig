/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_KTMW32
#define _INC_KTMW32

#include <ktmtypes.h>

#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

  WINBOOL WINAPI CommitComplete(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI CommitEnlistment(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI CommitTransaction(HANDLE TransactionHandle);
  WINBOOL WINAPI CommitTransactionAsync(HANDLE TransactionHandle);
  HANDLE WINAPI CreateEnlistment(LPSECURITY_ATTRIBUTES lpEnlistmentrAttributes,HANDLE ResourceManagerHandle,HANDLE TransactionHandle,NOTIFICATION_MASK NotificationMask,DWORD CreateOptions,PVOID EnlistmentKey);
  HANDLE WINAPI CreateTransaction (LPSECURITY_ATTRIBUTES lpTransactionAttributes, LPGUID UOW, DWORD CreateOptions, DWORD IsolationLevel, DWORD IsolationFlags, DWORD Timeout, LPWSTR Description);
  WINBOOL WINAPI SinglePhaseReject(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  HANDLE WINAPI CreateResourceManager(LPSECURITY_ATTRIBUTES lpResourceManagerAttributes,LPGUID ResourceManagerID,DWORD CreateOptions,HANDLE TmHandle,LPWSTR Description);
  HANDLE WINAPI CreateTransactionManager(LPSECURITY_ATTRIBUTES lpTransactionAttributes,LPWSTR LogFileName,ULONG CreateOptions,ULONG CommitStrength);
  WINBOOL WINAPI GetCurrentClockTransactionManager(HANDLE TransactionManagerHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI GetEnlistmentId(HANDLE EnlistmentHandle,LPGUID EnlistmentId);
  WINBOOL WINAPI GetEnlistmentRecoveryInformation(HANDLE EnlistmentHandle,ULONG BufferSize,PVOID Buffer,PULONG BufferUsed);
  WINBOOL WINAPI GetNotificationResourceManager(HANDLE ResourceManagerHandle,PTRANSACTION_NOTIFICATION TransactionNotification,ULONG NotificationLength,DWORD dwMilliseconds,PULONG ReturnLength);
  WINBOOL WINAPI GetNotificationResourceManagerAsync(HANDLE ResourceManagerHandle,PTRANSACTION_NOTIFICATION TransactionNotification,ULONG TransactionNotificationLength,PULONG ReturnLength,LPOVERLAPPED pOverlapped);
  WINBOOL WINAPI SetResourceManagerCompletionPort(HANDLE ResourceManagerHandle,HANDLE IoCompletionPortHandle,ULONG_PTR CompletionKey);
  WINBOOL WINAPI GetTransactionId(HANDLE TransactionHandle,LPGUID TransactionId);
  WINBOOL WINAPI GetTransactionInformation(HANDLE TransactionHandle,PDWORD Outcome,PDWORD IsolationLevel,PDWORD IsolationFlags,PDWORD Timeout,DWORD BufferLength,LPWSTR Description);
  WINBOOL WINAPI GetTransactionManagerId(HANDLE TransactionManagerHandle,LPGUID TransactionManagerId);
  HANDLE WINAPI OpenEnlistment(DWORD dwDesiredAccess,HANDLE ResourceManagerHandle,LPGUID EnlistmentId);
  HANDLE WINAPI OpenResourceManager(DWORD dwDesiredAccess,HANDLE TmHandle,LPGUID RmGuid);
  HANDLE WINAPI OpenTransaction(DWORD dwDesiredAccess,LPGUID TransactionId);
  HANDLE WINAPI OpenTransactionManager(LPWSTR LogFileName,ACCESS_MASK DesiredAccess,ULONG OpenOptions);
  HANDLE WINAPI OpenTransactionManagerById(LPGUID TransactionManagerId,ACCESS_MASK DesiredAccess,ULONG OpenOptions);
  WINBOOL WINAPI PrepareComplete(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI PrepareEnlistment(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI PrePrepareComplete(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI PrePrepareEnlistment(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI ReadOnlyEnlistment(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI RecoverEnlistment(HANDLE EnlistmentHandle,PVOID EnlistmentKey);
  WINBOOL WINAPI RecoverResourceManager(HANDLE ResourceManagerHandle);
  WINBOOL WINAPI RecoverTransactionManager(HANDLE TransactionManagerHandle);
  WINBOOL WINAPI RenameTransactionManager(LPWSTR LogFileName,LPGUID ExistingTransactionManagerGuid);
  WINBOOL WINAPI RollbackComplete(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI RollbackEnlistment(HANDLE EnlistmentHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI RollbackTransaction(HANDLE TransactionHandle);
  WINBOOL WINAPI RollbackTransactionAsync(HANDLE TransactionHandle);
  WINBOOL WINAPI RollforwardTransactionManager(HANDLE TransactionManagerHandle,PLARGE_INTEGER TmVirtualClock);
  WINBOOL WINAPI RollbackTransactionAsync(HANDLE TransactionHandle);
  WINBOOL WINAPI SetEnlistmentRecoveryInformation(HANDLE EnlistmentHandle,ULONG BufferSize,PVOID Buffer);
  WINBOOL WINAPI SetTransactionInformation(HANDLE TransactionHandle,DWORD IsolationLevel,DWORD IsolationFlags,DWORD Timeout,LPWSTR Description);

#ifdef __cplusplus
}
#endif
#endif /* (_WIN32_WINNT >= 0x0600) */

#endif /*_INC_KTMW32*/
