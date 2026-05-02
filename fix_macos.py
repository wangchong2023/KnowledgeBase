import os
import re

target_dir = "/Users/constantine/Documents/work/code/projects/km/Sources"

pattern_nav = re.compile(r'^(\s*)\.navigationBarTitleDisplayMode\((.*?)\)', re.MULTILINE)
pattern_list = re.compile(r'^(\s*)\.listStyle\(\.insetGrouped\)', re.MULTILINE)
pattern_nav_bar = re.compile(r'^(\s*)\.navigationBar\(.*?\)', re.MULTILINE)

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content

    def repl_nav(match):
        spaces = match.group(1)
        args = match.group(2)
        return f"#if os(iOS)\n{spaces}.navigationBarTitleDisplayMode({args})\n#endif"

    def repl_list(match):
        spaces = match.group(1)
        return f"#if os(iOS)\n{spaces}.listStyle(.insetGrouped)\n#endif"
        
    def repl_nav_bar(match):
        return f"#if os(iOS)\n{match.group(0)}\n#endif"

    # Avoid double wrapping by checking if #if os(iOS) is already right before
    # We'll just do a simple replacement and if it creates duplicates we'll fix it manually.
    # Actually, to be safe: we can check if it's already wrapped.
    # A safer way is to just apply it if not already present in the file? No, it might be present elsewhere.
    # Let's just run it, since I know which files I manually wrapped.
    # Wait, I manually wrapped TaskCenterView, SettingsView, SettingsAboutView.
    # I should ignore those.
    ignore_files = ["TaskCenterView.swift", "SettingsView.swift", "SettingsAboutView.swift", "VoiceNoteComponents.swift", "VoiceNoteView.swift"]
    if any(ignore in filepath for ignore in ignore_files):
        return

    content = pattern_nav.sub(repl_nav, content)
    content = pattern_list.sub(repl_list, content)
    content = pattern_nav_bar.sub(repl_nav_bar, content)
    
    if "PencilManager.swift" in filepath:
        if "#if os(iOS)" not in content:
             content = "#if os(iOS)\n" + content + "\n#endif\n"
             
    if "PerformanceService.swift" in filepath:
        pass # performance service has a UI view?! Wait, PerformanceService has a View? I'll check it later.

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed {filepath}")

for root, _, files in os.walk(target_dir):
    for file in files:
        if file.endswith(".swift"):
            process_file(os.path.join(root, file))
