import numpy as np

def G(s): return sum(ord(c.upper())-64 for c in s if c.isalpha())

T = [
    0xF2E7, 0x0D2F, 0x8000, 0x0054, 0x000C,
    0x0031, 0x0079, 0x00A9, 0x624B
]

STREAMS = {
    'P12_5': "For the oppression of the poor for the sighing of the needy now will I arise saith the LORD I will set him in safety from him that puffeth at him",
    'Q2_255': "Allah There is no god but He the Living the Self subsisting Eternal No slumber can seize Him nor sleep His are all things in the heavens and on earth",
    'P45_14': "She shall be brought unto the king in raiment of needlework the virgins her companions that follow her shall be brought unto thee"
}

def analyze():
    res = {}
    for name, text in STREAMS.items():
        g = G(text)
        words = len(text.split())
        chars = len(text.replace(' ',''))
        res[name] = {'g': g, 'words': words, 'chars': chars, 'hits': []}
        vals = [g, words, chars, g%10000, words*chars%100000, g+words, g*words%100000]
        for v in vals:
            for t in T:
                if v == t:
                    res[name]['hits'].append(hex(t))
                if v % 1000 == t % 1000:
                    res[name]['hits'].append(f'~{hex(t)}')
    for k,v in res.items():
        if v['hits']:
            print(f"MATCH {k}: {v['hits']}")
    total_g = sum(res[s]['g'] for s in res)
    if total_g in T: print(f"MATCH TOTAL_G: {hex(total_g)}")
    if total_g % 1000 in [t % 1000 for t in T]: print(f"MATCH TOTAL_G~: {hex(total_g)}")

if __name__ == '__main__':
    analyze()
