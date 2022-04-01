
class ProfileAgent(object):
    """ A class that communicates to a profiler which assembler code belongs to
    which functions. """

    def startup(self):
        pass
    def shutdown(self):
        pass
    def native_code_written(self, name, address, size):
        pass

