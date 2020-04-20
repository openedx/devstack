# DEFAULT DEVSTACK OPTIONS
# Included into Makefile and exported to command environment.
# Defaults are listed in this file.
# Local git-ignored overrides can be configured by creating `options.local.mk`.
# Variables are set here with ?= to allow for overriding them on the command line.

# Folder in which we looks for repositories.
# Defaults to parent.
DEVSTACK_WORKSPACE ?= $(shell pwd)/..

# Name of Docker Compose project.
# See https://docs.docker.com/compose/reference/envvars/#compose_project_name
# Defaults to 'devstack'.
COMPOSE_PROJECT_NAME ?= devstack

# Whether we should always copy programs to LMS cache upon LMS startup.
# If 'true', then run `make dev.cache-programs` whenever we bring up
# containers.
# Defaults to false.
ALWAYS_CACHE_PROGRAMS ?= false

# Load local overrides to options.
# The dash in front of 'include' makes it so we don't
# fail if the overrides file doesn't exist.
-include options.local.mk
