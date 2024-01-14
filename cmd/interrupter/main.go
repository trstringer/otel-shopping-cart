package main

import (
	"os"

	"github.com/spf13/cobra"
)

var (
	lockDurationSeconds int
)

var rootCmd = &cobra.Command{
	Use:   "interrupter",
	Short: "Service interrupter",
	Long:  `Interrupt service and cause quality issues.`,
	Run: func(cmd *cobra.Command, args []string) {
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
}

func main() {
	Execute()
}
