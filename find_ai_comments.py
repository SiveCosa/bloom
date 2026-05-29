import os
import re

lib_dir = 'lib'
emoji_pattern = re.compile(r'[\U00010000-\U0010ffff]|[\u2600-\u27BF]', flags=re.UNICODE)
ai_pattern = re.compile(r'(as an ai|chatgpt|openai|here is the|i can help with that|certainly!|sure!)', re.IGNORECASE)

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
                        if emoji_pattern.search(line):
                            issues.append(f"{path}:{i+1} Emoji found")
                        if ai_pattern.search(line) and line.strip().startswith('//'):
                            issues.append(f"{path}:{i+1} AI Comment found: {line.strip()}")
            except Exception as e:
                pass

for issue in issues:
    print(issue)
