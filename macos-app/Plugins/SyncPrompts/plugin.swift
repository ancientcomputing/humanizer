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
        let promptsDir = context.package.directory.appending(subpath: "../prompts")
        let outputDir = context.pluginWorkDirectory.appending(subpath: "Prompts")
        let names = ["humanize.md", "classify.md", "consolidate.md"]

        try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)

        return [
            .prebuildCommand(
                displayName: "Sync prompts/*.md into Resources/Prompts",
                executable: Path("/bin/cp"),
                arguments: names.map { promptsDir.appending(subpath: $0).string } + [outputDir.string],
                outputFilesDirectory: outputDir
            )
        ]
    }
}
