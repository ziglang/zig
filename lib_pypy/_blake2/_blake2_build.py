import os
import sys
import platform

from cffi import FFI

IS_WIN = sys.platform == 'win32'
if IS_WIN:
    BLAKE2_USE_SSE = True
    extra_compile_args = []
    define_macros = [('__SSE2__', '1')]
elif platform.machine().startswith('x86'):
    BLAKE2_USE_SSE = True
    extra_compile_args = ['-msse2']
    define_macros = []
else:
    BLAKE2_USE_SSE = False
    extra_compile_args = []
    define_macros = []
    
    

blake_cdef = """
#define BLAKE_OUTBYTES ...
#define BLAKE_SALTBYTES ...
#define BLAKE_BLOCKBYTES ...
#define BLAKE_PERSONALBYTES ...
#define BLAKE_KEYBYTES ...

typedef struct {
    uint8_t digest_length;
    uint8_t key_length;
    uint8_t fanout;
    uint8_t depth;
    uint32_t leaf_length;
    uint8_t node_depth;
    // node_offset is a bit special
    uint8_t inner_length;
    uint8_t salt[...];
    uint8_t personal[...];
    ...;
} blake_param ;

typedef struct {
   uint8_t last_node;
    ...;
} blake_state ;

int blake_init_param( blake_state *S, const blake_param *P );
int blake_update( blake_state *S, const uint8_t *in, uint64_t inlen );
int blake_final( blake_state *S, uint8_t *out, uint8_t outlen );

void* addressof_node_offset(blake_param *S);

void store32(void* dst, uint32_t w);
void store48(void* dst, uint64_t w);
void store64(void* dst, uint64_t w);
"""

blake2b_source = """
#include "impl/blake2.h"
#include "impl/blake2-impl.h"

#define BLAKE_OUTBYTES BLAKE2B_OUTBYTES
#define BLAKE_SALTBYTES BLAKE2B_SALTBYTES
#define BLAKE_BLOCKBYTES BLAKE2B_BLOCKBYTES
#define BLAKE_PERSONALBYTES BLAKE2B_PERSONALBYTES
#define BLAKE_KEYBYTES BLAKE2B_KEYBYTES

typedef blake2b_state blake_state;
typedef blake2b_param blake_param;

#define blake_init_param blake2b_init_param
#define blake_update blake2b_update
#define blake_final blake2b_final

void* addressof_node_offset(blake_param *S) {
  return &(S->node_offset);
}
"""


# since we cdir, we use a relative path. If we use an absolute path, we get
# compile cruft in a multi-level subdir
_libdir = 'impl'
if BLAKE2_USE_SSE:
    sourcesB=[os.path.join(_libdir, 'blake2b.c'), ]
    sourcesS=[os.path.join(_libdir, 'blake2s.c'), ]
else:    
    sourcesB=[os.path.join(_libdir, 'blake2b-ref.c'), ]
    sourcesS=[os.path.join(_libdir, 'blake2s-ref.c'), ]

blake2b_ffi = FFI()
blake2b_ffi.cdef(blake_cdef)
blake2b_ffi.set_source(
    '_blake2b_cffi', blake2b_source,
    sources=sourcesB,
    include_dirs=[_libdir],
    extra_compile_args=extra_compile_args,
    define_macros=define_macros,
)

def _replace_b2s(src):
    for b, s in (('blake2b', 'blake2s'),
                 ('BLAKE2B', 'BLAKE2S')):
        src = src.replace(b, s)
    return src

blake2s_ffi = FFI()
blake2s_ffi.cdef(blake_cdef)
blake2s_ffi.set_source(
    '_blake2s_cffi', _replace_b2s(blake2b_source),
    sources=sourcesS,
    include_dirs=[_libdir],
    extra_compile_args=extra_compile_args,
    define_macros=define_macros,
)

if __name__ == '__main__':
    os.chdir(os.path.dirname(__file__))
    blake2b_ffi.compile()
    blake2s_ffi.compile()
