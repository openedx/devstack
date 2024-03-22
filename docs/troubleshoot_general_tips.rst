Troubleshooting: Common Issues
##############################

.. contents:: Table of Contents

Known Issues
============

File ownership change
---------------------

If you notice that the ownership of some (maybe all) files have changed and you
need to enter your root password when editing a file, you might
have pulled changes to the remote repository from within a container. While running
``git pull``, git changes the owner of the files that you pull to the user that runs
that command. Within a container, that is the root user - so git operations
should be ran outside of the container.

To fix this situation, change the owner back to yourself outside of the container by running:

.. code:: sh

  $ sudo chown <user>:<group> -R .

Running LMS commands within a container
---------------------------------------

Most of the ``paver`` commands require a settings flag. If omitted, the flag defaults to
``devstack``. If you run into issues running ``paver`` commands in a docker container, you should append
the ``devstack_docker`` flag. For example:

.. code:: sh

  $ paver update_assets --settings=devstack_docker

Resource busy or locked
-----------------------

While running ``make static`` within the ecommerce container you could get an error
saying:

.. code:: sh

  Error: Error: EBUSY: resource busy or locked, rmdir '/edx/app/ecommerce/ecommerce/ecommerce/static/build/'

To fix this, remove the directory manually outside of the container and run the command again.

No space left on device
-----------------------

If you see the error ``no space left on device``, Docker has run
out of space in its Docker.qcow2 file.

Here is an example error while running ``make dev.pull.<service>``:

.. code:: sh

   ...
   32d52c166025: Extracting [==================================================>] 1.598 GB/1.598 GB
   ERROR: failed to register layer: Error processing tar file(exit status 1): write /edx/app/edxapp/edx-platform/.git/objects/pack/pack-4ff9873be2ca8ab77d4b0b302249676a37b3cd4b.pack: no space left on device
   make: *** [pull] Error 1

Try this first to clean up dangling images:

.. code:: sh

   make dev.prune  # (This is very safe, so try this first.)

If you are still seeing issues, you can try cleaning up dangling volumes.

1. Bring up all containers.

.. code:: sh

   make dev.up.large-and-slow

2. Remove all unused volumes. **Warning:** this will remove all Docker data on your system that is *not currently in use by a container*, which is why it's important to run the previous step. Otherwise, this will wipe out your Devstack data.

   docker volume prune -f

No such file or directory
-------------------------

While provisioning, some have seen the following error:

.. code:: sh

   ...
   cwd = os.getcwdu()
   OSError: [Errno 2] No such file or directory
   make: *** [dev.provision.services] Error 1

This issue can be worked around, but there's no guaranteed method to do so.
Rebooting and restarting Docker does *not* seem to correct the issue. You can
try the following:

.. code:: sh

   # repeat the following until you get past the error.
   make stop
   make dev.provision.<service>

Memory Limit
------------

While provisioning, some have seen the following error:

.. code:: sh

   ...
   Build failed running pavelib.assets.update_assets: Subprocess return code: 137

This error is an indication that your docker process died during execution.  Most likely,
this error is due to running out of memory.  Try increasing the memory
allocated to Docker (Recommended: 8 CPUs, 10 GB Memory, 2GB Swap).

Docker is using lots of CPU time when it should be idle
-------------------------------------------------------

On the Mac, this often manifests as the ``hyperkit`` process using a high
percentage of available CPU resources.  To identify the container(s)
responsible for the CPU usage:

.. code:: sh

    make dev.stats

Once you've identified a container using too much CPU time, check its logs;
for example:

.. code:: sh

    make dev.logs.lms

The most common culprit is an infinite restart loop where an error during
service startup causes the process to exit, but we've configured
``docker compose`` to immediately try starting it again (so the container will
stay running long enough for you to use a shell to investigate and fix the
problem).  Make sure the set of packages installed in the container matches
what your current code branch expects; you may need to rerun ``pip`` on a
requirements file or pull new container images that already have the required
package versions installed.

Missing git branches
--------------------

When trying to check out a branch, you may see an error like this::

    git checkout jj/REV-666-implement-evil-feature
    > error: pathspec 'jj/REV-666-implement-evil-feature' did not match any file(s) known to git

If you are sure you have (i) recently run ``git fetch`` and (ii) didn't misspell the
branch name, then it is possible your repository is set in "single-branch" mode, meaning
that it is configured to only fetch ``master``. Although devstack currently clones services'
repositories with all their branches, devstacks provisioned before September 2020
will start out with single-branch repositories. You check if your repository is in this
state by running ``git branch -r``. If you only see a couple of entries
(``origin/master`` and ``origin/HEAD``), then your local repository is in single-branch
mode.

You can manually reconfigure your repository to pull all branches by running these
commands from within the repository::

    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin
    git checkout jj/REV-666-implement-evil-feature
    > Switched to branch 'jj/REV-666-implement-evil-feature'.

