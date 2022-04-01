from rpython.jit.metainterp.support import ptr2int

class Boxes(object):
    pass

def get_real_model():
    class LoopModel(object):
        from rpython.jit.metainterp.history import TreeLoop, JitCellToken
        from rpython.jit.metainterp.history import ConstInt, ConstPtr, ConstFloat
        from rpython.jit.metainterp.history import BasicFailDescr, BasicFinalDescr, TargetToken
        from rpython.jit.metainterp.opencoder import Trace

        from rpython.jit.metainterp.history import get_const_ptr_for_string
        from rpython.jit.metainterp.history import get_const_ptr_for_unicode
        get_const_ptr_for_string = staticmethod(get_const_ptr_for_string)
        get_const_ptr_for_unicode = staticmethod(get_const_ptr_for_unicode)

        @staticmethod
        def convert_to_floatstorage(arg):
            from rpython.jit.codewriter import longlong
            return longlong.getfloatstorage(float(arg))

        @staticmethod
        def ptr_to_int(obj):
            return ptr2int(obj)

    return LoopModel

def get_mock_model():
    class MockLoopModel(object):
        class TreeLoop(object):
            def __init__(self, name):
                self.name = name

        class JitCellToken(object):
            I_am_a_descr = True

        class TargetToken(object):
            def __init__(self, jct):
                pass

        class BasicFailDescr(object):
            I_am_a_descr = True
            final_descr = False

        class BasicFinalDescr(object):
            I_am_a_descr = True
            final_descr = True

        class Box(object):
            _counter = 0
            type = 'b'

            def __init__(self, value=0):
                self.value = value

            def __repr__(self):
                result = str(self)
                result += '(%s)' % self.value
                return result

            def __str__(self):
                if not hasattr(self, '_str'):
                    self._str = '%s%d' % (self.type, Box._counter)
                    Box._counter += 1
                return self._str

        class BoxInt(Box):
            type = 'i'

        class BoxFloat(Box):
            type = 'f'

        class BoxRef(Box):
            type = 'p'

        class BoxVector(Box):
            type = 'V'

        class Const(object):
            bytesize = 8
            signed = True
            def __init__(self, value=None):
                self.value = value

            def _get_str(self):
                return str(self.value)

            def is_constant(self):
                return True

        class ConstInt(Const):
            datatype = 'i'
            pass

        class ConstPtr(Const):
            datatype = 'r'
            pass

        class ConstFloat(Const):
            datatype = 'f'
            signed = False
            pass

        @classmethod
        def get_const_ptr_for_string(cls, s):
            return cls.ConstPtr(s)

        @classmethod
        def get_const_ptr_for_unicode(cls, s):
            return cls.ConstPtr(s)

        @staticmethod
        def convert_to_floatstorage(arg):
            return float(arg)

        @staticmethod
        def ptr_to_int(obj):
            return id(obj)

    return MockLoopModel


def get_model(use_mock):
    if use_mock:
        model = get_mock_model()
    else:
        model = get_real_model()

    class ExtendedTreeLoop(model.TreeLoop):

        def as_json(self):
            return {
                'comment': self.comment,
                'name': self.name,
                'operations': [op.as_json() for op in self.operations],
                'inputargs': self.inputargs,
                'last_offset': self.last_offset
            }

        def getboxes(self):
            def opboxes(operations):
                for op in operations:
                    yield op.result
                    for box in op.getarglist():
                        yield box
            def allboxes():
                for box in self.inputargs:
                    yield box
                for box in opboxes(self.operations):
                    yield box

            boxes = Boxes()
            for box in allboxes():
                if isinstance(box, model.Box):
                    name = str(box)
                    setattr(boxes, name, box)
            return boxes

        def setvalues(self, **kwds):
            boxes = self.getboxes()
            for name, value in kwds.iteritems():
                getattr(boxes, name).value = value

    model.ExtendedTreeLoop = ExtendedTreeLoop
    return model
