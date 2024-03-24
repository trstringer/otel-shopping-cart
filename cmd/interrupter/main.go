package main

import (
	"context"
	"fmt"
	"math/rand"
	"os"
	"time"

	"github.com/spf13/cobra"

	"github.com/trstringer/otel-shopping-cart/pkg/dbmanager"
)

var (
	lockDurationSeconds int
	dbSQLAddress        string
	dbSQLUser           string
)

var rootCmd = &cobra.Command{
	Use:   "interrupter",
	Short: "Service interrupter",
	Long:  `Interrupt service and cause quality issues.`,
	Run: func(cmd *cobra.Command, args []string) {
		dbm := dbmanager.NewDBManager(dbSQLAddress, "otel_shopping_cart", dbSQLUser, os.Getenv("DB_PASSWORD"))
		users, err := dbm.GetAllUsers()
		if err != nil {
			fmt.Printf("Error getting users: %v\n", err)
			os.Exit(1)
		}

		for {
			randomUser := users[rand.Intn(len(users))]
			fmt.Printf("%s - Blocking for user %s\n", time.Now().String(), randomUser.Login)
			if err := dbm.SetUserLastAccessWithDelay(context.Background(), randomUser); err != nil {
				fmt.Printf("Error setting last user access: %v\n", err)
			}
		}
	},
}

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.Flags().IntVarP(&lockDurationSeconds, "lock-seconds", "l", 10, "time to hold locks for")
	rootCmd.Flags().StringVar(&dbSQLAddress, "db-address", "", "location for PostgreSQL instance")
	rootCmd.Flags().StringVar(&dbSQLUser, "db-user", "", "PostgreSQL user")
}

func main() {
	Execute()
}
