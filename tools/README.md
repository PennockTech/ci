tools
=====

### Shell choice

We stick as close as feasible to "POSIX shell", but we do expect a very few
extra things.  Not big features, just sane features:

1. We expect `local` to exist, as a builtin, to declare variables local inside
   a function.
2. We expect that `source` (or `.`) pass parameters to the sourced file in
   argv.

Almost all POSIX or POSIX-alike shells comply with these two feature
requirements.  But `dash` does not pass arguments to `source`.  And `dash` is
`/bin/sh` on a variety of Linux-derived systems.

The `/bin/sh` in Alpine is busybox, using `ash`.  Despite `dash` being derived
from `ash`, in this case `ash` supports passing arguments.  And Alpine does
not include `bash` by default, so we can't just write `#!/bin/bash`.

So:

1. If the script is to be run inside the container, then `#!` should reference
   `/bin/sh`
2. If the script is to be run from a host machine, or otherwise outside the
   container, then `#!` should reference `/bin/bash`.
