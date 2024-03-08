# This Makefile serves as the primary command-line interface to interacting with Devstack.

# Almost all targets take the form:
#     make dev.ACTION.SERVICES
# where ACTION could be 'up', 'pull.without-deps', 'attach', and so on,
# and SERVICES is a plus-sign-separated list of services.
# Examples:
#     make dev.attach.credentials
#     make dev.pull.registrar+cms
#     make dev.up.lms
#     make dev.up.without-deps.lms+forum+discovery+mysql80+elasticsearch710+memcached
#     make dev.restart-container.mysql80+lms

# There are also "prefix-form" targets, which are simply an alternate way to spell
# the 'dev.' targets.
# Specifically:
#      make dev.ACTION.SERVICE
# can be spelled as:
#      make SERVICE-ACTION
# For example:
#      make dev.up.registrar
# can be spelled:
#      make registrar-up

# Additionally, this file pulls in default configuration variables from `options.mk`
# as well as local overrides in `options.local.mk`, if present.
# Finally, extra targets from `compatibility.mk` and `local.mk` (if present)
# are pulled into this Makefile.

# Housekeeping Rules:
# * Put new targets under an appropriate header comment.
# * Prefix targets with 'dev.' if and only if they are meant to be part
#   of the general developer interface.
# * Consider adding "prefix-form" versions of new targets
#   for consistency/convenience of interface.
# * Add brief ##-prefixed comments on same line as targets to include them
#   in the `make help` message. Avoid adding descriptions that are overly long,
#   redundant with other targets, or irrelevant to users.

.DEFAULT_GOAL := help

# All devstack targets are "PHONY" in that they do not name actual files.
# Thus, all non-parameterized targets should be added to this declaration.
.PHONY: build-courses \
        create-test-course dev.attach dev.backup dev.cache-programs dev.check \
        dev.check-memory dev.checkout dev.clone dev.clone.https dev.clone.ssh \
        dev.dbshell dev.destroy dev.down dev.drop-db dev.kill dev.logs \
        dev.migrate dev.migrate.lms dev.migrate.cms \
        dev.provision dev.ps dev.pull dev.pull.without-deps \
        dev.reset dev.reset-repos dev.restart-container dev.restart-devserver \
        dev.restart-devserver.forum dev.restore dev.rm-stopped dev.shell \
        dev.shell.credentials dev.shell.discovery \
        dev.shell.ecommerce dev.shell.lms dev.shell.lms_watcher \
        dev.shell.registrar dev.shell.cms \
        dev.shell.cms_watcher dev.shell.xqueue dev.shell.xqueue_consumer \
        dev.static dev.static.lms dev.static.cms dev.stats dev.status \
        dev.stop dev.up dev.up.attach dev.up.shell \
        dev.up.without-deps dev.up.without-deps.shell dev.up.with-programs \
        dev.up.with-watchers dev.validate docs \
        help requirements impl-dev.clone.https impl-dev.clone.ssh impl-dev.provision \
        impl-dev.pull impl-dev.pull.without-deps impl-dev.up impl-dev.up.attach \
        impl-dev.up.without-deps selfcheck upgrade \
        validate-lms-volume vnc-passwords

# Load up options (configurable through options.local.mk).
include options.mk

# The `COMPOSE_FILE` environment variable tells Docker-Compose which YAML
# files to use when `docker-compose` is called without specifying any YAML files.
# These files include definitions of services and volumes.

# Files for use with local volume mounting (default).
COMPOSE_FILE := docker-compose-host.yml
COMPOSE_FILE := $(COMPOSE_FILE):docker-compose-themes.yml
COMPOSE_FILE := $(COMPOSE_FILE):docker-compose-watchers.yml
COMPOSE_FILE := docker-compose.yml:$(COMPOSE_FILE)

# Tell Docker-Compose that the Compose file list uses a colon as the separator.
COMPOSE_PATH_SEPARATOR := :

