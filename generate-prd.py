#!/usr/bin/env python3
"""Generate complete prd.json with all granular stories for Editio project."""
import json
from datetime import datetime

now = datetime.utcnow().isoformat() + 'Z'

stories = []

def create_story(id_str, category, story, steps, acceptance, priority, depends_on=[], verify_cmd=None):
    """Create a story object in v2.0 format."""
    if verify_cmd is None:
        verify_cmd = 'cargo build --lib'
    return {
        'id': id_str,
        'category': category,
        'story': story,
        'steps': steps,
        'acceptance': acceptance,
        'priority': priority,
        'status': 'pending',
        'progress': 0,
        'lastAttempt': None,
        'attemptCount': 0,
        'dependsOn': depends_on,
        'blocks': [],
        'verify': {
            'command': verify_cmd,
            'lastRun': None,
            'lastResult': 'not_run',
            'expectedResult': 'pass'
        },
        'files': [],
        'tests': [],
        'errors': [],
        'notes': '',
        'createdAt': now,
        'updatedAt': now
    }

# 1. PROJECT SETUP (Priority 1-10)
stories.append(create_story('1.1', 'technical', 'Initialize Rust workspace with Cargo.toml',
    ['Create Cargo.toml workspace file', 'Define workspace members'],
    'Workspace Cargo.toml exists with all crate members defined.',
    1, [], 'test -f Cargo.toml && grep -q "\\[workspace\\]" Cargo.toml'))

stories.append(create_story('1.2', 'technical', 'Create editio crate structure (main CLI binary)',
    ['Create crates/editio/Cargo.toml', 'Create crates/editio/src/main.rs with basic main()'],
    'editio crate exists and compiles.',
    2, ['1.1'], 'test -f crates/editio/Cargo.toml && cargo build --bin editio'))

stories.append(create_story('1.3', 'technical', 'Create editio-core crate structure',
    ['Create crates/editio-core/Cargo.toml', 'Create crates/editio-core/src/lib.rs'],
    'editio-core crate exists and compiles.',
    3, ['1.1'], 'test -f crates/editio-core/Cargo.toml && cargo build --lib -p editio-core'))

stories.append(create_story('1.4', 'technical', 'Create editio-ast crate structure',
    ['Create crates/editio-ast/Cargo.toml', 'Create crates/editio-ast/src/lib.rs'],
    'editio-ast crate exists and compiles.',
    4, ['1.1'], 'test -f crates/editio-ast/Cargo.toml && cargo build --lib -p editio-ast'))

stories.append(create_story('1.5', 'technical', 'Create editio-parser crate structure',
    ['Create crates/editio-parser/Cargo.toml', 'Create crates/editio-parser/src/lib.rs'],
    'editio-parser crate exists and compiles.',
    5, ['1.1'], 'test -f crates/editio-parser/Cargo.toml && cargo build --lib -p editio-parser'))

stories.append(create_story('1.6', 'technical', 'Create editio-layout crate structure',
    ['Create crates/editio-layout/Cargo.toml', 'Create crates/editio-layout/src/lib.rs'],
    'editio-layout crate exists and compiles.',
    6, ['1.1'], 'test -f crates/editio-layout/Cargo.toml && cargo build --lib -p editio-layout'))

stories.append(create_story('1.7', 'technical', 'Create editio-render crate structure',
    ['Create crates/editio-render/Cargo.toml', 'Create crates/editio-render/src/lib.rs'],
    'editio-render crate exists and compiles.',
    7, ['1.1'], 'test -f crates/editio-render/Cargo.toml && cargo build --lib -p editio-render'))

stories.append(create_story('1.8', 'technical', 'Create editio-pdf crate structure',
    ['Create crates/editio-pdf/Cargo.toml', 'Create crates/editio-pdf/src/lib.rs'],
    'editio-pdf crate exists and compiles.',
    8, ['1.1'], 'test -f crates/editio-pdf/Cargo.toml && cargo build --lib -p editio-pdf'))

stories.append(create_story('1.9', 'technical', 'Create editio-bib crate structure',
    ['Create crates/editio-bib/Cargo.toml', 'Create crates/editio-bib/src/lib.rs'],
    'editio-bib crate exists and compiles.',
    9, ['1.1'], 'test -f crates/editio-bib/Cargo.toml && cargo build --lib -p editio-bib'))

stories.append(create_story('1.10', 'technical', 'Create editio-math crate structure',
    ['Create crates/editio-math/Cargo.toml', 'Create crates/editio-math/src/lib.rs'],
    'editio-math crate exists and compiles.',
    10, ['1.1'], 'test -f crates/editio-math/Cargo.toml && cargo build --lib -p editio-math'))

# 2. MARKDOWN PARSING (Priority 11-28)
stories.append(create_story('2.1', 'technical', 'Add pulldown-cmark dependency to editio-parser Cargo.toml',
    ['Open crates/editio-parser/Cargo.toml', 'Add pulldown-cmark = "0.9" to [dependencies]'],
    'Cargo.toml includes pulldown-cmark dependency.',
    11, ['1.5'], 'grep -q pulldown-cmark crates/editio-parser/Cargo.toml'))

