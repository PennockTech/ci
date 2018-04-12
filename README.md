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
