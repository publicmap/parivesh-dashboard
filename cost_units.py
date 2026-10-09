import re

ONES = {w: i for i, w in enumerate(
    'zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen'.split())}
TENS = {w: 10 * i for i, w in enumerate('_ _ twenty thirty forty fifty sixty seventy eighty ninety'.split()) if w != '_'}
SCALES = {'lakh': 1e5, 'lakhs': 1e5, 'lac': 1e5, 'lacs': 1e5, 'crore': 1e7, 'crores': 1e7, 'cr': 1e7}
TOKEN = re.compile(r'\d+(?:\.\d+)?|[a-z]+')


def text_to_lakhs(text):
    if not text:
        return None
    total, group, current, seen, point = 0.0, 0.0, 0.0, False, None
    for tok in TOKEN.findall(str(text).lower()):
        if tok == 'point':
            point = ''
        elif point is not None and tok in ONES and ONES[tok] < 10:
            point += str(ONES[tok])
        elif tok in ONES:
            current += ONES[tok]; seen = True
        elif tok in TENS:
            current += TENS[tok]; seen = True
        elif tok == 'hundred':
            current = max(current, 1) * 100; seen = True
        elif tok == 'thousand':
            group += max(current, 1) * 1e3; current = 0.0; seen = True
        elif tok in SCALES:
            if point:
                current += float('0.' + point); point = None
            total += (group + max(current, 1 if not group else 0)) * SCALES[tok]; group = current = 0.0; seen = True
        elif tok[0].isdigit():
            current += float(tok); seen = True
    if point:
        current += float('0.' + point)
    total += group + current
    return total / 1e5 if seen and total > 0 else None


def normalize_cost_lakhs(value, text):
    try:
        v = float(value)
    except (TypeError, ValueError):
        return value
    expected = text_to_lakhs(text)
    if not expected or v <= 0:
        return value
    close = lambda a: abs(a - expected) <= 0.02 * expected + 0.01
    if close(v):
        return value
    if close(v / 1e5):
        return v / 1e5
    return value
