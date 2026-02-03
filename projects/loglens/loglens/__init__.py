from setuptools import setup, find_packages

setup(
    name='loglens',
    version='0.1.0',
    packages=find_packages(),
    install_requires=[
        'Click',
        'rich',
        'pytest',
    ],
    entry_points={
        'console_scripts': [
            'loglens = loglens.__main__:main',
        ],
    },
)