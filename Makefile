CART_PORT=8080
CART_IMAGE_REPO=ghcr.io/trstringer/otel-shopping-cart-cart
CART_CONTAINER_NAME=otel-shopping-cart-cart
USERS_PORT=8081
USERS_IMAGE_REPO=ghcr.io/trstringer/otel-shopping-cart-users
USERS_CONTAINER_NAME=otel-shopping-cart-users
PRICE_PORT=8082
PRICE_IMAGE_REPO=ghcr.io/trstringer/otel-shopping-cart-price
PRICE_CONTAINER_NAME=otel-shopping-cart-price
IMAGE_TAG=latest

MYSQL_ADDRESS=localhost:3307
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
build-images: build-image-cart build-image-users

.PHONY: build-image-cart
build-image-cart:
	docker build -t $(CART_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.cart .

.PHONY: build-image-users
build-image-users:
	docker build -t $(USERS_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.users .

.PHONY: build-image-price
build-image-price:
	docker build -t $(PRICE_IMAGE_REPO):$(IMAGE_TAG) -f ./dockerfiles/Dockerfile.price .

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

.PHONY: stop-containers
stop-containers:
	docker kill $(CART_CONTAINER_NAME) $(USERS_CONTAINER_NAME) $(PRICE_CONTAINER_NAME)

.PHONY: run-local-cart
run-local-cart: build-cart
	./dist/cart \
		-p $(CART_PORT) \
		--users-svc-address http://localhost:$(USERS_PORT)/users \
		--price-svc-address http://localhost:$(PRICE_PORT)/price \
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
		flask run \
		-p $(PRICE_PORT) \
		&

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
	docker run \
		-d \
		--rm \
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
