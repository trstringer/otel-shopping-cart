DROP DATABASE IF EXISTS otel_shopping_cart;
CREATE DATABASE otel_shopping_cart;

USE otel_shopping_cart;

CREATE TABLE application_user (
    id INT NOT NULL AUTO_INCREMENT,
    login VARCHAR(64) NOT NULL,
    first_name VARCHAR(64) NOT NULL,
    last_name VARCHAR(64) NOT NULL,
    date_added DATETIME NOT NULL DEFAULT (NOW()),
    PRIMARY KEY (id)
);

CREATE TABLE product (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(64),
    date_added DATETIME NOT NULL DEFAULT (NOW()),
    PRIMARY KEY (id)
);

CREATE TABLE product_price (
    id INT NOT NULL AUTO_INCREMENT,
    product_id INT NOT NULL,
    price DECIMAL(8, 2) NOT NULL,
    date_added DATETIME NOT NULL DEFAULT (NOW()),
    PRIMARY KEY (id),
    FOREIGN KEY (product_id)
        REFERENCES product(id)
);

CREATE TABLE cart (
    id INT NOT NULL AUTO_INCREMENT,
    application_user_id INT NOT NULL,
    product_id INT NOT NULL,
    date_added DATETIME NOT NULL DEFAULT (NOW()),
    PRIMARY KEY (id),
    FOREIGN KEY (application_user_id)
        REFERENCES application_user(id),
    FOREIGN KEY (product_id)
        REFERENCES product(id)
);

INSERT INTO application_user (login, first_name, last_name)
VALUES
    ("tlasagna", "Tommy", "Lasagna"),
    ("mmozzarella", "Maria", "Mozzarella"),
    ("pprosciutto", "Pietrina", "Prosciutto"),
    ("ppizza", "Pauly", "Pizza");

INSERT INTO product(name)
VALUES
    ("Athletic socks"),
    ("T-shirt"),
    ("Book"),
    ("Watch"),
    ("Telephone");

INSERT INTO product_price(product_id, price)
VALUES
    (1, 2.45),
    (2, 13.99),
    (3, 5.99),
    (4, 53.25),
    (5, 99.99);

INSERT INTO cart(application_user_id, product_id)
VALUES
    (1, 3),
    (1, 5),
    (2, 2),
    (3, 3),
    (3, 4),
    (4, 3);
