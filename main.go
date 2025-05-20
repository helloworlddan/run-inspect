package main

import (
	"context"
	"fmt"
	"net/http"

	"github.com/helloworlddan/run"
)

func main() {
	http.HandleFunc("/", indexHandler)

	// Define shutdown behavior and serve HTTP
	err := run.ServeHTTP(func(ctx context.Context) {
		run.Debug(nil, "connections closed")
	}, nil)
	if err != nil {
		run.Fatal(nil, err)
	}
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Name:             %s\n", run.ServiceName())
	fmt.Fprintf(w, "Revision:         %s\n", run.ServiceRevision())
	fmt.Fprintf(w, "URL:              %s\n", run.URL())
	fmt.Fprintf(w, "Project ID:       %s\n", run.ProjectID())
	fmt.Fprintf(w, "Project Number:   %s\n", run.ProjectNumber())
	fmt.Fprintf(w, "Region:           %s\n", run.Region())
	fmt.Fprintf(w, "Service Account:  %s\n", run.ServiceAccountEmail())
	fmt.Fprintf(w, "Serving Instance: %s\n", run.ID())
	fmt.Fprintf(w, "Port:             %s\n", run.ServicePort())
}