General git troubleshooting
---------------------------

``git`` is powerful but complex; you may occasionally find your respository in a
confusing state. This problem isn't devstack-specific.

If you find yourself stuck, folks in the edX-internal or Open edX Slack workspaces may
be able to give you a hand.

Alternatively, if you are at a roadblock and
*don't care about any changes you've made to your local copy of the repository*
(i.e., you have pushed or otherwise saved your work elsewhere)
then you can always delete the repository and start over again::

    rm -rf ./<repository>
    git clone git@github.com:openedx/<repository>

Finally, if you regularly find yourself mystified by git, consider reading
through `Understanding Git Conceptually`_. It explains core Git principles in way
that makes it easier to use the simpler ``git`` commands more effectively
and easier to use the more complicated ``git`` commands when you have to.

Problems with shared directories
--------------------------------

If you have problems like shared directories not appearing as shared, or very
slow sync times (up to an hour), it might be due to symlinks.  Be sure that
your actual devstack working directory matches the directory listed in the
Resources - File Sharing section of the Docker preferences.  Using a symlink as
the current directory and sharing the real directory (or vice-versa) may work
erratically.

Missing module
--------------

Occasionally, you'll get errors like 'Cannot import name Name from module xyz'. This usually happens because the code and the image are out of sync. To fix this, first make sure you have the latest images and the latest code. These instructions are written using the LMS as an example. Replace lms with cms, credentials, discovery, etc. as appropriate.

#. Run ``make dev.stop.lms`` from devstack
#. To update your image, you can run ``make dev.pull.lms`` from devstack.
#. To get the latest code, you can run ``git fetch && git pull`` from the head of the code repository. If you are working on a branch, you may need to rebase it onto the latest master or main.
#. From devstack, run ``make dev.up.lms`` and ``make dev.logs.lms``
#. If the import error is still there, run ``make dev.shell.lms`` and then, from within the service container, run ``make requirements``
#. After doing this, it may Just Work or you may need to restart the service with ``make dev.restart-devserver.lms`` (run from devstack)

Missing tables/migrations/fields
--------------------------------
Another error you may get if the code and the image are out of sync is sql or Django ORM errors about missing tables or models not having a certain field. To fix this, make sure you have the latest images and latest code, similar to the steps for Missing Module. Once you have updated the image and code, run ``make dev.migrate.lms`` (or your other service) from devstack to apply the latest migrations. You shouldn't need to restart the webserver or container.

.. _Understanding Git Conceptually: https://www.sbf5.com/~cduan/technical/git/

Demo course is empty in studio
------------------------------
After provisioning and opening Studio, you may see an empty outline for the demo course. This usually means there is a disconnect between the block ids in mySQL and the corresponding data in Mongo.

To fix this locally, simply add a new subsection and publish. The act of publishing should reload the whole course correctly.

See https://github.com/openedx/devstack/issues/1073 for the GitHub issue tracking this bug.

CORS error from login_refresh in MFE
------------------------------------
If you see "Access to XMLHttpRequest at 'http://localhost:18000/login_refresh' from origin 'http://localhost:2000' has been blocked by CORS policy: Request header field x-xsrf-token is not allowed by Access-Control-Allow-Headers in preflight response" it usually means you don't have a valid session.

The fix is to get a new auth session. You can do any of the following:

1. Before navigating to your MFE, go to http://localhost:18000 to restart your logged in http session.
2. Clear your cookies
3. Refresh http://localhost:18000
4. Log in
5. Navigate back to the MFE

Blank login/signup screens
--------------------------
After starting LMS/CMS (and compiling static assets for both), it's possible you run into a blank page when trying to sign in via http://localhost:18000/login. 

This is most likely a cache issue and can be easily fixed in 2 different ways:

1. Hard reloading the page, or
2. Rebuilding the frontend and giving it another try

Missing vendor file node_modules/backbone.paginator/lib/backbone.paginator.js
-----------------------------------------------------------------------------
This message sometimes appears when provisioning. The root cause of this is as yet unknown but the most effective workaround seems to be
to shell into the LMS (``make lms-shell`` in devstack) and run ``npm ci``, followed by ``paver update_assets``.
See `the github issue`_ to follow the work being done on the resolution.

.. _the github issue: https://github.com/openedx/devstack/issues/1072

Past problems (fixed)
=====================

If you see any of the following issues, you'll need to `update your repos and pull the latest images`_.

Permission denied for copying studio-frontend JS & CSS during provisioning
--------------------------------------------------------------------------