# All runnable services, separated by plus signs.
ALL_SERVICES := $(EDX_SERVICES)+$(THIRD_PARTY_SERVICES)

# These `*_SERVICES_LIST` variables are equivalent to their `*_SERVICES` counterparts,
# but with spaces for separators instead of plus signs.
EDX_SERVICES_LIST := $(subst +, ,$(EDX_SERVICES))
DB_SERVICES_LIST := $(subst +, ,$(DB_SERVICES))
ASSET_SERVICES_LIST := $(subst +, ,$(ASSET_SERVICES))
DEFAULT_SERVICES_LIST := $(subst +, ,$(DEFAULT_SERVICES))
THIRD_PARTY_SERVICES_LIST := $(subst +, ,$(THIRD_PARTY_SERVICES))
ALL_SERVICES_LIST := $(subst +, ,$(ALL_SERVICES))

# Get information on host operating system via the `uname` command.
OS := $(shell uname)

# Need to run some things under winpty in a Windows git-bash shell
# (but not when calling bash from a command shell or PowerShell).
ifneq (,$(MINGW_PREFIX))
    WINPTY := winpty
else
    WINPTY :=
endif

# Don't try redirecting to /dev/null in any Windows shell
ifneq (,$(findstring MINGW,$(OS)))
    DEVNULL :=
else
    DEVNULL := >/dev/null
endif

# Export Makefile variables to recipe shells.
export

# Include aliases from old Devstack commands to the ones in this Makefile.
# This allows us to evolve and tidy up the Devstack interface without removing support
# for existing scripts and workflows.
include compatibility.mk

# Include local, git-ignored Makefile with additional targets.
-include local.mk  # Prefix with hyphen to tolerate absence of file.


########################################################################################
# Targets for managing the Devstack repo itself.
########################################################################################

# Generates a help message. Borrowed from https://github.com/pydanny/cookiecutter-djangopackage.
help: ## Display this help message.
	@echo "Please use \`make <target>' where <target> is one of"
	@awk -F ':.*?## ' '/^[a-zA-Z]/ && NF==2 {printf "\033[36m  %-28s\033[0m %s\n", $$1, $$2}' Makefile | sort

requirements: ## install development environment requirements
	pip install -r requirements/dev.txt

upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: ## Upgrade requirements with pip-tools.
	pip install -qr requirements/pip-tools.txt
	pip-compile --allow-unsafe --rebuild --upgrade -o requirements/pip.txt requirements/pip.in
	pip-compile --upgrade -o requirements/pip-tools.txt requirements/pip-tools.in
	pip install -qr requirements/pip.txt
	pip install -qr requirements/pip-tools.txt
	pip-compile --upgrade -o requirements/base.txt requirements/base.in
	pip-compile --upgrade -o requirements/doc.txt requirements/doc.in
	pip-compile --upgrade -o requirements/test.txt requirements/test.in
	pip-compile --upgrade -o requirements/dev.txt requirements/dev.in

selfcheck: ## Check that the Makefile is free of Make syntax errors.
	@echo "The Makefile is well-formed."


########################################################################################
# Developer interface: Repository management.
########################################################################################

dev.reset-repos: ## Attempt to reset the local repo checkouts to the default branch working state.
	$(WINPTY) bash ./repo.sh reset

dev.status: ## Prints the status of all git repositories.
	$(WINPTY) bash ./repo.sh status

dev.checkout: ## Check out "openedx-release/$OPENEDX_RELEASE" in each repo if set, use default branch otherwise.
	./repo.sh checkout

dev.clone: dev.clone.ssh ## Clone service repos to the parent directory.

impl-dev.clone.https: ## Clone service repos using HTTPS method to the parent directory.
	./repo.sh clone

dev.clone.https: ## Clone service repos using HTTPS method to the parent directory.
	@scripts/send_metrics.py wrap "$@"

impl-dev.clone.ssh: ## Clone service repos using SSH method to the parent directory.
	./repo.sh clone_ssh

