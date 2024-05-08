# Author: Derek Slone-Zhen
# Pre-requs: make, docker, colima (on Mac)
# See `bin/setup-mac.sh` to install and setup a Mac environment

# Disable built-in implicit rules
.SUFFIXES:
MAKEFLAGS = -r -R

# Echo make target? https://stackoverflow.com/a/24901579/1331446
SHELL=/bin/bash
export PS4=[$@]
.SHELLFLAGS += -x -c 'echo -n "[$$0] " && eval "$$@"' $@
# MAKEFLAGS += -s

D_BUILD_OPTS ?= --progress=plain
#--no-cache
DC_BUILD_OPTS ?= --progress=plain
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)
PLATFORM ?= $(shell uname)

ifeq ($(PLATFORM),Darwin)
  COLIMA=.make/colima
else
  COLIMA=@\#
endif

#====================================================================================
# Top level targets
#====================================================================================

.PHONEY: list all clean make-clean clean really-clean co-clean co-fix

list: # List the targets in this Makefile
	@grep -B1 -E '^[a-zA-Z%$$][^:=]+:($$|[^=])' Makefile | sed -E '/^([[:space:]]*|--)$$/d'


# Builds the core docker images and their pre-req services, needed to then launch a `docker compose`
all: $(COLIMA) certs .make/docker/dataiku

# Just clean the "touch" files
make-clean:
	find .make -type f -name .git\* -prune -o -type f -delete

# Low grade clean, but does remove ALL services test data
clean: make-clean
	-docker compose down
	[ ! -d data ] || rm -rf data && mkdir data && chmod -R 0777 data
	-docker buildx prune --force

# Prune docker images and delete `colima` in addition to the "base" clean
really-clean: clean
	docker system prune -f -a
	docker volume prune -f -a
	docker builder prune -f --filter type=exec.cachemount

co-fix:
	-rm -rf ~/.colima/_lima/_networks/user-v2

# Prune docker images and delete `colima` in addition to the "base" clean
co-clean: clean
	$(COLIMA) delete -f


#====================================================================================
# GraphViz & auto-generation of `docker-compose-auto-services.yml`
#====================================================================================

%.svg: %.dot # Build SVG output file from `dot` (Graphviz) file
	dot -Tsvg -o "$@" "$^"

%.png: %.dot # Build PNG output file from `dot` (Graphviz) file
	dot -Tpng -o "$@" "$^"

%.dot: bin/%.dot.sh # Build dot `dot` (Graphviz) file from a script named after it
	./$< > "$@"


#====================================================================================
# colima setup
#====================================================================================

.PHONEY: docker-test

# Target to check colima (docker) env is up and running
.make/colima: ~/.colima/default/docker.sock
	touch "$@"
	@echo 'If subsequent docker commands fail, consider running `make docker-test` to test the colima / docker setup, or deleting `~/.colima/default/docker.sock` eg colima may have terminated ungracefully.'

# Many things in docker / colima will fail if they don't have access to the internet, for which they need the host SSL CA Certificates
~/.docker/certs.d/certs.pem:
	# See: https://github.com/abiosoft/colima/issues/131
	mkdir -p ~/.docker/certs.d
	# From: https://stackoverflow.com/questions/32472337/osx-export-system-certificates-from-keychain-in-pem-format-programmatically
	security find-certificate -a -p > ~/.docker/certs.d/certs.pem

# Sadly, there's no explicit `colima create`; it's created by default if it doesn't exist.
~/.colima/default/colima.yaml:
	colima start --verbose --vm-type=qemu --arch aarch64 --cpu $$((`nproc --all` - 1)) --memory 20 --disk 64
	colima ssh -- sudo sysctl -w user.max_user_namespaces=15000
	colima ssh -- sudo apt-get install -y htop tmux
	docker volume create --name=pgdata

# Other likely options: --vz-rosetta --mount $PWD/data:./:w --kubernetes --profile arm64/edge?
# NB: --vm-type=vz (Apple virtualisation) would not allow 25Gb of memory (overprovisioned)

# If either of the main configurations change, need to restart
~/.colima/default/docker.sock: ~/.docker/certs.d/certs.pem ~/.colima/default/colima.yaml
	colima --verbose stop
	[ ! -f "$@" ] || rm "$@"
	colima --verbose start

# Test target to check docker is now functional
docker-test: .make/colima
	docker run hello-world


#====================================================================================
# Since we can't easily reference docker file outputs, we `touch` an empty file in
# the .make folder as a proxy so we can have `make` do out of date checks.
#====================================================================================

# Build dot file of "docker-compose" dependancies
docker-compose.dot: docker-compose.dot.sh docker-compose*.yml
	"./$<"  > "$@"

# Build `auto-services-configuration.yaml` (docker-compose "include" file) based on folder names in `services` folder
docker-compose-auto-services.yml: docker-compose-auto-services.yml.sh services/*
	"./$<" > "$@"

# This puts certs into the porject space (which colima maps into the docker VM) so that these can then be copied into Docker images as they build
certs/certs.pem: ~/.docker/certs.d/certs.pem
	cp "$<" "$@"


CERT_LIST=$(shell sed -n '/-----BEGIN CERTIFICATE-----/p' certs/certs.pem | awk '{print "certs/cert-" NR ".crt"}')
$(CERT_LIST:crt=pem): certs/certs.pem certs/burst-pem.awk
	cd $(<D) && awk -f burst-pem.awk $(<F)

%.crt: %.pem
	openssl x509 -outform der -in "$<" -out "$@"

.PHONEY: certs

certs: $(CERT_LIST)

# "Fake" (touch) target for building explicit Docker images (from `./docker/*/Dockerfile`)
.make/docker/%: Dockerfile certs $(COLIMA)
	@echo '>> Building $(@F)'
	docker buildx build $(D_BUILD_OPTS) -t "$(@F)" -f "$<" .
	@touch "$@"


# D_BUILD_OPTS=--no-cache make .make/edge-core - may be needed if volume goes bad

# Pull an image needed by docker compose
.make/pull/%:
	tgt=$@ \
	&& img=$${tgt##*/} \
	&& img=$${img//--//} \
	&& docker pull $$img


.PHONEY: run

run: .make/docker/dataiku
	docker run -p 10000:10000 -it dataiku
