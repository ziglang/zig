import os
import sys

from cffi import FFI


ffi = FFI()
ffi.cdef("""
typedef struct {
    unsigned int rate;
    ...;
} KeccakWidth1600_SpongeInstance;

typedef struct {
    KeccakWidth1600_SpongeInstance sponge;
    unsigned int fixedOutputLength;
    unsigned char delimitedSuffix;
    ...;
} Keccak_HashInstance;

typedef enum { SUCCESS = ..., FAIL = ..., BAD_HASHLEN = ... } HashReturn;
typedef int... DataLength;
typedef unsigned char BitSequence;

HashReturn Keccak_HashInitialize_SHA3_224(Keccak_HashInstance*);
HashReturn Keccak_HashInitialize_SHA3_256(Keccak_HashInstance*);
HashReturn Keccak_HashInitialize_SHA3_384(Keccak_HashInstance*);
HashReturn Keccak_HashInitialize_SHA3_512(Keccak_HashInstance*);
HashReturn Keccak_HashInitialize_SHAKE128(Keccak_HashInstance*);
HashReturn Keccak_HashInitialize_SHAKE256(Keccak_HashInstance*);

HashReturn Keccak_HashUpdate(Keccak_HashInstance *, const BitSequence *, DataLength);
HashReturn Keccak_HashFinal(Keccak_HashInstance *, BitSequence *);
HashReturn Keccak_HashSqueeze(Keccak_HashInstance *hashInstance, BitSequence *data, DataLength databitlen);
""")

_libdir = os.path.join(os.path.dirname(__file__), 'kcp')

if sys.byteorder == 'big':
    # opt64 is not yet supported on big endian platforms
    keccakOpt = 32
elif sys.maxsize > 2**32:
    keccakOpt = 64
else:
    keccakOpt = 32

ffi.set_source(
    '_sha3_cffi',
("#define KeccakOpt %d\n" % keccakOpt) +
"""
/* we are only interested in KeccakP1600 */
#define KeccakP200_excluded 1
#define KeccakP400_excluded 1
#define KeccakP800_excluded 1

#if KeccakOpt == 64
  /* 64bit platforms with unsigned int64 */
  typedef uint64_t UINT64;
  typedef unsigned char UINT8;
#endif

/* inline all Keccak dependencies */
#include "kcp/KeccakHash.h"
#include "kcp/KeccakSponge.h"
#include "kcp/KeccakHash.c"
#include "kcp/KeccakSponge.c"
#if KeccakOpt == 64
  #include "kcp/KeccakP-1600-opt64.c"
#elif KeccakOpt == 32
  #include "kcp/KeccakP-1600-inplace32BI.c"
#endif
""",
    include_dirs=[_libdir],
)

if __name__ == '__main__':
    os.chdir(os.path.dirname(__file__))
    ffi.compile()
