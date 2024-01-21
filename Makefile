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
build-images: build-image-cart build-image-users build-image-price build-image-dataseed build-image-collector build-image-trafficgen build-image-interrupter

.PHONY: build-image-cart
build-image-cart:
	docker build -t $(CART_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.cart .

.PHONY: build-image-users
build-image-users:
	docker build -t $(USERS_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.users .

.PHONY: build-image-price
build-image-price:
	docker build -t $(PRICE_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.price .

.PHONY: build-image-dataseed
build-image-dataseed:
	docker build -t $(DATASEED_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.dataseed .

.PHONY: build-image-trafficgen
build-image-trafficgen:
	docker build -t $(TRAFFICGEN_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.trafficgen .

.PHONY: build-image-interrupter
build-image-interrupter:
	docker build -t $(INTERRUPTER_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.interrupter .

.PHONY: build-image-collector
build-image-collector: collector-custom-build
	docker build -t $(COLLECTOR_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.collector .

.PHONY: push-images
push-images:
	docker push $(CART_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(USERS_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(PRICE_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(DATASEED_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(COLLECTOR_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(TRAFFICGEN_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(INTERRUPTER_IMAGE_REPO):$(IMAGE_TAG)

.PHONY: run
run: run-local-cart run-local-users run-local-price
	@sleep 1
	@echo
	@echo "OTel shopping cart application up and running!"
	@echo "  Cart service (Go) running on localhost:$(CART_PORT)"
	@echo "  Users service (Go) running on localhost:$(USERS_PORT)"
	@echo "  Price service (Python) running on localhost:$(PRICE_PORT)"
	@echo "Run make stop to stop services"

.PHONY: stop
stop:
	-kill $$(pgrep cart)
	-kill $$(pgrep users)
	-kill $$(pgrep flask)

.PHONY: run-local-cart
run-local-cart: build-cart
	DB_PASSWORD=$(DB_PASSWORD) ./dist/cart \
		-p $(CART_PORT) \
		--users-svc-address http://localhost:$(USERS_PORT)/users \
		--price-svc-address http://localhost:$(PRICE_PORT)/price \
		--db-address $(DB_ADDRESS) \
		--db-user $(DB_APP_USER) \
		&

.PHONY: run-local-users
run-local-users: build-users
	DB_PASSWORD=$(DB_PASSWORD) ./dist/users \
		-p $(USERS_PORT) \
		--db-address $(DB_ADDRESS) \
		--db-user $(DB_APP_USER) \
		&

.PHONY: run-local-users-sync
run-local-users-sync: build-users
	HOST_IP=localhost DB_PASSWORD=$(DB_PASSWORD) ./dist/users \
		-p $(USERS_PORT) \
		--db-address $(DB_ADDRESS) \
		--db-user $(DB_APP_USER)

.PHONY: run-local-price
run-local-price:
	. ./external/price_server/venv/bin/activate && \
	FLASK_APP=./external/price_server/app.py \
	DB_ADDRESS=$(DB_HOST) \
	DB_PORT=$(DB_PORT) \
	DB_DATABASE="otel_shopping_cart" \
	DB_USER=$(DB_APP_USER) \
	DB_PASSWORD=$(DB_PASSWORD) \
		flask run \
		-p $(PRICE_PORT) \
		&

.PHONY: run-local-price-sync
run-local-price-sync:
	. ./external/price_server/venv/bin/activate && \
	FLASK_APP=./external/price_server/app.py \
	DB_ADDRESS=$(DB_HOST) \
	DB_PORT=$(DB_PORT) \
	DB_DATABASE="otel_shopping_cart" \
	DB_USER=$(DB_APP_USER) \
	DB_PASSWORD=$(DB_PASSWORD) \
	HOST_IP=127.0.0.1 \
		flask run \
		-p $(PRICE_PORT)

.PHONY: run-local-gunicorn-price
run-local-gunicorn-price:
	cd ./external/price_server && \
	. venv/bin/activate && \
	DB_ADDRESS=$(DB_HOST) \
	DB_PORT=$(DB_PORT) \
	DB_DATABASE="otel_shopping_cart" \
	DB_USER=$(DB_APP_USER) \
	DB_PASSWORD=$(DB_PASSWORD) \
	gunicorn "app:app"

.PHONY: debug-local-cart
debug-local-cart:
	DB_PASSWORD=$(DB_PASSWORD) dlv debug ./cmd/cart -- \
		-p $(CART_PORT) \
		--users-svc-address http://localhost:$(USERS_PORT)/users \
		--price-svc-address http://localhost:$(PRICE_PORT)/price \
		--db-address $(DB_ADDRESS) \
		--db-user $(DB_APP_USER)

.PHONY: debug-local-users
debug-local-users:
	DB_PASSWORD=$(DB_PASSWORD) dlv debug ./cmd/users -- \
		-p $(USERS_PORT) \
		--db-address $(DB_ADDRESS) \
		--db-user $(DB_APP_USER)

.PHONY: debug-local-price
debug-local-price:
	. ./external/price_server/venv/bin/activate && \
	FLASK_APP=./external/price_server/app.py \
	FLASK_ENV=development \
	DB_ADDRESS=$(DB_HOST) \
	DB_PORT=$(DB_PORT) \
	DB_DATABASE="otel_shopping_cart" \
	DB_USER=$(DB_APP_USER) \
	DB_PASSWORD=$(DB_PASSWORD) \
		flask run \
		-p $(PRICE_PORT) \

.PHONY: clean
clean: kind-clean
	rm -rf ./dist
	rm -rf ./collector/dist

.PHONY: run-local-database
run-local-database:
	./scripts/database_run_local.sh

.PHONY: run-local-price-container
run-local-price-container: build-image-price
	docker run \
		--name otel-shopping-cart-price \
		--rm \
		-e DB_ADDRESS=localhost \
		-e DB_PORT=6432 \
		-e DB_DATABASE=otel_shopping_cart \
		-e DB_USER=shoppingcartuser \
		-e DB_PASSWORD=secretdbpassword123 \
		-e HOST_IP=localhost \
		-p 8080:8080 \
		-p 6432:6432 \
		--net host \
		$(PRICE_IMAGE_REPO):$(IMAGE_TAG) -b 0.0.0.0:8080


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

.PHONY: chart-clean
chart-clean:
	helm uninstall otel-shopping-cart

.PHONY: collector-deploy
collector-deploy:
	helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
	helm upgrade -f ./charts/otel-collector/values.yaml --install otel-collector open-telemetry/opentelemetry-collector

.PHONY: collector-clean
collector-clean:
	helm uninstall otel-collector

.PHONY: collector-custom-build
collector-custom-build:
	ocb --config ./collector/manifest.yaml

.PHONY: jaeger-deploy
jaeger-deploy:
	./scripts/jaeger_install.sh

.PHONY: jaeger-clean
jaeger-clean:
	-kubectl delete -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.36.0/jaeger-operator.yaml -n observability
	-kubectl delete namespace observability
	-kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.3/cert-manager.yaml

.PHONY: jaeger-port-forward
jaeger-port-forward:
	kubectl port-forward svc/jaeger-query 16686

.PHONY: trafficgen-stop
trafficgen-stop:
	kubectl patch deploy trafficgen -p '{"spec": {"replicas": 0}}'
