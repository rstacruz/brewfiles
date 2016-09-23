host := $(shell hostname | sed 's/\.local//' | tr A-Z a-z)

update:
	@mkdir -p ${host}
	@echo "${host}/"
	cd "${host}" && brew bundle dump --force
	cd "${host}" && ruby ../_tools/bundle-clean.rb
