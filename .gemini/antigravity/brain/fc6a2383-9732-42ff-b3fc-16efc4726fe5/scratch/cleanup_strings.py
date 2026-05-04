import json

path = '/Users/constantine/Documents/work/code/projects/km/Sources/Localization/Localizable.xcstrings'

with open(path, 'r') as f:
    data = json.load(f)

if 'strings' in data:
    keys_to_remove = [k for k in data['strings'] if k.startswith('settings.') or k.startswith('ai.') or k.startswith('aitask.') or k.startswith('graph.')]
    print(f"Removing {len(keys_to_remove)} keys...")
    for k in keys_to_remove:
        del data['strings'][k]

with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("Optimization complete.")
