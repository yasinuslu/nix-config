{
  lib,
  inputs,
  ...
}:
let
  # Core module discovery function
  discoverModules =
    {
      baseDir, # Root directory to search
      topModuleArgs ? { }, # Arguments to pass to each module
    }:
    let
      # Recursively find .nix files
      findModFiles =
        dir:
        let
          # Read directory contents safely
          contents = if builtins.pathExists dir then builtins.readDir dir else { };

          # Process each item in the directory
          processItem =
            name: type:
            let
              path = dir + "/${name}";
            in
            if type == "regular" && lib.hasSuffix ".nix" name then
              [
                {
                  inherit path;
                  name = lib.removeSuffix ".nix" name;
                }
              ]
            else if type == "directory" then
              findModFiles path
            else
              [ ];

          # Map over directory contents
          results = lib.mapAttrsToList processItem contents;
        in
        builtins.concatLists results;

      # Convert file paths to module paths and option paths
      pathToModuleInfo =
        file:
        let
          # Remove baseDir prefix and .nix suffix
          relative = lib.removePrefix (toString baseDir + "/") (toString file.path);
          withoutNix = lib.removeSuffix ".nix" relative;

          # Split path into components
          components = lib.splitString "/" withoutNix;
        in
        {
          inherit (file) path;
          relativePath = withoutNix;
          components = components;
        };

      # Create nested structure from components
      mkNestedAttrs =
        components: value:
        if components == [ ] then
          value
        else
          {
            ${builtins.head components} = mkNestedAttrs (builtins.tail components) value;
          };

      # Create module for a single file
      makeModule =
        file:
        let
          moduleInfo = pathToModuleInfo file;
          originalModule = topModuleArgs.flake-parts-lib.importApply moduleInfo.path topModuleArgs;
        in
        originalModule;

      # Find all module files
      moduleFiles = findModFiles baseDir;

      # First create a flat attribute set with relative paths as keys
      modulesByPath = lib.listToAttrs (
        map (
          file:
          let
            moduleInfo = pathToModuleInfo file;
          in
          {
            name = moduleInfo.relativePath;
            value = {
              inherit (moduleInfo) components;
              module = makeModule file;
            };
          }
        ) moduleFiles
      );

      # Convert flat attribute set to nested structure
      nestedModules = lib.foldr lib.recursiveUpdate { } (
        lib.mapAttrsToList (path: info: mkNestedAttrs info.components info.module) modulesByPath
      );

      # Optional debug logging
      _ = lib.warn (
        if builtins.length moduleFiles == 0 then
          "No .nix modules discovered in ${toString baseDir}"
        else
          "Discovered ${toString (builtins.length moduleFiles)} .nix modules"
      ) null;
    in
    {
      nested = nestedModules;
      flat = map (info: info.module) (builtins.attrValues modulesByPath);
    };
in
{
  inherit discoverModules;
}