dev.clone.ssh: ## Clone service repos using SSH method to the parent directory.
	@scripts/send_metrics.py wrap "$@"

########################################################################################
# Developer interface: Docker image management.
########################################################################################

dev.prune: ## Prune dangling docker images, containers, and networks. Useful when you get the 'no space left on device' error
	docker system prune -f
	# See also: https://edx.readthedocs.io/projects/open-edx-devstack/en/latest/troubleshoot_general_tips.html#no-space-left-on-device

dev.pull.without-deps: _expects-service-list.dev.pull.without-deps

dev.pull.without-deps.%: ## Pull latest Docker images for specific services.
	@scripts/send_metrics.py wrap "dev.pull.without-deps.$*"

impl-dev.pull.without-deps.%: ## Pull latest Docker images for specific services.
	docker-compose pull $$(echo $* | tr + " ")

dev.pull:
	@scripts/send_metrics.py wrap "$@"

impl-dev.pull:
	@scripts/make_warn_default_large.sh "dev.pull"

dev.pull.large-and-slow: dev.pull.$(DEFAULT_SERVICES) ## Pull latest Docker images required by default services.
	@echo # at least one statement so that dev.pull.% doesn't run too

# Wildcards must be below anything they could match
dev.pull.%: ## Pull latest Docker images for services and their dependencies.
	@scripts/send_metrics.py wrap "dev.pull.$*"

impl-dev.pull.%: ## Pull latest Docker images for services and their dependencies.
	docker-compose pull --include-deps $$(echo $* | tr + " ")

########################################################################################
# Developer interface: Database management.
########################################################################################

impl-dev.provision: ## Provision dev environment with default services, and then stop them.
	make dev.check-memory
	$(WINPTY) bash ./provision.sh $(DEFAULT_SERVICES)
	make dev.stop

dev.provision: ## Provision dev environment with default services, and then stop them.
	@scripts/send_metrics.py wrap "$@"

impl-dev.provision.%: dev.check-memory ## Provision specified services.
	echo $*
	$(WINPTY) bash ./provision.sh $*

dev.provision.%: ## Provision specified services.
	@scripts/send_metrics.py wrap "dev.provision.$*"

dev.mysqldumpall: dev.up.mysql80
	sleep 10 # give the mysql server time to fully start up
	docker-compose exec mysql80 mysqldump --all-databases > .dev/devstackall.sql

dev.mysqlrestoredump: dev.up.mysql80
	sleep 10 # give the mysql server time to fully start up
	docker-compose exec -T mysql80 mysql < .dev/devstackall.sql

 ## Write all data volumes to the host, except for mysql, just use mysqldump
dev.backup: dev.up.mongo+elasticsearch710+opensearch12+coursegraph dev.mysqldumpall
	docker run --rm --volumes-from $$(make --silent --no-print-directory dev.print-container.mongo) -v $$(pwd)/.dev/backups:/backup arm64v8/debian:latest tar zcvf /backup/mongo.tar.gz /data/db
	docker run --rm --volumes-from $$(make --silent --no-print-directory dev.print-container.elasticsearch710) -v $$(pwd)/.dev/backups:/backup arm64v8/debian:latest tar zcvf /backup/elasticsearch710.tar.gz /usr/share/elasticsearch/data
	docker run --rm --volumes-from $$(make --silent --no-print-directory dev.print-container.opensearch12) -v $$(pwd)/.dev/backups:/backup arm64v8/debian:latest tar zcvf /backup/opensearch12.tar.gz /usr/share/opensearch/data
	docker run --rm --volumes-from $$(make --silent --no-print-directory dev.print-container.coursegraph) -v $$(pwd)/.dev/backups:/backup arm64v8/debian:latest tar zcvf /backup/coursegraph.tar.gz /data

 ## Restore all data volumes from the host. WILL OVERWRITE ALL EXISTING DATA!
