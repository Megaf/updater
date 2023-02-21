#!/bin/bash

# updater-skeleton.sh
# Date: 21 Feb 2023
# Author: Megaf - mmegaf [at] (gmail [dot] com) - https://github.com/Megaf
# Licence: GPL v3.0
#
# This script basically copies a specific folder from one repo
# and pushes it to another repo. This file is a template you can use.
#

# NOTICE: To run this you need to have git SSH and GPG settings set up.

# Source Repository and Aircraft Settings.
aircraft_path="FOLDER/AIRCRAFT_MODEL" # Aircraft Path relative to the git repository.
source_git_url="git@github.com:/REPOSITORY.git" # Reoplace with source repo.
source_git_branch="BRANCH" # Replace with desired branch from source repo.

# Destination Repository Settings.
dest_git_url="git@github.com:USER/AIRCRAFT_MODEL.git" # Repo where single aircraft model should be pushed to.
dest_git_branch="BRANCH" # Branch for that repo.

# General Settings.
base_dir="${HOME}" # Where the directory below is located, is it your home? USB stick?
local_dir="${base_dir}/Downloads" # Where do you want the stuff to be downloaded to.
sleep_time="1h" # Time between updates.


# DO NOT EDIT ANYTHING BELOW THIS!
source_git_dir="${local_dir}/$(echo "${source_git_url}" | cut -d "/" -f 2 | cut -d ";" -f 1)"
aircraft_dir="${source_git_dir}/${aircraft_path}"
dest_git_dir="${local_dir}/$(echo "${dest_git_url}" | cut -d "/" -f 2 | cut -d ";" -f 1)"
git_jobs="$(nproc)"


updated_sum() {
  md5sum "${source_git_dir}/.git/FETCH_HEAD" | cut -d " " -f 1
}

source_head() {
  cat "${source_git_dir}/.git/ORIG_HEAD"
}

if [ -d "${source_git_dir}" ]; then
  source_git_md5sum="$(updated_sum)"
  echo "OLD SUM WAS FOUND, SET TO [ ${source_git_md5sum} ]."
else
  source_git_md5sum="Not_Found"
  echo "OLD SUM NOT FOUND, SET TO [ ${source_git_md5sum} ]."
fi

# By the dafault the script only do shallow clones,
# remove "--depth=1 --single-branch" for full clones.
git_clone() {
  echo "CLONING [ ${2} ] branch [ ${1} ]."
  git clone --depth=1 --single-branch -j "${git_jobs}" -b "$1" "$2" "$3"
}

git_update() {
  echo "UPDATING [ ${2} ] branch [ ${1} ]."
  git reset --hard
  git pull -j "${git_jobs}"
  git checkout "$1"
  git pull -j "${git_jobs}"
}

generate_header() {
  echo "${1};$(date -u)" >> "${dest_git_dir}/COMMIT_HISTORY.txt"
  echo "${1}" > "${dest_git_dir}/LAST_COMMIT.txt"
}

copy_aircraft() {
  echo "COPYING ${aircraft_dir} to ${dest_git_dir}"
  rsync -a --delete --exclude ".git" --progress "${aircraft_dir}/" "${dest_git_dir}" || exit 1
  generate_header "$1"
  echo "COPY COMPLETED! :D"
}

git_push() {
  echo "PUSHING CHANGES TO [ ${dest_git_url} ]."
  cd "${dest_git_dir}" || exit 1
  git add * || exit 1
  git commit -a -S -m "Synced $(source_head)."
  git push
  echo "PUSH COMPLETED! :D"
}

while true; do
  mkdir -p "${local_dir}" || exit 1
  if [ ! -d "${dest_git_dir}" ]; then
    git_clone "${dest_git_branch}" "${dest_git_url}" "${dest_git_dir}"
  else
    cd "${dest_git_dir}" || exit 1
    git_update "${dest_git_branch}" "${dest_git_dir}"
  fi

  if [ ! -d "${source_git_dir}" ]; then
    git_clone "${source_git_branch}" "${source_git_url}" "${source_git_dir}"
  else
    old_sum="${source_git_md5sum}"
    echo "OLD SUM BEFORE GIT UPDATE WAS [ ${old_sum} ]."
    cd "${source_git_dir}" || exit 1
    git_update "${source_git_branch}" "${source_git_dir}"
  fi

  new_sum="$(updated_sum)"
  last_commit="$(cat "${dest_git_dir}"/LAST_COMMIT.txt)"
  echo "NEW SUM AFTER GIT UPDATE IS [ ${new_sum} ]."
  if [[  "${old_sum}" != "${new_sum}" ]] || [[ "${last_commit}" != "$(source_head)" ]]; then
    echo "SUMS ARE DIFFERENT, UPDATING REPOSITORY."
    copy_aircraft "$(source_head)"
    git_push
    echo "SLEEPING FOR [ ${sleep_time} ]"
  else
    echo "THEY ARE IDENTICAL, NO NEED FOR UPDATES."
    echo "SLEEPING FOR [ ${sleep_time} ]"
  fi
  sleep "${sleep_time}"
done

