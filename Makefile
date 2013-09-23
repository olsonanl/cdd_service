TOP_DIR = ../..

include $(TOP_DIR)/tools/Makefile.common

DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment
SERVICE_SPEC = ConservedDomainSearch.spec
SERVICE_NAME = ConservedDomainSearch
SERVICE_PORT = 7056
SERVICE_URL = http://10.0.16.184:$(SERVICE_PORT)

SERVICE_DIR = conserved_domain_search
SERVICE_SUBDIRS = webroot bin

SRC_SERVICE_PERL = $(wildcard service-scripts/*.pl)
BIN_SERVICE_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_SERVICE_PERL))))
DEPLOY_SERVICE_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(SRC_SERVICE_PERL))))

STARMAN_WORKERS = 8
STARMAN_MAX_REQUESTS = 100

TPAGE_ARGS = --define kb_top=$(TARGET) --define kb_runtime=$(DEPLOY_RUNTIME) --define kb_service_name=$(SERVICE_NAME) \
	--define kb_service_port=$(SERVICE_PORT) --define kb_service_dir=$(SERVICE_DIR) \
	--define kb_sphinx_port=$(SPHINX_PORT) --define kb_sphinx_host=$(SPHINX_HOST) \
	--define kb_psgi=$(SERVICE_NAME).psgi \
	--define kb_starman_workers=$(STARMAN_WORKERS) \
	--define kb_starman_max_requests=$(STARMAN_MAX_REQUESTS)

default: bin

bin: $(BIN_PERL)
#bin: build-libs $(BIN_PERL)

# Test Section

test: test-client test-scripts test-service
	@echo "running client and script tests"

test-client:
	# run each test
	for t in $(CLIENT_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

test-scripts:
	# run each test
	for t in $(SCRIPT_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

test-service:
	# run each test
	for t in $(SERVER_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

deploy: deploy-client deploy-service

deploy-all: deploy-client deploy-service

deploy-client: deploy-libs deploy-scripts deploy-docs

deploy-service: deploy-libs deploy-dir deploy-service-scripts
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERVICE_DIR)/start_service
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERVICE_DIR)/stop_service
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/stop_service

deploy-service-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib ; \
	export KB_DEPLOYMENT_CONFIG=$(TARGET)/deployment.cfg; \
	export WRAP_VARIABLES=KB_DEPLOYMENT_CONFIG; \
	for src in $(SRC_SERVICE_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/services/$(SERVICE_DIR)/bin/$$base ; \
	done

deploy-dir:
	if [ ! -d $(TARGET)/services/$(SERVICE_DIR) ] ; then mkdir $(TARGET)/services/$(SERVICE_DIR) ; fi
	if [ "$(SERVICE_SUBDIRS)" != "" ] ; then \
		for dir in $(SERVICE_SUBDIRS) ; do \
		    	if [ ! -d $(TARGET)/services/$(SERVICE_DIR)/$$dir ] ; then mkdir -p $(TARGET)/services/$(SERVICE_DIR)/$$dir ; fi \
		done;  \
	fi

deploy-docs: build-docs
	-mkdir -p $(TARGET)/services/$(SERVICE_NAME)/webroot/.
	cp docs/*.html $(TARGET)/services/$(SERVICE_NAME)/webroot/.

build-docs: compile-docs
	-mkdir -p docs
	pod2html --infile=lib/Bio/KBase/$(SERVICE_NAME)/Client.pm --outfile=docs/$(SERVICE_NAME).html

compile-docs: build-libs

build-libs: Makefile
	compile_typespec \
		--psgi $(SERVICE_NAME).psgi \
		--impl Bio::KBase::$(SERVICE_NAME)::$(SERVICE_NAME)Impl \
		--service Bio::KBase::$(SERVICE_NAME)::Service \
		--client Bio::KBase::$(SERVICE_NAME)::Client \
		--py biokbase/$(SERVICE_NAME)/Client \
		--js javascript/$(SERVICE_NAME)/Client \
		--scripts scripts \
		--url $(SERVICE_URL) \
		$(SERVICE_SPEC) lib

include $(TOP_DIR)/tools/Makefile.common.rules