dev.restore: dev.up.mongo+elasticsearch710+opensearch12+coursegraph dev.mysqlrestoredump
	docker run --rm --volumes-from $$(make --silent --no-print-directory dev.print-container.mongo) -v $$(pwd)/.dev/backups:/backup arm64v8/debian:latest tar zxvf /backup/mongo.tar.gz
	docker run --rm --volumes-from $$(make --silent --no-print-directory dev.print-container.elasticsearch710) -v $$(pwd)/.dev/backups:/backup arm64v8/debian:latest tar zxvf /backup/elasticsearch710.tar.gz
	docker run --rm --volumes-from $$(make --silent --no-print-directory dev.print-container.opensearch12) -v $$(pwd)/.dev/backups:/backup arm64v8/debian:latest tar zxvf /backup/opensearch12.tar.gz
	docker run --rm --volumes-from $$(make --silent --no-print-directory dev.print-container.coursegraph) -v $$(pwd)/.dev/backups:/backup arm64v8/debian:latest tar zxvf /backup/coursegraph.tar.gz

# List of Makefile targets to run database migrations, in the form dev.migrate.$(service)
# Services will only have their migrations added here
# if the service is present in both $(DEFAULT_SERVICES_LIST) and $(DB_SERVICES_LIST).
_db_migration_targets = \
$(foreach db_service,$(DB_SERVICES_LIST),\
	$(if $(filter $(db_service), $(DEFAULT_SERVICES_LIST)),\
		dev.migrate.$(db_service)))

dev.migrate: | $(_db_migration_targets) ## Run migrations for applicable default services.

dev.migrate.cms:
	docker-compose exec cms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform/ && make migrate-cms'

dev.migrate.lms:
	docker-compose exec lms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform/ && make migrate-lms'

dev.migrate.%: ## Run migrations on a service.
	docker-compose exec $* bash -c 'source /edx/app/$*/$*_env && cd /edx/app/$*/$*/ && make migrate'

dev.drop-db: _expects-database.dev.drop-db

dev.drop-db.%: ## Irreversably drop the contents of a MySQL database in each mysql container.
	docker-compose exec -T mysql80 bash -c "mysql --execute=\"DROP DATABASE $*;\""


########################################################################################
# Developer interface: Container management.
########################################################################################

dev.up.attach: _expects-service.dev.up.attach

impl-dev.up.attach.%: ## Bring up a service and its dependencies + and attach to it.
	docker-compose up $*

dev.up.attach.%: ## Bring up a service and its dependencies + and attach to it.
	@scripts/send_metrics.py wrap "dev.up.attach.$*"

dev.up.shell: _expects-service.dev.up.shell

dev.up.shell.%: ## Bring up a service and its dependencies + shell into it.
	make dev.up.$*
	make dev.shell.$*

dev.up.with-programs: dev.up dev.cache-programs ## Bring up default services + cache programs in LMS.

dev.up.with-programs.%: dev.up.$* dev.cache-programs ## Bring up services and their dependencies + cache programs in LMS.

dev.up.with-watchers: dev.up.$(DEFAULT_SERVICES)+lms_watcher+cms_watcher ## Bring up default services + asset watcher containers.

dev.up.with-watchers.%: ## Bring up services and their dependencies + asset watcher containers.
	make dev.up.$*
	make dev.up.lms_watcher+cms_watcher

dev.up.without-deps: _expects-service-list.dev.up.without-deps

impl-dev.up.without-deps.%: dev.check-memory ## Bring up services by themselves.
	docker-compose up -d --no-deps $$(echo $* | tr + " ")

dev.up.without-deps.%: ## Bring up services by themselves.
	@scripts/send_metrics.py wrap "dev.up.without-deps.$*"

dev.up.without-deps.shell: _expects-service.dev.up.without-deps.shell

dev.up.without-deps.shell.%: ## Bring up a service by itself + shell into it.
	make dev.up.without-deps.$*
	make dev.shell.$*

dev.up:
	@scripts/make_warn_default_large.sh "$@"

