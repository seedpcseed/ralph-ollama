from pathlib import Path
import logging

logger = logging.getLogger(__name__)

def verify_file(path, content):
    try:
        file_path = Path(path)
        with open(file_path, 'r') as f:
            logger.info(f'Verifying file at {path}...')
            if f.read() == content:
                logger.debug('File verified successfully.')
            else:
                logger.error('File verification failed. Content does not match.')
    except Exception as e:
        logger.error(f"An error occurred while verifying the file: {e}")