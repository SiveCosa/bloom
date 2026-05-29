import os
import re

lib_dir = 'lib'
dart_files = set()
for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            dart_files.add(os.path.join(root, f).replace('\\', '/'))

imported_files = set()
import_pattern = re.compile(r'import\s+[\'\"]([^\'\"]+)\.dart[\'\"]')

for f in dart_files:
    try:
        with open(f, 'r', encoding='utf-8') as file:
            content = file.read()
            imports = import_pattern.findall(content)
            for imp in imports:
                basename = imp.split('/')[-1] + '.dart'
                imported_files.add(basename)
    except:
        pass

unused = []
for f in dart_files:
    basename = os.path.basename(f)
    if basename != 'main.dart' and basename not in imported_files and basename != 'firebase_options.dart':
        unused.append(f)

print('Unused candidates:', unused)
