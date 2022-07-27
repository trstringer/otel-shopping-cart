"""OTel shopping cart price server"""

import os
import sys
from flask import Flask, jsonify
from manager.db import get_product_price

app = Flask(__name__)

@app.route("/price/<int:product_id>")
def product_price(product_id):
    """Route to get the product for a product"""

    output = get_product_price(product_id)
    return jsonify(output)

def validate_params() -> None:
    """Validate input parameters"""

    if os.environ.get("MYSQL_ADDRESS") is None:
        print("Must pass in environment var MYSQL_ADDRESS")
        sys.exit(1)

    if os.environ.get("MYSQL_PORT") is None:
        print("Must pass in environment var MYSQL_PORT")
        sys.exit(1)

    if os.environ.get("MYSQL_DATABASE") is None:
        print("Must pass in environment var MYSQL_DATABASE")
        sys.exit(1)

    if os.environ.get("MYSQL_USER") is None:
        print("Must pass in environment var MYSQL_USER")
        sys.exit(1)

    if os.environ.get("MYSQL_PASSWORD") is None:
        print("Must pass in environment var MYSQL_PASSWORD")
        sys.exit(1)

validate_params()
