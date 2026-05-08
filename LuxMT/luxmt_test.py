import requests

def check_translation():
    url = "https://luxasr.uni.lu/staging/luxmt/translate"
    
    # We'll test a simple phrase
    data = {
        "text": "The weather is beautiful today.",
        "source_lang": "en",
        "target_lang": "lb"
    }
    
    print("Connecting to University of Luxembourg servers...")
    
    try:
        response = requests.post(url, json=data)
        if response.status_code == 200:
            result = response.json()
            # The API returns a dictionary; we pull the translation value
            translated = result.get('translated_text', 'No translation found')
            print(f"\nSuccess!")
            print(f"English: {data['text']}")
            print(f"Luxembourgish: {translated}")
        else:
            print(f"Failed with status code: {response.status_code}")
            print(f"Message: {response.text}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    check_translation()