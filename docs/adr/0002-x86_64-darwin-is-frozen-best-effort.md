# x86_64-darwin is frozen best-effort on nixpkgs 25.05

x86_64-darwin builds against `nixpkgs-25.05-darwin`, `home-manager`
`release-25.05` and `nix-darwin-25.05`, and stays there. nixpkgs-unstable has
dropped x86_64-darwin, and 25.11-darwin and later target macOS 14, which an
Intel Mac capped at macOS 13 can't run, so no newer release pair works on
that hardware. 25.05 is past its security-support window: x86_64-darwin
machines get no nixpkgs security fixes from this framework. Every other
system (Linux, WSL2, NixOS, aarch64-darwin) tracks the rolling inputs.

"Best-effort" means x86_64-darwin is supported while it still evaluates and
builds with cheap fixes: a per-system input pin (as with sops-nix), an
`hm-compat.nix` shim, or a feature declared `unsupported` there. A change that
would hold the rolling systems back for it is not made. x86_64-darwin is
dropped in v5, with no deprecation cycle beyond this record.

## Considered Options

- **Drop x86_64-darwin now**: honest about the security position, but
  strands the one real Intel machine this framework was built on, which has
  no supported alternative short of replacing it.
- **Track 25.11-darwin or later**: its binaries link against macOS 14's
  libc++ and abort under dyld on macOS 13.
- **Hold every system on 25.05 for uniformity**: trades the security of every
  other machine for one platform's constraint.

## Consequences

- The support matrix states x86_64-darwin's status, so a consumer choosing
  this framework for an Intel Mac knows it gets no security updates.
- Rolling-only packages and options reach x86_64-darwin late or never;
  `hm-compat.nix` and per-system input pins (`sops-nix-darwin`) carry the
  difference, and a feature that can't be made to work there is marked
  `unsupported` for it.
- Consumer flakes whose own tooling (treefmt, devShells) must run on an Intel
  Mac inherit the same 25.05 ceiling for that tooling.
- The one exception to the freeze is the Nix daemon. 25.05's Nix series is
  unpatched upstream, and the daemon runs as root and handles every build,
  so `nix-x86-darwin` pins a patched upstream release for x86_64-darwin
  alone. It stays on the newest series built against nixos-25.05 (2.31.x),
  which still runs on macOS 13; bump it for each upstream point release.
- `flake-checker` is useful only scoped to the rolling `nixpkgs` input: over
  `nixpkgs-darwin` it reports the pin's age, a permanent finding this record
  already accepts.
