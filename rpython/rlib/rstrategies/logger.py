
class LogEntry(object):
    def __init__(self):
        self.slots = 0
        self.objects = 0
        self.element_typenames = {}
        
    def add(self, size, element_typename):
        self.slots += size
        self.objects += 1
        if element_typename:
            self.element_typenames[element_typename] = None
    
    def classnames(self):
        return self.element_typenames.keys()

class Logger(object):
    _attrs_ = ["active", "aggregate", "logs"]
    _immutable_fields_ = ["active?", "aggregate?", "logs"]
    
    def __init__(self):
        self.active = False
        self.aggregate = False
        self.logs = {}
    
    def activate(self, aggregate=False):
        self.active = True
        self.aggregate = self.aggregate or aggregate
    
    def log(self, new_strategy, size, cause="", old_strategy="", typename="", element_typename=""):
        if self.aggregate:
            key = (cause, old_strategy, new_strategy, typename)
            if key not in self.logs:
                self.logs[key] = LogEntry()
            entry = self.logs[key]
            entry.add(size, element_typename)
        else:
            element_typenames = [ element_typename ] if element_typename else []
            self.output(cause, old_strategy, new_strategy, typename, size, 1, element_typenames)
    
    def print_aggregated_log(self):
        if not self.aggregate:
            return
        for key, entry in self.logs.items():
            cause, old_strategy, new_strategy, typename = key
            slots, objects, element_typenames = entry.slots, entry.objects, entry.classnames()
            self.output(cause, old_strategy, new_strategy, typename, slots, objects, element_typenames)
    
    def output(self, cause, old_strategy, new_strategy, typename, slots, objects, element_typenames):
        old_strategy_string = "%s -> " % old_strategy if old_strategy else ""
        classname_string = " of %s" % typename if typename else ""
        element_string = (" elements: " + " ".join(element_typenames)) if element_typenames else ""
        format = (cause, old_strategy_string, new_strategy, classname_string, slots, objects, element_string)
        self.do_print("%s (%s%s)%s size %d objects %d%s" % format)
    
    def do_print(self, str):
        # Hook to increase testability
        print str
