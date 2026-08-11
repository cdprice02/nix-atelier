<!-- markdownlint-disable-file MD041 -->

<!-- MD041 wants a top-level heading first, but GitHub renders this file as the
     PR body, where an h1 would sit oddly above the repo's own PR title. -->

## Summary

<!-- What does this PR change and why? -->

## Checklist

- [ ] `just check` passes (runs `just lint-all` then `nix flake check --impure`)
- [ ] `pre-commit run --all-files` clean (trailing whitespace, secrets scan, alejandra, markdownlint)
- [ ] This is a framework improvement, not a personal preference (see [CONTRIBUTING.md](../CONTRIBUTING.md))
- [ ] Docs updated if the change affects bootstrap, profile selection, or module composition

## Related issues

<!-- Closes #N -->
