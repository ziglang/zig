# Lazy import

def start():
    global start, stop, publish_exc, wait_until_interrupt
    from server import start, stop, publish_exc, wait_until_interrupt
    return start()

def stop():
    pass

def wait_until_interrupt():
    pass

def publish_exc(exc):
    pass
