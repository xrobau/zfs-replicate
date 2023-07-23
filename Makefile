SHELL=/bin/bash

ANSBIN=/usr/bin/ansible-playbook
ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_HOST_KEY_CHECKING
ANSCMD=$(ANSBIN) --extra-vars "@local/replication.yml" -i local/clients

.PHONY: go
go: setup
	$(ANSCMD) main.yml

.PHONY: clients
clients: setup
	$(ANSCMD) main.yml -l clients

.PHONY: setup
setup: $(ANSBIN) local/ local/id_rsa local/clients local/replication.yml

local/:
	mkdir $@

local/id_rsa:
	ssh-keygen -f $@

local/clients local/replication.yml:
	@echo You need to create $@ - see $@.example for a template
	@exit 1

$(ANSBIN):
	apt-get -y install ansible
