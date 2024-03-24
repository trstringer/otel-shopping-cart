package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/spf13/cobra"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/baggage"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"

	"github.com/trstringer/otel-shopping-cart/pkg/telemetry"
	"github.com/trstringer/otel-shopping-cart/pkg/users"
)

const rootPath = "users"

var (
	port         int
	dbSQLAddress string
	dbSQLUser    string
	otelReceiver string
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "users",
	Short: "Users application",
	Long:  `Users application for OpenTelemetry example.`,
	Run: func(cmd *cobra.Command, args []string) {
		validateParams()
		tp, err := setupObservability()
		if err != nil {
			fmt.Printf("Error setting up observability: %v\n", err)
			os.Exit(1)
		}
		defer func() {
			if err := tp.Shutdown(context.Background()); err != nil {
				fmt.Printf("Error shutting down tracer provider: %v", err)
				os.Exit(1)
			}
		}()
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
	rootCmd.Flags().StringVar(&dbSQLAddress, "db-address", "", "location for PostgreSQL instance")
	rootCmd.Flags().StringVar(&dbSQLUser, "db-user", "", "PostgreSQL user")
	rootCmd.Flags().StringVar(&otelReceiver, "otel-receiver", "", "OpenTelemetry receiver")
}

func main() {
	Execute()
}

func setupObservability() (*sdktrace.TracerProvider, error) {
	tp, err := telemetry.OTLPTracerProvider(otelReceiver, "users", "v1.0.0")
	if err != nil {
		return nil, fmt.Errorf("error setting tracer provider: %w", err)
	}
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{}),
	)
	return tp, nil
}

func validateParams() {
	if dbSQLAddress == "" {
		fmt.Println("Must pass in --db-address")
		os.Exit(1)
	}

	if dbSQLUser == "" {
		fmt.Println("Must pass in --db-user")
		os.Exit(1)
	}

	if os.Getenv("DB_PASSWORD") == "" {
		fmt.Println("Must specify DB_PASSWORD")
		os.Exit(1)
	}

	if otelReceiver == "" {
		fmt.Println("Must pass in --otel-receiver")
		os.Exit(1)
	}
}

func allUsers(w http.ResponseWriter, r *http.Request) {
	httpRequest.Inc()
	userManager := users.NewDBManager(
		dbSQLAddress,
		"otel_shopping_cart",
		dbSQLUser,
		os.Getenv("DB_PASSWORD"),
	)
	allUsers, err := userManager.GetAllUsers()
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Printf("error retrieving all users: %v\n", err)
		w.Write([]byte(fmt.Sprintf("error retrieving all users: %v", err)))
		httpResponses.WithLabelValues(strconv.Itoa(http.StatusBadRequest)).Inc()
		return
	}
	userData, err := json.Marshal(allUsers)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Printf("error marshalling all users: %v\n", err)
		w.Write([]byte(fmt.Sprintf("error marshalling all users: %v", err)))
		httpResponses.WithLabelValues(strconv.Itoa(http.StatusBadRequest)).Inc()
		return
	}

	w.Write([]byte(userData))
}

func user(w http.ResponseWriter, r *http.Request) {
	httpRequest.Inc()
	ctx := r.Context()
	ctx, span := otel.Tracer(telemetry.TelemetryLibrary).Start(ctx, "get_user")
	defer span.End()

	reqBaggage := baggage.FromContext(ctx)
	span.SetAttributes(attribute.String(
		"req.addr",
		reqBaggage.Member("req.addr").Value()),
	)

	userName := strings.TrimPrefix(r.URL.Path, fmt.Sprintf("/%s/", rootPath))
	fmt.Printf("Received user request for %q\n", userName)

	userManager := users.NewDBManager(
		dbSQLAddress,
		"otel_shopping_cart",
		dbSQLUser,
		os.Getenv("DB_PASSWORD"),
	)
	user, err := getUser(ctx, userManager, userName)
	if err != nil {
		span.RecordError(err)
		w.WriteHeader(http.StatusBadRequest)
		fmt.Printf("error retrieving user: %v\n", err)
		w.Write([]byte(fmt.Sprintf("error retrieving user: %v", err)))
		httpResponses.WithLabelValues(strconv.Itoa(http.StatusBadRequest)).Inc()
		return
	}

	userData, err := json.Marshal(user)
	if err != nil {
		span.RecordError(err)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Printf("error retrieving user: %v\n", err)
		w.Write([]byte(fmt.Sprintf("error marshalling user data: %v", err)))
		httpResponses.WithLabelValues(strconv.Itoa(http.StatusInternalServerError)).Inc()
		return
	}

	w.Write([]byte(userData))
}

func getUser(ctx context.Context, userManager users.Manager, userName string) (*users.User, error) {
	return userManager.GetUser(ctx, userName)
}

func runServer() {
	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc(fmt.Sprintf("/%s", rootPath), allUsers)
	http.Handle(
		fmt.Sprintf("/%s/", rootPath),
		otelhttp.NewHandler(
			http.HandlerFunc(user),
			"http_user",
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
