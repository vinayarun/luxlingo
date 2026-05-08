import json
import requests
import os
import sys

# Configuration
SEED_PATH = "/Users/nv/Projects/luxlingo/app/src/main/assets/seed_data/initial_seed.json"
API_URL = "https://luxasr.uni.lu/staging/luxmt/translate"

def get_translation(text_en):
    payload = {"text": text_en, "source_lang": "en", "target_lang": "lb"}
    try:
        response = requests.post(API_URL, json=payload, timeout=10)
        return response.json().get('translated_text') if response.status_code == 200 else None
    except:
        return None

def generate_lesson(title_en, core_vocab_en, sentences_en):
    if not os.path.exists(SEED_PATH):
        print("Error: Seed file not found.")
        return

    with open(SEED_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 1. Generate Sense IDs and Vocabulary
    lesson_id = f"lesson_{len(data['curriculum']) + 1:03d}"
    new_senses = []
    core_sense_ids = []
    
    print(f"Generating lesson: {title_en} ({lesson_id})")
    
    for word_en in core_vocab_en:
        trans = get_translation(word_en)
        if not trans:
            print(f"Skipping {word_en} due to translation error.")
            continue
            
        # Create a simple id
        clean_word = word_en.lower().replace(" ", "_")
        sense_id = f"s_{clean_word}_gen"
        surface_id = f"w_{clean_word}_gen"
        
        # Check if already exists
        if any(s['sense_id'] == sense_id for s in data['senses']):
             sense_id += f"_{len(data['senses'])}"

        # Add to Senses
        data['senses'].append({
            "sense_id": sense_id,
            "surface_id": surface_id,
            "primary_en": word_en,
            "pos": "unknown",
            "is_golden_key": False,
            "is_picturable": False
        })
        
        # Add to Vocabulary (minimal)
        data['vocabulary'].append({
            "surface_id": surface_id,
            "lemma_id": f"l_{clean_word}",
            "word_lu": trans,
            "audio_ref": ""
        })
        
        core_sense_ids.append(sense_id)
        print(f"  Added vocabulary: {word_en} -> {trans}")

    # 2. Generate Sentences
    new_sent_ids = []
    for sent_en in sentences_en:
        trans = get_translation(sent_en)
        if not trans: continue
        
        sent_id = f"sent_{len(data['sentences']) + 1:03d}"
        
        data['sentences'].append({
            "sentence_id": sent_id,
            "text_lu": trans,
            "text_en": sent_en,
            "sense_ids": core_sense_ids, # Assign to all core senses for now
            "cloze_index": 0,
            "lex_coverage": 1.0,
            "syn_density": 1.0,
            "is_handcrafted": False
        })
        new_sent_ids.append(sent_id)
        print(f"  Added sentence: {sent_en} -> {trans}")

    # 3. Add to Curriculum
    data['curriculum'].append({
        "lesson_id": lesson_id,
        "title_en": title_en,
        "core_senses": core_sense_ids,
        "secondary_senses": [],
        "prereqs": [],
        "theme_tag": "generated"
    })

    # Save
    with open(SEED_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"\nSuccessfully added lesson {lesson_id} to {SEED_PATH}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python generate_lesson.py \"Lesson Title\" \"word1,word2\" \"sent1. sent2.\"")
    else:
        title = sys.argv[1]
        vocab = [w.strip() for w in sys.argv[2].split(",")]
        sentences = [s.strip() for s in sys.argv[3].split(".") if s.strip()]
        generate_lesson(title, vocab, sentences)
