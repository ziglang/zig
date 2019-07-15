/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef DXTmpl_h
#define DXTmpl_h

#include <limits.h>
#include <string.h>
#include <stdlib.h>
#include <search.h>

#define DXASSERT_VALID(pObj)

#ifndef PASCAL_INLINE
#define PASCAL_INLINE WINAPI
#endif

typedef void *DXLISTPOS;
typedef DWORD DXLISTHANDLE;

#define DX_BEFORE_START_POSITION ((void*)(INT_PTR)-1)

#ifndef __CRT__NO_INLINE
__CRT_INLINE WINBOOL DXIsValidAddress(const void *lp,UINT nBytes,WINBOOL bReadWrite) { return (lp!=NULL && !IsBadReadPtr(lp,nBytes) && (!bReadWrite || !IsBadWritePtr((LPVOID)lp,nBytes))); }
#endif

#ifdef __cplusplus

template<class TYPE>
inline void DXConstructElements(TYPE *pElements,int nCount) {
  _ASSERT(nCount==0 || DXIsValidAddress(pElements,nCount *sizeof(TYPE),TRUE));
  memset((void*)pElements,0,nCount *sizeof(TYPE));
}

template<class TYPE>
inline void DXDestructElements(TYPE *pElements,int nCount) {
  _ASSERT((nCount==0 || DXIsValidAddress(pElements,nCount *sizeof(TYPE),TRUE)));
  pElements;
  nCount;
}

template<class TYPE>
inline void DXCopyElements(TYPE *pDest,const TYPE *pSrc,int nCount) {
  _ASSERT((nCount==0 || DXIsValidAddress(pDest,nCount *sizeof(TYPE),TRUE)));
  _ASSERT((nCount==0 || DXIsValidAddress(pSrc,nCount *sizeof(TYPE),FALSE)));
  memcpy(pDest,pSrc,nCount *sizeof(TYPE));
}

template<class TYPE,class ARG_TYPE>
WINBOOL DXCompareElements(const TYPE *pElement1,const ARG_TYPE *pElement2) {
  _ASSERT(DXIsValidAddress(pElement1,sizeof(TYPE),FALSE));
  _ASSERT(DXIsValidAddress(pElement2,sizeof(ARG_TYPE),FALSE));
  return *pElement1==*pElement2;
}

template<class ARG_KEY>
inline UINT DXHashKey(ARG_KEY key) { return ((UINT)(void*)(DWORD)key) >> 4; }

struct CDXPlex {
  CDXPlex *pNext;
  UINT nMax;
  UINT nCur;
  void *data() { return this+1; }
  static CDXPlex *PASCAL_INLINE Create(CDXPlex *&pHead,UINT nMax,UINT cbElement) {
    CDXPlex *p = (CDXPlex*) new BYTE[sizeof(CDXPlex) + nMax *cbElement];
    if(!p) return NULL;
    p->nMax = nMax;
    p->nCur = 0;
    p->pNext = pHead;
    pHead = p;
    return p;
  }
  void FreeDataChain() {
    CDXPlex *p = this;
    while(p!=NULL) {
      BYTE *bytes = (BYTE*) p;
      CDXPlex *pNext = p->pNext;
      delete [] bytes;
      p = pNext;
    }
  }
};

template<class TYPE,class ARG_TYPE>
class CDXArray {
public:
  CDXArray();
  int GetSize() const;
  int GetUpperBound() const;
  void SetSize(int nNewSize,int nGrowBy = -1);
  void FreeExtra();
  void RemoveAll();
  TYPE GetAt(int nIndex) const;
  void SetAt(int nIndex,ARG_TYPE newElement);
  TYPE &ElementAt(int nIndex);
  const TYPE *GetData() const;
  TYPE *GetData();
  void SetAtGrow(int nIndex,ARG_TYPE newElement);
  int Add(ARG_TYPE newElement);
  int Append(const CDXArray &src);
  void Copy(const CDXArray &src);
  TYPE operator[](int nIndex) const;
  TYPE &operator[](int nIndex);
  void InsertAt(int nIndex,ARG_TYPE newElement,int nCount = 1);
  void RemoveAt(int nIndex,int nCount = 1);
  void InsertAt(int nStartIndex,CDXArray *pNewArray);
  void Sort(int (__cdecl *compare)(const void *elem1,const void *elem2));
protected:
  TYPE *m_pData;
  int m_nSize;
  int m_nMaxSize;
  int m_nGrowBy;
public:
  ~CDXArray();
};

