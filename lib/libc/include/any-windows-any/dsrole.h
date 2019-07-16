/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __DSROLE_H__
#define __DSROLE_H__

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum _DSROLE_MACHINE_ROLE {
    DsRole_RoleStandaloneWorkstation,DsRole_RoleMemberWorkstation,DsRole_RoleStandaloneServer,
    DsRole_RoleMemberServer,DsRole_RoleBackupDomainController,DsRole_RolePrimaryDomainController
  } DSROLE_MACHINE_ROLE;

  typedef enum _DSROLE_SERVER_STATE {
    DsRoleServerUnknown = 0,DsRoleServerPrimary,DsRoleServerBackup
  } DSROLE_SERVER_STATE,*PDSROLE_SERVER_STATE;

  typedef enum _DSROLE_PRIMARY_DOMAIN_INFO_LEVEL {
    DsRolePrimaryDomainInfoBasic = 1,DsRoleUpgradeStatus,DsRoleOperationState
  } DSROLE_PRIMARY_DOMAIN_INFO_LEVEL;

#define DSROLE_PRIMARY_DS_RUNNING 0x00000001
#define DSROLE_PRIMARY_DS_MIXED_MODE 0x00000002
#define DSROLE_UPGRADE_IN_PROGRESS 0x00000004
#define DSROLE_PRIMARY_DOMAIN_GUID_PRESENT 0x01000000

  typedef struct _DSROLE_PRIMARY_DOMAIN_INFO_BASIC {
    DSROLE_MACHINE_ROLE MachineRole;
    ULONG Flags;
    LPWSTR DomainNameFlat;
    LPWSTR DomainNameDns;
    LPWSTR DomainForestName;
    GUID DomainGuid;
  } DSROLE_PRIMARY_DOMAIN_INFO_BASIC,*PDSROLE_PRIMARY_DOMAIN_INFO_BASIC;

  typedef struct _DSROLE_UPGRADE_STATUS_INFO {
    ULONG OperationState;
    DSROLE_SERVER_STATE PreviousServerState;
  } DSROLE_UPGRADE_STATUS_INFO,*PDSROLE_UPGRADE_STATUS_INFO;

  typedef enum _DSROLE_OPERATION_STATE {
    DsRoleOperationIdle = 0,DsRoleOperationActive,DsRoleOperationNeedReboot
  } DSROLE_OPERATION_STATE;

  typedef struct _DSROLE_OPERATION_STATE_INFO {
    DSROLE_OPERATION_STATE OperationState;
  } DSROLE_OPERATION_STATE_INFO,*PDSROLE_OPERATION_STATE_INFO;

  DWORD WINAPI DsRoleGetPrimaryDomainInformation(LPCWSTR lpServer,DSROLE_PRIMARY_DOMAIN_INFO_LEVEL InfoLevel,PBYTE *Buffer);
  VOID WINAPI DsRoleFreeMemory(PVOID Buffer);

#ifdef __cplusplus
}
#endif
#endif
