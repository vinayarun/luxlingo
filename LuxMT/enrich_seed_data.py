import json
import requests
import time
import os
import difflib

# Configuration
SEED_PATH = "/Users/nv/Projects/luxlingo/app/src/main/assets/seed_data/initial_seed.json"
OUTPUT_PATH = "/Users/nv/Projects/luxlingo/app/src/main/assets/seed_data/initial_seed.json"
LOD_BASE_URL = "https://lod.lu/api"
LUXMT_URL = "https://luxasr.uni.lu/staging/luxmt/translate"
DELAY = 0.3 # Respectful API delay

# Natural Sentence Templates for all 39 core senses
NATURAL_TEMPLATES = {
    "I": ["I am here.", "I am happy."],
    "you": ["You are my friend.", "Do you see me?"],
    "is": ["The cat is black.", "The coffee is hot."],
    "are": ["We are happy.", "The children are playing."],
    "coffee": ["I like coffee.", "The coffee is hot."],
    "warm": ["The soup is warm.", "It is warm in the house."],
    "becomes": ["It becomes cold.", "He becomes a doctor."],
    "not": ["It is not cold.", "I am not tired."],
    "bread": ["I buy bread.", "The bread is fresh."],
    "eat": ["I eat lunch now.", "What do you like to eat?"],
    "drink": ["I drink water.", "What are you drinking?"],
    "water": ["I drink a lot of water.", "The water is on the table."],
    "thank you": ["Thank you for the help.", "Thank you very much."],
    "milk": ["The milk is cold.", "Do you want some milk?"],
    "Hello": ["Hello, how are you?", "Hello, nice to meet you."],
    "Goodbye": ["Goodbye, see you tomorrow.", "Goodbye, have a nice day."],
    "Please": ["Yes, please.", "Coffee, please."],
    "My": ["My name is John.", "My coffee is cold."],
    "Name": ["My name is Lutz.", "What is your name?"],
    "What": ["What is that?", "What do you drink?"],
    "How": ["How are you?", "How does it work?"],
    "and": ["Bread and coffee.", "You and I."],
    "or": ["Coffee or water?", "Tea or coffee?"],
    "your": ["Is that your name?", "Where is your bread?"],
    "that": ["That is good.", "I see that."],
    "You (formal)": ["Are you (formal) happy?", "You (formal) are here."],
    "You (formal/object)": ["I see you (formal).", "I understand you (formal)."],
    "understand": ["I understand you.", "Do you understand?"],
    "tired": ["I am very tired.", "You look tired."],
    "to be called": ["I am called Lutz.", "What are you called?"],
    "slowly": ["Please speak slowly.", "He walks slowly."],
    "me/to me": ["Give it to me.", "He sees me."],
    "good/well": ["This is very good.", "I am doing well."],
    "goes": ["How is it going?", "It goes well."],
    "it": ["It is warm.", "I see it."],
    "with": ["Coffee with milk.", "I am with you."],
    "without": ["Coffee without sugar.", "I am without water."],
    "very": ["It is very warm.", "I am very tired."],
    "if": ["If you want.", "If it is hot."]
}

def get_lod_article_id(query_en):
    """Searches LOD for an English term and returns the first article_id."""
    url = f"{LOD_BASE_URL}/en/search?query={query_en}&lang=en"
    try:
        resp = requests.get(url, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            results = data.get('results', [])
            if results:
                return results[0].get('article_id')
    except Exception as e:
        print(f"LOD Search Error for '{query_en}': {e}")
    return None

def get_lod_entry(article_id):
    """Fetches full entry details from LOD."""
    url = f"{LOD_BASE_URL}/en/entry/{article_id}"
    try:
        resp = requests.get(url, timeout=10)
        if resp.status_code == 200:
            return resp.json()
    except Exception as e:
        print(f"LOD Entry Error for '{article_id}': {e}")
    return None

def translate_to_lb(text_en):
    """Translates English to Luxembourgish using LuxMT."""
    payload = {"text": text_en, "source_lang": "en", "target_lang": "lb"}
    try:
        resp = requests.post(LUXMT_URL, json=payload, timeout=10)
        if resp.status_code == 200:
            return resp.json().get('translated_text')
    except Exception as e:
        print(f"LuxMT Translation Error for '{text_en}': {e}")
    return None

def enrich_pipeline():
    print(f"Loading seed data from {SEED_PATH}...")
    with open(SEED_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    senses = data.get('senses', [])
    new_sentences = []
    
    # We will keep track of unique words already processed to avoid redundant LOD calls
    word_mappings = {}

    print(f"Enriching {len(senses)} senses...")
    
    # Process Senses and Generate Sentences
    for i, sense in enumerate(senses):
        word_en = sense.get('primary_en')
        surface_id = sense.get('surface_id')
        
        print(f"[{i+1}/{len(senses)}] Processing '{word_en}'...")
        
        # 1. LOD.lu Enrichment (Mental Mapping)
        if word_en not in word_mappings:
            art_id = get_lod_article_id(word_en)
            if art_id:
                entry = get_lod_entry(art_id)
                # We could extract metadata here like part-of-speech, but for now we focus on sentences
                word_mappings[word_en] = {"art_id": art_id, "entry": entry}
            else:
                word_mappings[word_en] = None
        
        # 2. Sentence Generation (Natural Examples)
        # Use templates if available, else generate 2 simple ones
        templates = NATURAL_TEMPLATES.get(word_en, [
            f"The {word_en} is here.",
            f"I have {word_en}."
        ])
        
        for text_en in templates[:2]: # Max 2 per word for seed data size
            text_lu = translate_to_lb(text_en)
            if text_lu:
                sent_id = f"sent_{len(new_sentences) + 1:03d}"
                new_sentences.append({
                    "sentence_id": sent_id,
                    "text_en": text_en,
                    "text_lu": text_lu,
                    "sense_ids": [sense.get('sense_id')],
                    "is_handcrafted": False
                })
                print(f"  Added sentence: {text_en} -> {text_lu}")
            
        time.sleep(DELAY)

    # Replace the old sentences with the new natural ones
    data['sentences'] = new_sentences
    
    # Save the overhauled seed data
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"\nSuccessfully overhauled {OUTPUT_PATH}")
    print(f"Total New Sentences: {len(new_sentences)}")

if __name__ == "__main__":
    enrich_pipeline()
