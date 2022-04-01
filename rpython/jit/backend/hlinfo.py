
class HighLevelJITInfo:
    """
    A singleton class for the RPython-level JITed program to push information
    that the backend can use or log.
    """
    sys_executable = None


highleveljitinfo = HighLevelJITInfo()
