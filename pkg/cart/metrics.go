package cart

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	dbmanagerErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "dbmanager_error",
		Help: "dbmanager error count",
	})
)
