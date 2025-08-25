/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __LMJOIN_H__
#define __LMJOIN_H__

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum _NETSETUP_NAME_TYPE {
    NetSetupUnknown = 0,NetSetupMachine,NetSetupWorkgroup,NetSetupDomain,NetSetupNonExistentDomain,
    NetSetupDnsMachine
  } NETSETUP_NAME_TYPE,*PNETSETUP_NAME_TYPE;

  typedef enum _NETSETUP_JOIN_STATUS {
    NetSetupUnknownStatus = 0,NetSetupUnjoined,NetSetupWorkgroupName,NetSetupDomainName
  } NETSETUP_JOIN_STATUS,*PNETSETUP_JOIN_STATUS;

#define NETSETUP_JOIN_DOMAIN 0x00000001
#define NETSETUP_ACCT_CREATE 0x00000002
#define NETSETUP_ACCT_DELETE 0x00000004
#define NETSETUP_WIN9X_UPGRADE 0x00000010
#define NETSETUP_DOMAIN_JOIN_IF_JOINED 0x00000020
#define NETSETUP_JOIN_UNSECURE 0x00000040
#define NETSETUP_MACHINE_PWD_PASSED 0x00000080
#define NETSETUP_DEFER_SPN_SET 0x00000100

#define NETSETUP_INSTALL_INVOCATION 0x00040000
#define NETSETUP_IGNORE_UNSUPPORTED_FLAGS 0x10000000

#define NETSETUP_VALID_UNJOIN_FLAGS (NETSETUP_ACCT_DELETE | NETSETUP_IGNORE_UNSUPPORTED_FLAGS)

  NET_API_STATUS WINAPI NetJoinDomain(LPCWSTR lpServer,LPCWSTR lpDomain,LPCWSTR lpAccountOU,LPCWSTR lpAccount,LPCWSTR lpPassword,DWORD fJoinOptions);
  NET_API_STATUS WINAPI NetUnjoinDomain(LPCWSTR lpServer,LPCWSTR lpAccount,LPCWSTR lpPassword,DWORD fUnjoinOptions);
  NET_API_STATUS WINAPI NetRenameMachineInDomain(LPCWSTR lpServer,LPCWSTR lpNewMachineName,LPCWSTR lpAccount,LPCWSTR lpPassword,DWORD fRenameOptions);
  NET_API_STATUS WINAPI NetValidateName(LPCWSTR lpServer,LPCWSTR lpName,LPCWSTR lpAccount,LPCWSTR lpPassword,NETSETUP_NAME_TYPE NameType);
  NET_API_STATUS WINAPI NetGetJoinInformation(LPCWSTR lpServer,LPWSTR *lpNameBuffer,PNETSETUP_JOIN_STATUS BufferType);
  NET_API_STATUS WINAPI NetGetJoinableOUs(LPCWSTR lpServer,LPCWSTR lpDomain,LPCWSTR lpAccount,LPCWSTR lpPassword,DWORD *OUCount,LPWSTR **OUs);

#define NET_IGNORE_UNSUPPORTED_FLAGS 0x01

  NET_API_STATUS WINAPI NetAddAlternateComputerName(LPCWSTR Server,LPCWSTR AlternateName,LPCWSTR DomainAccount,LPCWSTR DomainAccountPassword,ULONG Reserved);
  NET_API_STATUS WINAPI NetRemoveAlternateComputerName(LPCWSTR Server,LPCWSTR AlternateName,LPCWSTR DomainAccount,LPCWSTR DomainAccountPassword,ULONG Reserved);
  NET_API_STATUS WINAPI NetSetPrimaryComputerName(LPCWSTR Server,LPCWSTR PrimaryName,LPCWSTR DomainAccount,LPCWSTR DomainAccountPassword,ULONG Reserved);

  typedef enum _NET_COMPUTER_NAME_TYPE {
    NetPrimaryComputerName,NetAlternateComputerNames,NetAllComputerNames,NetComputerNameTypeMax
  } NET_COMPUTER_NAME_TYPE,*PNET_COMPUTER_NAME_TYPE;

  NET_API_STATUS WINAPI NetEnumerateComputerNames(LPCWSTR Server,NET_COMPUTER_NAME_TYPE NameType,ULONG Reserved,PDWORD EntryCount,LPWSTR **ComputerNames);

#ifdef __cplusplus
}
#endif
#endif
