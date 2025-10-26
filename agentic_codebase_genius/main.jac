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

#     can execute with entry {
#         report "=== Codebase Genius started ===";
#         load_dotenv();

#         if not self.url {
#             report "Error: missing GitHub repository URL.";
#             disengage;
#         }

#         # Derive repo name
#         self.repo_name = self.url.split("/")[-1].replace(".git", "");

#         # Step 1 - Map repository
#         report "Step 1: Mapping repository...";
#         repo_mapper.map_repo(url=self.url);

#         # Step 2 - Analyze code
#         report "Step 2: Analyzing code...";
#         code_analyzer.analyze_repo(repo_name=self.repo_name);

#         # Step 3 - Generate documentation
#         report "Step 3: Generating documentation...";
#         doc_genie.generate_docs(repo_name=self.repo_name);
#         report f"✅ Documentation pipeline complete for {self.repo_name}";
#     }
# }

# with entry {
#     load_dotenv();
#     report "Environment variables loaded successfully!";
#     print(os.getenv("MONGO_DB_URI"));
# }

import os;
import dotenv;
include "agents/repo_mapper.jac";
include "agents/code_analyzer.jac";
include "agents/doc_genie.jac";
import from utils.helpers { save_document, fetch_documents };

walker code_genius {
    has url = "";
    has repo_name = "";
    has doc_path = "";

    can execute with entry {
        report "=== Codebase Genius started ===";
        dotenv.load_dotenv();

        if (!url) {
            report "Error: missing GitHub repository URL.";
            disengage;
        }

        # Derive repo name
        self.repo_name = url.split("/")[-1].replace(".git", "");

        # Step 1 - Map repository
        report "Step 1: Mapping repository...";
        spawn here walker::repo_mapper(url=url);

        # Step 2 - Analyze code
        report "Step 2: Analyzing code...";
        spawn here walker::code_analyzer(repo_name=self.repo_name);

        # Step 3 - Generate documentation
        report "Step 3: Generating documentation...";
        spawn here walker::doc_genie(repo_name=self.repo_name);
        
        report "✅ Documentation pipeline complete for " + self.repo_name;
    }
}

with entry {
    dotenv.load_dotenv();
    report "Environment variables loaded successfully!";
    std.out(os.getenv("MONGO_DB_URI"));
}