template<class TYPE,class ARG_TYPE>
inline int CDXArray<TYPE,ARG_TYPE>::GetSize() const { return m_nSize; }
template<class TYPE,class ARG_TYPE>
inline int CDXArray<TYPE,ARG_TYPE>::GetUpperBound() const { return m_nSize-1; }
template<class TYPE,class ARG_TYPE>
inline void CDXArray<TYPE,ARG_TYPE>::RemoveAll() { SetSize(0,-1); }
template<class TYPE,class ARG_TYPE>
inline TYPE CDXArray<TYPE,ARG_TYPE>::GetAt(int nIndex) const { _ASSERT((nIndex >= 0 && nIndex < m_nSize)); return m_pData[nIndex]; }
template<class TYPE,class ARG_TYPE>
inline void CDXArray<TYPE,ARG_TYPE>::SetAt(int nIndex,ARG_TYPE newElement) { _ASSERT((nIndex >= 0 && nIndex < m_nSize)); m_pData[nIndex] = newElement; }
template<class TYPE,class ARG_TYPE>
inline TYPE &CDXArray<TYPE,ARG_TYPE>::ElementAt(int nIndex) { _ASSERT((nIndex >= 0 && nIndex < m_nSize)); return m_pData[nIndex]; }
template<class TYPE,class ARG_TYPE>
inline const TYPE *CDXArray<TYPE,ARG_TYPE>::GetData() const { return (const TYPE*)m_pData; }
template<class TYPE,class ARG_TYPE>
inline TYPE *CDXArray<TYPE,ARG_TYPE>::GetData() { return (TYPE*)m_pData; }
template<class TYPE,class ARG_TYPE>
inline int CDXArray<TYPE,ARG_TYPE>::Add(ARG_TYPE newElement) {
  int nIndex = m_nSize;
  SetAtGrow(nIndex,newElement);
  return nIndex;
}
template<class TYPE,class ARG_TYPE>
inline TYPE CDXArray<TYPE,ARG_TYPE>::operator[](int nIndex) const { return GetAt(nIndex); }
template<class TYPE,class ARG_TYPE>
inline TYPE &CDXArray<TYPE,ARG_TYPE>::operator[](int nIndex) { return ElementAt(nIndex); }
template<class TYPE,class ARG_TYPE>
CDXArray<TYPE,ARG_TYPE>::CDXArray() { m_pData = NULL; m_nSize = m_nMaxSize = m_nGrowBy = 0; }
emplate<class TYPE,class ARG_TYPE>
CDXArray<TYPE,ARG_TYPE>::~CDXArray() {
  DXASSERT_VALID(this);
  if(m_pData!=NULL) {
    DXDestructElements(m_pData,m_nSize);
    delete[] (BYTE*)m_pData;
  }
}

template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::SetSize(int nNewSize,int nGrowBy) {
  DXASSERT_VALID(this);
  _ASSERT(nNewSize >= 0);
  if(nGrowBy!=-1) m_nGrowBy = nGrowBy;
  if(nNewSize==0) {
    if(m_pData!=NULL) {
      DXDestructElements(m_pData,m_nSize);
      delete[] (BYTE*)m_pData;
      m_pData = NULL;
    }
    m_nSize = m_nMaxSize = 0;
  } else if(!m_pData) {
#ifdef SIZE_T_MAX
    _ASSERT(nNewSize <= SIZE_T_MAX/sizeof(TYPE));
#endif
    m_pData = (TYPE*) new BYTE[nNewSize *sizeof(TYPE)];
    DXConstructElements(m_pData,nNewSize);
    m_nSize = m_nMaxSize = nNewSize;
  } else if(nNewSize <= m_nMaxSize) {
    if(nNewSize > m_nSize) {
      DXConstructElements(&m_pData[m_nSize],nNewSize-m_nSize);
    } else if(m_nSize > nNewSize) {
      DXDestructElements(&m_pData[nNewSize],m_nSize-nNewSize);
    }
    m_nSize = nNewSize;
  } else {
    int nGrowBy = m_nGrowBy;
    if(!nGrowBy) nGrowBy = min(1024,max(4,m_nSize / 8));
    int nNewMax;
    if(nNewSize < m_nMaxSize + nGrowBy) nNewMax = m_nMaxSize + nGrowBy;
    else nNewMax = nNewSize;
    _ASSERT(nNewMax >= m_nMaxSize);
#ifdef SIZE_T_MAX
    _ASSERT(nNewMax <= SIZE_T_MAX/sizeof(TYPE));
#endif
    TYPE *pNewData = (TYPE*) new BYTE[nNewMax *sizeof(TYPE)];

    if(!pNewData) return;
    memcpy(pNewData,m_pData,m_nSize *sizeof(TYPE));
    _ASSERT(nNewSize > m_nSize);
    DXConstructElements(&pNewData[m_nSize],nNewSize-m_nSize);
    delete[] (BYTE*)m_pData;
    m_pData = pNewData;
    m_nSize = nNewSize;
    m_nMaxSize = nNewMax;
  }
}

