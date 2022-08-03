package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/baggage"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/exporters/stdout/stdouttrace"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.10.0"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	"github.com/trstringer/otel-shopping-cart/pkg/users"
)

const (
	rootPath      = "users"
	otelTraceName = "github.com/trstringer/otel-shopping-cart/cmd/users/main"
	traceFileName = "trace2.json"
)

var (
	port         int
	mySQLAddress string
	mySQLUser    string
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "users",
	Short: "Users application",
	Long:  `Users application for OpenTelemetry example.`,
	Run: func(cmd *cobra.Command, args []string) {
		validateParams()
		runServer()
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.Flags().IntVarP(&port, "port", "p", 8080, "port for the server to listen on")
	rootCmd.Flags().StringVar(&mySQLAddress, "mysql-address", "", "location for MySQL instance")
	rootCmd.Flags().StringVar(&mySQLUser, "mysql-user", "", "MySQL user")
}

func fileTraceProvider() (*trace.TracerProvider, error) {
	file, err := os.Open(traceFileName)
	if errors.Is(err, os.ErrNotExist) {
		file, err = os.Create(traceFileName)
		if err != nil {
			return nil, fmt.Errorf("error creating trace file: %w", err)
		}
	} else if err != nil {
		return nil, fmt.Errorf("unknown error trying to open trace file: %w", err)
	}

	exporter, err := stdouttrace.New(
		stdouttrace.WithWriter(file),
		stdouttrace.WithPrettyPrint(),
	)
	if err != nil {
		return nil, fmt.Errorf("error getting stdout trace: %w", err)
	}

	resource, err := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String(otelTraceName),
			semconv.ServiceVersionKey.String("v1.0.0"),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("error creating otel resource: %w", err)
	}

	return trace.NewTracerProvider(
		trace.WithBatcher(exporter),
		trace.WithResource(resource),
	), nil
}

func otlpTracerProvider() (*trace.TracerProvider, error) {
	ctx := context.Background()

	res, err := resource.New(
		ctx,
		resource.WithAttributes(semconv.ServiceNameKey.String("users")),
	)
	if err != nil {
		return nil, fmt.Errorf("error creating OTLP tracer provider resource: %w", err)
	}

	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	hostIP := os.Getenv("HOST_IP")
	if hostIP == "" {
		return nil, fmt.Errorf("unexpected no host IP address for receiver")
	}
	receiverAddress := fmt.Sprintf("%s:%d", hostIP, 4317)

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

func main() {
	// tp, err := fileTraceProvider()
	tp, err := otlpTracerProvider()
	if err != nil {
		fmt.Printf("Error setting tracer provider: %v\n", err)
		os.Exit(1)
	}
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{}),
	)
	defer func() {
		if err := tp.Shutdown(context.Background()); err != nil {
			fmt.Printf("Error shutting down tracer provider: %v", err)
			os.Exit(1)
		}
	}()

	Execute()
}

func validateParams() {
	if mySQLAddress == "" {
		fmt.Println("Must pass in --mysql-address")
		os.Exit(1)
	}

	if mySQLUser == "" {
		fmt.Println("Must pass in --mysql-user")
		os.Exit(1)
	}

	if os.Getenv("MYSQL_PASSWORD") == "" {
		fmt.Println("Must specify MYSQL_PASSWORD")
		os.Exit(1)
	}
}

func user(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	ctx, span := otel.Tracer(otelTraceName).Start(ctx, "Get user")
	defer span.End()

	reqBaggage := baggage.FromContext(ctx)
	span.SetAttributes(attribute.String(
		"user.name",
		reqBaggage.Member("user.name").Value()),
	)

	userName := strings.TrimPrefix(r.URL.Path, fmt.Sprintf("/%s/", rootPath))
	fmt.Printf("Received user request for %s\n", userName)

	userManager := users.NewMySQLManager(
		mySQLAddress,
		"otel_shopping_cart",
		mySQLUser,
		os.Getenv("MYSQL_PASSWORD"),
	)
	user, err := getUser(ctx, userManager, userName)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(fmt.Sprintf("error retrieving user: %v", err)))
		return
	}

	userData, err := json.Marshal(user)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(fmt.Sprintf("error marshalling user data: %v", err)))
		return
	}

	w.Write([]byte(userData))
}

func getUser(ctx context.Context, userManager users.Manager, userName string) (*users.User, error) {
	return userManager.GetUser(ctx, userName)
}

func runServer() {
	http.Handle(
		fmt.Sprintf("/%s/", rootPath),
		otelhttp.NewHandler(
			http.HandlerFunc(user),
			"HTTP get user",
			otelhttp.WithTracerProvider(otel.GetTracerProvider()),
			otelhttp.WithPropagators(otel.GetTextMapPropagator()),
		),
	)

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("Running server on %s\n", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		fmt.Printf("Error running server: %v\n", err)
		os.Exit(1)
	}
}
