#!/usr/bin/env python3
"""fastboot komutunu calistirip ciktisindaki 'Sending/Writing [sparse] ... N/M' parcalarindan yuzde cubugu cizer.
Kullanim: fastboot_ilerleme.py "<baslik>" fastboot flash super super.img
"""
import subprocess, sys, re, time, shutil, threading

baslik, cmd = sys.argv[1], sys.argv[2:]
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
st = {'done': 0, 'total': 0, 'durum': 'başlıyor', 'pending': False}
t0 = time.time(); log = []; lock = threading.Lock(); bitti = threading.Event()
rx = re.compile(r"(Sending|Writing|Erasing|Formatting)(?: sparse)? '[^']+'(?: (\d+)/(\d+))?")

def ciz():
    with lock:
        w = max(20, min(50, shutil.get_terminal_size((80, 20)).columns - 45))
        oran = st['done'] / st['total'] if st['total'] else 0
        dolu = int(w * oran); gecen = int(time.time() - t0)
        kalan = f"~{int(gecen / oran - gecen)}s kaldı" if 0.02 < oran < 1 else ''
        sys.stdout.write(f"\r{baslik:<10} [{'█' * dolu}{'░' * (w - dolu)}] {oran * 100:5.1f}%  {gecen:>4}s {kalan:<12} {st['durum']:<18}")
        sys.stdout.flush()

def saat():
    while not bitti.wait(1): ciz()
threading.Thread(target=saat, daemon=True).start()

seg = ''
while True:
    b = p.stdout.read(1)
    if not b: break
    c = b.decode('utf-8', 'replace'); seg += c
    if c not in '\n])': continue
    log.append(seg)
    with lock:
        m = rx.search(seg)
        if m:
            kind, n, mm = m.groups()
            if mm: st['total'] = 2 * int(mm)
            elif not st['total']: st['total'] = 2
            st['pending'] = True
            st['durum'] = ({'Sending':'gönderiliyor ','Writing':'yazılıyor '}.get(kind,'siliniyor ')) + (f'{n}/{mm}' if n else '')
        if 'OKAY' in seg and st['pending']:
            st['done'] = min(st['total'], st['done'] + 1); st['pending'] = False
        if 'FAILED' in seg: st['durum'] = 'HATA'
    seg = ''
rc = p.wait(); bitti.set()
if rc == 0:
    with lock: st['total'] = max(st['total'], 1); st['done'] = st['total']; st['durum'] = 'tamam ✓'
ciz(); print()
if rc != 0:
    print(''.join(log[-12:])); print(f'HATA: {" ".join(cmd)} (çıkış {rc})')
sys.exit(rc)
