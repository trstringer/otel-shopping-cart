IMAGE_REPO_ROOT=localhost:5000
CART_PORT=8080
CART_IMAGE_REPO=$(IMAGE_REPO_ROOT)/otel-shopping-cart-cart
CART_CONTAINER_NAME=otel-shopping-cart-cart
USERS_PORT=8081
USERS_IMAGE_REPO=$(IMAGE_REPO_ROOT)/otel-shopping-cart-users
USERS_CONTAINER_NAME=otel-shopping-cart-users
PRICE_PORT=8082
PRICE_IMAGE_REPO=$(IMAGE_REPO_ROOT)/otel-shopping-cart-price
PRICE_CONTAINER_NAME=otel-shopping-cart-price
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
build-images: build-image-cart build-image-users build-image-price

.PHONY: build-image-cart
build-image-cart:
	docker build -t $(CART_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.cart .

.PHONY: build-image-users
build-image-users:
	docker build -t $(USERS_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.users .

.PHONY: build-image-price
build-image-price:
	docker build -t $(PRICE_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.price .

.PHONY: push-images
push-images:
	docker push $(CART_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(USERS_IMAGE_REPO):$(IMAGE_TAG)
	docker push $(PRICE_IMAGE_REPO):$(IMAGE_TAG)

.PHONY: clean-trace
clean-trace:
	rm -f trace*.json

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

.PHONY: stop-containers
stop-containers:
	docker kill $(CART_CONTAINER_NAME) $(USERS_CONTAINER_NAME) $(PRICE_CONTAINER_NAME)

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

.PHONY: run-container-cart
run-container-cart: build-image-cart
	docker run \
		-d \
		--rm \
		--name $(CART_CONTAINER_NAME) \
		-p $(CART_PORT):$(CART_PORT) \
		$(CART_IMAGE_REPO):$(IMAGE_TAG) \
		-p $(CART_PORT) \
		--users-svc-address http://localhost:$(USERS_PORT)/users \
		--price-svc-address http://localhost:$(PRICE_PORT)/price
	@echo
	@echo "Cart service running on localhost:$(CART_PORT)"

.PHONY: run-container-users
run-container-users: build-image-users
	docker run \
		-d \
		--rm \
		--name $(USERS_CONTAINER_NAME) \
		-p $(USERS_PORT):$(USERS_PORT) \
		$(USERS_IMAGE_REPO):$(IMAGE_TAG) \
		-p $(USERS_PORT)
	@echo
	@echo "Users service running on localhost:$(USERS_PORT)"

.PHONY: run-container-price
run-container-price: build-image-price
	MYSQL_ADDRESS=$(MYSQL_HOST) \
	MYSQL_PORT=$(MYSQL_PORT) \
	MYSQL_DATABASE="otel_shopping_cart" \
	MYSQL_USER=$(MYSQL_APP_USER) \
	MYSQL_PASSWORD=$(MYSQL_PASSWORD) \
	docker run \
		-d \
		--env MYSQL_ADDRESS \
		--env MYSQL_PORT \
		--env MYSQL_DATABASE \
		--env MYSQL_USER \
		--env MYSQL_PASSWORD \
		--name $(PRICE_CONTAINER_NAME) \
		-p $(PRICE_PORT):$(PRICE_PORT) \
		$(PRICE_IMAGE_REPO):$(IMAGE_TAG) \
		-b 0.0.0.0:$(PRICE_PORT)

.PHONY: clean
clean:
	rm -rf ./dist
	docker rmi $(CART_IMAGE_REPO):$(IMAGE_TAG)
	docker rmi $(USERS_IMAGE_REPO):$(IMAGE_TAG)

.PHONY: run-local-database
run-local-database:
	MYSQL_ROOT_PASSWORD=$(MYSQL_PASSWORD) ./scripts/database_run_local.sh

.PHONY: stop-local-database
stop-local-database:
	docker kill otel-shopping-cart-mysql 

.PHONY: kind-create
kind-create:
	./scripts/kind_with_registry.sh

.PHONY: kind-deploy
kind-deploy: build-images push-images kind-create

.PHONY: kind-clean
kind-clean:
	kind delete cluster

.PHONY: chart-install
chart-install:
	helm dependency build ./chart/otel-shopping-cart
	helm upgrade --install otel-shopping-cart ./chart/otel-shopping-cart

.PHONY: chart-clean
chart-clean:
	helm uninstall otel-shopping-cart
