import os
import re

target_dir = "/Users/constantine/Documents/work/code/projects/km/Sources/Shared"

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    content = content.replace("placement: .topBarTrailing", "placement: .automatic")
    content = content.replace("placement: .topBarLeading", "placement: .automatic")

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed {filepath}")

for root, _, files in os.walk(target_dir):
    for file in files:
        if file.endswith(".swift"):
            process_file(os.path.join(root, file))
