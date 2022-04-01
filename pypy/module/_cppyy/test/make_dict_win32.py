import glob, os, sys, subprocess

USES_PYTHON_CAPI = set(('pythonizables',))

fn = sys.argv[1]

if fn == 'all':
    all_headers = glob.glob('*.h')
    for header in all_headers:
        res = os.system(" ".join(['python', sys.argv[0], header[:-2]]+sys.argv[2:]))
        if res != 0:
            sys.exit(res)
    sys.exit(0)
else:
    if fn[-4:] == '.cxx': fn = fn[:-4]
    elif fn[-2:] == '.h': fn = fn[:-2]
    if not os.path.exists(fn+'.h'):
        print("file %s.h does not exist" % (fn,))
        sys.exit(1)

uses_python_capi = False
if fn in USES_PYTHON_CAPI:
    uses_python_capi = True

if os.path.exists(fn+'Dict.dll'):
    dct_time = os.stat(fn+'Dict.dll').st_mtime
    if not '-f' in sys.argv:
        mustbuild = False
        for ext in ['.h', '.cxx', '.xml']:
            if os.stat(fn+ext).st_mtime > dct_time:
                mustbuild = True
                break
        if not mustbuild:
            sys.exit(0)

 # cleanup
    for fg in set(glob.glob(fn+"_rflx*") + glob.glob(fn+"Dict*") + \
                  glob.glob("*.obj") + glob.glob(fn+"Linkdef.h")):
        os.remove(fg)

def _get_config_exec():
        return [sys.executable, '-m', 'cppyy_backend._cling_config']

def get_config(what):
    config_exec_args = _get_config_exec()
    config_exec_args.append('--'+what)
    cli_arg = subprocess.check_output(config_exec_args)
    return cli_arg.decode("utf-8").strip()

def get_python_include_dir():
    incdir = subprocess.check_output([sys.executable, '-c', "import sysconfig; print(sysconfig.get_path('include'))"])
    return incdir.decode("utf-8").strip()

def get_python_lib_dir():
    libdir = subprocess.check_output([sys.executable, '-c', "import sysconfig; print(sysconfig.get_path('stdlib'))"])
    return os.path.join(os.path.dirname(libdir.decode("utf-8").strip()), 'libs')

# genreflex option
#DICTIONARY_CMD = "genreflex {fn}.h --selection={fn}.xml --rootmap={fn}Dict.rootmap --rootmap-lib={fn}Dict.dll".format(fn=fn)

with open(fn+'Linkdef.h', 'w') as linkdef:
    linkdef.write("#ifdef __CLING__\n\n")
    linkdef.write("#pragma link C++ defined_in %s.h;\n" % fn)
    linkdef.write("\n#endif")

DICTIONARY_CMD = "python -m cppyy_backend._rootcling -f {fn}_rflx.cxx -rmf {fn}Dict.rootmap -rml {fn}Dict.dll {fn}.h {fn}Linkdef.h".format(fn=fn)
if os.system(DICTIONARY_CMD):
    sys.exit(1)

import platform
if '64' in platform.architecture()[0]:
    PLATFORMFLAG = '-D_AMD64_'
    MACHINETYPE  = 'X64'
else:
    PLATFORMFLAG = '-D_X86_'
    MACHINETYPE  = 'IX86'

cppflags = get_config('cppflags')
if uses_python_capi:
    cppflags += ' -I"' + get_python_include_dir() + '"'
BUILDOBJ_CMD_PART = "cl -O2 -nologo -TP -c -nologo " + cppflags + " -FIsehmap.h -Zc:__cplusplus -MD -GR -D_WINDOWS -DWIN32 " + PLATFORMFLAG + " -EHsc- -W3 -wd4141 -wd4291 -wd4244 -wd4049 -D_XKEYCHECK_H -D_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER -DNOMINMAX -D_CRT_SECURE_NO_WARNINGS {fn}.cxx -Fo{fn}.obj"
BUILDOBJ_CMD = BUILDOBJ_CMD_PART.format(fn=fn)
if os.system(BUILDOBJ_CMD):
    sys.exit(1)
BUILDOBJ_CMD = BUILDOBJ_CMD_PART.format(fn=fn+'_rflx')
if os.system(BUILDOBJ_CMD):
    sys.exit(1)

import cppyy_backend
CREATEDEF_CMD = "python bindexplib.py {fn} {fn}Dict".format(fn=fn)
if os.system(CREATEDEF_CMD):
    sys.exit(1)

ldflags = ''
if uses_python_capi:
    ldflags = ' /LIBPATH:"' + get_python_lib_dir() + '" '
CREATELIB_CMD = ("lib -nologo -MACHINE:" + MACHINETYPE + " -out:{fn}Dict.lib {fn}.obj {fn}_rflx.obj -def:{fn}Dict.def " + ldflags).format(fn=fn)
if os.system(CREATELIB_CMD):
    sys.exit(1)

ldflags += get_config('ldflags')
LINKDLL_CMD = ("link -nologo {fn}.obj {fn}_rflx.obj -DLL -out:{fn}Dict.dll {fn}Dict.exp " + ldflags).format(fn=fn)
if os.system(LINKDLL_CMD):
    sys.exit(1)

# cleanup
for fg in set(glob.glob(fn+"_rflx.cxx*") + glob.glob("*.obj") + glob.glob(fn+"Linkdef.h")):
    os.remove(fg)
