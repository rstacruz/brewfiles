host := $(shell hostname | sed 's/\.local//' | tr A-Z a-z)

update:
	@mkdir -p ${host}
	@echo "${host}/"
	@cd ${host} && rm Brewfile && brew bundle dump
