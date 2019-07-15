/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __DBDAO_H_
#define __DBDAO_H_

#ifndef __cplusplus
#error This file can be used only in C++
#else

class COleVariant;
class CdbBookmark;
class CdbException;
class CdbOleObject;
class CdbObject;
class CdbError;
class CdbProperty;
class CdbDBEngine;
class CdbWorkspace;
class CdbDatabase;
class CdbConnection;
class CdbRecordset;
class CdbGetRowsEx;
class CdbQueryDef;
class CdbTableDef;
class CdbField;
class CdbRelation;
class CdbIndex;
class CdbUser;
class CdbGroup;
class CdbDocument;
class CdbContainer;
class CdbParameter;
class CdbCollection;
class CdbErrors;
class CdbProperties;
class CdbWorkspaces;
class CdbDatabases;
class CdbConnections;
class CdbRecordsets;
class CdbQueryDefs;
class CdbTableDefs;
class CdbFields;
class CdbRelations;
class CdbIndexes;
class CdbUsers;
class CdbGroups;
class CdbDocuments;
class CdbContainers;
class CdbParameters;
class CdbBStr;

const char szKEY[] = "mbmabptebkjcdlgtjmskjwtsdhjbmkmwtrak";

#define DAO_MAXSEEKFIELDS 13

class DLLEXPORT CdbBSTR {
public:
  CONSTRUCTOR CdbBSTR(BSTR=NULL);
  DESTRUCTOR ~CdbBSTR(VOID);
  operator BSTR *(VOID);
  operator LPCTSTR(VOID);
private:
  BSTR m_bstr;
};

class CdbVariant : public COleVariant {
public:
  CONSTRUCTOR CdbVariant(LONG l);
  CONSTRUCTOR CdbVariant(VOID);
  CONSTRUCTOR CdbVariant(LPCTSTR pstr);
  CONSTRUCTOR CdbVariant(SHORT s,WINBOOL bIsBool = FALSE);
  CONSTRUCTOR CdbVariant(LPVARIANT pv);
  CONSTRUCTOR CdbVariant(LPSAFEARRAY psa);
  VOID operator =(LPVARIANT pv);
  VOID operator =(LPCTSTR pstr);
  VOID operator =(SHORT s);
  VOID operator =(const int i);
  VOID operator =(LONG l);
};

inline CONSTRUCTOR CdbVariant::CdbVariant(VOID) : COleVariant() {
  vt = VT_ERROR;
  scode = DISP_E_PARAMNOTFOUND;
}

inline CdbVariant::CdbVariant(LONG l) {
  if(l==-1) {
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  } else {
    vt = VT_I4;
    lVal = l;
  }
}

inline CONSTRUCTOR CdbVariant::CdbVariant(LPCTSTR pstr): COleVariant(pstr,VT_BSTRT) {
  if(!pstr) {
    VariantClear(this);
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  }
}

inline CONSTRUCTOR CdbVariant::CdbVariant(SHORT s,WINBOOL bIsBool) : COleVariant(s) {
  if(bIsBool) {
    vt = VT_BOOL;
    boolVal = s;
  } else if(s==-1) {
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  }
}

inline CONSTRUCTOR CdbVariant::CdbVariant(LPVARIANT pv) {
  if(!pv) {
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  } else
    VariantCopy(this,pv);
}

inline CONSTRUCTOR CdbVariant::CdbVariant(LPSAFEARRAY psa) {
  if(!psa) {
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  } else {
    vt = VT_ARRAY|VT_UI1;
    parray = psa;
  }
}

inline VOID CdbVariant::operator =(LPVARIANT pv) {
  if(!pv) {
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  } else
    VariantCopy(this,pv);
}

inline VOID CdbVariant::operator =(LPCTSTR pstr) {
  if(!pstr) {
    VariantClear(this);
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  } else {
#if defined(UNICODE)
    bstrVal = SysAllocString(pstr);
#else
    bstrVal = SysAllocStringByteLen(pstr,strlen(pstr));
#endif
    vt = VT_BSTR;
  }
}

inline VOID CdbVariant::operator =(SHORT s) {
  if(s==-1) {
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  } else {
    vt = VT_I2;
    iVal = s;
  }
}

inline VOID CdbVariant::operator =(const int i) {
  if(i==-1) {
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  } else {
    vt = VT_I2;
    iVal =(SHORT)i;
  }
}

inline VOID CdbVariant::operator =(LONG l) {
  if(l==-1) {
    vt = VT_ERROR;
    scode = DISP_E_PARAMNOTFOUND;
  } else {
    vt = VT_I4;
    lVal = l;
  }
}

HRESULT CdbWideFromAnsi(LPSTR,unsigned int,BSTR *);

