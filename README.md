# FACT Repository Knowledge System

This directory is the consolidated result of Product, Architecture, Engineering and AI Collaboration phases.

It is designed to be copied into the actual FACT repository root. It intentionally excludes phase manifests and completion reports.

## Context discipline

Only `CLAUDE.md` is globally relevant. Path rules activate by file scope; skills and agents load on demand; detailed documents are selected through `docs/ai/context-routing.md`.

## Integration notes

1. Merge these files into the real repository.
2. Keep existing application code and backend directories.
3. Review `.claude/settings.example.json`, then create project-local `.claude/settings.json` only after testing hook paths.
4. Compare the example analyzer configuration with the real `analysis_options.yaml` rather than overwriting blindly.
5. Run the first real feature task as an evaluation and tune routing from evidence.
