# import os;
# import from dotenv { load_dotenv }

# include agents.repo_mapper;
# include agents.code_analyzer;
# include agents.doc_genie;
# import from utils.helpers { save_document, fetch_documents }


# walker code_genius {
#     has url: str = "";
#     has repo_name: str = "";
#     has doc_path: str = "";

#     can execute with `root entry {
#         load_dotenv();
#         report "=== Codebase Genius started ===";

#         if not self.url {
#             report "Error: missing GitHub repository URL.";
#             return {"error": "Missing URL"};
#         };

#         self.repo_name = self.url.split("/")[-1].replace(".git", "");

#         report "Step 1: Mapping repository...";
#         spawn root ++> repo_mapper(url=self.url);

#         report "Step 2: Analyzing code...";
#         spawn root ++> code_analyzer(repo_name=self.repo_name);

#         report "Step 3: Generating documentation...";
#         spawn root ++> doc_genie(repo_name=self.repo_name);

#         report f"✅ Pipeline complete for {self.repo_name}";
#         return {"status": "success", "repo": self.repo_name, "doc_path": "./outputs/" + self.repo_name + "/docs.md"};
#     }
# }

import os;
import from dotenv { load_dotenv }

include agents.repo_mapper;
include agents.code_analyzer;
include agents.doc_genie;
import from utils.helpers { save_document, fetch_documents }

walker code_genius {
    has url: str = "";
    has repo_name: str = "";
    has doc_path: str = "";

    can execute with `root entry {
        load_dotenv();
        report "=== Codebase Genius started ===";

        if not self.url {
            report "Error: missing GitHub repository URL.";
            return {"error": "Missing URL"};
        };

        self.repo_name = self.url.split("/")[-1].replace(".git", "");

        report "Step 1: Mapping repository...";
        repo_mapper_instance = spawn repo_mapper;
        repo_mapper_instance.url = self.url;
        repo_mapper_instance.map_repo();

        report "Step 2: Analyzing code...";
        code_analyzer_instance = spawn code_analyzer;
        code_analyzer_instance.repo_name = self.repo_name;
        code_analyzer_instance.analyze_repo();

        report "Step 3: Generating documentation...";
        doc_genie_instance = spawn doc_genie;
        doc_genie_instance.repo_name = self.repo_name;
        doc_genie_instance.generate_docs();

        report f"✅ Pipeline complete for {self.repo_name}";
        return {"status": "success", "repo": self.repo_name, "doc_path": "./outputs/" + self.repo_name + "/docs.md"};
    }
}