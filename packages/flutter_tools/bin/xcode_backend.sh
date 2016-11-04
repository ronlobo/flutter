#!/bin/sh
# Copyright 2016 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

RunCommand() {
  echo "♦ " $@
  $@
  return $?
}

EchoError() {
  echo "$@" 1>&2
}

AssertExists() {
  RunCommand ls $1
  if [ $? -ne 0 ]; then
    EchoError "The path $1 does not exist"
    exit -1
  fi
  return 0
}

BuildApp() {
  local project_path="${SOURCE_ROOT}/.."
  if [[ -n "$FLUTTER_APPLICATION_PATH" ]]; then
    project_path=${FLUTTER_APPLICATION_PATH}
  fi

  local target_path="lib/main.dart"
  if [[ -n "$FLUTTER_TARGET" ]]; then
    target_path=${FLUTTER_TARGET}
  fi

  local build_mode="release"
  if [[ -n "$FLUTTER_BUILD_MODE" ]]; then
    build_mode=${FLUTTER_BUILD_MODE}
  fi

  local artifact_variant="unknown"
  case "$build_mode" in
    release) artifact_variant="ios-release";;
    profile) artifact_variant="ios-profile";;
    debug) artifact_variant="ios";;
    *) echo "Unknown FLUTTER_BUILD_MODE: $FLUTTER_BUILD_MODE";;
  esac

  local framework_path="${FLUTTER_ROOT}/bin/cache/artifacts/engine/${artifact_variant}"
  if [[ -n "$FLUTTER_FRAMEWORK_DIR" ]]; then
    framework_path="${FLUTTER_FRAMEWORK_DIR}"
  fi

  AssertExists ${project_path}

  local derived_dir=${SOURCE_ROOT}/Flutter
  RunCommand mkdir -p $derived_dir
  AssertExists $derived_dir

  RunCommand rm -f ${derived_dir}/Flutter.framework
  RunCommand rm -f ${derived_dir}/app.dylib
  RunCommand rm -f ${derived_dir}/app.flx
  RunCommand cp -r ${framework_path}/Flutter.framework ${derived_dir}
  RunCommand pushd ${project_path}

  AssertExists ${target_path}

  local build_dir=${FLUTTER_BUILD_DIR:-build}
  local local_engine_flag=""
  if [[ -n "$LOCAL_ENGINE" ]]; then
    local_engine_flag="--local-engine=$LOCAL_ENGINE"
  fi

  if [[ $CURRENT_ARCH != "x86_64" ]]; then
    local aot_flags=""
    if [[ "$build_mode" == "debug" ]]; then
      aot_flags="--interpreter --debug"
    else
      aot_flags="--${build_mode}"
    fi

    RunCommand ${FLUTTER_ROOT}/bin/flutter --suppress-analytics build aot \
      --output-dir=${build_dir}/aot                                       \
      --target-platform=ios                                               \
      --target=${target_path}                                             \
      ${aot_flags}                                                        \
      ${local_engine_flag}

    if [[ $? -ne 0 ]]; then
      EchoError "Failed to build ${project_path}."
      exit -1
    fi

    RunCommand cp ${build_dir}/aot/app.dylib ${derived_dir}/app.dylib
  else
    RunCommand eval "$(echo \"static const int Moo = 88;\" | xcrun clang -x c --shared -o ${derived_dir}/app.dylib -)"
  fi

  local precompilation_flag=""
  if [[ $CURRENT_ARCH != "x86_64" ]] && [[ "$build_mode" != "debug" ]]; then
    precompilation_flag="--precompiled"
  fi

  RunCommand ${FLUTTER_ROOT}/bin/flutter --suppress-analytics build flx \
    --target=${target_path}                                             \
    --output-file=${derived_dir}/app.flx                                \
    --snapshot=${build_dir}/snapshot_blob.bin                           \
    --depfile=${build_dir}/snapshot_blob.bin.d                          \
    --working-dir=${build_dir}/flx                                      \
    ${precompilation_flag}                                              \
    ${local_engine_flag}                                                \

  if [[ $? -ne 0 ]]; then
    EchoError "Failed to package ${project_path}."
    exit -1
  fi

  RunCommand popd

  echo "Project ${project_path} built and packaged successfully."
  return 0
}

BuildApp
