#!/bin/bash

export PATH="$PWD/bin:$PWD/bin/cache/dart-sdk/bin:$PATH"

trap detect_error_on_exit EXIT HUP INT QUIT TERM

detect_error_on_exit() {
    exit_code=$?
    set +x
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\x1B[31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m"
        echo -e "\x1B[1mError:\x1B[31m script exited early due to error ($exit_code)\x1B[0m"
        echo -e "\x1B[31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1B[0m"
    fi
}

set -ex

# analyze all the Dart code in the repo
flutter analyze --flutter-repo

# verify that the tests actually return failure on failure and success on success
(cd dev/automated_tests; ! flutter test test_smoke_test/fail_test.dart > /dev/null)
(cd dev/automated_tests; flutter test test_smoke_test/pass_test.dart > /dev/null)

COVERAGE_FLAG=
if [ -n "$TRAVIS" ] && [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
  COVERAGE_FLAG=--coverage
fi

SRC_ROOT=$PWD

# run tests
(cd packages/flutter; flutter test $COVERAGE_FLAG)
(cd packages/flutter_driver; dart -c test/all.dart)
(cd packages/flutter_test; flutter test)
(cd packages/flutter_tools; FLUTTER_ROOT=$SRC_ROOT dart -c test/all.dart)

(cd dev/devicelab; dart -c test/all.dart)
(cd dev/manual_tests; flutter test)
(cd examples/hello_world; flutter test)
(cd examples/layers; flutter test)
(cd examples/stocks; flutter test)
(cd examples/flutter_gallery; flutter test)

# generate and analyze our large sample app
dart dev/tools/mega_gallery.dart
(cd dev/benchmarks/mega_gallery; flutter analyze --watch --benchmark)

if [ -n "$COVERAGE_FLAG" ]; then
  GSUTIL=$HOME/google-cloud-sdk/bin/gsutil
  GCLOUD=$HOME/google-cloud-sdk/bin/gcloud

  $GCLOUD auth activate-service-account --key-file ../gcloud_key_file.json
  STORAGE_URL=gs://flutter_infra/flutter/coverage/lcov.info
  $GSUTIL cp packages/flutter/coverage/lcov.info $STORAGE_URL
fi

# generate the API docs, upload them
dev/bots/docs.sh
