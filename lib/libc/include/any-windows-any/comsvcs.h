/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include <_mingw.h>
#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __autosvcs_h__
#define __autosvcs_h__

#ifndef __ISecurityIdentityColl_FWD_DEFINED__
#define __ISecurityIdentityColl_FWD_DEFINED__
typedef struct ISecurityIdentityColl ISecurityIdentityColl;
#endif

#ifndef __ISecurityCallersColl_FWD_DEFINED__
#define __ISecurityCallersColl_FWD_DEFINED__
typedef struct ISecurityCallersColl ISecurityCallersColl;
#endif

#ifndef __ISecurityCallContext_FWD_DEFINED__
#define __ISecurityCallContext_FWD_DEFINED__
typedef struct ISecurityCallContext ISecurityCallContext;
#endif

#ifndef __IGetSecurityCallContext_FWD_DEFINED__
#define __IGetSecurityCallContext_FWD_DEFINED__
typedef struct IGetSecurityCallContext IGetSecurityCallContext;
#endif

#ifndef __SecurityProperty_FWD_DEFINED__
#define __SecurityProperty_FWD_DEFINED__
typedef struct SecurityProperty SecurityProperty;
#endif

#ifndef __ContextInfo_FWD_DEFINED__
#define __ContextInfo_FWD_DEFINED__
typedef struct ContextInfo ContextInfo;
#endif

#ifndef __ContextInfo2_FWD_DEFINED__
#define __ContextInfo2_FWD_DEFINED__
typedef struct ContextInfo2 ContextInfo2;
#endif

#ifndef __ObjectContext_FWD_DEFINED__
#define __ObjectContext_FWD_DEFINED__
typedef struct ObjectContext ObjectContext;
#endif

#ifndef __ITransactionContextEx_FWD_DEFINED__
#define __ITransactionContextEx_FWD_DEFINED__
typedef struct ITransactionContextEx ITransactionContextEx;
#endif

#ifndef __ITransactionContext_FWD_DEFINED__
#define __ITransactionContext_FWD_DEFINED__
typedef struct ITransactionContext ITransactionContext;
#endif

#ifndef __ICreateWithTransactionEx_FWD_DEFINED__
#define __ICreateWithTransactionEx_FWD_DEFINED__
typedef struct ICreateWithTransactionEx ICreateWithTransactionEx;
#endif

#ifndef __ICreateWithTipTransactionEx_FWD_DEFINED__
#define __ICreateWithTipTransactionEx_FWD_DEFINED__
typedef struct ICreateWithTipTransactionEx ICreateWithTipTransactionEx;
#endif

#ifndef __IComUserEvent_FWD_DEFINED__
#define __IComUserEvent_FWD_DEFINED__
typedef struct IComUserEvent IComUserEvent;
#endif

#ifndef __IComThreadEvents_FWD_DEFINED__
#define __IComThreadEvents_FWD_DEFINED__
typedef struct IComThreadEvents IComThreadEvents;
#endif

#ifndef __IComAppEvents_FWD_DEFINED__
#define __IComAppEvents_FWD_DEFINED__
typedef struct IComAppEvents IComAppEvents;
#endif

#ifndef __IComInstanceEvents_FWD_DEFINED__
#define __IComInstanceEvents_FWD_DEFINED__
typedef struct IComInstanceEvents IComInstanceEvents;
#endif

#ifndef __IComTransactionEvents_FWD_DEFINED__
#define __IComTransactionEvents_FWD_DEFINED__
typedef struct IComTransactionEvents IComTransactionEvents;
#endif

#ifndef __IComMethodEvents_FWD_DEFINED__
#define __IComMethodEvents_FWD_DEFINED__
typedef struct IComMethodEvents IComMethodEvents;
#endif

#ifndef __IComObjectEvents_FWD_DEFINED__
#define __IComObjectEvents_FWD_DEFINED__
typedef struct IComObjectEvents IComObjectEvents;
#endif

#ifndef __IComResourceEvents_FWD_DEFINED__
#define __IComResourceEvents_FWD_DEFINED__
typedef struct IComResourceEvents IComResourceEvents;
#endif

#ifndef __IComSecurityEvents_FWD_DEFINED__
#define __IComSecurityEvents_FWD_DEFINED__
typedef struct IComSecurityEvents IComSecurityEvents;
#endif

#ifndef __IComObjectPoolEvents_FWD_DEFINED__
#define __IComObjectPoolEvents_FWD_DEFINED__
typedef struct IComObjectPoolEvents IComObjectPoolEvents;
#endif

#ifndef __IComObjectPoolEvents2_FWD_DEFINED__
#define __IComObjectPoolEvents2_FWD_DEFINED__
typedef struct IComObjectPoolEvents2 IComObjectPoolEvents2;
#endif

#ifndef __IComObjectConstructionEvents_FWD_DEFINED__
#define __IComObjectConstructionEvents_FWD_DEFINED__
typedef struct IComObjectConstructionEvents IComObjectConstructionEvents;
#endif

#ifndef __IComActivityEvents_FWD_DEFINED__
#define __IComActivityEvents_FWD_DEFINED__
typedef struct IComActivityEvents IComActivityEvents;
#endif

#ifndef __IComIdentityEvents_FWD_DEFINED__
#define __IComIdentityEvents_FWD_DEFINED__
typedef struct IComIdentityEvents IComIdentityEvents;
#endif

#ifndef __IComQCEvents_FWD_DEFINED__
#define __IComQCEvents_FWD_DEFINED__
typedef struct IComQCEvents IComQCEvents;
#endif

#ifndef __IComExceptionEvents_FWD_DEFINED__
#define __IComExceptionEvents_FWD_DEFINED__
typedef struct IComExceptionEvents IComExceptionEvents;
#endif

#ifndef __ILBEvents_FWD_DEFINED__
#define __ILBEvents_FWD_DEFINED__
typedef struct ILBEvents ILBEvents;
#endif

#ifndef __IComCRMEvents_FWD_DEFINED__
#define __IComCRMEvents_FWD_DEFINED__
typedef struct IComCRMEvents IComCRMEvents;
#endif

#ifndef __IComMethod2Events_FWD_DEFINED__
#define __IComMethod2Events_FWD_DEFINED__
typedef struct IComMethod2Events IComMethod2Events;
#endif

#ifndef __IComTrackingInfoEvents_FWD_DEFINED__
#define __IComTrackingInfoEvents_FWD_DEFINED__
typedef struct IComTrackingInfoEvents IComTrackingInfoEvents;
#endif

#ifndef __IComTrackingInfoCollection_FWD_DEFINED__
#define __IComTrackingInfoCollection_FWD_DEFINED__
typedef struct IComTrackingInfoCollection IComTrackingInfoCollection;
#endif

#ifndef __IComTrackingInfoObject_FWD_DEFINED__
#define __IComTrackingInfoObject_FWD_DEFINED__
typedef struct IComTrackingInfoObject IComTrackingInfoObject;
#endif

#ifndef __IComTrackingInfoProperties_FWD_DEFINED__
#define __IComTrackingInfoProperties_FWD_DEFINED__
typedef struct IComTrackingInfoProperties IComTrackingInfoProperties;
#endif

#ifndef __IComApp2Events_FWD_DEFINED__
#define __IComApp2Events_FWD_DEFINED__
typedef struct IComApp2Events IComApp2Events;
#endif

#ifndef __IComTransaction2Events_FWD_DEFINED__
#define __IComTransaction2Events_FWD_DEFINED__
typedef struct IComTransaction2Events IComTransaction2Events;
#endif

#ifndef __IComInstance2Events_FWD_DEFINED__
#define __IComInstance2Events_FWD_DEFINED__
typedef struct IComInstance2Events IComInstance2Events;
#endif

#ifndef __IComObjectPool2Events_FWD_DEFINED__
#define __IComObjectPool2Events_FWD_DEFINED__
typedef struct IComObjectPool2Events IComObjectPool2Events;
#endif

#ifndef __IComObjectConstruction2Events_FWD_DEFINED__
#define __IComObjectConstruction2Events_FWD_DEFINED__
typedef struct IComObjectConstruction2Events IComObjectConstruction2Events;
#endif

#ifndef __ISystemAppEventData_FWD_DEFINED__
#define __ISystemAppEventData_FWD_DEFINED__
typedef struct ISystemAppEventData ISystemAppEventData;
#endif

#ifndef __IMtsEvents_FWD_DEFINED__
#define __IMtsEvents_FWD_DEFINED__
typedef struct IMtsEvents IMtsEvents;
#endif

#ifndef __IMtsEventInfo_FWD_DEFINED__
#define __IMtsEventInfo_FWD_DEFINED__
typedef struct IMtsEventInfo IMtsEventInfo;
#endif

#ifndef __IMTSLocator_FWD_DEFINED__
#define __IMTSLocator_FWD_DEFINED__
typedef struct IMTSLocator IMTSLocator;
#endif

#ifndef __IMtsGrp_FWD_DEFINED__
#define __IMtsGrp_FWD_DEFINED__
typedef struct IMtsGrp IMtsGrp;
#endif

#ifndef __IMessageMover_FWD_DEFINED__
#define __IMessageMover_FWD_DEFINED__
typedef struct IMessageMover IMessageMover;
#endif

#ifndef __IEventServerTrace_FWD_DEFINED__
#define __IEventServerTrace_FWD_DEFINED__
typedef struct IEventServerTrace IEventServerTrace;
#endif

#ifndef __IDispenserManager_FWD_DEFINED__
#define __IDispenserManager_FWD_DEFINED__
typedef struct IDispenserManager IDispenserManager;
#endif

#ifndef __IHolder_FWD_DEFINED__
#define __IHolder_FWD_DEFINED__
typedef struct IHolder IHolder;
#endif

#ifndef __IDispenserDriver_FWD_DEFINED__
#define __IDispenserDriver_FWD_DEFINED__
typedef struct IDispenserDriver IDispenserDriver;
#endif

#ifndef __IObjectContext_FWD_DEFINED__
#define __IObjectContext_FWD_DEFINED__
typedef struct IObjectContext IObjectContext;
#endif

#ifndef __IObjectControl_FWD_DEFINED__
#define __IObjectControl_FWD_DEFINED__
typedef struct IObjectControl IObjectControl;
#endif

#ifndef __IEnumNames_FWD_DEFINED__
#define __IEnumNames_FWD_DEFINED__
typedef struct IEnumNames IEnumNames;
#endif

#ifndef __ISecurityProperty_FWD_DEFINED__
#define __ISecurityProperty_FWD_DEFINED__
typedef struct ISecurityProperty ISecurityProperty;
#endif

#ifndef __ObjectControl_FWD_DEFINED__
#define __ObjectControl_FWD_DEFINED__
typedef struct ObjectControl ObjectControl;
#endif

#ifndef __ISharedProperty_FWD_DEFINED__
#define __ISharedProperty_FWD_DEFINED__
typedef struct ISharedProperty ISharedProperty;
#endif

#ifndef __ISharedPropertyGroup_FWD_DEFINED__
#define __ISharedPropertyGroup_FWD_DEFINED__
typedef struct ISharedPropertyGroup ISharedPropertyGroup;
#endif

#ifndef __ISharedPropertyGroupManager_FWD_DEFINED__
#define __ISharedPropertyGroupManager_FWD_DEFINED__
typedef struct ISharedPropertyGroupManager ISharedPropertyGroupManager;
#endif

#ifndef __IObjectConstruct_FWD_DEFINED__
#define __IObjectConstruct_FWD_DEFINED__
typedef struct IObjectConstruct IObjectConstruct;
#endif

#ifndef __IObjectConstructString_FWD_DEFINED__
#define __IObjectConstructString_FWD_DEFINED__
typedef struct IObjectConstructString IObjectConstructString;
#endif

#ifndef __IObjectContextActivity_FWD_DEFINED__
#define __IObjectContextActivity_FWD_DEFINED__
typedef struct IObjectContextActivity IObjectContextActivity;
#endif

#ifndef __IObjectContextInfo_FWD_DEFINED__
#define __IObjectContextInfo_FWD_DEFINED__
typedef struct IObjectContextInfo IObjectContextInfo;
#endif

#ifndef __IObjectContextInfo2_FWD_DEFINED__
#define __IObjectContextInfo2_FWD_DEFINED__
typedef struct IObjectContextInfo2 IObjectContextInfo2;
#endif

#ifndef __ITransactionStatus_FWD_DEFINED__
#define __ITransactionStatus_FWD_DEFINED__
typedef struct ITransactionStatus ITransactionStatus;
#endif

#ifndef __IObjectContextTip_FWD_DEFINED__
#define __IObjectContextTip_FWD_DEFINED__
typedef struct IObjectContextTip IObjectContextTip;
#endif

#ifndef __IPlaybackControl_FWD_DEFINED__
#define __IPlaybackControl_FWD_DEFINED__
typedef struct IPlaybackControl IPlaybackControl;
#endif

#ifndef __IGetContextProperties_FWD_DEFINED__
#define __IGetContextProperties_FWD_DEFINED__
typedef struct IGetContextProperties IGetContextProperties;
#endif

#ifndef __IContextState_FWD_DEFINED__
#define __IContextState_FWD_DEFINED__
typedef struct IContextState IContextState;
#endif

#ifndef __IPoolManager_FWD_DEFINED__
#define __IPoolManager_FWD_DEFINED__
typedef struct IPoolManager IPoolManager;
#endif

#ifndef __ISelectCOMLBServer_FWD_DEFINED__
#define __ISelectCOMLBServer_FWD_DEFINED__
typedef struct ISelectCOMLBServer ISelectCOMLBServer;
#endif

#ifndef __ICOMLBArguments_FWD_DEFINED__
#define __ICOMLBArguments_FWD_DEFINED__
typedef struct ICOMLBArguments ICOMLBArguments;
#endif

#ifndef __ICrmLogControl_FWD_DEFINED__
#define __ICrmLogControl_FWD_DEFINED__
typedef struct ICrmLogControl ICrmLogControl;
#endif

#ifndef __ICrmCompensatorVariants_FWD_DEFINED__
#define __ICrmCompensatorVariants_FWD_DEFINED__
typedef struct ICrmCompensatorVariants ICrmCompensatorVariants;
#endif

#ifndef __ICrmCompensator_FWD_DEFINED__
#define __ICrmCompensator_FWD_DEFINED__
typedef struct ICrmCompensator ICrmCompensator;
#endif

#ifndef __ICrmMonitorLogRecords_FWD_DEFINED__
#define __ICrmMonitorLogRecords_FWD_DEFINED__
typedef struct ICrmMonitorLogRecords ICrmMonitorLogRecords;
#endif

#ifndef __ICrmMonitorClerks_FWD_DEFINED__
#define __ICrmMonitorClerks_FWD_DEFINED__
typedef struct ICrmMonitorClerks ICrmMonitorClerks;
#endif

#ifndef __ICrmMonitor_FWD_DEFINED__
#define __ICrmMonitor_FWD_DEFINED__
typedef struct ICrmMonitor ICrmMonitor;
#endif

#ifndef __ICrmFormatLogRecords_FWD_DEFINED__
#define __ICrmFormatLogRecords_FWD_DEFINED__
typedef struct ICrmFormatLogRecords ICrmFormatLogRecords;
#endif

#ifndef __IServiceIISIntrinsicsConfig_FWD_DEFINED__
#define __IServiceIISIntrinsicsConfig_FWD_DEFINED__
typedef struct IServiceIISIntrinsicsConfig IServiceIISIntrinsicsConfig;
#endif

#ifndef __IServiceComTIIntrinsicsConfig_FWD_DEFINED__
#define __IServiceComTIIntrinsicsConfig_FWD_DEFINED__
typedef struct IServiceComTIIntrinsicsConfig IServiceComTIIntrinsicsConfig;
#endif

#ifndef __IServiceSxsConfig_FWD_DEFINED__
#define __IServiceSxsConfig_FWD_DEFINED__
typedef struct IServiceSxsConfig IServiceSxsConfig;
#endif

#ifndef __ICheckSxsConfig_FWD_DEFINED__
#define __ICheckSxsConfig_FWD_DEFINED__
typedef struct ICheckSxsConfig ICheckSxsConfig;
#endif

#ifndef __IServiceInheritanceConfig_FWD_DEFINED__
#define __IServiceInheritanceConfig_FWD_DEFINED__
typedef struct IServiceInheritanceConfig IServiceInheritanceConfig;
#endif

#ifndef __IServiceThreadPoolConfig_FWD_DEFINED__
#define __IServiceThreadPoolConfig_FWD_DEFINED__
typedef struct IServiceThreadPoolConfig IServiceThreadPoolConfig;
#endif

#ifndef __IServiceTransactionConfigBase_FWD_DEFINED__
#define __IServiceTransactionConfigBase_FWD_DEFINED__
typedef struct IServiceTransactionConfigBase IServiceTransactionConfigBase;
#endif

#ifndef __IServiceTransactionConfig_FWD_DEFINED__
#define __IServiceTransactionConfig_FWD_DEFINED__
typedef struct IServiceTransactionConfig IServiceTransactionConfig;
#endif

#ifndef __IServiceSynchronizationConfig_FWD_DEFINED__
#define __IServiceSynchronizationConfig_FWD_DEFINED__
typedef struct IServiceSynchronizationConfig IServiceSynchronizationConfig;
#endif

#ifndef __IServiceTrackerConfig_FWD_DEFINED__
#define __IServiceTrackerConfig_FWD_DEFINED__
typedef struct IServiceTrackerConfig IServiceTrackerConfig;
#endif

#ifndef __IServicePartitionConfig_FWD_DEFINED__
#define __IServicePartitionConfig_FWD_DEFINED__
typedef struct IServicePartitionConfig IServicePartitionConfig;
#endif

#ifndef __IServiceCall_FWD_DEFINED__
#define __IServiceCall_FWD_DEFINED__
typedef struct IServiceCall IServiceCall;
#endif

#ifndef __IAsyncErrorNotify_FWD_DEFINED__
#define __IAsyncErrorNotify_FWD_DEFINED__
typedef struct IAsyncErrorNotify IAsyncErrorNotify;
#endif

#ifndef __IServiceActivity_FWD_DEFINED__
#define __IServiceActivity_FWD_DEFINED__
typedef struct IServiceActivity IServiceActivity;
#endif

#ifndef __IThreadPoolKnobs_FWD_DEFINED__
#define __IThreadPoolKnobs_FWD_DEFINED__
typedef struct IThreadPoolKnobs IThreadPoolKnobs;
#endif

#ifndef __IComStaThreadPoolKnobs_FWD_DEFINED__
#define __IComStaThreadPoolKnobs_FWD_DEFINED__
typedef struct IComStaThreadPoolKnobs IComStaThreadPoolKnobs;
#endif

#ifndef __IComMtaThreadPoolKnobs_FWD_DEFINED__
#define __IComMtaThreadPoolKnobs_FWD_DEFINED__
typedef struct IComMtaThreadPoolKnobs IComMtaThreadPoolKnobs;
#endif

#ifndef __IComStaThreadPoolKnobs2_FWD_DEFINED__
#define __IComStaThreadPoolKnobs2_FWD_DEFINED__
typedef struct IComStaThreadPoolKnobs2 IComStaThreadPoolKnobs2;
#endif

#ifndef __IProcessInitializer_FWD_DEFINED__
#define __IProcessInitializer_FWD_DEFINED__
typedef struct IProcessInitializer IProcessInitializer;
#endif

#ifndef __IServicePoolConfig_FWD_DEFINED__
#define __IServicePoolConfig_FWD_DEFINED__
typedef struct IServicePoolConfig IServicePoolConfig;
#endif

#ifndef __IServicePool_FWD_DEFINED__
#define __IServicePool_FWD_DEFINED__
typedef struct IServicePool IServicePool;
#endif

#ifndef __IManagedPooledObj_FWD_DEFINED__
#define __IManagedPooledObj_FWD_DEFINED__
typedef struct IManagedPooledObj IManagedPooledObj;
#endif

#ifndef __IManagedPoolAction_FWD_DEFINED__
#define __IManagedPoolAction_FWD_DEFINED__
typedef struct IManagedPoolAction IManagedPoolAction;
#endif

#ifndef __IManagedObjectInfo_FWD_DEFINED__
#define __IManagedObjectInfo_FWD_DEFINED__
typedef struct IManagedObjectInfo IManagedObjectInfo;
#endif

#ifndef __IAppDomainHelper_FWD_DEFINED__
#define __IAppDomainHelper_FWD_DEFINED__
typedef struct IAppDomainHelper IAppDomainHelper;
#endif

#ifndef __IAssemblyLocator_FWD_DEFINED__
#define __IAssemblyLocator_FWD_DEFINED__
typedef struct IAssemblyLocator IAssemblyLocator;
#endif

#ifndef __IManagedActivationEvents_FWD_DEFINED__
#define __IManagedActivationEvents_FWD_DEFINED__
typedef struct IManagedActivationEvents IManagedActivationEvents;
#endif

#ifndef __ISendMethodEvents_FWD_DEFINED__
#define __ISendMethodEvents_FWD_DEFINED__
typedef struct ISendMethodEvents ISendMethodEvents;
#endif

#ifndef __ITransactionResourcePool_FWD_DEFINED__
#define __ITransactionResourcePool_FWD_DEFINED__
typedef struct ITransactionResourcePool ITransactionResourcePool;
#endif

#ifndef __IMTSCall_FWD_DEFINED__
#define __IMTSCall_FWD_DEFINED__
typedef struct IMTSCall IMTSCall;
#endif

#ifndef __IContextProperties_FWD_DEFINED__
#define __IContextProperties_FWD_DEFINED__
typedef struct IContextProperties IContextProperties;
#endif

#ifndef __IObjPool_FWD_DEFINED__
#define __IObjPool_FWD_DEFINED__
typedef struct IObjPool IObjPool;
#endif

#ifndef __ITransactionProperty_FWD_DEFINED__
#define __ITransactionProperty_FWD_DEFINED__
typedef struct ITransactionProperty ITransactionProperty;
#endif

#ifndef __IMTSActivity_FWD_DEFINED__
#define __IMTSActivity_FWD_DEFINED__
typedef struct IMTSActivity IMTSActivity;
#endif

#ifndef __SecurityIdentity_FWD_DEFINED__
#define __SecurityIdentity_FWD_DEFINED__
#ifdef __cplusplus
typedef class SecurityIdentity SecurityIdentity;
#else
typedef struct SecurityIdentity SecurityIdentity;
#endif
#endif

#ifndef __SecurityCallers_FWD_DEFINED__
#define __SecurityCallers_FWD_DEFINED__
#ifdef __cplusplus
typedef class SecurityCallers SecurityCallers;
#else
typedef struct SecurityCallers SecurityCallers;
#endif
#endif

#ifndef __SecurityCallContext_FWD_DEFINED__
#define __SecurityCallContext_FWD_DEFINED__
#ifdef __cplusplus
typedef class SecurityCallContext SecurityCallContext;
#else
typedef struct SecurityCallContext SecurityCallContext;
#endif
#endif

#ifndef __GetSecurityCallContextAppObject_FWD_DEFINED__
#define __GetSecurityCallContextAppObject_FWD_DEFINED__
#ifdef __cplusplus
typedef class GetSecurityCallContextAppObject GetSecurityCallContextAppObject;
#else
typedef struct GetSecurityCallContextAppObject GetSecurityCallContextAppObject;
#endif
#endif

#ifndef __IContextState_FWD_DEFINED__
#define __IContextState_FWD_DEFINED__
typedef struct IContextState IContextState;
#endif

#ifndef __Dummy30040732_FWD_DEFINED__
#define __Dummy30040732_FWD_DEFINED__
#ifdef __cplusplus
typedef class Dummy30040732 Dummy30040732;
#else
typedef struct Dummy30040732 Dummy30040732;
#endif
#endif

#ifndef __ContextInfo_FWD_DEFINED__
#define __ContextInfo_FWD_DEFINED__
typedef struct ContextInfo ContextInfo;
#endif

#ifndef __ContextInfo2_FWD_DEFINED__
#define __ContextInfo2_FWD_DEFINED__
typedef struct ContextInfo2 ContextInfo2;
#endif

#ifndef __ObjectControl_FWD_DEFINED__
#define __ObjectControl_FWD_DEFINED__
typedef struct ObjectControl ObjectControl;
#endif

#ifndef __TransactionContext_FWD_DEFINED__
#define __TransactionContext_FWD_DEFINED__
#ifdef __cplusplus
typedef class TransactionContext TransactionContext;
#else
typedef struct TransactionContext TransactionContext;
#endif
#endif

#ifndef __TransactionContextEx_FWD_DEFINED__
#define __TransactionContextEx_FWD_DEFINED__
#ifdef __cplusplus
typedef class TransactionContextEx TransactionContextEx;
#else
typedef struct TransactionContextEx TransactionContextEx;
#endif
#endif

#ifndef __ByotServerEx_FWD_DEFINED__
#define __ByotServerEx_FWD_DEFINED__
#ifdef __cplusplus
typedef class ByotServerEx ByotServerEx;
#else
typedef struct ByotServerEx ByotServerEx;
#endif
#endif

#ifndef __CServiceConfig_FWD_DEFINED__
#define __CServiceConfig_FWD_DEFINED__
#ifdef __cplusplus
typedef class CServiceConfig CServiceConfig;
#else
typedef struct CServiceConfig CServiceConfig;
#endif
#endif

#ifndef __ServicePool_FWD_DEFINED__
#define __ServicePool_FWD_DEFINED__
#ifdef __cplusplus
typedef class ServicePool ServicePool;
#else
typedef struct ServicePool ServicePool;
#endif
#endif

#ifndef __ServicePoolConfig_FWD_DEFINED__
#define __ServicePoolConfig_FWD_DEFINED__
#ifdef __cplusplus
typedef class ServicePoolConfig ServicePoolConfig;
#else
typedef struct ServicePoolConfig ServicePoolConfig;
#endif
#endif

#ifndef __SharedProperty_FWD_DEFINED__
#define __SharedProperty_FWD_DEFINED__
#ifdef __cplusplus
typedef class SharedProperty SharedProperty;
#else
typedef struct SharedProperty SharedProperty;
#endif
#endif

#ifndef __SharedPropertyGroup_FWD_DEFINED__
#define __SharedPropertyGroup_FWD_DEFINED__
#ifdef __cplusplus
typedef class SharedPropertyGroup SharedPropertyGroup;
#else
typedef struct SharedPropertyGroup SharedPropertyGroup;
#endif
#endif

#ifndef __SharedPropertyGroupManager_FWD_DEFINED__
#define __SharedPropertyGroupManager_FWD_DEFINED__
#ifdef __cplusplus
typedef class SharedPropertyGroupManager SharedPropertyGroupManager;
#else
typedef struct SharedPropertyGroupManager SharedPropertyGroupManager;
#endif
#endif

#ifndef __COMEvents_FWD_DEFINED__
#define __COMEvents_FWD_DEFINED__
#ifdef __cplusplus
typedef class COMEvents COMEvents;
#else
typedef struct COMEvents COMEvents;
#endif
#endif

#ifndef __CoMTSLocator_FWD_DEFINED__
#define __CoMTSLocator_FWD_DEFINED__
#ifdef __cplusplus
typedef class CoMTSLocator CoMTSLocator;
#else
typedef struct CoMTSLocator CoMTSLocator;
#endif
#endif

#ifndef __MtsGrp_FWD_DEFINED__
#define __MtsGrp_FWD_DEFINED__
#ifdef __cplusplus
typedef class MtsGrp MtsGrp;
#else
typedef struct MtsGrp MtsGrp;
#endif
#endif

#ifndef __ComServiceEvents_FWD_DEFINED__
#define __ComServiceEvents_FWD_DEFINED__
#ifdef __cplusplus
typedef class ComServiceEvents ComServiceEvents;
#else
typedef struct ComServiceEvents ComServiceEvents;
#endif
#endif

#ifndef __ComSystemAppEventData_FWD_DEFINED__
#define __ComSystemAppEventData_FWD_DEFINED__
#ifdef __cplusplus
typedef class ComSystemAppEventData ComSystemAppEventData;
#else
typedef struct ComSystemAppEventData ComSystemAppEventData;
#endif
#endif

#ifndef __CRMClerk_FWD_DEFINED__
#define __CRMClerk_FWD_DEFINED__
#ifdef __cplusplus
typedef class CRMClerk CRMClerk;
#else
typedef struct CRMClerk CRMClerk;
#endif
#endif

#ifndef __CRMRecoveryClerk_FWD_DEFINED__
#define __CRMRecoveryClerk_FWD_DEFINED__
#ifdef __cplusplus
typedef class CRMRecoveryClerk CRMRecoveryClerk;
#else
typedef struct CRMRecoveryClerk CRMRecoveryClerk;
#endif
#endif

#ifndef __LBEvents_FWD_DEFINED__
#define __LBEvents_FWD_DEFINED__
#ifdef __cplusplus
typedef class LBEvents LBEvents;
#else
typedef struct LBEvents LBEvents;
#endif
#endif

#ifndef __MessageMover_FWD_DEFINED__
#define __MessageMover_FWD_DEFINED__
#ifdef __cplusplus
typedef class MessageMover MessageMover;
#else
typedef struct MessageMover MessageMover;
#endif
#endif

#ifndef __DispenserManager_FWD_DEFINED__
#define __DispenserManager_FWD_DEFINED__
#ifdef __cplusplus
typedef class DispenserManager DispenserManager;
#else
typedef struct DispenserManager DispenserManager;
#endif
#endif

#ifndef __PoolMgr_FWD_DEFINED__
#define __PoolMgr_FWD_DEFINED__
#ifdef __cplusplus
typedef class PoolMgr PoolMgr;
#else
typedef struct PoolMgr PoolMgr;
#endif
#endif

#ifndef __EventServer_FWD_DEFINED__
#define __EventServer_FWD_DEFINED__
#ifdef __cplusplus
typedef class EventServer EventServer;
#else
typedef struct EventServer EventServer;
#endif
#endif

#ifndef __AppDomainHelper_FWD_DEFINED__
#define __AppDomainHelper_FWD_DEFINED__
#ifdef __cplusplus
typedef class AppDomainHelper AppDomainHelper;
#else
typedef struct AppDomainHelper AppDomainHelper;
#endif
#endif

#ifndef __ClrAssemblyLocator_FWD_DEFINED__
#define __ClrAssemblyLocator_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClrAssemblyLocator ClrAssemblyLocator;
#else
typedef struct ClrAssemblyLocator ClrAssemblyLocator;
#endif
#endif

#include "unknwn.h"
#include "oaidl.h"
#include "ocidl.h"
#include "comadmin.h"
#include "transact.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#include <objbase.h>

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0000_v0_0_s_ifspec;

#ifndef __ISecurityIdentityColl_INTERFACE_DEFINED__
#define __ISecurityIdentityColl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISecurityIdentityColl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISecurityIdentityColl : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get_Item(BSTR name,VARIANT *pItem) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnum) = 0;
  };
#else
  typedef struct ISecurityIdentityCollVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISecurityIdentityColl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISecurityIdentityColl *This);
      ULONG (WINAPI *Release)(ISecurityIdentityColl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISecurityIdentityColl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISecurityIdentityColl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISecurityIdentityColl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISecurityIdentityColl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISecurityIdentityColl *This,__LONG32 *plCount);
      HRESULT (WINAPI *get_Item)(ISecurityIdentityColl *This,BSTR name,VARIANT *pItem);
      HRESULT (WINAPI *get__NewEnum)(ISecurityIdentityColl *This,IUnknown **ppEnum);
    END_INTERFACE
  } ISecurityIdentityCollVtbl;
  struct ISecurityIdentityColl {
    CONST_VTBL struct ISecurityIdentityCollVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISecurityIdentityColl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISecurityIdentityColl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISecurityIdentityColl_Release(This) (This)->lpVtbl->Release(This)
#define ISecurityIdentityColl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISecurityIdentityColl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISecurityIdentityColl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISecurityIdentityColl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISecurityIdentityColl_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISecurityIdentityColl_get_Item(This,name,pItem) (This)->lpVtbl->get_Item(This,name,pItem)
#define ISecurityIdentityColl_get__NewEnum(This,ppEnum) (This)->lpVtbl->get__NewEnum(This,ppEnum)
#endif
#endif
  HRESULT WINAPI ISecurityIdentityColl_get_Count_Proxy(ISecurityIdentityColl *This,__LONG32 *plCount);
  void __RPC_STUB ISecurityIdentityColl_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityIdentityColl_get_Item_Proxy(ISecurityIdentityColl *This,BSTR name,VARIANT *pItem);
  void __RPC_STUB ISecurityIdentityColl_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityIdentityColl_get__NewEnum_Proxy(ISecurityIdentityColl *This,IUnknown **ppEnum);
  void __RPC_STUB ISecurityIdentityColl_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISecurityCallersColl_INTERFACE_DEFINED__
#define __ISecurityCallersColl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISecurityCallersColl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISecurityCallersColl : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get_Item(__LONG32 lIndex,ISecurityIdentityColl **pObj) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnum) = 0;
  };
#else
  typedef struct ISecurityCallersCollVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISecurityCallersColl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISecurityCallersColl *This);
      ULONG (WINAPI *Release)(ISecurityCallersColl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISecurityCallersColl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISecurityCallersColl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISecurityCallersColl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISecurityCallersColl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISecurityCallersColl *This,__LONG32 *plCount);
      HRESULT (WINAPI *get_Item)(ISecurityCallersColl *This,__LONG32 lIndex,ISecurityIdentityColl **pObj);
      HRESULT (WINAPI *get__NewEnum)(ISecurityCallersColl *This,IUnknown **ppEnum);
    END_INTERFACE
  } ISecurityCallersCollVtbl;
  struct ISecurityCallersColl {
    CONST_VTBL struct ISecurityCallersCollVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISecurityCallersColl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISecurityCallersColl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISecurityCallersColl_Release(This) (This)->lpVtbl->Release(This)
#define ISecurityCallersColl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISecurityCallersColl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISecurityCallersColl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISecurityCallersColl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISecurityCallersColl_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISecurityCallersColl_get_Item(This,lIndex,pObj) (This)->lpVtbl->get_Item(This,lIndex,pObj)
#define ISecurityCallersColl_get__NewEnum(This,ppEnum) (This)->lpVtbl->get__NewEnum(This,ppEnum)
#endif
#endif
  HRESULT WINAPI ISecurityCallersColl_get_Count_Proxy(ISecurityCallersColl *This,__LONG32 *plCount);
  void __RPC_STUB ISecurityCallersColl_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityCallersColl_get_Item_Proxy(ISecurityCallersColl *This,__LONG32 lIndex,ISecurityIdentityColl **pObj);
  void __RPC_STUB ISecurityCallersColl_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityCallersColl_get__NewEnum_Proxy(ISecurityCallersColl *This,IUnknown **ppEnum);
  void __RPC_STUB ISecurityCallersColl_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISecurityCallContext_INTERFACE_DEFINED__
#define __ISecurityCallContext_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISecurityCallContext;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISecurityCallContext : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get_Item(BSTR name,VARIANT *pItem) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnum) = 0;
    virtual HRESULT WINAPI IsCallerInRole(BSTR bstrRole,VARIANT_BOOL *pfInRole) = 0;
    virtual HRESULT WINAPI IsSecurityEnabled(VARIANT_BOOL *pfIsEnabled) = 0;
    virtual HRESULT WINAPI IsUserInRole(VARIANT *pUser,BSTR bstrRole,VARIANT_BOOL *pfInRole) = 0;
  };
#else
  typedef struct ISecurityCallContextVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISecurityCallContext *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISecurityCallContext *This);
      ULONG (WINAPI *Release)(ISecurityCallContext *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISecurityCallContext *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISecurityCallContext *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISecurityCallContext *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISecurityCallContext *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISecurityCallContext *This,__LONG32 *plCount);
      HRESULT (WINAPI *get_Item)(ISecurityCallContext *This,BSTR name,VARIANT *pItem);
      HRESULT (WINAPI *get__NewEnum)(ISecurityCallContext *This,IUnknown **ppEnum);
      HRESULT (WINAPI *IsCallerInRole)(ISecurityCallContext *This,BSTR bstrRole,VARIANT_BOOL *pfInRole);
      HRESULT (WINAPI *IsSecurityEnabled)(ISecurityCallContext *This,VARIANT_BOOL *pfIsEnabled);
      HRESULT (WINAPI *IsUserInRole)(ISecurityCallContext *This,VARIANT *pUser,BSTR bstrRole,VARIANT_BOOL *pfInRole);
    END_INTERFACE
  } ISecurityCallContextVtbl;
  struct ISecurityCallContext {
    CONST_VTBL struct ISecurityCallContextVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISecurityCallContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISecurityCallContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISecurityCallContext_Release(This) (This)->lpVtbl->Release(This)
#define ISecurityCallContext_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISecurityCallContext_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISecurityCallContext_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISecurityCallContext_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISecurityCallContext_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISecurityCallContext_get_Item(This,name,pItem) (This)->lpVtbl->get_Item(This,name,pItem)
#define ISecurityCallContext_get__NewEnum(This,ppEnum) (This)->lpVtbl->get__NewEnum(This,ppEnum)
#define ISecurityCallContext_IsCallerInRole(This,bstrRole,pfInRole) (This)->lpVtbl->IsCallerInRole(This,bstrRole,pfInRole)
#define ISecurityCallContext_IsSecurityEnabled(This,pfIsEnabled) (This)->lpVtbl->IsSecurityEnabled(This,pfIsEnabled)
#define ISecurityCallContext_IsUserInRole(This,pUser,bstrRole,pfInRole) (This)->lpVtbl->IsUserInRole(This,pUser,bstrRole,pfInRole)
#endif
#endif
  HRESULT WINAPI ISecurityCallContext_get_Count_Proxy(ISecurityCallContext *This,__LONG32 *plCount);
  void __RPC_STUB ISecurityCallContext_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityCallContext_get_Item_Proxy(ISecurityCallContext *This,BSTR name,VARIANT *pItem);
  void __RPC_STUB ISecurityCallContext_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityCallContext_get__NewEnum_Proxy(ISecurityCallContext *This,IUnknown **ppEnum);
  void __RPC_STUB ISecurityCallContext_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityCallContext_IsCallerInRole_Proxy(ISecurityCallContext *This,BSTR bstrRole,VARIANT_BOOL *pfInRole);
  void __RPC_STUB ISecurityCallContext_IsCallerInRole_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityCallContext_IsSecurityEnabled_Proxy(ISecurityCallContext *This,VARIANT_BOOL *pfIsEnabled);
  void __RPC_STUB ISecurityCallContext_IsSecurityEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityCallContext_IsUserInRole_Proxy(ISecurityCallContext *This,VARIANT *pUser,BSTR bstrRole,VARIANT_BOOL *pfInRole);
  void __RPC_STUB ISecurityCallContext_IsUserInRole_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetSecurityCallContext_INTERFACE_DEFINED__
#define __IGetSecurityCallContext_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetSecurityCallContext;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetSecurityCallContext : public IDispatch {
  public:
    virtual HRESULT WINAPI GetSecurityCallContext(ISecurityCallContext **ppObject) = 0;
  };
#else
  typedef struct IGetSecurityCallContextVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetSecurityCallContext *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetSecurityCallContext *This);
      ULONG (WINAPI *Release)(IGetSecurityCallContext *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IGetSecurityCallContext *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IGetSecurityCallContext *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IGetSecurityCallContext *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IGetSecurityCallContext *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetSecurityCallContext)(IGetSecurityCallContext *This,ISecurityCallContext **ppObject);
    END_INTERFACE
  } IGetSecurityCallContextVtbl;
  struct IGetSecurityCallContext {
    CONST_VTBL struct IGetSecurityCallContextVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetSecurityCallContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetSecurityCallContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetSecurityCallContext_Release(This) (This)->lpVtbl->Release(This)
#define IGetSecurityCallContext_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IGetSecurityCallContext_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IGetSecurityCallContext_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IGetSecurityCallContext_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IGetSecurityCallContext_GetSecurityCallContext(This,ppObject) (This)->lpVtbl->GetSecurityCallContext(This,ppObject)
#endif
#endif
  HRESULT WINAPI IGetSecurityCallContext_GetSecurityCallContext_Proxy(IGetSecurityCallContext *This,ISecurityCallContext **ppObject);
  void __RPC_STUB IGetSecurityCallContext_GetSecurityCallContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __SecurityProperty_INTERFACE_DEFINED__
#define __SecurityProperty_INTERFACE_DEFINED__
  EXTERN_C const IID IID_SecurityProperty;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct SecurityProperty : public IDispatch {
  public:
    virtual HRESULT WINAPI GetDirectCallerName(BSTR *bstrUserName) = 0;
    virtual HRESULT WINAPI GetDirectCreatorName(BSTR *bstrUserName) = 0;
    virtual HRESULT WINAPI GetOriginalCallerName(BSTR *bstrUserName) = 0;
    virtual HRESULT WINAPI GetOriginalCreatorName(BSTR *bstrUserName) = 0;
  };
#else
  typedef struct SecurityPropertyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(SecurityProperty *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(SecurityProperty *This);
      ULONG (WINAPI *Release)(SecurityProperty *This);
      HRESULT (WINAPI *GetTypeInfoCount)(SecurityProperty *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(SecurityProperty *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(SecurityProperty *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(SecurityProperty *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetDirectCallerName)(SecurityProperty *This,BSTR *bstrUserName);
      HRESULT (WINAPI *GetDirectCreatorName)(SecurityProperty *This,BSTR *bstrUserName);
      HRESULT (WINAPI *GetOriginalCallerName)(SecurityProperty *This,BSTR *bstrUserName);
      HRESULT (WINAPI *GetOriginalCreatorName)(SecurityProperty *This,BSTR *bstrUserName);
    END_INTERFACE
  } SecurityPropertyVtbl;
  struct SecurityProperty {
    CONST_VTBL struct SecurityPropertyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define SecurityProperty_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define SecurityProperty_AddRef(This) (This)->lpVtbl->AddRef(This)
#define SecurityProperty_Release(This) (This)->lpVtbl->Release(This)
#define SecurityProperty_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define SecurityProperty_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define SecurityProperty_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define SecurityProperty_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define SecurityProperty_GetDirectCallerName(This,bstrUserName) (This)->lpVtbl->GetDirectCallerName(This,bstrUserName)
#define SecurityProperty_GetDirectCreatorName(This,bstrUserName) (This)->lpVtbl->GetDirectCreatorName(This,bstrUserName)
#define SecurityProperty_GetOriginalCallerName(This,bstrUserName) (This)->lpVtbl->GetOriginalCallerName(This,bstrUserName)
#define SecurityProperty_GetOriginalCreatorName(This,bstrUserName) (This)->lpVtbl->GetOriginalCreatorName(This,bstrUserName)
#endif
#endif
  HRESULT WINAPI SecurityProperty_GetDirectCallerName_Proxy(SecurityProperty *This,BSTR *bstrUserName);
  void __RPC_STUB SecurityProperty_GetDirectCallerName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SecurityProperty_GetDirectCreatorName_Proxy(SecurityProperty *This,BSTR *bstrUserName);
  void __RPC_STUB SecurityProperty_GetDirectCreatorName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SecurityProperty_GetOriginalCallerName_Proxy(SecurityProperty *This,BSTR *bstrUserName);
  void __RPC_STUB SecurityProperty_GetOriginalCallerName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SecurityProperty_GetOriginalCreatorName_Proxy(SecurityProperty *This,BSTR *bstrUserName);
  void __RPC_STUB SecurityProperty_GetOriginalCreatorName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ContextInfo_INTERFACE_DEFINED__
#define __ContextInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ContextInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ContextInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI IsInTransaction(VARIANT_BOOL *pbIsInTx) = 0;
    virtual HRESULT WINAPI GetTransaction(IUnknown **ppTx) = 0;
    virtual HRESULT WINAPI GetTransactionId(BSTR *pbstrTxId) = 0;
    virtual HRESULT WINAPI GetActivityId(BSTR *pbstrActivityId) = 0;
    virtual HRESULT WINAPI GetContextId(BSTR *pbstrCtxId) = 0;
  };
#else
  typedef struct ContextInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ContextInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ContextInfo *This);
      ULONG (WINAPI *Release)(ContextInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ContextInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ContextInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ContextInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ContextInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *IsInTransaction)(ContextInfo *This,VARIANT_BOOL *pbIsInTx);
      HRESULT (WINAPI *GetTransaction)(ContextInfo *This,IUnknown **ppTx);
      HRESULT (WINAPI *GetTransactionId)(ContextInfo *This,BSTR *pbstrTxId);
      HRESULT (WINAPI *GetActivityId)(ContextInfo *This,BSTR *pbstrActivityId);
      HRESULT (WINAPI *GetContextId)(ContextInfo *This,BSTR *pbstrCtxId);
    END_INTERFACE
  } ContextInfoVtbl;
  struct ContextInfo {
    CONST_VTBL struct ContextInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ContextInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ContextInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ContextInfo_Release(This) (This)->lpVtbl->Release(This)
#define ContextInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ContextInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ContextInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ContextInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ContextInfo_IsInTransaction(This,pbIsInTx) (This)->lpVtbl->IsInTransaction(This,pbIsInTx)
#define ContextInfo_GetTransaction(This,ppTx) (This)->lpVtbl->GetTransaction(This,ppTx)
#define ContextInfo_GetTransactionId(This,pbstrTxId) (This)->lpVtbl->GetTransactionId(This,pbstrTxId)
#define ContextInfo_GetActivityId(This,pbstrActivityId) (This)->lpVtbl->GetActivityId(This,pbstrActivityId)
#define ContextInfo_GetContextId(This,pbstrCtxId) (This)->lpVtbl->GetContextId(This,pbstrCtxId)
#endif
#endif
  HRESULT WINAPI ContextInfo_IsInTransaction_Proxy(ContextInfo *This,VARIANT_BOOL *pbIsInTx);
  void __RPC_STUB ContextInfo_IsInTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ContextInfo_GetTransaction_Proxy(ContextInfo *This,IUnknown **ppTx);
  void __RPC_STUB ContextInfo_GetTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ContextInfo_GetTransactionId_Proxy(ContextInfo *This,BSTR *pbstrTxId);
  void __RPC_STUB ContextInfo_GetTransactionId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ContextInfo_GetActivityId_Proxy(ContextInfo *This,BSTR *pbstrActivityId);
  void __RPC_STUB ContextInfo_GetActivityId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ContextInfo_GetContextId_Proxy(ContextInfo *This,BSTR *pbstrCtxId);
  void __RPC_STUB ContextInfo_GetContextId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ContextInfo2_INTERFACE_DEFINED__
#define __ContextInfo2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ContextInfo2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ContextInfo2 : public ContextInfo {
  public:
    virtual HRESULT WINAPI GetPartitionId(BSTR *__MIDL_0011) = 0;
    virtual HRESULT WINAPI GetApplicationId(BSTR *__MIDL_0012) = 0;
    virtual HRESULT WINAPI GetApplicationInstanceId(BSTR *__MIDL_0013) = 0;
  };
#else
  typedef struct ContextInfo2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ContextInfo2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ContextInfo2 *This);
      ULONG (WINAPI *Release)(ContextInfo2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ContextInfo2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ContextInfo2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ContextInfo2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ContextInfo2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *IsInTransaction)(ContextInfo2 *This,VARIANT_BOOL *pbIsInTx);
      HRESULT (WINAPI *GetTransaction)(ContextInfo2 *This,IUnknown **ppTx);
      HRESULT (WINAPI *GetTransactionId)(ContextInfo2 *This,BSTR *pbstrTxId);
      HRESULT (WINAPI *GetActivityId)(ContextInfo2 *This,BSTR *pbstrActivityId);
      HRESULT (WINAPI *GetContextId)(ContextInfo2 *This,BSTR *pbstrCtxId);
      HRESULT (WINAPI *GetPartitionId)(ContextInfo2 *This,BSTR *__MIDL_0011);
      HRESULT (WINAPI *GetApplicationId)(ContextInfo2 *This,BSTR *__MIDL_0012);
      HRESULT (WINAPI *GetApplicationInstanceId)(ContextInfo2 *This,BSTR *__MIDL_0013);
    END_INTERFACE
  } ContextInfo2Vtbl;
  struct ContextInfo2 {
    CONST_VTBL struct ContextInfo2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ContextInfo2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ContextInfo2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ContextInfo2_Release(This) (This)->lpVtbl->Release(This)
#define ContextInfo2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ContextInfo2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ContextInfo2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ContextInfo2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ContextInfo2_IsInTransaction(This,pbIsInTx) (This)->lpVtbl->IsInTransaction(This,pbIsInTx)
#define ContextInfo2_GetTransaction(This,ppTx) (This)->lpVtbl->GetTransaction(This,ppTx)
#define ContextInfo2_GetTransactionId(This,pbstrTxId) (This)->lpVtbl->GetTransactionId(This,pbstrTxId)
#define ContextInfo2_GetActivityId(This,pbstrActivityId) (This)->lpVtbl->GetActivityId(This,pbstrActivityId)
#define ContextInfo2_GetContextId(This,pbstrCtxId) (This)->lpVtbl->GetContextId(This,pbstrCtxId)
#define ContextInfo2_GetPartitionId(This,__MIDL_0011) (This)->lpVtbl->GetPartitionId(This,__MIDL_0011)
#define ContextInfo2_GetApplicationId(This,__MIDL_0012) (This)->lpVtbl->GetApplicationId(This,__MIDL_0012)
#define ContextInfo2_GetApplicationInstanceId(This,__MIDL_0013) (This)->lpVtbl->GetApplicationInstanceId(This,__MIDL_0013)
#endif
#endif
  HRESULT WINAPI ContextInfo2_GetPartitionId_Proxy(ContextInfo2 *This,BSTR *__MIDL_0011);
  void __RPC_STUB ContextInfo2_GetPartitionId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ContextInfo2_GetApplicationId_Proxy(ContextInfo2 *This,BSTR *__MIDL_0012);
  void __RPC_STUB ContextInfo2_GetApplicationId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ContextInfo2_GetApplicationInstanceId_Proxy(ContextInfo2 *This,BSTR *__MIDL_0013);
  void __RPC_STUB ContextInfo2_GetApplicationInstanceId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ObjectContext_INTERFACE_DEFINED__
#define __ObjectContext_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ObjectContext;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ObjectContext : public IDispatch {
  public:
    virtual HRESULT WINAPI CreateInstance(BSTR bstrProgID,VARIANT *pObject) = 0;
    virtual HRESULT WINAPI SetComplete(void) = 0;
    virtual HRESULT WINAPI SetAbort(void) = 0;
    virtual HRESULT WINAPI EnableCommit(void) = 0;
    virtual HRESULT WINAPI DisableCommit(void) = 0;
    virtual HRESULT WINAPI IsInTransaction(VARIANT_BOOL *pbIsInTx) = 0;
    virtual HRESULT WINAPI IsSecurityEnabled(VARIANT_BOOL *pbIsEnabled) = 0;
    virtual HRESULT WINAPI IsCallerInRole(BSTR bstrRole,VARIANT_BOOL *pbInRole) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get_Item(BSTR name,VARIANT *pItem) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnum) = 0;
    virtual HRESULT WINAPI get_Security(SecurityProperty **ppSecurityProperty) = 0;
    virtual HRESULT WINAPI get_ContextInfo(ContextInfo **ppContextInfo) = 0;
  };
#else
  typedef struct ObjectContextVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ObjectContext *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ObjectContext *This);
      ULONG (WINAPI *Release)(ObjectContext *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ObjectContext *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ObjectContext *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ObjectContext *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ObjectContext *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *CreateInstance)(ObjectContext *This,BSTR bstrProgID,VARIANT *pObject);
      HRESULT (WINAPI *SetComplete)(ObjectContext *This);
      HRESULT (WINAPI *SetAbort)(ObjectContext *This);
      HRESULT (WINAPI *EnableCommit)(ObjectContext *This);
      HRESULT (WINAPI *DisableCommit)(ObjectContext *This);
      HRESULT (WINAPI *IsInTransaction)(ObjectContext *This,VARIANT_BOOL *pbIsInTx);
      HRESULT (WINAPI *IsSecurityEnabled)(ObjectContext *This,VARIANT_BOOL *pbIsEnabled);
      HRESULT (WINAPI *IsCallerInRole)(ObjectContext *This,BSTR bstrRole,VARIANT_BOOL *pbInRole);
      HRESULT (WINAPI *get_Count)(ObjectContext *This,__LONG32 *plCount);
      HRESULT (WINAPI *get_Item)(ObjectContext *This,BSTR name,VARIANT *pItem);
      HRESULT (WINAPI *get__NewEnum)(ObjectContext *This,IUnknown **ppEnum);
      HRESULT (WINAPI *get_Security)(ObjectContext *This,SecurityProperty **ppSecurityProperty);
      HRESULT (WINAPI *get_ContextInfo)(ObjectContext *This,ContextInfo **ppContextInfo);
    END_INTERFACE
  } ObjectContextVtbl;
  struct ObjectContext {
    CONST_VTBL struct ObjectContextVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ObjectContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ObjectContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ObjectContext_Release(This) (This)->lpVtbl->Release(This)
#define ObjectContext_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ObjectContext_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ObjectContext_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ObjectContext_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ObjectContext_CreateInstance(This,bstrProgID,pObject) (This)->lpVtbl->CreateInstance(This,bstrProgID,pObject)
#define ObjectContext_SetComplete(This) (This)->lpVtbl->SetComplete(This)
#define ObjectContext_SetAbort(This) (This)->lpVtbl->SetAbort(This)
#define ObjectContext_EnableCommit(This) (This)->lpVtbl->EnableCommit(This)
#define ObjectContext_DisableCommit(This) (This)->lpVtbl->DisableCommit(This)
#define ObjectContext_IsInTransaction(This,pbIsInTx) (This)->lpVtbl->IsInTransaction(This,pbIsInTx)
#define ObjectContext_IsSecurityEnabled(This,pbIsEnabled) (This)->lpVtbl->IsSecurityEnabled(This,pbIsEnabled)
#define ObjectContext_IsCallerInRole(This,bstrRole,pbInRole) (This)->lpVtbl->IsCallerInRole(This,bstrRole,pbInRole)
#define ObjectContext_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ObjectContext_get_Item(This,name,pItem) (This)->lpVtbl->get_Item(This,name,pItem)
#define ObjectContext_get__NewEnum(This,ppEnum) (This)->lpVtbl->get__NewEnum(This,ppEnum)
#define ObjectContext_get_Security(This,ppSecurityProperty) (This)->lpVtbl->get_Security(This,ppSecurityProperty)
#define ObjectContext_get_ContextInfo(This,ppContextInfo) (This)->lpVtbl->get_ContextInfo(This,ppContextInfo)
#endif
#endif
  HRESULT WINAPI ObjectContext_CreateInstance_Proxy(ObjectContext *This,BSTR bstrProgID,VARIANT *pObject);
  void __RPC_STUB ObjectContext_CreateInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_SetComplete_Proxy(ObjectContext *This);
  void __RPC_STUB ObjectContext_SetComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_SetAbort_Proxy(ObjectContext *This);
  void __RPC_STUB ObjectContext_SetAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_EnableCommit_Proxy(ObjectContext *This);
  void __RPC_STUB ObjectContext_EnableCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_DisableCommit_Proxy(ObjectContext *This);
  void __RPC_STUB ObjectContext_DisableCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_IsInTransaction_Proxy(ObjectContext *This,VARIANT_BOOL *pbIsInTx);
  void __RPC_STUB ObjectContext_IsInTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_IsSecurityEnabled_Proxy(ObjectContext *This,VARIANT_BOOL *pbIsEnabled);
  void __RPC_STUB ObjectContext_IsSecurityEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_IsCallerInRole_Proxy(ObjectContext *This,BSTR bstrRole,VARIANT_BOOL *pbInRole);
  void __RPC_STUB ObjectContext_IsCallerInRole_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_get_Count_Proxy(ObjectContext *This,__LONG32 *plCount);
  void __RPC_STUB ObjectContext_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_get_Item_Proxy(ObjectContext *This,BSTR name,VARIANT *pItem);
  void __RPC_STUB ObjectContext_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_get__NewEnum_Proxy(ObjectContext *This,IUnknown **ppEnum);
  void __RPC_STUB ObjectContext_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_get_Security_Proxy(ObjectContext *This,SecurityProperty **ppSecurityProperty);
  void __RPC_STUB ObjectContext_get_Security_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectContext_get_ContextInfo_Proxy(ObjectContext *This,ContextInfo **ppContextInfo);
  void __RPC_STUB ObjectContext_get_ContextInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionContextEx_INTERFACE_DEFINED__
#define __ITransactionContextEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionContextEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionContextEx : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateInstance(REFCLSID rclsid,REFIID riid,void **pObject) = 0;
    virtual HRESULT WINAPI Commit(void) = 0;
    virtual HRESULT WINAPI Abort(void) = 0;
  };
#else
  typedef struct ITransactionContextExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionContextEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionContextEx *This);
      ULONG (WINAPI *Release)(ITransactionContextEx *This);
      HRESULT (WINAPI *CreateInstance)(ITransactionContextEx *This,REFCLSID rclsid,REFIID riid,void **pObject);
      HRESULT (WINAPI *Commit)(ITransactionContextEx *This);
      HRESULT (WINAPI *Abort)(ITransactionContextEx *This);
    END_INTERFACE
  } ITransactionContextExVtbl;
  struct ITransactionContextEx {
    CONST_VTBL struct ITransactionContextExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionContextEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionContextEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionContextEx_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionContextEx_CreateInstance(This,rclsid,riid,pObject) (This)->lpVtbl->CreateInstance(This,rclsid,riid,pObject)
#define ITransactionContextEx_Commit(This) (This)->lpVtbl->Commit(This)
#define ITransactionContextEx_Abort(This) (This)->lpVtbl->Abort(This)
#endif
#endif
  HRESULT WINAPI ITransactionContextEx_CreateInstance_Proxy(ITransactionContextEx *This,REFCLSID rclsid,REFIID riid,void **pObject);
  void __RPC_STUB ITransactionContextEx_CreateInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionContextEx_Commit_Proxy(ITransactionContextEx *This);
  void __RPC_STUB ITransactionContextEx_Commit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionContextEx_Abort_Proxy(ITransactionContextEx *This);
  void __RPC_STUB ITransactionContextEx_Abort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionContext_INTERFACE_DEFINED__
#define __ITransactionContext_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionContext;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionContext : public IDispatch {
  public:
    virtual HRESULT WINAPI CreateInstance(BSTR pszProgId,VARIANT *pObject) = 0;
    virtual HRESULT WINAPI Commit(void) = 0;
    virtual HRESULT WINAPI Abort(void) = 0;
  };
#else
  typedef struct ITransactionContextVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionContext *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionContext *This);
      ULONG (WINAPI *Release)(ITransactionContext *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITransactionContext *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITransactionContext *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITransactionContext *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITransactionContext *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *CreateInstance)(ITransactionContext *This,BSTR pszProgId,VARIANT *pObject);
      HRESULT (WINAPI *Commit)(ITransactionContext *This);
      HRESULT (WINAPI *Abort)(ITransactionContext *This);
    END_INTERFACE
  } ITransactionContextVtbl;
  struct ITransactionContext {
    CONST_VTBL struct ITransactionContextVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionContext_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionContext_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITransactionContext_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITransactionContext_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITransactionContext_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITransactionContext_CreateInstance(This,pszProgId,pObject) (This)->lpVtbl->CreateInstance(This,pszProgId,pObject)
#define ITransactionContext_Commit(This) (This)->lpVtbl->Commit(This)
#define ITransactionContext_Abort(This) (This)->lpVtbl->Abort(This)
#endif
#endif
  HRESULT WINAPI ITransactionContext_CreateInstance_Proxy(ITransactionContext *This,BSTR pszProgId,VARIANT *pObject);
  void __RPC_STUB ITransactionContext_CreateInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionContext_Commit_Proxy(ITransactionContext *This);
  void __RPC_STUB ITransactionContext_Commit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionContext_Abort_Proxy(ITransactionContext *This);
  void __RPC_STUB ITransactionContext_Abort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICreateWithTransactionEx_INTERFACE_DEFINED__
#define __ICreateWithTransactionEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICreateWithTransactionEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICreateWithTransactionEx : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateInstance(ITransaction *pTransaction,REFCLSID rclsid,REFIID riid,void **pObject) = 0;
  };
#else
  typedef struct ICreateWithTransactionExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICreateWithTransactionEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICreateWithTransactionEx *This);
      ULONG (WINAPI *Release)(ICreateWithTransactionEx *This);
      HRESULT (WINAPI *CreateInstance)(ICreateWithTransactionEx *This,ITransaction *pTransaction,REFCLSID rclsid,REFIID riid,void **pObject);
    END_INTERFACE
  } ICreateWithTransactionExVtbl;
  struct ICreateWithTransactionEx {
    CONST_VTBL struct ICreateWithTransactionExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICreateWithTransactionEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICreateWithTransactionEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICreateWithTransactionEx_Release(This) (This)->lpVtbl->Release(This)
#define ICreateWithTransactionEx_CreateInstance(This,pTransaction,rclsid,riid,pObject) (This)->lpVtbl->CreateInstance(This,pTransaction,rclsid,riid,pObject)
#endif
#endif
  HRESULT WINAPI ICreateWithTransactionEx_CreateInstance_Proxy(ICreateWithTransactionEx *This,ITransaction *pTransaction,REFCLSID rclsid,REFIID riid,void **pObject);
  void __RPC_STUB ICreateWithTransactionEx_CreateInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICreateWithTipTransactionEx_INTERFACE_DEFINED__
#define __ICreateWithTipTransactionEx_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICreateWithTipTransactionEx;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICreateWithTipTransactionEx : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateInstance(BSTR bstrTipUrl,REFCLSID rclsid,REFIID riid,void **pObject) = 0;
  };
#else
  typedef struct ICreateWithTipTransactionExVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICreateWithTipTransactionEx *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICreateWithTipTransactionEx *This);
      ULONG (WINAPI *Release)(ICreateWithTipTransactionEx *This);
      HRESULT (WINAPI *CreateInstance)(ICreateWithTipTransactionEx *This,BSTR bstrTipUrl,REFCLSID rclsid,REFIID riid,void **pObject);
    END_INTERFACE
  } ICreateWithTipTransactionExVtbl;
  struct ICreateWithTipTransactionEx {
    CONST_VTBL struct ICreateWithTipTransactionExVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICreateWithTipTransactionEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICreateWithTipTransactionEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICreateWithTipTransactionEx_Release(This) (This)->lpVtbl->Release(This)
#define ICreateWithTipTransactionEx_CreateInstance(This,bstrTipUrl,rclsid,riid,pObject) (This)->lpVtbl->CreateInstance(This,bstrTipUrl,rclsid,riid,pObject)
#endif
#endif
  HRESULT WINAPI ICreateWithTipTransactionEx_CreateInstance_Proxy(ICreateWithTipTransactionEx *This,BSTR bstrTipUrl,REFCLSID rclsid,REFIID riid,void **pObject);
  void __RPC_STUB ICreateWithTipTransactionEx_CreateInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  __MINGW_EXTENSION typedef unsigned __int64 MTS_OBJID;
  __MINGW_EXTENSION typedef unsigned __int64 MTS_RESID;
  __MINGW_EXTENSION typedef unsigned __int64 ULONG64;

#ifndef _COMSVCSEVENTINFO_
#define _COMSVCSEVENTINFO_
  typedef struct __MIDL___MIDL_itf_autosvcs_0304_0001 {
    DWORD cbSize;
    DWORD dwPid;
    LONGLONG lTime;
    LONG lMicroTime;
    LONGLONG perfCount;
    GUID guidApp;
    LPOLESTR sMachineName;
  } COMSVCSEVENTINFO;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0304_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0304_v0_0_s_ifspec;

#ifndef __IComUserEvent_INTERFACE_DEFINED__
#define __IComUserEvent_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComUserEvent;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComUserEvent : public IUnknown {
  public:
    virtual HRESULT WINAPI OnUserEvent(COMSVCSEVENTINFO *pInfo,VARIANT *pvarEvent) = 0;
  };
#else
  typedef struct IComUserEventVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComUserEvent *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComUserEvent *This);
      ULONG (WINAPI *Release)(IComUserEvent *This);
      HRESULT (WINAPI *OnUserEvent)(IComUserEvent *This,COMSVCSEVENTINFO *pInfo,VARIANT *pvarEvent);
    END_INTERFACE
  } IComUserEventVtbl;
  struct IComUserEvent {
    CONST_VTBL struct IComUserEventVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComUserEvent_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComUserEvent_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComUserEvent_Release(This) (This)->lpVtbl->Release(This)
#define IComUserEvent_OnUserEvent(This,pInfo,pvarEvent) (This)->lpVtbl->OnUserEvent(This,pInfo,pvarEvent)
#endif
#endif
  HRESULT WINAPI IComUserEvent_OnUserEvent_Proxy(IComUserEvent *This,COMSVCSEVENTINFO *pInfo,VARIANT *pvarEvent);
  void __RPC_STUB IComUserEvent_OnUserEvent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComThreadEvents_INTERFACE_DEFINED__
#define __IComThreadEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComThreadEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComThreadEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnThreadStart(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,DWORD dwThread,DWORD dwTheadCnt) = 0;
    virtual HRESULT WINAPI OnThreadTerminate(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,DWORD dwThread,DWORD dwTheadCnt) = 0;
    virtual HRESULT WINAPI OnThreadBindToApartment(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 AptID,DWORD dwActCnt,DWORD dwLowCnt) = 0;
    virtual HRESULT WINAPI OnThreadUnBind(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 AptID,DWORD dwActCnt) = 0;
    virtual HRESULT WINAPI OnThreadWorkEnque(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen) = 0;
    virtual HRESULT WINAPI OnThreadWorkPrivate(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID) = 0;
    virtual HRESULT WINAPI OnThreadWorkPublic(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen) = 0;
    virtual HRESULT WINAPI OnThreadWorkRedirect(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen,ULONG64 ThreadNum) = 0;
    virtual HRESULT WINAPI OnThreadWorkReject(COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen) = 0;
    virtual HRESULT WINAPI OnThreadAssignApartment(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 AptID) = 0;
    virtual HRESULT WINAPI OnThreadUnassignApartment(COMSVCSEVENTINFO *pInfo,ULONG64 AptID) = 0;
  };
#else
  typedef struct IComThreadEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComThreadEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComThreadEvents *This);
      ULONG (WINAPI *Release)(IComThreadEvents *This);
      HRESULT (WINAPI *OnThreadStart)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,DWORD dwThread,DWORD dwTheadCnt);
      HRESULT (WINAPI *OnThreadTerminate)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,DWORD dwThread,DWORD dwTheadCnt);
      HRESULT (WINAPI *OnThreadBindToApartment)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 AptID,DWORD dwActCnt,DWORD dwLowCnt);
      HRESULT (WINAPI *OnThreadUnBind)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 AptID,DWORD dwActCnt);
      HRESULT (WINAPI *OnThreadWorkEnque)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen);
      HRESULT (WINAPI *OnThreadWorkPrivate)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID);
      HRESULT (WINAPI *OnThreadWorkPublic)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen);
      HRESULT (WINAPI *OnThreadWorkRedirect)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen,ULONG64 ThreadNum);
      HRESULT (WINAPI *OnThreadWorkReject)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen);
      HRESULT (WINAPI *OnThreadAssignApartment)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 AptID);
      HRESULT (WINAPI *OnThreadUnassignApartment)(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 AptID);
    END_INTERFACE
  } IComThreadEventsVtbl;
  struct IComThreadEvents {
    CONST_VTBL struct IComThreadEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComThreadEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComThreadEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComThreadEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComThreadEvents_OnThreadStart(This,pInfo,ThreadID,dwThread,dwTheadCnt) (This)->lpVtbl->OnThreadStart(This,pInfo,ThreadID,dwThread,dwTheadCnt)
#define IComThreadEvents_OnThreadTerminate(This,pInfo,ThreadID,dwThread,dwTheadCnt) (This)->lpVtbl->OnThreadTerminate(This,pInfo,ThreadID,dwThread,dwTheadCnt)
#define IComThreadEvents_OnThreadBindToApartment(This,pInfo,ThreadID,AptID,dwActCnt,dwLowCnt) (This)->lpVtbl->OnThreadBindToApartment(This,pInfo,ThreadID,AptID,dwActCnt,dwLowCnt)
#define IComThreadEvents_OnThreadUnBind(This,pInfo,ThreadID,AptID,dwActCnt) (This)->lpVtbl->OnThreadUnBind(This,pInfo,ThreadID,AptID,dwActCnt)
#define IComThreadEvents_OnThreadWorkEnque(This,pInfo,ThreadID,MsgWorkID,QueueLen) (This)->lpVtbl->OnThreadWorkEnque(This,pInfo,ThreadID,MsgWorkID,QueueLen)
#define IComThreadEvents_OnThreadWorkPrivate(This,pInfo,ThreadID,MsgWorkID) (This)->lpVtbl->OnThreadWorkPrivate(This,pInfo,ThreadID,MsgWorkID)
#define IComThreadEvents_OnThreadWorkPublic(This,pInfo,ThreadID,MsgWorkID,QueueLen) (This)->lpVtbl->OnThreadWorkPublic(This,pInfo,ThreadID,MsgWorkID,QueueLen)
#define IComThreadEvents_OnThreadWorkRedirect(This,pInfo,ThreadID,MsgWorkID,QueueLen,ThreadNum) (This)->lpVtbl->OnThreadWorkRedirect(This,pInfo,ThreadID,MsgWorkID,QueueLen,ThreadNum)
#define IComThreadEvents_OnThreadWorkReject(This,pInfo,ThreadID,MsgWorkID,QueueLen) (This)->lpVtbl->OnThreadWorkReject(This,pInfo,ThreadID,MsgWorkID,QueueLen)
#define IComThreadEvents_OnThreadAssignApartment(This,pInfo,guidActivity,AptID) (This)->lpVtbl->OnThreadAssignApartment(This,pInfo,guidActivity,AptID)
#define IComThreadEvents_OnThreadUnassignApartment(This,pInfo,AptID) (This)->lpVtbl->OnThreadUnassignApartment(This,pInfo,AptID)
#endif
#endif
  HRESULT WINAPI IComThreadEvents_OnThreadStart_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,DWORD dwThread,DWORD dwTheadCnt);
  void __RPC_STUB IComThreadEvents_OnThreadStart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadTerminate_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,DWORD dwThread,DWORD dwTheadCnt);
  void __RPC_STUB IComThreadEvents_OnThreadTerminate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadBindToApartment_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 AptID,DWORD dwActCnt,DWORD dwLowCnt);
  void __RPC_STUB IComThreadEvents_OnThreadBindToApartment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadUnBind_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 AptID,DWORD dwActCnt);
  void __RPC_STUB IComThreadEvents_OnThreadUnBind_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadWorkEnque_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen);
  void __RPC_STUB IComThreadEvents_OnThreadWorkEnque_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadWorkPrivate_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID);
  void __RPC_STUB IComThreadEvents_OnThreadWorkPrivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadWorkPublic_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen);
  void __RPC_STUB IComThreadEvents_OnThreadWorkPublic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadWorkRedirect_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen,ULONG64 ThreadNum);
  void __RPC_STUB IComThreadEvents_OnThreadWorkRedirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadWorkReject_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ThreadID,ULONG64 MsgWorkID,DWORD QueueLen);
  void __RPC_STUB IComThreadEvents_OnThreadWorkReject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadAssignApartment_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 AptID);
  void __RPC_STUB IComThreadEvents_OnThreadAssignApartment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComThreadEvents_OnThreadUnassignApartment_Proxy(IComThreadEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 AptID);
  void __RPC_STUB IComThreadEvents_OnThreadUnassignApartment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComAppEvents_INTERFACE_DEFINED__
#define __IComAppEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComAppEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComAppEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnAppActivation(COMSVCSEVENTINFO *pInfo,GUID guidApp) = 0;
    virtual HRESULT WINAPI OnAppShutdown(COMSVCSEVENTINFO *pInfo,GUID guidApp) = 0;
    virtual HRESULT WINAPI OnAppForceShutdown(COMSVCSEVENTINFO *pInfo,GUID guidApp) = 0;
  };
#else
  typedef struct IComAppEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComAppEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComAppEvents *This);
      ULONG (WINAPI *Release)(IComAppEvents *This);
      HRESULT (WINAPI *OnAppActivation)(IComAppEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
      HRESULT (WINAPI *OnAppShutdown)(IComAppEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
      HRESULT (WINAPI *OnAppForceShutdown)(IComAppEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
    END_INTERFACE
  } IComAppEventsVtbl;
  struct IComAppEvents {
    CONST_VTBL struct IComAppEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComAppEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComAppEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComAppEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComAppEvents_OnAppActivation(This,pInfo,guidApp) (This)->lpVtbl->OnAppActivation(This,pInfo,guidApp)
#define IComAppEvents_OnAppShutdown(This,pInfo,guidApp) (This)->lpVtbl->OnAppShutdown(This,pInfo,guidApp)
#define IComAppEvents_OnAppForceShutdown(This,pInfo,guidApp) (This)->lpVtbl->OnAppForceShutdown(This,pInfo,guidApp)
#endif
#endif
  HRESULT WINAPI IComAppEvents_OnAppActivation_Proxy(IComAppEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
  void __RPC_STUB IComAppEvents_OnAppActivation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComAppEvents_OnAppShutdown_Proxy(IComAppEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
  void __RPC_STUB IComAppEvents_OnAppShutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComAppEvents_OnAppForceShutdown_Proxy(IComAppEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
  void __RPC_STUB IComAppEvents_OnAppForceShutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComInstanceEvents_INTERFACE_DEFINED__
#define __IComInstanceEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComInstanceEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComInstanceEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnObjectCreate(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFCLSID clsid,REFGUID tsid,ULONG64 CtxtID,ULONG64 ObjectID) = 0;
    virtual HRESULT WINAPI OnObjectDestroy(COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID) = 0;
  };
#else
  typedef struct IComInstanceEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComInstanceEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComInstanceEvents *This);
      ULONG (WINAPI *Release)(IComInstanceEvents *This);
      HRESULT (WINAPI *OnObjectCreate)(IComInstanceEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFCLSID clsid,REFGUID tsid,ULONG64 CtxtID,ULONG64 ObjectID);
      HRESULT (WINAPI *OnObjectDestroy)(IComInstanceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
    END_INTERFACE
  } IComInstanceEventsVtbl;
  struct IComInstanceEvents {
    CONST_VTBL struct IComInstanceEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComInstanceEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComInstanceEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComInstanceEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComInstanceEvents_OnObjectCreate(This,pInfo,guidActivity,clsid,tsid,CtxtID,ObjectID) (This)->lpVtbl->OnObjectCreate(This,pInfo,guidActivity,clsid,tsid,CtxtID,ObjectID)
#define IComInstanceEvents_OnObjectDestroy(This,pInfo,CtxtID) (This)->lpVtbl->OnObjectDestroy(This,pInfo,CtxtID)
#endif
#endif
  HRESULT WINAPI IComInstanceEvents_OnObjectCreate_Proxy(IComInstanceEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFCLSID clsid,REFGUID tsid,ULONG64 CtxtID,ULONG64 ObjectID);
  void __RPC_STUB IComInstanceEvents_OnObjectCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComInstanceEvents_OnObjectDestroy_Proxy(IComInstanceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
  void __RPC_STUB IComInstanceEvents_OnObjectDestroy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComTransactionEvents_INTERFACE_DEFINED__
#define __IComTransactionEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComTransactionEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComTransactionEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnTransactionStart(COMSVCSEVENTINFO *pInfo,REFGUID guidTx,REFGUID tsid,WINBOOL fRoot) = 0;
    virtual HRESULT WINAPI OnTransactionPrepare(COMSVCSEVENTINFO *pInfo,REFGUID guidTx,WINBOOL fVoteYes) = 0;
    virtual HRESULT WINAPI OnTransactionAbort(COMSVCSEVENTINFO *pInfo,REFGUID guidTx) = 0;
    virtual HRESULT WINAPI OnTransactionCommit(COMSVCSEVENTINFO *pInfo,REFGUID guidTx) = 0;
  };
#else
  typedef struct IComTransactionEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComTransactionEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComTransactionEvents *This);
      ULONG (WINAPI *Release)(IComTransactionEvents *This);
      HRESULT (WINAPI *OnTransactionStart)(IComTransactionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx,REFGUID tsid,WINBOOL fRoot);
      HRESULT (WINAPI *OnTransactionPrepare)(IComTransactionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx,WINBOOL fVoteYes);
      HRESULT (WINAPI *OnTransactionAbort)(IComTransactionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx);
      HRESULT (WINAPI *OnTransactionCommit)(IComTransactionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx);
    END_INTERFACE
  } IComTransactionEventsVtbl;
  struct IComTransactionEvents {
    CONST_VTBL struct IComTransactionEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComTransactionEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComTransactionEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComTransactionEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComTransactionEvents_OnTransactionStart(This,pInfo,guidTx,tsid,fRoot) (This)->lpVtbl->OnTransactionStart(This,pInfo,guidTx,tsid,fRoot)
#define IComTransactionEvents_OnTransactionPrepare(This,pInfo,guidTx,fVoteYes) (This)->lpVtbl->OnTransactionPrepare(This,pInfo,guidTx,fVoteYes)
#define IComTransactionEvents_OnTransactionAbort(This,pInfo,guidTx) (This)->lpVtbl->OnTransactionAbort(This,pInfo,guidTx)
#define IComTransactionEvents_OnTransactionCommit(This,pInfo,guidTx) (This)->lpVtbl->OnTransactionCommit(This,pInfo,guidTx)
#endif
#endif
  HRESULT WINAPI IComTransactionEvents_OnTransactionStart_Proxy(IComTransactionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx,REFGUID tsid,WINBOOL fRoot);
  void __RPC_STUB IComTransactionEvents_OnTransactionStart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTransactionEvents_OnTransactionPrepare_Proxy(IComTransactionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx,WINBOOL fVoteYes);
  void __RPC_STUB IComTransactionEvents_OnTransactionPrepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTransactionEvents_OnTransactionAbort_Proxy(IComTransactionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx);
  void __RPC_STUB IComTransactionEvents_OnTransactionAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTransactionEvents_OnTransactionCommit_Proxy(IComTransactionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx);
  void __RPC_STUB IComTransactionEvents_OnTransactionCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComMethodEvents_INTERFACE_DEFINED__
#define __IComMethodEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComMethodEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComMethodEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnMethodCall(COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth) = 0;
    virtual HRESULT WINAPI OnMethodReturn(COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth,HRESULT hresult) = 0;
    virtual HRESULT WINAPI OnMethodException(COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth) = 0;
  };
#else
  typedef struct IComMethodEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComMethodEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComMethodEvents *This);
      ULONG (WINAPI *Release)(IComMethodEvents *This);
      HRESULT (WINAPI *OnMethodCall)(IComMethodEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth);
      HRESULT (WINAPI *OnMethodReturn)(IComMethodEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth,HRESULT hresult);
      HRESULT (WINAPI *OnMethodException)(IComMethodEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth);
    END_INTERFACE
  } IComMethodEventsVtbl;
  struct IComMethodEvents {
    CONST_VTBL struct IComMethodEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComMethodEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComMethodEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComMethodEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComMethodEvents_OnMethodCall(This,pInfo,oid,guidCid,guidRid,iMeth) (This)->lpVtbl->OnMethodCall(This,pInfo,oid,guidCid,guidRid,iMeth)
#define IComMethodEvents_OnMethodReturn(This,pInfo,oid,guidCid,guidRid,iMeth,hresult) (This)->lpVtbl->OnMethodReturn(This,pInfo,oid,guidCid,guidRid,iMeth,hresult)
#define IComMethodEvents_OnMethodException(This,pInfo,oid,guidCid,guidRid,iMeth) (This)->lpVtbl->OnMethodException(This,pInfo,oid,guidCid,guidRid,iMeth)
#endif
#endif
  HRESULT WINAPI IComMethodEvents_OnMethodCall_Proxy(IComMethodEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth);
  void __RPC_STUB IComMethodEvents_OnMethodCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComMethodEvents_OnMethodReturn_Proxy(IComMethodEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth,HRESULT hresult);
  void __RPC_STUB IComMethodEvents_OnMethodReturn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComMethodEvents_OnMethodException_Proxy(IComMethodEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,ULONG iMeth);
  void __RPC_STUB IComMethodEvents_OnMethodException_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComObjectEvents_INTERFACE_DEFINED__
#define __IComObjectEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComObjectEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComObjectEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnObjectActivate(COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID,ULONG64 ObjectID) = 0;
    virtual HRESULT WINAPI OnObjectDeactivate(COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID,ULONG64 ObjectID) = 0;
    virtual HRESULT WINAPI OnDisableCommit(COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID) = 0;
    virtual HRESULT WINAPI OnEnableCommit(COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID) = 0;
    virtual HRESULT WINAPI OnSetComplete(COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID) = 0;
    virtual HRESULT WINAPI OnSetAbort(COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID) = 0;
  };
#else
  typedef struct IComObjectEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComObjectEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComObjectEvents *This);
      ULONG (WINAPI *Release)(IComObjectEvents *This);
      HRESULT (WINAPI *OnObjectActivate)(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID,ULONG64 ObjectID);
      HRESULT (WINAPI *OnObjectDeactivate)(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID,ULONG64 ObjectID);
      HRESULT (WINAPI *OnDisableCommit)(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
      HRESULT (WINAPI *OnEnableCommit)(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
      HRESULT (WINAPI *OnSetComplete)(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
      HRESULT (WINAPI *OnSetAbort)(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
    END_INTERFACE
  } IComObjectEventsVtbl;
  struct IComObjectEvents {
    CONST_VTBL struct IComObjectEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComObjectEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComObjectEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComObjectEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComObjectEvents_OnObjectActivate(This,pInfo,CtxtID,ObjectID) (This)->lpVtbl->OnObjectActivate(This,pInfo,CtxtID,ObjectID)
#define IComObjectEvents_OnObjectDeactivate(This,pInfo,CtxtID,ObjectID) (This)->lpVtbl->OnObjectDeactivate(This,pInfo,CtxtID,ObjectID)
#define IComObjectEvents_OnDisableCommit(This,pInfo,CtxtID) (This)->lpVtbl->OnDisableCommit(This,pInfo,CtxtID)
#define IComObjectEvents_OnEnableCommit(This,pInfo,CtxtID) (This)->lpVtbl->OnEnableCommit(This,pInfo,CtxtID)
#define IComObjectEvents_OnSetComplete(This,pInfo,CtxtID) (This)->lpVtbl->OnSetComplete(This,pInfo,CtxtID)
#define IComObjectEvents_OnSetAbort(This,pInfo,CtxtID) (This)->lpVtbl->OnSetAbort(This,pInfo,CtxtID)
#endif
#endif
  HRESULT WINAPI IComObjectEvents_OnObjectActivate_Proxy(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID,ULONG64 ObjectID);
  void __RPC_STUB IComObjectEvents_OnObjectActivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectEvents_OnObjectDeactivate_Proxy(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID,ULONG64 ObjectID);
  void __RPC_STUB IComObjectEvents_OnObjectDeactivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectEvents_OnDisableCommit_Proxy(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
  void __RPC_STUB IComObjectEvents_OnDisableCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectEvents_OnEnableCommit_Proxy(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
  void __RPC_STUB IComObjectEvents_OnEnableCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectEvents_OnSetComplete_Proxy(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
  void __RPC_STUB IComObjectEvents_OnSetComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectEvents_OnSetAbort_Proxy(IComObjectEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
  void __RPC_STUB IComObjectEvents_OnSetAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComResourceEvents_INTERFACE_DEFINED__
#define __IComResourceEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComResourceEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComResourceEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnResourceCreate(COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted) = 0;
    virtual HRESULT WINAPI OnResourceAllocate(COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted,DWORD NumRated,DWORD Rating) = 0;
    virtual HRESULT WINAPI OnResourceRecycle(COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId) = 0;
    virtual HRESULT WINAPI OnResourceDestroy(COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,HRESULT hr,LPCOLESTR pszType,ULONG64 resId) = 0;
    virtual HRESULT WINAPI OnResourceTrack(COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted) = 0;
  };
#else
  typedef struct IComResourceEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComResourceEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComResourceEvents *This);
      ULONG (WINAPI *Release)(IComResourceEvents *This);
      HRESULT (WINAPI *OnResourceCreate)(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted);
      HRESULT (WINAPI *OnResourceAllocate)(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted,DWORD NumRated,DWORD Rating);
      HRESULT (WINAPI *OnResourceRecycle)(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId);
      HRESULT (WINAPI *OnResourceDestroy)(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,HRESULT hr,LPCOLESTR pszType,ULONG64 resId);
      HRESULT (WINAPI *OnResourceTrack)(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted);
    END_INTERFACE
  } IComResourceEventsVtbl;
  struct IComResourceEvents {
    CONST_VTBL struct IComResourceEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComResourceEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComResourceEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComResourceEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComResourceEvents_OnResourceCreate(This,pInfo,ObjectID,pszType,resId,enlisted) (This)->lpVtbl->OnResourceCreate(This,pInfo,ObjectID,pszType,resId,enlisted)
#define IComResourceEvents_OnResourceAllocate(This,pInfo,ObjectID,pszType,resId,enlisted,NumRated,Rating) (This)->lpVtbl->OnResourceAllocate(This,pInfo,ObjectID,pszType,resId,enlisted,NumRated,Rating)
#define IComResourceEvents_OnResourceRecycle(This,pInfo,ObjectID,pszType,resId) (This)->lpVtbl->OnResourceRecycle(This,pInfo,ObjectID,pszType,resId)
#define IComResourceEvents_OnResourceDestroy(This,pInfo,ObjectID,hr,pszType,resId) (This)->lpVtbl->OnResourceDestroy(This,pInfo,ObjectID,hr,pszType,resId)
#define IComResourceEvents_OnResourceTrack(This,pInfo,ObjectID,pszType,resId,enlisted) (This)->lpVtbl->OnResourceTrack(This,pInfo,ObjectID,pszType,resId,enlisted)
#endif
#endif
  HRESULT WINAPI IComResourceEvents_OnResourceCreate_Proxy(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted);
  void __RPC_STUB IComResourceEvents_OnResourceCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComResourceEvents_OnResourceAllocate_Proxy(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted,DWORD NumRated,DWORD Rating);
  void __RPC_STUB IComResourceEvents_OnResourceAllocate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComResourceEvents_OnResourceRecycle_Proxy(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId);
  void __RPC_STUB IComResourceEvents_OnResourceRecycle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComResourceEvents_OnResourceDestroy_Proxy(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,HRESULT hr,LPCOLESTR pszType,ULONG64 resId);
  void __RPC_STUB IComResourceEvents_OnResourceDestroy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComResourceEvents_OnResourceTrack_Proxy(IComResourceEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjectID,LPCOLESTR pszType,ULONG64 resId,WINBOOL enlisted);
  void __RPC_STUB IComResourceEvents_OnResourceTrack_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComSecurityEvents_INTERFACE_DEFINED__
#define __IComSecurityEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComSecurityEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComSecurityEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnAuthenticate(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 ObjectID,REFGUID guidIID,ULONG iMeth,ULONG cbByteOrig,BYTE *pSidOriginalUser,ULONG cbByteCur,BYTE *pSidCurrentUser,WINBOOL bCurrentUserInpersonatingInProc) = 0;
    virtual HRESULT WINAPI OnAuthenticateFail(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 ObjectID,REFGUID guidIID,ULONG iMeth,ULONG cbByteOrig,BYTE *pSidOriginalUser,ULONG cbByteCur,BYTE *pSidCurrentUser,WINBOOL bCurrentUserInpersonatingInProc) = 0;
  };
#else
  typedef struct IComSecurityEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComSecurityEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComSecurityEvents *This);
      ULONG (WINAPI *Release)(IComSecurityEvents *This);
      HRESULT (WINAPI *OnAuthenticate)(IComSecurityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 ObjectID,REFGUID guidIID,ULONG iMeth,ULONG cbByteOrig,BYTE *pSidOriginalUser,ULONG cbByteCur,BYTE *pSidCurrentUser,WINBOOL bCurrentUserInpersonatingInProc);
      HRESULT (WINAPI *OnAuthenticateFail)(IComSecurityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 ObjectID,REFGUID guidIID,ULONG iMeth,ULONG cbByteOrig,BYTE *pSidOriginalUser,ULONG cbByteCur,BYTE *pSidCurrentUser,WINBOOL bCurrentUserInpersonatingInProc);
    END_INTERFACE
  } IComSecurityEventsVtbl;
  struct IComSecurityEvents {
    CONST_VTBL struct IComSecurityEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComSecurityEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComSecurityEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComSecurityEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComSecurityEvents_OnAuthenticate(This,pInfo,guidActivity,ObjectID,guidIID,iMeth,cbByteOrig,pSidOriginalUser,cbByteCur,pSidCurrentUser,bCurrentUserInpersonatingInProc) (This)->lpVtbl->OnAuthenticate(This,pInfo,guidActivity,ObjectID,guidIID,iMeth,cbByteOrig,pSidOriginalUser,cbByteCur,pSidCurrentUser,bCurrentUserInpersonatingInProc)
#define IComSecurityEvents_OnAuthenticateFail(This,pInfo,guidActivity,ObjectID,guidIID,iMeth,cbByteOrig,pSidOriginalUser,cbByteCur,pSidCurrentUser,bCurrentUserInpersonatingInProc) (This)->lpVtbl->OnAuthenticateFail(This,pInfo,guidActivity,ObjectID,guidIID,iMeth,cbByteOrig,pSidOriginalUser,cbByteCur,pSidCurrentUser,bCurrentUserInpersonatingInProc)
#endif
#endif
  HRESULT WINAPI IComSecurityEvents_OnAuthenticate_Proxy(IComSecurityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 ObjectID,REFGUID guidIID,ULONG iMeth,ULONG cbByteOrig,BYTE *pSidOriginalUser,ULONG cbByteCur,BYTE *pSidCurrentUser,WINBOOL bCurrentUserInpersonatingInProc);
  void __RPC_STUB IComSecurityEvents_OnAuthenticate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComSecurityEvents_OnAuthenticateFail_Proxy(IComSecurityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,ULONG64 ObjectID,REFGUID guidIID,ULONG iMeth,ULONG cbByteOrig,BYTE *pSidOriginalUser,ULONG cbByteCur,BYTE *pSidCurrentUser,WINBOOL bCurrentUserInpersonatingInProc);
  void __RPC_STUB IComSecurityEvents_OnAuthenticateFail_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComObjectPoolEvents_INTERFACE_DEFINED__
#define __IComObjectPoolEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComObjectPoolEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComObjectPoolEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnObjPoolPutObject(COMSVCSEVENTINFO *pInfo,REFGUID guidObject,int nReason,DWORD dwAvailable,ULONG64 oid) = 0;
    virtual HRESULT WINAPI OnObjPoolGetObject(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,DWORD dwAvailable,ULONG64 oid) = 0;
    virtual HRESULT WINAPI OnObjPoolRecycleToTx(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid) = 0;
    virtual HRESULT WINAPI OnObjPoolGetFromTx(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid) = 0;
  };
#else
  typedef struct IComObjectPoolEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComObjectPoolEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComObjectPoolEvents *This);
      ULONG (WINAPI *Release)(IComObjectPoolEvents *This);
      HRESULT (WINAPI *OnObjPoolPutObject)(IComObjectPoolEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,int nReason,DWORD dwAvailable,ULONG64 oid);
      HRESULT (WINAPI *OnObjPoolGetObject)(IComObjectPoolEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,DWORD dwAvailable,ULONG64 oid);
      HRESULT (WINAPI *OnObjPoolRecycleToTx)(IComObjectPoolEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid);
      HRESULT (WINAPI *OnObjPoolGetFromTx)(IComObjectPoolEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid);
    END_INTERFACE
  } IComObjectPoolEventsVtbl;
  struct IComObjectPoolEvents {
    CONST_VTBL struct IComObjectPoolEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComObjectPoolEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComObjectPoolEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComObjectPoolEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComObjectPoolEvents_OnObjPoolPutObject(This,pInfo,guidObject,nReason,dwAvailable,oid) (This)->lpVtbl->OnObjPoolPutObject(This,pInfo,guidObject,nReason,dwAvailable,oid)
#define IComObjectPoolEvents_OnObjPoolGetObject(This,pInfo,guidActivity,guidObject,dwAvailable,oid) (This)->lpVtbl->OnObjPoolGetObject(This,pInfo,guidActivity,guidObject,dwAvailable,oid)
#define IComObjectPoolEvents_OnObjPoolRecycleToTx(This,pInfo,guidActivity,guidObject,guidTx,objid) (This)->lpVtbl->OnObjPoolRecycleToTx(This,pInfo,guidActivity,guidObject,guidTx,objid)
#define IComObjectPoolEvents_OnObjPoolGetFromTx(This,pInfo,guidActivity,guidObject,guidTx,objid) (This)->lpVtbl->OnObjPoolGetFromTx(This,pInfo,guidActivity,guidObject,guidTx,objid)
#endif
#endif
  HRESULT WINAPI IComObjectPoolEvents_OnObjPoolPutObject_Proxy(IComObjectPoolEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,int nReason,DWORD dwAvailable,ULONG64 oid);
  void __RPC_STUB IComObjectPoolEvents_OnObjPoolPutObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPoolEvents_OnObjPoolGetObject_Proxy(IComObjectPoolEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,DWORD dwAvailable,ULONG64 oid);
  void __RPC_STUB IComObjectPoolEvents_OnObjPoolGetObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPoolEvents_OnObjPoolRecycleToTx_Proxy(IComObjectPoolEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid);
  void __RPC_STUB IComObjectPoolEvents_OnObjPoolRecycleToTx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPoolEvents_OnObjPoolGetFromTx_Proxy(IComObjectPoolEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid);
  void __RPC_STUB IComObjectPoolEvents_OnObjPoolGetFromTx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComObjectPoolEvents2_INTERFACE_DEFINED__
#define __IComObjectPoolEvents2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComObjectPoolEvents2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComObjectPoolEvents2 : public IUnknown {
  public:
    virtual HRESULT WINAPI OnObjPoolCreateObject(COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwObjsCreated,ULONG64 oid) = 0;
    virtual HRESULT WINAPI OnObjPoolDestroyObject(COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwObjsCreated,ULONG64 oid) = 0;
    virtual HRESULT WINAPI OnObjPoolCreateDecision(COMSVCSEVENTINFO *pInfo,DWORD dwThreadsWaiting,DWORD dwAvail,DWORD dwCreated,DWORD dwMin,DWORD dwMax) = 0;
    virtual HRESULT WINAPI OnObjPoolTimeout(COMSVCSEVENTINFO *pInfo,REFGUID guidObject,REFGUID guidActivity,DWORD dwTimeout) = 0;
    virtual HRESULT WINAPI OnObjPoolCreatePool(COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwMin,DWORD dwMax,DWORD dwTimeout) = 0;
  };
#else
  typedef struct IComObjectPoolEvents2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComObjectPoolEvents2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComObjectPoolEvents2 *This);
      ULONG (WINAPI *Release)(IComObjectPoolEvents2 *This);
      HRESULT (WINAPI *OnObjPoolCreateObject)(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwObjsCreated,ULONG64 oid);
      HRESULT (WINAPI *OnObjPoolDestroyObject)(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwObjsCreated,ULONG64 oid);
      HRESULT (WINAPI *OnObjPoolCreateDecision)(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,DWORD dwThreadsWaiting,DWORD dwAvail,DWORD dwCreated,DWORD dwMin,DWORD dwMax);
      HRESULT (WINAPI *OnObjPoolTimeout)(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,REFGUID guidActivity,DWORD dwTimeout);
      HRESULT (WINAPI *OnObjPoolCreatePool)(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwMin,DWORD dwMax,DWORD dwTimeout);
    END_INTERFACE
  } IComObjectPoolEvents2Vtbl;
  struct IComObjectPoolEvents2 {
    CONST_VTBL struct IComObjectPoolEvents2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComObjectPoolEvents2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComObjectPoolEvents2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComObjectPoolEvents2_Release(This) (This)->lpVtbl->Release(This)
#define IComObjectPoolEvents2_OnObjPoolCreateObject(This,pInfo,guidObject,dwObjsCreated,oid) (This)->lpVtbl->OnObjPoolCreateObject(This,pInfo,guidObject,dwObjsCreated,oid)
#define IComObjectPoolEvents2_OnObjPoolDestroyObject(This,pInfo,guidObject,dwObjsCreated,oid) (This)->lpVtbl->OnObjPoolDestroyObject(This,pInfo,guidObject,dwObjsCreated,oid)
#define IComObjectPoolEvents2_OnObjPoolCreateDecision(This,pInfo,dwThreadsWaiting,dwAvail,dwCreated,dwMin,dwMax) (This)->lpVtbl->OnObjPoolCreateDecision(This,pInfo,dwThreadsWaiting,dwAvail,dwCreated,dwMin,dwMax)
#define IComObjectPoolEvents2_OnObjPoolTimeout(This,pInfo,guidObject,guidActivity,dwTimeout) (This)->lpVtbl->OnObjPoolTimeout(This,pInfo,guidObject,guidActivity,dwTimeout)
#define IComObjectPoolEvents2_OnObjPoolCreatePool(This,pInfo,guidObject,dwMin,dwMax,dwTimeout) (This)->lpVtbl->OnObjPoolCreatePool(This,pInfo,guidObject,dwMin,dwMax,dwTimeout)
#endif
#endif
  HRESULT WINAPI IComObjectPoolEvents2_OnObjPoolCreateObject_Proxy(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwObjsCreated,ULONG64 oid);
  void __RPC_STUB IComObjectPoolEvents2_OnObjPoolCreateObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPoolEvents2_OnObjPoolDestroyObject_Proxy(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwObjsCreated,ULONG64 oid);
  void __RPC_STUB IComObjectPoolEvents2_OnObjPoolDestroyObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPoolEvents2_OnObjPoolCreateDecision_Proxy(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,DWORD dwThreadsWaiting,DWORD dwAvail,DWORD dwCreated,DWORD dwMin,DWORD dwMax);
  void __RPC_STUB IComObjectPoolEvents2_OnObjPoolCreateDecision_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPoolEvents2_OnObjPoolTimeout_Proxy(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,REFGUID guidActivity,DWORD dwTimeout);
  void __RPC_STUB IComObjectPoolEvents2_OnObjPoolTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPoolEvents2_OnObjPoolCreatePool_Proxy(IComObjectPoolEvents2 *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,DWORD dwMin,DWORD dwMax,DWORD dwTimeout);
  void __RPC_STUB IComObjectPoolEvents2_OnObjPoolCreatePool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComObjectConstructionEvents_INTERFACE_DEFINED__
#define __IComObjectConstructionEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComObjectConstructionEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComObjectConstructionEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnObjectConstruct(COMSVCSEVENTINFO *pInfo,REFGUID guidObject,LPCOLESTR sConstructString,ULONG64 oid) = 0;
  };
#else
  typedef struct IComObjectConstructionEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComObjectConstructionEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComObjectConstructionEvents *This);
      ULONG (WINAPI *Release)(IComObjectConstructionEvents *This);
      HRESULT (WINAPI *OnObjectConstruct)(IComObjectConstructionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,LPCOLESTR sConstructString,ULONG64 oid);
    END_INTERFACE
  } IComObjectConstructionEventsVtbl;
  struct IComObjectConstructionEvents {
    CONST_VTBL struct IComObjectConstructionEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComObjectConstructionEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComObjectConstructionEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComObjectConstructionEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComObjectConstructionEvents_OnObjectConstruct(This,pInfo,guidObject,sConstructString,oid) (This)->lpVtbl->OnObjectConstruct(This,pInfo,guidObject,sConstructString,oid)
#endif
#endif
  HRESULT WINAPI IComObjectConstructionEvents_OnObjectConstruct_Proxy(IComObjectConstructionEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,LPCOLESTR sConstructString,ULONG64 oid);
  void __RPC_STUB IComObjectConstructionEvents_OnObjectConstruct_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComActivityEvents_INTERFACE_DEFINED__
#define __IComActivityEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComActivityEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComActivityEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnActivityCreate(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity) = 0;
    virtual HRESULT WINAPI OnActivityDestroy(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity) = 0;
    virtual HRESULT WINAPI OnActivityEnter(COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidEntered,DWORD dwThread) = 0;
    virtual HRESULT WINAPI OnActivityTimeout(COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidEntered,DWORD dwThread,DWORD dwTimeout) = 0;
    virtual HRESULT WINAPI OnActivityReenter(COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,DWORD dwThread,DWORD dwCallDepth) = 0;
    virtual HRESULT WINAPI OnActivityLeave(COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidLeft) = 0;
    virtual HRESULT WINAPI OnActivityLeaveSame(COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,DWORD dwCallDepth) = 0;
  };
#else
  typedef struct IComActivityEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComActivityEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComActivityEvents *This);
      ULONG (WINAPI *Release)(IComActivityEvents *This);
      HRESULT (WINAPI *OnActivityCreate)(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity);
      HRESULT (WINAPI *OnActivityDestroy)(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity);
      HRESULT (WINAPI *OnActivityEnter)(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidEntered,DWORD dwThread);
      HRESULT (WINAPI *OnActivityTimeout)(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidEntered,DWORD dwThread,DWORD dwTimeout);
      HRESULT (WINAPI *OnActivityReenter)(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,DWORD dwThread,DWORD dwCallDepth);
      HRESULT (WINAPI *OnActivityLeave)(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidLeft);
      HRESULT (WINAPI *OnActivityLeaveSame)(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,DWORD dwCallDepth);
    END_INTERFACE
  } IComActivityEventsVtbl;
  struct IComActivityEvents {
    CONST_VTBL struct IComActivityEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComActivityEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComActivityEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComActivityEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComActivityEvents_OnActivityCreate(This,pInfo,guidActivity) (This)->lpVtbl->OnActivityCreate(This,pInfo,guidActivity)
#define IComActivityEvents_OnActivityDestroy(This,pInfo,guidActivity) (This)->lpVtbl->OnActivityDestroy(This,pInfo,guidActivity)
#define IComActivityEvents_OnActivityEnter(This,pInfo,guidCurrent,guidEntered,dwThread) (This)->lpVtbl->OnActivityEnter(This,pInfo,guidCurrent,guidEntered,dwThread)
#define IComActivityEvents_OnActivityTimeout(This,pInfo,guidCurrent,guidEntered,dwThread,dwTimeout) (This)->lpVtbl->OnActivityTimeout(This,pInfo,guidCurrent,guidEntered,dwThread,dwTimeout)
#define IComActivityEvents_OnActivityReenter(This,pInfo,guidCurrent,dwThread,dwCallDepth) (This)->lpVtbl->OnActivityReenter(This,pInfo,guidCurrent,dwThread,dwCallDepth)
#define IComActivityEvents_OnActivityLeave(This,pInfo,guidCurrent,guidLeft) (This)->lpVtbl->OnActivityLeave(This,pInfo,guidCurrent,guidLeft)
#define IComActivityEvents_OnActivityLeaveSame(This,pInfo,guidCurrent,dwCallDepth) (This)->lpVtbl->OnActivityLeaveSame(This,pInfo,guidCurrent,dwCallDepth)
#endif
#endif
  HRESULT WINAPI IComActivityEvents_OnActivityCreate_Proxy(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity);
  void __RPC_STUB IComActivityEvents_OnActivityCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComActivityEvents_OnActivityDestroy_Proxy(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity);
  void __RPC_STUB IComActivityEvents_OnActivityDestroy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComActivityEvents_OnActivityEnter_Proxy(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidEntered,DWORD dwThread);
  void __RPC_STUB IComActivityEvents_OnActivityEnter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComActivityEvents_OnActivityTimeout_Proxy(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidEntered,DWORD dwThread,DWORD dwTimeout);
  void __RPC_STUB IComActivityEvents_OnActivityTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComActivityEvents_OnActivityReenter_Proxy(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,DWORD dwThread,DWORD dwCallDepth);
  void __RPC_STUB IComActivityEvents_OnActivityReenter_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComActivityEvents_OnActivityLeave_Proxy(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,REFGUID guidLeft);
  void __RPC_STUB IComActivityEvents_OnActivityLeave_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComActivityEvents_OnActivityLeaveSame_Proxy(IComActivityEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidCurrent,DWORD dwCallDepth);
  void __RPC_STUB IComActivityEvents_OnActivityLeaveSame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComIdentityEvents_INTERFACE_DEFINED__
#define __IComIdentityEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComIdentityEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComIdentityEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnIISRequestInfo(COMSVCSEVENTINFO *pInfo,ULONG64 ObjId,LPCOLESTR pszClientIP,LPCOLESTR pszServerIP,LPCOLESTR pszURL) = 0;
  };
#else
  typedef struct IComIdentityEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComIdentityEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComIdentityEvents *This);
      ULONG (WINAPI *Release)(IComIdentityEvents *This);
      HRESULT (WINAPI *OnIISRequestInfo)(IComIdentityEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjId,LPCOLESTR pszClientIP,LPCOLESTR pszServerIP,LPCOLESTR pszURL);
    END_INTERFACE
  } IComIdentityEventsVtbl;
  struct IComIdentityEvents {
    CONST_VTBL struct IComIdentityEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComIdentityEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComIdentityEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComIdentityEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComIdentityEvents_OnIISRequestInfo(This,pInfo,ObjId,pszClientIP,pszServerIP,pszURL) (This)->lpVtbl->OnIISRequestInfo(This,pInfo,ObjId,pszClientIP,pszServerIP,pszURL)
#endif
#endif
  HRESULT WINAPI IComIdentityEvents_OnIISRequestInfo_Proxy(IComIdentityEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 ObjId,LPCOLESTR pszClientIP,LPCOLESTR pszServerIP,LPCOLESTR pszURL);
  void __RPC_STUB IComIdentityEvents_OnIISRequestInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComQCEvents_INTERFACE_DEFINED__
#define __IComQCEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComQCEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComQCEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnQCRecord(COMSVCSEVENTINFO *pInfo,ULONG64 objid,WCHAR szQueue[60],REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT msmqhr) = 0;
    virtual HRESULT WINAPI OnQCQueueOpen(COMSVCSEVENTINFO *pInfo,WCHAR szQueue[60],ULONG64 QueueID,HRESULT hr) = 0;
    virtual HRESULT WINAPI OnQCReceive(COMSVCSEVENTINFO *pInfo,ULONG64 QueueID,REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT hr) = 0;
    virtual HRESULT WINAPI OnQCReceiveFail(COMSVCSEVENTINFO *pInfo,ULONG64 QueueID,HRESULT msmqhr) = 0;
    virtual HRESULT WINAPI OnQCMoveToReTryQueue(COMSVCSEVENTINFO *pInfo,REFGUID guidMsgId,REFGUID guidWorkFlowId,ULONG RetryIndex) = 0;
    virtual HRESULT WINAPI OnQCMoveToDeadQueue(COMSVCSEVENTINFO *pInfo,REFGUID guidMsgId,REFGUID guidWorkFlowId) = 0;
    virtual HRESULT WINAPI OnQCPlayback(COMSVCSEVENTINFO *pInfo,ULONG64 objid,REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT hr) = 0;
  };
#else
  typedef struct IComQCEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComQCEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComQCEvents *This);
      ULONG (WINAPI *Release)(IComQCEvents *This);
      HRESULT (WINAPI *OnQCRecord)(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 objid,WCHAR szQueue[60],REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT msmqhr);
      HRESULT (WINAPI *OnQCQueueOpen)(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,WCHAR szQueue[60],ULONG64 QueueID,HRESULT hr);
      HRESULT (WINAPI *OnQCReceive)(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 QueueID,REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT hr);
      HRESULT (WINAPI *OnQCReceiveFail)(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 QueueID,HRESULT msmqhr);
      HRESULT (WINAPI *OnQCMoveToReTryQueue)(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidMsgId,REFGUID guidWorkFlowId,ULONG RetryIndex);
      HRESULT (WINAPI *OnQCMoveToDeadQueue)(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidMsgId,REFGUID guidWorkFlowId);
      HRESULT (WINAPI *OnQCPlayback)(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 objid,REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT hr);
    END_INTERFACE
  } IComQCEventsVtbl;
  struct IComQCEvents {
    CONST_VTBL struct IComQCEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComQCEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComQCEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComQCEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComQCEvents_OnQCRecord(This,pInfo,objid,szQueue,guidMsgId,guidWorkFlowId,msmqhr) (This)->lpVtbl->OnQCRecord(This,pInfo,objid,szQueue,guidMsgId,guidWorkFlowId,msmqhr)
#define IComQCEvents_OnQCQueueOpen(This,pInfo,szQueue,QueueID,hr) (This)->lpVtbl->OnQCQueueOpen(This,pInfo,szQueue,QueueID,hr)
#define IComQCEvents_OnQCReceive(This,pInfo,QueueID,guidMsgId,guidWorkFlowId,hr) (This)->lpVtbl->OnQCReceive(This,pInfo,QueueID,guidMsgId,guidWorkFlowId,hr)
#define IComQCEvents_OnQCReceiveFail(This,pInfo,QueueID,msmqhr) (This)->lpVtbl->OnQCReceiveFail(This,pInfo,QueueID,msmqhr)
#define IComQCEvents_OnQCMoveToReTryQueue(This,pInfo,guidMsgId,guidWorkFlowId,RetryIndex) (This)->lpVtbl->OnQCMoveToReTryQueue(This,pInfo,guidMsgId,guidWorkFlowId,RetryIndex)
#define IComQCEvents_OnQCMoveToDeadQueue(This,pInfo,guidMsgId,guidWorkFlowId) (This)->lpVtbl->OnQCMoveToDeadQueue(This,pInfo,guidMsgId,guidWorkFlowId)
#define IComQCEvents_OnQCPlayback(This,pInfo,objid,guidMsgId,guidWorkFlowId,hr) (This)->lpVtbl->OnQCPlayback(This,pInfo,objid,guidMsgId,guidWorkFlowId,hr)
#endif
#endif
  HRESULT WINAPI IComQCEvents_OnQCRecord_Proxy(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 objid,WCHAR szQueue[60],REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT msmqhr);
  void __RPC_STUB IComQCEvents_OnQCRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComQCEvents_OnQCQueueOpen_Proxy(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,WCHAR szQueue[60],ULONG64 QueueID,HRESULT hr);
  void __RPC_STUB IComQCEvents_OnQCQueueOpen_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComQCEvents_OnQCReceive_Proxy(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 QueueID,REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT hr);
  void __RPC_STUB IComQCEvents_OnQCReceive_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComQCEvents_OnQCReceiveFail_Proxy(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 QueueID,HRESULT msmqhr);
  void __RPC_STUB IComQCEvents_OnQCReceiveFail_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComQCEvents_OnQCMoveToReTryQueue_Proxy(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidMsgId,REFGUID guidWorkFlowId,ULONG RetryIndex);
  void __RPC_STUB IComQCEvents_OnQCMoveToReTryQueue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComQCEvents_OnQCMoveToDeadQueue_Proxy(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,REFGUID guidMsgId,REFGUID guidWorkFlowId);
  void __RPC_STUB IComQCEvents_OnQCMoveToDeadQueue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComQCEvents_OnQCPlayback_Proxy(IComQCEvents *This,COMSVCSEVENTINFO *pInfo,ULONG64 objid,REFGUID guidMsgId,REFGUID guidWorkFlowId,HRESULT hr);
  void __RPC_STUB IComQCEvents_OnQCPlayback_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComExceptionEvents_INTERFACE_DEFINED__
#define __IComExceptionEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComExceptionEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComExceptionEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnExceptionUser(COMSVCSEVENTINFO *pInfo,ULONG code,ULONG64 address,LPCOLESTR pszStackTrace) = 0;
  };
#else
  typedef struct IComExceptionEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComExceptionEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComExceptionEvents *This);
      ULONG (WINAPI *Release)(IComExceptionEvents *This);
      HRESULT (WINAPI *OnExceptionUser)(IComExceptionEvents *This,COMSVCSEVENTINFO *pInfo,ULONG code,ULONG64 address,LPCOLESTR pszStackTrace);
    END_INTERFACE
  } IComExceptionEventsVtbl;
  struct IComExceptionEvents {
    CONST_VTBL struct IComExceptionEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComExceptionEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComExceptionEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComExceptionEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComExceptionEvents_OnExceptionUser(This,pInfo,code,address,pszStackTrace) (This)->lpVtbl->OnExceptionUser(This,pInfo,code,address,pszStackTrace)
#endif
#endif
  HRESULT WINAPI IComExceptionEvents_OnExceptionUser_Proxy(IComExceptionEvents *This,COMSVCSEVENTINFO *pInfo,ULONG code,ULONG64 address,LPCOLESTR pszStackTrace);
  void __RPC_STUB IComExceptionEvents_OnExceptionUser_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ILBEvents_INTERFACE_DEFINED__
#define __ILBEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ILBEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ILBEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI TargetUp(BSTR bstrServerName,BSTR bstrClsidEng) = 0;
    virtual HRESULT WINAPI TargetDown(BSTR bstrServerName,BSTR bstrClsidEng) = 0;
    virtual HRESULT WINAPI EngineDefined(BSTR bstrPropName,VARIANT *varPropValue,BSTR bstrClsidEng) = 0;
  };
#else
  typedef struct ILBEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ILBEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ILBEvents *This);
      ULONG (WINAPI *Release)(ILBEvents *This);
      HRESULT (WINAPI *TargetUp)(ILBEvents *This,BSTR bstrServerName,BSTR bstrClsidEng);
      HRESULT (WINAPI *TargetDown)(ILBEvents *This,BSTR bstrServerName,BSTR bstrClsidEng);
      HRESULT (WINAPI *EngineDefined)(ILBEvents *This,BSTR bstrPropName,VARIANT *varPropValue,BSTR bstrClsidEng);
    END_INTERFACE
  } ILBEventsVtbl;
  struct ILBEvents {
    CONST_VTBL struct ILBEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ILBEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ILBEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ILBEvents_Release(This) (This)->lpVtbl->Release(This)
#define ILBEvents_TargetUp(This,bstrServerName,bstrClsidEng) (This)->lpVtbl->TargetUp(This,bstrServerName,bstrClsidEng)
#define ILBEvents_TargetDown(This,bstrServerName,bstrClsidEng) (This)->lpVtbl->TargetDown(This,bstrServerName,bstrClsidEng)
#define ILBEvents_EngineDefined(This,bstrPropName,varPropValue,bstrClsidEng) (This)->lpVtbl->EngineDefined(This,bstrPropName,varPropValue,bstrClsidEng)
#endif
#endif
  HRESULT WINAPI ILBEvents_TargetUp_Proxy(ILBEvents *This,BSTR bstrServerName,BSTR bstrClsidEng);
  void __RPC_STUB ILBEvents_TargetUp_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ILBEvents_TargetDown_Proxy(ILBEvents *This,BSTR bstrServerName,BSTR bstrClsidEng);
  void __RPC_STUB ILBEvents_TargetDown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ILBEvents_EngineDefined_Proxy(ILBEvents *This,BSTR bstrPropName,VARIANT *varPropValue,BSTR bstrClsidEng);
  void __RPC_STUB ILBEvents_EngineDefined_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComCRMEvents_INTERFACE_DEFINED__
#define __IComCRMEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComCRMEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComCRMEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnCRMRecoveryStart(COMSVCSEVENTINFO *pInfo,GUID guidApp) = 0;
    virtual HRESULT WINAPI OnCRMRecoveryDone(COMSVCSEVENTINFO *pInfo,GUID guidApp) = 0;
    virtual HRESULT WINAPI OnCRMCheckpoint(COMSVCSEVENTINFO *pInfo,GUID guidApp) = 0;
    virtual HRESULT WINAPI OnCRMBegin(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,GUID guidActivity,GUID guidTx,WCHAR szProgIdCompensator[64],WCHAR szDescription[64]) = 0;
    virtual HRESULT WINAPI OnCRMPrepare(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID) = 0;
    virtual HRESULT WINAPI OnCRMCommit(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID) = 0;
    virtual HRESULT WINAPI OnCRMAbort(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID) = 0;
    virtual HRESULT WINAPI OnCRMIndoubt(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID) = 0;
    virtual HRESULT WINAPI OnCRMDone(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID) = 0;
    virtual HRESULT WINAPI OnCRMRelease(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID) = 0;
    virtual HRESULT WINAPI OnCRMAnalyze(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,DWORD dwCrmRecordType,DWORD dwRecordSize) = 0;
    virtual HRESULT WINAPI OnCRMWrite(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,WINBOOL fVariants,DWORD dwRecordSize) = 0;
    virtual HRESULT WINAPI OnCRMForget(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID) = 0;
    virtual HRESULT WINAPI OnCRMForce(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID) = 0;
    virtual HRESULT WINAPI OnCRMDeliver(COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,WINBOOL fVariants,DWORD dwRecordSize) = 0;
  };
#else
  typedef struct IComCRMEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComCRMEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComCRMEvents *This);
      ULONG (WINAPI *Release)(IComCRMEvents *This);
      HRESULT (WINAPI *OnCRMRecoveryStart)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
      HRESULT (WINAPI *OnCRMRecoveryDone)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
      HRESULT (WINAPI *OnCRMCheckpoint)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
      HRESULT (WINAPI *OnCRMBegin)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,GUID guidActivity,GUID guidTx,WCHAR szProgIdCompensator[64],WCHAR szDescription[64]);
      HRESULT (WINAPI *OnCRMPrepare)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
      HRESULT (WINAPI *OnCRMCommit)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
      HRESULT (WINAPI *OnCRMAbort)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
      HRESULT (WINAPI *OnCRMIndoubt)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
      HRESULT (WINAPI *OnCRMDone)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
      HRESULT (WINAPI *OnCRMRelease)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
      HRESULT (WINAPI *OnCRMAnalyze)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,DWORD dwCrmRecordType,DWORD dwRecordSize);
      HRESULT (WINAPI *OnCRMWrite)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,WINBOOL fVariants,DWORD dwRecordSize);
      HRESULT (WINAPI *OnCRMForget)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
      HRESULT (WINAPI *OnCRMForce)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
      HRESULT (WINAPI *OnCRMDeliver)(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,WINBOOL fVariants,DWORD dwRecordSize);
    END_INTERFACE
  } IComCRMEventsVtbl;
  struct IComCRMEvents {
    CONST_VTBL struct IComCRMEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComCRMEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComCRMEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComCRMEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComCRMEvents_OnCRMRecoveryStart(This,pInfo,guidApp) (This)->lpVtbl->OnCRMRecoveryStart(This,pInfo,guidApp)
#define IComCRMEvents_OnCRMRecoveryDone(This,pInfo,guidApp) (This)->lpVtbl->OnCRMRecoveryDone(This,pInfo,guidApp)
#define IComCRMEvents_OnCRMCheckpoint(This,pInfo,guidApp) (This)->lpVtbl->OnCRMCheckpoint(This,pInfo,guidApp)
#define IComCRMEvents_OnCRMBegin(This,pInfo,guidClerkCLSID,guidActivity,guidTx,szProgIdCompensator,szDescription) (This)->lpVtbl->OnCRMBegin(This,pInfo,guidClerkCLSID,guidActivity,guidTx,szProgIdCompensator,szDescription)
#define IComCRMEvents_OnCRMPrepare(This,pInfo,guidClerkCLSID) (This)->lpVtbl->OnCRMPrepare(This,pInfo,guidClerkCLSID)
#define IComCRMEvents_OnCRMCommit(This,pInfo,guidClerkCLSID) (This)->lpVtbl->OnCRMCommit(This,pInfo,guidClerkCLSID)
#define IComCRMEvents_OnCRMAbort(This,pInfo,guidClerkCLSID) (This)->lpVtbl->OnCRMAbort(This,pInfo,guidClerkCLSID)
#define IComCRMEvents_OnCRMIndoubt(This,pInfo,guidClerkCLSID) (This)->lpVtbl->OnCRMIndoubt(This,pInfo,guidClerkCLSID)
#define IComCRMEvents_OnCRMDone(This,pInfo,guidClerkCLSID) (This)->lpVtbl->OnCRMDone(This,pInfo,guidClerkCLSID)
#define IComCRMEvents_OnCRMRelease(This,pInfo,guidClerkCLSID) (This)->lpVtbl->OnCRMRelease(This,pInfo,guidClerkCLSID)
#define IComCRMEvents_OnCRMAnalyze(This,pInfo,guidClerkCLSID,dwCrmRecordType,dwRecordSize) (This)->lpVtbl->OnCRMAnalyze(This,pInfo,guidClerkCLSID,dwCrmRecordType,dwRecordSize)
#define IComCRMEvents_OnCRMWrite(This,pInfo,guidClerkCLSID,fVariants,dwRecordSize) (This)->lpVtbl->OnCRMWrite(This,pInfo,guidClerkCLSID,fVariants,dwRecordSize)
#define IComCRMEvents_OnCRMForget(This,pInfo,guidClerkCLSID) (This)->lpVtbl->OnCRMForget(This,pInfo,guidClerkCLSID)
#define IComCRMEvents_OnCRMForce(This,pInfo,guidClerkCLSID) (This)->lpVtbl->OnCRMForce(This,pInfo,guidClerkCLSID)
#define IComCRMEvents_OnCRMDeliver(This,pInfo,guidClerkCLSID,fVariants,dwRecordSize) (This)->lpVtbl->OnCRMDeliver(This,pInfo,guidClerkCLSID,fVariants,dwRecordSize)
#endif
#endif
  HRESULT WINAPI IComCRMEvents_OnCRMRecoveryStart_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
  void __RPC_STUB IComCRMEvents_OnCRMRecoveryStart_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMRecoveryDone_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
  void __RPC_STUB IComCRMEvents_OnCRMRecoveryDone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMCheckpoint_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
  void __RPC_STUB IComCRMEvents_OnCRMCheckpoint_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMBegin_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,GUID guidActivity,GUID guidTx,WCHAR szProgIdCompensator[64],WCHAR szDescription[64]);
  void __RPC_STUB IComCRMEvents_OnCRMBegin_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMPrepare_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
  void __RPC_STUB IComCRMEvents_OnCRMPrepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMCommit_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
  void __RPC_STUB IComCRMEvents_OnCRMCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMAbort_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
  void __RPC_STUB IComCRMEvents_OnCRMAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMIndoubt_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
  void __RPC_STUB IComCRMEvents_OnCRMIndoubt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMDone_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
  void __RPC_STUB IComCRMEvents_OnCRMDone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMRelease_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
  void __RPC_STUB IComCRMEvents_OnCRMRelease_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMAnalyze_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,DWORD dwCrmRecordType,DWORD dwRecordSize);
  void __RPC_STUB IComCRMEvents_OnCRMAnalyze_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMWrite_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,WINBOOL fVariants,DWORD dwRecordSize);
  void __RPC_STUB IComCRMEvents_OnCRMWrite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMForget_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
  void __RPC_STUB IComCRMEvents_OnCRMForget_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMForce_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID);
  void __RPC_STUB IComCRMEvents_OnCRMForce_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComCRMEvents_OnCRMDeliver_Proxy(IComCRMEvents *This,COMSVCSEVENTINFO *pInfo,GUID guidClerkCLSID,WINBOOL fVariants,DWORD dwRecordSize);
  void __RPC_STUB IComCRMEvents_OnCRMDeliver_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComMethod2Events_INTERFACE_DEFINED__
#define __IComMethod2Events_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComMethod2Events;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComMethod2Events : public IUnknown {
  public:
    virtual HRESULT WINAPI OnMethodCall2(COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth) = 0;
    virtual HRESULT WINAPI OnMethodReturn2(COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth,HRESULT hresult) = 0;
    virtual HRESULT WINAPI OnMethodException2(COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth) = 0;
  };
#else
  typedef struct IComMethod2EventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComMethod2Events *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComMethod2Events *This);
      ULONG (WINAPI *Release)(IComMethod2Events *This);
      HRESULT (WINAPI *OnMethodCall2)(IComMethod2Events *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth);
      HRESULT (WINAPI *OnMethodReturn2)(IComMethod2Events *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth,HRESULT hresult);
      HRESULT (WINAPI *OnMethodException2)(IComMethod2Events *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth);
    END_INTERFACE
  } IComMethod2EventsVtbl;
  struct IComMethod2Events {
    CONST_VTBL struct IComMethod2EventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComMethod2Events_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComMethod2Events_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComMethod2Events_Release(This) (This)->lpVtbl->Release(This)
#define IComMethod2Events_OnMethodCall2(This,pInfo,oid,guidCid,guidRid,dwThread,iMeth) (This)->lpVtbl->OnMethodCall2(This,pInfo,oid,guidCid,guidRid,dwThread,iMeth)
#define IComMethod2Events_OnMethodReturn2(This,pInfo,oid,guidCid,guidRid,dwThread,iMeth,hresult) (This)->lpVtbl->OnMethodReturn2(This,pInfo,oid,guidCid,guidRid,dwThread,iMeth,hresult)
#define IComMethod2Events_OnMethodException2(This,pInfo,oid,guidCid,guidRid,dwThread,iMeth) (This)->lpVtbl->OnMethodException2(This,pInfo,oid,guidCid,guidRid,dwThread,iMeth)
#endif
#endif
  HRESULT WINAPI IComMethod2Events_OnMethodCall2_Proxy(IComMethod2Events *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth);
  void __RPC_STUB IComMethod2Events_OnMethodCall2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComMethod2Events_OnMethodReturn2_Proxy(IComMethod2Events *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth,HRESULT hresult);
  void __RPC_STUB IComMethod2Events_OnMethodReturn2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComMethod2Events_OnMethodException2_Proxy(IComMethod2Events *This,COMSVCSEVENTINFO *pInfo,ULONG64 oid,REFCLSID guidCid,REFIID guidRid,DWORD dwThread,ULONG iMeth);
  void __RPC_STUB IComMethod2Events_OnMethodException2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComTrackingInfoEvents_INTERFACE_DEFINED__
#define __IComTrackingInfoEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComTrackingInfoEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComTrackingInfoEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnNewTrackingInfo(IUnknown *pToplevelCollection) = 0;
  };
#else
  typedef struct IComTrackingInfoEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComTrackingInfoEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComTrackingInfoEvents *This);
      ULONG (WINAPI *Release)(IComTrackingInfoEvents *This);
      HRESULT (WINAPI *OnNewTrackingInfo)(IComTrackingInfoEvents *This,IUnknown *pToplevelCollection);
    END_INTERFACE
  } IComTrackingInfoEventsVtbl;
  struct IComTrackingInfoEvents {
    CONST_VTBL struct IComTrackingInfoEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComTrackingInfoEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComTrackingInfoEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComTrackingInfoEvents_Release(This) (This)->lpVtbl->Release(This)
#define IComTrackingInfoEvents_OnNewTrackingInfo(This,pToplevelCollection) (This)->lpVtbl->OnNewTrackingInfo(This,pToplevelCollection)
#endif
#endif
  HRESULT WINAPI IComTrackingInfoEvents_OnNewTrackingInfo_Proxy(IComTrackingInfoEvents *This,IUnknown *pToplevelCollection);
  void __RPC_STUB IComTrackingInfoEvents_OnNewTrackingInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum __MIDL___MIDL_itf_autosvcs_0325_0001 {
    TRKCOLL_PROCESSES = 0,TRKCOLL_APPLICATIONS,TRKCOLL_COMPONENTS
  } TRACKING_COLL_TYPE;

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0325_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0325_v0_0_s_ifspec;

#ifndef __IComTrackingInfoCollection_INTERFACE_DEFINED__
#define __IComTrackingInfoCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComTrackingInfoCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComTrackingInfoCollection : public IUnknown {
  public:
    virtual HRESULT WINAPI Type(TRACKING_COLL_TYPE *pType) = 0;
    virtual HRESULT WINAPI Count(ULONG *pCount) = 0;
    virtual HRESULT WINAPI Item(ULONG ulIndex,REFIID riid,void **ppv) = 0;
  };
#else
  typedef struct IComTrackingInfoCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComTrackingInfoCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComTrackingInfoCollection *This);
      ULONG (WINAPI *Release)(IComTrackingInfoCollection *This);
      HRESULT (WINAPI *Type)(IComTrackingInfoCollection *This,TRACKING_COLL_TYPE *pType);
      HRESULT (WINAPI *Count)(IComTrackingInfoCollection *This,ULONG *pCount);
      HRESULT (WINAPI *Item)(IComTrackingInfoCollection *This,ULONG ulIndex,REFIID riid,void **ppv);
    END_INTERFACE
  } IComTrackingInfoCollectionVtbl;
  struct IComTrackingInfoCollection {
    CONST_VTBL struct IComTrackingInfoCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComTrackingInfoCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComTrackingInfoCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComTrackingInfoCollection_Release(This) (This)->lpVtbl->Release(This)
#define IComTrackingInfoCollection_Type(This,pType) (This)->lpVtbl->Type(This,pType)
#define IComTrackingInfoCollection_Count(This,pCount) (This)->lpVtbl->Count(This,pCount)
#define IComTrackingInfoCollection_Item(This,ulIndex,riid,ppv) (This)->lpVtbl->Item(This,ulIndex,riid,ppv)
#endif
#endif
  HRESULT WINAPI IComTrackingInfoCollection_Type_Proxy(IComTrackingInfoCollection *This,TRACKING_COLL_TYPE *pType);
  void __RPC_STUB IComTrackingInfoCollection_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTrackingInfoCollection_Count_Proxy(IComTrackingInfoCollection *This,ULONG *pCount);
  void __RPC_STUB IComTrackingInfoCollection_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTrackingInfoCollection_Item_Proxy(IComTrackingInfoCollection *This,ULONG ulIndex,REFIID riid,void **ppv);
  void __RPC_STUB IComTrackingInfoCollection_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComTrackingInfoObject_INTERFACE_DEFINED__
#define __IComTrackingInfoObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComTrackingInfoObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComTrackingInfoObject : public IUnknown {
  public:
    virtual HRESULT WINAPI GetValue(LPOLESTR szPropertyName,VARIANT *pvarOut) = 0;
  };
#else
  typedef struct IComTrackingInfoObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComTrackingInfoObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComTrackingInfoObject *This);
      ULONG (WINAPI *Release)(IComTrackingInfoObject *This);
      HRESULT (WINAPI *GetValue)(IComTrackingInfoObject *This,LPOLESTR szPropertyName,VARIANT *pvarOut);
    END_INTERFACE
  } IComTrackingInfoObjectVtbl;
  struct IComTrackingInfoObject {
    CONST_VTBL struct IComTrackingInfoObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComTrackingInfoObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComTrackingInfoObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComTrackingInfoObject_Release(This) (This)->lpVtbl->Release(This)
#define IComTrackingInfoObject_GetValue(This,szPropertyName,pvarOut) (This)->lpVtbl->GetValue(This,szPropertyName,pvarOut)
#endif
#endif
  HRESULT WINAPI IComTrackingInfoObject_GetValue_Proxy(IComTrackingInfoObject *This,LPOLESTR szPropertyName,VARIANT *pvarOut);
  void __RPC_STUB IComTrackingInfoObject_GetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComTrackingInfoProperties_INTERFACE_DEFINED__
#define __IComTrackingInfoProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComTrackingInfoProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComTrackingInfoProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI PropCount(ULONG *pCount) = 0;
    virtual HRESULT WINAPI GetPropName(ULONG ulIndex,LPOLESTR *ppszPropName) = 0;
  };
#else
  typedef struct IComTrackingInfoPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComTrackingInfoProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComTrackingInfoProperties *This);
      ULONG (WINAPI *Release)(IComTrackingInfoProperties *This);
      HRESULT (WINAPI *PropCount)(IComTrackingInfoProperties *This,ULONG *pCount);
      HRESULT (WINAPI *GetPropName)(IComTrackingInfoProperties *This,ULONG ulIndex,LPOLESTR *ppszPropName);
    END_INTERFACE
  } IComTrackingInfoPropertiesVtbl;
  struct IComTrackingInfoProperties {
    CONST_VTBL struct IComTrackingInfoPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComTrackingInfoProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComTrackingInfoProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComTrackingInfoProperties_Release(This) (This)->lpVtbl->Release(This)
#define IComTrackingInfoProperties_PropCount(This,pCount) (This)->lpVtbl->PropCount(This,pCount)
#define IComTrackingInfoProperties_GetPropName(This,ulIndex,ppszPropName) (This)->lpVtbl->GetPropName(This,ulIndex,ppszPropName)
#endif
#endif
  HRESULT WINAPI IComTrackingInfoProperties_PropCount_Proxy(IComTrackingInfoProperties *This,ULONG *pCount);
  void __RPC_STUB IComTrackingInfoProperties_PropCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTrackingInfoProperties_GetPropName_Proxy(IComTrackingInfoProperties *This,ULONG ulIndex,LPOLESTR *ppszPropName);
  void __RPC_STUB IComTrackingInfoProperties_GetPropName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComApp2Events_INTERFACE_DEFINED__
#define __IComApp2Events_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComApp2Events;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComApp2Events : public IUnknown {
  public:
    virtual HRESULT WINAPI OnAppActivation2(COMSVCSEVENTINFO *pInfo,GUID guidApp,GUID guidProcess) = 0;
    virtual HRESULT WINAPI OnAppShutdown2(COMSVCSEVENTINFO *pInfo,GUID guidApp) = 0;
    virtual HRESULT WINAPI OnAppForceShutdown2(COMSVCSEVENTINFO *pInfo,GUID guidApp) = 0;
    virtual HRESULT WINAPI OnAppPaused2(COMSVCSEVENTINFO *pInfo,GUID guidApp,WINBOOL bPaused) = 0;
    virtual HRESULT WINAPI OnAppRecycle2(COMSVCSEVENTINFO *pInfo,GUID guidApp,GUID guidProcess,__LONG32 lReason) = 0;
  };
#else
  typedef struct IComApp2EventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComApp2Events *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComApp2Events *This);
      ULONG (WINAPI *Release)(IComApp2Events *This);
      HRESULT (WINAPI *OnAppActivation2)(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp,GUID guidProcess);
      HRESULT (WINAPI *OnAppShutdown2)(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
      HRESULT (WINAPI *OnAppForceShutdown2)(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
      HRESULT (WINAPI *OnAppPaused2)(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp,WINBOOL bPaused);
      HRESULT (WINAPI *OnAppRecycle2)(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp,GUID guidProcess,__LONG32 lReason);
    END_INTERFACE
  } IComApp2EventsVtbl;
  struct IComApp2Events {
    CONST_VTBL struct IComApp2EventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComApp2Events_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComApp2Events_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComApp2Events_Release(This) (This)->lpVtbl->Release(This)
#define IComApp2Events_OnAppActivation2(This,pInfo,guidApp,guidProcess) (This)->lpVtbl->OnAppActivation2(This,pInfo,guidApp,guidProcess)
#define IComApp2Events_OnAppShutdown2(This,pInfo,guidApp) (This)->lpVtbl->OnAppShutdown2(This,pInfo,guidApp)
#define IComApp2Events_OnAppForceShutdown2(This,pInfo,guidApp) (This)->lpVtbl->OnAppForceShutdown2(This,pInfo,guidApp)
#define IComApp2Events_OnAppPaused2(This,pInfo,guidApp,bPaused) (This)->lpVtbl->OnAppPaused2(This,pInfo,guidApp,bPaused)
#define IComApp2Events_OnAppRecycle2(This,pInfo,guidApp,guidProcess,lReason) (This)->lpVtbl->OnAppRecycle2(This,pInfo,guidApp,guidProcess,lReason)
#endif
#endif
  HRESULT WINAPI IComApp2Events_OnAppActivation2_Proxy(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp,GUID guidProcess);
  void __RPC_STUB IComApp2Events_OnAppActivation2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComApp2Events_OnAppShutdown2_Proxy(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
  void __RPC_STUB IComApp2Events_OnAppShutdown2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComApp2Events_OnAppForceShutdown2_Proxy(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp);
  void __RPC_STUB IComApp2Events_OnAppForceShutdown2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComApp2Events_OnAppPaused2_Proxy(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp,WINBOOL bPaused);
  void __RPC_STUB IComApp2Events_OnAppPaused2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComApp2Events_OnAppRecycle2_Proxy(IComApp2Events *This,COMSVCSEVENTINFO *pInfo,GUID guidApp,GUID guidProcess,__LONG32 lReason);
  void __RPC_STUB IComApp2Events_OnAppRecycle2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComTransaction2Events_INTERFACE_DEFINED__
#define __IComTransaction2Events_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComTransaction2Events;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComTransaction2Events : public IUnknown {
  public:
    virtual HRESULT WINAPI OnTransactionStart2(COMSVCSEVENTINFO *pInfo,REFGUID guidTx,REFGUID tsid,WINBOOL fRoot,int nIsolationLevel) = 0;
    virtual HRESULT WINAPI OnTransactionPrepare2(COMSVCSEVENTINFO *pInfo,REFGUID guidTx,WINBOOL fVoteYes) = 0;
    virtual HRESULT WINAPI OnTransactionAbort2(COMSVCSEVENTINFO *pInfo,REFGUID guidTx) = 0;
    virtual HRESULT WINAPI OnTransactionCommit2(COMSVCSEVENTINFO *pInfo,REFGUID guidTx) = 0;
  };
#else
  typedef struct IComTransaction2EventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComTransaction2Events *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComTransaction2Events *This);
      ULONG (WINAPI *Release)(IComTransaction2Events *This);
      HRESULT (WINAPI *OnTransactionStart2)(IComTransaction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx,REFGUID tsid,WINBOOL fRoot,int nIsolationLevel);
      HRESULT (WINAPI *OnTransactionPrepare2)(IComTransaction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx,WINBOOL fVoteYes);
      HRESULT (WINAPI *OnTransactionAbort2)(IComTransaction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx);
      HRESULT (WINAPI *OnTransactionCommit2)(IComTransaction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx);
    END_INTERFACE
  } IComTransaction2EventsVtbl;
  struct IComTransaction2Events {
    CONST_VTBL struct IComTransaction2EventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComTransaction2Events_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComTransaction2Events_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComTransaction2Events_Release(This) (This)->lpVtbl->Release(This)
#define IComTransaction2Events_OnTransactionStart2(This,pInfo,guidTx,tsid,fRoot,nIsolationLevel) (This)->lpVtbl->OnTransactionStart2(This,pInfo,guidTx,tsid,fRoot,nIsolationLevel)
#define IComTransaction2Events_OnTransactionPrepare2(This,pInfo,guidTx,fVoteYes) (This)->lpVtbl->OnTransactionPrepare2(This,pInfo,guidTx,fVoteYes)
#define IComTransaction2Events_OnTransactionAbort2(This,pInfo,guidTx) (This)->lpVtbl->OnTransactionAbort2(This,pInfo,guidTx)
#define IComTransaction2Events_OnTransactionCommit2(This,pInfo,guidTx) (This)->lpVtbl->OnTransactionCommit2(This,pInfo,guidTx)
#endif
#endif
  HRESULT WINAPI IComTransaction2Events_OnTransactionStart2_Proxy(IComTransaction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx,REFGUID tsid,WINBOOL fRoot,int nIsolationLevel);
  void __RPC_STUB IComTransaction2Events_OnTransactionStart2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTransaction2Events_OnTransactionPrepare2_Proxy(IComTransaction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx,WINBOOL fVoteYes);
  void __RPC_STUB IComTransaction2Events_OnTransactionPrepare2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTransaction2Events_OnTransactionAbort2_Proxy(IComTransaction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx);
  void __RPC_STUB IComTransaction2Events_OnTransactionAbort2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComTransaction2Events_OnTransactionCommit2_Proxy(IComTransaction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidTx);
  void __RPC_STUB IComTransaction2Events_OnTransactionCommit2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComInstance2Events_INTERFACE_DEFINED__
#define __IComInstance2Events_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComInstance2Events;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComInstance2Events : public IUnknown {
  public:
    virtual HRESULT WINAPI OnObjectCreate2(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFCLSID clsid,REFGUID tsid,ULONG64 CtxtID,ULONG64 ObjectID,REFGUID guidPartition) = 0;
    virtual HRESULT WINAPI OnObjectDestroy2(COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID) = 0;
  };
#else
  typedef struct IComInstance2EventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComInstance2Events *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComInstance2Events *This);
      ULONG (WINAPI *Release)(IComInstance2Events *This);
      HRESULT (WINAPI *OnObjectCreate2)(IComInstance2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFCLSID clsid,REFGUID tsid,ULONG64 CtxtID,ULONG64 ObjectID,REFGUID guidPartition);
      HRESULT (WINAPI *OnObjectDestroy2)(IComInstance2Events *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
    END_INTERFACE
  } IComInstance2EventsVtbl;
  struct IComInstance2Events {
    CONST_VTBL struct IComInstance2EventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComInstance2Events_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComInstance2Events_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComInstance2Events_Release(This) (This)->lpVtbl->Release(This)
#define IComInstance2Events_OnObjectCreate2(This,pInfo,guidActivity,clsid,tsid,CtxtID,ObjectID,guidPartition) (This)->lpVtbl->OnObjectCreate2(This,pInfo,guidActivity,clsid,tsid,CtxtID,ObjectID,guidPartition)
#define IComInstance2Events_OnObjectDestroy2(This,pInfo,CtxtID) (This)->lpVtbl->OnObjectDestroy2(This,pInfo,CtxtID)
#endif
#endif
  HRESULT WINAPI IComInstance2Events_OnObjectCreate2_Proxy(IComInstance2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFCLSID clsid,REFGUID tsid,ULONG64 CtxtID,ULONG64 ObjectID,REFGUID guidPartition);
  void __RPC_STUB IComInstance2Events_OnObjectCreate2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComInstance2Events_OnObjectDestroy2_Proxy(IComInstance2Events *This,COMSVCSEVENTINFO *pInfo,ULONG64 CtxtID);
  void __RPC_STUB IComInstance2Events_OnObjectDestroy2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComObjectPool2Events_INTERFACE_DEFINED__
#define __IComObjectPool2Events_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComObjectPool2Events;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComObjectPool2Events : public IUnknown {
  public:
    virtual HRESULT WINAPI OnObjPoolPutObject2(COMSVCSEVENTINFO *pInfo,REFGUID guidObject,int nReason,DWORD dwAvailable,ULONG64 oid) = 0;
    virtual HRESULT WINAPI OnObjPoolGetObject2(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,DWORD dwAvailable,ULONG64 oid,REFGUID guidPartition) = 0;
    virtual HRESULT WINAPI OnObjPoolRecycleToTx2(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid) = 0;
    virtual HRESULT WINAPI OnObjPoolGetFromTx2(COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid,REFGUID guidPartition) = 0;
  };
#else
  typedef struct IComObjectPool2EventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComObjectPool2Events *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComObjectPool2Events *This);
      ULONG (WINAPI *Release)(IComObjectPool2Events *This);
      HRESULT (WINAPI *OnObjPoolPutObject2)(IComObjectPool2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,int nReason,DWORD dwAvailable,ULONG64 oid);
      HRESULT (WINAPI *OnObjPoolGetObject2)(IComObjectPool2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,DWORD dwAvailable,ULONG64 oid,REFGUID guidPartition);
      HRESULT (WINAPI *OnObjPoolRecycleToTx2)(IComObjectPool2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid);
      HRESULT (WINAPI *OnObjPoolGetFromTx2)(IComObjectPool2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid,REFGUID guidPartition);
    END_INTERFACE
  } IComObjectPool2EventsVtbl;
  struct IComObjectPool2Events {
    CONST_VTBL struct IComObjectPool2EventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComObjectPool2Events_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComObjectPool2Events_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComObjectPool2Events_Release(This) (This)->lpVtbl->Release(This)
#define IComObjectPool2Events_OnObjPoolPutObject2(This,pInfo,guidObject,nReason,dwAvailable,oid) (This)->lpVtbl->OnObjPoolPutObject2(This,pInfo,guidObject,nReason,dwAvailable,oid)
#define IComObjectPool2Events_OnObjPoolGetObject2(This,pInfo,guidActivity,guidObject,dwAvailable,oid,guidPartition) (This)->lpVtbl->OnObjPoolGetObject2(This,pInfo,guidActivity,guidObject,dwAvailable,oid,guidPartition)
#define IComObjectPool2Events_OnObjPoolRecycleToTx2(This,pInfo,guidActivity,guidObject,guidTx,objid) (This)->lpVtbl->OnObjPoolRecycleToTx2(This,pInfo,guidActivity,guidObject,guidTx,objid)
#define IComObjectPool2Events_OnObjPoolGetFromTx2(This,pInfo,guidActivity,guidObject,guidTx,objid,guidPartition) (This)->lpVtbl->OnObjPoolGetFromTx2(This,pInfo,guidActivity,guidObject,guidTx,objid,guidPartition)
#endif
#endif
  HRESULT WINAPI IComObjectPool2Events_OnObjPoolPutObject2_Proxy(IComObjectPool2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,int nReason,DWORD dwAvailable,ULONG64 oid);
  void __RPC_STUB IComObjectPool2Events_OnObjPoolPutObject2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPool2Events_OnObjPoolGetObject2_Proxy(IComObjectPool2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,DWORD dwAvailable,ULONG64 oid,REFGUID guidPartition);
  void __RPC_STUB IComObjectPool2Events_OnObjPoolGetObject2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPool2Events_OnObjPoolRecycleToTx2_Proxy(IComObjectPool2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid);
  void __RPC_STUB IComObjectPool2Events_OnObjPoolRecycleToTx2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComObjectPool2Events_OnObjPoolGetFromTx2_Proxy(IComObjectPool2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidActivity,REFGUID guidObject,REFGUID guidTx,ULONG64 objid,REFGUID guidPartition);
  void __RPC_STUB IComObjectPool2Events_OnObjPoolGetFromTx2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComObjectConstruction2Events_INTERFACE_DEFINED__
#define __IComObjectConstruction2Events_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComObjectConstruction2Events;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComObjectConstruction2Events : public IUnknown {
  public:
    virtual HRESULT WINAPI OnObjectConstruct2(COMSVCSEVENTINFO *pInfo,REFGUID guidObject,LPCOLESTR sConstructString,ULONG64 oid,REFGUID guidPartition) = 0;
  };
#else
  typedef struct IComObjectConstruction2EventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComObjectConstruction2Events *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComObjectConstruction2Events *This);
      ULONG (WINAPI *Release)(IComObjectConstruction2Events *This);
      HRESULT (WINAPI *OnObjectConstruct2)(IComObjectConstruction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,LPCOLESTR sConstructString,ULONG64 oid,REFGUID guidPartition);
    END_INTERFACE
  } IComObjectConstruction2EventsVtbl;
  struct IComObjectConstruction2Events {
    CONST_VTBL struct IComObjectConstruction2EventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComObjectConstruction2Events_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComObjectConstruction2Events_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComObjectConstruction2Events_Release(This) (This)->lpVtbl->Release(This)
#define IComObjectConstruction2Events_OnObjectConstruct2(This,pInfo,guidObject,sConstructString,oid,guidPartition) (This)->lpVtbl->OnObjectConstruct2(This,pInfo,guidObject,sConstructString,oid,guidPartition)
#endif
#endif
  HRESULT WINAPI IComObjectConstruction2Events_OnObjectConstruct2_Proxy(IComObjectConstruction2Events *This,COMSVCSEVENTINFO *pInfo,REFGUID guidObject,LPCOLESTR sConstructString,ULONG64 oid,REFGUID guidPartition);
  void __RPC_STUB IComObjectConstruction2Events_OnObjectConstruct2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISystemAppEventData_INTERFACE_DEFINED__
#define __ISystemAppEventData_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISystemAppEventData;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISystemAppEventData : public IUnknown {
  public:
    virtual HRESULT WINAPI Startup(void) = 0;
    virtual HRESULT WINAPI OnDataChanged(DWORD dwPID,DWORD dwMask,DWORD dwNumberSinks,BSTR bstrDwMethodMask,DWORD dwReason,ULONG64 u64TraceHandle) = 0;
  };
#else
  typedef struct ISystemAppEventDataVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISystemAppEventData *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISystemAppEventData *This);
      ULONG (WINAPI *Release)(ISystemAppEventData *This);
      HRESULT (WINAPI *Startup)(ISystemAppEventData *This);
      HRESULT (WINAPI *OnDataChanged)(ISystemAppEventData *This,DWORD dwPID,DWORD dwMask,DWORD dwNumberSinks,BSTR bstrDwMethodMask,DWORD dwReason,ULONG64 u64TraceHandle);
    END_INTERFACE
  } ISystemAppEventDataVtbl;
  struct ISystemAppEventData {
    CONST_VTBL struct ISystemAppEventDataVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISystemAppEventData_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISystemAppEventData_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISystemAppEventData_Release(This) (This)->lpVtbl->Release(This)
#define ISystemAppEventData_Startup(This) (This)->lpVtbl->Startup(This)
#define ISystemAppEventData_OnDataChanged(This,dwPID,dwMask,dwNumberSinks,bstrDwMethodMask,dwReason,u64TraceHandle) (This)->lpVtbl->OnDataChanged(This,dwPID,dwMask,dwNumberSinks,bstrDwMethodMask,dwReason,u64TraceHandle)
#endif
#endif
  HRESULT WINAPI ISystemAppEventData_Startup_Proxy(ISystemAppEventData *This);
  void __RPC_STUB ISystemAppEventData_Startup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISystemAppEventData_OnDataChanged_Proxy(ISystemAppEventData *This,DWORD dwPID,DWORD dwMask,DWORD dwNumberSinks,BSTR bstrDwMethodMask,DWORD dwReason,ULONG64 u64TraceHandle);
  void __RPC_STUB ISystemAppEventData_OnDataChanged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMtsEvents_INTERFACE_DEFINED__
#define __IMtsEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMtsEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMtsEvents : public IDispatch {
  public:
    virtual HRESULT WINAPI get_PackageName(BSTR *pVal) = 0;
    virtual HRESULT WINAPI get_PackageGuid(BSTR *pVal) = 0;
    virtual HRESULT WINAPI PostEvent(VARIANT *vEvent) = 0;
    virtual HRESULT WINAPI get_FireEvents(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI GetProcessID(__LONG32 *id) = 0;
  };
#else
  typedef struct IMtsEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMtsEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMtsEvents *This);
      ULONG (WINAPI *Release)(IMtsEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMtsEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMtsEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMtsEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMtsEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_PackageName)(IMtsEvents *This,BSTR *pVal);
      HRESULT (WINAPI *get_PackageGuid)(IMtsEvents *This,BSTR *pVal);
      HRESULT (WINAPI *PostEvent)(IMtsEvents *This,VARIANT *vEvent);
      HRESULT (WINAPI *get_FireEvents)(IMtsEvents *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *GetProcessID)(IMtsEvents *This,__LONG32 *id);
    END_INTERFACE
  } IMtsEventsVtbl;
  struct IMtsEvents {
    CONST_VTBL struct IMtsEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMtsEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMtsEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMtsEvents_Release(This) (This)->lpVtbl->Release(This)
#define IMtsEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMtsEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMtsEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMtsEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMtsEvents_get_PackageName(This,pVal) (This)->lpVtbl->get_PackageName(This,pVal)
#define IMtsEvents_get_PackageGuid(This,pVal) (This)->lpVtbl->get_PackageGuid(This,pVal)
#define IMtsEvents_PostEvent(This,vEvent) (This)->lpVtbl->PostEvent(This,vEvent)
#define IMtsEvents_get_FireEvents(This,pVal) (This)->lpVtbl->get_FireEvents(This,pVal)
#define IMtsEvents_GetProcessID(This,id) (This)->lpVtbl->GetProcessID(This,id)
#endif
#endif
  HRESULT WINAPI IMtsEvents_get_PackageName_Proxy(IMtsEvents *This,BSTR *pVal);
  void __RPC_STUB IMtsEvents_get_PackageName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsEvents_get_PackageGuid_Proxy(IMtsEvents *This,BSTR *pVal);
  void __RPC_STUB IMtsEvents_get_PackageGuid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsEvents_PostEvent_Proxy(IMtsEvents *This,VARIANT *vEvent);
  void __RPC_STUB IMtsEvents_PostEvent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsEvents_get_FireEvents_Proxy(IMtsEvents *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IMtsEvents_get_FireEvents_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsEvents_GetProcessID_Proxy(IMtsEvents *This,__LONG32 *id);
  void __RPC_STUB IMtsEvents_GetProcessID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMtsEventInfo_INTERFACE_DEFINED__
#define __IMtsEventInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMtsEventInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMtsEventInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Names(IUnknown **pUnk) = 0;
    virtual HRESULT WINAPI get_DisplayName(BSTR *sDisplayName) = 0;
    virtual HRESULT WINAPI get_EventID(BSTR *sGuidEventID) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *lCount) = 0;
    virtual HRESULT WINAPI get_Value(BSTR sKey,VARIANT *pVal) = 0;
  };
#else
  typedef struct IMtsEventInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMtsEventInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMtsEventInfo *This);
      ULONG (WINAPI *Release)(IMtsEventInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMtsEventInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMtsEventInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMtsEventInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMtsEventInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Names)(IMtsEventInfo *This,IUnknown **pUnk);
      HRESULT (WINAPI *get_DisplayName)(IMtsEventInfo *This,BSTR *sDisplayName);
      HRESULT (WINAPI *get_EventID)(IMtsEventInfo *This,BSTR *sGuidEventID);
      HRESULT (WINAPI *get_Count)(IMtsEventInfo *This,__LONG32 *lCount);
      HRESULT (WINAPI *get_Value)(IMtsEventInfo *This,BSTR sKey,VARIANT *pVal);
    END_INTERFACE
  } IMtsEventInfoVtbl;
  struct IMtsEventInfo {
    CONST_VTBL struct IMtsEventInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMtsEventInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMtsEventInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMtsEventInfo_Release(This) (This)->lpVtbl->Release(This)
#define IMtsEventInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMtsEventInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMtsEventInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMtsEventInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMtsEventInfo_get_Names(This,pUnk) (This)->lpVtbl->get_Names(This,pUnk)
#define IMtsEventInfo_get_DisplayName(This,sDisplayName) (This)->lpVtbl->get_DisplayName(This,sDisplayName)
#define IMtsEventInfo_get_EventID(This,sGuidEventID) (This)->lpVtbl->get_EventID(This,sGuidEventID)
#define IMtsEventInfo_get_Count(This,lCount) (This)->lpVtbl->get_Count(This,lCount)
#define IMtsEventInfo_get_Value(This,sKey,pVal) (This)->lpVtbl->get_Value(This,sKey,pVal)
#endif
#endif
  HRESULT WINAPI IMtsEventInfo_get_Names_Proxy(IMtsEventInfo *This,IUnknown **pUnk);
  void __RPC_STUB IMtsEventInfo_get_Names_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsEventInfo_get_DisplayName_Proxy(IMtsEventInfo *This,BSTR *sDisplayName);
  void __RPC_STUB IMtsEventInfo_get_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsEventInfo_get_EventID_Proxy(IMtsEventInfo *This,BSTR *sGuidEventID);
  void __RPC_STUB IMtsEventInfo_get_EventID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsEventInfo_get_Count_Proxy(IMtsEventInfo *This,__LONG32 *lCount);
  void __RPC_STUB IMtsEventInfo_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsEventInfo_get_Value_Proxy(IMtsEventInfo *This,BSTR sKey,VARIANT *pVal);
  void __RPC_STUB IMtsEventInfo_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMTSLocator_INTERFACE_DEFINED__
#define __IMTSLocator_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMTSLocator;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMTSLocator : public IDispatch {
  public:
    virtual HRESULT WINAPI GetEventDispatcher(IUnknown **pUnk) = 0;
  };
#else
  typedef struct IMTSLocatorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMTSLocator *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMTSLocator *This);
      ULONG (WINAPI *Release)(IMTSLocator *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMTSLocator *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMTSLocator *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMTSLocator *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMTSLocator *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetEventDispatcher)(IMTSLocator *This,IUnknown **pUnk);
    END_INTERFACE
  } IMTSLocatorVtbl;
  struct IMTSLocator {
    CONST_VTBL struct IMTSLocatorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMTSLocator_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMTSLocator_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMTSLocator_Release(This) (This)->lpVtbl->Release(This)
#define IMTSLocator_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMTSLocator_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMTSLocator_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMTSLocator_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMTSLocator_GetEventDispatcher(This,pUnk) (This)->lpVtbl->GetEventDispatcher(This,pUnk)
#endif
#endif
  HRESULT WINAPI IMTSLocator_GetEventDispatcher_Proxy(IMTSLocator *This,IUnknown **pUnk);
  void __RPC_STUB IMTSLocator_GetEventDispatcher_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMtsGrp_INTERFACE_DEFINED__
#define __IMtsGrp_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMtsGrp;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMtsGrp : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI Item(__LONG32 lIndex,IUnknown **ppUnkDispatcher) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
  };
#else
  typedef struct IMtsGrpVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMtsGrp *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMtsGrp *This);
      ULONG (WINAPI *Release)(IMtsGrp *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMtsGrp *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMtsGrp *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMtsGrp *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMtsGrp *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(IMtsGrp *This,__LONG32 *pVal);
      HRESULT (WINAPI *Item)(IMtsGrp *This,__LONG32 lIndex,IUnknown **ppUnkDispatcher);
      HRESULT (WINAPI *Refresh)(IMtsGrp *This);
    END_INTERFACE
  } IMtsGrpVtbl;
  struct IMtsGrp {
    CONST_VTBL struct IMtsGrpVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMtsGrp_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMtsGrp_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMtsGrp_Release(This) (This)->lpVtbl->Release(This)
#define IMtsGrp_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMtsGrp_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMtsGrp_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMtsGrp_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMtsGrp_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#define IMtsGrp_Item(This,lIndex,ppUnkDispatcher) (This)->lpVtbl->Item(This,lIndex,ppUnkDispatcher)
#define IMtsGrp_Refresh(This) (This)->lpVtbl->Refresh(This)
#endif
#endif
  HRESULT WINAPI IMtsGrp_get_Count_Proxy(IMtsGrp *This,__LONG32 *pVal);
  void __RPC_STUB IMtsGrp_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsGrp_Item_Proxy(IMtsGrp *This,__LONG32 lIndex,IUnknown **ppUnkDispatcher);
  void __RPC_STUB IMtsGrp_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMtsGrp_Refresh_Proxy(IMtsGrp *This);
  void __RPC_STUB IMtsGrp_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMessageMover_INTERFACE_DEFINED__
#define __IMessageMover_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMessageMover;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMessageMover : public IDispatch {
  public:
    virtual HRESULT WINAPI get_SourcePath(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_SourcePath(BSTR newVal) = 0;
    virtual HRESULT WINAPI get_DestPath(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_DestPath(BSTR newVal) = 0;
    virtual HRESULT WINAPI get_CommitBatchSize(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_CommitBatchSize(__LONG32 newVal) = 0;
    virtual HRESULT WINAPI MoveMessages(__LONG32 *plMessagesMoved) = 0;
  };
#else
  typedef struct IMessageMoverVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMessageMover *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMessageMover *This);
      ULONG (WINAPI *Release)(IMessageMover *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IMessageMover *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IMessageMover *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IMessageMover *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IMessageMover *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_SourcePath)(IMessageMover *This,BSTR *pVal);
      HRESULT (WINAPI *put_SourcePath)(IMessageMover *This,BSTR newVal);
      HRESULT (WINAPI *get_DestPath)(IMessageMover *This,BSTR *pVal);
      HRESULT (WINAPI *put_DestPath)(IMessageMover *This,BSTR newVal);
      HRESULT (WINAPI *get_CommitBatchSize)(IMessageMover *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_CommitBatchSize)(IMessageMover *This,__LONG32 newVal);
      HRESULT (WINAPI *MoveMessages)(IMessageMover *This,__LONG32 *plMessagesMoved);
    END_INTERFACE
  } IMessageMoverVtbl;
  struct IMessageMover {
    CONST_VTBL struct IMessageMoverVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMessageMover_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMessageMover_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMessageMover_Release(This) (This)->lpVtbl->Release(This)
#define IMessageMover_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IMessageMover_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IMessageMover_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IMessageMover_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IMessageMover_get_SourcePath(This,pVal) (This)->lpVtbl->get_SourcePath(This,pVal)
#define IMessageMover_put_SourcePath(This,newVal) (This)->lpVtbl->put_SourcePath(This,newVal)
#define IMessageMover_get_DestPath(This,pVal) (This)->lpVtbl->get_DestPath(This,pVal)
#define IMessageMover_put_DestPath(This,newVal) (This)->lpVtbl->put_DestPath(This,newVal)
#define IMessageMover_get_CommitBatchSize(This,pVal) (This)->lpVtbl->get_CommitBatchSize(This,pVal)
#define IMessageMover_put_CommitBatchSize(This,newVal) (This)->lpVtbl->put_CommitBatchSize(This,newVal)
#define IMessageMover_MoveMessages(This,plMessagesMoved) (This)->lpVtbl->MoveMessages(This,plMessagesMoved)
#endif
#endif
  HRESULT WINAPI IMessageMover_get_SourcePath_Proxy(IMessageMover *This,BSTR *pVal);
  void __RPC_STUB IMessageMover_get_SourcePath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessageMover_put_SourcePath_Proxy(IMessageMover *This,BSTR newVal);
  void __RPC_STUB IMessageMover_put_SourcePath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessageMover_get_DestPath_Proxy(IMessageMover *This,BSTR *pVal);
  void __RPC_STUB IMessageMover_get_DestPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessageMover_put_DestPath_Proxy(IMessageMover *This,BSTR newVal);
  void __RPC_STUB IMessageMover_put_DestPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessageMover_get_CommitBatchSize_Proxy(IMessageMover *This,__LONG32 *pVal);
  void __RPC_STUB IMessageMover_get_CommitBatchSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessageMover_put_CommitBatchSize_Proxy(IMessageMover *This,__LONG32 newVal);
  void __RPC_STUB IMessageMover_put_CommitBatchSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMessageMover_MoveMessages_Proxy(IMessageMover *This,__LONG32 *plMessagesMoved);
  void __RPC_STUB IMessageMover_MoveMessages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEventServerTrace_INTERFACE_DEFINED__
#define __IEventServerTrace_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEventServerTrace;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEventServerTrace : public IDispatch {
  public:
    virtual HRESULT WINAPI StartTraceGuid(BSTR bstrguidEvent,BSTR bstrguidFilter,LONG lPidFilter) = 0;
    virtual HRESULT WINAPI StopTraceGuid(BSTR bstrguidEvent,BSTR bstrguidFilter,LONG lPidFilter) = 0;
    virtual HRESULT WINAPI EnumTraceGuid(LONG *plCntGuids,BSTR *pbstrGuidList) = 0;
  };
#else
  typedef struct IEventServerTraceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEventServerTrace *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEventServerTrace *This);
      ULONG (WINAPI *Release)(IEventServerTrace *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEventServerTrace *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEventServerTrace *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEventServerTrace *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEventServerTrace *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *StartTraceGuid)(IEventServerTrace *This,BSTR bstrguidEvent,BSTR bstrguidFilter,LONG lPidFilter);
      HRESULT (WINAPI *StopTraceGuid)(IEventServerTrace *This,BSTR bstrguidEvent,BSTR bstrguidFilter,LONG lPidFilter);
      HRESULT (WINAPI *EnumTraceGuid)(IEventServerTrace *This,LONG *plCntGuids,BSTR *pbstrGuidList);
    END_INTERFACE
  } IEventServerTraceVtbl;
  struct IEventServerTrace {
    CONST_VTBL struct IEventServerTraceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEventServerTrace_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEventServerTrace_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEventServerTrace_Release(This) (This)->lpVtbl->Release(This)
#define IEventServerTrace_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEventServerTrace_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEventServerTrace_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEventServerTrace_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEventServerTrace_StartTraceGuid(This,bstrguidEvent,bstrguidFilter,lPidFilter) (This)->lpVtbl->StartTraceGuid(This,bstrguidEvent,bstrguidFilter,lPidFilter)
#define IEventServerTrace_StopTraceGuid(This,bstrguidEvent,bstrguidFilter,lPidFilter) (This)->lpVtbl->StopTraceGuid(This,bstrguidEvent,bstrguidFilter,lPidFilter)
#define IEventServerTrace_EnumTraceGuid(This,plCntGuids,pbstrGuidList) (This)->lpVtbl->EnumTraceGuid(This,plCntGuids,pbstrGuidList)
#endif
#endif
  HRESULT WINAPI IEventServerTrace_StartTraceGuid_Proxy(IEventServerTrace *This,BSTR bstrguidEvent,BSTR bstrguidFilter,LONG lPidFilter);
  void __RPC_STUB IEventServerTrace_StartTraceGuid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventServerTrace_StopTraceGuid_Proxy(IEventServerTrace *This,BSTR bstrguidEvent,BSTR bstrguidFilter,LONG lPidFilter);
  void __RPC_STUB IEventServerTrace_StopTraceGuid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEventServerTrace_EnumTraceGuid_Proxy(IEventServerTrace *This,LONG *plCntGuids,BSTR *pbstrGuidList);
  void __RPC_STUB IEventServerTrace_EnumTraceGuid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef struct _RECYCLE_INFO {
    GUID guidCombaseProcessIdentifier;
    LONGLONG ProcessStartTime;
    DWORD dwRecycleLifetimeLimit;
    DWORD dwRecycleMemoryLimit;
    DWORD dwRecycleExpirationTimeout;
  } RECYCLE_INFO;

  typedef enum tagCOMPLUS_APPTYPE {
    APPTYPE_UNKNOWN = 0xffffffff,APPTYPE_SERVER = 1,APPTYPE_LIBRARY = 0,APPTYPE_SWC = 2
  } COMPLUS_APPTYPE;

#define TRACKER_STARTSTOP_EVENT L"Global\\COM+ Tracker Push Event"
#define TRACKER_INIT_EVENT L"Global\\COM+ Tracker Init Event"

#ifndef GUID_STRING_SIZE
#define GUID_STRING_SIZE 40
#endif
  typedef struct CAppStatistics {
    DWORD m_cTotalCalls;
    DWORD m_cTotalInstances;
    DWORD m_cTotalClasses;
    DWORD m_cCallsPerSecond;
  } APPSTATISTICS;

  typedef struct CAppData {
    DWORD m_idApp;
    WCHAR m_szAppGuid[40];
    DWORD m_dwAppProcessId;
    APPSTATISTICS m_AppStatistics;
  } APPDATA;

  typedef struct CCLSIDData {
    CLSID m_clsid;
    DWORD m_cReferences;
    DWORD m_cBound;
    DWORD m_cPooled;
    DWORD m_cInCall;
    DWORD m_dwRespTime;
    DWORD m_cCallsCompleted;
    DWORD m_cCallsFailed;
  } CLSIDDATA;

  typedef struct CCLSIDData2 {
    CLSID m_clsid;
    GUID m_appid;
    GUID m_partid;
    WCHAR *m_pwszAppName;
    WCHAR *m_pwszCtxName;
    COMPLUS_APPTYPE m_eAppType;
    DWORD m_cReferences;
    DWORD m_cBound;
    DWORD m_cPooled;
    DWORD m_cInCall;
    DWORD m_dwRespTime;
    DWORD m_cCallsCompleted;
    DWORD m_cCallsFailed;
  } CLSIDDATA2;

  typedef DWORD_PTR RESTYPID;
  typedef DWORD_PTR RESID;
  typedef LPOLESTR SRESID;
  typedef LPCOLESTR constSRESID;
  typedef DWORD RESOURCERATING;
  typedef __LONG32 TIMEINSECS;
  typedef DWORD_PTR INSTID;
  typedef DWORD_PTR TRANSID;

#define MTXDM_E_ENLISTRESOURCEFAILED 0x8004E100

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0342_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0342_v0_0_s_ifspec;

#ifndef __IDispenserManager_INTERFACE_DEFINED__
#define __IDispenserManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDispenserManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDispenserManager : public IUnknown {
  public:
    virtual HRESULT WINAPI RegisterDispenser(IDispenserDriver *__MIDL_0014,LPCOLESTR szDispenserName,IHolder **__MIDL_0015) = 0;
    virtual HRESULT WINAPI GetContext(INSTID *__MIDL_0016,TRANSID *__MIDL_0017) = 0;
  };
#else
  typedef struct IDispenserManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDispenserManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDispenserManager *This);
      ULONG (WINAPI *Release)(IDispenserManager *This);
      HRESULT (WINAPI *RegisterDispenser)(IDispenserManager *This,IDispenserDriver *__MIDL_0014,LPCOLESTR szDispenserName,IHolder **__MIDL_0015);
      HRESULT (WINAPI *GetContext)(IDispenserManager *This,INSTID *__MIDL_0016,TRANSID *__MIDL_0017);
    END_INTERFACE
  } IDispenserManagerVtbl;
  struct IDispenserManager {
    CONST_VTBL struct IDispenserManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDispenserManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDispenserManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDispenserManager_Release(This) (This)->lpVtbl->Release(This)
#define IDispenserManager_RegisterDispenser(This,__MIDL_0014,szDispenserName,__MIDL_0015) (This)->lpVtbl->RegisterDispenser(This,__MIDL_0014,szDispenserName,__MIDL_0015)
#define IDispenserManager_GetContext(This,__MIDL_0016,__MIDL_0017) (This)->lpVtbl->GetContext(This,__MIDL_0016,__MIDL_0017)
#endif
#endif
  HRESULT WINAPI IDispenserManager_RegisterDispenser_Proxy(IDispenserManager *This,IDispenserDriver *__MIDL_0014,LPCOLESTR szDispenserName,IHolder **__MIDL_0015);
  void __RPC_STUB IDispenserManager_RegisterDispenser_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDispenserManager_GetContext_Proxy(IDispenserManager *This,INSTID *__MIDL_0016,TRANSID *__MIDL_0017);
  void __RPC_STUB IDispenserManager_GetContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0347_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0347_v0_0_s_ifspec;

#ifndef __IHolder_INTERFACE_DEFINED__
#define __IHolder_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IHolder;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IHolder : public IUnknown {
  public:
    virtual HRESULT WINAPI AllocResource(const RESTYPID __MIDL_0018,RESID *__MIDL_0019) = 0;
    virtual HRESULT WINAPI FreeResource(const RESID __MIDL_0020) = 0;
    virtual HRESULT WINAPI TrackResource(const RESID __MIDL_0021) = 0;
    virtual HRESULT WINAPI TrackResourceS(constSRESID __MIDL_0022) = 0;
    virtual HRESULT WINAPI UntrackResource(const RESID __MIDL_0023,const WINBOOL __MIDL_0024) = 0;
    virtual HRESULT WINAPI UntrackResourceS(constSRESID __MIDL_0025,const WINBOOL __MIDL_0026) = 0;
    virtual HRESULT WINAPI Close(void) = 0;
    virtual HRESULT WINAPI RequestDestroyResource(const RESID __MIDL_0027) = 0;
  };
#else
  typedef struct IHolderVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IHolder *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IHolder *This);
      ULONG (WINAPI *Release)(IHolder *This);
      HRESULT (WINAPI *AllocResource)(IHolder *This,const RESTYPID __MIDL_0018,RESID *__MIDL_0019);
      HRESULT (WINAPI *FreeResource)(IHolder *This,const RESID __MIDL_0020);
      HRESULT (WINAPI *TrackResource)(IHolder *This,const RESID __MIDL_0021);
      HRESULT (WINAPI *TrackResourceS)(IHolder *This,constSRESID __MIDL_0022);
      HRESULT (WINAPI *UntrackResource)(IHolder *This,const RESID __MIDL_0023,const WINBOOL __MIDL_0024);
      HRESULT (WINAPI *UntrackResourceS)(IHolder *This,constSRESID __MIDL_0025,const WINBOOL __MIDL_0026);
      HRESULT (WINAPI *Close)(IHolder *This);
      HRESULT (WINAPI *RequestDestroyResource)(IHolder *This,const RESID __MIDL_0027);
    END_INTERFACE
  } IHolderVtbl;
  struct IHolder {
    CONST_VTBL struct IHolderVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IHolder_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IHolder_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IHolder_Release(This) (This)->lpVtbl->Release(This)
#define IHolder_AllocResource(This,__MIDL_0018,__MIDL_0019) (This)->lpVtbl->AllocResource(This,__MIDL_0018,__MIDL_0019)
#define IHolder_FreeResource(This,__MIDL_0020) (This)->lpVtbl->FreeResource(This,__MIDL_0020)
#define IHolder_TrackResource(This,__MIDL_0021) (This)->lpVtbl->TrackResource(This,__MIDL_0021)
#define IHolder_TrackResourceS(This,__MIDL_0022) (This)->lpVtbl->TrackResourceS(This,__MIDL_0022)
#define IHolder_UntrackResource(This,__MIDL_0023,__MIDL_0024) (This)->lpVtbl->UntrackResource(This,__MIDL_0023,__MIDL_0024)
#define IHolder_UntrackResourceS(This,__MIDL_0025,__MIDL_0026) (This)->lpVtbl->UntrackResourceS(This,__MIDL_0025,__MIDL_0026)
#define IHolder_Close(This) (This)->lpVtbl->Close(This)
#define IHolder_RequestDestroyResource(This,__MIDL_0027) (This)->lpVtbl->RequestDestroyResource(This,__MIDL_0027)
#endif
#endif
  HRESULT WINAPI IHolder_AllocResource_Proxy(IHolder *This,const RESTYPID __MIDL_0018,RESID *__MIDL_0019);
  void __RPC_STUB IHolder_AllocResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHolder_FreeResource_Proxy(IHolder *This,const RESID __MIDL_0020);
  void __RPC_STUB IHolder_FreeResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHolder_TrackResource_Proxy(IHolder *This,const RESID __MIDL_0021);
  void __RPC_STUB IHolder_TrackResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHolder_TrackResourceS_Proxy(IHolder *This,constSRESID __MIDL_0022);
  void __RPC_STUB IHolder_TrackResourceS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHolder_UntrackResource_Proxy(IHolder *This,const RESID __MIDL_0023,const WINBOOL __MIDL_0024);
  void __RPC_STUB IHolder_UntrackResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHolder_UntrackResourceS_Proxy(IHolder *This,constSRESID __MIDL_0025,const WINBOOL __MIDL_0026);
  void __RPC_STUB IHolder_UntrackResourceS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHolder_Close_Proxy(IHolder *This);
  void __RPC_STUB IHolder_Close_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IHolder_RequestDestroyResource_Proxy(IHolder *This,const RESID __MIDL_0027);
  void __RPC_STUB IHolder_RequestDestroyResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0348_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0348_v0_0_s_ifspec;

#ifndef __IDispenserDriver_INTERFACE_DEFINED__
#define __IDispenserDriver_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDispenserDriver;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDispenserDriver : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateResource(const RESTYPID ResTypId,RESID *pResId,TIMEINSECS *pSecsFreeBeforeDestroy) = 0;
    virtual HRESULT WINAPI RateResource(const RESTYPID ResTypId,const RESID ResId,const WINBOOL fRequiresTransactionEnlistment,RESOURCERATING *pRating) = 0;
    virtual HRESULT WINAPI EnlistResource(const RESID ResId,const TRANSID TransId) = 0;
    virtual HRESULT WINAPI ResetResource(const RESID ResId) = 0;
    virtual HRESULT WINAPI DestroyResource(const RESID ResId) = 0;
    virtual HRESULT WINAPI DestroyResourceS(constSRESID ResId) = 0;
  };
#else
  typedef struct IDispenserDriverVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDispenserDriver *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDispenserDriver *This);
      ULONG (WINAPI *Release)(IDispenserDriver *This);
      HRESULT (WINAPI *CreateResource)(IDispenserDriver *This,const RESTYPID ResTypId,RESID *pResId,TIMEINSECS *pSecsFreeBeforeDestroy);
      HRESULT (WINAPI *RateResource)(IDispenserDriver *This,const RESTYPID ResTypId,const RESID ResId,const WINBOOL fRequiresTransactionEnlistment,RESOURCERATING *pRating);
      HRESULT (WINAPI *EnlistResource)(IDispenserDriver *This,const RESID ResId,const TRANSID TransId);
      HRESULT (WINAPI *ResetResource)(IDispenserDriver *This,const RESID ResId);
      HRESULT (WINAPI *DestroyResource)(IDispenserDriver *This,const RESID ResId);
      HRESULT (WINAPI *DestroyResourceS)(IDispenserDriver *This,constSRESID ResId);
    END_INTERFACE
  } IDispenserDriverVtbl;
  struct IDispenserDriver {
    CONST_VTBL struct IDispenserDriverVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDispenserDriver_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDispenserDriver_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDispenserDriver_Release(This) (This)->lpVtbl->Release(This)
#define IDispenserDriver_CreateResource(This,ResTypId,pResId,pSecsFreeBeforeDestroy) (This)->lpVtbl->CreateResource(This,ResTypId,pResId,pSecsFreeBeforeDestroy)
#define IDispenserDriver_RateResource(This,ResTypId,ResId,fRequiresTransactionEnlistment,pRating) (This)->lpVtbl->RateResource(This,ResTypId,ResId,fRequiresTransactionEnlistment,pRating)
#define IDispenserDriver_EnlistResource(This,ResId,TransId) (This)->lpVtbl->EnlistResource(This,ResId,TransId)
#define IDispenserDriver_ResetResource(This,ResId) (This)->lpVtbl->ResetResource(This,ResId)
#define IDispenserDriver_DestroyResource(This,ResId) (This)->lpVtbl->DestroyResource(This,ResId)
#define IDispenserDriver_DestroyResourceS(This,ResId) (This)->lpVtbl->DestroyResourceS(This,ResId)
#endif
#endif
  HRESULT WINAPI IDispenserDriver_CreateResource_Proxy(IDispenserDriver *This,const RESTYPID ResTypId,RESID *pResId,TIMEINSECS *pSecsFreeBeforeDestroy);
  void __RPC_STUB IDispenserDriver_CreateResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDispenserDriver_RateResource_Proxy(IDispenserDriver *This,const RESTYPID ResTypId,const RESID ResId,const WINBOOL fRequiresTransactionEnlistment,RESOURCERATING *pRating);
  void __RPC_STUB IDispenserDriver_RateResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDispenserDriver_EnlistResource_Proxy(IDispenserDriver *This,const RESID ResId,const TRANSID TransId);
  void __RPC_STUB IDispenserDriver_EnlistResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDispenserDriver_ResetResource_Proxy(IDispenserDriver *This,const RESID ResId);
  void __RPC_STUB IDispenserDriver_ResetResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDispenserDriver_DestroyResource_Proxy(IDispenserDriver *This,const RESID ResId);
  void __RPC_STUB IDispenserDriver_DestroyResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDispenserDriver_DestroyResourceS_Proxy(IDispenserDriver *This,constSRESID ResId);
  void __RPC_STUB IDispenserDriver_DestroyResourceS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#if defined(USE_UUIDOF_FOR_IID_) && USE___UUIDOF != 0
#define IID_IHolder __uuidof(IIHolder)
#define IID_IDispenserManager __uuidof(IDispenserManager)
#define IID_IDispenserDriver __uuidof(IDispenserDriver)
#endif

#define CRR_NO_REASON_SUPPLIED 0x00000000
#define CRR_LIFETIME_LIMIT 0xFFFFFFFF
#define CRR_ACTIVATION_LIMIT 0xFFFFFFFE
#define CRR_CALL_LIMIT 0xFFFFFFFD
#define CRR_MEMORY_LIMIT 0xFFFFFFFC
#define CRR_RECYCLED_FROM_UI 0xFFFFFFFB

  EXTERN_C const CLSID CLSID_MTSPackage;
  EXTERN_C const GUID GUID_DefaultAppPartition;
  EXTERN_C const GUID GUID_FinalizerCID;
  EXTERN_C const GUID IID_IEnterActivityWithNoLock;

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0349_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0349_v0_0_s_ifspec;

#ifndef __IObjectContext_INTERFACE_DEFINED__
#define __IObjectContext_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectContext;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectContext : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateInstance(REFCLSID rclsid,REFIID riid,LPVOID *ppv) = 0;
    virtual HRESULT WINAPI SetComplete(void) = 0;
    virtual HRESULT WINAPI SetAbort(void) = 0;
    virtual HRESULT WINAPI EnableCommit(void) = 0;
    virtual HRESULT WINAPI DisableCommit(void) = 0;
    virtual WINBOOL WINAPI IsInTransaction(void) = 0;
    virtual WINBOOL WINAPI IsSecurityEnabled(void) = 0;
    virtual HRESULT WINAPI IsCallerInRole(BSTR bstrRole,WINBOOL *pfIsInRole) = 0;
  };
#else
  typedef struct IObjectContextVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectContext *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectContext *This);
      ULONG (WINAPI *Release)(IObjectContext *This);
      HRESULT (WINAPI *CreateInstance)(IObjectContext *This,REFCLSID rclsid,REFIID riid,LPVOID *ppv);
      HRESULT (WINAPI *SetComplete)(IObjectContext *This);
      HRESULT (WINAPI *SetAbort)(IObjectContext *This);
      HRESULT (WINAPI *EnableCommit)(IObjectContext *This);
      HRESULT (WINAPI *DisableCommit)(IObjectContext *This);
      WINBOOL (WINAPI *IsInTransaction)(IObjectContext *This);
      WINBOOL (WINAPI *IsSecurityEnabled)(IObjectContext *This);
      HRESULT (WINAPI *IsCallerInRole)(IObjectContext *This,BSTR bstrRole,WINBOOL *pfIsInRole);
    END_INTERFACE
  } IObjectContextVtbl;
  struct IObjectContext {
    CONST_VTBL struct IObjectContextVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectContext_Release(This) (This)->lpVtbl->Release(This)
#define IObjectContext_CreateInstance(This,rclsid,riid,ppv) (This)->lpVtbl->CreateInstance(This,rclsid,riid,ppv)
#define IObjectContext_SetComplete(This) (This)->lpVtbl->SetComplete(This)
#define IObjectContext_SetAbort(This) (This)->lpVtbl->SetAbort(This)
#define IObjectContext_EnableCommit(This) (This)->lpVtbl->EnableCommit(This)
#define IObjectContext_DisableCommit(This) (This)->lpVtbl->DisableCommit(This)
#define IObjectContext_IsInTransaction(This) (This)->lpVtbl->IsInTransaction(This)
#define IObjectContext_IsSecurityEnabled(This) (This)->lpVtbl->IsSecurityEnabled(This)
#define IObjectContext_IsCallerInRole(This,bstrRole,pfIsInRole) (This)->lpVtbl->IsCallerInRole(This,bstrRole,pfIsInRole)
#endif
#endif
  HRESULT WINAPI IObjectContext_CreateInstance_Proxy(IObjectContext *This,REFCLSID rclsid,REFIID riid,LPVOID *ppv);
  void __RPC_STUB IObjectContext_CreateInstance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContext_SetComplete_Proxy(IObjectContext *This);
  void __RPC_STUB IObjectContext_SetComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContext_SetAbort_Proxy(IObjectContext *This);
  void __RPC_STUB IObjectContext_SetAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContext_EnableCommit_Proxy(IObjectContext *This);
  void __RPC_STUB IObjectContext_EnableCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContext_DisableCommit_Proxy(IObjectContext *This);
  void __RPC_STUB IObjectContext_DisableCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  WINBOOL WINAPI IObjectContext_IsInTransaction_Proxy(IObjectContext *This);
  void __RPC_STUB IObjectContext_IsInTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  WINBOOL WINAPI IObjectContext_IsSecurityEnabled_Proxy(IObjectContext *This);
  void __RPC_STUB IObjectContext_IsSecurityEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContext_IsCallerInRole_Proxy(IObjectContext *This,BSTR bstrRole,WINBOOL *pfIsInRole);
  void __RPC_STUB IObjectContext_IsCallerInRole_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjectControl_INTERFACE_DEFINED__
#define __IObjectControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectControl : public IUnknown {
  public:
    virtual HRESULT WINAPI Activate(void) = 0;
    virtual void WINAPI Deactivate(void) = 0;
    virtual WINBOOL WINAPI CanBePooled(void) = 0;
  };
#else
  typedef struct IObjectControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectControl *This);
      ULONG (WINAPI *Release)(IObjectControl *This);
      HRESULT (WINAPI *Activate)(IObjectControl *This);
      void (WINAPI *Deactivate)(IObjectControl *This);
      WINBOOL (WINAPI *CanBePooled)(IObjectControl *This);
    END_INTERFACE
  } IObjectControlVtbl;
  struct IObjectControl {
    CONST_VTBL struct IObjectControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectControl_Release(This) (This)->lpVtbl->Release(This)
#define IObjectControl_Activate(This) (This)->lpVtbl->Activate(This)
#define IObjectControl_Deactivate(This) (This)->lpVtbl->Deactivate(This)
#define IObjectControl_CanBePooled(This) (This)->lpVtbl->CanBePooled(This)
#endif
#endif
  HRESULT WINAPI IObjectControl_Activate_Proxy(IObjectControl *This);
  void __RPC_STUB IObjectControl_Activate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IObjectControl_Deactivate_Proxy(IObjectControl *This);
  void __RPC_STUB IObjectControl_Deactivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  WINBOOL WINAPI IObjectControl_CanBePooled_Proxy(IObjectControl *This);
  void __RPC_STUB IObjectControl_CanBePooled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumNames_INTERFACE_DEFINED__
#define __IEnumNames_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumNames;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumNames : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(unsigned __LONG32 celt,BSTR *rgname,unsigned __LONG32 *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(unsigned __LONG32 celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumNames **ppenum) = 0;
  };
#else
  typedef struct IEnumNamesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumNames *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumNames *This);
      ULONG (WINAPI *Release)(IEnumNames *This);
      HRESULT (WINAPI *Next)(IEnumNames *This,unsigned __LONG32 celt,BSTR *rgname,unsigned __LONG32 *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumNames *This,unsigned __LONG32 celt);
      HRESULT (WINAPI *Reset)(IEnumNames *This);
      HRESULT (WINAPI *Clone)(IEnumNames *This,IEnumNames **ppenum);
    END_INTERFACE
  } IEnumNamesVtbl;
  struct IEnumNames {
    CONST_VTBL struct IEnumNamesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumNames_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumNames_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumNames_Release(This) (This)->lpVtbl->Release(This)
#define IEnumNames_Next(This,celt,rgname,pceltFetched) (This)->lpVtbl->Next(This,celt,rgname,pceltFetched)
#define IEnumNames_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumNames_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumNames_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumNames_Next_Proxy(IEnumNames *This,unsigned __LONG32 celt,BSTR *rgname,unsigned __LONG32 *pceltFetched);
  void __RPC_STUB IEnumNames_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNames_Skip_Proxy(IEnumNames *This,unsigned __LONG32 celt);
  void __RPC_STUB IEnumNames_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNames_Reset_Proxy(IEnumNames *This);
  void __RPC_STUB IEnumNames_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumNames_Clone_Proxy(IEnumNames *This,IEnumNames **ppenum);
  void __RPC_STUB IEnumNames_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISecurityProperty_INTERFACE_DEFINED__
#define __ISecurityProperty_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISecurityProperty;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISecurityProperty : public IUnknown {
  public:
    virtual HRESULT WINAPI GetDirectCreatorSID(PSID *pSID) = 0;
    virtual HRESULT WINAPI GetOriginalCreatorSID(PSID *pSID) = 0;
    virtual HRESULT WINAPI GetDirectCallerSID(PSID *pSID) = 0;
    virtual HRESULT WINAPI GetOriginalCallerSID(PSID *pSID) = 0;
    virtual HRESULT WINAPI ReleaseSID(PSID pSID) = 0;
  };
#else
  typedef struct ISecurityPropertyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISecurityProperty *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISecurityProperty *This);
      ULONG (WINAPI *Release)(ISecurityProperty *This);
      HRESULT (WINAPI *GetDirectCreatorSID)(ISecurityProperty *This,PSID *pSID);
      HRESULT (WINAPI *GetOriginalCreatorSID)(ISecurityProperty *This,PSID *pSID);
      HRESULT (WINAPI *GetDirectCallerSID)(ISecurityProperty *This,PSID *pSID);
      HRESULT (WINAPI *GetOriginalCallerSID)(ISecurityProperty *This,PSID *pSID);
      HRESULT (WINAPI *ReleaseSID)(ISecurityProperty *This,PSID pSID);
    END_INTERFACE
  } ISecurityPropertyVtbl;
  struct ISecurityProperty {
    CONST_VTBL struct ISecurityPropertyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISecurityProperty_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISecurityProperty_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISecurityProperty_Release(This) (This)->lpVtbl->Release(This)
#define ISecurityProperty_GetDirectCreatorSID(This,pSID) (This)->lpVtbl->GetDirectCreatorSID(This,pSID)
#define ISecurityProperty_GetOriginalCreatorSID(This,pSID) (This)->lpVtbl->GetOriginalCreatorSID(This,pSID)
#define ISecurityProperty_GetDirectCallerSID(This,pSID) (This)->lpVtbl->GetDirectCallerSID(This,pSID)
#define ISecurityProperty_GetOriginalCallerSID(This,pSID) (This)->lpVtbl->GetOriginalCallerSID(This,pSID)
#define ISecurityProperty_ReleaseSID(This,pSID) (This)->lpVtbl->ReleaseSID(This,pSID)
#endif
#endif
  HRESULT WINAPI ISecurityProperty_GetDirectCreatorSID_Proxy(ISecurityProperty *This,PSID *pSID);
  void __RPC_STUB ISecurityProperty_GetDirectCreatorSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityProperty_GetOriginalCreatorSID_Proxy(ISecurityProperty *This,PSID *pSID);
  void __RPC_STUB ISecurityProperty_GetOriginalCreatorSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityProperty_GetDirectCallerSID_Proxy(ISecurityProperty *This,PSID *pSID);
  void __RPC_STUB ISecurityProperty_GetDirectCallerSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityProperty_GetOriginalCallerSID_Proxy(ISecurityProperty *This,PSID *pSID);
  void __RPC_STUB ISecurityProperty_GetOriginalCallerSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISecurityProperty_ReleaseSID_Proxy(ISecurityProperty *This,PSID pSID);
  void __RPC_STUB ISecurityProperty_ReleaseSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ObjectControl_INTERFACE_DEFINED__
#define __ObjectControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ObjectControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ObjectControl : public IUnknown {
  public:
    virtual HRESULT WINAPI Activate(void) = 0;
    virtual HRESULT WINAPI Deactivate(void) = 0;
    virtual HRESULT WINAPI CanBePooled(VARIANT_BOOL *pbPoolable) = 0;
  };
#else
  typedef struct ObjectControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ObjectControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ObjectControl *This);
      ULONG (WINAPI *Release)(ObjectControl *This);
      HRESULT (WINAPI *Activate)(ObjectControl *This);
      HRESULT (WINAPI *Deactivate)(ObjectControl *This);
      HRESULT (WINAPI *CanBePooled)(ObjectControl *This,VARIANT_BOOL *pbPoolable);
    END_INTERFACE
  } ObjectControlVtbl;
  struct ObjectControl {
    CONST_VTBL struct ObjectControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ObjectControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ObjectControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ObjectControl_Release(This) (This)->lpVtbl->Release(This)
#define ObjectControl_Activate(This) (This)->lpVtbl->Activate(This)
#define ObjectControl_Deactivate(This) (This)->lpVtbl->Deactivate(This)
#define ObjectControl_CanBePooled(This,pbPoolable) (This)->lpVtbl->CanBePooled(This,pbPoolable)
#endif
#endif
  HRESULT WINAPI ObjectControl_Activate_Proxy(ObjectControl *This);
  void __RPC_STUB ObjectControl_Activate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectControl_Deactivate_Proxy(ObjectControl *This);
  void __RPC_STUB ObjectControl_Deactivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ObjectControl_CanBePooled_Proxy(ObjectControl *This,VARIANT_BOOL *pbPoolable);
  void __RPC_STUB ObjectControl_CanBePooled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISharedProperty_INTERFACE_DEFINED__
#define __ISharedProperty_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISharedProperty;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISharedProperty : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Value(VARIANT *pVal) = 0;
    virtual HRESULT WINAPI put_Value(VARIANT val) = 0;
  };
#else
  typedef struct ISharedPropertyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISharedProperty *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISharedProperty *This);
      ULONG (WINAPI *Release)(ISharedProperty *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISharedProperty *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISharedProperty *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISharedProperty *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISharedProperty *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Value)(ISharedProperty *This,VARIANT *pVal);
      HRESULT (WINAPI *put_Value)(ISharedProperty *This,VARIANT val);
    END_INTERFACE
  } ISharedPropertyVtbl;
  struct ISharedProperty {
    CONST_VTBL struct ISharedPropertyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISharedProperty_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISharedProperty_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISharedProperty_Release(This) (This)->lpVtbl->Release(This)
#define ISharedProperty_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISharedProperty_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISharedProperty_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISharedProperty_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISharedProperty_get_Value(This,pVal) (This)->lpVtbl->get_Value(This,pVal)
#define ISharedProperty_put_Value(This,val) (This)->lpVtbl->put_Value(This,val)
#endif
#endif
  HRESULT WINAPI ISharedProperty_get_Value_Proxy(ISharedProperty *This,VARIANT *pVal);
  void __RPC_STUB ISharedProperty_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISharedProperty_put_Value_Proxy(ISharedProperty *This,VARIANT val);
  void __RPC_STUB ISharedProperty_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISharedPropertyGroup_INTERFACE_DEFINED__
#define __ISharedPropertyGroup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISharedPropertyGroup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISharedPropertyGroup : public IDispatch {
  public:
    virtual HRESULT WINAPI CreatePropertyByPosition(int Index,VARIANT_BOOL *fExists,ISharedProperty **ppProp) = 0;
    virtual HRESULT WINAPI get_PropertyByPosition(int Index,ISharedProperty **ppProperty) = 0;
    virtual HRESULT WINAPI CreateProperty(BSTR Name,VARIANT_BOOL *fExists,ISharedProperty **ppProp) = 0;
    virtual HRESULT WINAPI get_Property(BSTR Name,ISharedProperty **ppProperty) = 0;
  };
#else
  typedef struct ISharedPropertyGroupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISharedPropertyGroup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISharedPropertyGroup *This);
      ULONG (WINAPI *Release)(ISharedPropertyGroup *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISharedPropertyGroup *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISharedPropertyGroup *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISharedPropertyGroup *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISharedPropertyGroup *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *CreatePropertyByPosition)(ISharedPropertyGroup *This,int Index,VARIANT_BOOL *fExists,ISharedProperty **ppProp);
      HRESULT (WINAPI *get_PropertyByPosition)(ISharedPropertyGroup *This,int Index,ISharedProperty **ppProperty);
      HRESULT (WINAPI *CreateProperty)(ISharedPropertyGroup *This,BSTR Name,VARIANT_BOOL *fExists,ISharedProperty **ppProp);
      HRESULT (WINAPI *get_Property)(ISharedPropertyGroup *This,BSTR Name,ISharedProperty **ppProperty);
    END_INTERFACE
  } ISharedPropertyGroupVtbl;
  struct ISharedPropertyGroup {
    CONST_VTBL struct ISharedPropertyGroupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISharedPropertyGroup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISharedPropertyGroup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISharedPropertyGroup_Release(This) (This)->lpVtbl->Release(This)
#define ISharedPropertyGroup_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISharedPropertyGroup_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISharedPropertyGroup_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISharedPropertyGroup_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISharedPropertyGroup_CreatePropertyByPosition(This,Index,fExists,ppProp) (This)->lpVtbl->CreatePropertyByPosition(This,Index,fExists,ppProp)
#define ISharedPropertyGroup_get_PropertyByPosition(This,Index,ppProperty) (This)->lpVtbl->get_PropertyByPosition(This,Index,ppProperty)
#define ISharedPropertyGroup_CreateProperty(This,Name,fExists,ppProp) (This)->lpVtbl->CreateProperty(This,Name,fExists,ppProp)
#define ISharedPropertyGroup_get_Property(This,Name,ppProperty) (This)->lpVtbl->get_Property(This,Name,ppProperty)
#endif
#endif
  HRESULT WINAPI ISharedPropertyGroup_CreatePropertyByPosition_Proxy(ISharedPropertyGroup *This,int Index,VARIANT_BOOL *fExists,ISharedProperty **ppProp);
  void __RPC_STUB ISharedPropertyGroup_CreatePropertyByPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISharedPropertyGroup_get_PropertyByPosition_Proxy(ISharedPropertyGroup *This,int Index,ISharedProperty **ppProperty);
  void __RPC_STUB ISharedPropertyGroup_get_PropertyByPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISharedPropertyGroup_CreateProperty_Proxy(ISharedPropertyGroup *This,BSTR Name,VARIANT_BOOL *fExists,ISharedProperty **ppProp);
  void __RPC_STUB ISharedPropertyGroup_CreateProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISharedPropertyGroup_get_Property_Proxy(ISharedPropertyGroup *This,BSTR Name,ISharedProperty **ppProperty);
  void __RPC_STUB ISharedPropertyGroup_get_Property_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISharedPropertyGroupManager_INTERFACE_DEFINED__
#define __ISharedPropertyGroupManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISharedPropertyGroupManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISharedPropertyGroupManager : public IDispatch {
  public:
    virtual HRESULT WINAPI CreatePropertyGroup(BSTR Name,LONG *dwIsoMode,LONG *dwRelMode,VARIANT_BOOL *fExists,ISharedPropertyGroup **ppGroup) = 0;
    virtual HRESULT WINAPI get_Group(BSTR Name,ISharedPropertyGroup **ppGroup) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
  };
#else
  typedef struct ISharedPropertyGroupManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISharedPropertyGroupManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISharedPropertyGroupManager *This);
      ULONG (WINAPI *Release)(ISharedPropertyGroupManager *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISharedPropertyGroupManager *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISharedPropertyGroupManager *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISharedPropertyGroupManager *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISharedPropertyGroupManager *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *CreatePropertyGroup)(ISharedPropertyGroupManager *This,BSTR Name,LONG *dwIsoMode,LONG *dwRelMode,VARIANT_BOOL *fExists,ISharedPropertyGroup **ppGroup);
      HRESULT (WINAPI *get_Group)(ISharedPropertyGroupManager *This,BSTR Name,ISharedPropertyGroup **ppGroup);
      HRESULT (WINAPI *get__NewEnum)(ISharedPropertyGroupManager *This,IUnknown **retval);
    END_INTERFACE
  } ISharedPropertyGroupManagerVtbl;
  struct ISharedPropertyGroupManager {
    CONST_VTBL struct ISharedPropertyGroupManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISharedPropertyGroupManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISharedPropertyGroupManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISharedPropertyGroupManager_Release(This) (This)->lpVtbl->Release(This)
#define ISharedPropertyGroupManager_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISharedPropertyGroupManager_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISharedPropertyGroupManager_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISharedPropertyGroupManager_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISharedPropertyGroupManager_CreatePropertyGroup(This,Name,dwIsoMode,dwRelMode,fExists,ppGroup) (This)->lpVtbl->CreatePropertyGroup(This,Name,dwIsoMode,dwRelMode,fExists,ppGroup)
#define ISharedPropertyGroupManager_get_Group(This,Name,ppGroup) (This)->lpVtbl->get_Group(This,Name,ppGroup)
#define ISharedPropertyGroupManager_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#endif
#endif
  HRESULT WINAPI ISharedPropertyGroupManager_CreatePropertyGroup_Proxy(ISharedPropertyGroupManager *This,BSTR Name,LONG *dwIsoMode,LONG *dwRelMode,VARIANT_BOOL *fExists,ISharedPropertyGroup **ppGroup);
  void __RPC_STUB ISharedPropertyGroupManager_CreatePropertyGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISharedPropertyGroupManager_get_Group_Proxy(ISharedPropertyGroupManager *This,BSTR Name,ISharedPropertyGroup **ppGroup);
  void __RPC_STUB ISharedPropertyGroupManager_get_Group_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISharedPropertyGroupManager_get__NewEnum_Proxy(ISharedPropertyGroupManager *This,IUnknown **retval);
  void __RPC_STUB ISharedPropertyGroupManager_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjectConstruct_INTERFACE_DEFINED__
#define __IObjectConstruct_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectConstruct;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectConstruct : public IUnknown {
  public:
    virtual HRESULT WINAPI Construct(IDispatch *pCtorObj) = 0;
  };
#else
  typedef struct IObjectConstructVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectConstruct *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectConstruct *This);
      ULONG (WINAPI *Release)(IObjectConstruct *This);
      HRESULT (WINAPI *Construct)(IObjectConstruct *This,IDispatch *pCtorObj);
    END_INTERFACE
  } IObjectConstructVtbl;
  struct IObjectConstruct {
    CONST_VTBL struct IObjectConstructVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectConstruct_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectConstruct_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectConstruct_Release(This) (This)->lpVtbl->Release(This)
#define IObjectConstruct_Construct(This,pCtorObj) (This)->lpVtbl->Construct(This,pCtorObj)
#endif
#endif
  HRESULT WINAPI IObjectConstruct_Construct_Proxy(IObjectConstruct *This,IDispatch *pCtorObj);
  void __RPC_STUB IObjectConstruct_Construct_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjectConstructString_INTERFACE_DEFINED__
#define __IObjectConstructString_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectConstructString;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectConstructString : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ConstructString(BSTR *pVal) = 0;
  };
#else
  typedef struct IObjectConstructStringVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectConstructString *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectConstructString *This);
      ULONG (WINAPI *Release)(IObjectConstructString *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IObjectConstructString *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IObjectConstructString *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IObjectConstructString *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IObjectConstructString *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ConstructString)(IObjectConstructString *This,BSTR *pVal);
    END_INTERFACE
  } IObjectConstructStringVtbl;
  struct IObjectConstructString {
    CONST_VTBL struct IObjectConstructStringVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectConstructString_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectConstructString_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectConstructString_Release(This) (This)->lpVtbl->Release(This)
#define IObjectConstructString_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IObjectConstructString_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IObjectConstructString_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IObjectConstructString_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IObjectConstructString_get_ConstructString(This,pVal) (This)->lpVtbl->get_ConstructString(This,pVal)
#endif
#endif
  HRESULT WINAPI IObjectConstructString_get_ConstructString_Proxy(IObjectConstructString *This,BSTR *pVal);
  void __RPC_STUB IObjectConstructString_get_ConstructString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjectContextActivity_INTERFACE_DEFINED__
#define __IObjectContextActivity_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectContextActivity;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectContextActivity : public IUnknown {
  public:
    virtual HRESULT WINAPI GetActivityId(GUID *pGUID) = 0;
  };
#else
  typedef struct IObjectContextActivityVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectContextActivity *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectContextActivity *This);
      ULONG (WINAPI *Release)(IObjectContextActivity *This);
      HRESULT (WINAPI *GetActivityId)(IObjectContextActivity *This,GUID *pGUID);
    END_INTERFACE
  } IObjectContextActivityVtbl;
  struct IObjectContextActivity {
    CONST_VTBL struct IObjectContextActivityVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectContextActivity_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectContextActivity_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectContextActivity_Release(This) (This)->lpVtbl->Release(This)
#define IObjectContextActivity_GetActivityId(This,pGUID) (This)->lpVtbl->GetActivityId(This,pGUID)
#endif
#endif
  HRESULT WINAPI IObjectContextActivity_GetActivityId_Proxy(IObjectContextActivity *This,GUID *pGUID);
  void __RPC_STUB IObjectContextActivity_GetActivityId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjectContextInfo_INTERFACE_DEFINED__
#define __IObjectContextInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectContextInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectContextInfo : public IUnknown {
  public:
    virtual WINBOOL WINAPI IsInTransaction(void) = 0;
    virtual HRESULT WINAPI GetTransaction(IUnknown **pptrans) = 0;
    virtual HRESULT WINAPI GetTransactionId(GUID *pGuid) = 0;
    virtual HRESULT WINAPI GetActivityId(GUID *pGUID) = 0;
    virtual HRESULT WINAPI GetContextId(GUID *pGuid) = 0;
  };
#else
  typedef struct IObjectContextInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectContextInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectContextInfo *This);
      ULONG (WINAPI *Release)(IObjectContextInfo *This);
      WINBOOL (WINAPI *IsInTransaction)(IObjectContextInfo *This);
      HRESULT (WINAPI *GetTransaction)(IObjectContextInfo *This,IUnknown **pptrans);
      HRESULT (WINAPI *GetTransactionId)(IObjectContextInfo *This,GUID *pGuid);
      HRESULT (WINAPI *GetActivityId)(IObjectContextInfo *This,GUID *pGUID);
      HRESULT (WINAPI *GetContextId)(IObjectContextInfo *This,GUID *pGuid);
    END_INTERFACE
  } IObjectContextInfoVtbl;
  struct IObjectContextInfo {
    CONST_VTBL struct IObjectContextInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectContextInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectContextInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectContextInfo_Release(This) (This)->lpVtbl->Release(This)
#define IObjectContextInfo_IsInTransaction(This) (This)->lpVtbl->IsInTransaction(This)
#define IObjectContextInfo_GetTransaction(This,pptrans) (This)->lpVtbl->GetTransaction(This,pptrans)
#define IObjectContextInfo_GetTransactionId(This,pGuid) (This)->lpVtbl->GetTransactionId(This,pGuid)
#define IObjectContextInfo_GetActivityId(This,pGUID) (This)->lpVtbl->GetActivityId(This,pGUID)
#define IObjectContextInfo_GetContextId(This,pGuid) (This)->lpVtbl->GetContextId(This,pGuid)
#endif
#endif
  WINBOOL WINAPI IObjectContextInfo_IsInTransaction_Proxy(IObjectContextInfo *This);
  void __RPC_STUB IObjectContextInfo_IsInTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContextInfo_GetTransaction_Proxy(IObjectContextInfo *This,IUnknown **pptrans);
  void __RPC_STUB IObjectContextInfo_GetTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContextInfo_GetTransactionId_Proxy(IObjectContextInfo *This,GUID *pGuid);
  void __RPC_STUB IObjectContextInfo_GetTransactionId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContextInfo_GetActivityId_Proxy(IObjectContextInfo *This,GUID *pGUID);
  void __RPC_STUB IObjectContextInfo_GetActivityId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContextInfo_GetContextId_Proxy(IObjectContextInfo *This,GUID *pGuid);
  void __RPC_STUB IObjectContextInfo_GetContextId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjectContextInfo2_INTERFACE_DEFINED__
#define __IObjectContextInfo2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectContextInfo2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectContextInfo2 : public IObjectContextInfo {
  public:
    virtual HRESULT WINAPI GetPartitionId(GUID *pGuid) = 0;
    virtual HRESULT WINAPI GetApplicationId(GUID *pGuid) = 0;
    virtual HRESULT WINAPI GetApplicationInstanceId(GUID *pGuid) = 0;
  };
#else
  typedef struct IObjectContextInfo2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectContextInfo2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectContextInfo2 *This);
      ULONG (WINAPI *Release)(IObjectContextInfo2 *This);
      WINBOOL (WINAPI *IsInTransaction)(IObjectContextInfo2 *This);
      HRESULT (WINAPI *GetTransaction)(IObjectContextInfo2 *This,IUnknown **pptrans);
      HRESULT (WINAPI *GetTransactionId)(IObjectContextInfo2 *This,GUID *pGuid);
      HRESULT (WINAPI *GetActivityId)(IObjectContextInfo2 *This,GUID *pGUID);
      HRESULT (WINAPI *GetContextId)(IObjectContextInfo2 *This,GUID *pGuid);
      HRESULT (WINAPI *GetPartitionId)(IObjectContextInfo2 *This,GUID *pGuid);
      HRESULT (WINAPI *GetApplicationId)(IObjectContextInfo2 *This,GUID *pGuid);
      HRESULT (WINAPI *GetApplicationInstanceId)(IObjectContextInfo2 *This,GUID *pGuid);
    END_INTERFACE
  } IObjectContextInfo2Vtbl;
  struct IObjectContextInfo2 {
    CONST_VTBL struct IObjectContextInfo2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectContextInfo2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectContextInfo2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectContextInfo2_Release(This) (This)->lpVtbl->Release(This)
#define IObjectContextInfo2_IsInTransaction(This) (This)->lpVtbl->IsInTransaction(This)
#define IObjectContextInfo2_GetTransaction(This,pptrans) (This)->lpVtbl->GetTransaction(This,pptrans)
#define IObjectContextInfo2_GetTransactionId(This,pGuid) (This)->lpVtbl->GetTransactionId(This,pGuid)
#define IObjectContextInfo2_GetActivityId(This,pGUID) (This)->lpVtbl->GetActivityId(This,pGUID)
#define IObjectContextInfo2_GetContextId(This,pGuid) (This)->lpVtbl->GetContextId(This,pGuid)
#define IObjectContextInfo2_GetPartitionId(This,pGuid) (This)->lpVtbl->GetPartitionId(This,pGuid)
#define IObjectContextInfo2_GetApplicationId(This,pGuid) (This)->lpVtbl->GetApplicationId(This,pGuid)
#define IObjectContextInfo2_GetApplicationInstanceId(This,pGuid) (This)->lpVtbl->GetApplicationInstanceId(This,pGuid)
#endif
#endif
  HRESULT WINAPI IObjectContextInfo2_GetPartitionId_Proxy(IObjectContextInfo2 *This,GUID *pGuid);
  void __RPC_STUB IObjectContextInfo2_GetPartitionId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContextInfo2_GetApplicationId_Proxy(IObjectContextInfo2 *This,GUID *pGuid);
  void __RPC_STUB IObjectContextInfo2_GetApplicationId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IObjectContextInfo2_GetApplicationInstanceId_Proxy(IObjectContextInfo2 *This,GUID *pGuid);
  void __RPC_STUB IObjectContextInfo2_GetApplicationInstanceId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionStatus_INTERFACE_DEFINED__
#define __ITransactionStatus_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionStatus;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionStatus : public IUnknown {
  public:
    virtual HRESULT WINAPI SetTransactionStatus(HRESULT hrStatus) = 0;
    virtual HRESULT WINAPI GetTransactionStatus(HRESULT *pHrStatus) = 0;
  };
#else
  typedef struct ITransactionStatusVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionStatus *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionStatus *This);
      ULONG (WINAPI *Release)(ITransactionStatus *This);
      HRESULT (WINAPI *SetTransactionStatus)(ITransactionStatus *This,HRESULT hrStatus);
      HRESULT (WINAPI *GetTransactionStatus)(ITransactionStatus *This,HRESULT *pHrStatus);
    END_INTERFACE
  } ITransactionStatusVtbl;
  struct ITransactionStatus {
    CONST_VTBL struct ITransactionStatusVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionStatus_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionStatus_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionStatus_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionStatus_SetTransactionStatus(This,hrStatus) (This)->lpVtbl->SetTransactionStatus(This,hrStatus)
#define ITransactionStatus_GetTransactionStatus(This,pHrStatus) (This)->lpVtbl->GetTransactionStatus(This,pHrStatus)
#endif
#endif
  HRESULT WINAPI ITransactionStatus_SetTransactionStatus_Proxy(ITransactionStatus *This,HRESULT hrStatus);
  void __RPC_STUB ITransactionStatus_SetTransactionStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionStatus_GetTransactionStatus_Proxy(ITransactionStatus *This,HRESULT *pHrStatus);
  void __RPC_STUB ITransactionStatus_GetTransactionStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjectContextTip_INTERFACE_DEFINED__
#define __IObjectContextTip_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjectContextTip;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjectContextTip : public IUnknown {
  public:
    virtual HRESULT WINAPI GetTipUrl(BSTR *pTipUrl) = 0;
  };
#else
  typedef struct IObjectContextTipVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjectContextTip *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjectContextTip *This);
      ULONG (WINAPI *Release)(IObjectContextTip *This);
      HRESULT (WINAPI *GetTipUrl)(IObjectContextTip *This,BSTR *pTipUrl);
    END_INTERFACE
  } IObjectContextTipVtbl;
  struct IObjectContextTip {
    CONST_VTBL struct IObjectContextTipVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjectContextTip_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjectContextTip_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjectContextTip_Release(This) (This)->lpVtbl->Release(This)
#define IObjectContextTip_GetTipUrl(This,pTipUrl) (This)->lpVtbl->GetTipUrl(This,pTipUrl)
#endif
#endif
  HRESULT WINAPI IObjectContextTip_GetTipUrl_Proxy(IObjectContextTip *This,BSTR *pTipUrl);
  void __RPC_STUB IObjectContextTip_GetTipUrl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPlaybackControl_INTERFACE_DEFINED__
#define __IPlaybackControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPlaybackControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPlaybackControl : public IUnknown {
  public:
    virtual HRESULT WINAPI FinalClientRetry(void) = 0;
    virtual HRESULT WINAPI FinalServerRetry(void) = 0;
  };
#else
  typedef struct IPlaybackControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPlaybackControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPlaybackControl *This);
      ULONG (WINAPI *Release)(IPlaybackControl *This);
      HRESULT (WINAPI *FinalClientRetry)(IPlaybackControl *This);
      HRESULT (WINAPI *FinalServerRetry)(IPlaybackControl *This);
    END_INTERFACE
  } IPlaybackControlVtbl;
  struct IPlaybackControl {
    CONST_VTBL struct IPlaybackControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPlaybackControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPlaybackControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPlaybackControl_Release(This) (This)->lpVtbl->Release(This)
#define IPlaybackControl_FinalClientRetry(This) (This)->lpVtbl->FinalClientRetry(This)
#define IPlaybackControl_FinalServerRetry(This) (This)->lpVtbl->FinalServerRetry(This)
#endif
#endif
  HRESULT WINAPI IPlaybackControl_FinalClientRetry_Proxy(IPlaybackControl *This);
  void __RPC_STUB IPlaybackControl_FinalClientRetry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPlaybackControl_FinalServerRetry_Proxy(IPlaybackControl *This);
  void __RPC_STUB IPlaybackControl_FinalServerRetry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IGetContextProperties_INTERFACE_DEFINED__
#define __IGetContextProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IGetContextProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IGetContextProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI GetProperty(BSTR name,VARIANT *pProperty) = 0;
    virtual HRESULT WINAPI EnumNames(IEnumNames **ppenum) = 0;
  };
#else
  typedef struct IGetContextPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IGetContextProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IGetContextProperties *This);
      ULONG (WINAPI *Release)(IGetContextProperties *This);
      HRESULT (WINAPI *Count)(IGetContextProperties *This,__LONG32 *plCount);
      HRESULT (WINAPI *GetProperty)(IGetContextProperties *This,BSTR name,VARIANT *pProperty);
      HRESULT (WINAPI *EnumNames)(IGetContextProperties *This,IEnumNames **ppenum);
    END_INTERFACE
  } IGetContextPropertiesVtbl;
  struct IGetContextProperties {
    CONST_VTBL struct IGetContextPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IGetContextProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGetContextProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGetContextProperties_Release(This) (This)->lpVtbl->Release(This)
#define IGetContextProperties_Count(This,plCount) (This)->lpVtbl->Count(This,plCount)
#define IGetContextProperties_GetProperty(This,name,pProperty) (This)->lpVtbl->GetProperty(This,name,pProperty)
#define IGetContextProperties_EnumNames(This,ppenum) (This)->lpVtbl->EnumNames(This,ppenum)
#endif
#endif
  HRESULT WINAPI IGetContextProperties_Count_Proxy(IGetContextProperties *This,__LONG32 *plCount);
  void __RPC_STUB IGetContextProperties_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IGetContextProperties_GetProperty_Proxy(IGetContextProperties *This,BSTR name,VARIANT *pProperty);
  void __RPC_STUB IGetContextProperties_GetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IGetContextProperties_EnumNames_Proxy(IGetContextProperties *This,IEnumNames **ppenum);
  void __RPC_STUB IGetContextProperties_EnumNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum tagTransactionVote {
    TxCommit = 0,TxAbort = TxCommit + 1
  } TransactionVote;

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0367_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0367_v0_0_s_ifspec;

#ifndef __IContextState_INTERFACE_DEFINED__
#define __IContextState_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IContextState;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IContextState : public IUnknown {
  public:
    virtual HRESULT WINAPI SetDeactivateOnReturn(VARIANT_BOOL bDeactivate) = 0;
    virtual HRESULT WINAPI GetDeactivateOnReturn(VARIANT_BOOL *pbDeactivate) = 0;
    virtual HRESULT WINAPI SetMyTransactionVote(TransactionVote txVote) = 0;
    virtual HRESULT WINAPI GetMyTransactionVote(TransactionVote *ptxVote) = 0;
  };
#else
  typedef struct IContextStateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IContextState *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IContextState *This);
      ULONG (WINAPI *Release)(IContextState *This);
      HRESULT (WINAPI *SetDeactivateOnReturn)(IContextState *This,VARIANT_BOOL bDeactivate);
      HRESULT (WINAPI *GetDeactivateOnReturn)(IContextState *This,VARIANT_BOOL *pbDeactivate);
      HRESULT (WINAPI *SetMyTransactionVote)(IContextState *This,TransactionVote txVote);
      HRESULT (WINAPI *GetMyTransactionVote)(IContextState *This,TransactionVote *ptxVote);
    END_INTERFACE
  } IContextStateVtbl;
  struct IContextState {
    CONST_VTBL struct IContextStateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IContextState_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IContextState_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IContextState_Release(This) (This)->lpVtbl->Release(This)
#define IContextState_SetDeactivateOnReturn(This,bDeactivate) (This)->lpVtbl->SetDeactivateOnReturn(This,bDeactivate)
#define IContextState_GetDeactivateOnReturn(This,pbDeactivate) (This)->lpVtbl->GetDeactivateOnReturn(This,pbDeactivate)
#define IContextState_SetMyTransactionVote(This,txVote) (This)->lpVtbl->SetMyTransactionVote(This,txVote)
#define IContextState_GetMyTransactionVote(This,ptxVote) (This)->lpVtbl->GetMyTransactionVote(This,ptxVote)
#endif
#endif
  HRESULT WINAPI IContextState_SetDeactivateOnReturn_Proxy(IContextState *This,VARIANT_BOOL bDeactivate);
  void __RPC_STUB IContextState_SetDeactivateOnReturn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContextState_GetDeactivateOnReturn_Proxy(IContextState *This,VARIANT_BOOL *pbDeactivate);
  void __RPC_STUB IContextState_GetDeactivateOnReturn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContextState_SetMyTransactionVote_Proxy(IContextState *This,TransactionVote txVote);
  void __RPC_STUB IContextState_SetMyTransactionVote_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContextState_GetMyTransactionVote_Proxy(IContextState *This,TransactionVote *ptxVote);
  void __RPC_STUB IContextState_GetMyTransactionVote_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IPoolManager_INTERFACE_DEFINED__
#define __IPoolManager_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IPoolManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPoolManager : public IDispatch {
  public:
    virtual HRESULT WINAPI ShutdownPool(BSTR CLSIDOrProgID) = 0;
  };
#else
  typedef struct IPoolManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPoolManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPoolManager *This);
      ULONG (WINAPI *Release)(IPoolManager *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IPoolManager *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IPoolManager *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IPoolManager *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IPoolManager *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *ShutdownPool)(IPoolManager *This,BSTR CLSIDOrProgID);
    END_INTERFACE
  } IPoolManagerVtbl;
  struct IPoolManager {
    CONST_VTBL struct IPoolManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPoolManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPoolManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPoolManager_Release(This) (This)->lpVtbl->Release(This)
#define IPoolManager_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IPoolManager_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IPoolManager_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IPoolManager_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IPoolManager_ShutdownPool(This,CLSIDOrProgID) (This)->lpVtbl->ShutdownPool(This,CLSIDOrProgID)
#endif
#endif
  HRESULT WINAPI IPoolManager_ShutdownPool_Proxy(IPoolManager *This,BSTR CLSIDOrProgID);
  void __RPC_STUB IPoolManager_ShutdownPool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISelectCOMLBServer_INTERFACE_DEFINED__
#define __ISelectCOMLBServer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISelectCOMLBServer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISelectCOMLBServer : public IUnknown {
  public:
    virtual HRESULT WINAPI Init(void) = 0;
    virtual HRESULT WINAPI GetLBServer(IUnknown *pUnk) = 0;
  };
#else
  typedef struct ISelectCOMLBServerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISelectCOMLBServer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISelectCOMLBServer *This);
      ULONG (WINAPI *Release)(ISelectCOMLBServer *This);
      HRESULT (WINAPI *Init)(ISelectCOMLBServer *This);
      HRESULT (WINAPI *GetLBServer)(ISelectCOMLBServer *This,IUnknown *pUnk);
    END_INTERFACE
  } ISelectCOMLBServerVtbl;
  struct ISelectCOMLBServer {
    CONST_VTBL struct ISelectCOMLBServerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISelectCOMLBServer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISelectCOMLBServer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISelectCOMLBServer_Release(This) (This)->lpVtbl->Release(This)
#define ISelectCOMLBServer_Init(This) (This)->lpVtbl->Init(This)
#define ISelectCOMLBServer_GetLBServer(This,pUnk) (This)->lpVtbl->GetLBServer(This,pUnk)
#endif
#endif
  HRESULT WINAPI ISelectCOMLBServer_Init_Proxy(ISelectCOMLBServer *This);
  void __RPC_STUB ISelectCOMLBServer_Init_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISelectCOMLBServer_GetLBServer_Proxy(ISelectCOMLBServer *This,IUnknown *pUnk);
  void __RPC_STUB ISelectCOMLBServer_GetLBServer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICOMLBArguments_INTERFACE_DEFINED__
#define __ICOMLBArguments_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICOMLBArguments;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICOMLBArguments : public IUnknown {
  public:
    virtual HRESULT WINAPI GetCLSID(CLSID *pCLSID) = 0;
    virtual HRESULT WINAPI SetCLSID(CLSID *pCLSID) = 0;
    virtual HRESULT WINAPI GetMachineName(ULONG cchSvr,WCHAR szServerName[]) = 0;
    virtual HRESULT WINAPI SetMachineName(ULONG cchSvr,WCHAR szServerName[]) = 0;
  };
#else
  typedef struct ICOMLBArgumentsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICOMLBArguments *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICOMLBArguments *This);
      ULONG (WINAPI *Release)(ICOMLBArguments *This);
      HRESULT (WINAPI *GetCLSID)(ICOMLBArguments *This,CLSID *pCLSID);
      HRESULT (WINAPI *SetCLSID)(ICOMLBArguments *This,CLSID *pCLSID);
      HRESULT (WINAPI *GetMachineName)(ICOMLBArguments *This,ULONG cchSvr,WCHAR szServerName[]);
      HRESULT (WINAPI *SetMachineName)(ICOMLBArguments *This,ULONG cchSvr,WCHAR szServerName[]);
    END_INTERFACE
  } ICOMLBArgumentsVtbl;
  struct ICOMLBArguments {
    CONST_VTBL struct ICOMLBArgumentsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICOMLBArguments_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICOMLBArguments_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICOMLBArguments_Release(This) (This)->lpVtbl->Release(This)
#define ICOMLBArguments_GetCLSID(This,pCLSID) (This)->lpVtbl->GetCLSID(This,pCLSID)
#define ICOMLBArguments_SetCLSID(This,pCLSID) (This)->lpVtbl->SetCLSID(This,pCLSID)
#define ICOMLBArguments_GetMachineName(This,cchSvr,szServerName) (This)->lpVtbl->GetMachineName(This,cchSvr,szServerName)
#define ICOMLBArguments_SetMachineName(This,cchSvr,szServerName) (This)->lpVtbl->SetMachineName(This,cchSvr,szServerName)
#endif
#endif
  HRESULT WINAPI ICOMLBArguments_GetCLSID_Proxy(ICOMLBArguments *This,CLSID *pCLSID);
  void __RPC_STUB ICOMLBArguments_GetCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICOMLBArguments_SetCLSID_Proxy(ICOMLBArguments *This,CLSID *pCLSID);
  void __RPC_STUB ICOMLBArguments_SetCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICOMLBArguments_GetMachineName_Proxy(ICOMLBArguments *This,ULONG cchSvr,WCHAR szServerName[]);
  void __RPC_STUB ICOMLBArguments_GetMachineName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICOMLBArguments_SetMachineName_Proxy(ICOMLBArguments *This,ULONG cchSvr,WCHAR szServerName[]);
  void __RPC_STUB ICOMLBArguments_SetMachineName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define GetObjectContext(ppIOC) (CoGetObjectContext(IID_IObjectContext,(void **) (ppIOC))==S_OK ? S_OK : CONTEXT_E_NOCONTEXT)

  EXTERN_C HRESULT WINAPI CoCreateActivity(IUnknown *pIUnknown,REFIID riid,void **ppObj);
  EXTERN_C HRESULT WINAPI CoEnterServiceDomain(IUnknown *pConfigObject);
  EXTERN_C void WINAPI CoLeaveServiceDomain(IUnknown *pUnkStatus);
  EXTERN_C HRESULT WINAPI GetManagedExtensions(DWORD *dwExts);
  extern void *__cdecl SafeRef(REFIID rid,IUnknown *pUnk);
  extern HRESULT __cdecl RecycleSurrogate(__LONG32 lReasonCode);

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0371_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0371_v0_0_s_ifspec;

#ifndef __ICrmLogControl_INTERFACE_DEFINED__
#define __ICrmLogControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICrmLogControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICrmLogControl : public IUnknown {
  public:
    virtual HRESULT WINAPI get_TransactionUOW(BSTR *pVal) = 0;
    virtual HRESULT WINAPI RegisterCompensator(LPCWSTR lpcwstrProgIdCompensator,LPCWSTR lpcwstrDescription,LONG lCrmRegFlags) = 0;
    virtual HRESULT WINAPI WriteLogRecordVariants(VARIANT *pLogRecord) = 0;
    virtual HRESULT WINAPI ForceLog(void) = 0;
    virtual HRESULT WINAPI ForgetLogRecord(void) = 0;
    virtual HRESULT WINAPI ForceTransactionToAbort(void) = 0;
    virtual HRESULT WINAPI WriteLogRecord(BLOB rgBlob[],ULONG cBlob) = 0;
  };
#else
  typedef struct ICrmLogControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICrmLogControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICrmLogControl *This);
      ULONG (WINAPI *Release)(ICrmLogControl *This);
      HRESULT (WINAPI *get_TransactionUOW)(ICrmLogControl *This,BSTR *pVal);
      HRESULT (WINAPI *RegisterCompensator)(ICrmLogControl *This,LPCWSTR lpcwstrProgIdCompensator,LPCWSTR lpcwstrDescription,LONG lCrmRegFlags);
      HRESULT (WINAPI *WriteLogRecordVariants)(ICrmLogControl *This,VARIANT *pLogRecord);
      HRESULT (WINAPI *ForceLog)(ICrmLogControl *This);
      HRESULT (WINAPI *ForgetLogRecord)(ICrmLogControl *This);
      HRESULT (WINAPI *ForceTransactionToAbort)(ICrmLogControl *This);
      HRESULT (WINAPI *WriteLogRecord)(ICrmLogControl *This,BLOB rgBlob[],ULONG cBlob);
    END_INTERFACE
  } ICrmLogControlVtbl;
  struct ICrmLogControl {
    CONST_VTBL struct ICrmLogControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICrmLogControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICrmLogControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICrmLogControl_Release(This) (This)->lpVtbl->Release(This)
#define ICrmLogControl_get_TransactionUOW(This,pVal) (This)->lpVtbl->get_TransactionUOW(This,pVal)
#define ICrmLogControl_RegisterCompensator(This,lpcwstrProgIdCompensator,lpcwstrDescription,lCrmRegFlags) (This)->lpVtbl->RegisterCompensator(This,lpcwstrProgIdCompensator,lpcwstrDescription,lCrmRegFlags)
#define ICrmLogControl_WriteLogRecordVariants(This,pLogRecord) (This)->lpVtbl->WriteLogRecordVariants(This,pLogRecord)
#define ICrmLogControl_ForceLog(This) (This)->lpVtbl->ForceLog(This)
#define ICrmLogControl_ForgetLogRecord(This) (This)->lpVtbl->ForgetLogRecord(This)
#define ICrmLogControl_ForceTransactionToAbort(This) (This)->lpVtbl->ForceTransactionToAbort(This)
#define ICrmLogControl_WriteLogRecord(This,rgBlob,cBlob) (This)->lpVtbl->WriteLogRecord(This,rgBlob,cBlob)
#endif
#endif
  HRESULT WINAPI ICrmLogControl_get_TransactionUOW_Proxy(ICrmLogControl *This,BSTR *pVal);
  void __RPC_STUB ICrmLogControl_get_TransactionUOW_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmLogControl_RegisterCompensator_Proxy(ICrmLogControl *This,LPCWSTR lpcwstrProgIdCompensator,LPCWSTR lpcwstrDescription,LONG lCrmRegFlags);
  void __RPC_STUB ICrmLogControl_RegisterCompensator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmLogControl_WriteLogRecordVariants_Proxy(ICrmLogControl *This,VARIANT *pLogRecord);
  void __RPC_STUB ICrmLogControl_WriteLogRecordVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmLogControl_ForceLog_Proxy(ICrmLogControl *This);
  void __RPC_STUB ICrmLogControl_ForceLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmLogControl_ForgetLogRecord_Proxy(ICrmLogControl *This);
  void __RPC_STUB ICrmLogControl_ForgetLogRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmLogControl_ForceTransactionToAbort_Proxy(ICrmLogControl *This);
  void __RPC_STUB ICrmLogControl_ForceTransactionToAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmLogControl_WriteLogRecord_Proxy(ICrmLogControl *This,BLOB rgBlob[],ULONG cBlob);
  void __RPC_STUB ICrmLogControl_WriteLogRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICrmCompensatorVariants_INTERFACE_DEFINED__
#define __ICrmCompensatorVariants_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICrmCompensatorVariants;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICrmCompensatorVariants : public IUnknown {
  public:
    virtual HRESULT WINAPI SetLogControlVariants(ICrmLogControl *pLogControl) = 0;
    virtual HRESULT WINAPI BeginPrepareVariants(void) = 0;
    virtual HRESULT WINAPI PrepareRecordVariants(VARIANT *pLogRecord,VARIANT_BOOL *pbForget) = 0;
    virtual HRESULT WINAPI EndPrepareVariants(VARIANT_BOOL *pbOkToPrepare) = 0;
    virtual HRESULT WINAPI BeginCommitVariants(VARIANT_BOOL bRecovery) = 0;
    virtual HRESULT WINAPI CommitRecordVariants(VARIANT *pLogRecord,VARIANT_BOOL *pbForget) = 0;
    virtual HRESULT WINAPI EndCommitVariants(void) = 0;
    virtual HRESULT WINAPI BeginAbortVariants(VARIANT_BOOL bRecovery) = 0;
    virtual HRESULT WINAPI AbortRecordVariants(VARIANT *pLogRecord,VARIANT_BOOL *pbForget) = 0;
    virtual HRESULT WINAPI EndAbortVariants(void) = 0;
  };
#else
  typedef struct ICrmCompensatorVariantsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICrmCompensatorVariants *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICrmCompensatorVariants *This);
      ULONG (WINAPI *Release)(ICrmCompensatorVariants *This);
      HRESULT (WINAPI *SetLogControlVariants)(ICrmCompensatorVariants *This,ICrmLogControl *pLogControl);
      HRESULT (WINAPI *BeginPrepareVariants)(ICrmCompensatorVariants *This);
      HRESULT (WINAPI *PrepareRecordVariants)(ICrmCompensatorVariants *This,VARIANT *pLogRecord,VARIANT_BOOL *pbForget);
      HRESULT (WINAPI *EndPrepareVariants)(ICrmCompensatorVariants *This,VARIANT_BOOL *pbOkToPrepare);
      HRESULT (WINAPI *BeginCommitVariants)(ICrmCompensatorVariants *This,VARIANT_BOOL bRecovery);
      HRESULT (WINAPI *CommitRecordVariants)(ICrmCompensatorVariants *This,VARIANT *pLogRecord,VARIANT_BOOL *pbForget);
      HRESULT (WINAPI *EndCommitVariants)(ICrmCompensatorVariants *This);
      HRESULT (WINAPI *BeginAbortVariants)(ICrmCompensatorVariants *This,VARIANT_BOOL bRecovery);
      HRESULT (WINAPI *AbortRecordVariants)(ICrmCompensatorVariants *This,VARIANT *pLogRecord,VARIANT_BOOL *pbForget);
      HRESULT (WINAPI *EndAbortVariants)(ICrmCompensatorVariants *This);
    END_INTERFACE
  } ICrmCompensatorVariantsVtbl;
  struct ICrmCompensatorVariants {
    CONST_VTBL struct ICrmCompensatorVariantsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICrmCompensatorVariants_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICrmCompensatorVariants_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICrmCompensatorVariants_Release(This) (This)->lpVtbl->Release(This)
#define ICrmCompensatorVariants_SetLogControlVariants(This,pLogControl) (This)->lpVtbl->SetLogControlVariants(This,pLogControl)
#define ICrmCompensatorVariants_BeginPrepareVariants(This) (This)->lpVtbl->BeginPrepareVariants(This)
#define ICrmCompensatorVariants_PrepareRecordVariants(This,pLogRecord,pbForget) (This)->lpVtbl->PrepareRecordVariants(This,pLogRecord,pbForget)
#define ICrmCompensatorVariants_EndPrepareVariants(This,pbOkToPrepare) (This)->lpVtbl->EndPrepareVariants(This,pbOkToPrepare)
#define ICrmCompensatorVariants_BeginCommitVariants(This,bRecovery) (This)->lpVtbl->BeginCommitVariants(This,bRecovery)
#define ICrmCompensatorVariants_CommitRecordVariants(This,pLogRecord,pbForget) (This)->lpVtbl->CommitRecordVariants(This,pLogRecord,pbForget)
#define ICrmCompensatorVariants_EndCommitVariants(This) (This)->lpVtbl->EndCommitVariants(This)
#define ICrmCompensatorVariants_BeginAbortVariants(This,bRecovery) (This)->lpVtbl->BeginAbortVariants(This,bRecovery)
#define ICrmCompensatorVariants_AbortRecordVariants(This,pLogRecord,pbForget) (This)->lpVtbl->AbortRecordVariants(This,pLogRecord,pbForget)
#define ICrmCompensatorVariants_EndAbortVariants(This) (This)->lpVtbl->EndAbortVariants(This)
#endif
#endif
  HRESULT WINAPI ICrmCompensatorVariants_SetLogControlVariants_Proxy(ICrmCompensatorVariants *This,ICrmLogControl *pLogControl);
  void __RPC_STUB ICrmCompensatorVariants_SetLogControlVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_BeginPrepareVariants_Proxy(ICrmCompensatorVariants *This);
  void __RPC_STUB ICrmCompensatorVariants_BeginPrepareVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_PrepareRecordVariants_Proxy(ICrmCompensatorVariants *This,VARIANT *pLogRecord,VARIANT_BOOL *pbForget);
  void __RPC_STUB ICrmCompensatorVariants_PrepareRecordVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_EndPrepareVariants_Proxy(ICrmCompensatorVariants *This,VARIANT_BOOL *pbOkToPrepare);
  void __RPC_STUB ICrmCompensatorVariants_EndPrepareVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_BeginCommitVariants_Proxy(ICrmCompensatorVariants *This,VARIANT_BOOL bRecovery);
  void __RPC_STUB ICrmCompensatorVariants_BeginCommitVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_CommitRecordVariants_Proxy(ICrmCompensatorVariants *This,VARIANT *pLogRecord,VARIANT_BOOL *pbForget);
  void __RPC_STUB ICrmCompensatorVariants_CommitRecordVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_EndCommitVariants_Proxy(ICrmCompensatorVariants *This);
  void __RPC_STUB ICrmCompensatorVariants_EndCommitVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_BeginAbortVariants_Proxy(ICrmCompensatorVariants *This,VARIANT_BOOL bRecovery);
  void __RPC_STUB ICrmCompensatorVariants_BeginAbortVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_AbortRecordVariants_Proxy(ICrmCompensatorVariants *This,VARIANT *pLogRecord,VARIANT_BOOL *pbForget);
  void __RPC_STUB ICrmCompensatorVariants_AbortRecordVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensatorVariants_EndAbortVariants_Proxy(ICrmCompensatorVariants *This);
  void __RPC_STUB ICrmCompensatorVariants_EndAbortVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef _tagCrmLogRecordRead_
#define _tagCrmLogRecordRead_
  typedef struct tagCrmLogRecordRead {
    DWORD dwCrmFlags;
    DWORD dwSequenceNumber;
    BLOB blobUserData;
  } CrmLogRecordRead;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0373_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0373_v0_0_s_ifspec;

#ifndef __ICrmCompensator_INTERFACE_DEFINED__
#define __ICrmCompensator_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICrmCompensator;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICrmCompensator : public IUnknown {
  public:
    virtual HRESULT WINAPI SetLogControl(ICrmLogControl *pLogControl) = 0;
    virtual HRESULT WINAPI BeginPrepare(void) = 0;
    virtual HRESULT WINAPI PrepareRecord(CrmLogRecordRead crmLogRec,WINBOOL *pfForget) = 0;
    virtual HRESULT WINAPI EndPrepare(WINBOOL *pfOkToPrepare) = 0;
    virtual HRESULT WINAPI BeginCommit(WINBOOL fRecovery) = 0;
    virtual HRESULT WINAPI CommitRecord(CrmLogRecordRead crmLogRec,WINBOOL *pfForget) = 0;
    virtual HRESULT WINAPI EndCommit(void) = 0;
    virtual HRESULT WINAPI BeginAbort(WINBOOL fRecovery) = 0;
    virtual HRESULT WINAPI AbortRecord(CrmLogRecordRead crmLogRec,WINBOOL *pfForget) = 0;
    virtual HRESULT WINAPI EndAbort(void) = 0;
  };
#else
  typedef struct ICrmCompensatorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICrmCompensator *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICrmCompensator *This);
      ULONG (WINAPI *Release)(ICrmCompensator *This);
      HRESULT (WINAPI *SetLogControl)(ICrmCompensator *This,ICrmLogControl *pLogControl);
      HRESULT (WINAPI *BeginPrepare)(ICrmCompensator *This);
      HRESULT (WINAPI *PrepareRecord)(ICrmCompensator *This,CrmLogRecordRead crmLogRec,WINBOOL *pfForget);
      HRESULT (WINAPI *EndPrepare)(ICrmCompensator *This,WINBOOL *pfOkToPrepare);
      HRESULT (WINAPI *BeginCommit)(ICrmCompensator *This,WINBOOL fRecovery);
      HRESULT (WINAPI *CommitRecord)(ICrmCompensator *This,CrmLogRecordRead crmLogRec,WINBOOL *pfForget);
      HRESULT (WINAPI *EndCommit)(ICrmCompensator *This);
      HRESULT (WINAPI *BeginAbort)(ICrmCompensator *This,WINBOOL fRecovery);
      HRESULT (WINAPI *AbortRecord)(ICrmCompensator *This,CrmLogRecordRead crmLogRec,WINBOOL *pfForget);
      HRESULT (WINAPI *EndAbort)(ICrmCompensator *This);
    END_INTERFACE
  } ICrmCompensatorVtbl;
  struct ICrmCompensator {
    CONST_VTBL struct ICrmCompensatorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICrmCompensator_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICrmCompensator_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICrmCompensator_Release(This) (This)->lpVtbl->Release(This)
#define ICrmCompensator_SetLogControl(This,pLogControl) (This)->lpVtbl->SetLogControl(This,pLogControl)
#define ICrmCompensator_BeginPrepare(This) (This)->lpVtbl->BeginPrepare(This)
#define ICrmCompensator_PrepareRecord(This,crmLogRec,pfForget) (This)->lpVtbl->PrepareRecord(This,crmLogRec,pfForget)
#define ICrmCompensator_EndPrepare(This,pfOkToPrepare) (This)->lpVtbl->EndPrepare(This,pfOkToPrepare)
#define ICrmCompensator_BeginCommit(This,fRecovery) (This)->lpVtbl->BeginCommit(This,fRecovery)
#define ICrmCompensator_CommitRecord(This,crmLogRec,pfForget) (This)->lpVtbl->CommitRecord(This,crmLogRec,pfForget)
#define ICrmCompensator_EndCommit(This) (This)->lpVtbl->EndCommit(This)
#define ICrmCompensator_BeginAbort(This,fRecovery) (This)->lpVtbl->BeginAbort(This,fRecovery)
#define ICrmCompensator_AbortRecord(This,crmLogRec,pfForget) (This)->lpVtbl->AbortRecord(This,crmLogRec,pfForget)
#define ICrmCompensator_EndAbort(This) (This)->lpVtbl->EndAbort(This)
#endif
#endif
  HRESULT WINAPI ICrmCompensator_SetLogControl_Proxy(ICrmCompensator *This,ICrmLogControl *pLogControl);
  void __RPC_STUB ICrmCompensator_SetLogControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_BeginPrepare_Proxy(ICrmCompensator *This);
  void __RPC_STUB ICrmCompensator_BeginPrepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_PrepareRecord_Proxy(ICrmCompensator *This,CrmLogRecordRead crmLogRec,WINBOOL *pfForget);
  void __RPC_STUB ICrmCompensator_PrepareRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_EndPrepare_Proxy(ICrmCompensator *This,WINBOOL *pfOkToPrepare);
  void __RPC_STUB ICrmCompensator_EndPrepare_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_BeginCommit_Proxy(ICrmCompensator *This,WINBOOL fRecovery);
  void __RPC_STUB ICrmCompensator_BeginCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_CommitRecord_Proxy(ICrmCompensator *This,CrmLogRecordRead crmLogRec,WINBOOL *pfForget);
  void __RPC_STUB ICrmCompensator_CommitRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_EndCommit_Proxy(ICrmCompensator *This);
  void __RPC_STUB ICrmCompensator_EndCommit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_BeginAbort_Proxy(ICrmCompensator *This,WINBOOL fRecovery);
  void __RPC_STUB ICrmCompensator_BeginAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_AbortRecord_Proxy(ICrmCompensator *This,CrmLogRecordRead crmLogRec,WINBOOL *pfForget);
  void __RPC_STUB ICrmCompensator_AbortRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmCompensator_EndAbort_Proxy(ICrmCompensator *This);
  void __RPC_STUB ICrmCompensator_EndAbort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef _tagCrmTransactionState_
#define _tagCrmTransactionState_
  typedef enum tagCrmTransactionState {
    TxState_Active = 0,TxState_Committed,TxState_Aborted,TxState_Indoubt
  } CrmTransactionState;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0374_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0374_v0_0_s_ifspec;

#ifndef __ICrmMonitorLogRecords_INTERFACE_DEFINED__
#define __ICrmMonitorLogRecords_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICrmMonitorLogRecords;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICrmMonitorLogRecords : public IUnknown {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI get_TransactionState(CrmTransactionState *pVal) = 0;
    virtual HRESULT WINAPI get_StructuredRecords(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI GetLogRecord(DWORD dwIndex,CrmLogRecordRead *pCrmLogRec) = 0;
    virtual HRESULT WINAPI GetLogRecordVariants(VARIANT IndexNumber,LPVARIANT pLogRecord) = 0;
  };
#else
  typedef struct ICrmMonitorLogRecordsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICrmMonitorLogRecords *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICrmMonitorLogRecords *This);
      ULONG (WINAPI *Release)(ICrmMonitorLogRecords *This);
      HRESULT (WINAPI *get_Count)(ICrmMonitorLogRecords *This,__LONG32 *pVal);
      HRESULT (WINAPI *get_TransactionState)(ICrmMonitorLogRecords *This,CrmTransactionState *pVal);
      HRESULT (WINAPI *get_StructuredRecords)(ICrmMonitorLogRecords *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *GetLogRecord)(ICrmMonitorLogRecords *This,DWORD dwIndex,CrmLogRecordRead *pCrmLogRec);
      HRESULT (WINAPI *GetLogRecordVariants)(ICrmMonitorLogRecords *This,VARIANT IndexNumber,LPVARIANT pLogRecord);
    END_INTERFACE
  } ICrmMonitorLogRecordsVtbl;
  struct ICrmMonitorLogRecords {
    CONST_VTBL struct ICrmMonitorLogRecordsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICrmMonitorLogRecords_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICrmMonitorLogRecords_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICrmMonitorLogRecords_Release(This) (This)->lpVtbl->Release(This)
#define ICrmMonitorLogRecords_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#define ICrmMonitorLogRecords_get_TransactionState(This,pVal) (This)->lpVtbl->get_TransactionState(This,pVal)
#define ICrmMonitorLogRecords_get_StructuredRecords(This,pVal) (This)->lpVtbl->get_StructuredRecords(This,pVal)
#define ICrmMonitorLogRecords_GetLogRecord(This,dwIndex,pCrmLogRec) (This)->lpVtbl->GetLogRecord(This,dwIndex,pCrmLogRec)
#define ICrmMonitorLogRecords_GetLogRecordVariants(This,IndexNumber,pLogRecord) (This)->lpVtbl->GetLogRecordVariants(This,IndexNumber,pLogRecord)
#endif
#endif
  HRESULT WINAPI ICrmMonitorLogRecords_get_Count_Proxy(ICrmMonitorLogRecords *This,__LONG32 *pVal);
  void __RPC_STUB ICrmMonitorLogRecords_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorLogRecords_get_TransactionState_Proxy(ICrmMonitorLogRecords *This,CrmTransactionState *pVal);
  void __RPC_STUB ICrmMonitorLogRecords_get_TransactionState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorLogRecords_get_StructuredRecords_Proxy(ICrmMonitorLogRecords *This,VARIANT_BOOL *pVal);
  void __RPC_STUB ICrmMonitorLogRecords_get_StructuredRecords_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorLogRecords_GetLogRecord_Proxy(ICrmMonitorLogRecords *This,DWORD dwIndex,CrmLogRecordRead *pCrmLogRec);
  void __RPC_STUB ICrmMonitorLogRecords_GetLogRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorLogRecords_GetLogRecordVariants_Proxy(ICrmMonitorLogRecords *This,VARIANT IndexNumber,LPVARIANT pLogRecord);
  void __RPC_STUB ICrmMonitorLogRecords_GetLogRecordVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICrmMonitorClerks_INTERFACE_DEFINED__
#define __ICrmMonitorClerks_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICrmMonitorClerks;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICrmMonitorClerks : public IDispatch {
  public:
    virtual HRESULT WINAPI Item(VARIANT Index,LPVARIANT pItem) = 0;
    virtual HRESULT WINAPI get__NewEnum(LPUNKNOWN *pVal) = 0;
    virtual HRESULT WINAPI get_Count(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI ProgIdCompensator(VARIANT Index,LPVARIANT pItem) = 0;
    virtual HRESULT WINAPI Description(VARIANT Index,LPVARIANT pItem) = 0;
    virtual HRESULT WINAPI TransactionUOW(VARIANT Index,LPVARIANT pItem) = 0;
    virtual HRESULT WINAPI ActivityId(VARIANT Index,LPVARIANT pItem) = 0;
  };
#else
  typedef struct ICrmMonitorClerksVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICrmMonitorClerks *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICrmMonitorClerks *This);
      ULONG (WINAPI *Release)(ICrmMonitorClerks *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICrmMonitorClerks *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICrmMonitorClerks *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICrmMonitorClerks *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICrmMonitorClerks *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Item)(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
      HRESULT (WINAPI *get__NewEnum)(ICrmMonitorClerks *This,LPUNKNOWN *pVal);
      HRESULT (WINAPI *get_Count)(ICrmMonitorClerks *This,__LONG32 *pVal);
      HRESULT (WINAPI *ProgIdCompensator)(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
      HRESULT (WINAPI *Description)(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
      HRESULT (WINAPI *TransactionUOW)(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
      HRESULT (WINAPI *ActivityId)(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
    END_INTERFACE
  } ICrmMonitorClerksVtbl;
  struct ICrmMonitorClerks {
    CONST_VTBL struct ICrmMonitorClerksVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICrmMonitorClerks_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICrmMonitorClerks_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICrmMonitorClerks_Release(This) (This)->lpVtbl->Release(This)
#define ICrmMonitorClerks_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICrmMonitorClerks_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICrmMonitorClerks_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICrmMonitorClerks_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICrmMonitorClerks_Item(This,Index,pItem) (This)->lpVtbl->Item(This,Index,pItem)
#define ICrmMonitorClerks_get__NewEnum(This,pVal) (This)->lpVtbl->get__NewEnum(This,pVal)
#define ICrmMonitorClerks_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#define ICrmMonitorClerks_ProgIdCompensator(This,Index,pItem) (This)->lpVtbl->ProgIdCompensator(This,Index,pItem)
#define ICrmMonitorClerks_Description(This,Index,pItem) (This)->lpVtbl->Description(This,Index,pItem)
#define ICrmMonitorClerks_TransactionUOW(This,Index,pItem) (This)->lpVtbl->TransactionUOW(This,Index,pItem)
#define ICrmMonitorClerks_ActivityId(This,Index,pItem) (This)->lpVtbl->ActivityId(This,Index,pItem)
#endif
#endif
  HRESULT WINAPI ICrmMonitorClerks_Item_Proxy(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
  void __RPC_STUB ICrmMonitorClerks_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorClerks_get__NewEnum_Proxy(ICrmMonitorClerks *This,LPUNKNOWN *pVal);
  void __RPC_STUB ICrmMonitorClerks_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorClerks_get_Count_Proxy(ICrmMonitorClerks *This,__LONG32 *pVal);
  void __RPC_STUB ICrmMonitorClerks_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorClerks_ProgIdCompensator_Proxy(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
  void __RPC_STUB ICrmMonitorClerks_ProgIdCompensator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorClerks_Description_Proxy(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
  void __RPC_STUB ICrmMonitorClerks_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorClerks_TransactionUOW_Proxy(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
  void __RPC_STUB ICrmMonitorClerks_TransactionUOW_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitorClerks_ActivityId_Proxy(ICrmMonitorClerks *This,VARIANT Index,LPVARIANT pItem);
  void __RPC_STUB ICrmMonitorClerks_ActivityId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICrmMonitor_INTERFACE_DEFINED__
#define __ICrmMonitor_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICrmMonitor;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICrmMonitor : public IUnknown {
  public:
    virtual HRESULT WINAPI GetClerks(ICrmMonitorClerks **pClerks) = 0;
    virtual HRESULT WINAPI HoldClerk(VARIANT Index,LPVARIANT pItem) = 0;
  };
#else
  typedef struct ICrmMonitorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICrmMonitor *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICrmMonitor *This);
      ULONG (WINAPI *Release)(ICrmMonitor *This);
      HRESULT (WINAPI *GetClerks)(ICrmMonitor *This,ICrmMonitorClerks **pClerks);
      HRESULT (WINAPI *HoldClerk)(ICrmMonitor *This,VARIANT Index,LPVARIANT pItem);
    END_INTERFACE
  } ICrmMonitorVtbl;
  struct ICrmMonitor {
    CONST_VTBL struct ICrmMonitorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICrmMonitor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICrmMonitor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICrmMonitor_Release(This) (This)->lpVtbl->Release(This)
#define ICrmMonitor_GetClerks(This,pClerks) (This)->lpVtbl->GetClerks(This,pClerks)
#define ICrmMonitor_HoldClerk(This,Index,pItem) (This)->lpVtbl->HoldClerk(This,Index,pItem)
#endif
#endif
  HRESULT WINAPI ICrmMonitor_GetClerks_Proxy(ICrmMonitor *This,ICrmMonitorClerks **pClerks);
  void __RPC_STUB ICrmMonitor_GetClerks_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmMonitor_HoldClerk_Proxy(ICrmMonitor *This,VARIANT Index,LPVARIANT pItem);
  void __RPC_STUB ICrmMonitor_HoldClerk_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICrmFormatLogRecords_INTERFACE_DEFINED__
#define __ICrmFormatLogRecords_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICrmFormatLogRecords;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICrmFormatLogRecords : public IUnknown {
  public:
    virtual HRESULT WINAPI GetColumnCount(__LONG32 *plColumnCount) = 0;
    virtual HRESULT WINAPI GetColumnHeaders(LPVARIANT pHeaders) = 0;
    virtual HRESULT WINAPI GetColumn(CrmLogRecordRead CrmLogRec,LPVARIANT pFormattedLogRecord) = 0;
    virtual HRESULT WINAPI GetColumnVariants(VARIANT LogRecord,LPVARIANT pFormattedLogRecord) = 0;
  };
#else
  typedef struct ICrmFormatLogRecordsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICrmFormatLogRecords *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICrmFormatLogRecords *This);
      ULONG (WINAPI *Release)(ICrmFormatLogRecords *This);
      HRESULT (WINAPI *GetColumnCount)(ICrmFormatLogRecords *This,__LONG32 *plColumnCount);
      HRESULT (WINAPI *GetColumnHeaders)(ICrmFormatLogRecords *This,LPVARIANT pHeaders);
      HRESULT (WINAPI *GetColumn)(ICrmFormatLogRecords *This,CrmLogRecordRead CrmLogRec,LPVARIANT pFormattedLogRecord);
      HRESULT (WINAPI *GetColumnVariants)(ICrmFormatLogRecords *This,VARIANT LogRecord,LPVARIANT pFormattedLogRecord);
    END_INTERFACE
  } ICrmFormatLogRecordsVtbl;
  struct ICrmFormatLogRecords {
    CONST_VTBL struct ICrmFormatLogRecordsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICrmFormatLogRecords_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICrmFormatLogRecords_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICrmFormatLogRecords_Release(This) (This)->lpVtbl->Release(This)
#define ICrmFormatLogRecords_GetColumnCount(This,plColumnCount) (This)->lpVtbl->GetColumnCount(This,plColumnCount)
#define ICrmFormatLogRecords_GetColumnHeaders(This,pHeaders) (This)->lpVtbl->GetColumnHeaders(This,pHeaders)
#define ICrmFormatLogRecords_GetColumn(This,CrmLogRec,pFormattedLogRecord) (This)->lpVtbl->GetColumn(This,CrmLogRec,pFormattedLogRecord)
#define ICrmFormatLogRecords_GetColumnVariants(This,LogRecord,pFormattedLogRecord) (This)->lpVtbl->GetColumnVariants(This,LogRecord,pFormattedLogRecord)
#endif
#endif
  HRESULT WINAPI ICrmFormatLogRecords_GetColumnCount_Proxy(ICrmFormatLogRecords *This,__LONG32 *plColumnCount);
  void __RPC_STUB ICrmFormatLogRecords_GetColumnCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmFormatLogRecords_GetColumnHeaders_Proxy(ICrmFormatLogRecords *This,LPVARIANT pHeaders);
  void __RPC_STUB ICrmFormatLogRecords_GetColumnHeaders_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmFormatLogRecords_GetColumn_Proxy(ICrmFormatLogRecords *This,CrmLogRecordRead CrmLogRec,LPVARIANT pFormattedLogRecord);
  void __RPC_STUB ICrmFormatLogRecords_GetColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICrmFormatLogRecords_GetColumnVariants_Proxy(ICrmFormatLogRecords *This,VARIANT LogRecord,LPVARIANT pFormattedLogRecord);
  void __RPC_STUB ICrmFormatLogRecords_GetColumnVariants_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum tagCSC_InheritanceConfig {
    CSC_Inherit = 0,CSC_Ignore = CSC_Inherit + 1
  } CSC_InheritanceConfig;

  typedef enum tagCSC_ThreadPool {
    CSC_ThreadPoolNone = 0,CSC_ThreadPoolInherit,CSC_STAThreadPool,
    CSC_MTAThreadPool
  } CSC_ThreadPool;

  typedef enum tagCSC_Binding {
    CSC_NoBinding = 0,CSC_BindToPoolThread = CSC_NoBinding + 1
  } CSC_Binding;

  typedef enum tagCSC_TransactionConfig {
    CSC_NoTransaction = 0,CSC_IfContainerIsTransactional,CSC_CreateTransactionIfNecessary,
    CSC_NewTransaction
  } CSC_TransactionConfig;

  typedef enum tagCSC_SynchronizationConfig {
    CSC_NoSynchronization = 0,CSC_IfContainerIsSynchronized,
    CSC_NewSynchronizationIfNecessary,CSC_NewSynchronization
  } CSC_SynchronizationConfig;

  typedef enum tagCSC_TrackerConfig {
    CSC_DontUseTracker = 0,CSC_UseTracker = CSC_DontUseTracker + 1
  } CSC_TrackerConfig;

  typedef enum tagCSC_PartitionConfig {
    CSC_NoPartition = 0,CSC_InheritPartition,CSC_NewPartition
  } CSC_PartitionConfig;

  typedef enum tagCSC_IISIntrinsicsConfig {
    CSC_NoIISIntrinsics = 0,CSC_InheritIISIntrinsics = CSC_NoIISIntrinsics + 1
  } CSC_IISIntrinsicsConfig;

  typedef enum tagCSC_COMTIIntrinsicsConfig {
    CSC_NoCOMTIIntrinsics = 0,CSC_InheritCOMTIIntrinsics = CSC_NoCOMTIIntrinsics + 1
  } CSC_COMTIIntrinsicsConfig;

  typedef enum tagCSC_SxsConfig {
    CSC_NoSxs = 0,CSC_InheritSxs,CSC_NewSxs
  } CSC_SxsConfig;

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0378_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0378_v0_0_s_ifspec;

#ifndef __IServiceIISIntrinsicsConfig_INTERFACE_DEFINED__
#define __IServiceIISIntrinsicsConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceIISIntrinsicsConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceIISIntrinsicsConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI IISIntrinsicsConfig(CSC_IISIntrinsicsConfig iisIntrinsicsConfig) = 0;
  };
#else
  typedef struct IServiceIISIntrinsicsConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceIISIntrinsicsConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceIISIntrinsicsConfig *This);
      ULONG (WINAPI *Release)(IServiceIISIntrinsicsConfig *This);
      HRESULT (WINAPI *IISIntrinsicsConfig)(IServiceIISIntrinsicsConfig *This,CSC_IISIntrinsicsConfig iisIntrinsicsConfig);
    END_INTERFACE
  } IServiceIISIntrinsicsConfigVtbl;
  struct IServiceIISIntrinsicsConfig {
    CONST_VTBL struct IServiceIISIntrinsicsConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceIISIntrinsicsConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceIISIntrinsicsConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceIISIntrinsicsConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServiceIISIntrinsicsConfig_IISIntrinsicsConfig(This,iisIntrinsicsConfig) (This)->lpVtbl->IISIntrinsicsConfig(This,iisIntrinsicsConfig)
#endif
#endif
  HRESULT WINAPI IServiceIISIntrinsicsConfig_IISIntrinsicsConfig_Proxy(IServiceIISIntrinsicsConfig *This,CSC_IISIntrinsicsConfig iisIntrinsicsConfig);
  void __RPC_STUB IServiceIISIntrinsicsConfig_IISIntrinsicsConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceComTIIntrinsicsConfig_INTERFACE_DEFINED__
#define __IServiceComTIIntrinsicsConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceComTIIntrinsicsConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceComTIIntrinsicsConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI ComTIIntrinsicsConfig(CSC_COMTIIntrinsicsConfig comtiIntrinsicsConfig) = 0;
  };
#else
  typedef struct IServiceComTIIntrinsicsConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceComTIIntrinsicsConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceComTIIntrinsicsConfig *This);
      ULONG (WINAPI *Release)(IServiceComTIIntrinsicsConfig *This);
      HRESULT (WINAPI *ComTIIntrinsicsConfig)(IServiceComTIIntrinsicsConfig *This,CSC_COMTIIntrinsicsConfig comtiIntrinsicsConfig);
    END_INTERFACE
  } IServiceComTIIntrinsicsConfigVtbl;
  struct IServiceComTIIntrinsicsConfig {
    CONST_VTBL struct IServiceComTIIntrinsicsConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceComTIIntrinsicsConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceComTIIntrinsicsConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceComTIIntrinsicsConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServiceComTIIntrinsicsConfig_ComTIIntrinsicsConfig(This,comtiIntrinsicsConfig) (This)->lpVtbl->ComTIIntrinsicsConfig(This,comtiIntrinsicsConfig)
#endif
#endif
  HRESULT WINAPI IServiceComTIIntrinsicsConfig_ComTIIntrinsicsConfig_Proxy(IServiceComTIIntrinsicsConfig *This,CSC_COMTIIntrinsicsConfig comtiIntrinsicsConfig);
  void __RPC_STUB IServiceComTIIntrinsicsConfig_ComTIIntrinsicsConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceSxsConfig_INTERFACE_DEFINED__
#define __IServiceSxsConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceSxsConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceSxsConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI SxsConfig(CSC_SxsConfig scsConfig) = 0;
    virtual HRESULT WINAPI SxsName(LPCWSTR szSxsName) = 0;
    virtual HRESULT WINAPI SxsDirectory(LPCWSTR szSxsDirectory) = 0;
  };
#else
  typedef struct IServiceSxsConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceSxsConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceSxsConfig *This);
      ULONG (WINAPI *Release)(IServiceSxsConfig *This);
      HRESULT (WINAPI *SxsConfig)(IServiceSxsConfig *This,CSC_SxsConfig scsConfig);
      HRESULT (WINAPI *SxsName)(IServiceSxsConfig *This,LPCWSTR szSxsName);
      HRESULT (WINAPI *SxsDirectory)(IServiceSxsConfig *This,LPCWSTR szSxsDirectory);
    END_INTERFACE
  } IServiceSxsConfigVtbl;
  struct IServiceSxsConfig {
    CONST_VTBL struct IServiceSxsConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceSxsConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceSxsConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceSxsConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServiceSxsConfig_SxsConfig(This,scsConfig) (This)->lpVtbl->SxsConfig(This,scsConfig)
#define IServiceSxsConfig_SxsName(This,szSxsName) (This)->lpVtbl->SxsName(This,szSxsName)
#define IServiceSxsConfig_SxsDirectory(This,szSxsDirectory) (This)->lpVtbl->SxsDirectory(This,szSxsDirectory)
#endif
#endif
  HRESULT WINAPI IServiceSxsConfig_SxsConfig_Proxy(IServiceSxsConfig *This,CSC_SxsConfig scsConfig);
  void __RPC_STUB IServiceSxsConfig_SxsConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceSxsConfig_SxsName_Proxy(IServiceSxsConfig *This,LPCWSTR szSxsName);
  void __RPC_STUB IServiceSxsConfig_SxsName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceSxsConfig_SxsDirectory_Proxy(IServiceSxsConfig *This,LPCWSTR szSxsDirectory);
  void __RPC_STUB IServiceSxsConfig_SxsDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICheckSxsConfig_INTERFACE_DEFINED__
#define __ICheckSxsConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICheckSxsConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICheckSxsConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI IsSameSxsConfig(LPCWSTR wszSxsName,LPCWSTR wszSxsDirectory,LPCWSTR wszSxsAppName) = 0;
  };
#else
  typedef struct ICheckSxsConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICheckSxsConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICheckSxsConfig *This);
      ULONG (WINAPI *Release)(ICheckSxsConfig *This);
      HRESULT (WINAPI *IsSameSxsConfig)(ICheckSxsConfig *This,LPCWSTR wszSxsName,LPCWSTR wszSxsDirectory,LPCWSTR wszSxsAppName);
    END_INTERFACE
  } ICheckSxsConfigVtbl;
  struct ICheckSxsConfig {
    CONST_VTBL struct ICheckSxsConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICheckSxsConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICheckSxsConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICheckSxsConfig_Release(This) (This)->lpVtbl->Release(This)
#define ICheckSxsConfig_IsSameSxsConfig(This,wszSxsName,wszSxsDirectory,wszSxsAppName) (This)->lpVtbl->IsSameSxsConfig(This,wszSxsName,wszSxsDirectory,wszSxsAppName)
#endif
#endif
  HRESULT WINAPI ICheckSxsConfig_IsSameSxsConfig_Proxy(ICheckSxsConfig *This,LPCWSTR wszSxsName,LPCWSTR wszSxsDirectory,LPCWSTR wszSxsAppName);
  void __RPC_STUB ICheckSxsConfig_IsSameSxsConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceInheritanceConfig_INTERFACE_DEFINED__
#define __IServiceInheritanceConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceInheritanceConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceInheritanceConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI ContainingContextTreatment(CSC_InheritanceConfig inheritanceConfig) = 0;
  };
#else
  typedef struct IServiceInheritanceConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceInheritanceConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceInheritanceConfig *This);
      ULONG (WINAPI *Release)(IServiceInheritanceConfig *This);
      HRESULT (WINAPI *ContainingContextTreatment)(IServiceInheritanceConfig *This,CSC_InheritanceConfig inheritanceConfig);
    END_INTERFACE
  } IServiceInheritanceConfigVtbl;
  struct IServiceInheritanceConfig {
    CONST_VTBL struct IServiceInheritanceConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceInheritanceConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceInheritanceConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceInheritanceConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServiceInheritanceConfig_ContainingContextTreatment(This,inheritanceConfig) (This)->lpVtbl->ContainingContextTreatment(This,inheritanceConfig)
#endif
#endif
  HRESULT WINAPI IServiceInheritanceConfig_ContainingContextTreatment_Proxy(IServiceInheritanceConfig *This,CSC_InheritanceConfig inheritanceConfig);
  void __RPC_STUB IServiceInheritanceConfig_ContainingContextTreatment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceThreadPoolConfig_INTERFACE_DEFINED__
#define __IServiceThreadPoolConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceThreadPoolConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceThreadPoolConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI SelectThreadPool(CSC_ThreadPool threadPool) = 0;
    virtual HRESULT WINAPI SetBindingInfo(CSC_Binding binding) = 0;
  };
#else
  typedef struct IServiceThreadPoolConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceThreadPoolConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceThreadPoolConfig *This);
      ULONG (WINAPI *Release)(IServiceThreadPoolConfig *This);
      HRESULT (WINAPI *SelectThreadPool)(IServiceThreadPoolConfig *This,CSC_ThreadPool threadPool);
      HRESULT (WINAPI *SetBindingInfo)(IServiceThreadPoolConfig *This,CSC_Binding binding);
    END_INTERFACE
  } IServiceThreadPoolConfigVtbl;
  struct IServiceThreadPoolConfig {
    CONST_VTBL struct IServiceThreadPoolConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceThreadPoolConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceThreadPoolConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceThreadPoolConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServiceThreadPoolConfig_SelectThreadPool(This,threadPool) (This)->lpVtbl->SelectThreadPool(This,threadPool)
#define IServiceThreadPoolConfig_SetBindingInfo(This,binding) (This)->lpVtbl->SetBindingInfo(This,binding)
#endif
#endif
  HRESULT WINAPI IServiceThreadPoolConfig_SelectThreadPool_Proxy(IServiceThreadPoolConfig *This,CSC_ThreadPool threadPool);
  void __RPC_STUB IServiceThreadPoolConfig_SelectThreadPool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceThreadPoolConfig_SetBindingInfo_Proxy(IServiceThreadPoolConfig *This,CSC_Binding binding);
  void __RPC_STUB IServiceThreadPoolConfig_SetBindingInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceTransactionConfigBase_INTERFACE_DEFINED__
#define __IServiceTransactionConfigBase_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceTransactionConfigBase;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceTransactionConfigBase : public IUnknown {
  public:
    virtual HRESULT WINAPI ConfigureTransaction(CSC_TransactionConfig transactionConfig) = 0;
    virtual HRESULT WINAPI IsolationLevel(COMAdminTxIsolationLevelOptions option) = 0;
    virtual HRESULT WINAPI TransactionTimeout(ULONG ulTimeoutSec) = 0;
    virtual HRESULT WINAPI BringYourOwnTransaction(LPCWSTR szTipURL) = 0;
    virtual HRESULT WINAPI NewTransactionDescription(LPCWSTR szTxDesc) = 0;
  };
#else
  typedef struct IServiceTransactionConfigBaseVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceTransactionConfigBase *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceTransactionConfigBase *This);
      ULONG (WINAPI *Release)(IServiceTransactionConfigBase *This);
      HRESULT (WINAPI *ConfigureTransaction)(IServiceTransactionConfigBase *This,CSC_TransactionConfig transactionConfig);
      HRESULT (WINAPI *IsolationLevel)(IServiceTransactionConfigBase *This,COMAdminTxIsolationLevelOptions option);
      HRESULT (WINAPI *TransactionTimeout)(IServiceTransactionConfigBase *This,ULONG ulTimeoutSec);
      HRESULT (WINAPI *BringYourOwnTransaction)(IServiceTransactionConfigBase *This,LPCWSTR szTipURL);
      HRESULT (WINAPI *NewTransactionDescription)(IServiceTransactionConfigBase *This,LPCWSTR szTxDesc);
    END_INTERFACE
  } IServiceTransactionConfigBaseVtbl;
  struct IServiceTransactionConfigBase {
    CONST_VTBL struct IServiceTransactionConfigBaseVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceTransactionConfigBase_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceTransactionConfigBase_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceTransactionConfigBase_Release(This) (This)->lpVtbl->Release(This)
#define IServiceTransactionConfigBase_ConfigureTransaction(This,transactionConfig) (This)->lpVtbl->ConfigureTransaction(This,transactionConfig)
#define IServiceTransactionConfigBase_IsolationLevel(This,option) (This)->lpVtbl->IsolationLevel(This,option)
#define IServiceTransactionConfigBase_TransactionTimeout(This,ulTimeoutSec) (This)->lpVtbl->TransactionTimeout(This,ulTimeoutSec)
#define IServiceTransactionConfigBase_BringYourOwnTransaction(This,szTipURL) (This)->lpVtbl->BringYourOwnTransaction(This,szTipURL)
#define IServiceTransactionConfigBase_NewTransactionDescription(This,szTxDesc) (This)->lpVtbl->NewTransactionDescription(This,szTxDesc)
#endif
#endif
  HRESULT WINAPI IServiceTransactionConfigBase_ConfigureTransaction_Proxy(IServiceTransactionConfigBase *This,CSC_TransactionConfig transactionConfig);
  void __RPC_STUB IServiceTransactionConfigBase_ConfigureTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceTransactionConfigBase_IsolationLevel_Proxy(IServiceTransactionConfigBase *This,COMAdminTxIsolationLevelOptions option);
  void __RPC_STUB IServiceTransactionConfigBase_IsolationLevel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceTransactionConfigBase_TransactionTimeout_Proxy(IServiceTransactionConfigBase *This,ULONG ulTimeoutSec);
  void __RPC_STUB IServiceTransactionConfigBase_TransactionTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceTransactionConfigBase_BringYourOwnTransaction_Proxy(IServiceTransactionConfigBase *This,LPCWSTR szTipURL);
  void __RPC_STUB IServiceTransactionConfigBase_BringYourOwnTransaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceTransactionConfigBase_NewTransactionDescription_Proxy(IServiceTransactionConfigBase *This,LPCWSTR szTxDesc);
  void __RPC_STUB IServiceTransactionConfigBase_NewTransactionDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceTransactionConfig_INTERFACE_DEFINED__
#define __IServiceTransactionConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceTransactionConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceTransactionConfig : public IServiceTransactionConfigBase {
  public:
    virtual HRESULT WINAPI ConfigureBYOT(ITransaction *pITxByot) = 0;
  };
#else
  typedef struct IServiceTransactionConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceTransactionConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceTransactionConfig *This);
      ULONG (WINAPI *Release)(IServiceTransactionConfig *This);
      HRESULT (WINAPI *ConfigureTransaction)(IServiceTransactionConfig *This,CSC_TransactionConfig transactionConfig);
      HRESULT (WINAPI *IsolationLevel)(IServiceTransactionConfig *This,COMAdminTxIsolationLevelOptions option);
      HRESULT (WINAPI *TransactionTimeout)(IServiceTransactionConfig *This,ULONG ulTimeoutSec);
      HRESULT (WINAPI *BringYourOwnTransaction)(IServiceTransactionConfig *This,LPCWSTR szTipURL);
      HRESULT (WINAPI *NewTransactionDescription)(IServiceTransactionConfig *This,LPCWSTR szTxDesc);
      HRESULT (WINAPI *ConfigureBYOT)(IServiceTransactionConfig *This,ITransaction *pITxByot);
    END_INTERFACE
  } IServiceTransactionConfigVtbl;
  struct IServiceTransactionConfig {
    CONST_VTBL struct IServiceTransactionConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceTransactionConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceTransactionConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceTransactionConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServiceTransactionConfig_ConfigureTransaction(This,transactionConfig) (This)->lpVtbl->ConfigureTransaction(This,transactionConfig)
#define IServiceTransactionConfig_IsolationLevel(This,option) (This)->lpVtbl->IsolationLevel(This,option)
#define IServiceTransactionConfig_TransactionTimeout(This,ulTimeoutSec) (This)->lpVtbl->TransactionTimeout(This,ulTimeoutSec)
#define IServiceTransactionConfig_BringYourOwnTransaction(This,szTipURL) (This)->lpVtbl->BringYourOwnTransaction(This,szTipURL)
#define IServiceTransactionConfig_NewTransactionDescription(This,szTxDesc) (This)->lpVtbl->NewTransactionDescription(This,szTxDesc)
#define IServiceTransactionConfig_ConfigureBYOT(This,pITxByot) (This)->lpVtbl->ConfigureBYOT(This,pITxByot)
#endif
#endif
  HRESULT WINAPI IServiceTransactionConfig_ConfigureBYOT_Proxy(IServiceTransactionConfig *This,ITransaction *pITxByot);
  void __RPC_STUB IServiceTransactionConfig_ConfigureBYOT_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceSynchronizationConfig_INTERFACE_DEFINED__
#define __IServiceSynchronizationConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceSynchronizationConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceSynchronizationConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI ConfigureSynchronization(CSC_SynchronizationConfig synchConfig) = 0;
  };
#else
  typedef struct IServiceSynchronizationConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceSynchronizationConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceSynchronizationConfig *This);
      ULONG (WINAPI *Release)(IServiceSynchronizationConfig *This);
      HRESULT (WINAPI *ConfigureSynchronization)(IServiceSynchronizationConfig *This,CSC_SynchronizationConfig synchConfig);
    END_INTERFACE
  } IServiceSynchronizationConfigVtbl;
  struct IServiceSynchronizationConfig {
    CONST_VTBL struct IServiceSynchronizationConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceSynchronizationConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceSynchronizationConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceSynchronizationConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServiceSynchronizationConfig_ConfigureSynchronization(This,synchConfig) (This)->lpVtbl->ConfigureSynchronization(This,synchConfig)
#endif
#endif
  HRESULT WINAPI IServiceSynchronizationConfig_ConfigureSynchronization_Proxy(IServiceSynchronizationConfig *This,CSC_SynchronizationConfig synchConfig);
  void __RPC_STUB IServiceSynchronizationConfig_ConfigureSynchronization_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceTrackerConfig_INTERFACE_DEFINED__
#define __IServiceTrackerConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceTrackerConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceTrackerConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI TrackerConfig(CSC_TrackerConfig trackerConfig,LPCWSTR szTrackerAppName,LPCWSTR szTrackerCtxName) = 0;
  };
#else
  typedef struct IServiceTrackerConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceTrackerConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceTrackerConfig *This);
      ULONG (WINAPI *Release)(IServiceTrackerConfig *This);
      HRESULT (WINAPI *TrackerConfig)(IServiceTrackerConfig *This,CSC_TrackerConfig trackerConfig,LPCWSTR szTrackerAppName,LPCWSTR szTrackerCtxName);
    END_INTERFACE
  } IServiceTrackerConfigVtbl;
  struct IServiceTrackerConfig {
    CONST_VTBL struct IServiceTrackerConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceTrackerConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceTrackerConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceTrackerConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServiceTrackerConfig_TrackerConfig(This,trackerConfig,szTrackerAppName,szTrackerCtxName) (This)->lpVtbl->TrackerConfig(This,trackerConfig,szTrackerAppName,szTrackerCtxName)
#endif
#endif
  HRESULT WINAPI IServiceTrackerConfig_TrackerConfig_Proxy(IServiceTrackerConfig *This,CSC_TrackerConfig trackerConfig,LPCWSTR szTrackerAppName,LPCWSTR szTrackerCtxName);
  void __RPC_STUB IServiceTrackerConfig_TrackerConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServicePartitionConfig_INTERFACE_DEFINED__
#define __IServicePartitionConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServicePartitionConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServicePartitionConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI PartitionConfig(CSC_PartitionConfig partitionConfig) = 0;
    virtual HRESULT WINAPI PartitionID(REFGUID guidPartitionID) = 0;
  };
#else
  typedef struct IServicePartitionConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServicePartitionConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServicePartitionConfig *This);
      ULONG (WINAPI *Release)(IServicePartitionConfig *This);
      HRESULT (WINAPI *PartitionConfig)(IServicePartitionConfig *This,CSC_PartitionConfig partitionConfig);
      HRESULT (WINAPI *PartitionID)(IServicePartitionConfig *This,REFGUID guidPartitionID);
    END_INTERFACE
  } IServicePartitionConfigVtbl;
  struct IServicePartitionConfig {
    CONST_VTBL struct IServicePartitionConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServicePartitionConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServicePartitionConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServicePartitionConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServicePartitionConfig_PartitionConfig(This,partitionConfig) (This)->lpVtbl->PartitionConfig(This,partitionConfig)
#define IServicePartitionConfig_PartitionID(This,guidPartitionID) (This)->lpVtbl->PartitionID(This,guidPartitionID)
#endif
#endif
  HRESULT WINAPI IServicePartitionConfig_PartitionConfig_Proxy(IServicePartitionConfig *This,CSC_PartitionConfig partitionConfig);
  void __RPC_STUB IServicePartitionConfig_PartitionConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePartitionConfig_PartitionID_Proxy(IServicePartitionConfig *This,REFGUID guidPartitionID);
  void __RPC_STUB IServicePartitionConfig_PartitionID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceCall_INTERFACE_DEFINED__
#define __IServiceCall_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceCall;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceCall : public IUnknown {
  public:
    virtual HRESULT WINAPI OnCall(void) = 0;
  };
#else
  typedef struct IServiceCallVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceCall *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceCall *This);
      ULONG (WINAPI *Release)(IServiceCall *This);
      HRESULT (WINAPI *OnCall)(IServiceCall *This);
    END_INTERFACE
  } IServiceCallVtbl;
  struct IServiceCall {
    CONST_VTBL struct IServiceCallVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceCall_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceCall_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceCall_Release(This) (This)->lpVtbl->Release(This)
#define IServiceCall_OnCall(This) (This)->lpVtbl->OnCall(This)
#endif
#endif
  HRESULT WINAPI IServiceCall_OnCall_Proxy(IServiceCall *This);
  void __RPC_STUB IServiceCall_OnCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAsyncErrorNotify_INTERFACE_DEFINED__
#define __IAsyncErrorNotify_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAsyncErrorNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAsyncErrorNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI OnError(HRESULT hr) = 0;
  };
#else
  typedef struct IAsyncErrorNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAsyncErrorNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAsyncErrorNotify *This);
      ULONG (WINAPI *Release)(IAsyncErrorNotify *This);
      HRESULT (WINAPI *OnError)(IAsyncErrorNotify *This,HRESULT hr);
    END_INTERFACE
  } IAsyncErrorNotifyVtbl;
  struct IAsyncErrorNotify {
    CONST_VTBL struct IAsyncErrorNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAsyncErrorNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAsyncErrorNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAsyncErrorNotify_Release(This) (This)->lpVtbl->Release(This)
#define IAsyncErrorNotify_OnError(This,hr) (This)->lpVtbl->OnError(This,hr)
#endif
#endif
  HRESULT WINAPI IAsyncErrorNotify_OnError_Proxy(IAsyncErrorNotify *This,HRESULT hr);
  void __RPC_STUB IAsyncErrorNotify_OnError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServiceActivity_INTERFACE_DEFINED__
#define __IServiceActivity_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServiceActivity;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServiceActivity : public IUnknown {
  public:
    virtual HRESULT WINAPI SynchronousCall(IServiceCall *pIServiceCall) = 0;
    virtual HRESULT WINAPI AsynchronousCall(IServiceCall *pIServiceCall) = 0;
    virtual HRESULT WINAPI BindToCurrentThread(void) = 0;
    virtual HRESULT WINAPI UnbindFromThread(void) = 0;
  };
#else
  typedef struct IServiceActivityVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServiceActivity *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServiceActivity *This);
      ULONG (WINAPI *Release)(IServiceActivity *This);
      HRESULT (WINAPI *SynchronousCall)(IServiceActivity *This,IServiceCall *pIServiceCall);
      HRESULT (WINAPI *AsynchronousCall)(IServiceActivity *This,IServiceCall *pIServiceCall);
      HRESULT (WINAPI *BindToCurrentThread)(IServiceActivity *This);
      HRESULT (WINAPI *UnbindFromThread)(IServiceActivity *This);
    END_INTERFACE
  } IServiceActivityVtbl;
  struct IServiceActivity {
    CONST_VTBL struct IServiceActivityVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServiceActivity_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServiceActivity_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServiceActivity_Release(This) (This)->lpVtbl->Release(This)
#define IServiceActivity_SynchronousCall(This,pIServiceCall) (This)->lpVtbl->SynchronousCall(This,pIServiceCall)
#define IServiceActivity_AsynchronousCall(This,pIServiceCall) (This)->lpVtbl->AsynchronousCall(This,pIServiceCall)
#define IServiceActivity_BindToCurrentThread(This) (This)->lpVtbl->BindToCurrentThread(This)
#define IServiceActivity_UnbindFromThread(This) (This)->lpVtbl->UnbindFromThread(This)
#endif
#endif
  HRESULT WINAPI IServiceActivity_SynchronousCall_Proxy(IServiceActivity *This,IServiceCall *pIServiceCall);
  void __RPC_STUB IServiceActivity_SynchronousCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceActivity_AsynchronousCall_Proxy(IServiceActivity *This,IServiceCall *pIServiceCall);
  void __RPC_STUB IServiceActivity_AsynchronousCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceActivity_BindToCurrentThread_Proxy(IServiceActivity *This);
  void __RPC_STUB IServiceActivity_BindToCurrentThread_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServiceActivity_UnbindFromThread_Proxy(IServiceActivity *This);
  void __RPC_STUB IServiceActivity_UnbindFromThread_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IThreadPoolKnobs_INTERFACE_DEFINED__
#define __IThreadPoolKnobs_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IThreadPoolKnobs;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IThreadPoolKnobs : public IUnknown {
  public:
    virtual HRESULT WINAPI GetMaxThreads(__LONG32 *plcMaxThreads) = 0;
    virtual HRESULT WINAPI GetCurrentThreads(__LONG32 *plcCurrentThreads) = 0;
    virtual HRESULT WINAPI SetMaxThreads(__LONG32 lcMaxThreads) = 0;
    virtual HRESULT WINAPI GetDeleteDelay(__LONG32 *pmsecDeleteDelay) = 0;
    virtual HRESULT WINAPI SetDeleteDelay(__LONG32 msecDeleteDelay) = 0;
    virtual HRESULT WINAPI GetMaxQueuedRequests(__LONG32 *plcMaxQueuedRequests) = 0;
    virtual HRESULT WINAPI GetCurrentQueuedRequests(__LONG32 *plcCurrentQueuedRequests) = 0;
    virtual HRESULT WINAPI SetMaxQueuedRequests(__LONG32 lcMaxQueuedRequests) = 0;
    virtual HRESULT WINAPI SetMinThreads(__LONG32 lcMinThreads) = 0;
    virtual HRESULT WINAPI SetQueueDepth(__LONG32 lcQueueDepth) = 0;
  };
#else
  typedef struct IThreadPoolKnobsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IThreadPoolKnobs *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IThreadPoolKnobs *This);
      ULONG (WINAPI *Release)(IThreadPoolKnobs *This);
      HRESULT (WINAPI *GetMaxThreads)(IThreadPoolKnobs *This,__LONG32 *plcMaxThreads);
      HRESULT (WINAPI *GetCurrentThreads)(IThreadPoolKnobs *This,__LONG32 *plcCurrentThreads);
      HRESULT (WINAPI *SetMaxThreads)(IThreadPoolKnobs *This,__LONG32 lcMaxThreads);
      HRESULT (WINAPI *GetDeleteDelay)(IThreadPoolKnobs *This,__LONG32 *pmsecDeleteDelay);
      HRESULT (WINAPI *SetDeleteDelay)(IThreadPoolKnobs *This,__LONG32 msecDeleteDelay);
      HRESULT (WINAPI *GetMaxQueuedRequests)(IThreadPoolKnobs *This,__LONG32 *plcMaxQueuedRequests);
      HRESULT (WINAPI *GetCurrentQueuedRequests)(IThreadPoolKnobs *This,__LONG32 *plcCurrentQueuedRequests);
      HRESULT (WINAPI *SetMaxQueuedRequests)(IThreadPoolKnobs *This,__LONG32 lcMaxQueuedRequests);
      HRESULT (WINAPI *SetMinThreads)(IThreadPoolKnobs *This,__LONG32 lcMinThreads);
      HRESULT (WINAPI *SetQueueDepth)(IThreadPoolKnobs *This,__LONG32 lcQueueDepth);
    END_INTERFACE
  } IThreadPoolKnobsVtbl;
  struct IThreadPoolKnobs {
    CONST_VTBL struct IThreadPoolKnobsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IThreadPoolKnobs_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IThreadPoolKnobs_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IThreadPoolKnobs_Release(This) (This)->lpVtbl->Release(This)
#define IThreadPoolKnobs_GetMaxThreads(This,plcMaxThreads) (This)->lpVtbl->GetMaxThreads(This,plcMaxThreads)
#define IThreadPoolKnobs_GetCurrentThreads(This,plcCurrentThreads) (This)->lpVtbl->GetCurrentThreads(This,plcCurrentThreads)
#define IThreadPoolKnobs_SetMaxThreads(This,lcMaxThreads) (This)->lpVtbl->SetMaxThreads(This,lcMaxThreads)
#define IThreadPoolKnobs_GetDeleteDelay(This,pmsecDeleteDelay) (This)->lpVtbl->GetDeleteDelay(This,pmsecDeleteDelay)
#define IThreadPoolKnobs_SetDeleteDelay(This,msecDeleteDelay) (This)->lpVtbl->SetDeleteDelay(This,msecDeleteDelay)
#define IThreadPoolKnobs_GetMaxQueuedRequests(This,plcMaxQueuedRequests) (This)->lpVtbl->GetMaxQueuedRequests(This,plcMaxQueuedRequests)
#define IThreadPoolKnobs_GetCurrentQueuedRequests(This,plcCurrentQueuedRequests) (This)->lpVtbl->GetCurrentQueuedRequests(This,plcCurrentQueuedRequests)
#define IThreadPoolKnobs_SetMaxQueuedRequests(This,lcMaxQueuedRequests) (This)->lpVtbl->SetMaxQueuedRequests(This,lcMaxQueuedRequests)
#define IThreadPoolKnobs_SetMinThreads(This,lcMinThreads) (This)->lpVtbl->SetMinThreads(This,lcMinThreads)
#define IThreadPoolKnobs_SetQueueDepth(This,lcQueueDepth) (This)->lpVtbl->SetQueueDepth(This,lcQueueDepth)
#endif
#endif
  HRESULT WINAPI IThreadPoolKnobs_GetMaxThreads_Proxy(IThreadPoolKnobs *This,__LONG32 *plcMaxThreads);
  void __RPC_STUB IThreadPoolKnobs_GetMaxThreads_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_GetCurrentThreads_Proxy(IThreadPoolKnobs *This,__LONG32 *plcCurrentThreads);
  void __RPC_STUB IThreadPoolKnobs_GetCurrentThreads_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_SetMaxThreads_Proxy(IThreadPoolKnobs *This,__LONG32 lcMaxThreads);
  void __RPC_STUB IThreadPoolKnobs_SetMaxThreads_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_GetDeleteDelay_Proxy(IThreadPoolKnobs *This,__LONG32 *pmsecDeleteDelay);
  void __RPC_STUB IThreadPoolKnobs_GetDeleteDelay_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_SetDeleteDelay_Proxy(IThreadPoolKnobs *This,__LONG32 msecDeleteDelay);
  void __RPC_STUB IThreadPoolKnobs_SetDeleteDelay_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_GetMaxQueuedRequests_Proxy(IThreadPoolKnobs *This,__LONG32 *plcMaxQueuedRequests);
  void __RPC_STUB IThreadPoolKnobs_GetMaxQueuedRequests_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_GetCurrentQueuedRequests_Proxy(IThreadPoolKnobs *This,__LONG32 *plcCurrentQueuedRequests);
  void __RPC_STUB IThreadPoolKnobs_GetCurrentQueuedRequests_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_SetMaxQueuedRequests_Proxy(IThreadPoolKnobs *This,__LONG32 lcMaxQueuedRequests);
  void __RPC_STUB IThreadPoolKnobs_SetMaxQueuedRequests_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_SetMinThreads_Proxy(IThreadPoolKnobs *This,__LONG32 lcMinThreads);
  void __RPC_STUB IThreadPoolKnobs_SetMinThreads_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IThreadPoolKnobs_SetQueueDepth_Proxy(IThreadPoolKnobs *This,__LONG32 lcQueueDepth);
  void __RPC_STUB IThreadPoolKnobs_SetQueueDepth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComStaThreadPoolKnobs_INTERFACE_DEFINED__
#define __IComStaThreadPoolKnobs_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComStaThreadPoolKnobs;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComStaThreadPoolKnobs : public IUnknown {
  public:
    virtual HRESULT WINAPI SetMinThreadCount(DWORD minThreads) = 0;
    virtual HRESULT WINAPI GetMinThreadCount(DWORD *minThreads) = 0;
    virtual HRESULT WINAPI SetMaxThreadCount(DWORD maxThreads) = 0;
    virtual HRESULT WINAPI GetMaxThreadCount(DWORD *maxThreads) = 0;
    virtual HRESULT WINAPI SetActivityPerThread(DWORD activitiesPerThread) = 0;
    virtual HRESULT WINAPI GetActivityPerThread(DWORD *activitiesPerThread) = 0;
    virtual HRESULT WINAPI SetActivityRatio(DOUBLE activityRatio) = 0;
    virtual HRESULT WINAPI GetActivityRatio(DOUBLE *activityRatio) = 0;
    virtual HRESULT WINAPI GetThreadCount(DWORD *pdwThreads) = 0;
    virtual HRESULT WINAPI GetQueueDepth(DWORD *pdwQDepth) = 0;
    virtual HRESULT WINAPI SetQueueDepth(__LONG32 dwQDepth) = 0;
  };
#else
  typedef struct IComStaThreadPoolKnobsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComStaThreadPoolKnobs *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComStaThreadPoolKnobs *This);
      ULONG (WINAPI *Release)(IComStaThreadPoolKnobs *This);
      HRESULT (WINAPI *SetMinThreadCount)(IComStaThreadPoolKnobs *This,DWORD minThreads);
      HRESULT (WINAPI *GetMinThreadCount)(IComStaThreadPoolKnobs *This,DWORD *minThreads);
      HRESULT (WINAPI *SetMaxThreadCount)(IComStaThreadPoolKnobs *This,DWORD maxThreads);
      HRESULT (WINAPI *GetMaxThreadCount)(IComStaThreadPoolKnobs *This,DWORD *maxThreads);
      HRESULT (WINAPI *SetActivityPerThread)(IComStaThreadPoolKnobs *This,DWORD activitiesPerThread);
      HRESULT (WINAPI *GetActivityPerThread)(IComStaThreadPoolKnobs *This,DWORD *activitiesPerThread);
      HRESULT (WINAPI *SetActivityRatio)(IComStaThreadPoolKnobs *This,DOUBLE activityRatio);
      HRESULT (WINAPI *GetActivityRatio)(IComStaThreadPoolKnobs *This,DOUBLE *activityRatio);
      HRESULT (WINAPI *GetThreadCount)(IComStaThreadPoolKnobs *This,DWORD *pdwThreads);
      HRESULT (WINAPI *GetQueueDepth)(IComStaThreadPoolKnobs *This,DWORD *pdwQDepth);
      HRESULT (WINAPI *SetQueueDepth)(IComStaThreadPoolKnobs *This,__LONG32 dwQDepth);
    END_INTERFACE
  } IComStaThreadPoolKnobsVtbl;
  struct IComStaThreadPoolKnobs {
    CONST_VTBL struct IComStaThreadPoolKnobsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComStaThreadPoolKnobs_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComStaThreadPoolKnobs_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComStaThreadPoolKnobs_Release(This) (This)->lpVtbl->Release(This)
#define IComStaThreadPoolKnobs_SetMinThreadCount(This,minThreads) (This)->lpVtbl->SetMinThreadCount(This,minThreads)
#define IComStaThreadPoolKnobs_GetMinThreadCount(This,minThreads) (This)->lpVtbl->GetMinThreadCount(This,minThreads)
#define IComStaThreadPoolKnobs_SetMaxThreadCount(This,maxThreads) (This)->lpVtbl->SetMaxThreadCount(This,maxThreads)
#define IComStaThreadPoolKnobs_GetMaxThreadCount(This,maxThreads) (This)->lpVtbl->GetMaxThreadCount(This,maxThreads)
#define IComStaThreadPoolKnobs_SetActivityPerThread(This,activitiesPerThread) (This)->lpVtbl->SetActivityPerThread(This,activitiesPerThread)
#define IComStaThreadPoolKnobs_GetActivityPerThread(This,activitiesPerThread) (This)->lpVtbl->GetActivityPerThread(This,activitiesPerThread)
#define IComStaThreadPoolKnobs_SetActivityRatio(This,activityRatio) (This)->lpVtbl->SetActivityRatio(This,activityRatio)
#define IComStaThreadPoolKnobs_GetActivityRatio(This,activityRatio) (This)->lpVtbl->GetActivityRatio(This,activityRatio)
#define IComStaThreadPoolKnobs_GetThreadCount(This,pdwThreads) (This)->lpVtbl->GetThreadCount(This,pdwThreads)
#define IComStaThreadPoolKnobs_GetQueueDepth(This,pdwQDepth) (This)->lpVtbl->GetQueueDepth(This,pdwQDepth)
#define IComStaThreadPoolKnobs_SetQueueDepth(This,dwQDepth) (This)->lpVtbl->SetQueueDepth(This,dwQDepth)
#endif
#endif
  HRESULT WINAPI IComStaThreadPoolKnobs_SetMinThreadCount_Proxy(IComStaThreadPoolKnobs *This,DWORD minThreads);
  void __RPC_STUB IComStaThreadPoolKnobs_SetMinThreadCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_GetMinThreadCount_Proxy(IComStaThreadPoolKnobs *This,DWORD *minThreads);
  void __RPC_STUB IComStaThreadPoolKnobs_GetMinThreadCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_SetMaxThreadCount_Proxy(IComStaThreadPoolKnobs *This,DWORD maxThreads);
  void __RPC_STUB IComStaThreadPoolKnobs_SetMaxThreadCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_GetMaxThreadCount_Proxy(IComStaThreadPoolKnobs *This,DWORD *maxThreads);
  void __RPC_STUB IComStaThreadPoolKnobs_GetMaxThreadCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_SetActivityPerThread_Proxy(IComStaThreadPoolKnobs *This,DWORD activitiesPerThread);
  void __RPC_STUB IComStaThreadPoolKnobs_SetActivityPerThread_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_GetActivityPerThread_Proxy(IComStaThreadPoolKnobs *This,DWORD *activitiesPerThread);
  void __RPC_STUB IComStaThreadPoolKnobs_GetActivityPerThread_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_SetActivityRatio_Proxy(IComStaThreadPoolKnobs *This,DOUBLE activityRatio);
  void __RPC_STUB IComStaThreadPoolKnobs_SetActivityRatio_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_GetActivityRatio_Proxy(IComStaThreadPoolKnobs *This,DOUBLE *activityRatio);
  void __RPC_STUB IComStaThreadPoolKnobs_GetActivityRatio_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_GetThreadCount_Proxy(IComStaThreadPoolKnobs *This,DWORD *pdwThreads);
  void __RPC_STUB IComStaThreadPoolKnobs_GetThreadCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_GetQueueDepth_Proxy(IComStaThreadPoolKnobs *This,DWORD *pdwQDepth);
  void __RPC_STUB IComStaThreadPoolKnobs_GetQueueDepth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs_SetQueueDepth_Proxy(IComStaThreadPoolKnobs *This,__LONG32 dwQDepth);
  void __RPC_STUB IComStaThreadPoolKnobs_SetQueueDepth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComMtaThreadPoolKnobs_INTERFACE_DEFINED__
#define __IComMtaThreadPoolKnobs_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComMtaThreadPoolKnobs;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComMtaThreadPoolKnobs : public IUnknown {
  public:
    virtual HRESULT WINAPI MTASetMaxThreadCount(DWORD dwMaxThreads) = 0;
    virtual HRESULT WINAPI MTAGetMaxThreadCount(DWORD *pdwMaxThreads) = 0;
    virtual HRESULT WINAPI MTASetThrottleValue(DWORD dwThrottle) = 0;
    virtual HRESULT WINAPI MTAGetThrottleValue(DWORD *pdwThrottle) = 0;
  };
#else
  typedef struct IComMtaThreadPoolKnobsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComMtaThreadPoolKnobs *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComMtaThreadPoolKnobs *This);
      ULONG (WINAPI *Release)(IComMtaThreadPoolKnobs *This);
      HRESULT (WINAPI *MTASetMaxThreadCount)(IComMtaThreadPoolKnobs *This,DWORD dwMaxThreads);
      HRESULT (WINAPI *MTAGetMaxThreadCount)(IComMtaThreadPoolKnobs *This,DWORD *pdwMaxThreads);
      HRESULT (WINAPI *MTASetThrottleValue)(IComMtaThreadPoolKnobs *This,DWORD dwThrottle);
      HRESULT (WINAPI *MTAGetThrottleValue)(IComMtaThreadPoolKnobs *This,DWORD *pdwThrottle);
    END_INTERFACE
  } IComMtaThreadPoolKnobsVtbl;
  struct IComMtaThreadPoolKnobs {
    CONST_VTBL struct IComMtaThreadPoolKnobsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComMtaThreadPoolKnobs_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComMtaThreadPoolKnobs_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComMtaThreadPoolKnobs_Release(This) (This)->lpVtbl->Release(This)
#define IComMtaThreadPoolKnobs_MTASetMaxThreadCount(This,dwMaxThreads) (This)->lpVtbl->MTASetMaxThreadCount(This,dwMaxThreads)
#define IComMtaThreadPoolKnobs_MTAGetMaxThreadCount(This,pdwMaxThreads) (This)->lpVtbl->MTAGetMaxThreadCount(This,pdwMaxThreads)
#define IComMtaThreadPoolKnobs_MTASetThrottleValue(This,dwThrottle) (This)->lpVtbl->MTASetThrottleValue(This,dwThrottle)
#define IComMtaThreadPoolKnobs_MTAGetThrottleValue(This,pdwThrottle) (This)->lpVtbl->MTAGetThrottleValue(This,pdwThrottle)
#endif
#endif
  HRESULT WINAPI IComMtaThreadPoolKnobs_MTASetMaxThreadCount_Proxy(IComMtaThreadPoolKnobs *This,DWORD dwMaxThreads);
  void __RPC_STUB IComMtaThreadPoolKnobs_MTASetMaxThreadCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComMtaThreadPoolKnobs_MTAGetMaxThreadCount_Proxy(IComMtaThreadPoolKnobs *This,DWORD *pdwMaxThreads);
  void __RPC_STUB IComMtaThreadPoolKnobs_MTAGetMaxThreadCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComMtaThreadPoolKnobs_MTASetThrottleValue_Proxy(IComMtaThreadPoolKnobs *This,DWORD dwThrottle);
  void __RPC_STUB IComMtaThreadPoolKnobs_MTASetThrottleValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComMtaThreadPoolKnobs_MTAGetThrottleValue_Proxy(IComMtaThreadPoolKnobs *This,DWORD *pdwThrottle);
  void __RPC_STUB IComMtaThreadPoolKnobs_MTAGetThrottleValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IComStaThreadPoolKnobs2_INTERFACE_DEFINED__
#define __IComStaThreadPoolKnobs2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IComStaThreadPoolKnobs2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IComStaThreadPoolKnobs2 : public IComStaThreadPoolKnobs {
  public:
    virtual HRESULT WINAPI GetMaxCPULoad(DWORD *pdwLoad) = 0;
    virtual HRESULT WINAPI SetMaxCPULoad(__LONG32 pdwLoad) = 0;
    virtual HRESULT WINAPI GetCPUMetricEnabled(WINBOOL *pbMetricEnabled) = 0;
    virtual HRESULT WINAPI SetCPUMetricEnabled(WINBOOL bMetricEnabled) = 0;
    virtual HRESULT WINAPI GetCreateThreadsAggressively(WINBOOL *pbMetricEnabled) = 0;
    virtual HRESULT WINAPI SetCreateThreadsAggressively(WINBOOL bMetricEnabled) = 0;
    virtual HRESULT WINAPI GetMaxCSR(DWORD *pdwCSR) = 0;
    virtual HRESULT WINAPI SetMaxCSR(__LONG32 dwCSR) = 0;
    virtual HRESULT WINAPI GetWaitTimeForThreadCleanup(DWORD *pdwThreadCleanupWaitTime) = 0;
    virtual HRESULT WINAPI SetWaitTimeForThreadCleanup(__LONG32 dwThreadCleanupWaitTime) = 0;
  };
#else
  typedef struct IComStaThreadPoolKnobs2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IComStaThreadPoolKnobs2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IComStaThreadPoolKnobs2 *This);
      ULONG (WINAPI *Release)(IComStaThreadPoolKnobs2 *This);
      HRESULT (WINAPI *SetMinThreadCount)(IComStaThreadPoolKnobs2 *This,DWORD minThreads);
      HRESULT (WINAPI *GetMinThreadCount)(IComStaThreadPoolKnobs2 *This,DWORD *minThreads);
      HRESULT (WINAPI *SetMaxThreadCount)(IComStaThreadPoolKnobs2 *This,DWORD maxThreads);
      HRESULT (WINAPI *GetMaxThreadCount)(IComStaThreadPoolKnobs2 *This,DWORD *maxThreads);
      HRESULT (WINAPI *SetActivityPerThread)(IComStaThreadPoolKnobs2 *This,DWORD activitiesPerThread);
      HRESULT (WINAPI *GetActivityPerThread)(IComStaThreadPoolKnobs2 *This,DWORD *activitiesPerThread);
      HRESULT (WINAPI *SetActivityRatio)(IComStaThreadPoolKnobs2 *This,DOUBLE activityRatio);
      HRESULT (WINAPI *GetActivityRatio)(IComStaThreadPoolKnobs2 *This,DOUBLE *activityRatio);
      HRESULT (WINAPI *GetThreadCount)(IComStaThreadPoolKnobs2 *This,DWORD *pdwThreads);
      HRESULT (WINAPI *GetQueueDepth)(IComStaThreadPoolKnobs2 *This,DWORD *pdwQDepth);
      HRESULT (WINAPI *SetQueueDepth)(IComStaThreadPoolKnobs2 *This,__LONG32 dwQDepth);
      HRESULT (WINAPI *GetMaxCPULoad)(IComStaThreadPoolKnobs2 *This,DWORD *pdwLoad);
      HRESULT (WINAPI *SetMaxCPULoad)(IComStaThreadPoolKnobs2 *This,__LONG32 pdwLoad);
      HRESULT (WINAPI *GetCPUMetricEnabled)(IComStaThreadPoolKnobs2 *This,WINBOOL *pbMetricEnabled);
      HRESULT (WINAPI *SetCPUMetricEnabled)(IComStaThreadPoolKnobs2 *This,WINBOOL bMetricEnabled);
      HRESULT (WINAPI *GetCreateThreadsAggressively)(IComStaThreadPoolKnobs2 *This,WINBOOL *pbMetricEnabled);
      HRESULT (WINAPI *SetCreateThreadsAggressively)(IComStaThreadPoolKnobs2 *This,WINBOOL bMetricEnabled);
      HRESULT (WINAPI *GetMaxCSR)(IComStaThreadPoolKnobs2 *This,DWORD *pdwCSR);
      HRESULT (WINAPI *SetMaxCSR)(IComStaThreadPoolKnobs2 *This,__LONG32 dwCSR);
      HRESULT (WINAPI *GetWaitTimeForThreadCleanup)(IComStaThreadPoolKnobs2 *This,DWORD *pdwThreadCleanupWaitTime);
      HRESULT (WINAPI *SetWaitTimeForThreadCleanup)(IComStaThreadPoolKnobs2 *This,__LONG32 dwThreadCleanupWaitTime);
    END_INTERFACE
  } IComStaThreadPoolKnobs2Vtbl;
  struct IComStaThreadPoolKnobs2 {
    CONST_VTBL struct IComStaThreadPoolKnobs2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IComStaThreadPoolKnobs2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IComStaThreadPoolKnobs2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IComStaThreadPoolKnobs2_Release(This) (This)->lpVtbl->Release(This)
#define IComStaThreadPoolKnobs2_SetMinThreadCount(This,minThreads) (This)->lpVtbl->SetMinThreadCount(This,minThreads)
#define IComStaThreadPoolKnobs2_GetMinThreadCount(This,minThreads) (This)->lpVtbl->GetMinThreadCount(This,minThreads)
#define IComStaThreadPoolKnobs2_SetMaxThreadCount(This,maxThreads) (This)->lpVtbl->SetMaxThreadCount(This,maxThreads)
#define IComStaThreadPoolKnobs2_GetMaxThreadCount(This,maxThreads) (This)->lpVtbl->GetMaxThreadCount(This,maxThreads)
#define IComStaThreadPoolKnobs2_SetActivityPerThread(This,activitiesPerThread) (This)->lpVtbl->SetActivityPerThread(This,activitiesPerThread)
#define IComStaThreadPoolKnobs2_GetActivityPerThread(This,activitiesPerThread) (This)->lpVtbl->GetActivityPerThread(This,activitiesPerThread)
#define IComStaThreadPoolKnobs2_SetActivityRatio(This,activityRatio) (This)->lpVtbl->SetActivityRatio(This,activityRatio)
#define IComStaThreadPoolKnobs2_GetActivityRatio(This,activityRatio) (This)->lpVtbl->GetActivityRatio(This,activityRatio)
#define IComStaThreadPoolKnobs2_GetThreadCount(This,pdwThreads) (This)->lpVtbl->GetThreadCount(This,pdwThreads)
#define IComStaThreadPoolKnobs2_GetQueueDepth(This,pdwQDepth) (This)->lpVtbl->GetQueueDepth(This,pdwQDepth)
#define IComStaThreadPoolKnobs2_SetQueueDepth(This,dwQDepth) (This)->lpVtbl->SetQueueDepth(This,dwQDepth)
#define IComStaThreadPoolKnobs2_GetMaxCPULoad(This,pdwLoad) (This)->lpVtbl->GetMaxCPULoad(This,pdwLoad)
#define IComStaThreadPoolKnobs2_SetMaxCPULoad(This,pdwLoad) (This)->lpVtbl->SetMaxCPULoad(This,pdwLoad)
#define IComStaThreadPoolKnobs2_GetCPUMetricEnabled(This,pbMetricEnabled) (This)->lpVtbl->GetCPUMetricEnabled(This,pbMetricEnabled)
#define IComStaThreadPoolKnobs2_SetCPUMetricEnabled(This,bMetricEnabled) (This)->lpVtbl->SetCPUMetricEnabled(This,bMetricEnabled)
#define IComStaThreadPoolKnobs2_GetCreateThreadsAggressively(This,pbMetricEnabled) (This)->lpVtbl->GetCreateThreadsAggressively(This,pbMetricEnabled)
#define IComStaThreadPoolKnobs2_SetCreateThreadsAggressively(This,bMetricEnabled) (This)->lpVtbl->SetCreateThreadsAggressively(This,bMetricEnabled)
#define IComStaThreadPoolKnobs2_GetMaxCSR(This,pdwCSR) (This)->lpVtbl->GetMaxCSR(This,pdwCSR)
#define IComStaThreadPoolKnobs2_SetMaxCSR(This,dwCSR) (This)->lpVtbl->SetMaxCSR(This,dwCSR)
#define IComStaThreadPoolKnobs2_GetWaitTimeForThreadCleanup(This,pdwThreadCleanupWaitTime) (This)->lpVtbl->GetWaitTimeForThreadCleanup(This,pdwThreadCleanupWaitTime)
#define IComStaThreadPoolKnobs2_SetWaitTimeForThreadCleanup(This,dwThreadCleanupWaitTime) (This)->lpVtbl->SetWaitTimeForThreadCleanup(This,dwThreadCleanupWaitTime)
#endif
#endif
  HRESULT WINAPI IComStaThreadPoolKnobs2_GetMaxCPULoad_Proxy(IComStaThreadPoolKnobs2 *This,DWORD *pdwLoad);
  void __RPC_STUB IComStaThreadPoolKnobs2_GetMaxCPULoad_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_SetMaxCPULoad_Proxy(IComStaThreadPoolKnobs2 *This,__LONG32 pdwLoad);
  void __RPC_STUB IComStaThreadPoolKnobs2_SetMaxCPULoad_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_GetCPUMetricEnabled_Proxy(IComStaThreadPoolKnobs2 *This,WINBOOL *pbMetricEnabled);
  void __RPC_STUB IComStaThreadPoolKnobs2_GetCPUMetricEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_SetCPUMetricEnabled_Proxy(IComStaThreadPoolKnobs2 *This,WINBOOL bMetricEnabled);
  void __RPC_STUB IComStaThreadPoolKnobs2_SetCPUMetricEnabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_GetCreateThreadsAggressively_Proxy(IComStaThreadPoolKnobs2 *This,WINBOOL *pbMetricEnabled);
  void __RPC_STUB IComStaThreadPoolKnobs2_GetCreateThreadsAggressively_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_SetCreateThreadsAggressively_Proxy(IComStaThreadPoolKnobs2 *This,WINBOOL bMetricEnabled);
  void __RPC_STUB IComStaThreadPoolKnobs2_SetCreateThreadsAggressively_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_GetMaxCSR_Proxy(IComStaThreadPoolKnobs2 *This,DWORD *pdwCSR);
  void __RPC_STUB IComStaThreadPoolKnobs2_GetMaxCSR_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_SetMaxCSR_Proxy(IComStaThreadPoolKnobs2 *This,__LONG32 dwCSR);
  void __RPC_STUB IComStaThreadPoolKnobs2_SetMaxCSR_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_GetWaitTimeForThreadCleanup_Proxy(IComStaThreadPoolKnobs2 *This,DWORD *pdwThreadCleanupWaitTime);
  void __RPC_STUB IComStaThreadPoolKnobs2_GetWaitTimeForThreadCleanup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IComStaThreadPoolKnobs2_SetWaitTimeForThreadCleanup_Proxy(IComStaThreadPoolKnobs2 *This,__LONG32 dwThreadCleanupWaitTime);
  void __RPC_STUB IComStaThreadPoolKnobs2_SetWaitTimeForThreadCleanup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IProcessInitializer_INTERFACE_DEFINED__
#define __IProcessInitializer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IProcessInitializer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IProcessInitializer : public IUnknown {
  public:
    virtual HRESULT WINAPI Startup(IUnknown *punkProcessControl) = 0;
    virtual HRESULT WINAPI Shutdown(void) = 0;
  };
#else
  typedef struct IProcessInitializerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IProcessInitializer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IProcessInitializer *This);
      ULONG (WINAPI *Release)(IProcessInitializer *This);
      HRESULT (WINAPI *Startup)(IProcessInitializer *This,IUnknown *punkProcessControl);
      HRESULT (WINAPI *Shutdown)(IProcessInitializer *This);
    END_INTERFACE
  } IProcessInitializerVtbl;
  struct IProcessInitializer {
    CONST_VTBL struct IProcessInitializerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IProcessInitializer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IProcessInitializer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IProcessInitializer_Release(This) (This)->lpVtbl->Release(This)
#define IProcessInitializer_Startup(This,punkProcessControl) (This)->lpVtbl->Startup(This,punkProcessControl)
#define IProcessInitializer_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#endif
#endif
  HRESULT WINAPI IProcessInitializer_Startup_Proxy(IProcessInitializer *This,IUnknown *punkProcessControl);
  void __RPC_STUB IProcessInitializer_Startup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IProcessInitializer_Shutdown_Proxy(IProcessInitializer *This);
  void __RPC_STUB IProcessInitializer_Shutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServicePoolConfig_INTERFACE_DEFINED__
#define __IServicePoolConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServicePoolConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServicePoolConfig : public IUnknown {
  public:
    virtual HRESULT WINAPI put_MaxPoolSize(DWORD dwMaxPool) = 0;
    virtual HRESULT WINAPI get_MaxPoolSize(DWORD *pdwMaxPool) = 0;
    virtual HRESULT WINAPI put_MinPoolSize(DWORD dwMinPool) = 0;
    virtual HRESULT WINAPI get_MinPoolSize(DWORD *pdwMinPool) = 0;
    virtual HRESULT WINAPI put_CreationTimeout(DWORD dwCreationTimeout) = 0;
    virtual HRESULT WINAPI get_CreationTimeout(DWORD *pdwCreationTimeout) = 0;
    virtual HRESULT WINAPI put_TransactionAffinity(WINBOOL fTxAffinity) = 0;
    virtual HRESULT WINAPI get_TransactionAffinity(WINBOOL *pfTxAffinity) = 0;
    virtual HRESULT WINAPI put_ClassFactory(IClassFactory *pFactory) = 0;
    virtual HRESULT WINAPI get_ClassFactory(IClassFactory **pFactory) = 0;
  };
#else
  typedef struct IServicePoolConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServicePoolConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServicePoolConfig *This);
      ULONG (WINAPI *Release)(IServicePoolConfig *This);
      HRESULT (WINAPI *put_MaxPoolSize)(IServicePoolConfig *This,DWORD dwMaxPool);
      HRESULT (WINAPI *get_MaxPoolSize)(IServicePoolConfig *This,DWORD *pdwMaxPool);
      HRESULT (WINAPI *put_MinPoolSize)(IServicePoolConfig *This,DWORD dwMinPool);
      HRESULT (WINAPI *get_MinPoolSize)(IServicePoolConfig *This,DWORD *pdwMinPool);
      HRESULT (WINAPI *put_CreationTimeout)(IServicePoolConfig *This,DWORD dwCreationTimeout);
      HRESULT (WINAPI *get_CreationTimeout)(IServicePoolConfig *This,DWORD *pdwCreationTimeout);
      HRESULT (WINAPI *put_TransactionAffinity)(IServicePoolConfig *This,WINBOOL fTxAffinity);
      HRESULT (WINAPI *get_TransactionAffinity)(IServicePoolConfig *This,WINBOOL *pfTxAffinity);
      HRESULT (WINAPI *put_ClassFactory)(IServicePoolConfig *This,IClassFactory *pFactory);
      HRESULT (WINAPI *get_ClassFactory)(IServicePoolConfig *This,IClassFactory **pFactory);
    END_INTERFACE
  } IServicePoolConfigVtbl;
  struct IServicePoolConfig {
    CONST_VTBL struct IServicePoolConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServicePoolConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServicePoolConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServicePoolConfig_Release(This) (This)->lpVtbl->Release(This)
#define IServicePoolConfig_put_MaxPoolSize(This,dwMaxPool) (This)->lpVtbl->put_MaxPoolSize(This,dwMaxPool)
#define IServicePoolConfig_get_MaxPoolSize(This,pdwMaxPool) (This)->lpVtbl->get_MaxPoolSize(This,pdwMaxPool)
#define IServicePoolConfig_put_MinPoolSize(This,dwMinPool) (This)->lpVtbl->put_MinPoolSize(This,dwMinPool)
#define IServicePoolConfig_get_MinPoolSize(This,pdwMinPool) (This)->lpVtbl->get_MinPoolSize(This,pdwMinPool)
#define IServicePoolConfig_put_CreationTimeout(This,dwCreationTimeout) (This)->lpVtbl->put_CreationTimeout(This,dwCreationTimeout)
#define IServicePoolConfig_get_CreationTimeout(This,pdwCreationTimeout) (This)->lpVtbl->get_CreationTimeout(This,pdwCreationTimeout)
#define IServicePoolConfig_put_TransactionAffinity(This,fTxAffinity) (This)->lpVtbl->put_TransactionAffinity(This,fTxAffinity)
#define IServicePoolConfig_get_TransactionAffinity(This,pfTxAffinity) (This)->lpVtbl->get_TransactionAffinity(This,pfTxAffinity)
#define IServicePoolConfig_put_ClassFactory(This,pFactory) (This)->lpVtbl->put_ClassFactory(This,pFactory)
#define IServicePoolConfig_get_ClassFactory(This,pFactory) (This)->lpVtbl->get_ClassFactory(This,pFactory)
#endif
#endif
  HRESULT WINAPI IServicePoolConfig_put_MaxPoolSize_Proxy(IServicePoolConfig *This,DWORD dwMaxPool);
  void __RPC_STUB IServicePoolConfig_put_MaxPoolSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_get_MaxPoolSize_Proxy(IServicePoolConfig *This,DWORD *pdwMaxPool);
  void __RPC_STUB IServicePoolConfig_get_MaxPoolSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_put_MinPoolSize_Proxy(IServicePoolConfig *This,DWORD dwMinPool);
  void __RPC_STUB IServicePoolConfig_put_MinPoolSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_get_MinPoolSize_Proxy(IServicePoolConfig *This,DWORD *pdwMinPool);
  void __RPC_STUB IServicePoolConfig_get_MinPoolSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_put_CreationTimeout_Proxy(IServicePoolConfig *This,DWORD dwCreationTimeout);
  void __RPC_STUB IServicePoolConfig_put_CreationTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_get_CreationTimeout_Proxy(IServicePoolConfig *This,DWORD *pdwCreationTimeout);
  void __RPC_STUB IServicePoolConfig_get_CreationTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_put_TransactionAffinity_Proxy(IServicePoolConfig *This,WINBOOL fTxAffinity);
  void __RPC_STUB IServicePoolConfig_put_TransactionAffinity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_get_TransactionAffinity_Proxy(IServicePoolConfig *This,WINBOOL *pfTxAffinity);
  void __RPC_STUB IServicePoolConfig_get_TransactionAffinity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_put_ClassFactory_Proxy(IServicePoolConfig *This,IClassFactory *pFactory);
  void __RPC_STUB IServicePoolConfig_put_ClassFactory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePoolConfig_get_ClassFactory_Proxy(IServicePoolConfig *This,IClassFactory **pFactory);
  void __RPC_STUB IServicePoolConfig_get_ClassFactory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServicePool_INTERFACE_DEFINED__
#define __IServicePool_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IServicePool;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServicePool : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(IUnknown *pPoolConfig) = 0;
    virtual HRESULT WINAPI GetObject(REFIID riid,void **ppv) = 0;
    virtual HRESULT WINAPI Shutdown(void) = 0;
  };
#else
  typedef struct IServicePoolVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServicePool *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServicePool *This);
      ULONG (WINAPI *Release)(IServicePool *This);
      HRESULT (WINAPI *Initialize)(IServicePool *This,IUnknown *pPoolConfig);
      HRESULT (WINAPI *GetObject)(IServicePool *This,REFIID riid,void **ppv);
      HRESULT (WINAPI *Shutdown)(IServicePool *This);
    END_INTERFACE
  } IServicePoolVtbl;
  struct IServicePool {
    CONST_VTBL struct IServicePoolVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServicePool_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServicePool_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServicePool_Release(This) (This)->lpVtbl->Release(This)
#define IServicePool_Initialize(This,pPoolConfig) (This)->lpVtbl->Initialize(This,pPoolConfig)
#define IServicePool_GetObject(This,riid,ppv) (This)->lpVtbl->GetObject(This,riid,ppv)
#define IServicePool_Shutdown(This) (This)->lpVtbl->Shutdown(This)
#endif
#endif
  HRESULT WINAPI IServicePool_Initialize_Proxy(IServicePool *This,IUnknown *pPoolConfig);
  void __RPC_STUB IServicePool_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePool_GetObject_Proxy(IServicePool *This,REFIID riid,void **ppv);
  void __RPC_STUB IServicePool_GetObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServicePool_Shutdown_Proxy(IServicePool *This);
  void __RPC_STUB IServicePool_Shutdown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IManagedPooledObj_INTERFACE_DEFINED__
#define __IManagedPooledObj_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IManagedPooledObj;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IManagedPooledObj : public IUnknown {
  public:
    virtual HRESULT WINAPI SetHeld(WINBOOL m_bHeld) = 0;
  };
#else
  typedef struct IManagedPooledObjVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IManagedPooledObj *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IManagedPooledObj *This);
      ULONG (WINAPI *Release)(IManagedPooledObj *This);
      HRESULT (WINAPI *SetHeld)(IManagedPooledObj *This,WINBOOL m_bHeld);
    END_INTERFACE
  } IManagedPooledObjVtbl;
  struct IManagedPooledObj {
    CONST_VTBL struct IManagedPooledObjVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IManagedPooledObj_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IManagedPooledObj_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IManagedPooledObj_Release(This) (This)->lpVtbl->Release(This)
#define IManagedPooledObj_SetHeld(This,m_bHeld) (This)->lpVtbl->SetHeld(This,m_bHeld)
#endif
#endif
  HRESULT WINAPI IManagedPooledObj_SetHeld_Proxy(IManagedPooledObj *This,WINBOOL m_bHeld);
  void __RPC_STUB IManagedPooledObj_SetHeld_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IManagedPoolAction_INTERFACE_DEFINED__
#define __IManagedPoolAction_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IManagedPoolAction;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IManagedPoolAction : public IUnknown {
  public:
    virtual HRESULT WINAPI LastRelease(void) = 0;
  };
#else
  typedef struct IManagedPoolActionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IManagedPoolAction *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IManagedPoolAction *This);
      ULONG (WINAPI *Release)(IManagedPoolAction *This);
      HRESULT (WINAPI *LastRelease)(IManagedPoolAction *This);
    END_INTERFACE
  } IManagedPoolActionVtbl;
  struct IManagedPoolAction {
    CONST_VTBL struct IManagedPoolActionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IManagedPoolAction_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IManagedPoolAction_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IManagedPoolAction_Release(This) (This)->lpVtbl->Release(This)
#define IManagedPoolAction_LastRelease(This) (This)->lpVtbl->LastRelease(This)
#endif
#endif
  HRESULT WINAPI IManagedPoolAction_LastRelease_Proxy(IManagedPoolAction *This);
  void __RPC_STUB IManagedPoolAction_LastRelease_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IManagedObjectInfo_INTERFACE_DEFINED__
#define __IManagedObjectInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IManagedObjectInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IManagedObjectInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetIUnknown(IUnknown **pUnk) = 0;
    virtual HRESULT WINAPI GetIObjectControl(IObjectControl **pCtrl) = 0;
    virtual HRESULT WINAPI SetInPool(WINBOOL bInPool,IManagedPooledObj *pPooledObj) = 0;
    virtual HRESULT WINAPI SetWrapperStrength(WINBOOL bStrong) = 0;
  };
#else
  typedef struct IManagedObjectInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IManagedObjectInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IManagedObjectInfo *This);
      ULONG (WINAPI *Release)(IManagedObjectInfo *This);
      HRESULT (WINAPI *GetIUnknown)(IManagedObjectInfo *This,IUnknown **pUnk);
      HRESULT (WINAPI *GetIObjectControl)(IManagedObjectInfo *This,IObjectControl **pCtrl);
      HRESULT (WINAPI *SetInPool)(IManagedObjectInfo *This,WINBOOL bInPool,IManagedPooledObj *pPooledObj);
      HRESULT (WINAPI *SetWrapperStrength)(IManagedObjectInfo *This,WINBOOL bStrong);
    END_INTERFACE
  } IManagedObjectInfoVtbl;
  struct IManagedObjectInfo {
    CONST_VTBL struct IManagedObjectInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IManagedObjectInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IManagedObjectInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IManagedObjectInfo_Release(This) (This)->lpVtbl->Release(This)
#define IManagedObjectInfo_GetIUnknown(This,pUnk) (This)->lpVtbl->GetIUnknown(This,pUnk)
#define IManagedObjectInfo_GetIObjectControl(This,pCtrl) (This)->lpVtbl->GetIObjectControl(This,pCtrl)
#define IManagedObjectInfo_SetInPool(This,bInPool,pPooledObj) (This)->lpVtbl->SetInPool(This,bInPool,pPooledObj)
#define IManagedObjectInfo_SetWrapperStrength(This,bStrong) (This)->lpVtbl->SetWrapperStrength(This,bStrong)
#endif
#endif
  HRESULT WINAPI IManagedObjectInfo_GetIUnknown_Proxy(IManagedObjectInfo *This,IUnknown **pUnk);
  void __RPC_STUB IManagedObjectInfo_GetIUnknown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IManagedObjectInfo_GetIObjectControl_Proxy(IManagedObjectInfo *This,IObjectControl **pCtrl);
  void __RPC_STUB IManagedObjectInfo_GetIObjectControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IManagedObjectInfo_SetInPool_Proxy(IManagedObjectInfo *This,WINBOOL bInPool,IManagedPooledObj *pPooledObj);
  void __RPC_STUB IManagedObjectInfo_SetInPool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IManagedObjectInfo_SetWrapperStrength_Proxy(IManagedObjectInfo *This,WINBOOL bStrong);
  void __RPC_STUB IManagedObjectInfo_SetWrapperStrength_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAppDomainHelper_INTERFACE_DEFINED__
#define __IAppDomainHelper_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAppDomainHelper;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAppDomainHelper : public IDispatch {
  public:
    virtual HRESULT WINAPI Initialize(IUnknown *pUnkAD,HRESULT (WINAPI __MIDL_0028)(void *pv),void *pPool) = 0;
    virtual HRESULT WINAPI DoCallback(IUnknown *pUnkAD,HRESULT (WINAPI __MIDL_0029)(void *pv),void *pPool) = 0;
  };
#else
  typedef struct IAppDomainHelperVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAppDomainHelper *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAppDomainHelper *This);
      ULONG (WINAPI *Release)(IAppDomainHelper *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAppDomainHelper *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAppDomainHelper *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAppDomainHelper *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAppDomainHelper *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Initialize)(IAppDomainHelper *This,IUnknown *pUnkAD,HRESULT (WINAPI __MIDL_0028)(void *pv),void *pPool);
      HRESULT (WINAPI *DoCallback)(IAppDomainHelper *This,IUnknown *pUnkAD,HRESULT (WINAPI __MIDL_0029)(void *pv),void *pPool);
    END_INTERFACE
  } IAppDomainHelperVtbl;
  struct IAppDomainHelper {
    CONST_VTBL struct IAppDomainHelperVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAppDomainHelper_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAppDomainHelper_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAppDomainHelper_Release(This) (This)->lpVtbl->Release(This)
#define IAppDomainHelper_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAppDomainHelper_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAppDomainHelper_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAppDomainHelper_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAppDomainHelper_Initialize(This,pUnkAD,__MIDL_0028,pPool) (This)->lpVtbl->Initialize(This,pUnkAD,__MIDL_0028,pPool)
#define IAppDomainHelper_DoCallback(This,pUnkAD,__MIDL_0029,pPool) (This)->lpVtbl->DoCallback(This,pUnkAD,__MIDL_0029,pPool)
#endif
#endif
  HRESULT WINAPI IAppDomainHelper_Initialize_Proxy(IAppDomainHelper *This,IUnknown *pUnkAD,HRESULT (WINAPI __MIDL_0028)(void *pv),void *pPool);
  void __RPC_STUB IAppDomainHelper_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAppDomainHelper_DoCallback_Proxy(IAppDomainHelper *This,IUnknown *pUnkAD,HRESULT (WINAPI __MIDL_0029)(void *pv),void *pPool);
  void __RPC_STUB IAppDomainHelper_DoCallback_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IAssemblyLocator_INTERFACE_DEFINED__
#define __IAssemblyLocator_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAssemblyLocator;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAssemblyLocator : public IDispatch {
  public:
    virtual HRESULT WINAPI GetModules(BSTR applicationDir,BSTR applicationName,BSTR assemblyName,SAFEARRAY **pModules) = 0;
  };
#else
  typedef struct IAssemblyLocatorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAssemblyLocator *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAssemblyLocator *This);
      ULONG (WINAPI *Release)(IAssemblyLocator *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IAssemblyLocator *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IAssemblyLocator *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IAssemblyLocator *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IAssemblyLocator *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetModules)(IAssemblyLocator *This,BSTR applicationDir,BSTR applicationName,BSTR assemblyName,SAFEARRAY **pModules);
    END_INTERFACE
  } IAssemblyLocatorVtbl;
  struct IAssemblyLocator {
    CONST_VTBL struct IAssemblyLocatorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAssemblyLocator_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAssemblyLocator_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAssemblyLocator_Release(This) (This)->lpVtbl->Release(This)
#define IAssemblyLocator_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IAssemblyLocator_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IAssemblyLocator_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IAssemblyLocator_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IAssemblyLocator_GetModules(This,applicationDir,applicationName,assemblyName,pModules) (This)->lpVtbl->GetModules(This,applicationDir,applicationName,assemblyName,pModules)
#endif
#endif
  HRESULT WINAPI IAssemblyLocator_GetModules_Proxy(IAssemblyLocator *This,BSTR applicationDir,BSTR applicationName,BSTR assemblyName,SAFEARRAY **pModules);
  void __RPC_STUB IAssemblyLocator_GetModules_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IManagedActivationEvents_INTERFACE_DEFINED__
#define __IManagedActivationEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IManagedActivationEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IManagedActivationEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateManagedStub(IManagedObjectInfo *pInfo,WINBOOL fDist) = 0;
    virtual HRESULT WINAPI DestroyManagedStub(IManagedObjectInfo *pInfo) = 0;
  };
#else
  typedef struct IManagedActivationEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IManagedActivationEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IManagedActivationEvents *This);
      ULONG (WINAPI *Release)(IManagedActivationEvents *This);
      HRESULT (WINAPI *CreateManagedStub)(IManagedActivationEvents *This,IManagedObjectInfo *pInfo,WINBOOL fDist);
      HRESULT (WINAPI *DestroyManagedStub)(IManagedActivationEvents *This,IManagedObjectInfo *pInfo);
    END_INTERFACE
  } IManagedActivationEventsVtbl;
  struct IManagedActivationEvents {
    CONST_VTBL struct IManagedActivationEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IManagedActivationEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IManagedActivationEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IManagedActivationEvents_Release(This) (This)->lpVtbl->Release(This)
#define IManagedActivationEvents_CreateManagedStub(This,pInfo,fDist) (This)->lpVtbl->CreateManagedStub(This,pInfo,fDist)
#define IManagedActivationEvents_DestroyManagedStub(This,pInfo) (This)->lpVtbl->DestroyManagedStub(This,pInfo)
#endif
#endif
  HRESULT WINAPI IManagedActivationEvents_CreateManagedStub_Proxy(IManagedActivationEvents *This,IManagedObjectInfo *pInfo,WINBOOL fDist);
  void __RPC_STUB IManagedActivationEvents_CreateManagedStub_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IManagedActivationEvents_DestroyManagedStub_Proxy(IManagedActivationEvents *This,IManagedObjectInfo *pInfo);
  void __RPC_STUB IManagedActivationEvents_DestroyManagedStub_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISendMethodEvents_INTERFACE_DEFINED__
#define __ISendMethodEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISendMethodEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISendMethodEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI SendMethodCall(const void *pIdentity,REFIID riid,DWORD dwMeth) = 0;
    virtual HRESULT WINAPI SendMethodReturn(const void *pIdentity,REFIID riid,DWORD dwMeth,HRESULT hrCall,HRESULT hrServer) = 0;
  };
#else
  typedef struct ISendMethodEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISendMethodEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISendMethodEvents *This);
      ULONG (WINAPI *Release)(ISendMethodEvents *This);
      HRESULT (WINAPI *SendMethodCall)(ISendMethodEvents *This,const void *pIdentity,REFIID riid,DWORD dwMeth);
      HRESULT (WINAPI *SendMethodReturn)(ISendMethodEvents *This,const void *pIdentity,REFIID riid,DWORD dwMeth,HRESULT hrCall,HRESULT hrServer);
    END_INTERFACE
  } ISendMethodEventsVtbl;
  struct ISendMethodEvents {
    CONST_VTBL struct ISendMethodEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISendMethodEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISendMethodEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISendMethodEvents_Release(This) (This)->lpVtbl->Release(This)
#define ISendMethodEvents_SendMethodCall(This,pIdentity,riid,dwMeth) (This)->lpVtbl->SendMethodCall(This,pIdentity,riid,dwMeth)
#define ISendMethodEvents_SendMethodReturn(This,pIdentity,riid,dwMeth,hrCall,hrServer) (This)->lpVtbl->SendMethodReturn(This,pIdentity,riid,dwMeth,hrCall,hrServer)
#endif
#endif
  HRESULT WINAPI ISendMethodEvents_SendMethodCall_Proxy(ISendMethodEvents *This,const void *pIdentity,REFIID riid,DWORD dwMeth);
  void __RPC_STUB ISendMethodEvents_SendMethodCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISendMethodEvents_SendMethodReturn_Proxy(ISendMethodEvents *This,const void *pIdentity,REFIID riid,DWORD dwMeth,HRESULT hrCall,HRESULT hrServer);
  void __RPC_STUB ISendMethodEvents_SendMethodReturn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0406_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0406_v0_0_s_ifspec;

#ifndef __ITransactionResourcePool_INTERFACE_DEFINED__
#define __ITransactionResourcePool_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionResourcePool;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionResourcePool : public IUnknown {
  public:
    virtual HRESULT WINAPI PutResource(IObjPool *pPool,IUnknown *pUnk) = 0;
    virtual HRESULT WINAPI GetResource(IObjPool *pPool,IUnknown **ppUnk) = 0;
  };
#else
  typedef struct ITransactionResourcePoolVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionResourcePool *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionResourcePool *This);
      ULONG (WINAPI *Release)(ITransactionResourcePool *This);
      HRESULT (WINAPI *PutResource)(ITransactionResourcePool *This,IObjPool *pPool,IUnknown *pUnk);
      HRESULT (WINAPI *GetResource)(ITransactionResourcePool *This,IObjPool *pPool,IUnknown **ppUnk);
    END_INTERFACE
  } ITransactionResourcePoolVtbl;
  struct ITransactionResourcePool {
    CONST_VTBL struct ITransactionResourcePoolVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionResourcePool_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionResourcePool_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionResourcePool_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionResourcePool_PutResource(This,pPool,pUnk) (This)->lpVtbl->PutResource(This,pPool,pUnk)
#define ITransactionResourcePool_GetResource(This,pPool,ppUnk) (This)->lpVtbl->GetResource(This,pPool,ppUnk)
#endif
#endif
  HRESULT WINAPI ITransactionResourcePool_PutResource_Proxy(ITransactionResourcePool *This,IObjPool *pPool,IUnknown *pUnk);
  void __RPC_STUB ITransactionResourcePool_PutResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionResourcePool_GetResource_Proxy(ITransactionResourcePool *This,IObjPool *pPool,IUnknown **ppUnk);
  void __RPC_STUB ITransactionResourcePool_GetResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C HRESULT WINAPI MTSCreateActivity (REFIID riid,void **ppobj);

  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0407_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_autosvcs_0407_v0_0_s_ifspec;

#ifndef __IMTSCall_INTERFACE_DEFINED__
#define __IMTSCall_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMTSCall;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMTSCall : public IUnknown {
  public:
    virtual HRESULT WINAPI OnCall(void) = 0;
  };
#else
  typedef struct IMTSCallVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMTSCall *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMTSCall *This);
      ULONG (WINAPI *Release)(IMTSCall *This);
      HRESULT (WINAPI *OnCall)(IMTSCall *This);
    END_INTERFACE
  } IMTSCallVtbl;
  struct IMTSCall {
    CONST_VTBL struct IMTSCallVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMTSCall_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMTSCall_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMTSCall_Release(This) (This)->lpVtbl->Release(This)
#define IMTSCall_OnCall(This) (This)->lpVtbl->OnCall(This)
#endif
#endif
  HRESULT WINAPI IMTSCall_OnCall_Proxy(IMTSCall *This);
  void __RPC_STUB IMTSCall_OnCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IContextProperties_INTERFACE_DEFINED__
#define __IContextProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IContextProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IContextProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI GetProperty(BSTR name,VARIANT *pProperty) = 0;
    virtual HRESULT WINAPI EnumNames(IEnumNames **ppenum) = 0;
    virtual HRESULT WINAPI SetProperty(BSTR name,VARIANT property) = 0;
    virtual HRESULT WINAPI RemoveProperty(BSTR name) = 0;
  };
#else
  typedef struct IContextPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IContextProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IContextProperties *This);
      ULONG (WINAPI *Release)(IContextProperties *This);
      HRESULT (WINAPI *Count)(IContextProperties *This,__LONG32 *plCount);
      HRESULT (WINAPI *GetProperty)(IContextProperties *This,BSTR name,VARIANT *pProperty);
      HRESULT (WINAPI *EnumNames)(IContextProperties *This,IEnumNames **ppenum);
      HRESULT (WINAPI *SetProperty)(IContextProperties *This,BSTR name,VARIANT property);
      HRESULT (WINAPI *RemoveProperty)(IContextProperties *This,BSTR name);
    END_INTERFACE
  } IContextPropertiesVtbl;
  struct IContextProperties {
    CONST_VTBL struct IContextPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IContextProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IContextProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IContextProperties_Release(This) (This)->lpVtbl->Release(This)
#define IContextProperties_Count(This,plCount) (This)->lpVtbl->Count(This,plCount)
#define IContextProperties_GetProperty(This,name,pProperty) (This)->lpVtbl->GetProperty(This,name,pProperty)
#define IContextProperties_EnumNames(This,ppenum) (This)->lpVtbl->EnumNames(This,ppenum)
#define IContextProperties_SetProperty(This,name,property) (This)->lpVtbl->SetProperty(This,name,property)
#define IContextProperties_RemoveProperty(This,name) (This)->lpVtbl->RemoveProperty(This,name)
#endif
#endif
  HRESULT WINAPI IContextProperties_Count_Proxy(IContextProperties *This,__LONG32 *plCount);
  void __RPC_STUB IContextProperties_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContextProperties_GetProperty_Proxy(IContextProperties *This,BSTR name,VARIANT *pProperty);
  void __RPC_STUB IContextProperties_GetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContextProperties_EnumNames_Proxy(IContextProperties *This,IEnumNames **ppenum);
  void __RPC_STUB IContextProperties_EnumNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContextProperties_SetProperty_Proxy(IContextProperties *This,BSTR name,VARIANT property);
  void __RPC_STUB IContextProperties_SetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IContextProperties_RemoveProperty_Proxy(IContextProperties *This,BSTR name);
  void __RPC_STUB IContextProperties_RemoveProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IObjPool_INTERFACE_DEFINED__
#define __IObjPool_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IObjPool;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IObjPool : public IUnknown {
  public:
    virtual void WINAPI Reserved1(void) = 0;
    virtual void WINAPI Reserved2(void) = 0;
    virtual void WINAPI Reserved3(void) = 0;
    virtual void WINAPI Reserved4(void) = 0;
    virtual void WINAPI PutEndTx(IUnknown *pObj) = 0;
    virtual void WINAPI Reserved5(void) = 0;
    virtual void WINAPI Reserved6(void) = 0;
  };
#else
  typedef struct IObjPoolVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IObjPool *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IObjPool *This);
      ULONG (WINAPI *Release)(IObjPool *This);
      void (WINAPI *Reserved1)(IObjPool *This);
      void (WINAPI *Reserved2)(IObjPool *This);
      void (WINAPI *Reserved3)(IObjPool *This);
      void (WINAPI *Reserved4)(IObjPool *This);
      void (WINAPI *PutEndTx)(IObjPool *This,IUnknown *pObj);
      void (WINAPI *Reserved5)(IObjPool *This);
      void (WINAPI *Reserved6)(IObjPool *This);
    END_INTERFACE
  } IObjPoolVtbl;
  struct IObjPool {
    CONST_VTBL struct IObjPoolVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IObjPool_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IObjPool_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IObjPool_Release(This) (This)->lpVtbl->Release(This)
#define IObjPool_Reserved1(This) (This)->lpVtbl->Reserved1(This)
#define IObjPool_Reserved2(This) (This)->lpVtbl->Reserved2(This)
#define IObjPool_Reserved3(This) (This)->lpVtbl->Reserved3(This)
#define IObjPool_Reserved4(This) (This)->lpVtbl->Reserved4(This)
#define IObjPool_PutEndTx(This,pObj) (This)->lpVtbl->PutEndTx(This,pObj)
#define IObjPool_Reserved5(This) (This)->lpVtbl->Reserved5(This)
#define IObjPool_Reserved6(This) (This)->lpVtbl->Reserved6(This)
#endif
#endif
  void WINAPI IObjPool_Reserved1_Proxy(IObjPool *This);
  void __RPC_STUB IObjPool_Reserved1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IObjPool_Reserved2_Proxy(IObjPool *This);
  void __RPC_STUB IObjPool_Reserved2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IObjPool_Reserved3_Proxy(IObjPool *This);
  void __RPC_STUB IObjPool_Reserved3_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IObjPool_Reserved4_Proxy(IObjPool *This);
  void __RPC_STUB IObjPool_Reserved4_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IObjPool_PutEndTx_Proxy(IObjPool *This,IUnknown *pObj);
  void __RPC_STUB IObjPool_PutEndTx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IObjPool_Reserved5_Proxy(IObjPool *This);
  void __RPC_STUB IObjPool_Reserved5_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IObjPool_Reserved6_Proxy(IObjPool *This);
  void __RPC_STUB IObjPool_Reserved6_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITransactionProperty_INTERFACE_DEFINED__
#define __ITransactionProperty_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITransactionProperty;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITransactionProperty : public IUnknown {
  public:
    virtual void WINAPI Reserved1(void) = 0;
    virtual void WINAPI Reserved2(void) = 0;
    virtual void WINAPI Reserved3(void) = 0;
    virtual void WINAPI Reserved4(void) = 0;
    virtual void WINAPI Reserved5(void) = 0;
    virtual void WINAPI Reserved6(void) = 0;
    virtual void WINAPI Reserved7(void) = 0;
    virtual void WINAPI Reserved8(void) = 0;
    virtual void WINAPI Reserved9(void) = 0;
    virtual HRESULT WINAPI GetTransactionResourcePool(ITransactionResourcePool **ppTxPool) = 0;
    virtual void WINAPI Reserved10(void) = 0;
    virtual void WINAPI Reserved11(void) = 0;
    virtual void WINAPI Reserved12(void) = 0;
    virtual void WINAPI Reserved13(void) = 0;
    virtual void WINAPI Reserved14(void) = 0;
    virtual void WINAPI Reserved15(void) = 0;
    virtual void WINAPI Reserved16(void) = 0;
    virtual void WINAPI Reserved17(void) = 0;
  };
#else
  typedef struct ITransactionPropertyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITransactionProperty *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITransactionProperty *This);
      ULONG (WINAPI *Release)(ITransactionProperty *This);
      void (WINAPI *Reserved1)(ITransactionProperty *This);
      void (WINAPI *Reserved2)(ITransactionProperty *This);
      void (WINAPI *Reserved3)(ITransactionProperty *This);
      void (WINAPI *Reserved4)(ITransactionProperty *This);
      void (WINAPI *Reserved5)(ITransactionProperty *This);
      void (WINAPI *Reserved6)(ITransactionProperty *This);
      void (WINAPI *Reserved7)(ITransactionProperty *This);
      void (WINAPI *Reserved8)(ITransactionProperty *This);
      void (WINAPI *Reserved9)(ITransactionProperty *This);
      HRESULT (WINAPI *GetTransactionResourcePool)(ITransactionProperty *This,ITransactionResourcePool **ppTxPool);
      void (WINAPI *Reserved10)(ITransactionProperty *This);
      void (WINAPI *Reserved11)(ITransactionProperty *This);
      void (WINAPI *Reserved12)(ITransactionProperty *This);
      void (WINAPI *Reserved13)(ITransactionProperty *This);
      void (WINAPI *Reserved14)(ITransactionProperty *This);
      void (WINAPI *Reserved15)(ITransactionProperty *This);
      void (WINAPI *Reserved16)(ITransactionProperty *This);
      void (WINAPI *Reserved17)(ITransactionProperty *This);
    END_INTERFACE
  } ITransactionPropertyVtbl;
  struct ITransactionProperty {
    CONST_VTBL struct ITransactionPropertyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITransactionProperty_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITransactionProperty_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITransactionProperty_Release(This) (This)->lpVtbl->Release(This)
#define ITransactionProperty_Reserved1(This) (This)->lpVtbl->Reserved1(This)
#define ITransactionProperty_Reserved2(This) (This)->lpVtbl->Reserved2(This)
#define ITransactionProperty_Reserved3(This) (This)->lpVtbl->Reserved3(This)
#define ITransactionProperty_Reserved4(This) (This)->lpVtbl->Reserved4(This)
#define ITransactionProperty_Reserved5(This) (This)->lpVtbl->Reserved5(This)
#define ITransactionProperty_Reserved6(This) (This)->lpVtbl->Reserved6(This)
#define ITransactionProperty_Reserved7(This) (This)->lpVtbl->Reserved7(This)
#define ITransactionProperty_Reserved8(This) (This)->lpVtbl->Reserved8(This)
#define ITransactionProperty_Reserved9(This) (This)->lpVtbl->Reserved9(This)
#define ITransactionProperty_GetTransactionResourcePool(This,ppTxPool) (This)->lpVtbl->GetTransactionResourcePool(This,ppTxPool)
#define ITransactionProperty_Reserved10(This) (This)->lpVtbl->Reserved10(This)
#define ITransactionProperty_Reserved11(This) (This)->lpVtbl->Reserved11(This)
#define ITransactionProperty_Reserved12(This) (This)->lpVtbl->Reserved12(This)
#define ITransactionProperty_Reserved13(This) (This)->lpVtbl->Reserved13(This)
#define ITransactionProperty_Reserved14(This) (This)->lpVtbl->Reserved14(This)
#define ITransactionProperty_Reserved15(This) (This)->lpVtbl->Reserved15(This)
#define ITransactionProperty_Reserved16(This) (This)->lpVtbl->Reserved16(This)
#define ITransactionProperty_Reserved17(This) (This)->lpVtbl->Reserved17(This)
#endif
#endif
  void WINAPI ITransactionProperty_Reserved1_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved2_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved3_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved3_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved4_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved4_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved5_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved5_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved6_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved6_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved7_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved7_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved8_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved8_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved9_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved9_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITransactionProperty_GetTransactionResourcePool_Proxy(ITransactionProperty *This,ITransactionResourcePool **ppTxPool);
  void __RPC_STUB ITransactionProperty_GetTransactionResourcePool_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved10_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved10_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved11_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved11_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved12_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved12_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved13_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved13_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved14_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved14_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved15_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved15_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved16_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved16_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ITransactionProperty_Reserved17_Proxy(ITransactionProperty *This);
  void __RPC_STUB ITransactionProperty_Reserved17_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMTSActivity_INTERFACE_DEFINED__
#define __IMTSActivity_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMTSActivity;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMTSActivity : public IUnknown {
  public:
    virtual HRESULT WINAPI SynchronousCall(IMTSCall *pCall) = 0;
    virtual HRESULT WINAPI AsyncCall(IMTSCall *pCall) = 0;
    virtual void WINAPI Reserved1(void) = 0;
    virtual HRESULT WINAPI BindToCurrentThread(void) = 0;
    virtual HRESULT WINAPI UnbindFromThread(void) = 0;
  };
#else
  typedef struct IMTSActivityVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMTSActivity *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMTSActivity *This);
      ULONG (WINAPI *Release)(IMTSActivity *This);
      HRESULT (WINAPI *SynchronousCall)(IMTSActivity *This,IMTSCall *pCall);
      HRESULT (WINAPI *AsyncCall)(IMTSActivity *This,IMTSCall *pCall);
      void (WINAPI *Reserved1)(IMTSActivity *This);
      HRESULT (WINAPI *BindToCurrentThread)(IMTSActivity *This);
      HRESULT (WINAPI *UnbindFromThread)(IMTSActivity *This);
    END_INTERFACE
  } IMTSActivityVtbl;
  struct IMTSActivity {
    CONST_VTBL struct IMTSActivityVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMTSActivity_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMTSActivity_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMTSActivity_Release(This) (This)->lpVtbl->Release(This)
#define IMTSActivity_SynchronousCall(This,pCall) (This)->lpVtbl->SynchronousCall(This,pCall)
#define IMTSActivity_AsyncCall(This,pCall) (This)->lpVtbl->AsyncCall(This,pCall)
#define IMTSActivity_Reserved1(This) (This)->lpVtbl->Reserved1(This)
#define IMTSActivity_BindToCurrentThread(This) (This)->lpVtbl->BindToCurrentThread(This)
#define IMTSActivity_UnbindFromThread(This) (This)->lpVtbl->UnbindFromThread(This)
#endif
#endif
  HRESULT WINAPI IMTSActivity_SynchronousCall_Proxy(IMTSActivity *This,IMTSCall *pCall);
  void __RPC_STUB IMTSActivity_SynchronousCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMTSActivity_AsyncCall_Proxy(IMTSActivity *This,IMTSCall *pCall);
  void __RPC_STUB IMTSActivity_AsyncCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI IMTSActivity_Reserved1_Proxy(IMTSActivity *This);
  void __RPC_STUB IMTSActivity_Reserved1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMTSActivity_BindToCurrentThread_Proxy(IMTSActivity *This);
  void __RPC_STUB IMTSActivity_BindToCurrentThread_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMTSActivity_UnbindFromThread_Proxy(IMTSActivity *This);
  void __RPC_STUB IMTSActivity_UnbindFromThread_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __COMSVCSLib_LIBRARY_DEFINED__
#define __COMSVCSLib_LIBRARY_DEFINED__
  typedef enum __MIDL___MIDL_itf_autosvcs_0412_0001 {
    mtsErrCtxAborted = 0x8004e002,mtsErrCtxAborting = 0x8004e003,mtsErrCtxNoContext = 0x8004e004,mtsErrCtxNotRegistered = 0x8004e005,
    mtsErrCtxSynchTimeout = 0x8004e006,mtsErrCtxOldReference = 0x8004e007,mtsErrCtxRoleNotFound = 0x8004e00c,mtsErrCtxNoSecurity = 0x8004e00d,
    mtsErrCtxWrongThread = 0x8004e00e,mtsErrCtxTMNotAvailable = 0x8004e00f,comQCErrApplicationNotQueued = 0x80110600,
    comQCErrNoQueueableInterfaces = 0x80110601,comQCErrQueuingServiceNotAvailable = 0x80110602,comQCErrQueueTransactMismatch = 0x80110603,
    comqcErrRecorderMarshalled = 0x80110604,comqcErrOutParam = 0x80110605,comqcErrRecorderNotTrusted = 0x80110606,comqcErrPSLoad = 0x80110607,
    comqcErrMarshaledObjSameTxn = 0x80110608,comqcErrInvalidMessage = 0x80110650,comqcErrMsmqSidUnavailable = 0x80110651,
    comqcErrWrongMsgExtension = 0x80110652,comqcErrMsmqServiceUnavailable = 0x80110653,comqcErrMsgNotAuthenticated = 0x80110654,
    comqcErrMsmqConnectorUsed = 0x80110655,comqcErrBadMarshaledObject = 0x80110656
  } Error_Constants;

  typedef enum __MIDL___MIDL_itf_autosvcs_0412_0002 {
    LockSetGet = 0,LockMethod = LockSetGet + 1
  } LockModes;

  typedef enum __MIDL___MIDL_itf_autosvcs_0412_0003 {
    Standard = 0,Process = Standard + 1
  } ReleaseModes;

#ifndef _tagCrmFlags_
#define _tagCrmFlags_
  typedef enum tagCRMFLAGS {
    CRMFLAG_FORGETTARGET = 0x1,CRMFLAG_WRITTENDURINGPREPARE = 0x2,CRMFLAG_WRITTENDURINGCOMMIT = 0x4,CRMFLAG_WRITTENDURINGABORT = 0x8,
    CRMFLAG_WRITTENDURINGRECOVERY = 0x10,CRMFLAG_WRITTENDURINGREPLAY = 0x20,CRMFLAG_REPLAYINPROGRESS = 0x40
  } CRMFLAGS;
#endif
#ifndef _tagCrmRegFlags_
#define _tagCrmRegFlags_
  typedef enum tagCRMREGFLAGS {
    CRMREGFLAG_PREPAREPHASE = 0x1,CRMREGFLAG_COMMITPHASE = 0x2,CRMREGFLAG_ABORTPHASE = 0x4,CRMREGFLAG_ALLPHASES = 0x7,
    CRMREGFLAG_FAILIFINDOUBTSREMAIN = 0x10
  } CRMREGFLAGS;
#endif

  EXTERN_C const IID LIBID_COMSVCSLib;
  EXTERN_C const CLSID CLSID_SecurityIdentity;
#ifdef __cplusplus
  class SecurityIdentity;
#endif
  EXTERN_C const CLSID CLSID_SecurityCallers;
#ifdef __cplusplus
  class SecurityCallers;
#endif
  EXTERN_C const CLSID CLSID_SecurityCallContext;
#ifdef __cplusplus
  class SecurityCallContext;
#endif
  EXTERN_C const CLSID CLSID_GetSecurityCallContextAppObject;
#ifdef __cplusplus
  class GetSecurityCallContextAppObject;
#endif
  EXTERN_C const CLSID CLSID_Dummy30040732;
#ifdef __cplusplus
  class Dummy30040732;
#endif
  EXTERN_C const CLSID CLSID_TransactionContext;
#ifdef __cplusplus
  class TransactionContext;
#endif
  EXTERN_C const CLSID CLSID_TransactionContextEx;
#ifdef __cplusplus
  class TransactionContextEx;
#endif
  EXTERN_C const CLSID CLSID_ByotServerEx;
#ifdef __cplusplus
  class ByotServerEx;
#endif
  EXTERN_C const CLSID CLSID_CServiceConfig;
#ifdef __cplusplus
  class CServiceConfig;
#endif
  EXTERN_C const CLSID CLSID_ServicePool;
#ifdef __cplusplus
  class ServicePool;
#endif
  EXTERN_C const CLSID CLSID_ServicePoolConfig;
#ifdef __cplusplus
  class ServicePoolConfig;
#endif
  EXTERN_C const CLSID CLSID_SharedProperty;
#ifdef __cplusplus
  class SharedProperty;
#endif
  EXTERN_C const CLSID CLSID_SharedPropertyGroup;
#ifdef __cplusplus
  class SharedPropertyGroup;
#endif
  EXTERN_C const CLSID CLSID_SharedPropertyGroupManager;
#ifdef __cplusplus
  class SharedPropertyGroupManager;
#endif
  EXTERN_C const CLSID CLSID_COMEvents;
#ifdef __cplusplus
  class COMEvents;
#endif
  EXTERN_C const CLSID CLSID_CoMTSLocator;
#ifdef __cplusplus
  class CoMTSLocator;
#endif
  EXTERN_C const CLSID CLSID_MtsGrp;
#ifdef __cplusplus
  class MtsGrp;
#endif
  EXTERN_C const CLSID CLSID_ComServiceEvents;
#ifdef __cplusplus
  class ComServiceEvents;
#endif
  EXTERN_C const CLSID CLSID_ComSystemAppEventData;
#ifdef __cplusplus
  class ComSystemAppEventData;
#endif
  EXTERN_C const CLSID CLSID_CRMClerk;
#ifdef __cplusplus
  class CRMClerk;
#endif
  EXTERN_C const CLSID CLSID_CRMRecoveryClerk;
#ifdef __cplusplus
  class CRMRecoveryClerk;
#endif
  EXTERN_C const CLSID CLSID_LBEvents;
#ifdef __cplusplus
  class LBEvents;
#endif
  EXTERN_C const CLSID CLSID_MessageMover;
#ifdef __cplusplus
  class MessageMover;
#endif
  EXTERN_C const CLSID CLSID_DispenserManager;
#ifdef __cplusplus
  class DispenserManager;
#endif
  EXTERN_C const CLSID CLSID_PoolMgr;
#ifdef __cplusplus
  class PoolMgr;
#endif
  EXTERN_C const CLSID CLSID_EventServer;
#ifdef __cplusplus
  class EventServer;
#endif
  EXTERN_C const CLSID CLSID_AppDomainHelper;
#ifdef __cplusplus
  class AppDomainHelper;
#endif
  EXTERN_C const CLSID CLSID_ClrAssemblyLocator;
#ifdef __cplusplus
  class ClrAssemblyLocator;
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API LPSAFEARRAY_UserSize(ULONG *,ULONG,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserMarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserUnmarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  void __RPC_API LPSAFEARRAY_UserFree(ULONG *,LPSAFEARRAY *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
