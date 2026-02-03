from setuptools import setup, find_packages

setup(
    name='loglens',
    version='0.1',
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        'Click',   # For creating CLI apps
        
        # Add other dependencies here
    ],
    entry_points='''
        [console_scripts]
        loglens=loglens.cli:main
    ''',
)