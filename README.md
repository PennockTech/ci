ci
==

Continuous Integration images.

Sub-directories `docker-FOO` each contain a `Dockerfile` controlling
the build of a Docker image.

We have a philosophical objection to encouraging the use of sudo, instead of
capabilities and drop-only privileges, albeit not as great as our objections
to mode 0777 directories, `curl | sh` or retrieval without checksum
verification.


docker-purple
-------------

First-generation Pennock Tech CI image for ourselves, rather than for
clients.  Based on Alpine, this is rather heavy, with gcc, clang,
python, go and much more.

Creates:
 * `pennocktech/ci:purple-root`: everything installed, uid is `root`
 * `pennocktech/ci:purple`: run-time user is `ci`

Known issues:
 * build style is incompatible with Docker build-step caching, needs a rethink
   to find a decent middle-ground while still avoiding the 20-line chained-&&
   pattern
 * missing docker and kubectl still
 * too large

I do development work _on_ Zsh, so the usual suspects such as "remove fancy
shells", are not really tenable.  I mostly wanted to get an image with
up-to-date pip out, before the PyPI cut-over, so haven't yet prioritized sane
shrinkage.
