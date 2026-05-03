import json
import re
import os

def find_tr_keys(directory):
    keys = set()
    tr_pattern = re.compile(r'Localized\.tr\("([^"]+)"\)')
    trf_pattern = re.compile(r'Localized\.trf\("([^"]+)"')
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.swift'):
                with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                    content = f.read()
                    keys.update(tr_pattern.findall(content))
                    keys.update(trf_pattern.findall(content))
    return keys

def load_xcstrings(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return set(data.get('strings', {}).keys())

def main():
    sources_dir = 'Sources'
    xcstrings_file = 'Sources/Localization/Localizable.xcstrings'
    
    code_keys = find_tr_keys(sources_dir)
    xcstrings_keys = load_xcstrings(xcstrings_file)
    
    missing_keys = code_keys - xcstrings_keys
    
    if missing_keys:
        print(f"Found {len(missing_keys)} missing keys in Localizable.xcstrings:")
        for key in sorted(missing_keys):
            print(f"  - {key}")
    else:
        print("All Localized.tr keys are present in Localizable.xcstrings.")

if __name__ == "__main__":
    main()