stories.append(create_story('2.2', 'technical', 'Create AST Node enum with Document variant',
    ['Create crates/editio-ast/src/lib.rs', 'Define pub enum Node with Document(Vec<Node>) variant'],
    'AST Node enum exists with Document variant.',
    12, ['1.4'], 'grep -q "Document(Vec<Node>)" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('2.3', 'technical', 'Add Paragraph variant to AST Node enum',
    ['Add Paragraph(Vec<Inline>) variant to Node enum'],
    'Node enum includes Paragraph variant.',
    13, ['2.2'], 'grep -q "Paragraph" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('2.4', 'technical', 'Add Heading variant to AST Node enum',
    ['Add Heading { level: u8, content: Vec<Inline> } variant to Node enum'],
    'Node enum includes Heading variant.',
    14, ['2.2'], 'grep -q "Heading" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('2.5', 'technical', 'Add CodeBlock variant to AST Node enum',
    ['Add CodeBlock { language: Option<String>, content: String } variant'],
    'Node enum includes CodeBlock variant.',
    15, ['2.2'], 'grep -q "CodeBlock" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('2.6', 'technical', 'Add Table variant to AST Node enum',
    ['Add Table { headers: Vec<Vec<Inline>>, rows: Vec<Vec<Vec<Inline>>> } variant'],
    'Node enum includes Table variant.',
    16, ['2.2'], 'grep -q "Table" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('2.7', 'technical', 'Add Image variant with Attributes support to AST Node enum',
    ['Add Image { src: String, caption: Option<String>, attrs: Attributes } variant'],
    'Node enum includes Image variant with Attributes.',
    17, ['2.2'], 'grep -q "Image" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('2.8', 'technical', 'Create Inline enum for inline content',
    ['Create pub enum Inline with Text(String), Strong(Vec<Inline>), Emphasis(Vec<Inline>) variants'],
    'Inline enum exists with basic variants.',
    18, ['2.2'], 'grep -q "enum Inline" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('2.9', 'technical', 'Create Attributes struct for YAML-style attributes',
    ['Create pub struct Attributes with float, width, height, label, caption fields'],
    'Attributes struct exists with all required fields.',
    19, ['2.7'], 'grep -q "struct Attributes" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('2.10', 'technical', 'Implement parse_headings() function for # syntax',
    ['Create parse_headings() in editio-parser', 'Use pulldown-cmark to parse headings', 'Convert to AST Heading nodes'],
    'parse_headings() converts markdown headings to AST.',
    20, ['2.1', '2.4'], 'cargo test --lib -p editio-parser test_parse_headings'))

stories.append(create_story('2.11', 'technical', 'Implement parse_paragraphs() function for text blocks',
    ['Create parse_paragraphs() in editio-parser', 'Parse paragraph text and inline formatting'],
    'parse_paragraphs() converts markdown paragraphs to AST.',
    21, ['2.1', '2.3', '2.8'], 'cargo test --lib -p editio-parser test_parse_paragraphs'))

stories.append(create_story('2.12', 'technical', 'Implement parse_code_blocks() for ``` blocks',
    ['Create parse_code_blocks() in editio-parser', 'Extract language and content'],
    'parse_code_blocks() converts markdown code blocks to AST.',
    22, ['2.1', '2.5'], 'cargo test --lib -p editio-parser test_parse_code_blocks'))

stories.append(create_story('2.13', 'technical', 'Implement parse_tables() for markdown tables',
    ['Create parse_tables() in editio-parser', 'Parse table headers and rows'],
    'parse_tables() converts markdown tables to AST.',
    23, ['2.1', '2.6'], 'cargo test --lib -p editio-parser test_parse_tables'))

stories.append(create_story('2.14', 'technical', 'Implement parse_images() with YAML attribute parsing',
    ['Create parse_images() in editio-parser', 'Parse image syntax with {float=right width=50%} attributes'],
    'parse_images() converts markdown images with attributes to AST.',
    24, ['2.1', '2.7', '2.9'], 'cargo test --lib -p editio-parser test_parse_images_with_attrs'))

stories.append(create_story('2.15', 'technical', 'Implement parse_links() for [text](url) syntax',
    ['Create parse_links() in editio-parser', 'Parse inline links'],
    'parse_links() converts markdown links to AST.',
    25, ['2.1', '2.8'], 'cargo test --lib -p editio-parser test_parse_links'))

stories.append(create_story('2.16', 'technical', 'Implement parse_lists() for ordered and unordered lists',
    ['Create parse_lists() in editio-parser', 'Handle both ordered and unordered lists'],
    'parse_lists() converts markdown lists to AST.',
    26, ['2.1', '2.2'], 'cargo test --lib -p editio-parser test_parse_lists'))

stories.append(create_story('2.17', 'technical', 'Add CommonMark compliance tests',
    ['Create tests/commonmark.rs', 'Add tests for all CommonMark features'],
    'CommonMark compliance tests exist and pass.',
    27, ['2.10', '2.11', '2.12', '2.13', '2.15', '2.16'], 'cargo test --lib -p editio-parser commonmark_compliance'))

