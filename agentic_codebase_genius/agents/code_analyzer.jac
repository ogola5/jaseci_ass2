import from utils.helpers { parse_python_files, save_document, explain_code_module_with_gemini } # <--- FIX: Added semicolon
import os;

walker code_analyzer {
    has repo_name: str = "";

    can analyze_repo with entry {
        if not self.repo_name {
            report "Missing repository name.";
            disengage;
        };

        report "Analyzing code in " + self.repo_name + "...";
        analysis_result = parse_python_files("./outputs/" + self.repo_name + "/repo"); # <--- FIX: Added semicolon

        report "Generating module summaries with Gemini...";
        summaries = [];

        for each in analysis_result {
            file_path = each["file"]; # <--- FIX: Added semicolon
            try {
                report "Summarizing " + file_path + "...";
                summary = explain_code_module_with_gemini("auto", file_path); # <--- FIX: Added semicolon
                summaries.append({
                    "file": file_path,
                    "summary": summary,
                }); # <--- FIX: Added semicolon
            } except Exception as e { # <--- FIX: Changed bare 'except' to 'except Exception as e'
                report f"Failed to summarize {file_path}: {e}"; # <--- Good Practice: Log the error
                summaries.append({
                    "file": file_path,
                    "summary": "Failed to summarize."
                }); # <--- FIX: Added semicolon
            };
        };

        save_document("code_analysis", {
            "repo": self.repo_name,
            "analysis": analysis_result,
            "summaries": summaries
        }); # <--- FIX: Added semicolon

        report "✅ Code analysis and summaries saved successfully.";
    }
}