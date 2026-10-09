#!/usr/bin/env python3
"""Resolve NEEDED libs of the parameter_parser service against the One UI root;
pull missing ones from the phone (Axion) and check undefined symbols."""
import os, subprocess, sys
ROOT, W = sys.argv[1], sys.argv[2]
BIONIC = {'libc.so', 'libm.so', 'libdl.so', 'libdl_android.so', 'ld-android.so'}
DIRS = ['system/lib64', 'system_ext/lib64']
def needed(p):
    out = subprocess.run(['readelf', '-dW', p], capture_output=True, text=True).stdout
    return [l.split('[')[1].split(']')[0] for l in out.splitlines() if '(NEEDED)' in l]
def syms(p, defined):
    out = subprocess.run(['nm', '-D', '--defined-only' if defined else '--undefined-only', p], capture_output=True, text=True).stdout
    return {l.split()[-1].split('@')[0] for l in out.splitlines() if l.strip()}
def in_oneui(l):
    for d in DIRS:
        p = os.path.join(ROOT, d, l)
        if os.path.exists(p): return p
def pull(l):
    dst = os.path.join(W, 'libs', l); os.makedirs(os.path.dirname(dst), exist_ok=True)
    if not os.path.exists(dst):
        for src in ('/system/lib64/', '/system_ext/lib64/'):
            if subprocess.run(['adb', 'pull', src + l, dst], capture_output=True).returncode == 0: break
        else: return None
    return dst
todo = [os.path.join(W, 'android.hardware.audio.parameter_parser.service')]
seen, add, have = set(), [], {}
while todo:
    p = todo.pop()
    for l in needed(p):
        if l in seen or l in BIONIC: continue
        seen.add(l)
        q = in_oneui(l)
        if q: have[l] = q; continue
        q = pull(l)
        if not q: print('BULUNAMADI', l); continue
        add.append(l); todo.append(q)
print('EKLENECEK:', ' '.join(sorted(add)))
# undefined symbol check for everything we add (binary + new libs)
provide = set()
for l, q in have.items(): provide |= syms(q, True)
for l in add: provide |= syms(os.path.join(W, 'libs', l), True)
bion = set()
for b in ('libc.so', 'libm.so', 'libdl.so'):
    p = os.path.join(ROOT, 'system/lib64/bootstrap', b)
    p = p if os.path.exists(p) else os.path.join(ROOT, 'system/lib64', b)
    if os.path.exists(p): bion |= syms(p, True)
for f in [os.path.join(W, 'android.hardware.audio.parameter_parser.service')] + [os.path.join(W, 'libs', l) for l in add]:
    miss = sorted(s for s in syms(f, False) - provide - bion if s and not s.startswith('__cxa') )
    print(os.path.basename(f), 'eksik sembol:', len(miss), miss[:8])
