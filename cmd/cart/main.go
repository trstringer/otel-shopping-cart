package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
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
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.10.0"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	"github.com/trstringer/otel-shopping-cart/pkg/cart"
	"github.com/trstringer/otel-shopping-cart/pkg/users"
)

const (
	rootPath         = "cart"
	telemetryLibrary = "github.com/trstringer/otel-shopping-cart"
)

var (
	port                int
	usersServiceAddress string
	priceServiceAddress string
	mySQLAddress        string
	mySQLUser           string
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "cart",
	Short: "Cart application",
	Long:  `Shopping cart application for OpenTelemetry example.`,
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
	rootCmd.Flags().StringVar(&usersServiceAddress, "users-svc-address", "", "address for users service")
	rootCmd.Flags().StringVar(&priceServiceAddress, "price-svc-address", "", "address for price service")
	rootCmd.Flags().StringVar(&mySQLAddress, "mysql-address", "", "location for MySQL instance")
	rootCmd.Flags().StringVar(&mySQLUser, "mysql-user", "", "MySQL user")
}

func otlpTracerProvider() (*trace.TracerProvider, error) {
	ctx := context.Background()

	res, err := resource.New(
		ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String("cart"),
			semconv.ServiceVersionKey.String("v1.0.0"),
		),
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
	if usersServiceAddress == "" {
		fmt.Println("Must pass in --users-svc-address")
		os.Exit(1)
	}

	if priceServiceAddress == "" {
		fmt.Println("Must pass in --price-svc-address")
		os.Exit(1)
	}

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

func userCart(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer(telemetryLibrary).Start(r.Context(), "get_user_cart")
	defer span.End()

	userNameBaggage, err := baggage.NewMember("req.addr", r.RemoteAddr)
	if err != nil {
		fmt.Printf("Error creating baggage member: %v\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("request error"))
		return
	}

	reqBaggage, err := baggage.New(userNameBaggage)
	if err != nil {
		fmt.Printf("Error creating baggage: %v\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("request error"))
		return
	}
	ctx = baggage.ContextWithBaggage(ctx, reqBaggage)

	userName := strings.TrimPrefix(r.URL.Path, fmt.Sprintf("/%s/", rootPath))
	fmt.Printf("Received cart request for %s\n", userName)

	cartManager := cart.NewMySQLManager(
		mySQLAddress,
		"otel_shopping_cart",
		mySQLUser,
		os.Getenv("MYSQL_PASSWORD"),
	)

	user, err := getUser(ctx, usersServiceAddress, userName)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(fmt.Sprintf("error getting user: %v", err)))
		return
	}
	userCart, err := getUserCart(ctx, cartManager, user)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(fmt.Sprintf("error getting user cart: %v", err)))
		return
	}

	if r.Method == http.MethodPost {
		data, err := io.ReadAll(r.Body)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("error reading body data: %v", err)))
			return
		}
		newItem := cart.Product{}
		if err := json.Unmarshal(data, &newItem); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("error unmarshalling data: %v", err)))
			return
		}
		if err := addItemToUserCart(cartManager, userCart, newItem); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("error adding item to cart: %v", err)))
			return
		}
	}

	if r.Method == http.MethodGet || r.Method == http.MethodPost {
		userCart, err = getUserCart(ctx, cartManager, user)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("error getting user cart: %v", err)))
			return
		}
		jsonCart, err := json.Marshal(userCart)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("error marshalling cart: %v", err)))
			return
		}

		w.Write([]byte(jsonCart))
		return
	}

	w.WriteHeader(http.StatusBadRequest)
	w.Write([]byte("unknown method"))
}

func getUser(ctx context.Context, userServiceEndpoint, userName string) (*users.User, error) {
	ctx, span := otel.Tracer(telemetryLibrary).Start(ctx, "get_user")
	defer span.End()

	resp, err := otelhttp.Get(ctx, fmt.Sprintf("%s/%s", userServiceEndpoint, userName))
	if err != nil {
		return nil, fmt.Errorf("error getting user from user service: %w", err)
	} else if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bad status code from user service: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("error reading response body from user service: %w", err)
	}

	user := users.User{}
	if err := json.Unmarshal(body, &user); err != nil {
		return nil, fmt.Errorf("error unmarshalling user service response: %w", err)
	}

	return &user, nil
}

func getProductPrice(ctx context.Context, priceServiceEndpoint string, productID int) (float64, error) {
	ctx, span := otel.Tracer(telemetryLibrary).Start(ctx, "get_product_price")
	defer span.End()

	span.SetAttributes(attribute.Int("product.id", productID))

	resp, err := otelhttp.Get(ctx, fmt.Sprintf("%s/%d", priceServiceEndpoint, productID))
	if err != nil {
		return 0.0, fmt.Errorf("error getting price from price service: %w", err)
	} else if resp.StatusCode != http.StatusOK {
		return 0.0, fmt.Errorf("bad status code from price service: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0.0, fmt.Errorf("error reading response body from price service: %w", err)
	}

	product := struct {
		Cost float64 `json:"price"`
	}{}
	if err := json.Unmarshal(body, &product); err != nil {
		return 0.0, fmt.Errorf("error unmarshalling price service response: %w", err)
	}

	return product.Cost, nil
}

func getUserCart(ctx context.Context, cartManager cart.Manager, user *users.User) (*cart.Cart, error) {
	userCart, err := cartManager.GetUserCart(user)
	if err != nil {
		return nil, fmt.Errorf("error getting user cart: %w", err)
	}
	for idx, product := range userCart.Products {
		price, err := getProductPrice(ctx, priceServiceAddress, product.ID)
		if err != nil {
			return nil, fmt.Errorf("error getting price for product ID %d: %w", product.ID, err)
		}
		userCart.Products[idx].Cost = price
	}
	return userCart, nil
}

func addItemToUserCart(cartManager cart.Manager, userCart *cart.Cart, item cart.Product) error {
	return cartManager.AddItem(userCart, item)
}

func runServer() {
	http.Handle(
		fmt.Sprintf("/%s/", rootPath),
		otelhttp.NewHandler(
			http.HandlerFunc(userCart),
			"http_user_cart",
			otelhttp.WithTracerProvider(otel.GetTracerProvider()),
			otelhttp.WithPropagators(otel.GetTextMapPropagator()),
		))

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("Running server on %s\n", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		fmt.Printf("Error running server: %v\n", err)
		os.Exit(1)
	}
}
