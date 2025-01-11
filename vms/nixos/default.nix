{
  stdenvNoCC,
  aarch64-qemu-efi,
  fetchurl,
  lib,
  mkQemu,
  perl,
  gum,
  makeWrapper,
}:
let

  iso = fetchurl {
    url = "https://releases.nixos.org/nixos/24.11/nixos-24.11.712512.3f0a8ac25fb6/nixos-minimal-24.11.712512.3f0a8ac25fb6-aarch64-linux.iso";
    hash = "sha256-gqCyAhnNn4ewCA+h6kAr0PdO/7KDC6wwBF4Kzfasn44=";
  };
  qemu = mkQemu { hostCpuTarget = "aarch64-softmmu"; };
in
stdenvNoCC.mkDerivation {

  pname = "nixos-vm";
  version = "24.11";
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
          qemu
          perl
          gum
        ]
      }"
  '';
}
