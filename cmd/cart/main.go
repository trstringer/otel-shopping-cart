/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/spf13/cobra"
	"github.com/trstringer/otel-shopping-cart/pkg/cart"
	"github.com/trstringer/otel-shopping-cart/pkg/users"
)

const rootPath = "cart"

var (
	port                int
	usersServiceAddress string
	priceServiceAddress string
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
}

func main() {
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
}

func userCart(w http.ResponseWriter, r *http.Request) {
	userName := strings.TrimPrefix(r.URL.Path, fmt.Sprintf("/%s/", rootPath))
	fmt.Printf("Received cart request for %s\n", userName)

	cartManager := cart.NewFakeCartManager(priceServiceAddress)

	user, err := getUser(usersServiceAddress, userName)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(fmt.Sprintf("error getting user: %v", err)))
		return
	}
	userCart, err := getUserCart(cartManager, user)
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

func getUser(userServiceEndpoint, userName string) (*users.User, error) {
	resp, err := http.Get(fmt.Sprintf("%s/%s", userServiceEndpoint, userName))
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

func getUserCart(cartManager cart.Manager, user *users.User) (*cart.Cart, error) {
	return cartManager.GetUserCart(user)
}

func addItemToUserCart(cartManager cart.Manager, userCart *cart.Cart, item cart.Product) error {
	return cartManager.AddItem(userCart, item)
}

func runServer() {
	http.HandleFunc(fmt.Sprintf("/%s/", rootPath), userCart)

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("Running server on %s\n", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		fmt.Printf("Error running server: %v\n", err)
		os.Exit(1)
	}
}
