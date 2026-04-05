package bootstrap

import (
	"net/http/httptest"
	"testing"
)

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest("GET", "/healthz", nil)
	rr := httptest.NewRecorder()
	healthHandler(rr, req)
	if rr.Code != 200 {
		t.Fatalf("status %d", rr.Code)
	}
	if got := rr.Body.String(); got != `{"status":"ok"}` {
		t.Fatalf("body %q", got)
	}
}