class CdbWide {
public:
  CONSTRUCTOR CdbWide(LPSTR pstr,unsigned int cb=0) {
    CdbWideFromAnsi(pstr,(pstr ? (cb==0 ? strlen(pstr) : cb) : 0),&m_bstr);
  }
  DESTRUCTOR ~CdbWide() {
    SysFreeString(m_bstr);
  }
  operator LPWSTR() { return (LPWSTR)m_bstr; }
  operator LPSTR() { return (LPSTR)m_bstr; }
  ULONG cBytes() { return SysStringByteLen(m_bstr); }
private:
  BSTR m_bstr;
};

class DLLEXPORT CdbOleObject : public CObject {
public:
  CONSTRUCTOR CdbOleObject(VOID);
  virtual DESTRUCTOR ~CdbOleObject(VOID);
  WINBOOL Exists(VOID);
  CdbOleObject &operator = (CdbOleObject &o);
  operator LPUNKNOWN(){ return GetInterface();}
  VOID SetInterface(LPUNKNOWN punk,WINBOOL bAddRef=FALSE);
  VOID SetInterface(REFIID riidClass,REFIID riidInterface);
  VOID SetInterfaceLic(REFIID riidClass,REFIID riidInterface);
  LPUNKNOWN GetInterface(WINBOOL bAddRef=FALSE,WINBOOL bThrowException=TRUE) const;
  virtual VOID OnInterfaceChange(VOID);
  VOID SetRichErrorInfo(LPOLESTR pstrSource,LPOLESTR pstrDescription,LPOLESTR pstrHelpFile,ULONG ulHelpID) const;
protected:
  WINBOOL StartOLE(VOID);
  LPUNKNOWN m_punkInterface;
};

class DLLEXPORT CdbCollection : public CdbOleObject {
public:
  virtual CdbObject ObItem(LONG i) = 0;
  virtual CdbObject ObItem(LPCTSTR pstr) = 0;
  virtual LONG GetCount(VOID) = 0;
  virtual VOID ObAppend(CdbObject &obj) = 0;
  virtual VOID Delete(LPCTSTR pstr) = 0;
  virtual VOID Refresh(VOID) = 0;
};

class DLLEXPORT CdbStaticCollection : public CdbCollection {
public:
  CdbObject ObItem(LONG i);
  CdbObject ObItem(LPCTSTR pstr);
  LONG GetCount(VOID);
  VOID ObAppend(CdbObject &obj);
  VOID Delete(LPCTSTR pstr);
  VOID Refresh(VOID);
};

class DLLEXPORT CdbDynamicCollection : public CdbCollection {
public:
  CdbObject ObItem(LONG i);
  CdbObject ObItem(LPCTSTR pstr);
  LONG GetCount(VOID);
  VOID ObAppend(CdbObject &obj);
  VOID Delete(LPCTSTR pstr);
  VOID Refresh(VOID);
};

#define DAOMFC_STATIC_COLLECTION_DECL(objColl,objSingle,intSingle) class DLLEXPORT objColl : public CdbStaticCollection { public: objSingle Item(LONG i); objSingle Item(LPCTSTR pstr); objSingle operator[](LONG i); objSingle operator[](LPCTSTR pstr); }
#define DAOMFC_DYNAMIC_COLLECTION_DECL(objColl,objSingle,intSingle) class DLLEXPORT objColl : public CdbDynamicCollection { public: objSingle Item(LONG i); objSingle Item(LPCTSTR pstr); VOID Append(objSingle &o); objSingle operator[](LONG i); objSingle operator[](LPCTSTR pstr); }

DAOMFC_STATIC_COLLECTION_DECL(CdbErrors,CdbError,DAOError);
DAOMFC_STATIC_COLLECTION_DECL(CdbDatabases,CdbDatabase,DAODatabase);
DAOMFC_STATIC_COLLECTION_DECL(CdbRecordsets,CdbRecordset,DAORecordset);
DAOMFC_STATIC_COLLECTION_DECL(CdbParameters,CdbParameter,DAOParameter);
DAOMFC_STATIC_COLLECTION_DECL(CdbDocuments,CdbDocument,DAODocument);
DAOMFC_STATIC_COLLECTION_DECL(CdbContainers,CdbContainer,DAOContainer);
DAOMFC_DYNAMIC_COLLECTION_DECL(CdbProperties,CdbProperty,DAOProperty);
DAOMFC_DYNAMIC_COLLECTION_DECL(CdbFields,CdbField,DAOField);
DAOMFC_DYNAMIC_COLLECTION_DECL(CdbQueryDefs,CdbQueryDef,DAOQueryDef);
DAOMFC_DYNAMIC_COLLECTION_DECL(CdbTableDefs,CdbTableDef,DAOTableDef);
DAOMFC_DYNAMIC_COLLECTION_DECL(CdbIndexes,CdbIndex,DAOIndex);
DAOMFC_DYNAMIC_COLLECTION_DECL(CdbRelations,CdbRelation,DAORelation);
DAOMFC_DYNAMIC_COLLECTION_DECL(CdbUsers,CdbUser,DAOUser);
DAOMFC_DYNAMIC_COLLECTION_DECL(CdbGroups,CdbGroup,DAOGroup);

