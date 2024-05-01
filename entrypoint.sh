#!/bin/bash

set -eo pipefail

# config
project_filename=${PROJECT_FILENAME:-project1.lpi}
major_version=${MAJOR_VERSION:-0}
minor_version=${MINOR_VERSION:-0}
revision_version=${REVISION_VERSION:-0}
build_number=${BUILD_NUBER:-0}
verbose=${VERBOSE:-false}

# # since https://github.blog/2022-04-12-git-security-vulnerability-announced/ runner uses?
# git config --global --add safe.directory /github/workspace

# cd "${GITHUB_WORKSPACE}/${source}" || exit 1

echo "*** CONFIGURATION ***"
echo -e "PROJECT_FILENAME: ${project_filename}"
echo -e "MAJOR_VERSION: ${major_version}"
echo -e "MINOR_VERSION: ${minor_version}"
echo -e "REVISION_VERSION: ${revision_version}"
echo -e "BUILD_NUBER: ${build_number}"

# verbose, show everything
if $verbose
then
    set -x
fi

if [[ ! -f ${project_filename} ]]; then
    echo "Project/Package file not found: ${project_filename}"
    exit 1
fi

# Project paths
major_path='.CONFIG.ProjectOptions.VersionInfo.MajorVersionNr."+@Value"'
minor_path='.CONFIG.ProjectOptions.VersionInfo.MinorVersionNr."+@Value"'
revision_path='.CONFIG.ProjectOptions.VersionInfo.RevisionNr."+@Value"'
build_path='.CONFIG.ProjectOptions.VersionInfo.BuildNr."+@Value"'

# IS this a project or packages
out=$(yq e -p xml -o xml '.CONFIG.ProjectOptions' ${project_filename})
if [[ $out == "null" ]]
then
    # Package paths
    major_path='.CONFIG.Package.Version."+@Major"'
    minor_path='.CONFIG.Package.Version."+@Minor"'
    revision_path='.CONFIG.Package.Version."+@Release"'
    build_path='.CONFIG.Package.Version."+@Build"'
fi

# Set major version:
yq e -p xml -o xml -i "$major_path = $major_version" $project_filename

# Set minor version:
yq e -p xml -o xml -i "$minor_path = $minor_version" $project_filename

# Set revision version:
yq e -p xml -o xml -i "$revision_path = $revision_version" $project_filename

# Set build numberor :
yq e -p xml -o xml -i "$build_path = $build_number" $project_filename