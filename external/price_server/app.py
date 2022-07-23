"""OTel shopping cart price server"""

from flask import Flask, jsonify
from manager.fake import get_product_price

app = Flask(__name__)

@app.route("/price/<int:product_id>")
def product_price(product_id):
    """Route to get the product for a product"""

    output = get_product_price(product_id)
    return jsonify(output)