stories.append(create_story('2.18', 'technical', 'Add GFM extension tests (strikethrough, tables, task lists)',
    ['Create tests/gfm.rs', 'Add tests for GFM-specific features'],
    'GFM extension tests exist and pass.',
    28, ['2.13', '2.16'], 'cargo test --lib -p editio-parser gfm_extensions'))

# 3. TWO-PASS LAYOUT ENGINE (Priority 29-48)
stories.append(create_story('3.1', 'technical', 'Create Layout struct for layout metadata',
    ['Create Layout struct in editio-layout', 'Add page_size, margins, font_size fields'],
    'Layout struct exists with basic fields.',
    29, ['1.6'], 'grep -q "struct Layout" crates/editio-layout/src/lib.rs && cargo build --lib -p editio-layout'))

stories.append(create_story('3.2', 'technical', 'Create WrapZone struct for text wrapping',
    ['Create WrapZone struct', 'Add position, width, height fields'],
    'WrapZone struct exists.',
    30, ['3.1'], 'grep -q "struct WrapZone" crates/editio-layout/src/lib.rs && cargo build --lib -p editio-layout'))

stories.append(create_story('3.3', 'technical', 'Create Float struct for floating elements',
    ['Create Float struct', 'Add position, size, element_type fields'],
    'Float struct exists.',
    31, ['3.1'], 'grep -q "struct Float" crates/editio-layout/src/lib.rs && cargo build --lib -p editio-layout'))

stories.append(create_story('3.4', 'technical', 'Create FloatPosition enum (left, right, none)',
    ['Create FloatPosition enum', 'Add Left, Right, None variants'],
    'FloatPosition enum exists.',
    32, ['3.3'], 'grep -q "enum FloatPosition" crates/editio-layout/src/lib.rs && cargo build --lib -p editio-layout'))

stories.append(create_story('3.5', 'technical', 'Implement collect_floats() to extract floating figures from AST',
    ['Create collect_floats() function', 'Traverse AST and collect Image nodes with float attributes'],
    'collect_floats() extracts all floating figures.',
    33, ['3.3', '2.7'], 'cargo test --lib -p editio-layout test_collect_floats'))

stories.append(create_story('3.6', 'technical', 'Implement calculate_text_flow() to identify paragraphs and lists',
    ['Create calculate_text_flow() function', 'Identify paragraph boundaries and list boundaries'],
    'calculate_text_flow() identifies text flow elements.',
    34, ['3.1', '2.3', '2.16'], 'cargo test --lib -p editio-layout test_calculate_text_flow'))

stories.append(create_story('3.7', 'technical', 'Implement CSS-style float algorithm for single float',
    ['Create float_algorithm() function', 'Calculate wrap zones for left/right floats'],
    'Float algorithm calculates wrap zones correctly.',
    35, ['3.2', '3.4', '3.5'], 'cargo test --lib -p editio-layout test_float_algorithm'))

stories.append(create_story('3.8', 'technical', 'Implement wrap zone calculation for left float',
    ['Extend float_algorithm()', 'Handle left float positioning and wrap zone'],
    'Left floats create correct wrap zones.',
    36, ['3.7'], 'cargo test --lib -p editio-layout test_left_float_wrap'))

stories.append(create_story('3.9', 'technical', 'Implement wrap zone calculation for right float',
    ['Extend float_algorithm()', 'Handle right float positioning and wrap zone'],
    'Right floats create correct wrap zones.',
    37, ['3.7'], 'cargo test --lib -p editio-layout test_right_float_wrap'))

stories.append(create_story('3.10', 'technical', 'Implement text wrapping around single float',
    ['Create wrap_text_around_float() function', 'Calculate text positions avoiding wrap zone'],
    'Text wraps around single float correctly.',
    38, ['3.8', '3.9'], 'cargo test --lib -p editio-layout test_text_wrap_single'))

stories.append(create_story('3.11', 'technical', 'Implement list wrapping around float (key differentiator)',
    ['Extend wrap_text_around_float()', 'Handle list items wrapping around float'],
    'Lists wrap around floats correctly (key feature).',
    39, ['3.10', '2.16'], 'cargo test --lib -p editio-layout test_list_wrap_around_float'))

stories.append(create_story('3.12', 'technical', 'Implement multiple float handling (left and right)',
    ['Extend float_algorithm()', 'Handle multiple floats on same page'],
    'Multiple floats handled correctly.',
    40, ['3.8', '3.9'], 'cargo test --lib -p editio-layout test_multiple_floats'))

stories.append(create_story('3.13', 'technical', 'Implement figure placement optimization to minimize page breaks',
    ['Create optimize_float_placement() function', 'Calculate best float positions'],
    'Float placement optimized to minimize page breaks.',
    41, ['3.5', '3.7'], 'cargo test --lib -p editio-layout test_optimize_placement'))

stories.append(create_story('3.14', 'technical', 'Implement page break calculation based on content',
    ['Create calculate_page_breaks() function', 'Determine where pages break'],
    'Page breaks calculated correctly.',
    42, ['3.1', '3.6'], 'cargo test --lib -p editio-layout test_page_breaks'))

