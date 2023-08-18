{
  description = "libraries for account and server management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05-pre";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nixFlake.url = "github:nix-community/poetry2nix";
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nixFlake }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend (final: prev: {
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (python-self: python-super: {
              setuptools-scm = python-super.setuptools-scm.overridePythonAttrs (old: rec {
                version = "6.4.2";
                src = python-super.fetchPypi {
                  pname = "setuptools_scm";
                  inherit version;
                  sha256 = "sha256-aDOsZcbtlxGk1dImb4Akz6B8UzoOVfTBL27/KApanjA=";
                };
              });
            })
          ];
        });
        poetry2nix = poetry2nixFlake.legacyPackages.${system};
        python37 = pkgs.python37;
        pypkgs-build-requirements = {
          cracklib = [ pkgs.cracklib "setuptools" ];
          pygithub = [ "setuptools-scm" ];
        };
        p2n-overrides = (self: super:
          builtins.mapAttrs
            (package: build-requirements:
              (builtins.getAttr package super).overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg: if builtins.isString pkg then builtins.getAttr pkg super else pkg) build-requirements);
              })
            )
            pypkgs-build-requirements
        );
        poetry-config = {
          python = python37;
          projectDir = ./.;
          overrides = (poetry2nix.defaultPoetryOverrides.extend
            (self: super: {
              pysnmp = super.pysnmp.overridePythonAttrs (old: {
                version = "4.4.13";
                src = pkgs.fetchFromGitHub {
                  owner = "etingof";
                  repo = "pysnmp";
                  rev = "release-4.4.13";
                  sha256 = "sha256-N3yJdVur4T/vXpRTaHRWVQa1hPpZbMk/J+H38kjqAwE=";
                };
                patches = [ ];
              });
            })).extend (
            p2n-overrides
          );

          editablePackageSources = {
            ocflib = ./ocflib;
          };
        };
      in
      {
        packages.default = poetry2nix.mkPoetryApplication (builtins.removeAttrs poetry-config [ "editablePackageSources" ]);
        devShells.default = (poetry2nix.mkPoetryEnv poetry-config).env;
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
