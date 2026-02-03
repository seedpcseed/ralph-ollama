for file in cli.py parsers/base.py parsers/apache.py parsers/json.py parsers/syslog.py analyzers/patterns.py analyzers/errors.py analyzers/anomalies.py reporters/console.py reporters/html.py tests/fixtures/*; do
    if [ ! -e $file ]; then
        echo "INCOMPLETE"
        echo "Missing file: $file"
        exit 1
    fi
done
echo "COMPLETE"