stories.append(create_story('3.15', 'technical', 'Implement first pass: measure all content',
    ['Create measure_pass() function', 'Calculate dimensions of all elements'],
    'First pass measures all content.',
    43, ['3.6'], 'cargo test --lib -p editio-layout test_measure_pass'))

stories.append(create_story('3.16', 'technical', 'Implement second pass: place all content',
    ['Create place_pass() function', 'Position all elements using measurements'],
    'Second pass places all content.',
    44, ['3.15', '3.14'], 'cargo test --lib -p editio-layout test_place_pass'))

stories.append(create_story('3.17', 'technical', 'Create LayoutMetadata struct to store layout results',
    ['Create LayoutMetadata struct', 'Store wrap zones, page breaks, float positions'],
    'LayoutMetadata struct stores layout results.',
    45, ['3.2', '3.14'], 'grep -q "struct LayoutMetadata" crates/editio-layout/src/lib.rs && cargo build --lib -p editio-layout'))

stories.append(create_story('3.18', 'technical', 'Implement calculate_layout() main function',
    ['Create calculate_layout() function', 'Orchestrate two-pass layout'],
    'calculate_layout() performs complete layout calculation.',
    46, ['3.15', '3.16', '3.17'], 'cargo test --lib -p editio-layout test_calculate_layout'))

stories.append(create_story('3.19', 'technical', 'Add integration tests for figure wrapping with lists',
    ['Create tests/figure_wrap_lists.rs', 'Add regression tests for list wrapping'],
    'Integration tests verify list wrapping works.',
    47, ['3.11'], 'cargo test --lib -p editio-layout figure_wrap_lists'))

stories.append(create_story('3.20', 'technical', 'Add performance benchmarks for layout engine',
    ['Create benches/layout_bench.rs', 'Benchmark layout calculation speed'],
    'Performance benchmarks exist.',
    48, ['3.18'], 'cargo bench --lib -p editio-layout'))

# 4. PDF OUTPUT (Priority 49-58)
stories.append(create_story('4.1', 'technical', 'Add printpdf dependency to editio-pdf Cargo.toml',
    ['Open crates/editio-pdf/Cargo.toml', 'Add printpdf = "0.7" to [dependencies]'],
    'Cargo.toml includes printpdf dependency.',
    49, ['1.8'], 'grep -q printpdf crates/editio-pdf/Cargo.toml'))

stories.append(create_story('4.2', 'technical', 'Create PDF document creation function',
    ['Create create_pdf_document() function', 'Initialize printpdf document'],
    'PDF document creation function exists.',
    50, ['4.1'], 'cargo test --lib -p editio-pdf test_create_document'))

stories.append(create_story('4.3', 'technical', 'Implement page setup with size and margins',
    ['Create setup_page() function', 'Set page size and margins from LayoutMetadata'],
    'Page setup function configures pages correctly.',
    51, ['4.2', '3.17'], 'cargo test --lib -p editio-pdf test_page_setup'))

stories.append(create_story('4.4', 'technical', 'Implement text rendering with wrap zones',
    ['Create render_text() function', 'Render text avoiding wrap zones'],
    'Text renders correctly with wrap zones.',
    52, ['4.2', '3.2'], 'cargo test --lib -p editio-pdf test_render_text'))

stories.append(create_story('4.5', 'technical', 'Implement figure placement using absolute positioning',
    ['Create render_figure() function', 'Place figures at calculated positions'],
    'Figures placed correctly using layout positions.',
    53, ['4.2', '3.17'], 'cargo test --lib -p editio-pdf test_render_figure'))

stories.append(create_story('4.6', 'technical', 'Implement text flowing around figures',
    ['Extend render_text()', 'Use wrap zones to flow text around figures'],
    'Text flows around figures correctly.',
    54, ['4.4', '4.5'], 'cargo test --lib -p editio-pdf test_text_flow_around_figures'))

stories.append(create_story('4.7', 'technical', 'Implement list rendering with text wrapping',
    ['Create render_list() function', 'Render lists that wrap around figures'],
    'Lists render correctly with wrapping.',
    55, ['4.4', '3.11'], 'cargo test --lib -p editio-pdf test_list_wrapping'))

stories.append(create_story('4.8', 'technical', 'Implement font embedding (Times New Roman)',
    ['Create embed_font() function', 'Load and embed Times New Roman font'],
    'Font embedding works correctly.',
    56, ['4.2'], 'cargo test --lib -p editio-pdf test_font_embedding'))

stories.append(create_story('4.9', 'technical', 'Implement headers and footers with page numbers',
    ['Create render_header_footer() function', 'Add headers/footers to each page'],
    'Headers and footers render correctly.',
    57, ['4.3'], 'cargo test --lib -p editio-pdf test_headers_footers'))

stories.append(create_story('4.10', 'technical', 'Implement render_pdf() main function',
    ['Create render_pdf() function', 'Orchestrate PDF rendering from AST and layout'],
    'render_pdf() generates complete PDF.',
    58, ['4.4', '4.5', '4.7', '4.9'], 'cargo test --lib -p editio-pdf test_render_pdf'))

