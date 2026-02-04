pub enum Node       {
    // ... existing variants ...
    Image(String, Vec<(String, String)>),   // Add this line to handle image events with YAML attributes support
}
