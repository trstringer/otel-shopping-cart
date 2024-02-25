# OpenTelemetry shopping cart application

Sample application to highlight distributed tracing and other aspects with [OpenTelemetry](https://opentelemetry.io/).

## Why?

OpenTelemetry is great, but generating signals (traces, metrics, and logs) isn't trivial if you're trying to learn, build, or experiment. This application is a good source of telemetry. Install it, fork it, add to it, do what you want with it!

## Usage

There are a few ways to "use" the application...

If you want to run _everything_ in a local [kind](https://kind.sigs.k8s.io/) cluster:

```bash
make deploy
```

Local dependencies:

* [kind](https://kind.sigs.k8s.io/)
* [ocb](https://opentelemetry.io/docs/collector/custom-collector/)
* [helm](https://helm.sh/docs/intro/install/)

If you already have a Kubernetes cluster and you want the application and observability tooling:

```bash
make app-install-with-tools
```

Local dependency: [helm](https://helm.sh/docs/intro/install/)

If you want _just_ the application:

```bash
make app-install
```

Local dependency: [helm](https://helm.sh/docs/intro/install/)

## Viewing telemetry

Once everything is installed, you should be able to view the traces through Jaeger. If you installed Jaeger either with `make deploy` or `make app-install-with-tools` you can port-forward:

```bash
make jaeger-port-forward
```

And navigate your browser to `localhost:16686` to view traces:

![Jaeger trace data](./images/otel-shopping-cart-jaeger-trace.png)

## Cleanup

To cleanup the local instance, run:

```
$ make clean
```

## Application design

![Application design](./images/otel-shopping-cart-design.png)

There are three services in this application:

* **Cart** - Service handling user requests for shopping cart data (written in Go)
* **User** - Handles user verification and lookup requests from the cart service (written in Go)
* **Price** - Serves update pricing information for products (written in Python)

The backend persistent application data storage is with **PostgreSQL**.

Instrumentation is entirely with OpenTelemetry's APIs and SDKs. Telemetry collection is achieved through the [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector) sending trace data to Jaeger.