dev.up.large-and-slow: dev.up.$(DEFAULT_SERVICES) ## Bring up default services.
	@echo # at least one statement so that dev.up.% doesn't run too

impl-dev.up.%: dev.check-memory ## Bring up services and their dependencies.
	docker-compose up -d $$(echo $* | tr + " ")
ifeq ($(ALWAYS_CACHE_PROGRAMS),true)
	make dev.cache-programs
endif

# Wildcards must be below anything they could match
dev.up.%:
	@scripts/send_metrics.py wrap "dev.up.$*"

dev.ps: ## View list of created services and their statuses.
	docker-compose ps

dev.print-container.%: ## Get the ID of the running container for a given service.
	@# Can be run as ``make --silent --no-print-directory dev.print-container.$service`` for just ID.
	@echo $$(docker-compose ps --quiet $*)

dev.restart-container: ## Restart all service containers.
	docker-compose restart $$(echo $* | tr + " ")

dev.restart-container.%: ## Restart specific services' containers.
	docker-compose restart $$(echo $* | tr + " ")

dev.stop: ## Stop all running services.
	docker-compose stop

dev.stop.%: ## Stop specific services.
	docker-compose stop $$(echo $* | tr + " ")

dev.kill: ## Kill all running services.
	docker-compose stop

dev.kill.%: ## Kill specific services.
	docker-compose kill $$(echo $* | tr + " ")

dev.rm-stopped: ## Remove stopped containers. Does not affect running containers.
	docker-compose rm --force

dev.down: ## Documentation for a change to naming
	@echo "dev.down has been renamed to dev.remove-containers. If this doesn't seem like what you were looking for, you probably want to be using dev.stop instead. See docs for more details."

dev.down.%:
	@echo "dev.down has been renamed to dev.remove-containers. If this doesn't seem like what you were looking for, you probably want to be using dev.stop instead. See docs for more details."

dev.remove-containers: ## Stop and remove containers and networks for all services.
	docker-compose down

dev.remove-containers.%: ## Stop and remove containers for specific services.
	docker-compose rm --force --stop $$(echo $* | tr + " ")


########################################################################################
# Developer interface: System queries and checks.
########################################################################################

dev.check-memory: ## Check if enough memory has been allocated to Docker.
	@if [ `docker info --format '{{.MemTotal}}'` -lt 2095771648 ]; then echo "\033[0;31mWarning, System Memory is set too low!!! Increase Docker memory to be at least 2 Gigs\033[0m"; fi || exit 0

dev.stats: ## Get per-container CPU and memory utilization data.
	docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

dev.check: dev.check.$(DEFAULT_SERVICES) ## Run checks for the default service set.

dev.check.%:  # Run checks for a given service or set of services.
	$(WINPTY) bash ./check.sh $*

dev.wait-for.%:  ## Wait for these services to become ready
	$(WINPTY) bash ./wait-ready.sh $$(echo $* | tr + " ")

dev.validate: ## Print effective Docker-Compose config, validating files in COMPOSE_FILE.
	docker-compose config


########################################################################################
# Developer interface: Runtime service management (caching, logs, shells).
########################################################################################

dev.cache-programs: ## Copy programs from Discovery to Memcached for use in LMS.
	$(WINPTY) bash ./programs/provision.sh cache

dev.restart-devserver: _expects-service.dev.restart-devserver

dev.restart-devserver.forum:
	docker-compose exec -T forum bash -c 'kill $$(ps aux | grep "ruby app.rb" | egrep -v "while|grep" | awk "{print \$$2}")'

dev.forum.build-indices: ## Build indices for forum service
	docker-compose exec -T forum bash -c "cd forum && source ruby_env && source devstack_forum_env && cd cs_comments_service/ && bin/rake search:rebuild_indices"

dev.restart-devserver.%: ## Kill an edX service's development server. Watcher should restart it.
	# Applicable to Django services only.
	docker-compose exec -T $* bash -c 'kill $$(ps aux | egrep "manage.py ?\w* runserver" | egrep -v "while|grep" | awk "{print \$$2}")'

