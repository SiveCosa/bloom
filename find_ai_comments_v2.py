import os
import emoji

lib_dir = 'lib'
issues = []
for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f).replace('\\', '/')
            try:
                with open(path, 'r', encoding='utf-8') as file:
                    content = file.read()
                    lines = content.split('\n')
                    for i, line in enumerate(lines):
                        if emoji.emoji_count(line) > 0:
                            issues.append(f"{path}:{i+1} Emoji found")
                        lower_line = line.lower().strip()
                        if lower_line.startswith('//') and ('as an ai' in lower_line or 'here is the' in lower_line or 'i can help' in lower_line or 'certainly' in lower_line or 'sure' in lower_line or 'chatgpt' in lower_line):
                            issues.append(f"{path}:{i+1} AI Comment found: {line.strip()}")
            except Exception as e:
                pass

for issue in issues:
    print(issue)