class DLLEXPORT CdbWorkspaces : public CdbDynamicCollection {
  friend CdbDBEngine;
private:
  DAODBEngine *pDBEng;
  WINBOOL m_bDontStart;
public:
  CONSTRUCTOR CdbWorkspaces(VOID){pDBEng = NULL;}
  CdbWorkspace Item(LONG i);
  CdbWorkspace Item(LPCTSTR pstr);
  VOID Append(CdbWorkspace &o);
  CdbWorkspace operator[](LONG i);
  CdbWorkspace operator[](LPCTSTR pstr);
  VOID SetDBEngine(DAODBEngine *peng){pDBEng = peng;}
  VOID GetDelayedInterface();
};

class DLLEXPORT CdbConnections : public CdbStaticCollection {
public:
  CONSTRUCTOR CdbConnections(CdbConnections &Connections);
  CONSTRUCTOR CdbConnections() { pwrk = NULL; }
  CdbConnection Item(LONG i);
  CdbConnection Item(LPCTSTR pstr);
  CdbConnection operator[](LONG i);
  CdbConnection operator[](LPCTSTR pstr);
  CdbConnections &operator = (CdbConnections &o);
  LONG GetCount(VOID);
  VOID Refresh(VOID);
  VOID SetWorkspace(DAOWorkspace *pParent) { pwrk = pParent; }
private:
  VOID CheckInterface();
  DAOWorkspace *pwrk;
};

class DLLEXPORT CdbObject : public CdbOleObject {
public:
  CONSTRUCTOR CdbObject(VOID);
  CONSTRUCTOR CdbObject(LPUNKNOWN punk,WINBOOL bAddRef=FALSE);
  virtual CString GetName(VOID);
  virtual VOID SetName(LPCTSTR pstr);
  CdbProperties Properties;
};

class DLLEXPORT CdbGetRowsEx : public CdbObject {
public:
  CONSTRUCTOR CdbGetRowsEx(VOID);
  CONSTRUCTOR CdbGetRowsEx(ICDAORecordset *pGetRows,WINBOOL bAddRef=FALSE);
  CONSTRUCTOR CdbGetRowsEx(const CdbGetRowsEx &);
  CdbGetRowsEx &operator =(const CdbGetRowsEx &);
  VOID OnInterfaceChange(VOID);
};

