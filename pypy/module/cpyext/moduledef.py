from pypy.interpreter.mixedmodule import MixedModule
from pypy.module.cpyext.state import State
from pypy.module.cpyext import api

class Module(MixedModule):
    interpleveldefs = {
        'is_cpyext_function': 'interp_cpyext.is_cpyext_function',
        'FunctionType': 'methodobject.W_PyCFunctionObject',
    }

    appleveldefs = {
    }

    atexit_funcs = []

    def startup(self, space):
        space.fromcache(State).startup(space)

    def register_atexit(self, function):
        if len(self.atexit_funcs) >= 32:
            raise ValueError("cannot register more than 32 atexit functions")
        self.atexit_funcs.append(function)

    def shutdown(self, space):
        for func in self.atexit_funcs:
            func()


# import these modules to register api functions by side-effect
import pypy.module.cpyext.pyobject
import pypy.module.cpyext.boolobject
import pypy.module.cpyext.floatobject
import pypy.module.cpyext.modsupport
import pypy.module.cpyext.pythonrun
import pypy.module.cpyext.pyerrors
import pypy.module.cpyext.typeobject
import pypy.module.cpyext.object
import pypy.module.cpyext.bytesobject
import pypy.module.cpyext.bytearrayobject
import pypy.module.cpyext.tupleobject
import pypy.module.cpyext.setobject
import pypy.module.cpyext.dictobject
import pypy.module.cpyext.longobject
import pypy.module.cpyext.listobject
import pypy.module.cpyext.sequence
import pypy.module.cpyext.buffer
import pypy.module.cpyext.eval
import pypy.module.cpyext.import_
import pypy.module.cpyext.mapping
import pypy.module.cpyext.iterator
import pypy.module.cpyext.unicodeobject
import pypy.module.cpyext.sysmodule
import pypy.module.cpyext.number
import pypy.module.cpyext.sliceobject
import pypy.module.cpyext.stubsactive
import pypy.module.cpyext.pystate
import pypy.module.cpyext.cdatetime
import pypy.module.cpyext.complexobject
import pypy.module.cpyext.weakrefobject
import pypy.module.cpyext.funcobject
import pypy.module.cpyext.frameobject
import pypy.module.cpyext.classobject
import pypy.module.cpyext.exception
import pypy.module.cpyext.memoryobject
import pypy.module.cpyext.codecs
import pypy.module.cpyext.pyfile
import pypy.module.cpyext.pystrtod
import pypy.module.cpyext.pytraceback
import pypy.module.cpyext.methodobject
import pypy.module.cpyext.dictproxyobject
import pypy.module.cpyext.marshal
import pypy.module.cpyext.genobject
import pypy.module.cpyext.namespaceobject
import pypy.module.cpyext.pystrhex
import pypy.module.cpyext.contextvars

# now that all rffi_platform.Struct types are registered, configure them
api.configure_types()
