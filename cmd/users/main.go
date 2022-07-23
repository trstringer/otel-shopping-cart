/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/spf13/cobra"
	"github.com/trstringer/otel-shopping-cart/pkg/users"
)

const rootPath = "users"

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

func main() {
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
	userName := strings.TrimPrefix(r.URL.Path, fmt.Sprintf("/%s/", rootPath))
	fmt.Printf("Received user request for %s\n", userName)

	userManager := users.NewMySQLManager(
		mySQLAddress,
		"otel_shopping_cart",
		mySQLUser,
		os.Getenv("MYSQL_PASSWORD"),
	)
	user, err := userManager.GetUser(userName)
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

func getUser(userManager users.Manager, userName string) (*users.User, error) {
	return userManager.GetUser(userName)
}

func runServer() {
	http.HandleFunc(fmt.Sprintf("/%s/", rootPath), user)

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("Running server on %s\n", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		fmt.Printf("Error running server: %v\n", err)
		os.Exit(1)
	}
}