template<class TYPE,class ARG_TYPE>
int CDXArray<TYPE,ARG_TYPE>::Append(const CDXArray &src) {
  DXASSERT_VALID(this);
  _ASSERT(this!=&src);
  int nOldSize = m_nSize;
  SetSize(m_nSize + src.m_nSize);
  DXCopyElements(m_pData + nOldSize,src.m_pData,src.m_nSize);
  return nOldSize;
}

template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::Copy(const CDXArray &src) {
  DXASSERT_VALID(this);
  _ASSERT(this!=&src);
  SetSize(src.m_nSize);
  DXCopyElements(m_pData,src.m_pData,src.m_nSize);
}

template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::FreeExtra() {
  DXASSERT_VALID(this);
  if(m_nSize!=m_nMaxSize) {
#ifdef SIZE_T_MAX
    _ASSERT(m_nSize <= SIZE_T_MAX/sizeof(TYPE));
#endif
    TYPE *pNewData = NULL;
    if(m_nSize!=0) {
      pNewData = (TYPE*) new BYTE[m_nSize *sizeof(TYPE)];
      if(!pNewData) return;
      memcpy(pNewData,m_pData,m_nSize *sizeof(TYPE));
    }
    delete[] (BYTE*)m_pData;
    m_pData = pNewData;
    m_nMaxSize = m_nSize;
  }
}

template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::SetAtGrow(int nIndex,ARG_TYPE newElement) {
  DXASSERT_VALID(this);
  _ASSERT(nIndex >= 0);
  if(nIndex >= m_nSize) SetSize(nIndex+1,-1);
  m_pData[nIndex] = newElement;
}

template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::InsertAt(int nIndex,ARG_TYPE newElement,int nCount) {
  DXASSERT_VALID(this);
  _ASSERT(nIndex >= 0);
  _ASSERT(nCount > 0);
  if(nIndex >= m_nSize) SetSize(nIndex + nCount,-1);
  else {
    int nOldSize = m_nSize;
    SetSize(m_nSize + nCount,-1);
    memmove(&m_pData[nIndex+nCount],&m_pData[nIndex],(nOldSize-nIndex) *sizeof(TYPE));
    DXConstructElements(&m_pData[nIndex],nCount);
  }
  _ASSERT(nIndex + nCount <= m_nSize);
  while(nCount--)
    m_pData[nIndex++] = newElement;
}

template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::RemoveAt(int nIndex,int nCount) {
  DXASSERT_VALID(this);
  _ASSERT(nIndex >= 0);
  _ASSERT(nCount >= 0);
  _ASSERT(nIndex + nCount <= m_nSize);
  int nMoveCount = m_nSize - (nIndex + nCount);
  DXDestructElements(&m_pData[nIndex],nCount);
  if(nMoveCount)
    memcpy(&m_pData[nIndex],&m_pData[nIndex + nCount],nMoveCount *sizeof(TYPE));
  m_nSize -= nCount;
}

template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::InsertAt(int nStartIndex,CDXArray *pNewArray) {
  DXASSERT_VALID(this);
  DXASSERT_VALID(pNewArray);
  _ASSERT(nStartIndex >= 0);
  if(pNewArray->GetSize() > 0) {
    InsertAt(nStartIndex,pNewArray->GetAt(0),pNewArray->GetSize());
    for(int i = 0;i < pNewArray->GetSize();i++)
      SetAt(nStartIndex + i,pNewArray->GetAt(i));
  }
}

template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::Sort(int (__cdecl *compare)(const void *elem1,const void *elem2)) {
  DXASSERT_VALID(this);
  _ASSERT(m_pData!=NULL);
  qsort(m_pData,m_nSize,sizeof(TYPE),compare);
}

#ifdef _DEBUG
template<class TYPE,class ARG_TYPE>
void CDXArray<TYPE,ARG_TYPE>::AssertValid() const {
  if(!m_pData) {
    _ASSERT(m_nSize==0);
    _ASSERT(m_nMaxSize==0);
  } else {
    _ASSERT(m_nSize >= 0);
    _ASSERT(m_nMaxSize >= 0);
    _ASSERT(m_nSize <= m_nMaxSize);
    _ASSERT(DXIsValidAddress(m_pData,m_nMaxSize *sizeof(TYPE),TRUE));
  }
}
#endif

template<class TYPE,class ARG_TYPE>
class CDXList {
protected:
  struct CNode {
    CNode *pNext;
    CNode *pPrev;
    TYPE data;
  };
public:
  CDXList(int nBlockSize = 10);
  int GetCount() const;
  WINBOOL IsEmpty() const;
  TYPE &GetHead();
  TYPE GetHead() const;
  TYPE &GetTail();
  TYPE GetTail() const;

