output=$(python -m loglens)
if [[ $output == *"parse"* && $output == *"analyze"* ]]; then
    echo "STATUS: COMPLETE"
else
    echo "STATUS: INCOMPLETE"
    echo "REASON: 'parse' or 'analyze' not found in the output of 'python -m loglens'"
fi