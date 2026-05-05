import json
import os

path = '/Users/constantine/Documents/work/code/projects/km/Sources/Localization/Localizable.xcstrings'
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Define prompts
mindmap_prompt = """请根据提供的内容，生成一个层级清晰的 Mermaid 思维导图 (Mindmap)。
要求：
1. 首行必须是 '# <总结标题>'（语言与内容一致）。
2. 以 'mindmap' 开头。
3. 根节点用 'root((标题))'。
4. 使用缩进表示层级，禁止使用 '-' 开头。
5. 节点文字禁止包含任何括号 '()'、冒号 ':' 或方括号 '[]'。
6. 禁止使用 Markdown 代码块包裹（即禁止使用 ``` 符号）。"""

infographic_prompt = """请根据提供的内容，生成一张逻辑严密的 Mermaid 可视化信息图 (Flowchart)。
要求：
1. 首行必须是 '# <总结标题>'（语言与内容一致）。
2. 第二行开始输出 Mermaid 代码，以 'graph TD' (或 LR/BT) 开头。
3. 节点定义必须使用 ID["文字内容"] 格式（严格使用双引号包裹文字）。
4. 文字内容中严禁包含任何引号、方括号、圆括号或冒号。
5. 重点展示知识点之间的因果、组成或流程关系。
6. 禁止使用 Markdown 代码块包裹（即禁止使用 ``` 符号）。"""

data['strings']['prompt.default.mindmap'] = {
    'extractionState': 'manual',
    'localizations': {
        'zh-Hans': { 'stringUnit': { 'state': 'translated', 'value': mindmap_prompt } },
        'en': { 'stringUnit': { 'state': 'translated', 'value': "Generate a Mermaid mindmap..." } }
    }
}
data['strings']['prompt.default.infographic'] = {
    'extractionState': 'manual',
    'localizations': {
        'zh-Hans': { 'stringUnit': { 'state': 'translated', 'value': infographic_prompt } },
        'en': { 'stringUnit': { 'state': 'translated', 'value': "Generate a Mermaid flowchart..." } }
    }
}

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Successfully updated Localizable.xcstrings")
