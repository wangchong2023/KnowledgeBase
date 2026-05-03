import json
import os

file_path = 'Sources/Localization/Localizable.xcstrings'
with open(file_path, 'r') as f:
    data = json.load(f)

new_strings = {
    "onboarding.step.welcome.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "欢迎使用 %@" } },
            "en": { "stringUnit": { "state": "translated", "value": "Welcome to %@" } }
        }
    },
    "onboarding.step.welcome.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "开启您的知识管理新纪元" } },
            "en": { "stringUnit": { "state": "translated", "value": "Start your new era of knowledge management" } }
        }
    },
    "onboarding.step.linking.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识关联" } },
            "en": { "stringUnit": { "state": "translated", "value": "Knowledge Linking" } }
        }
    },
    "onboarding.step.linking.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "通过 [[链接]] 发现想法之间的隐藏联系" } },
            "en": { "stringUnit": { "state": "translated", "value": "Discover hidden connections via [[links]]" } }
        }
    },
    "onboarding.step.aiLab.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "AI 实验室" } },
            "en": { "stringUnit": { "state": "translated", "value": "AI Lab" } }
        }
    },
    "onboarding.step.aiLab.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "让 AI 帮您深度扫描、总结和合成知识" } },
            "en": { "stringUnit": { "state": "translated", "value": "Let AI help you scan, summarize and synthesize" } }
        }
    },
    "onboarding.step.graph.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "动态图谱" } },
            "en": { "stringUnit": { "state": "translated", "value": "Dynamic Graph" } }
        }
    },
    "onboarding.step.graph.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "在 2D 和 3D 空间中俯瞰您的知识宇宙" } },
            "en": { "stringUnit": { "state": "translated", "value": "Oversee your knowledge universe in 2D and 3D" } }
        }
    },
    "onboarding.step.vault.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "隐私与安全" } },
            "en": { "stringUnit": { "state": "translated", "value": "Privacy & Security" } }
        }
    },
    "onboarding.step.vault.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "所有数据存储在本地，端到端加密保护" } },
            "en": { "stringUnit": { "state": "translated", "value": "Local storage with E2E encryption" } }
        }
    },
    "onboarding.action.start": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "立即开启" } },
            "en": { "stringUnit": { "state": "translated", "value": "Get Started" } }
        }
    },
    "onboarding.action.next": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "下一步" } },
            "en": { "stringUnit": { "state": "translated", "value": "Next" } }
        }
    },
    "onboarding.action.skip": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "跳过" } },
            "en": { "stringUnit": { "state": "translated", "value": "Skip" } }
        }
    },
    "medal.wall.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "荣誉奖章" } },
            "en": { "stringUnit": { "state": "translated", "value": "Medal Wall" } }
        }
    },
    "medal.wall.count": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "已获得 %lld 枚奖章" } },
            "en": { "stringUnit": { "state": "translated", "value": "%lld Medals Earned" } }
        }
    },
    "medal.totalEarned": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "获得总数" } },
            "en": { "stringUnit": { "state": "translated", "value": "Total Earned" } }
        }
    },
    "medal.progress": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "达成进度" } },
            "en": { "stringUnit": { "state": "translated", "value": "Progress" } }
        }
    },
    "medal.category.explore": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "探索达人" } },
            "en": { "stringUnit": { "state": "translated", "value": "Explorer" } }
        }
    },
    "medal.category.accumulation": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识富翁" } },
            "en": { "stringUnit": { "state": "translated", "value": "Accumulator" } }
        }
    },
    "medal.category.connection": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "架构大师" } },
            "en": { "stringUnit": { "state": "translated", "value": "Architect" } }
        }
    },
    "medal.congrats": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "恭喜获得" } },
            "en": { "stringUnit": { "state": "translated", "value": "Congratulations" } }
        }
    },
    "medal.first_page.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "第一块砖" } },
            "en": { "stringUnit": { "state": "translated", "value": "First Brick" } }
        }
    },
    "medal.first_page.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "创建了第一个知识页面" } },
            "en": { "stringUnit": { "state": "translated", "value": "Created your first page" } }
        }
    },
    "medal.nodes_5.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "初露锋芒" } },
            "en": { "stringUnit": { "state": "translated", "value": "Early Bloomer" } }
        }
    },
    "medal.nodes_5.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识库节点数达到 5 个" } },
            "en": { "stringUnit": { "state": "translated", "value": "Reached 5 nodes" } }
        }
    },
    "medal.nodes_10.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "勤勉学者" } },
            "en": { "stringUnit": { "state": "translated", "value": "Diligent Scholar" } }
        }
    },
    "medal.nodes_10.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识库节点数达到 10 个" } },
            "en": { "stringUnit": { "state": "translated", "value": "Reached 10 nodes" } }
        }
    },
    "medal.nodes_100.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "百卷藏书" } },
            "en": { "stringUnit": { "state": "translated", "value": "Centennial Library" } }
        }
    },
    "medal.nodes_100.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识库节点数达到 100 个" } },
            "en": { "stringUnit": { "state": "translated", "value": "Reached 100 nodes" } }
        }
    },
    "medal.links_5.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "关联初探" } },
            "en": { "stringUnit": { "state": "translated", "value": "Connection Probe" } }
        }
    },
    "medal.links_5.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识库链接数达到 5 个" } },
            "en": { "stringUnit": { "state": "translated", "value": "Reached 5 links" } }
        }
    },
    "medal.links_10.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "织网专家" } },
            "en": { "stringUnit": { "state": "translated", "value": "Web Weaver" } }
        }
    },
    "medal.links_10.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识库链接数达到 10 个" } },
            "en": { "stringUnit": { "state": "translated", "value": "Reached 10 links" } }
        }
    },
    "medal.links_100.title": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识主宰" } },
            "en": { "stringUnit": { "state": "translated", "value": "Knowledge Overlord" } }
        }
    },
    "medal.links_100.desc": {
        "localizations": {
            "zh-Hans": { "stringUnit": { "state": "translated", "value": "知识库链接数达到 100 个" } },
            "en": { "stringUnit": { "state": "translated", "value": "Reached 100 links" } }
        }
    }
}

data['strings'].update(new_strings)
with open(file_path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
