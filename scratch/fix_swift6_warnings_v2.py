import os
import re

def fix_existential_types(directory):
    protocols = [
        "LLMServiceProtocol",
        "LogServiceProtocol",
        "AnalyticsServiceProtocol",
        "IngestServiceProtocol",
        "StorageServiceProtocol"
    ]
    
    for protocol in protocols:
        # Match the protocol when used as a type, but NOT in inheritance/definition
        # This is a simplified approach: avoid matches on the same line as class/struct/enum/extension/protocol definitions
        pattern = re.compile(r'(?<!any\s)(?<!protocol\s)(?<!\.)\b' + protocol + r'\b(?!\.self)(?!\.Type)')
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file.endswith(".swift"):
                    path = os.path.join(root, file)
                    with open(path, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                    
                    new_lines = []
                    changed = False
                    for line in lines:
                        # Skip definition lines
                        if any(x in line for x in ["class ", "struct ", "enum ", "extension ", "protocol "]) and ":" in line:
                            new_lines.append(line)
                            continue
                            
                        new_line = pattern.sub(f"any {protocol}", line)
                        if new_line != line:
                            changed = True
                        new_lines.append(new_line)
                    
                    if changed:
                        with open(path, 'w', encoding='utf-8') as f:
                            f.writelines(new_lines)
                        print(f"Updated {path} for {protocol}")

if __name__ == "__main__":
    # First revert common mistakes
    # Actually, it's safer to just run a cleanup to remove 'any' where it shouldn't be
    fix_existential_types("Sources/Shared")
    print("Swift 6 existential types cleanup complete.")