#define DAOVINIT(var) do { (var).vt = VT_ERROR; (var).scode = DISP_E_PARAMNOTFOUND; } while (0)
#define STV(pstr) CdbVariant(pstr)
#define STB(pstr) V_BSTR(((LPVARIANT)STV(pstr)))
#define LTV(l) CdbVariant(l)
#define OLTV(l) CdbVariant((l))
#define BTB(b) ((VARIANT_BOOL)(b?-1:0))
#define BTV(b) CdbVariant(BTB(b),TRUE)
#define SHTV(s) CdbVariant((SHORT)s)
#define VTV(pv) CdbVariant(pv)
#define ATV(psa,var) do { if(!psa) { var.vt = VT_ERROR; var.scode = DISP_E_PARAMNOTFOUND; } else { var.vt = VT_ARRAY|VT_UI1; SafeArrayCopy(psa,&var.parray); } } while (0)
#define DAOMFC_CALL(hr) do { HRESULT hresult = (hr); if(FAILED(hresult)) { TRACE0("\nDBDAO Call Failed.\n\t"); TRACE2("\nIn file %s on line %d\n",_T("DBDAO.CPP"),__LINE__); TRACE1("hResult = %X\n",hresult); if(GetScode(hresult)==E_OUTOFMEMORY) AfxThrowMemoryException(); else throw CdbException(hresult); } } while (0)
#define LPROPGET(intDAO,meth) do { intDAO *p = (intDAO *)GetInterface(); LONG l = 0; DAOMFC_CALL(p->meth(&l)); return l; } while (0)
#define LPROPSET(intDAO,meth,l) do { intDAO *p = (intDAO *)GetInterface(); DAOMFC_CALL(p->meth(l)); } while(0)
#define WPROPGET(intDAO,meth) do { intDAO *p = (intDAO *)GetInterface(); SHORT s = 0; DAOMFC_CALL(p->meth(&s)); return s; } while (0)
#define WPROPSET(intDAO,meth,s) do { intDAO *p = (intDAO *)GetInterface(); DAOMFC_CALL(p->meth(s)); } while(0)
#define SPROPGET(intDAO,meth) do { intDAO *p = (intDAO *)GetInterface(); CdbBSTR bstr; DAOMFC_CALL(p->meth(bstr)); return bstr; } while (0)
#define SPROPSET(intDAO,meth,s) do { intDAO *p = (intDAO *)GetInterface(); DAOMFC_CALL(p->meth(STB(s))); } while(0)
#define DPROPGET(intDAO,meth) do { intDAO *p = (intDAO *)GetInterface(); VARIANT Var; VariantInit(&Var); DAOMFC_CALL(p->meth(&Var)); return Var; } while (0)
#define DPROPSET(intDAO,meth,pv) do { intDAO *p = (intDAO *)GetInterface(); DAOMFC_CALL(p->meth(*pv)); } while(0)
#define BPROPGET(intDAO,meth) do { intDAO *p = (intDAO *)GetInterface(); VARIANT_BOOL vb = 0; DAOMFC_CALL(p->meth(&vb)); return(WINBOOL)vb; } while (0)
#define BPROPSET(intDAO,meth,b) do { intDAO *p = (intDAO *)GetInterface(); DAOMFC_CALL(p->meth(BTB(b))); } while(0)
#define VPROPGET(intDAO,meth) do { intDAO *p = (intDAO *)GetInterface(); COleVariant v; VariantInit(&v); DAOMFC_CALL(p->meth(&v)); return &v; } while (0)
#define VPROPSET(intDAO,meth,pv) do { intDAO *p = (intDAO *)GetInterface(); DAOMFC_CALL(p->meth(*pv)); } while(0)
#define DWPROPGET(intDAO,meth) do { intDAO *p = (intDAO *)GetInterface(); DWORD dw = 0; DAOMFC_CALL(p->meth(&dw)); return dw; } while (0)
#define DAOMFC_STATIC_COLLECTION_IMPL(objColl,objSingle,intColl,intSingle) objSingle objColl::Item(LONG i) { return (intSingle *)(ObItem(i).GetInterface(TRUE)); } objSingle objColl::Item(LPCTSTR pstr) { return (intSingle *)(ObItem(pstr).GetInterface(TRUE)); } objSingle objColl::operator[](LONG i) { return (intSingle *)(Item(i).GetInterface(TRUE)); } objSingle objColl::operator[](LPCTSTR pstr) { return (intSingle *)(Item(pstr).GetInterface(TRUE)); }
#define DAOMFC_DYNAMIC_COLLECTION_IMPL(objColl,objSingle,intColl,intSingle) objSingle objColl::Item(LONG i) { return (intSingle *)(ObItem(i).GetInterface(TRUE)); } objSingle objColl::Item(LPCTSTR pstr) { return (intSingle *)(ObItem(pstr).GetInterface(TRUE)); } VOID objColl::Append(objSingle &o) { ObAppend(o); } objSingle objColl::operator[](LONG i) { return (intSingle *)(Item(i).GetInterface(TRUE)); } objSingle objColl::operator[](LPCTSTR pstr) { return (intSingle *)(Item(pstr).GetInterface(TRUE)); }

#undef INTERFACE
#define INTERFACE DAOMFCSCollection
DECLARE_INTERFACE_(DAOMFCSCollection,_DAOCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT index,LPUNKNOWN *ppunk);
};

#undef INTERFACE
#define INTERFACE DAOMFCDCollection
DECLARE_INTERFACE_(DAOMFCDCollection,_DAODynaCollection) {
#ifndef __cplusplus
  /* IUnknown methods */
  STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
  STDMETHOD_(ULONG, AddRef)(THIS) PURE;
  STDMETHOD_(ULONG, Release)(THIS) PURE;
  /*** IDispatch methods ***/
  STDMETHOD(GetTypeInfoCount)(THIS_ UINT *pctinfo);
  STDMETHOD(GetTypeInfo)(THIS_ UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
  STDMETHOD(GetIDsOfNames)(THIS_ REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
  STDMETHOD(Invoke)(THIS_ DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
  /*** _DAOCollection ***/
  STDMETHOD(get_Count) (THIS_ short *c) PURE;
  STDMETHOD(_NewEnum) (THIS_ IUnknown **ppunk) PURE;
  STDMETHOD(Refresh) (THIS) PURE;
  /*** _DAODynaCollection ***/
  STDMETHOD(Append) (THIS_ IDispatch *Object) PURE;
  STDMETHOD(Delete) (THIS_ BSTR Name) PURE;
#endif
  STDMETHOD(get_Item) (THIS_ VARIANT index,LPUNKNOWN *ppunk);
};

#endif /* __cplusplus */

#endif
