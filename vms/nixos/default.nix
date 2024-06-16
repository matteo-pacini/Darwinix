{
  stdenvNoCC,
  aarch64-qemu-efi,
  fetchurl,
  lib,
  qemu,
  perl,
  gum,
  makeWrapper,
}:
let
  inherit (builtins)
    filter
    elem
    split
    baseNameOf
    ;
  iso = fetchurl {
    url = "https://releases.nixos.org/nixos/24.05/nixos-24.05.1409.cc54fb41d137/nixos-minimal-24.05.1409.cc54fb41d137-aarch64-linux.iso";
    hash = "sha256-nNm3KUBkxS8tgwd52HZgb3bFywb8A12zFEXVn+CnyBU=";
  };
  thisQemu = qemu.override {
    # Avoid long compiling times by only building aarch64 target
    hostCpuTargets = [ "${stdenvNoCC.hostPlatform.qemuArch}-softmmu" ];
  };
  finalQemu = thisQemu.overrideAttrs (oldAttrs: {
    # Filter out patches that disable some advanced Cocoa features,
    # like copy-pasting between host and guest.
    # Min. OS required becomes macOS 11.0, which is the base SDK for `aaarch64-darwin`.
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/virtualization/qemu/default.nix#L116-L137
    patches = filter (patch: !(elem "cocoa" (split "-" (baseNameOf patch)))) oldAttrs.patches;
  });
in
stdenvNoCC.mkDerivation {

  pname = "nixos-vm";
  version = "24.05";
  src = ../../scripts;
  nativeBuildInputs = [ makeWrapper ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/{bin,share}
    cp $src/nixos.sh $out/bin
    patchShebangs $out/bin/nixos.sh
    substituteInPlace $out/bin/nixos.sh \
      --replace-fail "@@prefix@@" "\"$out\""
    chmod +x $out/bin/nixos.sh
    cp -r ${aarch64-qemu-efi}/share/RELEASEAARCH64_QEMU_EFI.fd $out/share
    cp -r ${aarch64-qemu-efi}/share/RELEASEAARCH64_QEMU_VARS.fd $out/share
    cp ${iso} $out/share/nixos.iso
    wrapProgram $out/bin/nixos.sh \
      --prefix PATH : "${
        lib.makeBinPath [
          finalQemu
          perl
          gum
        ]
      }"
  '';
}
