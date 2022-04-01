from rpython.rlib.objectmodel import specialize

class DummyVMProf(object):
    is_enabled = False

    def __init__(self):
        self._unique_id = 0

    def register_code_object_class(self, CodeClass, full_name_func):
        CodeClass._vmprof_unique_id = self._unique_id
        self._unique_id += 1

    @specialize.argtype(1)
    def register_code(self, code, full_name_func):
        pass

    def enable(self, fileno, interval, memory=0, native=0, real_time=0):
        pass

    def disable(self):
        pass

    def start_sampling(self):
        pass

    def stop_sampling(self):
        return -1
