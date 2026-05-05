import json
import sys

def add_keys(file_path, keys_to_add):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    for key, (zh, en) in keys_to_add.items():
        data['strings'][key] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": en
                    }
                },
                "zh-Hans": {
                    "stringUnit": {
                        "state": "translated",
                        "value": zh
                    }
                }
            }
        }
    
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# Localizable.xcstrings
add_keys('Sources/Localization/Localizable.xcstrings', {
    "synthesis.clearAllConfirm": ("清空全部合成文档", "Clear all synthesized documents"),
    "synthesis.batchDeleteConfirm": ("删除选中的合成文档", "Delete selected synthesized documents")
})

# AITasks.xcstrings
add_keys('Sources/Localization/AITasks.xcstrings', {
    "aitask.clearConfirmTitle": ("清空任务历史", "Clear Task History"),
    "aitask.clearConfirmMessage": ("此操作将清除所有已完成和失败的任务记录，不可恢复。", "This will clear all completed and failed task records. This action cannot be undone.")
})

# Backup.xcstrings
add_keys('Sources/Localization/Backup.xcstrings', {
    "deleteConfirmTitle": ("删除备份", "Delete Backup"),
    "deleteConfirmMessage": ("您确定要永久删除此备份吗？此操作不可撤销。", "Are you sure you want to permanently delete this backup? This action cannot be undone.")
})

print("✅ Localization keys added successfully.")
