#!/usr/bin/env python3
"""Fix quality issues in the new batch sentences."""
import json, re, shutil, datetime

SEED_PATH = 'ios/LuxLingo/LuxLingo/Resources/initial_seed.json'

seed = json.load(open(SEED_PATH, encoding='utf-8'))
by_id = {s['sentence_id']: s for s in seed['sentences']}

fixes = 0

# ── 1. "now today" / "today now" redundancy in English ──────────────────────
# EN: "now today" → "today" / "today now" → "today"
# LU: "elo haut" → "haut" / "haut elo" → "haut"
now_today_count = 0
for s in seed['sentences']:
    if '_new' not in s.get('sentence_id', ''):
        continue
    en = s['text_en']
    lu = s.get('text_lu', '')
    changed = False

    # Fix English
    new_en = re.sub(r'\bnow today\b', 'today', en, flags=re.IGNORECASE)
    new_en = re.sub(r'\btoday now\b', 'today', new_en, flags=re.IGNORECASE)
    if new_en != en:
        s['text_en'] = new_en
        changed = True

    # Fix Luxembourgish
    new_lu = re.sub(r'\belo haut\b', 'haut', lu, flags=re.IGNORECASE)
    new_lu = re.sub(r'\bhaut elo\b', 'haut', new_lu, flags=re.IGNORECASE)
    if new_lu != lu:
        s['text_lu'] = new_lu
        changed = True

    if changed:
        now_today_count += 1
        fixes += 1

print(f'Fixed now_today redundancy: {now_today_count}')

# ── 2. Child characters going to work ───────────────────────────────────────
child_work_fixes = {
    'sent_s_fréi_1_new6': (
        'Paul goes to school early.',
        'De Paul geet fréi an d\'Schoul.'
    ),
    'sent_s_spéit_1_new6': (
        'Paul goes to school late.',
        'De Paul geet spéit an d\'Schoul.'
    ),
    'sent_s_nächst_1_new6': (
        'Paul goes to school next Monday.',
        'De Paul geet nächsten Méindeg an d\'Schoul.'
    ),
    'sent_s_moies_1_new6': (
        'Paul goes to school in the morning.',
        'De Paul geet moies an d\'Schoul.'
    ),
    'sent_s_ewech_1_new6': (
        'Paul is away at school now.',
        'De Paul ass elo an der Schoul.'
    ),
    'sent_s_sou datt_1_new11': (
        'Lena makes a warm breakfast so that everyone is ready for school.',
        'Lena mécht e waarmt Moiesiessen, sou datt jiddereen fir d\'Schoul prett ass.'
    ),
}
for sid, (en, lu) in child_work_fixes.items():
    if sid in by_id:
        by_id[sid]['text_en'] = en
        by_id[sid]['text_lu'] = lu
        fixes += 1
print(f'Fixed child_work: {len(child_work_fixes)}')

# ── 3. War / military content ────────────────────────────────────────────────
# Reframe to historical/book context — word "Krich" is valid vocab but needs age-appropriate framing
war_fixes = {
    'sent_s_krich_1_new1': (
        'In the history book, there is a big war.',
        'Am Geschichtsbuch gëtt et e grousse Krich.'
    ),
    'sent_s_krich_1_new2': (
        'In the old story, the war is very real.',
        'An der aler Geschicht ass de Krich ganz reell.'
    ),
    'sent_s_krich_1_new3': (
        'War is very bad.',
        'De Krich ass ganz schlëmm.'
    ),
    'sent_s_krich_1_new4': (
        'In the history book, people help during the war.',
        'Am Geschichtsbuch hëllefen d\'Leit während dem Krich.'
    ),
    'sent_s_krich_1_new5': (
        'In the old story, the war is finally over.',
        'An der aler Geschicht ass de Krich endlech eriwwer.'
    ),
    'sent_s_krich_1_new6': (
        'Paul reads about the big war in his history book.',
        'De Paul liest iwwer de grousse Krich an sengem Geschichtsbuch.'
    ),
    'sent_s_krich_1_new7': (
        'Mr. Weiss teaches about the old war.',
        'Här Weiss léiert iwwer de ale Krich.'
    ),
    'sent_s_krich_1_new8': (
        'Natali hears about the old war in her history class.',
        'Natali héiert vum ale Krich a hirem Geschichtscoers.'
    ),
    'sent_s_krich_1_new9': (
        'Neighbors chat about the old war in the quiet village.',
        'Noperen schwätzen iwwer de ale Krich am rouege Duerf.'
    ),
    'sent_s_krich_1_new10': (
        'Claire and Marc learn about the old war at school.',
        'Claire a Marc léieren iwwer de ale Krich an der Schoul.'
    ),
    'sent_s_krich_1_new11': (
        'Lena reads about the old war while she is at school.',
        'Lena liest vum ale Krich, während si an der Schoul ass.'
    ),
}
for sid, (en, lu) in war_fixes.items():
    if sid in by_id:
        by_id[sid]['text_en'] = en
        by_id[sid]['text_lu'] = lu
        fixes += 1
print(f'Fixed war_military: {len(war_fixes)}')