dev.logs: ## View logs from running containers.
	docker-compose logs -f

dev.logs.%: ## View the logs of the specified service container.
	docker-compose logs -f --tail=500 $*

dev.attach: _expects-service.dev.attach

dev.attach.%: ## Attach to the specified service container process for debugging & seeing logs.
	docker attach "$$(make --silent --no-print-directory dev.print-container.$*)"

dev.shell: _expects-service.dev.shell

dev.shell.credentials:
	docker-compose exec credentials env TERM=$(TERM) bash -c 'source /edx/app/credentials/credentials_env && cd /edx/app/credentials/credentials && /bin/bash'

dev.shell.discovery:
	docker-compose exec discovery env TERM=$(TERM) bash -c '/bin/bash'

dev.shell.ecommerce:
	docker-compose exec ecommerce env TERM=$(TERM) /bin/bash

dev.shell.registrar:
	docker-compose exec registrar env TERM=$(TERM) /bin/bash

dev.shell.xqueue:
	docker-compose exec xqueue env TERM=$(TERM) /bin/bash

dev.shell.lms:
	docker-compose exec lms env TERM=$(TERM) bash -c '/bin/bash'

dev.shell.lms_watcher:
	docker-compose exec lms_watcher env TERM=$(TERM) bash -c '/bin/bash'

dev.shell.cms:
	docker-compose exec cms env TERM=$(TERM) bash -c '/bin/bash'

dev.shell.cms_watcher:
	docker-compose exec cms_watcher env TERM=$(TERM) bash -c '/bin/bash'

dev.shell.xqueue_consumer:
	docker-compose exec xqueue_consumer env TERM=$(TERM) /bin/bash

dev.shell.analyticsapi:
	docker exec -it edx.devstack.analyticsapi env TERM=$(TERM) bash -c '/bin/bash'

dev.shell.insights:
	docker-compose exec insights env TERM=$(TERM) bash -c 'eval $$(source /edx/app/insights/insights_env; echo PATH="$$PATH";) && /bin/bash'

dev.shell.%: ## Run a shell on the specified service's container.
	docker-compose exec $* /bin/bash

dev.dbshell:
	docker-compose exec mysql80 bash -c "mysql"

DB_NAMES_LIST = credentials discovery ecommerce notes registrar xqueue edxapp edxapp_csmh dashboard analytics-api reports reports_v1
_db_copy8_targets = $(addprefix dev.dbcopy8.,$(DB_NAMES_LIST))
dev.dbcopyall8: ## Clean mysql80 container and copy data from old mysql 5.7 containers into new mysql8 dbs
	$(MAKE) stop
	$(MAKE) dev.remove-containers.mysql80
	docker volume rm devstack_mysql80_data
	$(MAKE) dev.up.mysql57+mysql80
	$(MAKE) dev.wait-for.mysql57+mysql80
	docker-compose exec -T mysql80 mysql -uroot mysql < provision-mysql80.sql
	$(MAKE) $(_db_copy8_targets)
	$(MAKE) stop

dev.dbcopy8.%: ## Copy data from old mysql 5.7 container into a new 8 db
	docker-compose exec mysql57 mysqldump "$*" > .dev/$*.sql
	docker-compose exec -T mysql80 mysql "$*" < .dev/$*.sql
	rm .dev/$*.sql

dev.dbshell.%: ## Run a SQL shell on the given database.
	docker-compose exec mysql80 bash -c "mysql $*"

# List of Makefile targets to run static asset generation, in the form dev.static.$(service)
# Services will only have their asset generation added here
# if the service is present in both $(DEFAULT_SERVICES) and $(ASSET_SERVICES).
_asset_compilation_targets = \
$(foreach asset_service,$(ASSET_SERVICES_LIST),\
	$(if $(filter $(asset_service), $(DEFAULT_SERVICES_LIST)),\
		dev.static.$(asset_service)))

