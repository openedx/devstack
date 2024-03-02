#!/usr/bin/env bash

set -e
set -o pipefail

# Script for Git repos housing edX services. These repos are mounted as
# data volumes into their corresponding Docker containers to facilitate development.
# Repos are cloned to/removed from the directory above the one housing this file.

if [ -z "$DEVSTACK_WORKSPACE" ]; then
    echo "need to set workspace dir"
    exit 1
elif [ -d "$DEVSTACK_WORKSPACE" ]; then
    cd "$DEVSTACK_WORKSPACE"
else
    echo "Workspace directory $DEVSTACK_WORKSPACE doesn't exist"
    exit 1
fi

# When you add new services should add them to both repos and ssh_repos
# (or non_release_repos and non_release_ssh_repos if they are not part
# of Open edX releases).
repos=(
    "https://github.com/openedx/course-discovery.git"
    "https://github.com/openedx/credentials.git"
    "https://github.com/openedx/cs_comments_service.git"
    "https://github.com/openedx/ecommerce.git"
    "https://github.com/openedx/edx-notes-api.git"
    "https://github.com/openedx/edx-platform.git"
    "https://github.com/openedx/xqueue.git"
    "https://github.com/openedx/edx-analytics-dashboard.git"
    "https://github.com/openedx/frontend-app-gradebook.git"
    "https://github.com/openedx/frontend-app-learner-dashboard"
    "https://github.com/openedx/frontend-app-learner-record"
    "https://github.com/openedx/frontend-app-payment.git"
    "https://github.com/openedx/frontend-app-publisher.git"
    "https://github.com/openedx/edx-analytics-dashboard.git"
    "https://github.com/openedx/edx-analytics-data-api.git"
)

non_release_repos=(
    "https://github.com/openedx/frontend-app-authn.git"
    "https://github.com/openedx/frontend-app-course-authoring.git"
    "https://github.com/openedx/frontend-app-learning.git"
    "https://github.com/openedx/frontend-app-library-authoring.git"
    "https://github.com/openedx/registrar.git"
    "https://github.com/openedx/frontend-app-program-console.git"
    "https://github.com/openedx/frontend-app-account.git"
    "https://github.com/openedx/frontend-app-profile.git"
    "https://github.com/openedx/frontend-app-ora-grading.git"
)

ssh_repos=(
    "git@github.com:openedx/course-discovery.git"
    "git@github.com:openedx/credentials.git"
    "git@github.com:openedx/cs_comments_service.git"
    "git@github.com:openedx/ecommerce.git"
    "git@github.com:openedx/edx-notes-api.git"
    "git@github.com:openedx/edx-platform.git"
    "git@github.com:openedx/xqueue.git"
    "git@github.com:openedx/edx-analytics-dashboard.git"
    "git@github.com:openedx/frontend-app-gradebook.git"
    "git@github.com:openedx/frontend-app-learner-dashboard.git"
    "git@github.com:openedx/frontend-app-learner-record.git"
    "git@github.com:openedx/frontend-app-payment.git"
    "git@github.com:openedx/frontend-app-publisher.git"
    "git@github.com:openedx/edx-analytics-dashboard.git"
    "git@github.com:openedx/edx-analytics-data-api.git"
)

non_release_ssh_repos=(
    "git@github.com:openedx/frontend-app-authn.git"
    "git@github.com:openedx/frontend-app-course-authoring.git"
    "git@github.com:openedx/frontend-app-learning.git"
    "git@github.com:openedx/frontend-app-library-authoring.git"
    "git@github.com:openedx/registrar.git"
    "git@github.com:openedx/frontend-app-program-console.git"
    "git@github.com:openedx/frontend-app-account.git"
    "git@github.com:openedx/frontend-app-profile.git"
    "git@github.com:openedx/frontend-app-ora-grading.git"
)
# Space separated list of repos that use 2u specific branch should be
# set in your environment. example:
# export TWOU_MAIN_REPOS="ecommerce yourownrepo"
#
# If TWOU_MAIN_REPOS is set in the env, then TWOU_CHECKOUT_BRANCH must
# also be set. Here is an example of how to update your bashrc
# file, so that you can get these variables created (note, TWOU_MAIN_REPOS
# likely will grow over time, and not just use ecommerce'):
# $ echo -e "\nexport TWOU_CHECKOUT_BRANCH=\"2u/main\"\nexport TWOU_MAIN_REPOS=\"ecommerce yourownrepo\"" >> ~/.bash_profile

if [ -n "${OPENEDX_RELEASE}" ]; then
    OPENEDX_GIT_BRANCH=open-release/${OPENEDX_RELEASE}
else
    repos+=("${non_release_repos[@]}")
    ssh_repos+=("${non_release_ssh_repos[@]}")
fi

name_pattern=".*/(.*).git"

_checkout ()
{
    repos_to_checkout=("$@")

    for repo in "${repos_to_checkout[@]}"
    do
        # Use Bash's regex match operator to capture the name of the repo.
        # Results of the match are saved to an array called $BASH_REMATCH.
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[1]}"

        # If a directory exists and it is nonempty, assume the repo has been cloned.
        if [ -d "$name" ] && [ -n "$(ls -A "$name" 2>/dev/null)" ]; then
            cd "$name"
            _checkout_and_update_branch
            cd ..
        fi
    done
}

