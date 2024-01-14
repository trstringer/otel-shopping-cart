package main

import (
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/spf13/cobra"
	"golang.org/x/sync/errgroup"

	"github.com/trstringer/otel-shopping-cart/pkg/users"
)

var (
	cartURL  string
	usersURL string

	concurrency int
)

var rootCmd = &cobra.Command{
	Use:   "trafficgen",
	Short: "Traffic generator",
	Long:  `Generate traffic for the OpenTelemetry shopping card application.`,
	Run: func(cmd *cobra.Command, args []string) {
		generateTraffic(concurrency)
	},
}

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.Flags().IntVarP(&concurrency, "concurrency", "c", 100, "max degree of concurrency")
	rootCmd.Flags().StringVar(&cartURL, "cart-url", "cart", "cart URL")
	rootCmd.Flags().StringVar(&usersURL, "users-url", "users", "users URL")
}

func userRequests() error {
	resp, err := http.Get(fmt.Sprintf("http://%s/users", usersURL))
	if err != nil {
		return fmt.Errorf("error getting all users: %w", err)
	}
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("error reading all users body: %w", err)
	}
	var users []users.User
	err = json.Unmarshal(data, &users)
	if err != nil {
		return fmt.Errorf("error unmarshalling all users: %w", err)
	}

	for {
		idx := rand.Intn(len(users))
		userName := users[idx].Login
		_, err = http.Get(fmt.Sprintf("http://%s/users/%s", usersURL, userName))
		if err != nil {
			return fmt.Errorf("error getting user %s: %w", userName, err)
		}
		_, err = http.Get(fmt.Sprintf("http://%s/cart/%s", cartURL, userName))
		if err != nil {
			return fmt.Errorf("error getting user cart %s: %w", userName, err)
		}
	}
}

func generateTraffic(maxConcurrency int) {
	var g errgroup.Group
	g.SetLimit(concurrency)

	for i := 0; i < maxConcurrency; i++ {
		i := i
		g.Go(func() error {
			fmt.Printf("Starting routine %d\n", i)
			time.Sleep(2 * time.Second)
			return userRequests()
		})
	}

	if err := g.Wait(); err != nil {
		fmt.Printf("Error from user requests: %v\n", err)
	}
	fmt.Println("Done...")
}

func main() {
	Execute()
}
