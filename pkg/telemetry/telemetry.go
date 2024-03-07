package telemetry

import (
	"context"
	"fmt"
	"time"

	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// TelemetryLibrary is the string for the instrumentation library.
const TelemetryLibrary = "github.com/trstringer/otel-shopping-cart"

// OTLPTracerProvider supplies an OTLP tracer provider.
func OTLPTracerProvider(receiver, serviceName, serviceVersion string) (*trace.TracerProvider, error) {
	ctx := context.Background()

	res, err := resource.New(
		ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String(serviceName),
			semconv.ServiceVersionKey.String(serviceVersion),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("error creating OTLP tracer provider resource: %w", err)
	}

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	receiverAddress := fmt.Sprintf("%s:%d", receiver, 4317)
	fmt.Printf("Receiver address: %s\n", receiverAddress)

	conn, err := grpc.DialContext(
		ctx,
		receiverAddress,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
	)
	if err != nil {
		return nil, fmt.Errorf("error creating client connection to collector: %w", err)
	}

	otlpTraceExporter, err := otlptracegrpc.New(
		ctx,
		otlptracegrpc.WithGRPCConn(conn),
	)

	return trace.NewTracerProvider(
		trace.WithSampler(trace.AlwaysSample()),
		trace.WithResource(res),
		trace.WithSpanProcessor(trace.NewBatchSpanProcessor(otlpTraceExporter)),
	), nil
}
