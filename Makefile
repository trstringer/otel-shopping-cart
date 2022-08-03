IMAGE_REPO_ROOT=localhost:5000
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
IMAGE_TAG=latest

MYSQL_ADDRESS=localhost:3307
MYSQL_PORT=3307
MYSQL_HOST=localhost
MYSQL_APP_USER=root
MYSQL_PASSWORD=localmysql123

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
build-images: build-image-cart build-image-users build-image-price build-image-dataseed

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

.PHONY: push-images
push-images:
	docker push $(CART_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(USERS_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(PRICE_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(DATASEED_IMAGE_REPO):$(IMAGE_TAG)

.PHONY: run
run: clean-trace run-local-cart run-local-users run-local-price
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
	MYSQL_PASSWORD=$(MYSQL_PASSWORD) ./dist/cart \
		-p $(CART_PORT) \
		--users-svc-address http://localhost:$(USERS_PORT)/users \
		--price-svc-address http://localhost:$(PRICE_PORT)/price \
		--mysql-address $(MYSQL_ADDRESS) \
		--mysql-user $(MYSQL_APP_USER) \
		&

.PHONY: run-local-users
run-local-users: build-users
	MYSQL_PASSWORD=$(MYSQL_PASSWORD) ./dist/users \
		-p $(USERS_PORT) \
		--mysql-address $(MYSQL_ADDRESS) \
		--mysql-user $(MYSQL_APP_USER) \
		&

.PHONY: run-local-price
run-local-price:
	. ./external/price_server/venv/bin/activate && \
	FLASK_APP=./external/price_server/app.py \
	MYSQL_ADDRESS=$(MYSQL_HOST) \
	MYSQL_PORT=$(MYSQL_PORT) \
	MYSQL_DATABASE="otel_shopping_cart" \
	MYSQL_USER=$(MYSQL_APP_USER) \
	MYSQL_PASSWORD=$(MYSQL_PASSWORD) \
		flask run \
		-p $(PRICE_PORT) \
		&

.PHONY: run-local-gunicorn-price
run-local-gunicorn-price:
	cd ./external/price_server && \
	. venv/bin/activate && \
	MYSQL_ADDRESS=$(MYSQL_HOST) \
	MYSQL_PORT=$(MYSQL_PORT) \
	MYSQL_DATABASE="otel_shopping_cart" \
	MYSQL_USER=$(MYSQL_APP_USER) \
	MYSQL_PASSWORD=$(MYSQL_PASSWORD) \
	gunicorn "app:app"	

.PHONY: debug-local-cart
debug-local-cart:
	MYSQL_PASSWORD=$(MYSQL_PASSWORD) dlv debug ./cmd/cart -- \
		-p $(CART_PORT) \
		--users-svc-address http://localhost:$(USERS_PORT)/users \
		--price-svc-address http://localhost:$(PRICE_PORT)/price \
		--mysql-address $(MYSQL_ADDRESS) \
		--mysql-user $(MYSQL_APP_USER)

.PHONY: debug-local-users
debug-local-users:
	MYSQL_PASSWORD=$(MYSQL_PASSWORD) dlv debug ./cmd/users -- \
		-p $(USERS_PORT) \
		--mysql-address $(MYSQL_ADDRESS) \
		--mysql-user $(MYSQL_APP_USER)

.PHONY: debug-local-price
debug-local-price:
	. ./external/price_server/venv/bin/activate && \
	FLASK_APP=./external/price_server/app.py \
	FLASK_ENV=development \
	MYSQL_ADDRESS=$(MYSQL_HOST) \
	MYSQL_PORT=$(MYSQL_PORT) \
	MYSQL_DATABASE="otel_shopping_cart" \
	MYSQL_USER=$(MYSQL_APP_USER) \
	MYSQL_PASSWORD=$(MYSQL_PASSWORD) \
		flask run \
		-p $(PRICE_PORT) \

.PHONY: clean
clean: kind-clean
	rm -rf ./dist

.PHONY: run-local-database
run-local-database:
	MYSQL_ROOT_PASSWORD=$(MYSQL_PASSWORD) ./scripts/database_run_local.sh

.PHONY: stop-local-database
stop-local-database:
	docker kill otel-shopping-cart-mysql 

.PHONY: deploy
deploy: kind-deploy chart-install

.PHONY: kind-create
kind-create:
	./scripts/kind_with_registry.sh

.PHONY: kind-deploy
kind-deploy: build-images push-images kind-create ingress-create collector-deploy jaeger-deploy

.PHONY: kind-clean
kind-clean:
	kind delete cluster

.PHONY: chart-install
chart-install:
	helm upgrade --install otel-shopping-cart ./chart/otel-shopping-cart

.PHONY: chart-clean
chart-clean:
	helm uninstall otel-shopping-cart

.PHONY: ingress-create
ingress-create:
	kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
	kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Equal","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'

.PHONY: collector-deploy
collector-deploy:
	helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
	helm upgrade -f ./chart/otel-collector/values.yaml --install otel-collector open-telemetry/opentelemetry-collector

.PHONY: collector-clean
collector-clean:
	helm uninstall otel-collector

.PHONY: jaeger-deploy
jaeger-deploy:
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.3/cert-manager.yaml
	@echo Sleeping for 2 minutes while cert manager startup happens
	@echo so that the jaeger install succeeds
	@sleep 120
	kubectl create namespace observability
	kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.36.0/jaeger-operator.yaml -n observability
	@echo Sleeping for 30 seconds while jaeger starts up so that
	@echo the jaeger CR installation succeeds
	@sleep 30
	kubectl create -f ./kubernetes/jaeger.yaml

.PHONY: jaeger-clean
jaeger-clean:
	-kubectl delete -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.36.0/jaeger-operator.yaml -n observability
	-kubectl delete namespace observability
	-kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.3/cert-manager.yaml
