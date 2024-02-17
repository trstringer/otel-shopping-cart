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

.PHONY: build
build: build-cart build-users

.PHONY: build-cart
build-cart:
	mkdir -p ./dist
	go build -o ./dist/cart ./cmd/cart

.PHONY: build-users
build-users:
	mkdir -p ./dist
	go build -o ./dist/users ./cmd/users

.PHONY: build-images
build-images:
	docker build -t $(CART_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.cart .
	docker build -t $(COLLECTOR_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.collector .
	docker build -t $(DATASEED_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.dataseed .
	docker build -t $(INTERRUPTER_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.interrupter .
	docker build -t $(PRICE_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.price .
	docker build -t $(TRAFFICGEN_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.trafficgen .
	docker build -t $(USERS_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.users .

.PHONY: push-images
push-images:
	docker push $(CART_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(USERS_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(PRICE_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(DATASEED_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(COLLECTOR_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(TRAFFICGEN_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(INTERRUPTER_IMAGE_REPO):$(IMAGE_TAG)

.PHONY: clean
clean: kind-clean
	rm -rf ./dist
	rm -rf ./collector/dist

.PHONY: run-local-database
run-local-database:
	./scripts/database_run_local.sh

.PHONY: stop-local-database
stop-local-database:
	docker kill $(DB_CONTAINER_NAME)

.PHONY: deploy
deploy: kind-deploy chart-install

.PHONY: kind-create
kind-create:
	./scripts/kind_with_registry.sh

.PHONY: kind-deploy
kind-deploy: build-images push-images kind-create jaeger-deploy

.PHONY: kind-clean
kind-clean:
	kind delete cluster

.PHONY: chart-install
chart-install:
	helm upgrade --install otel-shopping-cart ./charts/otel-shopping-cart

.PHONY: collector-custom-build
collector-custom-build:
	ocb --config ./collector/manifest.yaml

.PHONY: jaeger-deploy
jaeger-deploy:
	./scripts/jaeger_install.sh

.PHONY: jaeger-port-forward
jaeger-port-forward:
	kubectl port-forward svc/jaeger-query 16686

.PHONY: trafficgen-stop
trafficgen-stop:
	kubectl patch deploy trafficgen -p '{"spec": {"replicas": 0}}'

.PHONY: e2e
e2e:
	./scripts/e2e.sh

.PHONY: deps
deps:
	./scripts/dependencies.sh
