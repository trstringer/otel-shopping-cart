"""Database manager for the price server"""

import os
import psycopg2
from .product_price import ProductPrice

def get_product_price(product_id: int) -> float:
    """Returns the product price from the database"""

    cnx = psycopg2.connect(
        host=os.environ["DB_ADDRESS"],
        port=os.environ["DB_PORT"],
        database=os.environ["DB_DATABASE"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"]
    )

    query = """
SELECT price
FROM product_price
WHERE product_id = %s;
"""

    cursor = cnx.cursor()
    cursor.execute(query, (product_id,))

    for (price,) in cursor:
        if price is not None:
            cursor.close()
            cnx.close()
            return ProductPrice(product_id=product_id, price=float(price))

    return None