  TYPE RemoveHead();
  TYPE RemoveTail();
  DXLISTPOS AddHead(ARG_TYPE newElement);
  DXLISTPOS AddTail(ARG_TYPE newElement);
  void AddHead(CDXList *pNewList);
  void AddTail(CDXList *pNewList);
  void RemoveAll();
  DXLISTPOS GetHeadPosition() const;
  DXLISTPOS GetTailPosition() const;
  TYPE &GetNext(DXLISTPOS &rPosition);
  TYPE GetNext(DXLISTPOS &rPosition) const;
  TYPE &GetPrev(DXLISTPOS &rPosition);
  TYPE GetPrev(DXLISTPOS &rPosition) const;
  TYPE &GetAt(DXLISTPOS position);
  TYPE GetAt(DXLISTPOS position) const;
  void SetAt(DXLISTPOS pos,ARG_TYPE newElement);
  void RemoveAt(DXLISTPOS position);
  DXLISTPOS InsertBefore(DXLISTPOS position,ARG_TYPE newElement);
  DXLISTPOS InsertAfter(DXLISTPOS position,ARG_TYPE newElement);
  DXLISTPOS Find(ARG_TYPE searchValue,DXLISTPOS startAfter = NULL) const;
  DXLISTPOS FindIndex(int nIndex) const;
protected:
  CNode *m_pNodeHead;
  CNode *m_pNodeTail;
  int m_nCount;
  CNode *m_pNodeFree;
  struct CDXPlex *m_pBlocks;
  int m_nBlockSize;
  CNode *NewNode(CNode *,CNode *);
  void FreeNode(CNode *);
public:
  ~CDXList();
#ifdef _DEBUG
  void AssertValid() const;
#endif
};

template<class TYPE,class ARG_TYPE>
inline int CDXList<TYPE,ARG_TYPE>::GetCount() const { return m_nCount; }
template<class TYPE,class ARG_TYPE>
inline WINBOOL CDXList<TYPE,ARG_TYPE>::IsEmpty() const { return m_nCount==0; }
template<class TYPE,class ARG_TYPE>
inline TYPE &CDXList<TYPE,ARG_TYPE>::GetHead() { _ASSERT(m_pNodeHead!=NULL); return m_pNodeHead->data; }
template<class TYPE,class ARG_TYPE>
inline TYPE CDXList<TYPE,ARG_TYPE>::GetHead() const { _ASSERT(m_pNodeHead!=NULL); return m_pNodeHead->data; }
template<class TYPE,class ARG_TYPE>
inline TYPE &CDXList<TYPE,ARG_TYPE>::GetTail() { _ASSERT(m_pNodeTail!=NULL); return m_pNodeTail->data; }
template<class TYPE,class ARG_TYPE>
inline TYPE CDXList<TYPE,ARG_TYPE>::GetTail() const { _ASSERT(m_pNodeTail!=NULL); return m_pNodeTail->data; }
template<class TYPE,class ARG_TYPE>
inline DXLISTPOS CDXList<TYPE,ARG_TYPE>::GetHeadPosition() const { return (DXLISTPOS) m_pNodeHead; }
template<class TYPE,class ARG_TYPE>
inline DXLISTPOS CDXList<TYPE,ARG_TYPE>::GetTailPosition() const { return (DXLISTPOS) m_pNodeTail; }
template<class TYPE,class ARG_TYPE>
inline TYPE &CDXList<TYPE,ARG_TYPE>::GetNext(DXLISTPOS &rPosition) {
  CNode *pNode = (CNode *) rPosition;
  _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
  rPosition = (DXLISTPOS) pNode->pNext;
  return pNode->data;
}
template<class TYPE,class ARG_TYPE>
inline TYPE CDXList<TYPE,ARG_TYPE>::GetNext(DXLISTPOS &rPosition) const {
  CNode *pNode = (CNode *) rPosition;
  _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
  rPosition = (DXLISTPOS) pNode->pNext;
  return pNode->data;
}
template<class TYPE,class ARG_TYPE>
inline TYPE &CDXList<TYPE,ARG_TYPE>::GetPrev(DXLISTPOS &rPosition) {
  CNode *pNode = (CNode *) rPosition;
  _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
  rPosition = (DXLISTPOS) pNode->pPrev;
  return pNode->data;
}
template<class TYPE,class ARG_TYPE>
inline TYPE CDXList<TYPE,ARG_TYPE>::GetPrev(DXLISTPOS &rPosition) const {
  CNode *pNode = (CNode *) rPosition;
  _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
  rPosition = (DXLISTPOS) pNode->pPrev;
  return pNode->data;
}
template<class TYPE,class ARG_TYPE>
inline TYPE &CDXList<TYPE,ARG_TYPE>::GetAt(DXLISTPOS position) {
  CNode *pNode = (CNode *) position;
  _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
  return pNode->data;
}
template<class TYPE,class ARG_TYPE>
inline TYPE CDXList<TYPE,ARG_TYPE>::GetAt(DXLISTPOS position) const {
  CNode *pNode = (CNode *) position;
  _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
  return pNode->data;
}
template<class TYPE,class ARG_TYPE>
inline void CDXList<TYPE,ARG_TYPE>::SetAt(DXLISTPOS pos,ARG_TYPE newElement) {
  CNode *pNode = (CNode *) pos;
  _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
  pNode->data = newElement;
}

