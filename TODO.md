# TODO

```sh
packaging/windows_cross/buildpackage.sh
```

## Overall

-   Totally reorganise build system so that it works the same way on all
    platforms
-   Have proper phases for each section, which can be linked to make targets,
    and depend on one another
-   ~Don't build multiple architectures at once at the script level~
-   Unify makefiles (somehow)
-   ~Clean up script litter everywhere~
-   ~Move the C# source into one top level directory~
-   Fix the launch scripts (easier when there is no more disparity between
    regular and package builds)
-   Verify that all builds still work
-   Investigate a generic cross-platform build process
-   Pre-commit
-   Stop fetching anything at build time (kills reproduceability)

## Windows

-   ~Rename to windows_cross~
-   Investigate native packaging etc as well
-   Fix resource hacking

## Linux

-   ~Verify it works~
-   Fix dedicated server launch script
-   Add other packaging options

## MacOS

-   Verify it works
-   Check if unsigned releases work at all
