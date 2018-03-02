host := $(shell hostname | sed 's/\.local//' | tr A-Z a-z)

update:
	@mkdir -p ${host}
	@echo "${host}/"
	if which mas > /dev/null; then mas list > "${host}/mac_app_store.txt"; fi
	cd "${host}" && brew bundle dump --force
	cd "${host}" && ruby ../_tools/bundle-clean.rb
