# Linux/WSL2 profile name -> {context, tier, withGui, useFor} axes, consumed
# by flake.nix's homeConfigurations (each entry becomes a mkLinuxPair call)
# and by the generated docs/profiles.md: single-sourced so the two can't
# drift. `useFor` is the doc table's editorial "Use for" text; everything
# else feeds mkProfile directly.
#
# darwinConfigurations is not represented here: it's a fixed 4-entry
# {personal,work} x {x86_64-darwin,aarch64-darwin} cross product with tier
# hardcoded to "dev" and withGui hardcoded true inside mkDarwinConfig itself
# (not parameters), so there's no repeated pattern here worth datifying.
{
  personal = {
    context = "personal";
    tier = "dev";
    withGui = false;
    useFor = "Personal Linux / WSL2";
  };
  personal-gui = {
    context = "personal";
    tier = "dev";
    withGui = true;
    useFor = "Personal desktop Linux";
  };
  personal-minimal = {
    context = "personal";
    tier = "minimal";
    withGui = false;
    useFor = "Bootstrap or low-resource machine";
  };
  personal-server = {
    context = "personal";
    tier = "server";
    withGui = false;
    useFor = "Personal headless server";
  };
  work = {
    context = "work";
    tier = "dev";
    withGui = false;
    useFor = "Work Linux / WSL2";
  };
  work-gui = {
    context = "work";
    tier = "dev";
    withGui = true;
    useFor = "Work desktop Linux";
  };
  work-minimal = {
    context = "work";
    tier = "minimal";
    withGui = false;
    useFor = "Work bootstrap";
  };
  work-server = {
    context = "work";
    tier = "server";
    withGui = false;
    useFor = "Work headless server";
  };
}
