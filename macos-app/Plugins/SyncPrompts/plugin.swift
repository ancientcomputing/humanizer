import Foundation
import PackagePlugin

/// Copies prompts/*.md (the single source of truth, shared with the Python
/// backend at core/prompts.py) into the plugin's build work directory before
/// every build. SwiftPM picks up files under a prebuild command's
/// outputFilesDirectory as target resources automatically, so the .md files
/// never need to be hand-duplicated into Swift source.
@main
struct SyncPrompts: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let promptsDir = context.package.directoryURL.appending(path: "../prompts")
        let outputDir = context.pluginWorkDirectoryURL.appending(path: "Prompts")
        let names = ["humanize.md", "classify.md", "consolidate.md", "verify.md"]

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        return [
            .prebuildCommand(
                displayName: "Sync prompts/*.md into Resources/Prompts",
                executable: URL(fileURLWithPath: "/bin/cp"),
                arguments: names.map { promptsDir.appending(path: $0).path } + [outputDir.path],
                outputFilesDirectory: outputDir
            )
        ]
    }
}
