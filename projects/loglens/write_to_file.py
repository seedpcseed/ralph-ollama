from pathlib import Path
import logging

logger = logging.getLogger(__name__)

def write_code_block(path, content):
    try:
        file_path = Path(path)
        with open(file_path, 'w') as f:
            logger.info(f'Writing code block to {path}...')
            f.write(content)
            logger.debug('Code block written successfully.')
    except Exception as e:
        logger.error(f"An error occurred while writing the file: {e}")