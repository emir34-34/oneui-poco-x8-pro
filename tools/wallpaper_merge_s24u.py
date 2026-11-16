import json, sys, re
s26p, s24p, outp = sys.argv[1:4]
a = json.load(open(s26p)); b = json.load(open(s24p))
renk = {'ZKLG': 'str_id_black', 'ZT': 'str_id_gray', 'ZVLB': 'str_id_violet', 'ZYZO': 'str_id_yellow'}
vids, stat = [], []
for e in b['phone']:
    if e.get('screen') != 0: continue
    e = json.loads(json.dumps(e)); e['isDefault'] = False
    if e['type'] == 10:
        kod = re.search(r'_([A-Z]+)\.mp4', e['filename']).group(1)
        fn = f's24_infinity_{kod.lower()}.mp4'
        e['filename'] = fn; e['type_params']['service_settings']['filename'] = fn
        e['desc_str_id'] = renk[kod]; vids.append(e)
    elif e['type'] == 0:
        e['filename'] = 's24_' + e['filename'].lower(); stat.append(e)
for i, e in enumerate(stat):
    e['desc_str_id'] = renk[['ZKLG', 'ZT', 'ZVLB', 'ZYZO'][min(i // 2, 3)]]
ph = a['phone']
ph[:] = [e for e in ph if not (e['screen']==0 and e['type'] in (0,10) and re.match(r'(video|wallpaper)_00[1-6]', e.get('filename','')))]
stat[0]['isDefault'] = True
vids[0]['isDefault'] = True
iv = 0
ph[iv:iv] = vids
ist = max(i for i, e in enumerate(ph) if e['type'] in (0,10) and e['screen'] == 0) + 1
ph[ist:ist] = stat
n = 0
for e in ph:
    if e['screen'] == 0 and e['type'] in (0, 10) and e.get('which') != 11:
        e['index'] = n; n += 1
a['dex'] = []
json.dump(a, open(outp, 'w'), ensure_ascii=False, indent=2)
for e in ph:
    if e['screen'] == 0 and e['type'] in (0, 10): print(e['type'], e.get('which'), e['index'], e['isDefault'], e['filename'], e.get('desc_str_id'))
