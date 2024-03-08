IMAGE_REPO_ROOT=localhost:5001
CART_PORT=8080
CART_CONTAINER_NAME=otel-shopping-cart-cart
CART_IMAGE_REPO=$(IMAGE_REPO_ROOT)/$(CART_CONTAINER_NAME)
USERS_PORT=8081
USERS_CONTAINER_NAME=otel-shopping-cart-users
USERS_IMAGE_REPO=$(IMAGE_REPO_ROOT)/$(USERS_CONTAINER_NAME)
PRICE_PORT=8082
PRICE_CONTAINER_NAME=otel-shopping-cart-price
PRICE_IMAGE_REPO=$(IMAGE_REPO_ROOT)/$(PRICE_CONTAINER_NAME)
DATASEED_CONTAINER_NAME=otel-shopping-cart-dataseed
DATASEED_IMAGE_REPO=$(IMAGE_REPO_ROOT)/$(DATASEED_CONTAINER_NAME)
DB_CONTAINER_NAME=otel-shopping-cart-postgres
COLLECTOR_CONTAINER_NAME=otel-shopping-cart-collector
COLLECTOR_IMAGE_REPO=$(IMAGE_REPO_ROOT)/$(COLLECTOR_CONTAINER_NAME)
TRAFFICGEN_CONTAINER_NAME=otel-shopping-cart-trafficgen
TRAFFICGEN_IMAGE_REPO=$(IMAGE_REPO_ROOT)/$(TRAFFICGEN_CONTAINER_NAME)
INTERRUPTER_CONTAINER_NAME=otel-shopping-cart-interrupter
INTERRUPTER_IMAGE_REPO=$(IMAGE_REPO_ROOT)/$(INTERRUPTER_CONTAINER_NAME)
IMAGE_TAG=latest

DB_ADDRESS=localhost:5432
DB_PORT=5432
DB_HOST=localhost
DB_APP_USER=shoppingcartuser
DB_PASSWORD=secretdbpassword123

.PHONY: run-local
run-local: kind-create install-tools-local install-app-local

.PHONY: kind-create
kind-create:
	./scripts/kind_with_registry.sh

.PHONY: stop-local
stop-local:
	kind delete cluster

.PHONY: stop-trafficgen
stop-trafficgen:
	kubectl patch deploy trafficgen -p '{"spec": {"replicas": 0}}'

.PHONY: install-tools-local
install-tools-local: install-cert-manager install-jaeger install-kube-prometheus-stack install-opentelemetry-operator install-opentelemetry-collector-local

.PHONY: install-tools
install-tools: install-cert-manager install-jaeger install-kube-prometheus-stack install-opentelemetry-operator install-opentelemetry-collector

.PHONY: install-cert-manager
install-cert-manager:
	./scripts/cert-manager_install.sh

.PHONY: install-jaeger
install-jaeger:
	./scripts/jaeger_install.sh

.PHONY: install-kube-prometheus-stack
install-kube-prometheus-stack:
	./scripts/kube-prometheus-stack_install.sh

.PHONY: install-opentelemetry-operator
install-opentelemetry-operator:
	./scripts/opentelemetry_operator_install.sh

.PHONY: install-opentelemetry-collector-local
install-opentelemetry-collector-local:
	helm upgrade --install otel ./collector/opentelemetry

.PHONY: install-opentelemetry-collector
install-opentelemetry-collector:
	helm upgrade \
		--install \
		--set collector.image.repository=ghcr.io/trstringer/otel-shopping-cart-collector \
		otel \
		./collector/opentelemetry

.PHONY: install-app
install-app:
	helm upgrade \
		--install \
		--set cart.image.repository=ghcr.io/trstringer/otel-shopping-cart-cart \
		--set user.image.repository=ghcr.io/trstringer/otel-shopping-cart-users \
		--set price.image.repository=ghcr.io/trstringer/otel-shopping-cart-price \
		--set db.dataseed.image.repository=ghcr.io/trstringer/otel-shopping-cart-dataseed \
		--set trafficgen.image.repository=ghcr.io/trstringer/otel-shopping-cart-trafficgen \
		--set interrupter.image.repository=ghcr.io/trstringer/otel-shopping-cart-interrupter \
		otel-shopping-cart \
		./charts/otel-shopping-cart

.PHONY: install-app-local
install-app-local: build-images push-images
	helm upgrade --install otel-shopping-cart ./charts/otel-shopping-cart

.PHONY: build-images
build-images: build-collector
	docker build -t $(CART_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.cart .
	docker build -t $(COLLECTOR_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.collector .
	docker build -t $(DATASEED_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.dataseed .
	docker build -t $(INTERRUPTER_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.interrupter .
	docker build -t $(PRICE_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.price .
	docker build -t $(TRAFFICGEN_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.trafficgen .
	docker build -t $(USERS_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.users .

.PHONY: build-collector
build-collector:
	ocb --config ./collector/manifest.yaml

.PHONY: push-images
push-images:
	docker push $(CART_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(USERS_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(PRICE_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(DATASEED_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(COLLECTOR_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(TRAFFICGEN_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(INTERRUPTER_IMAGE_REPO):$(IMAGE_TAG)

.PHONY: port-forward-jaeger
port-forward-jaeger:
	kubectl port-forward svc/jaeger-query 16686
	@echo "Navigate to http://localhost:16686"

.PHONY: port-forward-grafana
port-forward-grafana:
	kubectl port-forward svc/prometheus-grafana 8080:80
	@echo "Navigate to http://localhost:8080"

.PHONY: port-forward-prometheus
port-forward-prometheus:
	kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090
	@echo "Navigate to http://localhost:9090"

.PHONY: e2e
e2e:
	./scripts/e2e.sh

.PHONY: deps
deps:
	./scripts/dependencies.sh

.PHONY: version
version:
	@./scripts/version.py

.PHONY: run-local-database
run-local-database:
	./scripts/database_run_local.sh

.PHONY: stop-local-database
stop-local-database:
	docker kill $(DB_CONTAINER_NAME)
