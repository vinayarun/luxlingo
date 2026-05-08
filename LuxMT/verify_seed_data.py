import json
import requests
import time
import difflib
import os

# Configuration
SEED_PATH = "/Users/nv/Projects/luxlingo/app/src/main/assets/seed_data/initial_seed.json"
API_URL = "https://luxasr.uni.lu/staging/luxmt/translate"
SIMILARITY_THRESHOLD = 0.95
DELAY_SECONDS = 0.2

def get_translation(text_en):
    payload = {
        "text": text_en,
        "source_lang": "en",
        "target_lang": "lb"
    }
    try:
        response = requests.post(API_URL, json=payload, timeout=10)
        if response.status_code == 200:
            return response.json().get('translated_text')
        else:
            print(f"API Error ({response.status_code}): {response.text}")
    except Exception as e:
        print(f"Request Exception: {e}")
    return None

def verify_data():
    if not os.path.exists(SEED_PATH):
        print(f"Error: Seed file not found at {SEED_PATH}")
        return

    with open(SEED_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    sentences = data.get('sentences', [])
    total = len(sentences)
    updated_count = 0
    match_count = 0
    error_count = 0
    corrections = []

    print(f"Starting verification of {total} sentences...")

    for i, entry in enumerate(sentences):
        text_en = entry.get('text_en')
        text_lu_old = entry.get('text_lu')
        
        print(f"[{i+1}/{total}] Processing: {text_en[:30]}...")
        
        text_lu_new = get_translation(text_en)
        
        if text_lu_new:
            # Calculate similarity
            similarity = difflib.SequenceMatcher(None, text_lu_old, text_lu_new).ratio()
            
            if similarity < SIMILARITY_THRESHOLD:
                print(f"  Significant difference found (sim={similarity:.2f})")
                print(f"  Old: {text_lu_old}")
                print(f"  New: {text_lu_new}")
                
                # Update entry
                entry['text_lu'] = text_lu_new
                entry['is_handcrafted'] = False
                updated_count += 1
                
                corrections.append({
                    "id": entry.get('sentence_id'),
                    "en": text_en,
                    "old": text_lu_old,
                    "new": text_lu_new,
                    "similarity": similarity
                })
            else:
                match_count += 1
        else:
            error_count += 1
            
        # Small delay to respect the API
        time.sleep(DELAY_SECONDS)

    # Save results
    if updated_count > 0:
        with open(SEED_PATH, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"\nSaved updates to {SEED_PATH}")

    # Final Summary
    print("\nVerification Summary:")
    print(f"Total Sentences: {total}")
    print(f"Matches (>=95%): {match_count}")
    print(f"Updated (<95%): {updated_count}")
    print(f"Errors: {error_count}")

    # Save a detailed report for the AI to present
    report = {
        "stats": {
            "total": total,
            "matches": match_count,
            "updated": updated_count,
            "errors": error_count
        },
        "corrections": corrections
    }
    with open("/tmp/verification_results.json", "w", encoding="utf-8") as rf:
        json.dump(report, rf, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    verify_data()
