from pypy.module.cpyext.api import cts


freefunc = cts.definitions['freefunc']
destructor = cts.definitions['destructor']
printfunc = cts.definitions['printfunc']
getattrfunc = cts.definitions['getattrfunc']
getattrofunc = cts.definitions['getattrofunc']
setattrfunc = cts.definitions['setattrfunc']
setattrofunc = cts.definitions['setattrofunc']
cmpfunc = cts.definitions['cmpfunc']
reprfunc = cts.definitions['reprfunc']
hashfunc = cts.definitions['hashfunc']
richcmpfunc = cts.definitions['richcmpfunc']
getiterfunc = cts.definitions['getiterfunc']
iternextfunc = cts.definitions['iternextfunc']
descrgetfunc = cts.definitions['descrgetfunc']
descrsetfunc = cts.definitions['descrsetfunc']
initproc = cts.definitions['initproc']
newfunc = cts.definitions['newfunc']
allocfunc = cts.definitions['allocfunc']

unaryfunc = cts.definitions['unaryfunc']
binaryfunc = cts.definitions['binaryfunc']
ternaryfunc = cts.definitions['ternaryfunc']
inquiry = cts.definitions['inquiry']
lenfunc = cts.definitions['lenfunc']
ssizeargfunc = cts.definitions['ssizeargfunc']
ssizessizeargfunc = cts.definitions['ssizessizeargfunc']
ssizeobjargproc = cts.definitions['ssizeobjargproc']
ssizessizeobjargproc = cts.definitions['ssizessizeobjargproc']
objobjargproc = cts.definitions['objobjargproc']

objobjproc = cts.definitions['objobjproc']
visitproc = cts.definitions['visitproc']
traverseproc = cts.definitions['traverseproc']

getter = cts.definitions['getter']
setter = cts.definitions['setter']


getbufferproc = cts.definitions['getbufferproc']
releasebufferproc = cts.definitions['releasebufferproc']


PyGetSetDef = cts.definitions['PyGetSetDef']
PyNumberMethods = cts.definitions['PyNumberMethods']
PySequenceMethods = cts.definitions['PySequenceMethods']
PyMappingMethods = cts.definitions['PyMappingMethods']
PyBufferProcs = cts.definitions['PyBufferProcs']
PyMemberDef = cts.definitions['PyMemberDef']
