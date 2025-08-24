{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flakelight.url = "github:nix-community/flakelight";
    flakelight-zig.url = "github:accelbread/flakelight-zig";
    zig.url = "github:silversquirl/zig-flake/compat";
    zls.url = "github:zigtools/zls";

    flakelight.inputs.nixpkgs.follows = "nixpkgs";
    flakelight-zig.inputs.flakelight.follows = "flakelight";
    zig.inputs.nixpkgs.follows = "nixpkgs";
    zls.inputs.nixpkgs.follows = "nixpkgs";
    zls.inputs.zig-overlay.follows = "zig";
  };

  outputs =
    {
      flakelight,
      flakelight-zig,
      zig,
      zls,
      ...
    }@inputs:
    flakelight ./. {
      inherit inputs;

      imports = [
        flakelight-zig.flakelightModules.default
      ];

      zigToolchain =
        pkgs:
        let
          zigPkgs = zig.packages.${pkgs.system};
          zlsPkgs = zls.packages.${pkgs.system};
        in
        {
          zig = zigPkgs.default;
          zls = zlsPkgs.zls;
        };

      devShell.packages =
        pkgs: with pkgs; [
          just
        ];
    };
}
