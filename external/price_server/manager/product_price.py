"""ProductPrice definition"""

from dataclasses import dataclass

@dataclass
class ProductPrice:
    """Representation of a product and its price"""

    product_id: int
    price: float

    def __init__(self, product_id: int, price: float):
        self.product_id = product_id
        self.price = price
