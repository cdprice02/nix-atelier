# Social preview image

`social-preview.png` is what shows up when a link to this repo unfurls on
GitHub, Slack, Discord, etc. GitHub has no API for setting it: **Settings ->
General -> Social preview**, drag-and-drop, is the only way, so this file
has to be uploaded by hand after every real change.

`social-preview.svg` is the source; `social-preview.png` is that file
rendered at 1280x640, GitHub's recommended size. After editing the SVG,
regenerate the PNG with:

```sh
FONTDIR="$(nix build --no-link --print-out-paths nixpkgs#nerd-fonts.fira-code)/share/fonts/truetype/NerdFonts/FiraCode"
nix run nixpkgs#resvg -- --use-fonts-dir "$FONTDIR" --width 1280 --height 640 \
  .github/social-preview.svg .github/social-preview.png
```

Unpinned `nixpkgs#...`, deliberately: matches this repo's own CI precedent
(`check.yml`'s `nix shell nixpkgs#just`) for one-off tooling that isn't part
of the flake's own dependency graph.

Font is `FiraCode Nerd Font Mono`, not plain `Fira Code`: nixpkgs's `fira-code`
package ships only a variable-weight font, and `resvg` doesn't resolve
`font-weight` against a variable font's weight axis, so every weight rendered
identically until switching to the Nerd Font build, which ships real static
weight files. Matches `modules/lib/gui-base.nix`'s actual Alacritty
`font.normal.family` regardless.

Colors are this repo's own real `rose_pine` values, not just the upstream
theme's defaults:

| Color                  | Value     | Source                                                                             |
| ---------------------- | --------- | ---------------------------------------------------------------------------------- |
| Background             | `#1a1921` | `gui-base.nix`'s own `alacritty.colors.primary.background` override                |
| Text                   | `#e0def4` | `rose_pine`'s real foreground                                                      |
| Cursor block           | `#524f67` | `alacritty-theme`'s actual `rose_pine.toml`, `colors.cursor.cursor` -- not a guess |
| Accent (prompt, pills) | `#31748f` | `rose_pine`'s "pine"                                                               |
| Muted tagline          | `#908caa` | `rose_pine`'s "subtle"                                                             |
