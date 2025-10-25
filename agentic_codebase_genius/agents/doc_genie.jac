# import from utils.helpers { generate_markdown, fetch_documents }
# import os;

# walker doc_genie {
#     has repo_name: str = "";

#     can generate_docs with entry {
#         if not self.repo_name {
#             report("Missing repository name.");
#             disengage;
#         }

#         report("Fetching repo data...");
#         repo_data = fetch_documents("repo_maps", {"url": {"$regex": self.repo_name}});
#         analysis_data = fetch_documents("code_analysis", {"repo": self.repo_name});

#         report("Synthesizing documentation...");
#         output_path = generate_markdown(self.repo_name, repo_data, analysis_data);

#         report(f"📄 Documentation generated at: {output_path}");
#     }
# }

import from utils.helpers { generate_markdown, fetch_documents, synthesize_final_doc_with_gemini, save_document }
import os, json;

walker doc_genie {
    has repo_name: str = "";

    can generate_docs with entry {
        if not self.repo_name {
            report "Missing repository name.";
            disengage;
        }

        report "Fetching repo data...";
        repo_data = fetch_documents("repo_maps", {"url": {"$regex": self.repo_name}});
        analysis_data = fetch_documents("code_analysis", {"repo": self.repo_name});

        if not repo_data or not analysis_data {
            report "Missing data for documentation.";
            disengage;
        }

        repo_summary = repo_data[0].get("summary", "");
        analysis_summaries = "\n".join(
            [a.get("summary","") for a in analysis_data[0].get("summaries",[])]
        );

        # Step 4 – Generate and finalize documentation
        report "Step 4: Synthesizing final Markdown...";
        output_path = generate_markdown(self.repo_name, repo_data, analysis_data);

        # Append Gemini-generated summary
        with open(output_path, "a") as f {
            f.write("\n\n## Gemini AI Summary\n\n" + gemini_doc);
        }

        # Persist document metadata
        save_document("docs", {
            "repo": self.repo_name,
            "path": output_path,
            "timestamp": now(),
        });

        report "📄 Final documentation generated at " + output_path;
    }
}