template<class TYPE,class ARG_TYPE>
CDXList<TYPE,ARG_TYPE>::CDXList(int nBlockSize) {
  _ASSERT(nBlockSize > 0);
  m_nCount = 0;
  m_pNodeHead = m_pNodeTail = m_pNodeFree = NULL;
  m_pBlocks = NULL;
  m_nBlockSize = nBlockSize;
}

template<class TYPE,class ARG_TYPE>
void CDXList<TYPE,ARG_TYPE>::RemoveAll() {
  DXASSERT_VALID(this);
  CNode *pNode;
  for(pNode = m_pNodeHead;pNode!=NULL;pNode = pNode->pNext)
    DXDestructElements(&pNode->data,1);
  m_nCount = 0;
  m_pNodeHead = m_pNodeTail = m_pNodeFree = NULL;
  m_pBlocks->FreeDataChain();
  m_pBlocks = NULL;
}

template<class TYPE,class ARG_TYPE>
CDXList<TYPE,ARG_TYPE>::~CDXList() {
  RemoveAll();
  _ASSERT(m_nCount==0);
}

template<class TYPE,class ARG_TYPE>
typename CDXList<TYPE,ARG_TYPE>::CNode *
CDXList<TYPE,ARG_TYPE>::NewNode(CNode *pPrev,CNode *pNext) {
  if(!m_pNodeFree) {
    CDXPlex *pNewBlock = CDXPlex::Create(m_pBlocks,m_nBlockSize,sizeof(CNode));
    CNode *pNode = (CNode *) pNewBlock->data();
    pNode += m_nBlockSize - 1;
    for(int i = m_nBlockSize-1;i >= 0;i--,pNode--) {
      pNode->pNext = m_pNodeFree;
      m_pNodeFree = pNode;
    }
  }
  _ASSERT(m_pNodeFree!=NULL);
  CDXList::CNode *pNode = m_pNodeFree;
  m_pNodeFree = m_pNodeFree->pNext;
  pNode->pPrev = pPrev;
  pNode->pNext = pNext;
  m_nCount++;
  _ASSERT(m_nCount > 0);
  DXConstructElements(&pNode->data,1);
  return pNode;
}

template<class TYPE,class ARG_TYPE>
void CDXList<TYPE,ARG_TYPE>::FreeNode(CNode *pNode) {
  DXDestructElements(&pNode->data,1);
  pNode->pNext = m_pNodeFree;
  m_pNodeFree = pNode;
  m_nCount--;
  _ASSERT(m_nCount >= 0);
}

template<class TYPE,class ARG_TYPE>
DXLISTPOS CDXList<TYPE,ARG_TYPE>::AddHead(ARG_TYPE newElement) {
  DXASSERT_VALID(this);
  CNode *pNewNode = NewNode(NULL,m_pNodeHead);
  pNewNode->data = newElement;
  if(m_pNodeHead!=NULL) m_pNodeHead->pPrev = pNewNode;
  else m_pNodeTail = pNewNode;
  m_pNodeHead = pNewNode;
  return (DXLISTPOS) pNewNode;
}

template<class TYPE,class ARG_TYPE>
DXLISTPOS CDXList<TYPE,ARG_TYPE>::AddTail(ARG_TYPE newElement) {
  DXASSERT_VALID(this);
  CNode *pNewNode = NewNode(m_pNodeTail,NULL);
  pNewNode->data = newElement;
  if(m_pNodeTail!=NULL) m_pNodeTail->pNext = pNewNode;
  else m_pNodeHead = pNewNode;
  m_pNodeTail = pNewNode;
  return (DXLISTPOS) pNewNode;
}

template<class TYPE,class ARG_TYPE>
void CDXList<TYPE,ARG_TYPE>::AddHead(CDXList *pNewList) {
  DXASSERT_VALID(this);
  DXASSERT_VALID(pNewList);
  DXLISTPOS pos = pNewList->GetTailPosition();
  while(pos!=NULL)
    AddHead(pNewList->GetPrev(pos));
}

template<class TYPE,class ARG_TYPE>
void CDXList<TYPE,ARG_TYPE>::AddTail(CDXList *pNewList) {
  DXASSERT_VALID(this);
  DXASSERT_VALID(pNewList);
  DXLISTPOS pos = pNewList->GetHeadPosition();
  while(pos!=NULL)
    AddTail(pNewList->GetNext(pos));
}