dev.static: | $(_asset_compilation_targets)

dev.static.lms:
	docker-compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform/ && paver update_assets lms'

dev.static.cms:
	docker-compose exec -T cms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform/ && paver update_assets cms'

dev.static.%: ## Rebuild static assets for the specified service's container.
	docker-compose exec -T $* bash -c 'source /edx/app/$*/$*_env && cd /edx/app/$*/$*/ && make static'


########################################################################################
# Developer interface: Commands that do a combination of things.
########################################################################################


dev.reset: dev.remove-containers dev.reset-repos dev.prune dev.pull.large-and-slow dev.up.large-and-slow dev.static dev.migrate ## Attempt to reset the local devstack to the default branch working state without destroying data.

dev.destroy.coursegraph: dev.remove-containers.coursegraph ## Remove all coursegraph data.
	docker volume rm ${COMPOSE_PROJECT_NAME}_coursegraph_data

# See https://github.com/openedx/devstack/issues/1113 for lack of ability to destroy data volumes
dev.destroy: ## Irreversibly remove all devstack-related containers and networks (though not data volumes)
	$(WINPTY) bash ./destroy.sh

########################################################################################
# Support for "prefix-form" commands:
#     $service-$action instead of dev.$action.$services
# For example, the command:
#     make dev.attach.registrar
# can be expressed as:
#     make registrar-attach
# This form may be quicker to type and more amenable to tab-completion.
########################################################################################

# Implementation notes:
# The weird syntax here is a way to generate generic targets from existing generic targets.
# For example:
#     $(addsuffix -migrate, $(DB_SERVICES_LIST))
# Takes the list of all DB-backed services and appends '-migrate', yielding a list like:
#  	  credentials-migrate discovery-migrate ecommerce-migrate ...(and so on)
# Then:
#     : %-migrate: dev.migrate.%
# Tells Make to match against the aforementioned list, and given an occurance like:
#     SERVICE-migrate
# define it as a target with no recipe but with a single prerequisite:
#     dev.migrate.SERVICE
# Effectively, 'SERVICE-migrate' is aliased to 'dev.migrate.SERVICE' for
# all values of SERVICE in $(DB_SERVICES_LIST).

$(addsuffix -pull, $(ALL_SERVICES_LIST)): %-pull: dev.pull.%
$(addsuffix -pull-without-deps, $(ALL_SERVICES_LIST)): %-pull-without-deps: dev.pull.without-deps.%
$(addsuffix -migrate, $(DB_SERVICES_LIST)): %-migrate: dev.migrate.%
$(addsuffix -up, $(ALL_SERVICES_LIST)): %-up: dev.up.%
$(addsuffix -up-attach, $(ALL_SERVICES_LIST)): %-up-attach: dev.up.attach.%
$(addsuffix -up-shell, $(ALL_SERVICES_LIST)): %-up-shell: dev.up.shell.%
$(addsuffix -up-with-programs, $(EDX_SERVICES_LIST)): %-up-with-programs: dev.up.with-programs.%
$(addsuffix -up-with-watchers, $(ALL_SERVICES_LIST)): %-up-with-watchers: dev.up.with-watchers.%
$(addsuffix -up-without-deps, $(ALL_SERVICES_LIST)): %-up-without-deps: dev.up.without-deps.%
$(addsuffix -up-without-deps-shell, $(ALL_SERVICES_LIST)): %-up-without-deps-shell: dev.up.without-deps.shell.%
$(addsuffix -print-container, $(ALL_SERVICES_LIST)): %-print-container: dev.print-container.%
$(addsuffix -restart-container, $(ALL_SERVICES_LIST)): %-restart-container: dev.restart-container.%
$(addsuffix -stop, $(ALL_SERVICES_LIST)): %-stop: dev.stop.%
$(addsuffix -kill, $(ALL_SERVICES_LIST)): %-kill: dev.kill.%
$(addsuffix -down, $(ALL_SERVICES_LIST)): %-down: dev.down.%
$(addsuffix -remove-containers, $(ALL_SERVICES_LIST)): %-remove-containers: dev.remove-containers.%
$(addsuffix -check, $(EDX_SERVICES_LIST)): %-check: dev.check.%
$(addsuffix -restart-devserver, $(EDX_SERVICES_LIST)): %-restart-devserver: dev.restart-devserver.%
$(addsuffix -logs, $(ALL_SERVICES_LIST)): %-logs: dev.logs.%
$(addsuffix -attach, $(ALL_SERVICES_LIST)): %-attach: dev.attach.%
$(addsuffix -shell, $(ALL_SERVICES_LIST)): %-shell: dev.shell.%
$(addsuffix -static, $(ASSET_SERVICES_LIST)): %-static: dev.static.%


