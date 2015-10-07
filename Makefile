SHELL := /bin/bash  # Use bash syntax

# Settings
# ===

# Default port for the dev server - can be overridden e.g.: "PORT=1234 make run"
ifeq ($(PORT),)
	# ** CHANGE THIS **
	PORT=8099
endif

# Settings
# ===
# ** CHANGE THE PROJECT NAME **
PROJECT_NAME=django-blueprint
APP_IMAGE=${PROJECT_NAME}
SASS_CONTAINER=${PROJECT_NAME}-sass

# Help text
# ===

define HELP_TEXT

${PROJECT_NAME} - A Django website by the Canonical web team
===

Basic usage
---

> make run         # Prepare Docker images and run the Django site

Now browse to http://127.0.0.1:${PORT} to run the site

All commands
---

> make help               # This message
> make run                # build, watch-sass and run-app-image
> make it so              # a fun alias for "make run"
> make build-app-image    # Build the docker image
> make run-app-image      # Use Docker to run the website
> make watch-sass         # Setup the sass watcher, to compile CSS
> make compile-sass       # Setup the sass watcher, to compile CSS
> make stop-sass-watcher  # If the watcher is running in the background, stop it
> make clean              # Delete all created images and containers
> make demo               # Build a demo on ubuntu.qa

(To understand commands in more details, simply read the Makefile)

endef

##
# Print help text
##
help:
	$(info ${HELP_TEXT})

##
# Use docker to run the sass watcher and the website
##
run:
	${MAKE} build-app-image
	${MAKE} watch-sass &
	${MAKE} run-app-image

##
# Build the docker image
##
build-app-image:
	docker build -t ${APP_IMAGE} .

##
# Run the Django site using the docker image
##
run-app-image:
	$(eval docker_ip := `hash boot2docker 2> /dev/null && echo "\`boot2docker ip\`" || echo "127.0.0.1"`)

	@echo ""
	@echo "======================================="
	@echo "Running server on http://${docker_ip}:${PORT}"
	@echo "======================================="
	@echo ""
	docker run -p ${PORT}:5000 -v `pwd`:/app -w=/app ${APP_IMAGE}

##
# Create or start the sass container, to rebuild sass files when there are changes
##
watch-sass:
	$(eval is_running := `docker inspect --format="{{ .State.Running }}" ${SASS_CONTAINER} 2>/dev/null || echo "missing"`)
	@if [[ "${is_running}" == "true" ]]; then docker attach ${SASS_CONTAINER}; fi
	@if [[ "${is_running}" == "false" ]]; then docker start -a ${SASS_CONTAINER}; fi
	@if [[ "${is_running}" == "missing" ]]; then docker run --name ${SASS_CONTAINER} -v `pwd`:/app ubuntudesign/sass sass --debug-info --watch /app/static/css; fi

##
# Force a rebuild of the sass files
##
compile-sass:
	docker run -v `pwd`:/app ubuntudesign/sass sass --debug-info --update /app/static/css --force

##
# If the watcher is running in the background, stop it
##
stop-sass-watcher:
	docker stop ${SASS_CONTAINER}

##
# Re-create the app image (e.g. to update dependencies)
##
rebuild-app-image:
	-docker rmi -f ${APP_IMAGE} 2> /dev/null
	${MAKE} build-app-image

##
# Delete all created images and containers
##
clean:
	@echo "Removing images and containers:"
	@docker rm -f ${SASS_CONTAINER} 2>/dev/null && echo "${SASS_CONTAINER} removed" || echo "Sass container not found: Nothing to do"
	@docker rmi -f ${APP_IMAGE} 2>/dev/null && echo "${APP_IMAGE} removed" || echo "App image not found: Nothing to do"

##
# Build a demo on ubuntu.qa
##
demo:
	${MAKE} build-app-image
	$(eval current_branch := `git rev-parse --abbrev-ref HEAD`)
	$(eval image_location := "ubuntudesign/${APP_IMAGE}:${current_branch}")
	docker tag -f ${APP_IMAGE} ${image_location}
	docker push ${image_location}
	ssh dokku@ubuntu.qa deploy-image ${image_location} ${PROJECT_NAME}-${current_branch}
	@echo ""
	@echo "==="
	@echo "Demo built: http://${PROJECT_NAME}-${current_branch}.ubuntu.qa/"
	@echo "==="
	@echo ""

##
# "make it so" alias for "make run" (thanks @karlwilliams)
##
it:
so: run

# Phony targets (don't correspond to files or directories)
all: help build run run-app-image watch-sass compile-sass stop-sass-watcher rebuild-app-image it so
.PHONY: all
