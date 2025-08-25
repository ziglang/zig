/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#if !defined(_INC_COMDEFSP)
#define _INC_COMDEFSP

#include <_mingw.h>

#if !defined(RC_INVOKED) && USE___UUIDOF != 0

#ifndef __cplusplus
#error Native compiler support only available in C++ compiler.
#endif

#ifndef _COM_SMARTPTR_TYPEDEF
#error The header file comdefsp.h requires comdef.h to be included first.
#endif

#if defined(__AsyncIAdviseSink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(AsyncIAdviseSink,__uuidof(AsyncIAdviseSink));
#endif
#if defined(__AsyncIAdviseSink2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(AsyncIAdviseSink2,__uuidof(AsyncIAdviseSink2));
#endif
#if defined(__AsyncIMultiQI_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(AsyncIMultiQI,__uuidof(AsyncIMultiQI));
#endif
#if defined(__AsyncIPipeByte_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(AsyncIPipeByte,__uuidof(AsyncIPipeByte));
#endif
#if defined(__AsyncIPipeDouble_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(AsyncIPipeDouble,__uuidof(AsyncIPipeDouble));
#endif
#if defined(__AsyncIPipeLong_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(AsyncIPipeLong,__uuidof(AsyncIPipeLong));
#endif
#if defined(__AsyncIUnknown_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(AsyncIUnknown,__uuidof(AsyncIUnknown));
#endif
#if defined(__FolderItem_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(FolderItem,__uuidof(FolderItem));
#endif
#if defined(__FolderItemVerb_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(FolderItemVerb,__uuidof(FolderItemVerb));
#endif
#if defined(__FolderItemVerbs_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(FolderItemVerbs,__uuidof(FolderItemVerbs));
#endif
#if defined(__FolderItems_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(FolderItems,__uuidof(FolderItems));
#endif
#if defined(__IAccessible_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAccessible,__uuidof(IAccessible));
#endif
#if defined(__IActiveScript_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScript,__uuidof(IActiveScript));
#endif
#if defined(__IActiveScriptError_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScriptError,__uuidof(IActiveScriptError));
#endif
#if defined(__IActiveScriptParse_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScriptParse,__uuidof(IActiveScriptParse));
#endif
#if defined(__IActiveScriptParseProcedure_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScriptParseProcedure,__uuidof(IActiveScriptParseProcedure));
#endif
#if defined(__IActiveScriptParseProcedureOld_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScriptParseProcedureOld,__uuidof(IActiveScriptParseProcedureOld));
#endif
#if defined(__IActiveScriptSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScriptSite,__uuidof(IActiveScriptSite));
#endif
#if defined(__IActiveScriptSiteInterruptPoll_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScriptSiteInterruptPoll,__uuidof(IActiveScriptSiteInterruptPoll));
#endif
#if defined(__IActiveScriptSiteWindow_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScriptSiteWindow,__uuidof(IActiveScriptSiteWindow));
#endif
#if defined(__IActiveScriptStats_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IActiveScriptStats,__uuidof(IActiveScriptStats));
#endif
#if defined(__IAddrExclusionControl_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAddrExclusionControl,__uuidof(IAddrExclusionControl));
#endif
#if defined(__IAddrTrackingControl_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAddrTrackingControl,__uuidof(IAddrTrackingControl));
#endif
#if defined(__IAdviseSink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAdviseSink,__uuidof(IAdviseSink));
#endif
#if defined(__IAdviseSink2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAdviseSink2,__uuidof(IAdviseSink2));
#endif
#if defined(__IAdviseSinkEx_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAdviseSinkEx,__uuidof(IAdviseSinkEx));
#endif
#if defined(__IAsyncManager_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAsyncManager,__uuidof(IAsyncManager));
#endif
#if defined(__IAsyncRpcChannelBuffer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAsyncRpcChannelBuffer,__uuidof(IAsyncRpcChannelBuffer));
#endif
#if defined(__IAuthenticate_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IAuthenticate,__uuidof(IAuthenticate));
#endif
#if defined(__IBindCtx_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IBindCtx,__uuidof(IBindCtx));
#endif
#if defined(__IBindEventHandler_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IBindEventHandler,__uuidof(IBindEventHandler));
#endif
#if defined(__IBindHost_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IBindHost,__uuidof(IBindHost));
#endif
#if defined(__IBindProtocol_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IBindProtocol,__uuidof(IBindProtocol));
#endif
#if defined(__IBindStatusCallback_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IBindStatusCallback,__uuidof(IBindStatusCallback));
#endif
#if defined(__IBinding_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IBinding,__uuidof(IBinding));
#endif
#if defined(__IBlockingLock_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IBlockingLock,__uuidof(IBlockingLock));
#endif
#if defined(__ICSSFilter_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICSSFilter,__uuidof(ICSSFilter));
#endif
#if defined(__ICSSFilterSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICSSFilterSite,__uuidof(ICSSFilterSite));
#endif
#if defined(__ICallFactory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICallFactory,__uuidof(ICallFactory));
#endif
#if defined(__ICancelMethodCalls_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICancelMethodCalls,__uuidof(ICancelMethodCalls));
#endif
#if defined(__ICatInformation_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICatInformation,__uuidof(ICatInformation));
#endif
#if defined(__ICatRegister_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICatRegister,__uuidof(ICatRegister));
#endif
#if defined(__ICatalogFileInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICatalogFileInfo,__uuidof(ICatalogFileInfo));
#endif
#if defined(__IChannelHook_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IChannelHook,__uuidof(IChannelHook));
#endif
#if defined(__IChannelMgr_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IChannelMgr,__uuidof(IChannelMgr));
#endif
#if defined(__IClassActivator_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IClassActivator,__uuidof(IClassActivator));
#endif
#if defined(__IClassFactory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IClassFactory,__uuidof(IClassFactory));
#endif
#if defined(__IClassFactory2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IClassFactory2,__uuidof(IClassFactory2));
#endif
#if defined(__IClientSecurity_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IClientSecurity,__uuidof(IClientSecurity));
#endif
#if defined(__ICodeInstall_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICodeInstall,__uuidof(ICodeInstall));
#endif
#if defined(__IConnectionPoint_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IConnectionPoint,__uuidof(IConnectionPoint));
#endif
#if defined(__IConnectionPointContainer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IConnectionPointContainer,__uuidof(IConnectionPointContainer));
#endif
#if defined(__IContinue_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IContinue,__uuidof(IContinue));
#endif
#if defined(__IContinueCallback_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IContinueCallback,__uuidof(IContinueCallback));
#endif
#if defined(__ICreateErrorInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICreateErrorInfo,__uuidof(ICreateErrorInfo));
#endif
#if defined(__ICreateTypeInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICreateTypeInfo,__uuidof(ICreateTypeInfo));
#endif
#if defined(__ICreateTypeInfo2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICreateTypeInfo2,__uuidof(ICreateTypeInfo2));
#endif
#if defined(__ICreateTypeLib_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICreateTypeLib,__uuidof(ICreateTypeLib));
#endif
#if defined(__ICreateTypeLib2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICreateTypeLib2,__uuidof(ICreateTypeLib2));
#endif
#if defined(__ICustomDoc_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ICustomDoc,__uuidof(ICustomDoc));
#endif
#if defined(__IDataAdviseHolder_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDataAdviseHolder,__uuidof(IDataAdviseHolder));
#endif
#if defined(__IDataFilter_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDataFilter,__uuidof(IDataFilter));
#endif
#if defined(__IDataObject_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDataObject,__uuidof(IDataObject));
#endif
#if defined(__IDeskBand_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDeskBand,__uuidof(IDeskBand));
#endif
#if defined(__IDirectWriterLock_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDirectWriterLock,__uuidof(IDirectWriterLock));
#endif
#if defined(__IDispError_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDispError,__uuidof(IDispError));
#endif
#if defined(__IDispatch_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDispatch,__uuidof(IDispatch));
#endif
#if defined(__IDispatchEx_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDispatchEx,__uuidof(IDispatchEx));
#endif
#if defined(__IDocHostShowUI_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDocHostShowUI,__uuidof(IDocHostShowUI));
#endif
#if defined(__IDocHostUIHandler_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDocHostUIHandler,__uuidof(IDocHostUIHandler));
#endif
#if defined(__IDockingWindow_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDockingWindow,__uuidof(IDockingWindow));
#endif
#if defined(__IDropSource_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDropSource,__uuidof(IDropSource));
#endif
#if defined(__IDropTarget_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDropTarget,__uuidof(IDropTarget));
#endif
#if defined(__IDummyHICONIncluder_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IDummyHICONIncluder,__uuidof(IDummyHICONIncluder));
#endif
#if defined(__IEncodingFilterFactory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEncodingFilterFactory,__uuidof(IEncodingFilterFactory));
#endif
#if defined(__IEnumCATEGORYINFO_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumCATEGORYINFO,__uuidof(IEnumCATEGORYINFO));
#endif
#if defined(__IEnumChannels_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumChannels,__uuidof(IEnumChannels));
#endif
#if defined(__IEnumCodePage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumCodePage,__uuidof(IEnumCodePage));
#endif
#if defined(__IEnumConnectionPoints_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumConnectionPoints,__uuidof(IEnumConnectionPoints));
#endif
#if defined(__IEnumConnections_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumConnections,__uuidof(IEnumConnections));
#endif
#if defined(__IEnumFORMATETC_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumFORMATETC,__uuidof(IEnumFORMATETC));
#endif
#if defined(__IEnumGUID_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumGUID,__uuidof(IEnumGUID));
#endif
#if defined(__IEnumHLITEM_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumHLITEM,__uuidof(IEnumHLITEM));
#endif
#if defined(__IEnumIDList_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumIDList,__uuidof(IEnumIDList));
#endif
#if defined(__IEnumMoniker_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumMoniker,__uuidof(IEnumMoniker));
#endif
#if defined(__IEnumOLEVERB_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumOLEVERB,__uuidof(IEnumOLEVERB));
#endif
#if defined(__IEnumOleDocumentViews_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumOleDocumentViews,__uuidof(IEnumOleDocumentViews));
#endif
#if defined(__IEnumOleUndoUnits_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumOleUndoUnits,__uuidof(IEnumOleUndoUnits));
#endif
#if defined(__IEnumRfc1766_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumRfc1766,__uuidof(IEnumRfc1766));
#endif
#if defined(__IEnumSTATDATA_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumSTATDATA,__uuidof(IEnumSTATDATA));
#endif
#if defined(__IEnumSTATPROPSETSTG_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumSTATPROPSETSTG,__uuidof(IEnumSTATPROPSETSTG));
#endif
#if defined(__IEnumSTATPROPSTG_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumSTATPROPSTG,__uuidof(IEnumSTATPROPSTG));
#endif
#if defined(__IEnumSTATSTG_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumSTATSTG,__uuidof(IEnumSTATSTG));
#endif
#if defined(__IEnumSTATURL_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumSTATURL,__uuidof(IEnumSTATURL));
#endif
#if defined(__IEnumString_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumString,__uuidof(IEnumString));
#endif
#if defined(__IEnumUnknown_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumUnknown,__uuidof(IEnumUnknown));
#endif
#if defined(__IEnumVARIANT_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IEnumVARIANT,__uuidof(IEnumVARIANT));
#endif
#if defined(__IErrorInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IErrorInfo,__uuidof(IErrorInfo));
#endif
#if defined(__IErrorLog_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IErrorLog,__uuidof(IErrorLog));
#endif
#if defined(__IExtensionServices_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IExtensionServices,__uuidof(IExtensionServices));
#endif
#if defined(__IExternalConnection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IExternalConnection,__uuidof(IExternalConnection));
#endif
#if defined(__IFillLockBytes_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IFillLockBytes,__uuidof(IFillLockBytes));
#endif
#if defined(__IFilter_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IFilter,__uuidof(IFilter));
#endif
#if defined(__IFolderViewOC_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IFolderViewOC,__uuidof(IFolderViewOC));
#endif
#if defined(__IFont_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IFont,__uuidof(IFont));
#endif
#if defined(__IFontDisp_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IFontDisp,__uuidof(IFontDisp));
#endif
#if defined(__IFontEventsDisp_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IFontEventsDisp,__uuidof(IFontEventsDisp));
#endif
#if defined(__IForegroundTransfer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IForegroundTransfer,__uuidof(IForegroundTransfer));
#endif
#if defined(__IGlobalInterfaceTable_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IGlobalInterfaceTable,__uuidof(IGlobalInterfaceTable));
#endif
#if defined(__IHTMLAnchorElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLAnchorElement,__uuidof(IHTMLAnchorElement));
#endif
#if defined(__IHTMLAreaElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLAreaElement,__uuidof(IHTMLAreaElement));
#endif
#if defined(__IHTMLAreasCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLAreasCollection,__uuidof(IHTMLAreasCollection));
#endif
#if defined(__IHTMLBGsound_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLBGsound,__uuidof(IHTMLBGsound));
#endif
#if defined(__IHTMLBRElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLBRElement,__uuidof(IHTMLBRElement));
#endif
#if defined(__IHTMLBaseElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLBaseElement,__uuidof(IHTMLBaseElement));
#endif
#if defined(__IHTMLBaseFontElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLBaseFontElement,__uuidof(IHTMLBaseFontElement));
#endif
#if defined(__IHTMLBlockElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLBlockElement,__uuidof(IHTMLBlockElement));
#endif
#if defined(__IHTMLBodyElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLBodyElement,__uuidof(IHTMLBodyElement));
#endif
#if defined(__IHTMLButtonElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLButtonElement,__uuidof(IHTMLButtonElement));
#endif
#if defined(__IHTMLCommentElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLCommentElement,__uuidof(IHTMLCommentElement));
#endif
#if defined(__IHTMLControlElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLControlElement,__uuidof(IHTMLControlElement));
#endif
#if defined(__IHTMLControlRange_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLControlRange,__uuidof(IHTMLControlRange));
#endif
#if defined(__IHTMLDDElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDDElement,__uuidof(IHTMLDDElement));
#endif
#if defined(__IHTMLDListElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDListElement,__uuidof(IHTMLDListElement));
#endif
#if defined(__IHTMLDTElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDTElement,__uuidof(IHTMLDTElement));
#endif
#if defined(__IHTMLDatabinding_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDatabinding,__uuidof(IHTMLDatabinding));
#endif
#if defined(__IHTMLDialog_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDialog,__uuidof(IHTMLDialog));
#endif
#if defined(__IHTMLDivElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDivElement,__uuidof(IHTMLDivElement));
#endif
#if defined(__IHTMLDivPosition_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDivPosition,__uuidof(IHTMLDivPosition));
#endif
#if defined(__IHTMLDocument_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDocument,__uuidof(IHTMLDocument));
#endif
#if defined(__IHTMLDocument2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLDocument2,__uuidof(IHTMLDocument2));
#endif
#if defined(__IHTMLElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLElement,__uuidof(IHTMLElement));
#endif
#if defined(__IHTMLElementCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLElementCollection,__uuidof(IHTMLElementCollection));
#endif
#if defined(__IHTMLEmbedElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLEmbedElement,__uuidof(IHTMLEmbedElement));
#endif
#if defined(__IHTMLEventObj_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLEventObj,__uuidof(IHTMLEventObj));
#endif
#if defined(__IHTMLFieldSetElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFieldSetElement,__uuidof(IHTMLFieldSetElement));
#endif
#if defined(__IHTMLFiltersCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFiltersCollection,__uuidof(IHTMLFiltersCollection));
#endif
#if defined(__IHTMLFontElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFontElement,__uuidof(IHTMLFontElement));
#endif
#if defined(__IHTMLFontNamesCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFontNamesCollection,__uuidof(IHTMLFontNamesCollection));
#endif
#if defined(__IHTMLFontSizesCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFontSizesCollection,__uuidof(IHTMLFontSizesCollection));
#endif
#if defined(__IHTMLFormElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFormElement,__uuidof(IHTMLFormElement));
#endif
#if defined(__IHTMLFrameBase_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFrameBase,__uuidof(IHTMLFrameBase));
#endif
#if defined(__IHTMLFrameElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFrameElement,__uuidof(IHTMLFrameElement));
#endif
#if defined(__IHTMLFrameSetElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFrameSetElement,__uuidof(IHTMLFrameSetElement));
#endif
#if defined(__IHTMLFramesCollection2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLFramesCollection2,__uuidof(IHTMLFramesCollection2));
#endif
#if defined(__IHTMLHRElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLHRElement,__uuidof(IHTMLHRElement));
#endif
#if defined(__IHTMLHeaderElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLHeaderElement,__uuidof(IHTMLHeaderElement));
#endif
#if defined(__IHTMLIFrameElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLIFrameElement,__uuidof(IHTMLIFrameElement));
#endif
#if defined(__IHTMLImageElementFactory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLImageElementFactory,__uuidof(IHTMLImageElementFactory));
#endif
#if defined(__IHTMLImgElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLImgElement,__uuidof(IHTMLImgElement));
#endif
#if defined(__IHTMLInputButtonElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLInputButtonElement,__uuidof(IHTMLInputButtonElement));
#endif
#if defined(__IHTMLInputFileElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLInputFileElement,__uuidof(IHTMLInputFileElement));
#endif
#if defined(__IHTMLInputHiddenElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLInputHiddenElement,__uuidof(IHTMLInputHiddenElement));
#endif
#if defined(__IHTMLInputImage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLInputImage,__uuidof(IHTMLInputImage));
#endif
#if defined(__IHTMLInputTextElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLInputTextElement,__uuidof(IHTMLInputTextElement));
#endif
#if defined(__IHTMLIsIndexElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLIsIndexElement,__uuidof(IHTMLIsIndexElement));
#endif
#if defined(__IHTMLLIElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLLIElement,__uuidof(IHTMLLIElement));
#endif
#if defined(__IHTMLLabelElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLLabelElement,__uuidof(IHTMLLabelElement));
#endif
#if defined(__IHTMLLegendElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLLegendElement,__uuidof(IHTMLLegendElement));
#endif
#if defined(__IHTMLLinkElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLLinkElement,__uuidof(IHTMLLinkElement));
#endif
#if defined(__IHTMLListElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLListElement,__uuidof(IHTMLListElement));
#endif
#if defined(__IHTMLLocation_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLLocation,__uuidof(IHTMLLocation));
#endif
#if defined(__IHTMLMapElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLMapElement,__uuidof(IHTMLMapElement));
#endif
#if defined(__IHTMLMarqueeElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLMarqueeElement,__uuidof(IHTMLMarqueeElement));
#endif
#if defined(__IHTMLMetaElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLMetaElement,__uuidof(IHTMLMetaElement));
#endif
#if defined(__IHTMLMimeTypesCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLMimeTypesCollection,__uuidof(IHTMLMimeTypesCollection));
#endif
#if defined(__IHTMLNextIdElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLNextIdElement,__uuidof(IHTMLNextIdElement));
#endif
#if defined(__IHTMLNoShowElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLNoShowElement,__uuidof(IHTMLNoShowElement));
#endif
#if defined(__IHTMLOListElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLOListElement,__uuidof(IHTMLOListElement));
#endif
#if defined(__IHTMLObjectElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLObjectElement,__uuidof(IHTMLObjectElement));
#endif
#if defined(__IHTMLOpsProfile_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLOpsProfile,__uuidof(IHTMLOpsProfile));
#endif
#if defined(__IHTMLOptionButtonElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLOptionButtonElement,__uuidof(IHTMLOptionButtonElement));
#endif
#if defined(__IHTMLOptionElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLOptionElement,__uuidof(IHTMLOptionElement));
#endif
#if defined(__IHTMLOptionElementFactory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLOptionElementFactory,__uuidof(IHTMLOptionElementFactory));
#endif
#if defined(__IHTMLOptionsHolder_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLOptionsHolder,__uuidof(IHTMLOptionsHolder));
#endif
#if defined(__IHTMLParaElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLParaElement,__uuidof(IHTMLParaElement));
#endif
#if defined(__IHTMLPhraseElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLPhraseElement,__uuidof(IHTMLPhraseElement));
#endif
#if defined(__IHTMLPluginsCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLPluginsCollection,__uuidof(IHTMLPluginsCollection));
#endif
#if defined(__IHTMLRuleStyle_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLRuleStyle,__uuidof(IHTMLRuleStyle));
#endif
#if defined(__IHTMLScreen_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLScreen,__uuidof(IHTMLScreen));
#endif
#if defined(__IHTMLScriptElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLScriptElement,__uuidof(IHTMLScriptElement));
#endif
#if defined(__IHTMLSelectElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLSelectElement,__uuidof(IHTMLSelectElement));
#endif
#if defined(__IHTMLSelectionObject_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLSelectionObject,__uuidof(IHTMLSelectionObject));
#endif
#if defined(__IHTMLSpanElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLSpanElement,__uuidof(IHTMLSpanElement));
#endif
#if defined(__IHTMLSpanFlow_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLSpanFlow,__uuidof(IHTMLSpanFlow));
#endif
#if defined(__IHTMLStyle_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLStyle,__uuidof(IHTMLStyle));
#endif
#if defined(__IHTMLStyleElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLStyleElement,__uuidof(IHTMLStyleElement));
#endif
#if defined(__IHTMLStyleFontFace_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLStyleFontFace,__uuidof(IHTMLStyleFontFace));
#endif
#if defined(__IHTMLStyleSheet_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLStyleSheet,__uuidof(IHTMLStyleSheet));
#endif
#if defined(__IHTMLStyleSheetRule_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLStyleSheetRule,__uuidof(IHTMLStyleSheetRule));
#endif
#if defined(__IHTMLStyleSheetRulesCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLStyleSheetRulesCollection,__uuidof(IHTMLStyleSheetRulesCollection));
#endif
#if defined(__IHTMLStyleSheetsCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLStyleSheetsCollection,__uuidof(IHTMLStyleSheetsCollection));
#endif
#if defined(__IHTMLTable_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTable,__uuidof(IHTMLTable));
#endif
#if defined(__IHTMLTableCaption_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTableCaption,__uuidof(IHTMLTableCaption));
#endif
#if defined(__IHTMLTableCell_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTableCell,__uuidof(IHTMLTableCell));
#endif
#if defined(__IHTMLTableCol_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTableCol,__uuidof(IHTMLTableCol));
#endif
#if defined(__IHTMLTableRow_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTableRow,__uuidof(IHTMLTableRow));
#endif
#if defined(__IHTMLTableSection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTableSection,__uuidof(IHTMLTableSection));
#endif
#if defined(__IHTMLTextAreaElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTextAreaElement,__uuidof(IHTMLTextAreaElement));
#endif
#if defined(__IHTMLTextContainer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTextContainer,__uuidof(IHTMLTextContainer));
#endif
#if defined(__IHTMLTextElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTextElement,__uuidof(IHTMLTextElement));
#endif
#if defined(__IHTMLTitleElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTitleElement,__uuidof(IHTMLTitleElement));
#endif
#if defined(__IHTMLTxtRange_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLTxtRange,__uuidof(IHTMLTxtRange));
#endif
#if defined(__IHTMLUListElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLUListElement,__uuidof(IHTMLUListElement));
#endif
#if defined(__IHTMLUnknownElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLUnknownElement,__uuidof(IHTMLUnknownElement));
#endif
#if defined(__IHTMLWindow2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHTMLWindow2,__uuidof(IHTMLWindow2));
#endif
#if defined(__IHlink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHlink,__uuidof(IHlink));
#endif
#if defined(__IHlinkBrowseContext_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHlinkBrowseContext,__uuidof(IHlinkBrowseContext));
#endif
#if defined(__IHlinkFrame_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHlinkFrame,__uuidof(IHlinkFrame));
#endif
#if defined(__IHlinkSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHlinkSite,__uuidof(IHlinkSite));
#endif
#if defined(__IHlinkTarget_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHlinkTarget,__uuidof(IHlinkTarget));
#endif
#if defined(__IHttpNegotiate_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHttpNegotiate,__uuidof(IHttpNegotiate));
#endif
#if defined(__IHttpNegotiate2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHttpNegotiate2,__uuidof(IHttpNegotiate2));
#endif
#if defined(__IHttpSecurity_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IHttpSecurity,__uuidof(IHttpSecurity));
#endif
#if defined(__IImageDecodeEventSink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IImageDecodeEventSink,__uuidof(IImageDecodeEventSink));
#endif
#if defined(__IImageDecodeFilter_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IImageDecodeFilter,__uuidof(IImageDecodeFilter));
#endif
#if defined(__IInternalUnknown_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternalUnknown,__uuidof(IInternalUnknown));
#endif
#if defined(__IInternet_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternet,__uuidof(IInternet));
#endif
#if defined(__IInternetBindInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetBindInfo,__uuidof(IInternetBindInfo));
#endif
#if defined(__IInternetHostSecurityManager_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetHostSecurityManager,__uuidof(IInternetHostSecurityManager));
#endif
#if defined(__IInternetPriority_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetPriority,__uuidof(IInternetPriority));
#endif
#if defined(__IInternetProtocol_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetProtocol,__uuidof(IInternetProtocol));
#endif
#if defined(__IInternetProtocolInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetProtocolInfo,__uuidof(IInternetProtocolInfo));
#endif
#if defined(__IInternetProtocolRoot_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetProtocolRoot,__uuidof(IInternetProtocolRoot));
#endif
#if defined(__IInternetProtocolSink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetProtocolSink,__uuidof(IInternetProtocolSink));
#endif
#if defined(__IInternetProtocolSinkStackable_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetProtocolSinkStackable,__uuidof(IInternetProtocolSinkStackable));
#endif
#if defined(__IInternetSecurityManager_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetSecurityManager,__uuidof(IInternetSecurityManager));
#endif
#if defined(__IInternetSecurityMgrSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetSecurityMgrSite,__uuidof(IInternetSecurityMgrSite));
#endif
#if defined(__IInternetSession_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetSession,__uuidof(IInternetSession));
#endif
#if defined(__IInternetThreadSwitch_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetThreadSwitch,__uuidof(IInternetThreadSwitch));
#endif
#if defined(__IInternetZoneManager_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IInternetZoneManager,__uuidof(IInternetZoneManager));
#endif
#if defined(__ILayoutStorage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ILayoutStorage,__uuidof(ILayoutStorage));
#endif
#if defined(__ILockBytes_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ILockBytes,__uuidof(ILockBytes));
#endif
#if defined(__IMLangCodePages_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangCodePages,__uuidof(IMLangCodePages));
#endif
#if defined(__IMLangConvertCharset_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangConvertCharset,__uuidof(IMLangConvertCharset));
#endif
#if defined(__IMLangFontLink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangFontLink,__uuidof(IMLangFontLink));
#endif
#if defined(__IMLangLineBreakConsole_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangLineBreakConsole,__uuidof(IMLangLineBreakConsole));
#endif
#if defined(__IMLangString_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangString,__uuidof(IMLangString));
#endif
#if defined(__IMLangStringAStr_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangStringAStr,__uuidof(IMLangStringAStr));
#endif
#if defined(__IMLangStringBufA_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangStringBufA,__uuidof(IMLangStringBufA));
#endif
#if defined(__IMLangStringBufW_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangStringBufW,__uuidof(IMLangStringBufW));
#endif
#if defined(__IMLangStringWStr_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMLangStringWStr,__uuidof(IMLangStringWStr));
#endif
#if defined(__IMalloc_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMalloc,__uuidof(IMalloc));
#endif
#if defined(__IMallocSpy_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMallocSpy,__uuidof(IMallocSpy));
#endif
#if defined(__IMapMIMEToCLSID_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMapMIMEToCLSID,__uuidof(IMapMIMEToCLSID));
#endif
#if defined(__IMarshal_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMarshal,__uuidof(IMarshal));
#endif
#if defined(__IMarshal2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMarshal2,__uuidof(IMarshal2));
#endif
#if defined(__IMessageFilter_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMessageFilter,__uuidof(IMessageFilter));
#endif
#if defined(__IMimeInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMimeInfo,__uuidof(IMimeInfo));
#endif
#if defined(__IMoniker_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMoniker,__uuidof(IMoniker));
#endif
#if defined(__IMonikerProp_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMonikerProp,__uuidof(IMonikerProp));
#endif
#if defined(__IMultiLanguage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMultiLanguage,__uuidof(IMultiLanguage));
#endif
#if defined(__IMultiQI_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IMultiQI,__uuidof(IMultiQI));
#endif
#if defined(__IObjectIdentity_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IObjectIdentity,__uuidof(IObjectIdentity));
#endif
#if defined(__IObjectSafety_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IObjectSafety,__uuidof(IObjectSafety));
#endif
#if defined(__IObjectWithSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IObjectWithSite,__uuidof(IObjectWithSite));
#endif
#if defined(__IOleAdviseHolder_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleAdviseHolder,__uuidof(IOleAdviseHolder));
#endif
#if defined(__IOleCache_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleCache,__uuidof(IOleCache));
#endif
#if defined(__IOleCache2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleCache2,__uuidof(IOleCache2));
#endif
#if defined(__IOleCacheControl_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleCacheControl,__uuidof(IOleCacheControl));
#endif
#if defined(__IOleClientSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleClientSite,__uuidof(IOleClientSite));
#endif
#if defined(__IOleCommandTarget_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleCommandTarget,__uuidof(IOleCommandTarget));
#endif
#if defined(__IOleContainer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleContainer,__uuidof(IOleContainer));
#endif
#if defined(__IOleControl_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleControl,__uuidof(IOleControl));
#endif
#if defined(__IOleControlSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleControlSite,__uuidof(IOleControlSite));
#endif
#if defined(__IOleDocument_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleDocument,__uuidof(IOleDocument));
#endif
#if defined(__IOleDocumentSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleDocumentSite,__uuidof(IOleDocumentSite));
#endif
#if defined(__IOleDocumentView_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleDocumentView,__uuidof(IOleDocumentView));
#endif
#if defined(__IOleInPlaceActiveObject_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleInPlaceActiveObject,__uuidof(IOleInPlaceActiveObject));
#endif
#if defined(__IOleInPlaceFrame_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleInPlaceFrame,__uuidof(IOleInPlaceFrame));
#endif
#if defined(__IOleInPlaceObject_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleInPlaceObject,__uuidof(IOleInPlaceObject));
#endif
#if defined(__IOleInPlaceObjectWindowless_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleInPlaceObjectWindowless,__uuidof(IOleInPlaceObjectWindowless));
#endif
#if defined(__IOleInPlaceSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleInPlaceSite,__uuidof(IOleInPlaceSite));
#endif
#if defined(__IOleInPlaceSiteEx_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleInPlaceSiteEx,__uuidof(IOleInPlaceSiteEx));
#endif
#if defined(__IOleInPlaceSiteWindowless_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleInPlaceSiteWindowless,__uuidof(IOleInPlaceSiteWindowless));
#endif
#if defined(__IOleInPlaceUIWindow_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleInPlaceUIWindow,__uuidof(IOleInPlaceUIWindow));
#endif
#if defined(__IOleItemContainer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleItemContainer,__uuidof(IOleItemContainer));
#endif
#if defined(__IOleLink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleLink,__uuidof(IOleLink));
#endif
#if defined(__IOleObject_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleObject,__uuidof(IOleObject));
#endif
#if defined(__IOleParentUndoUnit_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleParentUndoUnit,__uuidof(IOleParentUndoUnit));
#endif
#if defined(__IOleUndoManager_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleUndoManager,__uuidof(IOleUndoManager));
#endif
#if defined(__IOleUndoUnit_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleUndoUnit,__uuidof(IOleUndoUnit));
#endif
#if defined(__IOleWindow_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOleWindow,__uuidof(IOleWindow));
#endif
#if defined(__IOmHistory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOmHistory,__uuidof(IOmHistory));
#endif
#if defined(__IOmNavigator_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOmNavigator,__uuidof(IOmNavigator));
#endif
#if defined(__IOplockStorage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IOplockStorage,__uuidof(IOplockStorage));
#endif
#if defined(__IPSFactoryBuffer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPSFactoryBuffer,__uuidof(IPSFactoryBuffer));
#endif
#if defined(__IParseDisplayName_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IParseDisplayName,__uuidof(IParseDisplayName));
#endif
#if defined(__IPerPropertyBrowsing_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPerPropertyBrowsing,__uuidof(IPerPropertyBrowsing));
#endif
#if defined(__IPersist_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersist,__uuidof(IPersist));
#endif
#if defined(__IPersistFile_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistFile,__uuidof(IPersistFile));
#endif
#if defined(__IPersistFolder_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistFolder,__uuidof(IPersistFolder));
#endif
#if defined(__IPersistFolder2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistFolder2,__uuidof(IPersistFolder2));
#endif
#if defined(__IPersistHistory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistHistory,__uuidof(IPersistHistory));
#endif
#if defined(__IPersistMemory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistMemory,__uuidof(IPersistMemory));
#endif
#if defined(__IPersistMoniker_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistMoniker,__uuidof(IPersistMoniker));
#endif
#if defined(__IPersistPropertyBag_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistPropertyBag,__uuidof(IPersistPropertyBag));
#endif
#if defined(__IPersistPropertyBag2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistPropertyBag2,__uuidof(IPersistPropertyBag2));
#endif
#if defined(__IPersistStorage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistStorage,__uuidof(IPersistStorage));
#endif
#if defined(__IPersistStream_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistStream,__uuidof(IPersistStream));
#endif
#if defined(__IPersistStreamInit_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPersistStreamInit,__uuidof(IPersistStreamInit));
#endif
#if defined(__IPicture_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPicture,__uuidof(IPicture));
#endif
#if defined(__IPictureDisp_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPictureDisp,__uuidof(IPictureDisp));
#endif
#if defined(__IPipeByte_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPipeByte,__uuidof(IPipeByte));
#endif
#if defined(__IPipeDouble_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPipeDouble,__uuidof(IPipeDouble));
#endif
#if defined(__IPipeLong_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPipeLong,__uuidof(IPipeLong));
#endif
#if defined(__IPointerInactive_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPointerInactive,__uuidof(IPointerInactive));
#endif
#if defined(__IPrint_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPrint,__uuidof(IPrint));
#endif
#if defined(__IProgressNotify_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IProgressNotify,__uuidof(IProgressNotify));
#endif
#if defined(__IPropertyBag_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPropertyBag,__uuidof(IPropertyBag));
#endif
#if defined(__IPropertyBag2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPropertyBag2,__uuidof(IPropertyBag2));
#endif
#if defined(__IPropertyNotifySink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPropertyNotifySink,__uuidof(IPropertyNotifySink));
#endif
#if defined(__IPropertyPage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPropertyPage,__uuidof(IPropertyPage));
#endif
#if defined(__IPropertyPage2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPropertyPage2,__uuidof(IPropertyPage2));
#endif
#if defined(__IPropertyPageSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPropertyPageSite,__uuidof(IPropertyPageSite));
#endif
#if defined(__IPropertySetStorage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPropertySetStorage,__uuidof(IPropertySetStorage));
#endif
#if defined(__IPropertyStorage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IPropertyStorage,__uuidof(IPropertyStorage));
#endif
#if defined(__IProvideClassInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IProvideClassInfo,__uuidof(IProvideClassInfo));
#endif
#if defined(__IProvideClassInfo2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IProvideClassInfo2,__uuidof(IProvideClassInfo2));
#endif
#if defined(__IProvideMultipleClassInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IProvideMultipleClassInfo,__uuidof(IProvideMultipleClassInfo));
#endif
#if defined(__IQuickActivate_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IQuickActivate,__uuidof(IQuickActivate));
#endif
#if defined(__IROTData_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IROTData,__uuidof(IROTData));
#endif
#if defined(__IRecordInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRecordInfo,__uuidof(IRecordInfo));
#endif
#if defined(__IReleaseMarshalBuffers_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IReleaseMarshalBuffers,__uuidof(IReleaseMarshalBuffers));
#endif
#if defined(__IRootStorage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRootStorage,__uuidof(IRootStorage));
#endif
#if defined(__IRpcChannelBuffer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRpcChannelBuffer,__uuidof(IRpcChannelBuffer));
#endif
#if defined(__IRpcChannelBuffer2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRpcChannelBuffer2,__uuidof(IRpcChannelBuffer2));
#endif
#if defined(__IRpcChannelBuffer3_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRpcChannelBuffer3,__uuidof(IRpcChannelBuffer3));
#endif
#if defined(__IRpcHelper_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRpcHelper,__uuidof(IRpcHelper));
#endif
#if defined(__IRpcOptions_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRpcOptions,__uuidof(IRpcOptions));
#endif
#if defined(__IRpcProxyBuffer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRpcProxyBuffer,__uuidof(IRpcProxyBuffer));
#endif
#if defined(__IRpcStubBuffer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRpcStubBuffer,__uuidof(IRpcStubBuffer));
#endif
#if defined(__IRpcSyntaxNegotiate_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRpcSyntaxNegotiate,__uuidof(IRpcSyntaxNegotiate));
#endif
#if defined(__IRunnableObject_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRunnableObject,__uuidof(IRunnableObject));
#endif
#if defined(__IRunningObjectTable_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IRunningObjectTable,__uuidof(IRunningObjectTable));
#endif
#if defined(__ISequentialStream_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISequentialStream,__uuidof(ISequentialStream));
#endif
#if defined(__IServerSecurity_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IServerSecurity,__uuidof(IServerSecurity));
#endif
#if defined(__IServiceProvider_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IServiceProvider,__uuidof(IServiceProvider));
#endif
#if defined(__IShellBrowser_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellBrowser,__uuidof(IShellBrowser));
#endif
#if defined(__IShellDispatch_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellDispatch,__uuidof(IShellDispatch));
#endif
#if defined(__IShellExtInit_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellExtInit,__uuidof(IShellExtInit));
#endif
#if defined(__IShellFolder_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellFolder,__uuidof(IShellFolder));
#endif
#if defined(__IShellFolderViewDual_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellFolderViewDual,__uuidof(IShellFolderViewDual));
#endif
#if defined(__IShellLinkA_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellLinkA,__uuidof(IShellLinkA));
#endif
#if defined(__IShellLinkDual_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellLinkDual,__uuidof(IShellLinkDual));
#endif
#if defined(__IShellLinkW_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellLinkW,__uuidof(IShellLinkW));
#endif
#if defined(__IShellPropSheetExt_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellPropSheetExt,__uuidof(IShellPropSheetExt));
#endif
#if defined(__IShellUIHelper_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellUIHelper,__uuidof(IShellUIHelper));
#endif
#if defined(__IShellView_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellView,__uuidof(IShellView));
#endif
#if defined(__IShellView2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellView2,__uuidof(IShellView2));
#endif
#if defined(__IShellWindows_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IShellWindows,__uuidof(IShellWindows));
#endif
#if defined(__ISimpleFrameSite_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISimpleFrameSite,__uuidof(ISimpleFrameSite));
#endif
#if defined(__ISoftDistExt_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISoftDistExt,__uuidof(ISoftDistExt));
#endif
#if defined(__ISpecifyPropertyPages_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISpecifyPropertyPages,__uuidof(ISpecifyPropertyPages));
#endif
#if defined(__IStdMarshalInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IStdMarshalInfo,__uuidof(IStdMarshalInfo));
#endif
#if defined(__IStorage_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IStorage,__uuidof(IStorage));
#endif
#if defined(__IStream_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IStream,__uuidof(IStream));
#endif
#if defined(__ISubscriptionMgr_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISubscriptionMgr,__uuidof(ISubscriptionMgr));
#endif
#if defined(__ISupportErrorInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISupportErrorInfo,__uuidof(ISupportErrorInfo));
#endif
#if defined(__ISurrogate_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISurrogate,__uuidof(ISurrogate));
#endif
#if defined(__ISynchronize_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISynchronize,__uuidof(ISynchronize));
#endif
#if defined(__ISynchronizeContainer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISynchronizeContainer,__uuidof(ISynchronizeContainer));
#endif
#if defined(__ISynchronizeEvent_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISynchronizeEvent,__uuidof(ISynchronizeEvent));
#endif
#if defined(__ISynchronizeHandle_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISynchronizeHandle,__uuidof(ISynchronizeHandle));
#endif
#if defined(__ISynchronizeMutex_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ISynchronizeMutex,__uuidof(ISynchronizeMutex));
#endif
#if defined(__IThumbnailExtractor_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IThumbnailExtractor,__uuidof(IThumbnailExtractor));
#endif
#if defined(__ITimeAndNoticeControl_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITimeAndNoticeControl,__uuidof(ITimeAndNoticeControl));
#endif
#if defined(__ITimer_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITimer,__uuidof(ITimer));
#endif
#if defined(__ITimerService_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITimerService,__uuidof(ITimerService));
#endif
#if defined(__ITimerSink_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITimerSink,__uuidof(ITimerSink));
#endif
#if defined(__ITypeChangeEvents_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITypeChangeEvents,__uuidof(ITypeChangeEvents));
#endif
#if defined(__ITypeComp_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITypeComp,__uuidof(ITypeComp));
#endif
#if defined(__ITypeFactory_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITypeFactory,__uuidof(ITypeFactory));
#endif
#if defined(__ITypeInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITypeInfo,__uuidof(ITypeInfo));
#endif
#if defined(__ITypeInfo2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITypeInfo2,__uuidof(ITypeInfo2));
#endif
#if defined(__ITypeLib_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITypeLib,__uuidof(ITypeLib));
#endif
#if defined(__ITypeLib2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITypeLib2,__uuidof(ITypeLib2));
#endif
#if defined(__ITypeMarshal_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(ITypeMarshal,__uuidof(ITypeMarshal));
#endif
#if defined(__IUnknown_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IUnknown,__uuidof(IUnknown));
#endif
#if defined(__IUrlHistoryNotify_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IUrlHistoryNotify,__uuidof(IUrlHistoryNotify));
#endif
#if defined(__IUrlHistoryStg_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IUrlHistoryStg,__uuidof(IUrlHistoryStg));
#endif
#if defined(__IUrlHistoryStg2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IUrlHistoryStg2,__uuidof(IUrlHistoryStg2));
#endif
#if defined(__IUrlMon_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IUrlMon,__uuidof(IUrlMon));
#endif
#if defined(__IVariantChangeType_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IVariantChangeType,__uuidof(IVariantChangeType));
#endif
#if defined(__IViewObject_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IViewObject,__uuidof(IViewObject));
#endif
#if defined(__IViewObject2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IViewObject2,__uuidof(IViewObject2));
#endif
#if defined(__IViewObjectEx_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IViewObjectEx,__uuidof(IViewObjectEx));
#endif
#if defined(__IWaitMultiple_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IWaitMultiple,__uuidof(IWaitMultiple));
#endif
#if defined(__IWebBrowser_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IWebBrowser,__uuidof(IWebBrowser));
#endif
#if defined(__IWebBrowser2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IWebBrowser2,__uuidof(IWebBrowser2));
#endif
#if defined(__IWebBrowserApp_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IWebBrowserApp,__uuidof(IWebBrowserApp));
#endif
#if defined(__IWinInetHttpInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IWinInetHttpInfo,__uuidof(IWinInetHttpInfo));
#endif
#if defined(__IWinInetInfo_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IWinInetInfo,__uuidof(IWinInetInfo));
#endif
#if defined(__IWindowForBindingUI_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IWindowForBindingUI,__uuidof(IWindowForBindingUI));
#endif
#if defined(__IWrappedProtocol_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IWrappedProtocol,__uuidof(IWrappedProtocol));
#endif
#if defined(__IXMLAttribute_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLAttribute,__uuidof(IXMLAttribute));
#endif
#if defined(__IXMLDOMAttribute_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMAttribute,__uuidof(IXMLDOMAttribute));
#endif
#if defined(__IXMLDOMCDATASection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMCDATASection,__uuidof(IXMLDOMCDATASection));
#endif
#if defined(__IXMLDOMCharacterData_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMCharacterData,__uuidof(IXMLDOMCharacterData));
#endif
#if defined(__IXMLDOMComment_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMComment,__uuidof(IXMLDOMComment));
#endif
#if defined(__IXMLDOMDocument_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMDocument,__uuidof(IXMLDOMDocument));
#endif
#if defined(__IXMLDOMDocumentFragment_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMDocumentFragment,__uuidof(IXMLDOMDocumentFragment));
#endif
#if defined(__IXMLDOMDocumentType_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMDocumentType,__uuidof(IXMLDOMDocumentType));
#endif
#if defined(__IXMLDOMElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMElement,__uuidof(IXMLDOMElement));
#endif
#if defined(__IXMLDOMEntity_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMEntity,__uuidof(IXMLDOMEntity));
#endif
#if defined(__IXMLDOMEntityReference_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMEntityReference,__uuidof(IXMLDOMEntityReference));
#endif
#if defined(__IXMLDOMImplementation_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMImplementation,__uuidof(IXMLDOMImplementation));
#endif
#if defined(__IXMLDOMNamedNodeMap_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMNamedNodeMap,__uuidof(IXMLDOMNamedNodeMap));
#endif
#if defined(__IXMLDOMNode_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMNode,__uuidof(IXMLDOMNode));
#endif
#if defined(__IXMLDOMNodeList_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMNodeList,__uuidof(IXMLDOMNodeList));
#endif
#if defined(__IXMLDOMNotation_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMNotation,__uuidof(IXMLDOMNotation));
#endif
#if defined(__IXMLDOMParseError_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMParseError,__uuidof(IXMLDOMParseError));
#endif
#if defined(__IXMLDOMProcessingInstruction_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMProcessingInstruction,__uuidof(IXMLDOMProcessingInstruction));
#endif
#if defined(__IXMLDOMText_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDOMText,__uuidof(IXMLDOMText));
#endif
#if defined(__IXMLDSOControl_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDSOControl,__uuidof(IXMLDSOControl));
#endif
#if defined(__IXMLDocument_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDocument,__uuidof(IXMLDocument));
#endif
#if defined(__IXMLDocument2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLDocument2,__uuidof(IXMLDocument2));
#endif
#if defined(__IXMLElement_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLElement,__uuidof(IXMLElement));
#endif
#if defined(__IXMLElement2_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLElement2,__uuidof(IXMLElement2));
#endif
#if defined(__IXMLElementCollection_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLElementCollection,__uuidof(IXMLElementCollection));
#endif
#if defined(__IXMLError_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLError,__uuidof(IXMLError));
#endif
#if defined(__IXMLHttpRequest_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXMLHttpRequest,__uuidof(IXMLHttpRequest));
#endif
#if defined(__IXTLRuntime_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(IXTLRuntime,__uuidof(IXTLRuntime));
#endif
#if defined(__OLEDBSimpleProvider_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(OLEDBSimpleProvider,__uuidof(OLEDBSimpleProvider));
#endif
#if defined(__OLEDBSimpleProviderListener_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(OLEDBSimpleProviderListener,__uuidof(OLEDBSimpleProviderListener));
#endif
#if defined(__XMLDOMDocumentEvents_INTERFACE_DEFINED__)
_COM_SMARTPTR_TYPEDEF(XMLDOMDocumentEvents,__uuidof(XMLDOMDocumentEvents));
#endif

#if defined(__DOMDocument_FWD_DEFINED__)
_COM_SMARTPTR_TYPEDEF(DOMDocument,__uuidof(DOMDocument));
#endif
#if defined(__DOMFreeThreadedDocument_FWD_DEFINED__)
_COM_SMARTPTR_TYPEDEF(DOMFreeThreadedDocument,__uuidof(DOMFreeThreadedDocument));
#endif
#if defined(__XMLDSOControl_FWD_DEFINED__)
_COM_SMARTPTR_TYPEDEF(XMLDSOControl,__uuidof(XMLDSOControl));
#endif
#if defined(__XMLDocument_FWD_DEFINED__)
_COM_SMARTPTR_TYPEDEF(XMLDocument,__uuidof(XMLDocument));
#endif
#if defined(__XMLHTTPRequest_FWD_DEFINED__)
_COM_SMARTPTR_TYPEDEF(XMLHTTPRequest,__uuidof(XMLHTTPRequest));
#endif
#endif
#endif
