

import from utils.helpers { clone_repo, build_file_tree, save_document, read_readme, summarize_readme_with_gemini }
import os;

walker repo_mapper {
    has url: str = "";
    has repo_path: str = "";
    has file_tree: dict = {};
    has readme_summary: str = "";

    can map_repo with entry {
        if not self.url {
            report "Missing repository URL.";
            disengage;
        }

        report "Cloning repository...";
        self.repo_path = clone_repo(self.url);
        report "Cloned to " + self.repo_path;

        report "Building file tree...";
        self.file_tree = build_file_tree(self.repo_path);

        report "Reading README...";
        readme_content = read_readme(self.repo_path);
        if readme_content {
            report "Summarizing README with Gemini...";
            self.readme_summary = summarize_readme_with_gemini(readme_content, self.url.split("/")[-1]);
        } else {
            self.readme_summary = "No README found.";
        }

        save_document("repo_maps", {
            "url": self.url,
            "tree": self.file_tree,
            "summary": self.readme_summary
        });

        report "Repository structure and summary saved.";
    }
}
