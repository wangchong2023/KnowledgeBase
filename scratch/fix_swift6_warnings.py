import os
import re

def fix_existential_types(directory):
    # List of protocols that should be prefixed with 'any' when used as types
    protocols = [
        "LLMServiceProtocol",
        "LogServiceProtocol",
        "AnalyticsServiceProtocol",
        "IngestServiceProtocol",
        "StorageServiceProtocol"
    ]
    
    # regex to match protocol usage as a type (e.g., : Protocol, -> Protocol, var p: Protocol)
    # Avoiding 'protocol Name', 'any Name', 'Name.self', 'Name.Type', etc.
    
    for protocol in protocols:
        pattern = re.compile(r'(?<!any\s)(?<!protocol\s)(?<!\.)\b' + protocol + r'\b(?!\.self)(?!\.Type)')
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file.endswith(".swift"):
                    path = os.path.join(root, file)
                    with open(path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    new_content = pattern.sub(f"any {protocol}", content)
                    
                    if new_content != content:
                        with open(path, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        print(f"Updated {path} for {protocol}")

if __name__ == "__main__":
    fix_existential_types("Sources/Shared")
    print("Swift 6 existential types cleanup complete.")
