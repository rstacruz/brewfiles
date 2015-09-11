host := $(shell hostname | sed 's/\.local//' | tr A-Z a-z)

update:
	@if ! brew tap | grep rstacruz/backup >/dev/null; then brew tap rstacruz/backup; fi
	@mkdir -p ${host}
	@echo "${host}/"
	@cd ${host} && brew backup
