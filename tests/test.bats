setup() {
  set -eu -o pipefail
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/test-ddev-vite
  mkdir -p $TESTDIR
  export PROJNAME=test-ddev-vite
  export DDEV_NON_INTERACTIVE=true
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  ddev config --project-name=${PROJNAME}
  ddev start -y >/dev/null
}

install_vite() {
  ddev exec npm i vite
}

start_dev_server() {
  # Start dev server in the background to be able to continue test
  ddev vite &

  # Wait maximum 5s until vite is ready for requests
  for _ in `seq 1 10`; do
    echo -n .
    if ddev exec nc -z localhost 5173; then
      return
    fi
    sleep 0.5
  done
}

health_checks() {
  curl -s -D - -o /dev/null https://${PROJNAME}.ddev.site/_vite/@vite/client | grep "HTTP/2 200"
}

teardown() {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory and run dev server" {
  set -eu -o pipefail
  cd ${TESTDIR}
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ${DIR}
  ddev restart
  install_vite
  start_dev_server
  health_checks
}

@test "install from release and run dev server" {
  skip "no release yet"

  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get ddev/ddev-ddev-vite with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ddev/ddev-ddev-vite
  ddev restart >/dev/null
  install_vite
  start_dev_server
  health_checks
}

@test "fail to install in apache project" {
  set -eu -o pipefail
  cd ${TESTDIR}
  ddev config --webserver-type apache-fpm
  run ddev get ${DIR}
  [ "$status" -eq 1 ]
}

@test "install from directory and run build" {
  set -eu -o pipefail
  cd ${TESTDIR}
  ddev get ${DIR}
  ddev restart
  install_vite
  touch index.html
  ddev vite build --manifest
  test -f dist/index.html
  test -f dist/.vite/manifest.json
}