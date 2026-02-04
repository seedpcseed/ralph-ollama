pub mod bibliography;

// ... other code ...

impl Editio {
    pub fn new() -> Self {
        // ... other initialization ...
        
        let bib = bibliography::Bibliography::new();

        Self {
            // ... other fields ...
            bibliography: bib,
        }
    }

    // ... other methods ...
}
