from pathlib import Path

def create_file(path):
    try:
        file = Path(path)
        file.touch()
    except Exception as e:
        print('Failed to create file:', e)