checkout ()
{
    _checkout "${repos[@]}"
}

_clone ()
{

    repos_to_clone=("$@")
    for repo in "${repos_to_clone[@]}"
    do
        # Use Bash's regex match operator to capture the name of the repo.
        # Results of the match are saved to an array called $BASH_REMATCH.
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[1]}"

        # If a directory exists and it is nonempty, assume the repo has been checked out
        # and only make sure it's on the required branch
        if [ -d "$name" ] && [ -n "$(ls -A "$name" 2>/dev/null)" ]; then
            if [ ! -d "$name/.git" ]; then
                printf "ERROR: [%s] exists but is not a git repo.\n" "$name"
                exit 1
            fi
            printf "The [%s] repo is already checked out. Checking for updates.\n" "$name"
            cd "${DEVSTACK_WORKSPACE}/${name}"
            _checkout_and_update_branch
            cd ..
        else
            if [ -n "${TWOU_CHECKOUT_BRANCH}" ] && echo "${TWOU_MAIN_REPOS}" | grep -o "${name}"; then
                CLONE_BRANCH="-b ${TWOU_CHECKOUT_BRANCH}"
            elif [ -n "${OPENEDX_GIT_BRANCH:-}" ]; then
                CLONE_BRANCH="-b ${OPENEDX_GIT_BRANCH}"
            else
                CLONE_BRANCH=""
            fi

            if [ "${SHALLOW_CLONE}" == "1" ]; then
                git clone ${CLONE_BRANCH} -c core.symlinks=true --depth=1 "${repo}"
            else
                git clone ${CLONE_BRANCH} -c core.symlinks=true "${repo}"
            fi
        fi
    done
    cd - &> /dev/null
}

_checkout_and_update_branch ()
{
    GIT_SYMBOLIC_REF="$(git symbolic-ref HEAD 2>/dev/null)"
    BRANCH_NAME=${GIT_SYMBOLIC_REF##refs/heads/}

    if [ -n "${TWOU_CHECKOUT_BRANCH}" ] && echo "${TWOU_MAIN_REPOS}" | grep -o "${name}"; then
        CHECKOUT_BRANCH="${TWOU_CHECKOUT_BRANCH}"
    elif [ -n "${OPENEDX_GIT_BRANCH}" ]; then
        CHECKOUT_BRANCH=${OPENEDX_GIT_BRANCH}
    else
        CHECKOUT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    fi

    echo "Checking out branch ${CHECKOUT_BRANCH}"
    if [ "${BRANCH_NAME}" == "${CHECKOUT_BRANCH}" ]; then
        git pull origin ${CHECKOUT_BRANCH}
    else
        git fetch origin ${CHECKOUT_BRANCH}:${CHECKOUT_BRANCH}
        git checkout ${CHECKOUT_BRANCH}
    fi
    find . -name '*.pyc' -not -path './.git/*' -delete
}

clone ()
{
    _clone "${repos[@]}"
}

clone_ssh ()
{
    _clone "${ssh_repos[@]}"
}

reset ()
{
    read -p "This will switch to the default branch and pull changes in your local git checkouts. Would you like to proceed? [y/n] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelling."
        exit 1
    fi

    for repo in ${repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[1]}"

        if [ -d "$name" ]; then
            DEFAULT_BRANCH=$(cd ${name}; git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
            # Try to switch branch and pull, but fail if there are uncommitted changes.
            if (cd "$name"; git checkout -q ${DEFAULT_BRANCH} && git pull -q --ff-only);
            then
                # Echo untracked files to simplify debugging and make it easier to see that resetting does not remove everything
                untracked_files="$(cd ${name} && git ls-files --others --exclude-standard)"
                if [[ $untracked_files ]];
                then
                    echo "The following untracked files are in ${name} repository:"
                    echo "$untracked_files"
                fi
            else
                echo >&2 "Failed to reset $name repo. Exiting."
                echo >&2 "Please go to the repo and clean up any issues that are keeping 'git checkout $DEFAULT_BRANCH' and 'git pull' from working."
                exit 1
            fi
        else
            printf "The [%s] repo is not cloned. Skipping.\n" "$name"
        fi
    done
}

status ()
{
    currDir=$(pwd)
    for repo in ${repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        name="${BASH_REMATCH[1]}"

        if [ -d "$name" ]; then
            printf "\nGit status for [%s]:\n" "$name"
            cd "$name";git status;cd "$currDir"
        else
            printf "The [%s] repo is not cloned. Skipping.\n" "$name"
        fi
    done
    cd - &> /dev/null
}

if [ "$1" == "checkout" ]; then
    checkout
elif [ "$1" == "clone" ]; then
    clone
elif [ "$1" == "clone_ssh" ]; then
    clone_ssh
elif [ "$1" == "reset" ]; then
    reset
elif [ "$1" == "status" ]; then
    status
fi
