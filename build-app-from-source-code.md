# Build app from source code

## PackageCompiler.jl

Open julia and run the following to install PackageCompiler.lj

```julia
Pkg.add("PackageCompiler")
```

## Create app

Use PackageCompiler.create\_app() to compile app from source project. For this example, the git-qool repo is restored to \~/repos/git-qool and the app will be created at \~/GitQooLCompiled

```julia
using PackageCompiler

create_app("repos/git-qool", "GitQooLCompiled")
```

Now the app can be run via the executable within the GitQooLCompiled/bin directory
