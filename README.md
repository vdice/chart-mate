chart-mate
======

[![Build Status](https://travis-ci.org/sgoings/chart-mate.svg?branch=master)](https://travis-ci.org/sgoings/chart-mate)

chart-mate is a [rerun][rerun] module that can be run on OSX or Linux in order
to help run e2e tests of [helm][helm] charts on a real [kubernetes][kubernetes]
cluster.

Quickstart
----------

1. Get `chart-mate`

  ```
  git clone https://github.com/sgoings/chart-mate.git
  cd chart-mate
  ```

2. Run the `hacking.sh` script

  ```
  ./hacking.sh
  ```

3. Source the `hacking.sh` script

  ```
  source hacking.sh
  ```

4. Run `rerun chart-mate`!

  ```
  rerun chart-mate
  ```

[rerun]: http://rerun.github.io/rerun/
[helm]: http://helm.sh
[kubernetes]: http://kubernetes.io
