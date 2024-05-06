#!/bin/bash

set -exo pipefail

# config
project_filename=${PROJECT_FILENAME:-project1.lpi}
github_token=${GITHUB_TOKEN}
verbose=${VERBOSE:-false}

# since https://github.blog/2022-04-12-git-security-vulnerability-announced/ runner uses?
git config --global safe.directory "${GITHUB_WORKSPACE}"
git config --global safe.directory /github/workspace
git remote set-url origin "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}"
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

cd "${GITHUB_WORKSPACE}/${source}" || exit 1

echo "*** CONFIGURATION ***"
echo -e "PROJECT_FILENAME: ${project_filename}"

# Require github_token
if [[ -z "${GITHUB_TOKEN}" ]]; then
  # shellcheck disable=SC2016
  MESSAGE='Missing env var "github_token: ${{ secrets.GITHUB_TOKEN }}".'
  echo -e "[ERROR] ${MESSAGE}"
  exit 1
fi

# IDEA
# 1: Get the latest git tag
# 2: based on the commit message we bump the version of either patch, minor or major.
# 3: Update the lazarus project/package with the new version
# 4: Commit (amend) the changes back to the repo
# 5: Tag the new commit (from 3) with the updated version (from 1)

#####################
## Step 1: Get the latest git tag
#####################
git fetch --tags
tagFmt="^v?[0-9]+\.[0-9]+\.[0-9]+$"
git_refs=$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)')
matching_tag_refs=$( (grep -E "$tagFmt" <<< "$git_refs") || true)
tag=$(head -n 1 <<< "$matching_tag_refs")
# tag should now contain the latests tag (or empty if there was no tag)

if [ -z "$tag" ]
then
  tag="v1.0.0"
fi

tag_commit=$(git rev-list -n 1 "$tag" || true )
head_commit=$(git rev-parse HEAD)
# skip if there are no new commits for non-pre_release
if [ "$tag_commit" == "$head_commit" ]
then
    echo "No new commits. Skipping..."
    exit 0
fi


#####################
## Step 2: bump the version of either patch, minor or major
#####################
log=$(git log "${tag_commit}".."${head_commit}" --format=%B)
printf "History:\n---\n%s\n---\n" "$log"

case "$log" in
    *"#major"*) new=$(semver -i major "$tag");;
    *"#minor"*) new=$(semver -i minor "$tag");;
    *"#patch"*) new=$(semver -i patch "$tag");;
    *)
        echo "No git commit bump set! Exiting";
        exit 1;;
esac

# Extract major, minor and patch
[[ $new =~ ^.?([0-9]+)\.([0-9]+)\.([0-9]+) ]]
major_version=${BASH_REMATCH[1]}
minor_version=${BASH_REMATCH[2]}
revision_version=${BASH_REMATCH[3]}
build_number="0"


#####################
# Step 3: Update the lazarus project/package with the new version
#####################
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


#####################
# Step 4: Commit (amend) the changes back to the repo
#####################
branch=$(git symbolic-ref --short -q HEAD)
git commit --amend -am "Automatically bumped version: ${new}"


#####################
# Step 5: Tag commit
#####################
git tag -f ${new}
git push --force-with-lease origin ${branch}