# ── 4. Emergency content ─────────────────────────────────────────────────────
# Reframe to safety/first-aid context appropriate for children
emergency_fixes = {
    'sent_s_noutfall_1_new1': (
        'There is an emergency at the hospital.',
        'Et gëtt en Noutfall am Spidol.'
    ),
    'sent_s_noutfall_1_new2': (
        'The emergency needs quick help.',
        'D\'Noutlag brauch séier Hëllef.'
    ),
    'sent_s_noutfall_1_new3': (
        'Marc calls for help in the emergency.',
        'Marc rifft no Hëllef an der Nout.'
    ),
    'sent_s_noutfall_1_new4': (
        'We help each other in an emergency.',
        'Mir hëllefen eis géigesäiteg an engem Noutfall.'
    ),
    'sent_s_noutfall_1_new5': (
        'The emergency is over and everyone is safe.',
        'De Noutfall ass eriwwer a jiddereen ass sécher.'
    ),
    'sent_s_noutfall_1_new6': (
        'Paul calls 112 for the big emergency.',
        'De Paul rifft 112 fir déi grouss Nout.'
    ),
    'sent_s_noutfall_1_new7': (
        'Mr. Weiss teaches about emergency safety today.',
        'Här Weiss léiert haut iwwer d\'Noutfallsécherheet.'
    ),
    'sent_s_noutfall_1_new8': (
        'Natali learns what to do in an emergency.',
        'Natali léiert, wat si an enger Noutlag maache soll.'
    ),
    'sent_s_noutfall_1_new9': (
        'Neighbors help each other in the emergency.',
        'Noperen hëllefen sech géigesäiteg an der Nout.'
    ),
    'sent_s_noutfall_1_new10': (
        'Claire and Marc learn about emergency safety at school.',
        'Claire a Marc léieren iwwer Noutfallsécherheet an der Schoul.'
    ),
    'sent_s_noutfall_1_new11': (
        'Lena learns about the emergency exit while she is at school.',
        'Lena léiert vum Noutausgang, während si an der Schoul ass.'
    ),
}
for sid, (en, lu) in emergency_fixes.items():
    if sid in by_id:
        by_id[sid]['text_en'] = en
        by_id[sid]['text_lu'] = lu
        fixes += 1
print(f'Fixed emergency: {len(emergency_fixes)}')

# ── 5. Board ambiguity ───────────────────────────────────────────────────────
board_fixes = {
    'sent_s_schreiwen_1_new6': (
        'Mr. Weiss writes on the blackboard.',
        'Här Weiss schreift um Tafell.'
    ),
    'sent_s_un_1_new7': (
        'Mr. Weiss writes a new word on the blackboard.',
        'Här Weiss schreift e neit Wuert um Tafell.'
    ),
    'sent_s_et_1_new9': (
        'Mr. Weiss writes a new word on the blackboard and asks the children to read it.',
        'Här Weiss schreift e neit Wuert op d\'Tafel a freet d\'Kanner, et ze liesen.'
    ),
    'sent_s_wuert_1_new11': (
        'Claire helps Marc to spell the word on the blackboard.',
        'Claire hëlleft dem Marc, d\'Wuert um Tafell ze buchstabéieren.'
    ),
}
for sid, (en, lu) in board_fixes.items():
    if sid in by_id:
        by_id[sid]['text_en'] = en
        by_id[sid]['text_lu'] = lu
        fixes += 1
print(f'Fixed board_ambiguous: {len(board_fixes)}')

# ── 6. Natali awkward measurement sentences ──────────────────────────────────
natali_fixes = {
    'sent_s_gewiicht_1_new8': (
        'Natali puts her bag on the scale to check its weight.',
        'Natali leet hir Taasch op d\'Waage fir hiert Gewiicht ze kontrolléieren.'
    ),
    'sent_s_héicht_1_new8': (
        'Natali knows her own height.',
        'Natali weess hir eegen Héicht.'
    ),
    'sent_s_längt_1_new8': (
        'Natali measures the length of the table.',
        'Natali moosst d\'Längt vum Dësch.'
    ),
    'sent_s_déift_1_new8': (
        'Natali measures the depth of the water.',
        'Natali moosst d\'Déift vum Waasser.'
    ),
}
for sid, (en, lu) in natali_fixes.items():
    if sid in by_id:
        by_id[sid]['text_en'] = en
        by_id[sid]['text_lu'] = lu
        fixes += 1
print(f'Fixed natali_awkward: {len(natali_fixes)}')

# ── 7. Sibling romantic language ─────────────────────────────────────────────
sibling_fixes = {
    'sent_s_léift_1_new10': (
        'Claire and Marc share their joy while they play in the park.',
        'Claire a Marc deelen hir Freed, während si am Park spillen.'
    ),
}
for sid, (en, lu) in sibling_fixes.items():
    if sid in by_id:
        by_id[sid]['text_en'] = en
        by_id[sid]['text_lu'] = lu
        fixes += 1
print(f'Fixed sibling_romantic: {len(sibling_fixes)}')

# ── Save ─────────────────────────────────────────────────────────────────────
bk = SEED_PATH + f'.bak_{datetime.datetime.now().strftime("%Y%m%d_%H%M%S")}'
shutil.copy2(SEED_PATH, bk)

old_ver = seed.get('version', 6.9)
seed['version'] = round(old_ver + 0.1, 1)
with open(SEED_PATH, 'w', encoding='utf-8') as f:
    json.dump(seed, f, ensure_ascii=False, indent=2)

print(f'\nTotal fixes: {fixes}')
print(f'Seed: v{old_ver} → v{seed["version"]}')
print(f'Backup: {bk}')