template<class TYPE,class ARG_TYPE>
TYPE CDXList<TYPE,ARG_TYPE>::RemoveHead() {
  DXASSERT_VALID(this);
  _ASSERT(m_pNodeHead!=NULL);
  _ASSERT(DXIsValidAddress(m_pNodeHead,sizeof(CNode),TRUE));
  CNode *pOldNode = m_pNodeHead;
  TYPE returnValue = pOldNode->data;
  m_pNodeHead = pOldNode->pNext;
  if(m_pNodeHead!=NULL) m_pNodeHead->pPrev = NULL;
  else m_pNodeTail = NULL;
  FreeNode(pOldNode);
  return returnValue;
}

template<class TYPE,class ARG_TYPE>
TYPE CDXList<TYPE,ARG_TYPE>::RemoveTail() {
  DXASSERT_VALID(this);
  _ASSERT(m_pNodeTail!=NULL);
  _ASSERT(DXIsValidAddress(m_pNodeTail,sizeof(CNode),TRUE));
  CNode *pOldNode = m_pNodeTail;
  TYPE returnValue = pOldNode->data;
  m_pNodeTail = pOldNode->pPrev;
  if(m_pNodeTail!=NULL) m_pNodeTail->pNext = NULL;
  else m_pNodeHead = NULL;
  FreeNode(pOldNode);
  return returnValue;
}

template<class TYPE,class ARG_TYPE>
DXLISTPOS CDXList<TYPE,ARG_TYPE>::InsertBefore(DXLISTPOS position,ARG_TYPE newElement) {
  DXASSERT_VALID(this);
  if(!position) return AddHead(newElement);
  CNode *pOldNode = (CNode *) position;
  CNode *pNewNode = NewNode(pOldNode->pPrev,pOldNode);
  pNewNode->data = newElement;
  if(pOldNode->pPrev!=NULL) {
    _ASSERT(DXIsValidAddress(pOldNode->pPrev,sizeof(CNode),TRUE));
    pOldNode->pPrev->pNext = pNewNode;
  } else {
    _ASSERT(pOldNode==m_pNodeHead);
    m_pNodeHead = pNewNode;
  }
  pOldNode->pPrev = pNewNode;
  return (DXLISTPOS) pNewNode;
}

template<class TYPE,class ARG_TYPE>
DXLISTPOS CDXList<TYPE,ARG_TYPE>::InsertAfter(DXLISTPOS position,ARG_TYPE newElement) {
  DXASSERT_VALID(this);
  if(!position) return AddTail(newElement);
  CNode *pOldNode = (CNode *) position;
  _ASSERT(DXIsValidAddress(pOldNode,sizeof(CNode),TRUE));
  CNode *pNewNode = NewNode(pOldNode,pOldNode->pNext);
  pNewNode->data = newElement;
  if(pOldNode->pNext!=NULL) {
    _ASSERT(DXIsValidAddress(pOldNode->pNext,sizeof(CNode),TRUE));
    pOldNode->pNext->pPrev = pNewNode;
  } else {
    _ASSERT(pOldNode==m_pNodeTail);
    m_pNodeTail = pNewNode;
  }
  pOldNode->pNext = pNewNode;
  return (DXLISTPOS) pNewNode;
}

template<class TYPE,class ARG_TYPE>
void CDXList<TYPE,ARG_TYPE>::RemoveAt(DXLISTPOS position) {
  DXASSERT_VALID(this);
  CNode *pOldNode = (CNode *) position;
  _ASSERT(DXIsValidAddress(pOldNode,sizeof(CNode),TRUE));
  if(pOldNode==m_pNodeHead) {
    m_pNodeHead = pOldNode->pNext;
  } else {
    _ASSERT(DXIsValidAddress(pOldNode->pPrev,sizeof(CNode),TRUE));
    pOldNode->pPrev->pNext = pOldNode->pNext;
  }
  if(pOldNode==m_pNodeTail) m_pNodeTail = pOldNode->pPrev;
  else {
    _ASSERT(DXIsValidAddress(pOldNode->pNext,sizeof(CNode),TRUE));
    pOldNode->pNext->pPrev = pOldNode->pPrev;
  }
  FreeNode(pOldNode);
}

template<class TYPE,class ARG_TYPE>
DXLISTPOS CDXList<TYPE,ARG_TYPE>::FindIndex(int nIndex) const {
  DXASSERT_VALID(this);
  _ASSERT(nIndex >= 0);
  if(nIndex >= m_nCount) return NULL;
  CNode *pNode = m_pNodeHead;
  while(nIndex--) {
    _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
    pNode = pNode->pNext;
  }
  return (DXLISTPOS) pNode;
}

