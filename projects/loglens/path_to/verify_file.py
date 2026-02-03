def verify_changes(path, content):
    try:
        with open(path, 'r') as file:
            if file.read() == content:
                return True
            else:
                print('File verification failed. Content does not match.')
                return False
    except Exception as e:
        print('Failed to verify the file:', e)