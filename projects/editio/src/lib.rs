pub trait Plugin {
    fn name(&self) -> &str;
    fn version(&self) -> &str;
}

pub struct EditioPlugin {}

impl Plugin for EditioPlugin {
    fn name(&self) -> &str {
        "editio-plugin"
    }

    fn version(&self) -> &str {
        "0.1.0"
    }
}
