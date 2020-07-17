ci
==

Continuous Integration images.

**These are not for production deployments of code:
they are large and bloated.
These images contain Stuff We Often Need In CI Testing.
The two use-cases are fundamentally different.**

Sub-directories `docker-FOO` each contain a `Dockerfile` controlling
the build of a Docker image.

We have a philosophical objection to encouraging the use of sudo, instead of
capabilities and drop-only privileges, albeit not as great as our objections
to mode 0777 directories, `curl | sh` or retrieval without checksum
verification.

Beware that these add my own certificate authorities to the system trust
stores.


docker-gobuild
--------------

Alpine images derived from upstream `golang:${VERSION}-alpine` images, with a
strictly minimal set of packages added.

These images should be sufficient to build.  They will not be extended to
include enough packages to make it easier to test or debug.  They do alas
include the docker CLI to be able to talk to Docker, to build images, not just
binaries.  Tools for building other packaging artifacts will probably not be
added, instead a new variant will be used.


```console
$ docker-gobuild/build.sh 1.14.6
```


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


Sizes
-----

I periodically update the Docker Hub description with stats on the
(horrendously large) sizes of these images.
They're not small.  Size is not a goal.

For production deployments, Small Is Good.
The smaller it is, the faster it transfers, the less there is to go wrong.
The less likely it is to be evicted from cache.
You can be small _relative to_ a large base image, as long as the base image
truly is widely used across all the target hosts, so will already be present.

My typical pattern is to use a multi-stage `Dockerfile` to build Go code in
`golang:x.y.z` or `alpine:x.y`,
then copy it into a `FROM scratch` final image in the last stage,
or sometimes `FROM alpine` if I want to be able to SSH in.
I expect total image sizes to be less than 20MiB,
or less than 50MiB if Alpine is used.
Perhaps more if there's a lot of ancillary data which for some reason belongs
in the image instead of a distinct Volume.

By contrast, these CI images take a "kitchen sink" approach.  The goal is to
not have to think too much about what I'm depending on when writing tests:
being able to write and run decent tests is more important than keeping the CI
image small, and an extra minute in CI runner start-up time is not a problem.
As long as the _build_ is small, so that it's comprehensible and easy to
audit, I am happy.

So as a rough ballpark:
* Pastel: 30 — 40 MiB
* Pink: 1.5 — 1.7 **GiB**
* Purple: 2.5 — 3 **GiB**

Those are insane.  I should probably abandon Pink and Purple and use Ubuntu
images for that sort of testing.  If I'm pausing to think about it when
writing tests, I might.  But otherwise: these are available, they work, and
they're a consistent environment.

But they're not a template for constructing an image for deployment to
Production.  And they're not intended to be.
