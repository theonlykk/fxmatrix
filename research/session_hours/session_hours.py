"""Layer outcome by the UTC hour of entry (HANDOFF s89: does a session gate earn?). STUB: tests first."""


def broker_to_utc(s):
    raise NotImplementedError


def block(dt):
    raise NotImplementedError


def in_window(dt):
    raise NotImplementedError


def layers(records):
    raise NotImplementedError


def in_era(layers_, start, end):
    raise NotImplementedError


def summarise(layers_, commission):
    raise NotImplementedError


def verdict(eras):
    raise NotImplementedError
