package main

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	httpRequest = promauto.NewCounter(prometheus.CounterOpts{
		Name: "cart_http_request",
		Help: "HTTP request",
	})
	httpResponses = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cart_http_response",
			Help: "HTTP response",
		},
		[]string{"status"},
	)
)
