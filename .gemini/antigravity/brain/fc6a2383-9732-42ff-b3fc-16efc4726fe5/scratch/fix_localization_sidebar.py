import json
import os

file_path = 'Sources/Localization/Localizable.xcstrings'
with open(file_path, 'r') as f:
    data = json.load(f)

new_strings = {
    "sidebar.knowledge": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识库" } },
            "en": { "stringUnit": { "state": "translated", "value": "Knowledge" } }
        }
    },
    "sidebar.system": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "系统" } },
            "en": { "stringUnit": { "state": "translated", "value": "System" } }
        }
    },
    "sidebar.tools": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "工具" } },
            "en": { "stringUnit": { "state": "translated", "value": "Tools" } }
        }
    },
    "app.name": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识灵动" } },
            "en": { "stringUnit": { "state": "translated", "value": "KM Lingdong" } }
        }
    },
    "settings.language.system": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "跟随系统" } },
            "en": { "stringUnit": { "state": "translated", "value": "Follow System" } }
        }
    },
    "settings.language.chinese": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "简体中文" } },
            "en": { "stringUnit": { "state": "translated", "value": "Simplified Chinese" } }
        }
    },
    "settings.language.english": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "English" } },
            "en": { "stringUnit": { "state": "translated", "value": "English" } }
        }
    }
}

data['strings'].update(new_strings)
with open(file_path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