template<class TYPE,class ARG_TYPE>
DXLISTPOS CDXList<TYPE,ARG_TYPE>::Find(ARG_TYPE searchValue,DXLISTPOS startAfter) const {
  DXASSERT_VALID(this);
  CNode *pNode = (CNode *) startAfter;
  if(!pNode) pNode = m_pNodeHead;
  else {
    _ASSERT(DXIsValidAddress(pNode,sizeof(CNode),TRUE));
    pNode = pNode->pNext;
  }
  for(;pNode!=NULL;pNode = pNode->pNext)
    if(DXCompareElements(&pNode->data,&searchValue)) return (DXLISTPOS)pNode;
  return NULL;
}

#ifdef _DEBUG
template<class TYPE,class ARG_TYPE>
void CDXList<TYPE,ARG_TYPE>::AssertValid() const {
  if(!m_nCount) {
    _ASSERT(!m_pNodeHead);
    _ASSERT(!m_pNodeTail);
  } else {
    _ASSERT(DXIsValidAddress(m_pNodeHead,sizeof(CNode),TRUE));
    _ASSERT(DXIsValidAddress(m_pNodeTail,sizeof(CNode),TRUE));
  }
}
#endif

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
class CDXMap {
protected:
  struct CAssoc {
    CAssoc *pNext;
    UINT nHashValue;
    KEY key;
    VALUE value;
  };
public:
  CDXMap(int nBlockSize = 10);
  int GetCount() const;
  WINBOOL IsEmpty() const;
  WINBOOL Lookup(ARG_KEY key,VALUE& rValue) const;
  VALUE& operator[](ARG_KEY key);
  void SetAt(ARG_KEY key,ARG_VALUE newValue);
  WINBOOL RemoveKey(ARG_KEY key);
  void RemoveAll();
  DXLISTPOS GetStartPosition() const;
  void GetNextAssoc(DXLISTPOS &rNextPosition,KEY& rKey,VALUE& rValue) const;
  UINT GetHashTableSize() const;
  void InitHashTable(UINT hashSize,WINBOOL bAllocNow = TRUE);
protected:
  CAssoc **m_pHashTable;
  UINT m_nHashTableSize;
  int m_nCount;
  CAssoc *m_pFreeList;
  struct CDXPlex *m_pBlocks;
  int m_nBlockSize;
  CAssoc *NewAssoc();
  void FreeAssoc(CAssoc*);
  CAssoc *GetAssocAt(ARG_KEY,UINT&) const;
public:
  ~CDXMap();
#ifdef _DEBUG
  void AssertValid() const;
#endif
};

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
inline int CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::GetCount() const { return m_nCount; }
template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
inline WINBOOL CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::IsEmpty() const { return m_nCount==0; }
template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
inline void CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::SetAt(ARG_KEY key,ARG_VALUE newValue) { (*this)[key] = newValue; }
template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
inline DXLISTPOS CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::GetStartPosition() const { return (m_nCount==0) ? NULL : DX_BEFORE_START_POSITION; }
template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
inline UINT CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::GetHashTableSize() const { return m_nHashTableSize; }

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::CDXMap(int nBlockSize) {
  _ASSERT(nBlockSize > 0);
  m_pHashTable = NULL;
  m_nHashTableSize = 17;
  m_nCount = 0;
  m_pFreeList = NULL;
  m_pBlocks = NULL;
  m_nBlockSize = nBlockSize;
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
void CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::InitHashTable(UINT nHashSize,WINBOOL bAllocNow) {
  DXASSERT_VALID(this);
  _ASSERT(m_nCount==0);
  _ASSERT(nHashSize > 0);
  if(m_pHashTable!=NULL) {
    delete[] m_pHashTable;
    m_pHashTable = NULL;
  }
  if(bAllocNow) {
    m_pHashTable = new CAssoc *[nHashSize];
    if(!m_pHashTable) return;
    memset(m_pHashTable,0,sizeof(CAssoc*) *nHashSize);
  }
  m_nHashTableSize = nHashSize;
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
void CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::RemoveAll() {
  DXASSERT_VALID(this);
  if(m_pHashTable!=NULL) {
    for(UINT nHash = 0;nHash < m_nHashTableSize;nHash++) {
      CAssoc *pAssoc;
      for(pAssoc = m_pHashTable[nHash]; pAssoc!=NULL;
	pAssoc = pAssoc->pNext)
      {
	DXDestructElements(&pAssoc->value,1);
	DXDestructElements(&pAssoc->key,1);
      }
    }
  }
  delete[] m_pHashTable;
  m_pHashTable = NULL;
  m_nCount = 0;
  m_pFreeList = NULL;
  m_pBlocks->FreeDataChain();
  m_pBlocks = NULL;
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::~CDXMap() {
  RemoveAll();
  _ASSERT(m_nCount==0);
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
typename CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::CAssoc*
CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::NewAssoc() {
  if(!m_pFreeList) {
    CDXPlex *newBlock = CDXPlex::Create(m_pBlocks,m_nBlockSize,sizeof(CDXMap::CAssoc));
    CDXMap::CAssoc *pAssoc = (CDXMap::CAssoc*) newBlock->data();
    pAssoc += m_nBlockSize - 1;
    for(int i = m_nBlockSize-1;i >= 0;i--,pAssoc--) {
      pAssoc->pNext = m_pFreeList;
      m_pFreeList = pAssoc;
    }
  }
  _ASSERT(m_pFreeList!=NULL);
  CDXMap::CAssoc *pAssoc = m_pFreeList;
  m_pFreeList = m_pFreeList->pNext;
  m_nCount++;
  _ASSERT(m_nCount > 0);
  DXConstructElements(&pAssoc->key,1);
  DXConstructElements(&pAssoc->value,1);
  return pAssoc;
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
void CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::FreeAssoc(CAssoc *pAssoc) {
  DXDestructElements(&pAssoc->value,1);
  DXDestructElements(&pAssoc->key,1);
  pAssoc->pNext = m_pFreeList;
  m_pFreeList = pAssoc;
  m_nCount--;
  _ASSERT(m_nCount >= 0);
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
typename CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::CAssoc*
CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::GetAssocAt(ARG_KEY key,UINT& nHash) const {
  nHash = DXHashKey(key) % m_nHashTableSize;
  if(!m_pHashTable) return NULL;
  CAssoc *pAssoc;
  for(pAssoc = m_pHashTable[nHash];pAssoc!=NULL;pAssoc = pAssoc->pNext) {
    if(DXCompareElements(&pAssoc->key,&key)) return pAssoc;
  }
  return NULL;
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
WINBOOL CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::Lookup(ARG_KEY key,VALUE& rValue) const {
  DXASSERT_VALID(this);
  UINT nHash;
  CAssoc *pAssoc = GetAssocAt(key,nHash);
  if(!pAssoc) return FALSE;
  rValue = pAssoc->value;
  return TRUE;
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
VALUE& CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::operator[](ARG_KEY key) {
  DXASSERT_VALID(this);
  UINT nHash;
  CAssoc *pAssoc;
  if(!(pAssoc = GetAssocAt(key,nHash))) {
    if(!m_pHashTable) InitHashTable(m_nHashTableSize);
    pAssoc = NewAssoc();
    pAssoc->nHashValue = nHash;
    pAssoc->key = key;
    pAssoc->pNext = m_pHashTable[nHash];
    m_pHashTable[nHash] = pAssoc;
  }
  return pAssoc->value;
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
WINBOOL CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::RemoveKey(ARG_KEY key) {
  DXASSERT_VALID(this);
  if(!m_pHashTable) return FALSE;
  CAssoc **ppAssocPrev;
  ppAssocPrev = &m_pHashTable[DXHashKey(key) % m_nHashTableSize];
  CAssoc *pAssoc;
  for(pAssoc = *ppAssocPrev;pAssoc!=NULL;pAssoc = pAssoc->pNext) {
    if(DXCompareElements(&pAssoc->key,&key)) {
      *ppAssocPrev = pAssoc->pNext;
      FreeAssoc(pAssoc);
      return TRUE;
    }
    ppAssocPrev = &pAssoc->pNext;
  }
  return FALSE;
}

template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
void CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::GetNextAssoc(DXLISTPOS &rNextPosition,KEY& rKey,VALUE& rValue) const {
  DXASSERT_VALID(this);
  _ASSERT(m_pHashTable!=NULL);
  CAssoc *pAssocRet = (CAssoc*)rNextPosition;
  _ASSERT(pAssocRet!=NULL);
  if(pAssocRet==(CAssoc*) DX_BEFORE_START_POSITION) {
    for(UINT nBucket = 0;nBucket < m_nHashTableSize;nBucket++)
      if((pAssocRet = m_pHashTable[nBucket])!=NULL)
	break;
    _ASSERT(pAssocRet!=NULL);
  }
  _ASSERT(DXIsValidAddress(pAssocRet,sizeof(CAssoc),TRUE));
  CAssoc *pAssocNext;
  if(!(pAssocNext = pAssocRet->pNext)) {
    for(UINT nBucket = pAssocRet->nHashValue + 1;nBucket < m_nHashTableSize;nBucket++)
      if((pAssocNext = m_pHashTable[nBucket])!=NULL)
	break;
  }
  rNextPosition = (DXLISTPOS) pAssocNext;
  rKey = pAssocRet->key;
  rValue = pAssocRet->value;
}

#ifdef _DEBUG
template<class KEY,class ARG_KEY,class VALUE,class ARG_VALUE>
void CDXMap<KEY,ARG_KEY,VALUE,ARG_VALUE>::AssertValid() const {
  _ASSERT(m_nHashTableSize > 0);
  _ASSERT((m_nCount==0 || m_pHashTable!=NULL));
}
#endif

#endif /* __cplusplus */

#endif
