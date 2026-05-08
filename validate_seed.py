import json
import os

def validate_luxlingo_json(filepath):
    if not os.path.exists(filepath):
        print(f"❌ Error: {filepath} not found.")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 1. Map all IDs for cross-referencing
    vocab_ids = {v['surface_id'] for v in data.get('vocabulary', [])}
    sense_ids = {s['sense_id'] for s in data.get('senses', [])}
    sentence_ids = {st['sentence_id'] for st in data.get('sentences', [])}

    errors = []

    # 2. Check Senses -> Vocab link
    for sense in data.get('senses', []):
        if sense['surface_id'] not in vocab_ids:
            errors.append(f"Sense '{sense['sense_id']}' points to missing vocab '{sense['surface_id']}'")

    # 3. Check Curriculum -> Senses (Orphans)
    for lesson in data.get('curriculum', []):
        lesson_id = lesson['lesson_id']
        core_senses = lesson.get('core_senses', [])

        # Find all sentences assigned to this lesson (if filtered by lesson_id)
        # Or find all sentences that use the core senses
        for sense_id in core_senses:
            if sense_id not in sense_ids:
                errors.append(f"Lesson '{lesson_id}' requires missing sense '{sense_id}'")

            # Check if at least one sentence contains this core sense
            has_sentence = any(sense_id in st.get('sense_ids', []) for st in data.get('sentences', []))
            if not has_sentence:
                errors.append(f"🚫 ORPHAN: Sense '{sense_id}' is required in Lesson '{lesson_id}' but NO sentence uses it!")

    # 4. Check Sentences -> Senses
    for st in data.get('sentences', []):
        for s_id in st.get('sense_ids', []):
            if s_id not in sense_ids:
                errors.append(f"Sentence '{st['sentence_id']}' uses missing sense '{s_id}'")

    # Output results
    if not errors:
        print("✅ JSON Data is valid and pedagogical loops are closed!")
    else:
        print(f"❌ Found {len(errors)} errors:")
        for err in errors:
            print(f"  - {err}")

if __name__ == "__main__":
    validate_luxlingo_json('initial_seed.json')
