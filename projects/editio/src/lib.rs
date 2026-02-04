pub mod bibliography;

// ... other code ...

pub struct Figure {
    // TODO: Implement figure structure here
}

pub struct Table {
    // TODO: Implement table structure here
}

impl Editio  {
    pub fn new() -> Self {
        // ... other initialization ...
        
        let bib = bibliography::Bibliography::new();

        Self {
            // ... other fields ...
            figures: Vec::new(),
            tables: Vec::new(),
            bibliography: bib,
        }
    }

    // ... other methods ...
}
