"""Database manager for the price server"""

import os
from mysql import connector
from .product_price import ProductPrice

def get_product_price(product_id: int) -> float:
    """Returns the product price from the database"""

    cnx = connector.connect(
        host=os.environ["MYSQL_ADDRESS"],
        port=os.environ["MYSQL_PORT"],
        database=os.environ["MYSQL_DATABASE"],
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"]
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
