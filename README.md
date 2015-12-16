chart-mate
======

[![Build Status](https://travis-ci.org/sgoings/chart-mate.svg?branch=master)](https://travis-ci.org/sgoings/chart-mate)

chart-mate is a [rerun][rerun] module that can be run on OSX or Linux in order
to help run e2e tests of [helm][helm] charts on a real [kubernetes][kubernetes]
cluster.

Quickstart
----------

1. Install `rerun`

  ```
  git clone https://github.com/rerun/rerun.git
  cd rerun
  export RERUN_PATH="$(pwd)"
  export PATH="$RERUN_PATH:$PATH"
  ```

2. Get `chart-mate`

  ```
  git clone https://github.com/sgoings/chart-mate.git
  cd chart-mate
  export CHART_MATE_PATH="$(pwd)"
  ```

3. Add `chart-mate` to `rerun`'s module path

  ```
  export RERUN_MODULES="${CHART_MATE_PATH}:${RERUN_PATH}/modules"
  ```

4. Run `rerun chart-mate`!

  ```
  rerun chart-mate
  ```

[rerun]: http://rerun.github.io/rerun/
[helm]: http://helm.sh
[kubernetes]: http://kubernetes.io
