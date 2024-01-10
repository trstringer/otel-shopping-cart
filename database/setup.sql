CREATE TABLE application_user (
    id SERIAL,
    login VARCHAR(64) NOT NULL,
    first_name VARCHAR(64) NOT NULL,
    last_name VARCHAR(64) NOT NULL,
    date_added TIMESTAMP NOT NULL DEFAULT (NOW()),
    PRIMARY KEY (id)
);

CREATE TABLE product (
    id SERIAL,
    name VARCHAR(64),
    date_added TIMESTAMP NOT NULL DEFAULT (NOW()),
    PRIMARY KEY (id)
);

CREATE TABLE product_price (
    id SERIAL,
    product_id INT NOT NULL,
    price DECIMAL(8, 2) NOT NULL,
    date_added TIMESTAMP NOT NULL DEFAULT (NOW()),
    PRIMARY KEY (id),
    FOREIGN KEY (product_id)
        REFERENCES product(id)
);

CREATE TABLE cart (
    id SERIAL,
    application_user_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    date_added TIMESTAMP NOT NULL DEFAULT (NOW()),
    PRIMARY KEY (id),
    FOREIGN KEY (application_user_id)
        REFERENCES application_user(id),
    FOREIGN KEY (product_id)
        REFERENCES product(id)
);

INSERT INTO application_user (login, first_name, last_name)
VALUES
    ('tlasagna', 'Tommy', 'Lasagna'),
    ('mmozzarella', 'Maria', 'Mozzarella'),
    ('pprosciutto', 'Pietrina', 'Prosciutto'),
    ('ppizza', 'Pauly', 'Pizza'),
    ('bbruschetta', 'Bianca', 'Bruschetta'),
    ('llinguine', 'Lucia', 'Linguine'),
    ('ggorgonzola', 'Georgia', 'Gorgonzola');

INSERT INTO product(name)
VALUES
    ('Athletic socks'),
    ('T-shirt'),
    ('Book'),
    ('Watch'),
    ('Telephone'),
    ('Pencil'),
    ('Chair'),
    ('Hat');

INSERT INTO product_price(product_id, price)
VALUES
    (1, 2.45),
    (2, 13.99),
    (3, 5.99),
    (4, 53.25),
    (5, 99.99),
    (6, 1.39),
    (7, 253.21),
    (8, 15.99);

INSERT INTO cart(application_user_id, product_id, quantity)
VALUES
    (1, 3, 1),
    (1, 5, 2),
    (2, 2, 2),
    (3, 3, 2),
    (3, 4, 2),
    (4, 3, 2),
    (5, 6, 1),
    (5, 2, 1),
    (5, 7, 2),
    (6, 1, 5),
    (7, 3, 3);

CREATE ROLE shoppingcartuser WITH LOGIN PASSWORD 'secretdbpassword123';
GRANT SELECT ON TABLE public.application_user TO shoppingcartuser;
GRANT SELECT, INSERT ON TABLE public.cart TO shoppingcartuser;
GRANT SELECT ON TABLE public.product TO shoppingcartuser;
GRANT SELECT ON TABLE public.product_price TO shoppingcartuser;
