def replace_string(input_str):
    if not isinstance(input_str, str):
        raise ValueError('Input should be a string')
    
    return input_str.replace("e", "o").replace("E", "O")  # Replace both lowercase and uppercase 'e' with 'o'