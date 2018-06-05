ci
==

Continuous Integration images.

Sub-directories `docker-FOO` each contain a `Dockerfile` controlling
the build of a Docker image.

We have a philosophical objection to encouraging the use of sudo, instead of
capabilities and drop-only privileges, albeit not as great as our objections
to mode 0777 directories, `curl | sh` or retrieval without checksum
verification.

Beware that these add my own certificate authorities to the system trust
stores.


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
 * missing kubectl still
 * too large

I do development work _on_ Zsh, so the usual suspects such as "remove fancy
shells", are not really tenable.  I mostly wanted to get an image with
up-to-date pip out, before the PyPI cut-over, so haven't yet prioritized sane
shrinkage.


docker-pink
-----------

Stripped down from `docker-purple`, this has things required for a custom Go
build but is missing most of the rest of the tooling added.  The purple
tooling is used to create this image.


docker-pastel
-------------

This is created with the purple tooling, but only installs the most critical
of packages:

* `curl`
* `git`
* `jq`
* `openssl`

A few config files go in too, including the aforementioned certificate trust
stores being setup.

