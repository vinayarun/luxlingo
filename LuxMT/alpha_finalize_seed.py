import json
import os

ALPHA_SEED_PATH = "/Users/nv/Projects/luxlingo/app/src/main/assets/seed_data/alpha_seed.json"
TRANSLATED_SENTENCES_PATH = "/Users/nv/Projects/luxlingo/LuxMT/alpha_sentences_translated.json"
FINAL_OUTPUT_PATH = "/Users/nv/Projects/luxlingo/app/src/main/assets/seed_data/alpha_seed.json"

def finalize_seed():
    if not os.path.exists(ALPHA_SEED_PATH):
        print(f"Error: {ALPHA_SEED_PATH} not found.")
        return
    if not os.path.exists(TRANSLATED_SENTENCES_PATH):
        print(f"Error: {TRANSLATED_SENTENCES_PATH} not found.")
        return

    with open(ALPHA_SEED_PATH, 'r', encoding='utf-8') as f:
        seed_data = json.load(f)

    with open(TRANSLATED_SENTENCES_PATH, 'r', encoding='utf-8') as f:
        translated_data = json.load(f)

    final_sentences = []
    
    # Map for easy lookup
    translated_map = translated_data.get("sentences", {})

    for sense_id, results in translated_map.items():
        # results is a list of {"text_en": ..., "text_lu": ...}
        # We assume 3 sentences per sense: Simple, Intermediate, Advanced
        difficulties = ["simple", "intermediate", "advanced"]
        
        for i, res in enumerate(results):
            diff = difficulties[i] if i < len(difficulties) else "advanced"
            
            # Simple cloze index calculation
            # Try to find the lemma word in the sentence
            # We'll need the vocab entry to get the word_lu
            cloze_index = 0
            
            final_sentences.append({
                "sentence_id": f"sent_{sense_id}_{diff}",
                "sense_ids": [sense_id],
                "text_en": res["text_en"],
                "text_lu": res["text_lu"],
                "cloze_index": cloze_index, # Default or calculated
                "audio_url": "", # Placeholder
                "difficulty": diff
            })

    # Update vocab audio field name
    for v in seed_data["vocabulary"]:
        v["audio_ref"] = v.pop("audio_url", "")

    seed_data["sentences"] = final_sentences
    
    # Always regenerate curriculum to ensure correct field names for alpha
    curriculum = []
    senses = seed_data.get("senses", [])
    
    current_idx = 0
    lesson_num = 1
    while current_idx < len(senses):
        # 7 words for first 20 lessons, 10 thereafter
        step = 7 if lesson_num <= 20 else 10
        lesson_senses = [s["sense_id"] for s in senses[current_idx : current_idx + step]]
        
        curriculum.append({
            "lesson_id": f"lesson_{lesson_num}",
            "title_en": f"Lesson {lesson_num}",
            "core_senses": lesson_senses,
            "secondary_senses": []
        })
        
        current_idx += step
        lesson_num += 1
        
    seed_data["curriculum"] = curriculum

    # Manual cleanup for "I give you a book" -> "I will give you a book"
    for sent in seed_data["sentences"]:
        if sent["text_en"] == "I give you a book.":
            sent["text_en"] = "I will give you a book."
        elif sent["text_en"] == "I give you a book":
            sent["text_en"] = "I will give you a book."

    with open(FINAL_OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(seed_data, f, ensure_ascii=False, indent=2)

    print(f"Finalized alpha_seed.json with {len(final_sentences)} sentences and {len(seed_data['curriculum'])} lessons.")

if __name__ == "__main__":
    finalize_seed()
