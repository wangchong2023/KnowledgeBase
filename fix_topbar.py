import os

files = [
    "/Users/constantine/Documents/work/code/projects/km/Sources/Shared/Views/Features/ChatView.swift",
    "/Users/constantine/Documents/work/code/projects/km/Sources/Shared/Views/Editors/IconPickerView.swift"
]

for f in files:
    if os.path.exists(f):
        with open(f, 'r') as file:
            content = file.read()
        content = content.replace("placement: .topBarTrailing", "placement: .automatic")
        with open(f, 'w') as file:
            file.write(content)
        print(f"Fixed {f}")
