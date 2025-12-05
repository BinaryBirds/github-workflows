SHELL=/bin/bash

baseUrl = https://raw.githubusercontent.com/BinaryBirds/github-workflows/refs/heads/main/scripts

breakage:
	curl -s $(baseUrl)/check-api-breakage.sh | bash

symlinks:
	curl -s $(baseUrl)/check-broken-symlinks.sh | bash

docc-create:
	curl -s $(baseUrl)/generate-docs.sh | bash

docc-warnings:
	curl -s $(baseUrl)/check-docc-warnings.sh | bash

headers:
	curl -s $(baseUrl)/check-swift-headers.sh | bash

fix-headers:
	curl -s $(baseUrl)/check-swift-headers.sh | bash -s -- --fix 
	
deps:
	curl -s $(baseUrl)/check-local-swift-dependencies.sh | bash

openapi-security:
	curl -s $(baseUrl)/check-openapi-security.sh | bash

openapi-validation:
	curl -s $(baseUrl)/check-openapi-validation.sh | bash

language:
	curl -s $(baseUrl)/check-unacceptable-language.sh | bash

contributors:
	curl -s $(baseUrl)/generate-contributors-list.sh | bash

## params: -v: version string
install-format:
	curl -s $(baseUrl)/install-swift-format.sh | bash

install-openapi:
	curl -s $(baseUrl)/install-swift-openapi-generator.sh | bash

run-clean:
	curl -s $(baseUrl)/run-clean.sh | bash
	
## params: -n: name, -p: port
run-openapi:
	curl -s $(baseUrl)/run-openapi-docker.sh | bash

lint:
	curl -s $(baseUrl)/run-swift-format.sh | bash

format:
	curl -s $(baseUrl)/run-swift-format.sh | bash -s -- --fix 

check: symlinks language deps lint