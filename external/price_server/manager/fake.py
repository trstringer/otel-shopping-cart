"""Fake representation for price manager"""

from random import random
from .product_price import ProductPrice

def get_product_price(product_id: int):
    """Fake implementation of product price"""

    return ProductPrice(product_id=product_id, price=random() * 10)
