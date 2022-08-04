"""OTel shopping cart price server"""

import os
import sys
from flask import Flask, jsonify
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, SERVICE_VERSION
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from manager.db import get_product_price

resource = Resource(attributes={
    SERVICE_NAME: "otel-shopping-price",
    SERVICE_VERSION: "v1.0.0"
})
tracer_provider = TracerProvider(resource=resource)

host_ip = os.environ.get("HOST_IP")
if host_ip is None:
    print("Must pass in environment var HOST_IP")
    sys.exit(1)

tracer_provider.add_span_processor(span_processor=BatchSpanProcessor(
    OTLPSpanExporter(endpoint=f"{host_ip}:4317", insecure=True)
))
trace.set_tracer_provider(tracer_provider)

app = Flask(__name__)
tracer = trace.get_tracer(__name__)

@app.route("/price/<int:product_id>")
def product_price(product_id: int):
    """Route to get the product for a product"""

    with tracer.start_as_current_span("Product price lookup"):
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
