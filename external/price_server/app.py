"""OTel shopping cart price server"""

import os
import sys
from flask import Flask, jsonify
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, SERVICE_VERSION
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor
from manager.db import get_product_price

app = Flask(__name__)

@app.route("/price/<int:product_id>")
def product_price(product_id: int):
    """Route to get the product for a product"""

    output = get_product_price(product_id)
    return jsonify(output)

def validate_params() -> None:
    """Validate input parameters"""

    if os.environ.get("DB_ADDRESS") is None:
        print("Must pass in environment var DB_ADDRESS")
        sys.exit(1)

    if os.environ.get("DB_PORT") is None:
        print("Must pass in environment var DB_PORT")
        sys.exit(1)

    if os.environ.get("DB_DATABASE") is None:
        print("Must pass in environment var DB_DATABASE")
        sys.exit(1)

    if os.environ.get("DB_USER") is None:
        print("Must pass in environment var DB_USER")
        sys.exit(1)

    if os.environ.get("DB_PASSWORD") is None:
        print("Must pass in environment var DB_PASSWORD")
        sys.exit(1)

def main():
    """Main entry point"""

    validate_params()

    resource = Resource(attributes={
        SERVICE_NAME: "price",
        SERVICE_VERSION: "v1.0.0"
    })
    tracer_provider = TracerProvider(resource=resource)

    otel_receiver = os.environ.get("OTEL_RECEIVER")
    if otel_receiver is None:
        print("Must pass in environment var OTEL_RECEIVER")
        sys.exit(1)

    tracer_provider.add_span_processor(span_processor=BatchSpanProcessor(
        OTLPSpanExporter(endpoint=f"{otel_receiver}:4317", insecure=True)
    ))
    trace.set_tracer_provider(tracer_provider)

    FlaskInstrumentor().instrument_app(app)
    Psycopg2Instrumentor().instrument()

main()