During ``make dev.provision``, the edx-platform script ``copy-node-modules.sh`` would fail with the following output, or similar::

    Copying studio-frontend JS & CSS from node_modules into vendor directories...
    + read -r -d '' src_file
    ++ find node_modules/@edx/studio-frontend/dist -type f -print0
    + [[ node_modules/@edx/studio-frontend/dist/accessibilityPolicy.min.css = *.css ]]
    + cp --force node_modules/@edx/studio-frontend/dist/accessibilityPolicy.min.css common/static/common/css/vendor
    cp: cannot remove 'common/static/common/css/vendor/accessibilityPolicy.min.css': Permission denied

This issue was introduced on edx-platform master in July 2023 and was resolved in August 2023 (without becoming part of a named release). See https://github.com/openedx/devstack/issues/1138 for more details, including a workaround for those unable to upgrade their repos or images for some reason.

Cannot find valid pkg-config name
---------------------------------

During ``make requirements`` there would be an error::

    Exception: Cannot find valid pkg-config name.
    Specify MYSQLCLIENT_CFLAGS and MYSQLCLIENT_LDFLAGS env vars manually

This was resolved in July 2023 with https://github.com/openedx/edx-platform/pull/32732.

Cannot run ``make upgrade`` in lms shell due to missing wget
------------------------------------------------------------

``make upgrade`` or ``make compile-requirements`` in lms-shell would produce an error about wget::

    wget -O "requirements/common_constraints.txt" https://raw.githubusercontent.com/edx/edx-lint/master/edx_lint/files/common_constraints.txt
    /bin/sh: 1: wget: not found
    make[1]: *** [Makefile:115: requirements/common_constraints.txt] Error 127

This error was `introduced <https://github.com/openedx/edx-platform/pull/33271>`_ and `resolved <https://github.com/openedx/edx-platform/pull/33288>`_ in September 2023. While this can be solved by updating your devstack, you can also run ``apt update; apt install wget`` from lms-shell to resolve this temporarily.

CSRF errors with MFEs after Django 4.2 upgrade
----------------------------------------------

When using an MFE in devstack, a call to a service fails with 403 Forbidden and these log messages::

   CSRF verification failed. Request aborted.

   Origin checking failed - http://localhost/:{your MFE / service port} does not match any trusted origins.

This may be caused by an upgrade to Django 4.2, which has changes to CSRF checking. The upgrade occurred in early February 2024 in edx-platform, but may occur at other times in IDAs. In edx-platform, this was fixed by `setting CSRF trusted origins in devstack.py <https://github.com/openedx/edx-platform/pull/34192/files>`_.

.. _update your repos and pull the latest images:

Updating Devstack
=================
It may be that the bug you have encountered has already been resolved and you just need to update your devstack. You can do this without losing any of your existing data or having to reprovision, although you will lose your container command history once you pull new images.

To update devstack to the latest images and code:

1. ``make dev.stop`` This will stop all running containers.
2. ``make dev.reset-repos`` This will pull all the latest code into all your devstack service and MFE repos.
3. ``git fetch && git pull`` on the master branch in devstack. This will pull all the latest code into the devstack repo itself.
4. ``make dev.pull.lms`` This will pull the latest lms image and all its dependencies. If you need other services/MFEs, you can replace this with ``make dev.pull.lms+cms+other_service+other_MFE...`` or ``make dev.pull.large-and-slow`` if you really need everything.

Depending on your needs, you may also want to run ``make dev.migrate.lms`` to apply all the latest migrations and/or ``make dev.static.lms`` to recompile static assets.
Like with pulling images, you can also narrow these commands to specific services/MFEs with ``make dev.migrate.lms+cms+...,`` or run  ``make dev.migrate`` and ``make dev.static`` (no suffixes) to include everything.

Running ``make dev.reset`` will do all the above for all services, which can be useful but takes much more time. It will also run a full ``docker system prune -f`` to get rid of unused images and networks.

Manual Upgrades
===============

Sometimes there is a change to devstack that requires existing devstack installations to be manually upgraded. See :doc:`manual_upgrades` for recent cases of this.

Starting From Scratch
=====================

If you think your devstack is broken beyond repair, you can start from scratch using ``make dev.destroy``, followed by the :doc:`getting_started` instructions.

If you want to make absolutely sure that there are no lingering data volumes after the ``dev.destroy`` step, run ``docker volume ls --quiet | grep devstack`` -- if you see surviving devstack volumes that are currently mentioned in docker-compose.yml, there may be a bug. If you can reproduce the issue reliably, consider `reporting an issue <Reporting New Issues_>`_.


Reporting New Issues
====================

Please check the `existing list of known bugs`_ or file `a bug report`_ with any information that could help us debug it.

.. _existing list of known bugs: https://github.com/openedx/devstack/labels/bug
.. _a bug report: https://github.com/openedx/devstack/issues/new?assignees=&labels=bug&projects=&template=Bug-Report.yml&title=%5BBug%5D%3A+