########################################################################################
# Helper targets for other targets to use.
########################################################################################

# Many targets allow service(s) to be passed in as a suffix.
# For example, make dev.up.lms` is a more specific form of `make dev.up`.
# For some targets, it is invalid NOT to pass in a service as a suffix.
# For example, `make dev.attach.lms` is valid, but `make dev.attach` is not.
# For such targets, we still want to define the invalid stub target in this Makefile
# for the purpose of including it in command-line completion.
# These _expects-* targets can be used to define those stub targets such that they
# print out something useful. See `dev.attach` for an example usage.

_expects-service.%:
	@echo "'make $*' on its own has no effect."
	@echo "It expects a service as a suffix."
	@echo "For example:"
	@echo "    make $*.lms"

_expects-service-list.%:
	@echo "'make $*' on its own has no effect."
	@echo "It expects one or more services as a suffix, separated by plus signs."
	@echo "For example:"
	@echo "    make $*.lms"
	@echo "Or:"
	@echo "    make $*.registrar+ecommerce+cms"

_expects-database.%:
	@echo "'make $*' on its own has no effect."
	@echo "It expects a database as a suffix."
	@echo "For example:"
	@echo "    make $*.edxapp"


########################################################################################
# Convenient ways to opt in or out of devstack usage metrics reporting
########################################################################################

metrics-opt-in: ## To opt into basic data collection to help improve devstack
	@./scripts/send_metrics.py opt-in

metrics-opt-out: ## To opt out of metrics data collection
	@./scripts/send_metrics.py opt-out


########################################################################################
# Miscellaneous targets.
# These are useful, but don't fit nicely to the greater Devstack interface.
########################################################################################

docs: ## generate Sphinx HTML documentation, including API docs
	tox -e docs

validate-lms-volume: ## Validate that changes to the local workspace are reflected in the LMS container.
	touch $(DEVSTACK_WORKSPACE)/edx-platform/testfile
	docker-compose exec -T lms ls /edx/app/edxapp/edx-platform/testfile
	rm $(DEVSTACK_WORKSPACE)/edx-platform/testfile

vnc-passwords: ## Get the VNC passwords for the Chrome and Firefox Selenium containers.
	@docker-compose logs chrome 2>&1 | grep "VNC password" | tail -1
	@docker-compose logs firefox 2>&1 | grep "VNC password" | tail -1

hadoop-application-logs-%: ## View hadoop logs by application Id.
	docker-compose exec nodemanager yarn logs -applicationId $*

create-test-course: ## Provisions cms, and ecommerce with course(s) in test-course.json.
	$(WINPTY) bash ./course-generator/create-courses.sh --cms --ecommerce course-generator/test-course.json

build-courses: ## Build course and provision cms, and ecommerce with it.
	# Modify test-course.json before running this make target to generate a custom course
	$(WINPTY) bash ./course-generator/build-course-json.sh course-generator/tmp-config.json
	$(WINPTY) bash ./course-generator/create-courses.sh --cms --ecommerce course-generator/tmp-config.json
	rm course-generator/tmp-config.json