# 5. CROSS-REFERENCES (Priority 59-66)
stories.append(create_story('5.1', 'technical', 'Create Reference struct for cross-references',
    ['Create Reference struct', 'Add label, target_type, text fields'],
    'Reference struct exists.',
    59, ['1.4'], 'grep -q "struct Reference" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('5.2', 'technical', 'Add CrossReference variant to AST Node enum',
    ['Add CrossReference { label: String, text: Option<String> } variant'],
    'Node enum includes CrossReference variant.',
    60, ['5.1', '2.2'], 'grep -q "CrossReference" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('5.3', 'technical', 'Implement label tracking system',
    ['Create LabelRegistry struct', 'Track all labels in document'],
    'Label tracking system exists.',
    61, ['5.1'], 'cargo test --lib -p editio-core test_label_tracking'))

stories.append(create_story('5.4', 'technical', 'Implement parse_cross_references() for [@label] syntax',
    ['Create parse_cross_references() function', 'Parse [@label] and [See @label] syntax'],
    'Cross-reference parsing works.',
    62, ['5.2', '2.1'], 'cargo test --lib -p editio-parser test_parse_cross_references'))

stories.append(create_story('5.5', 'technical', 'Implement reference resolution (compile-time)',
    ['Create resolve_references() function', 'Resolve all cross-references to targets'],
    'Reference resolution works.',
    63, ['5.3', '5.4'], 'cargo test --lib -p editio-core test_resolve_references'))

stories.append(create_story('5.6', 'technical', 'Implement automatic numbering for figures',
    ['Create number_figures() function', 'Assign sequential numbers to figures'],
    'Figure numbering works.',
    64, ['5.3'], 'cargo test --lib -p editio-core test_figure_numbering'))

stories.append(create_story('5.7', 'technical', 'Implement automatic numbering for tables',
    ['Create number_tables() function', 'Assign sequential numbers to tables'],
    'Table numbering works.',
    65, ['5.3'], 'cargo test --lib -p editio-core test_table_numbering'))

stories.append(create_story('5.8', 'technical', 'Implement automatic numbering for equations',
    ['Create number_equations() function', 'Assign sequential numbers to equations'],
    'Equation numbering works.',
    66, ['5.3'], 'cargo test --lib -p editio-core test_equation_numbering'))

# 6. ACADEMIC EXTENSIONS (Priority 67-74)
stories.append(create_story('6.1', 'technical', 'Add Theorem variant to AST Node enum',
    ['Add Theorem { label: Option<String>, content: Vec<Node> } variant'],
    'Node enum includes Theorem variant.',
    67, ['2.2'], 'grep -q "Theorem" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('6.2', 'technical', 'Add Proof variant to AST Node enum',
    ['Add Proof { content: Vec<Node> } variant'],
    'Node enum includes Proof variant.',
    68, ['2.2'], 'grep -q "Proof" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('6.3', 'technical', 'Add Algorithm variant to AST Node enum',
    ['Add Algorithm { label: Option<String>, caption: Option<String>, content: Vec<Node> } variant'],
    'Node enum includes Algorithm variant.',
    69, ['2.2'], 'grep -q "Algorithm" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('6.4', 'technical', 'Add Pseudocode variant to AST Node enum',
    ['Add Pseudocode { label: Option<String>, caption: Option<String>, content: Vec<Node> } variant'],
    'Node enum includes Pseudocode variant.',
    70, ['2.2'], 'grep -q "Pseudocode" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('6.5', 'technical', 'Extend CodeBlock variant with label and caption fields',
    ['Modify CodeBlock variant', 'Add label: Option<String>, caption: Option<String> fields'],
    'CodeBlock includes label and caption.',
    71, ['2.5'], 'grep -q "caption: Option<String>" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('6.6', 'technical', 'Implement parse_theorem() for ::::{theorem} syntax',
    ['Create parse_theorem() function', 'Parse block directive syntax'],
    'Theorem parsing works.',
    72, ['6.1', '2.1'], 'cargo test --lib -p editio-parser test_parse_theorem'))

stories.append(create_story('6.7', 'technical', 'Implement parse_algorithm() for ::::{algorithm} syntax',
    ['Create parse_algorithm() function', 'Parse algorithm block directive'],
    'Algorithm parsing works.',
    73, ['6.3', '2.1'], 'cargo test --lib -p editio-parser test_parse_algorithm'))

stories.append(create_story('6.8', 'technical', 'Implement auto-numbering for academic extensions',
    ['Create number_academic_extensions() function', 'Number theorems, algorithms, code blocks'],
    'Academic extensions numbered correctly.',
    74, ['6.1', '6.3', '5.3'], 'cargo test --lib -p editio-core test_academic_numbering'))

