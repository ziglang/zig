from rpython.jit.backend.detect_cpu import *


def test_autodetect():
    try:
        name = autodetect()
    except ProcessorAutodetectError:
        pass
    else:
        assert isinstance(name, str)

def test_getcpuclassname():
    try:
        modname, clsname = getcpuclassname()
    except ProcessorAutodetectError:
        pass
    else:
        assert isinstance(modname, str)
        assert isinstance(clsname, str)

def test_getcpuclass():
    try:
        cpu = getcpuclass()
    except ProcessorAutodetectError:
        pass
    else:
        from rpython.jit.backend.model import AbstractCPU
        assert issubclass(cpu, AbstractCPU)


def test_detect_model_from_c_compiler():
    info1 = detect_model_from_host_platform()
    info2 = detect_model_from_c_compiler()
    assert info1 == info2

def test_getcpufeatures():
    features = getcpufeatures()
    assert isinstance(features, list)
    for x in features:
        assert x in ['floats', 'singlefloats', 'longlong']
