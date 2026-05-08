import json
import requests
import time
import os

# Configuration
SENTENCE_FILES = [
    "/Users/nv/Projects/luxlingo/LuxMT/sentences_en_1_50.json",
    "/Users/nv/Projects/luxlingo/LuxMT/sentences_en_51_100.json",
    "/Users/nv/Projects/luxlingo/LuxMT/sentences_en_101_200.json",
    "/Users/nv/Projects/luxlingo/LuxMT/sentences_en_201_300.json",
    "/Users/nv/Projects/luxlingo/LuxMT/sentences_en_301_400.json",
    "/Users/nv/Projects/luxlingo/LuxMT/sentences_en_401_500.json",
    "/Users/nv/Projects/luxlingo/LuxMT/sentences_en_501_638.json"
]
LUXMT_URL = "https://luxasr.uni.lu/staging/luxmt/translate"
OUTPUT_PATH = "/Users/nv/Projects/luxlingo/LuxMT/alpha_sentences_translated.json"
STATE_PATH = "/Users/nv/Projects/luxlingo/LuxMT/translate_state.json"

def translate_text(text_en):
    payload = {"text": text_en, "source_lang": "en", "target_lang": "lb"}
    try:
        resp = requests.post(LUXMT_URL, json=payload, timeout=10)
        if resp.status_code == 200:
            return resp.json().get('translated_text')
    except Exception as e:
        print(f"Error translating '{text_en[:20]}...': {e}")
    return None

def run_translation():
    # Merge all source sentences
    all_sentences = {}
    for file_path in SENTENCE_FILES:
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                all_sentences.update(json.load(f))
    
    # Load state
    state = {}
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH, 'r', encoding='utf-8') as f:
            state = json.load(f)
            
    translated_results = state.get("results", {})
    processed_senses = state.get("processed_senses", [])

    total_senses = len(all_sentences)
    print(f"Starting translation of {total_senses} senses (approx {total_senses*3} sentences)...")

    for sense_id, sentences_en in all_sentences.items():
        if sense_id in processed_senses:
            continue
            
        print(f"Translating sense: {sense_id} ({len(processed_senses)+1}/{total_senses})...")
        translated_for_sense = []
        for text_en in sentences_en:
            text_lu = translate_text(text_en)
            if text_lu:
                translated_for_sense.append({
                    "text_en": text_en,
                    "text_lu": text_lu
                })
            else:
                # If translation fails, add English as fallback or skip
                translated_for_sense.append({
                    "text_en": text_en,
                    "text_lu": "[TRANSLATION_FAILED]"
                })
            time.sleep(0.1) # Small delay to avoid hammering
            
        translated_results[sense_id] = translated_for_sense
        processed_senses.append(sense_id)
        
        # Save state every 10 senses
        if len(processed_senses) % 10 == 0:
            state["results"] = translated_results
            state["processed_senses"] = processed_senses
            with open(STATE_PATH, 'w', encoding='utf-8') as f:
                json.dump(state, f, ensure_ascii=False, indent=2)
            print(f"Progress saved: {len(processed_senses)} senses processed.")

    # Final Save
    final_output = {
        "sentences": translated_results
    }
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)
    
    print(f"Translation complete! Results saved to {OUTPUT_PATH}")

if __name__ == "__main__":
    run_translation()
