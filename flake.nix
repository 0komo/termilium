{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flakelight = {
      url = "github:nix-community/flakelight";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flakelight-zig = {
      url = "github:accelbread/flakelight-zig";
      inputs.flakelight.follows = "flakelight";
    };
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { flakelight, flakelight-zig, zig-overlay, ... }@inputs:
    flakelight ./. {
      inherit inputs;

      imports = [
        flakelight-zig.flakelightModules.default
      ];

      withOverlays = [
        zig-overlay.overlays.default
      ];

      zigToolchain = pkgs: {
        inherit (pkgs) zls;
        zig = pkgs.zigpkgs."0.14.1";
      };
    };
}