# 7. MATH TYPESETTING (Priority 75-82)
stories.append(create_story('7.1', 'technical', 'Add Math variant to AST Node enum',
    ['Add Math { content: String, display: bool, label: Option<String> } variant'],
    'Node enum includes Math variant.',
    75, ['2.2'], 'grep -q "Math" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('7.2', 'technical', 'Create math preprocessor to extract math before parsing',
    ['Create preprocess_math() function', 'Extract $...$ and $$...$$ expressions'],
    'Math preprocessing extracts expressions.',
    76, ['7.1'], 'cargo test --lib -p editio-parser test_preprocess_math'))

stories.append(create_story('7.3', 'technical', 'Implement parse_inline_math() for $...$ syntax',
    ['Create parse_inline_math() function', 'Parse inline math expressions'],
    'Inline math parsing works.',
    77, ['7.2'], 'cargo test --lib -p editio-parser test_parse_inline_math'))

stories.append(create_story('7.4', 'technical', 'Implement parse_display_math() for $$...$$ syntax',
    ['Create parse_display_math() function', 'Parse display math expressions'],
    'Display math parsing works.',
    78, ['7.2'], 'cargo test --lib -p editio-parser test_parse_display_math'))

stories.append(create_story('7.5', 'technical', 'Implement math label parsing {label=eq:1}',
    ['Extend math parsing', 'Parse math labels from attributes'],
    'Math label parsing works.',
    79, ['7.3', '7.4'], 'cargo test --lib -p editio-parser test_math_labels'))

stories.append(create_story('7.6', 'technical', 'Create pdflatex subprocess wrapper for math rendering',
    ['Create render_math_pdflatex() function', 'Shell out to pdflatex for math'],
    'pdflatex wrapper exists.',
    80, ['1.10'], 'cargo test --lib -p editio-math test_pdflatex_wrapper'))

stories.append(create_story('7.7', 'technical', 'Implement math PDF fragment extraction',
    ['Create extract_math_pdf() function', 'Extract PDF fragments from pdflatex output'],
    'Math PDF extraction works.',
    81, ['7.6'], 'cargo test --lib -p editio-math test_extract_math_pdf'))

stories.append(create_story('7.8', 'technical', 'Implement math rendering integration with PDF renderer',
    ['Integrate math rendering', 'Embed math PDF fragments into main PDF'],
    'Math rendering integrated with PDF.',
    82, ['7.7', '4.10'], 'cargo test --lib -p editio-pdf test_math_rendering'))

# 8. BIBLIOGRAPHY SYSTEM (Priority 83-90)
stories.append(create_story('8.1', 'technical', 'Add Citation variant to AST Node enum',
    ['Add Citation { key: String, style: CitationStyle } variant'],
    'Node enum includes Citation variant.',
    83, ['2.2'], 'grep -q "Citation" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('8.2', 'technical', 'Create CitationStyle enum (AuthorYear, Numeric)',
    ['Create CitationStyle enum', 'Add AuthorYear and Numeric variants'],
    'CitationStyle enum exists.',
    84, ['8.1'], 'grep -q "enum CitationStyle" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('8.3', 'technical', 'Create BibEntry struct for bibliography entries',
    ['Create BibEntry struct', 'Add key, entry_type, fields fields'],
    'BibEntry struct exists.',
    85, ['1.9'], 'grep -q "struct BibEntry" crates/editio-bib/src/lib.rs && cargo build --lib -p editio-bib'))

stories.append(create_story('8.4', 'technical', 'Implement BibTeX parser',
    ['Create parse_bibtex() function', 'Parse .bib file format'],
    'BibTeX parser works.',
    86, ['8.3'], 'cargo test --lib -p editio-bib test_parse_bibtex'))

stories.append(create_story('8.5', 'technical', 'Implement parse_citations() for [@author2024] syntax',
    ['Create parse_citations() function', 'Parse citation syntax in markdown'],
    'Citation parsing works.',
    87, ['8.1', '2.1'], 'cargo test --lib -p editio-parser test_parse_citations'))

stories.append(create_story('8.6', 'technical', 'Implement citation resolution',
    ['Create resolve_citations() function', 'Resolve citations from bibliography'],
    'Citation resolution works.',
    88, ['8.4', '8.5'], 'cargo test --lib -p editio-core test_resolve_citations'))

stories.append(create_story('8.7', 'technical', 'Implement author-year citation formatting',
    ['Create format_author_year() function', 'Format citations as (Author, Year)'],
    'Author-year formatting works.',
    89, ['8.6'], 'cargo test --lib -p editio-core test_author_year_format'))

stories.append(create_story('8.8', 'technical', 'Implement numeric citation formatting',
    ['Create format_numeric() function', 'Format citations as [1], [2], etc.'],
    'Numeric formatting works.',
    90, ['8.6'], 'cargo test --lib -p editio-core test_numeric_format'))

# 9. FIGURE SUPPORT (Priority 91-98)
stories.append(create_story('9.1', 'technical', 'Implement figure numbering collection',
    ['Create collect_figure_numbers() function', 'Collect all figures with labels'],
    'Figure numbering collection works.',
    91, ['5.6', '2.7'], 'cargo test --lib -p editio-core test_collect_figure_numbers'))

stories.append(create_story('9.2', 'technical', 'Implement figure caption extraction',
    ['Create extract_figure_captions() function', 'Extract captions from Image nodes'],
    'Figure caption extraction works.',
    92, ['2.7'], 'cargo test --lib -p editio-core test_extract_figure_captions'))

