import os
import re

lib_dir = 'lib'

def is_dumb_comment(line):
    line = line.strip()
    if not line.startswith('//'):
        return False
    
    # Extract the comment text
    text = line[2:].strip()
    
    # Ignore comments with punctuation
    if any(c in text for c in ['.', ',', '!', '?', ';']):
        return False
    
    # Ignore long comments (more than 7 words)
    words = text.split()
    if len(words) > 7:
        return False
        
    # Check for structural keywords
    lower_text = text.lower()
    keywords = ['padding', 'spacing', 'button', 'row', 'column', 'container', 
                'header', 'footer', 'body', 'layer', 'avatar', 'text', 'icon', 
                'stat', 'name', 'link', 'section', 'background', 'foreground',
                'username', 'password', 'grid', 'card']
                
    # Also catch some exact matches
    exact_matches = ['filters', 'location', 'date & time row', 'app bar title & actions', 'month']
    
    if lower_text in exact_matches:
        return True
        
    for kw in keywords:
        if kw in lower_text:
            return True
            
    return False

modified_files = 0
for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            try:
                with open(path, 'r', encoding='utf-8') as file:
                    lines = file.readlines()
                    
                new_lines = []
                changed = False
                for line in lines:
                    if is_dumb_comment(line):
                        changed = True
                    else:
                        new_lines.append(line)
                        
                if changed:
                    with open(path, 'w', encoding='utf-8') as file:
                        file.writelines(new_lines)
                    modified_files += 1
            except Exception as e:
                pass

print(f"Cleaned dumb comments from {modified_files} files.")
