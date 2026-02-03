from dataclasses import dataclass
from typing import List, Dict

@dataclass
class AnalysisResult:
    num_errors: int = 0
    error_details: List[Dict] = None
    top_error_codes: Dict[str, int] = None
    avg_response_time: float = 0.0