stories.append(create_story('9.3', 'technical', 'Implement figure cross-referencing',
    ['Create resolve_figure_references() function', 'Resolve [@fig:label] references'],
    'Figure cross-referencing works.',
    93, ['5.5', '9.1'], 'cargo test --lib -p editio-core test_figure_references'))

stories.append(create_story('9.4', 'technical', 'Implement figure rendering in PDF',
    ['Create render_figure_with_caption() function', 'Render figure with caption and number'],
    'Figure rendering works.',
    94, ['4.5', '9.2'], 'cargo test --lib -p editio-pdf test_render_figure_with_caption'))

stories.append(create_story('9.5', 'technical', 'Implement figure text wrapping integration',
    ['Integrate figure rendering', 'Ensure figures participate in text wrapping'],
    'Figures integrated with text wrapping.',
    95, ['9.4', '3.10'], 'cargo test --lib -p editio-pdf test_figure_wrapping'))

stories.append(create_story('9.6', 'technical', 'Add image loading structure (placeholder for MVP)',
    ['Create load_image() function', 'Return placeholder for MVP'],
    'Image loading structure exists.',
    96, ['9.4'], 'cargo test --lib -p editio-pdf test_load_image'))

stories.append(create_story('9.7', 'technical', 'Implement figure numbering display',
    ['Create format_figure_number() function', 'Format as "Figure N" or "Figure N: Caption"'],
    'Figure numbering display works.',
    97, ['9.1', '9.2'], 'cargo test --lib -p editio-core test_figure_number_display'))

stories.append(create_story('9.8', 'technical', 'Add comprehensive figure tests',
    ['Create tests/figures.rs', 'Add tests for all figure features'],
    'Comprehensive figure tests exist.',
    98, ['9.3', '9.4', '9.7'], 'cargo test --lib -p editio-core test_figures'))

# 10. TABLE SUPPORT (Priority 99-106)
stories.append(create_story('10.1', 'technical', 'Implement table numbering collection',
    ['Create collect_table_numbers() function', 'Collect all tables with labels'],
    'Table numbering collection works.',
    99, ['5.7', '2.6'], 'cargo test --lib -p editio-core test_collect_table_numbers'))

stories.append(create_story('10.2', 'technical', 'Implement table caption extraction',
    ['Create extract_table_captions() function', 'Extract captions from Table nodes'],
    'Table caption extraction works.',
    100, ['2.6'], 'cargo test --lib -p editio-core test_extract_table_captions'))

stories.append(create_story('10.3', 'technical', 'Implement table cross-referencing',
    ['Create resolve_table_references() function', 'Resolve [@tbl:label] references'],
    'Table cross-referencing works.',
    101, ['5.5', '10.1'], 'cargo test --lib -p editio-core test_table_references'))

stories.append(create_story('10.4', 'technical', 'Implement table rendering with grid',
    ['Create render_table() function', 'Render table with borders and grid'],
    'Table rendering works.',
    102, ['4.10', '2.6'], 'cargo test --lib -p editio-pdf test_render_table'))

stories.append(create_story('10.5', 'technical', 'Implement table header row rendering',
    ['Extend render_table()', 'Render header row with different styling'],
    'Table header rendering works.',
    103, ['10.4'], 'cargo test --lib -p editio-pdf test_table_header'))

stories.append(create_story('10.6', 'technical', 'Implement column alignment support',
    ['Create ColumnAlignment enum', 'Add left, center, right, justify variants'],
    'Column alignment works.',
    104, ['10.4'], 'cargo test --lib -p editio-pdf test_column_alignment'))

stories.append(create_story('10.7', 'technical', 'Implement table numbering display',
    ['Create format_table_number() function', 'Format as "Table N" or "Table N: Caption"'],
    'Table numbering display works.',
    105, ['10.1', '10.2'], 'cargo test --lib -p editio-core test_table_number_display'))

stories.append(create_story('10.8', 'technical', 'Add comprehensive table tests',
    ['Create tests/tables.rs', 'Add tests for all table features'],
    'Comprehensive table tests exist.',
    106, ['10.3', '10.4', '10.7'], 'cargo test --lib -p editio-core test_tables'))

# 11. DOCUMENT FORMATTING (Priority 107-116)
stories.append(create_story('11.1', 'technical', 'Create DocumentMetadata struct for YAML front matter',
    ['Create DocumentMetadata struct', 'Add title, author, date, page_size, margins, font_size fields'],
    'DocumentMetadata struct exists.',
    107, ['1.4'], 'grep -q "struct DocumentMetadata" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('11.2', 'technical', 'Add serde-yaml dependency for YAML parsing',
    ['Add serde-yaml = "0.9" to editio-parser Cargo.toml'],
    'serde-yaml dependency added.',
    108, ['1.5'], 'grep -q serde-yaml crates/editio-parser/Cargo.toml'))

