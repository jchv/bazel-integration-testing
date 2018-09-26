# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(":common.bzl", "BAZEL_HASH_DICT", "BAZEL_VERSIONS")

_BAZEL_BINARY_PACKAGE = "http://releases.bazel.build/{version}/release/bazel-{version}-installer-{platform}.sh"

def _get_platform_name(rctx):
  os_name = rctx.os.name.lower()
  # We default on linux-x86_64 because we only support 2 platforms
  return "darwin-x86_64" if os_name.startswith("mac os") else "linux-x86_64"

def _get_installer(rctx):
  platform = _get_platform_name(rctx)
  version = rctx.attr.version
  url = _BAZEL_BINARY_PACKAGE.format(version = version, platform = platform)
  args = {"url": url, "type": "zip", "output": "bin"}
  if version in BAZEL_HASH_DICT and platform in BAZEL_HASH_DICT[version]:
    args["sha256"] = BAZEL_HASH_DICT[version][platform]
  rctx.download_and_extract(**args)

def _extract_bazel(rctx):
  install_base = rctx.path("install_base")
  foo = install_base.get_child("_embedded_binaries").get_child("embedded_tools").get_child("platforms").get_child("BUILD")
  rctx.file(foo,
            """
# Standard constraint_setting and constraint_values to be used in platforms.

package(
    default_visibility = ["//visibility:public"],
)

# These match values in //src/main/java/com/google/devtools/build/lib/util:CPU.java
constraint_setting(name = "cpu")

constraint_value(
    name = "x86_32",
    constraint_setting = ":cpu",
)

constraint_value(
    name = "x86_64",
    constraint_setting = ":cpu",
)

constraint_value(
    name = "ppc",
    constraint_setting = ":cpu",
)

constraint_value(
    name = "arm",
    constraint_setting = ":cpu",
)

constraint_value(
    name = "aarch64",
    constraint_setting = ":cpu",
)

constraint_value(
    name = "s390x",
    constraint_setting = ":cpu",
)

# These match values in //src/main/java/com/google/devtools/build/lib/util:OS.java
constraint_setting(name = "os")

constraint_value(
    name = "osx",
    constraint_setting = ":os",
)

constraint_value(
    name = "ios",
    constraint_setting = ":os",
)

constraint_value(
    name = "freebsd",
    constraint_setting = ":os",
)

constraint_value(
    name = "android",
    constraint_setting = ":os",
)

constraint_value(
    name = "linux",
    constraint_setting = ":os",
)

constraint_value(
    name = "windows",
    constraint_setting = ":os",
)

# A constraint that can only be matched by the autoconfigured platforms.
constraint_setting(
    name = "autoconfigure_status",
    visibility = ["//visibility:private"],
)

constraint_value(
    name = "autoconfigured",
    constraint_setting = ":autoconfigure_status",
    visibility = [
        "@bazel_tools//:__subpackages__",
        "@local_config_cc//:__subpackages__",
    ],
)

# A default platform with nothing defined.
platform(name = "default_platform")

# A default platform referring to the host system. This only exists for
# internal build configurations, and so shouldn't be accessed by other packages.
platform(
    name = "host_platform",
    constraint_values = [
        ":autoconfigured",
    ],
    cpu_constraints = [
        ":x86_32",
        ":x86_64",
        ":ppc",
        ":arm",
        ":aarch64",
        ":s390x",
    ],
    host_platform = True,
    os_constraints = [
        ":osx",
        ":freebsd",
        ":linux",
        ":windows",
    ],
)

platform(
    name = "target_platform",
    constraint_values = [
        ":autoconfigured",
    ],
    cpu_constraints = [
        ":x86_32",
        ":x86_64",
        ":ppc",
        ":arm",
        ":aarch64",
        ":s390x",
    ],
    os_constraints = [
        ":osx",
        ":freebsd",
        ":linux",
        ":windows",
    ],
    target_platform = True,
)
            """)
  result = rctx.execute([
      rctx.path("bin/bazel-real"), "--install_base",
      rctx.path("install_base"), "version"
  ])
  if result.return_code != 0:
    fail("`bazel version` returned non zero return code (%s): %s%s" %
         (result.return_code, result.stderr, result.stdout))
  ver = result.stdout.strip().split("\n")[0].split(":")[1].strip()
  if ver != rctx.attr.version:
    fail("`bazel version` returned version %s (expected %s)" %
         (ver, rctx.attr.version))

def _bazel_repository_impl(rctx):
  _get_installer(rctx)
  _extract_bazel(rctx)
  rctx.file("WORKSPACE", "workspace(name='%s')" % rctx.attr.name)
  rctx.template("bazel.sh", Label("//tools:bazel.sh"))
  rctx.file("BUILD", """
filegroup(
  name = "bazel_install_base",
  srcs = glob(["install_base/**"]),
  visibility = ["//visibility:public"])

sh_binary(
  name = "bazel",
  srcs = ["bazel.sh"],
  data = [
      ":bazel_install_base",
      ":bin/bazel-real",
  ],
  visibility = ["//visibility:public"])""")

bazel_binary = repository_rule(
    attrs = {
        "version": attr.string(default = "0.5.3"),
    },
    implementation = _bazel_repository_impl,
)
"""Download a bazel binary for integration test.

Args:
  version: the version of Bazel to download.

Limitation: only support Linux and macOS for now.
"""

def bazel_binaries(versions = BAZEL_VERSIONS):
  """Download all bazel binaries specified in BAZEL_VERSIONS."""
  for version in versions:
    name = "build_bazel_bazel_" + version.replace(".", "_")
    if not native.existing_rule(name):
      bazel_binary(name = name, version = version)
