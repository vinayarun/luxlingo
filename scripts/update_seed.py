import json, re, os

path = '/mnt/HDDs/VinayDocs2/Research/vscode/luxlingo_3/app/src/main/assets/seed_data/initial_seed.json'
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

UZ = set('unitedzoahUNITEDZOAH')

def apply_n_rule(text):
    words = text.split()
    processed = []
    has_modified = False
    for i in range(len(words)):
        w = words[i]
        # Regex to split word and punctuation
        mm = re.search(r'^([\w\']*[ëäöüÄËÖÜ\w]+)([.,!?;]*)$', w)
        if not mm:
            processed.append(w)
            continue
        stem, punct = mm.groups()
        
        # Candidate rule: check if it ends in n
        if stem.lower().endswith('n'):
            should_drop = False
            if i + 1 < len(words):
                next_word = words[i+1]
                nm = re.search(r'[a-zA-ZëäöüÄËÖÜ]', next_word)
                if nm:
                    if nm.group(0) not in UZ:
                        should_drop = True
                else:
                    should_drop = True # Punctuation
            else:
                should_drop = True # End of sentence
            
            if should_drop:
                # Blacklist/Whitelist for N-rule (A1 subset)
                candidates = ['den', 'een', 'vun', 'an', 'wann', 'keen', 'hien', 'sinn', 'hunn', 'moien', 'verstinn', 'heeschen', 'drénken', 'iessen']
                if stem.lower() in candidates or stem.lower().endswith('en'):
                    old_stem = stem
                    if stem.lower() in ['sinn', 'hunn']:
                        stem = stem[:-2]
                    else:
                        stem = stem[:-1]
                    if old_stem != stem:
                        has_modified = True
        
        processed.append(stem + punct)
    return ' '.join(processed), has_modified

# 1. Update existing sentences
modified_count = 0
for sent in data['sentences']:
    # Conjugation verify before rule
    lu = sent['text_lu']
    lu = lu.replace('Du heescht ', 'Du heeschts ').replace('Du heescht?', 'Du heeschts?')
    lu = lu.replace('Du verstinn', 'Du verstees').replace('Du versti ', 'Du verstees ')
    lu = lu.replace('Dir verstoen', 'Dir verstitt').replace('Dir verstoe ', 'Dir verstitt ')
    lu = lu.replace('Dir heeschen', 'Dir heescht').replace('Dir heesche ', 'Dir heescht ')
    
    new_lu, changed = apply_n_rule(lu)
    if lu != new_lu:
        sent['text_lu'] = new_lu
        modified_count += 1

# 2. Inject Glue Words
glue = {
    'w_mat': ['l_mat', 'mat', 'with', 'preposition'],
    'w_ouni': ['l_ouni', 'ouni', 'without', 'preposition'],
    'w_ganz': ['l_ganz', 'ganz', 'very', 'adverb'],
    'w_wann': ['l_wann', 'wann', 'if', 'conjunction']
}
v_ids = {v['surface_id'] for v in data['vocabulary']}
for sid, info in glue.items():
    if sid not in v_ids:
        data['vocabulary'].append({'surface_id': sid, 'lemma_id': info[0], 'word_lu': info[1], 'audio_ref': f'audio/{info[1]}.mp3'})

s_ids = {s['sense_id'] for s in data['senses']}
for sid, info in glue.items():
    sense_id = f's_{sid[2:]}_1'
    if sense_id not in s_ids:
        data['senses'].append({
            'sense_id': sense_id, 
            'surface_id': sid, 
            'primary_en': info[2], 
            'pos': info[3], 
            'is_golden_key': True,
            'is_picturable': False
        })
    else:
        for s in data['senses']:
            if s['sense_id'] == sense_id:
                s['is_golden_key'] = True

for s in data['senses']:
    if s['sense_id'] == 's_et_1':
        s['is_golden_key'] = True

# 3. Add context for new words
existing_ids = {s['sentence_id'] for s in data['sentences']}
ns_data = [
    ('Ech si mat Dir.', 'I am with you.', ['s_ech_1', 's_sinn_is_1', 's_mat_1', 's_dir_formal'], 1),
    ('Brout mat Kaffi.', 'Bread with coffee.', ['s_brout_1', 's_mat_1', 's_kaffi_1'], 1),
    ('Kaffi ouni Mëllech.', 'Coffee without milk.', ['s_kaffi_1', 's_ouni_1', 's_mellech_1'], 1),
    ('Dat ass ganz gutt.', 'That is very good.', ['s_dat_1', 's_sinn_is_1', 's_ganz_1', 's_gutt_1'], 2),
    ('Wann Dir verstitt.', 'If you (formal) understand.', ['s_wann_1', 's_dir_formal', 's_verstoen_1'], 0)
]
for i, (lu, en, sids, cloze) in enumerate(ns_data):
    sid = f'sent_zoah_glue_{i}'
    if sid not in existing_ids:
        data['sentences'].append({
            'sentence_id': sid,
            'text_lu': lu,
            'text_en': en,
            'sense_ids': sids,
            'cloze_index': cloze,
            'lex_coverage': 1.0,
            'syn_density': 1,
            'is_handcrafted': True
        })

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f'MODIFIED: {modified_count}')
