import json

file_path = '/Users/constantine/Documents/work/code/projects/km/Sources/Localization/Editor.xcstrings'

with open(file_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

new_strings = {}
keys_to_prefix = [
    "iconPicker.academic",
    "iconPicker.allIcons",
    "iconPicker.common",
    "iconPicker.customSelected",
    "iconPicker.nature",
    "iconPicker.reset",
    "iconPicker.selectIcon",
    "iconPicker.symbols",
    "iconPicker.transport",
    "iconPicker.useDefault"
]

for key, value in data['strings'].items():
    if key in keys_to_prefix:
        new_strings[f"editor.{key}"] = value
    else:
        new_strings[key] = value

data['strings'] = new_strings

with open(file_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Successfully updated Editor.xcstrings with prefixed keys.")