stories.append(create_story('11.3', 'technical', 'Implement YAML front matter parsing',
    ['Create parse_front_matter() function', 'Parse --- delimited YAML'],
    'YAML front matter parsing works.',
    109, ['11.2', '11.1'], 'cargo test --lib -p editio-parser test_parse_front_matter'))

stories.append(create_story('11.4', 'technical', 'Create PageSize enum (letter, A4, legal, custom)',
    ['Create PageSize enum', 'Add Letter, A4, Legal, Custom variants'],
    'PageSize enum exists.',
    110, ['11.1'], 'grep -q "enum PageSize" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('11.5', 'technical', 'Create Margins struct',
    ['Create Margins struct', 'Add top, bottom, left, right fields'],
    'Margins struct exists.',
    111, ['11.1'], 'grep -q "struct Margins" crates/editio-ast/src/lib.rs && cargo build --lib -p editio-ast'))

stories.append(create_story('11.6', 'technical', 'Implement dimension parsing (mm, cm, in, pt, px, %, em)',
    ['Create parse_dimension() function', 'Parse dimension strings'],
    'Dimension parsing works.',
    112, ['11.5'], 'cargo test --lib -p editio-parser test_parse_dimension'))

stories.append(create_story('11.7', 'technical', 'Implement page settings application',
    ['Create apply_page_settings() function', 'Apply margins and page size to layout'],
    'Page settings application works.',
    113, ['11.4', '11.5', '3.1'], 'cargo test --lib -p editio-layout test_apply_page_settings'))

stories.append(create_story('11.8', 'technical', 'Implement section formatting with automatic heading numbering',
    ['Create format_sections() function', 'Number headings hierarchically (1, 1.1, 1.1.1)'],
    'Section formatting works.',
    114, ['2.4'], 'cargo test --lib -p editio-core test_section_formatting'))

stories.append(create_story('11.9', 'technical', 'Implement paragraph formatting (alignment, spacing, indent)',
    ['Create format_paragraphs() function', 'Apply alignment, spacing, indentation'],
    'Paragraph formatting works.',
    115, ['2.3'], 'cargo test --lib -p editio-core test_paragraph_formatting'))

stories.append(create_story('11.10', 'technical', 'Implement page numbering in headers/footers',
    ['Extend render_header_footer()', 'Add sequential page numbers'],
    'Page numbering works.',
    116, ['4.9'], 'cargo test --lib -p editio-pdf test_page_numbering'))

# 12. CLI INTERFACE (Priority 117-124)
stories.append(create_story('12.1', 'technical', 'Add clap dependency to editio Cargo.toml',
    ['Open crates/editio/Cargo.toml', 'Add clap = { version = "4.5", features = ["derive"] }'],
    'Cargo.toml includes clap dependency.',
    117, ['1.2'], 'grep -q clap crates/editio/Cargo.toml'))

stories.append(create_story('12.2', 'technical', 'Create CLI Args struct with clap derive',
    ['Create Args struct', 'Use #[derive(Parser)] from clap'],
    'CLI Args struct exists.',
    118, ['12.1'], 'grep -q "struct Args" crates/editio/src/main.rs && cargo build --bin editio'))

stories.append(create_story('12.3', 'technical', 'Add Commands enum with Compile and Check variants',
    ['Create Commands enum', 'Add Compile and Check variants with fields'],
    'Commands enum exists.',
    119, ['12.2'], 'grep -q "enum Commands" crates/editio/src/main.rs && cargo build --bin editio'))

stories.append(create_story('12.4', 'technical', 'Implement compile subcommand with file argument',
    ['Create compile_command() function', 'Parse file argument and output flag'],
    'Compile subcommand works.',
    120, ['12.3'], 'cargo build --bin editio && ./target/debug/editio compile --help'))

stories.append(create_story('12.5', 'technical', 'Implement check subcommand for syntax validation',
    ['Create check_command() function', 'Validate markdown syntax'],
    'Check subcommand works.',
    121, ['12.3'], 'cargo build --bin editio && ./target/debug/editio check --help'))

stories.append(create_story('12.6', 'technical', 'Implement output file flag (-o) for compile command',
    ['Extend compile_command()', 'Add output: Option<PathBuf> field'],
    'Output flag works.',
    122, ['12.4'], 'cargo build --bin editio && ./target/debug/editio compile --help | grep -q output'))

stories.append(create_story('12.7', 'technical', 'Implement default output file naming',
    ['Create default_output_name() function', 'Generate output.pdf from input.md'],
    'Default output naming works.',
    123, ['12.6'], 'cargo test --bin editio test_default_output_naming'))

stories.append(create_story('12.8', 'technical', 'Implement error handling for CLI commands',
    ['Add error handling', 'Display clear error messages'],
    'Error handling works.',
    124, ['12.4', '12.5'], 'cargo test --bin editio test_error_handling'))

# Write JSON file
output = {
    'version': '2.0',
    'branchName': 'ralph/editio',
    'createdAt': now,
    'updatedAt': now,
    'userStories': stories
}

with open('projects/editio/prd.json', 'w') as f:
    json.dump(output, f, indent=2)

print(f'Generated {len(stories)} stories')
print(f'Written to projects/editio/prd.json')
