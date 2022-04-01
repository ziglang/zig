from pypy.interpreter.mixedmodule import MixedModule 

class Module(MixedModule):
    """A demo built-in module based on ctypes."""

    interpleveldefs = {
        'measuretime'      : 'demo.measuretime',
        'sieve'            : 'demo.sieve',
        'MyType'           : 'demo.W_MyType',
    }

    appleveldefs = {
        'DemoError'        : 'app_demo.DemoError',
    }

    # Used in tests
    demo_events = []
    def setup_after_space_initialization(self):
        Module.demo_events.append('setup')
    def startup(self, space):
        Module.demo_events.append('startup')
    def shutdown(self, space):
        Module.demo_events.append('shutdown')

