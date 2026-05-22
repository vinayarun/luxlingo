import csv
import json
import os
import sys

BASE_CSV = "sentences_edit.csv"
EXPANDED_CSV = "sentences_expanded.csv"

def init_csv():
    if not os.path.exists(EXPANDED_CSV):
        with open(BASE_CSV, 'r', encoding='utf-8') as f_in, open(EXPANDED_CSV, 'w', encoding='utf-8', newline='') as f_out:
            f_out.write(f_in.read())
        print(f"Initialized {EXPANDED_CSV}")
    else:
        print(f"{EXPANDED_CSV} already exists.")

def get_next_batch(batch_size=5):
    ordered_meanings = []
    seen = set()
    rows = []
    with open(BASE_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            m = row['meaning_en']
            rows.append(row)
            if m not in seen:
                seen.add(m)
                ordered_meanings.append(m)
    
    expanded_counts = {m: 0 for m in ordered_meanings}
    with open(EXPANDED_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if '_exp_' in row['sentence_id']:
                expanded_counts[row['meaning_en']] = expanded_counts.get(row['meaning_en'], 0) + 1
    
    batch = []
    for m in ordered_meanings:
        if expanded_counts[m] < 11:
            batch.append(m)
            if len(batch) == batch_size:
                break
                
    if not batch:
        print("All words have been expanded.")
        return
        
    print(f"Next batch to process: {batch}")
    print("Details for prompt:")
    for m in batch:
        for r in rows:
            if r['meaning_en'] == m:
                print(f"Word: {m} | sense_id: {r['sense_id']} | lesson: {r['lesson']} | word_lb: {r['word_lb']}")
                break

def append_generated(json_file):
    with open(json_file, 'r', encoding='utf-8') as f:
        new_sentences = json.load(f)
        
    with open(EXPANDED_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)
        
    counts = {}
    for r in rows:
        if '_exp_' in r['sentence_id']:
            parts = r['sentence_id'].split('_exp_')
            if len(parts) == 2:
                diff_idx = parts[1]
                diff = diff_idx.rstrip('0123456789')
                key = (r['sense_id'], diff)
                counts[key] = counts.get(key, 0) + 1

    meta = {}
    for r in rows:
        m = r['meaning_en']
        if m not in meta:
            meta[m] = {'lesson': r['lesson'], 'word_lb': r['word_lb'], 'sense_id': r['sense_id']}
            
    with open(EXPANDED_CSV, 'a', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        
        for item in new_sentences:
            sense_id = item['sense_id']
            diff = item['difficulty']
            key = (sense_id, diff)
            counts[key] = counts.get(key, 0) + 1
            idx = counts[key]
            
            meaning_en = None
            lesson = None
            word_lb = None
            for m, info in meta.items():
                if info['sense_id'] == sense_id:
                    meaning_en = m
                    lesson = info['lesson']
                    word_lb = info['word_lb']
                    break
                    
            if not meaning_en:
                print(f"Error: Could not find metadata for sense_id {sense_id}")
                continue
                
            sent_id = f"{sense_id}_exp_{diff}{idx}"
            row = {
                'lesson': lesson,
                'sentence_id': sent_id,
                'sense_id': sense_id,
                'word_lb': word_lb,
                'meaning_en': meaning_en,
                'difficulty': diff,
                'text_en': item['text_en'],
                'text_lu': ''
            }
            writer.writerow(row)
    print(f"Appended {len(new_sentences)} sentences.")

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == 'init':
        init_csv()
    elif cmd == 'next':
        get_next_batch()
    elif cmd == 'append':
        append_generated(sys.argv[2])
